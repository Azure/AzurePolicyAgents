<#
.SYNOPSIS
    Creates or updates the specialised Azure AI Foundry policy agents (deny, audit, dine, modify,
    instructionsAgent) in a single Foundry project.

.DESCRIPTION
    Installs the Metro.AI module, sets the Foundry context, then deploys each requested agent from
    its instruction definition. For each agent type the instructions come from the matching
    -*Instructions parameter when supplied, otherwise they are built or loaded from
    agentInstructions/<type>PolicyAgentInstructions.json. The InstructionsAgent is additionally
    configured with the Microsoft Learn MCP server. Existing agents are left unchanged unless
    -UpdateExisting is set, in which case they are patched in place using their current agent id.

.PARAMETER ProjectEndpoint
    Azure AI Foundry project endpoint.

.PARAMETER ModelDeploymentName
    Model deployment name assigned to every agent (overrides any model in the definition).

.PARAMETER AgentTypes
    Comma-separated list of agent types to deploy. Defaults to "deny,audit,deployIfNotExists,modify".

.PARAMETER DenyInstructions
    Optional inline instruction override for the deny agent. When empty, the definition is built or
    loaded from agentInstructions.

.PARAMETER AuditInstructions
    Optional inline instruction override for the audit agent. When empty, built or loaded from agentInstructions.

.PARAMETER DineInstructions
    Optional inline instruction override for the DINE agent. When empty, built or loaded from agentInstructions.

.PARAMETER ModifyInstructions
    Optional inline instruction override for the modify agent. When empty, built or loaded from agentInstructions.

.PARAMETER MaintenanceInstructions
    Optional inline instruction override for the InstructionsAgent. When empty, built or loaded from agentInstructions.

.PARAMETER MicrosoftLearnMcpUrl
    URL of the Microsoft Learn MCP server attached to the InstructionsAgent.

.PARAMETER MicrosoftLearnMcpServerLabel
    Label used for the Microsoft Learn MCP server connection.

.PARAMETER MicrosoftLearnMcpAllowedTools
    Allowed tool names exposed by the Microsoft Learn MCP server.

.PARAMETER DisableMicrosoftLearnMcp
    Disables the Microsoft Learn MCP server on the InstructionsAgent.

.PARAMETER UpdateExisting
    Updates an agent in place when one of the same name already exists instead of skipping it.

.PARAMETER ReasoningEffort
    Default reasoning_effort applied to an agent when its definition does not specify one.
#>
param(
    [Parameter(Mandatory = $true)]
    [string] $ProjectEndpoint,
    
    [Parameter(Mandatory = $true)]
    [string] $ModelDeploymentName,
    
    [Parameter(Mandatory = $false)]
    [string] $AgentTypes = "deny,audit,deployIfNotExists,modify",
    
    [Parameter(Mandatory = $false)]
    [string] $DenyInstructions = "",
    
    [Parameter(Mandatory = $false)]
    [string] $AuditInstructions = "",
    
    [Parameter(Mandatory = $false)]
    [string] $DineInstructions = "",
    
    [Parameter(Mandatory = $false)]
    [string] $ModifyInstructions = "",

    [Parameter(Mandatory = $false)]
    [string] $MaintenanceInstructions = "",

    [Parameter(Mandatory = $false)]
    [string] $MicrosoftLearnMcpUrl = "https://learn.microsoft.com/api/mcp",

    [Parameter(Mandatory = $false)]
    [string] $MicrosoftLearnMcpServerLabel = "microsoft-learn",

    [Parameter(Mandatory = $false)]
    [string[]] $MicrosoftLearnMcpAllowedTools = @(
        "microsoft_docs_search",
        "microsoft_docs_fetch",
        "microsoft_code_sample_search"
    ),

    [Parameter(Mandatory = $false)]
    [switch] $DisableMicrosoftLearnMcp = $false,
    
    [Parameter(Mandatory = $false)]
    [switch] $UpdateExisting = $false,

    [Parameter(Mandatory = $false)]
    [string] $ReasoningEffort = "medium"
)

Write-Host "Installing Metro.AI PowerShell module..." -ForegroundColor Cyan
Install-Module -Name Metro.AI -Force -AllowClobber

# Metro.AI authenticates with the Az PowerShell context (Get-AzAccessToken). If that context is
# missing or points at a different tenant/subscription than the Foundry endpoint, Set-MetroAIContext
# fails with a misleading HTTP 404. Surface the active context so mismatches are obvious.
$azContext = Get-AzContext
if (-not $azContext) {
    throw "No Az PowerShell context found. Run Connect-AzAccount (and Set-AzContext) against the target tenant/subscription before running this script."
}
Write-Host "Az context: subscription '$($azContext.Subscription.Name)' ($($azContext.Subscription.Id)), tenant $($azContext.Tenant.Id)" -ForegroundColor Cyan
Write-Host "Ensure this tenant matches the Foundry endpoint '$ProjectEndpoint'. A mismatch surfaces as HTTP 404 from Set-MetroAIContext." -ForegroundColor Yellow

Write-Host "Setting Metro.AI context..." -ForegroundColor Cyan
Set-MetroAIContext -Endpoint $ProjectEndpoint -ApiType Agent

function Get-RealAgentId {
    param([object] $AgentObject)
    if (-not $AgentObject) { return $null }
    # Use the root .id - in Foundry Agents preview this equals the agent name and is the
    # correct identifier for all subsequent API calls (conversations, updates, etc.)
    return $AgentObject.id
}

function Get-DefaultMcpServersConfiguration {
    if ($DisableMicrosoftLearnMcp) {
        return @()
    }

    return @(
        @{
            server_label  = $MicrosoftLearnMcpServerLabel
            server_url    = $MicrosoftLearnMcpUrl
            allowed_tools = $MicrosoftLearnMcpAllowedTools
        }
    )
}

function Set-AgentReasoningEffort {
    param(
        [string] $AgentId,
        [string] $ReasoningEffortValue
    )

    try {
        $current = Get-MetroAIAgent -AgentId $AgentId
        $currentDefinition = if ($current.versions -and $current.versions.latest -and $current.versions.latest.definition) {
            $current.versions.latest.definition
        }
        elseif ($current.definition) {
            $current.definition
        }
        else {
            $null
        }

        if (-not $currentDefinition) {
            throw "Could not resolve the current agent definition for '$AgentId' - cannot build a full replacement body."
        }

        # Rebuild the full definition, preserving every field the agent already has,
        # and only add/overwrite "reasoning.effort".
        $definition = @{
            kind         = $currentDefinition.kind
            model        = $currentDefinition.model
            instructions = $currentDefinition.instructions
        }
        if ($null -ne $currentDefinition.temperature) { $definition.temperature = $currentDefinition.temperature }
        if ($null -ne $currentDefinition.top_p) { $definition.top_p = $currentDefinition.top_p }
        if ($currentDefinition.response_format) { $definition.response_format = $currentDefinition.response_format }
        if ($currentDefinition.tools) { $definition.tools = $currentDefinition.tools }
        if ($currentDefinition.tool_resources) { $definition.tool_resources = $currentDefinition.tool_resources }
        $definition.reasoning = @{ effort = $ReasoningEffortValue }

        $body = @{
            name       = $current.name
            definition = $definition
        }
        if ($current.description) { $body.description = $current.description }
        if ($current.metadata) { $body.metadata = $current.metadata }

        Invoke-MetroAIApiCall -Service 'agents' -Operation 'update' -Path $AgentId -Method 'Post' `
            -ContentType 'application/json' -Body $body | Out-Null
        Write-Host "Applied reasoning_effort=$ReasoningEffortValue to agent $AgentId" -ForegroundColor Gray
    }
    catch {
        Write-Warning "Could not apply reasoning_effort to agent $AgentId (non-fatal, agent will use model defaults): $($_.Exception.Message)"
    }
}

# Function to create or update an agent using Metro.AI
function Deploy-Agent {
    param(
        [string] $AgentName,
        [object] $AgentDefinition,
        [string] $ModelOverride = "",
        [bool] $UpdateMode = $false,
        [bool] $EnableMcp = $false
    )
    
    try {
        Write-Host "Processing agent: $AgentName" -ForegroundColor Yellow
        
        # Check if agent already exists
        # List returns simplified objects; fetch the full single-agent object
        # immediately so we have all properties (including real system-assigned IDs)
        $existingAgents = Get-MetroAIAgent
        $existingAgentSummary = $existingAgents | Where-Object { $_.name -eq $AgentName }
        $existingAgent = if ($existingAgentSummary) {
            $fullObj = Get-MetroAIAgent -AgentId $existingAgentSummary.id
            $fullObj
        }
        else { $null }
        
        $agentModel = if (-not [string]::IsNullOrEmpty($ModelOverride)) {
            $ModelOverride
        }
        elseif ($AgentDefinition.definition -and $AgentDefinition.definition.model) {
            $AgentDefinition.definition.model
        }
        elseif ($AgentDefinition.model) {
            $AgentDefinition.model
        }
        else {
            throw "No model found in agent definition. Provide -ModelDeploymentName."
        }

        $agentInstructions = if ($AgentDefinition.definition -and $AgentDefinition.definition.instructions) {
            $AgentDefinition.definition.instructions
        }
        elseif ($AgentDefinition.instructions) {
            $AgentDefinition.instructions
        }
        else { "" }

        $agentDescription = $AgentDefinition.description
        $mcpServersConfiguration = if ($EnableMcp) { Get-DefaultMcpServersConfiguration } else { @() }

        $agentReasoningEffort = if ($AgentDefinition.definition -and $AgentDefinition.definition.reasoning_effort) {
            $AgentDefinition.definition.reasoning_effort
        }
        elseif ($AgentDefinition.reasoning_effort) {
            $AgentDefinition.reasoning_effort
        }
        else {
            $ReasoningEffort
        }

        Write-Host "Using model: $agentModel" -ForegroundColor Gray
        Write-Host "Using reasoning_effort: $agentReasoningEffort" -ForegroundColor Gray
        if ($mcpServersConfiguration.Count -gt 0) {
            Write-Host "Enabling MCP server: $($MicrosoftLearnMcpServerLabel) -> $($MicrosoftLearnMcpUrl)" -ForegroundColor Gray
        }

        if ($existingAgent -and $UpdateMode) {
            $existingRealId = Get-RealAgentId $existingAgent
            Write-Host "Updating agent '$AgentName' (ID: $existingRealId) — clearing MCP servers then reapplying..." -ForegroundColor Magenta

            # Step 1: Strip all MCP server entries (preserves other tools, agent stays live)
            Set-MetroAIAgent -AgentId $existingAgent.id -RemoveMcp | Out-Null

            # Step 2: Push the updated instructions and model
            $updateParams = @{
                AgentId      = $existingAgent.id
                Name         = $AgentName
                Model        = $agentModel
                Instructions = $agentInstructions
            }
            if ($agentDescription) { $updateParams["Description"] = $agentDescription }
            Set-MetroAIAgent @updateParams | Out-Null

            # Step 3: Re-add MCP servers (appending to a now-empty MCP list = exactly one entry)
            if ($mcpServersConfiguration.Count -gt 0) {
                Set-MetroAIAgent -AgentId $existingAgent.id -McpServersConfiguration $mcpServersConfiguration | Out-Null
                Write-Host "MCP server(s) reapplied: $($mcpServersConfiguration | ForEach-Object { $_.server_label } | Join-String -Separator ', ')" -ForegroundColor Gray
            }

            # Step 4: Best-effort application of reasoning_effort (not supported
            # as a named cmdlet parameter - see Set-AgentReasoningEffort)
            Set-AgentReasoningEffort -AgentId $existingAgent.id -ReasoningEffortValue $agentReasoningEffort

            $fullUpdated = Get-MetroAIAgent -AgentId $existingAgent.id
            $realId = Get-RealAgentId $fullUpdated
            Write-Host "Agent $AgentName updated successfully. ID: $realId" -ForegroundColor Green
            $fullUpdated | Add-Member -NotePropertyName '_resolvedId' -NotePropertyValue $realId -Force
            return $fullUpdated
        }
        elseif ($existingAgent -and -not $UpdateMode) {
            $realId = Get-RealAgentId $existingAgent
            Write-Host "Agent $AgentName already exists (ID: $realId). Skipping creation. Use -UpdateExisting to update." -ForegroundColor Yellow
            $existingAgent | Add-Member -NotePropertyName '_resolvedId' -NotePropertyValue $realId -Force
            return $existingAgent
        }
        else {
            # Brand-new agent — create with full configuration in one call
            Write-Host "Creating new agent: $AgentName" -ForegroundColor Cyan

            $createParams = @{
                Name         = $AgentName
                Model        = $agentModel
                Instructions = $agentInstructions
            }
            if ($agentDescription) { $createParams["Description"] = $agentDescription }
            if ($mcpServersConfiguration.Count -gt 0) {
                $createParams["McpServersConfiguration"] = $mcpServersConfiguration
            }

            $newAgent = New-MetroAIAgent @createParams
            # Re-fetch full object to surface the real system-assigned ID
            $fullNew = Get-MetroAIAgent -AgentId $newAgent.id
            $realId = Get-RealAgentId $fullNew

            # Best-effort application of reasoning_effort (not supported as a
            # named cmdlet parameter - see Set-AgentReasoningEffort)
            Set-AgentReasoningEffort -AgentId $realId -ReasoningEffortValue $agentReasoningEffort
            $fullNew = Get-MetroAIAgent -AgentId $realId

            Write-Host "Full created agent properties: $($fullNew | ConvertTo-Json -Depth 3 -Compress)" -ForegroundColor DarkGray
            Write-Host "Agent $AgentName created successfully. ID: $realId" -ForegroundColor Green
            $fullNew | Add-Member -NotePropertyName '_resolvedId' -NotePropertyValue $realId -Force
            return $fullNew
        }
    }
    catch {
        Write-Error "Failed to deploy agent $AgentName : $($_.Exception.Message)"
        throw
    }
}

# Function to build instructions from markdown if needed
function Build-InstructionsIfNeeded {
    param(
        [string] $AgentType
    )
    
    $instructionsPath = Join-Path $PSScriptRoot "../agentInstructions"
    $buildScript = Join-Path $PSScriptRoot "build-instructions.ps1"
    $outputFile = Join-Path $instructionsPath "${AgentType}PolicyAgentInstructions.json"
    
    # Check if build script exists and output file is missing or older than source files
    if (Test-Path $buildScript) {
        $markdownFile = Join-Path $instructionsPath "${AgentType}PolicyAgent.md"
        $templateFile = Join-Path $instructionsPath "templates/${AgentType}PolicyAgent.template.json"

        
        $shouldBuild = $false
        
        if (-not (Test-Path $outputFile)) {
            Write-Host "Output file missing, building instructions for $AgentType agent..." -ForegroundColor Yellow
            $shouldBuild = $true
        }
        elseif ((Test-Path $markdownFile) -and ((Get-Item $markdownFile).LastWriteTime -gt (Get-Item $outputFile).LastWriteTime)) {
            Write-Host "Markdown file newer than output, rebuilding instructions for $AgentType agent..." -ForegroundColor Yellow
            $shouldBuild = $true
        }
        elseif ((Test-Path $templateFile) -and ((Get-Item $templateFile).LastWriteTime -gt (Get-Item $outputFile).LastWriteTime)) {
            Write-Host "Template file newer than output, rebuilding instructions for $AgentType agent..." -ForegroundColor Yellow
            $shouldBuild = $true
        }
        
        if ($shouldBuild) {
            try {
                & $buildScript -AgentType $AgentType
                Write-Host "Successfully built instructions for $AgentType agent" -ForegroundColor Green
            }
            catch {
                Write-Warning "Failed to build instructions for $AgentType agent: $($_.Exception.Message)"
                Write-Host "Continuing with existing JSON file if available..." -ForegroundColor Yellow
            }
        }
    }
}

# Function to load agent definition from JSON file or use parameter
function Get-AgentInstructions {
    param(
        [string] $InstructionParameter,
        [string] $JsonFilePath,
        [string] $AgentType = ""
    )
    
    # Try to build instructions from markdown if needed
    if (-not [string]::IsNullOrEmpty($AgentType)) {
        Build-InstructionsIfNeeded -AgentType $AgentType
    }
    
    if (-not [string]::IsNullOrEmpty($InstructionParameter)) {
        # If instructions provided as parameter, use them
        try {
            $jsonObj = $InstructionParameter | ConvertFrom-Json
            return $jsonObj
        }
        catch {
            # If not JSON, create minimal agent definition
            return @{
                instructions = $InstructionParameter
            }
        }
    }
    elseif (Test-Path $JsonFilePath) {
        # Load from JSON file
        try {
            $jsonContent = Get-Content $JsonFilePath -Raw | ConvertFrom-Json
            return $jsonContent
        }
        catch {
            Write-Error "Failed to load agent definition from $JsonFilePath : $($_.Exception.Message)"
            throw
        }
    }
    else {
        Write-Error "No agent definition provided and file not found: $JsonFilePath"
        throw
    }
}

# Main deployment logic
try {
    Write-Host "Starting specialized agent deployment..." -ForegroundColor Green
    Write-Host "Project Endpoint: $ProjectEndpoint" -ForegroundColor Cyan
    Write-Host "Model Deployment: $ModelDeploymentName" -ForegroundColor Cyan
    Write-Host "Agent Types: $AgentTypes" -ForegroundColor Cyan
    Write-Host "Microsoft Learn MCP: InstructionsAgent only (enabled: $(-not $DisableMicrosoftLearnMcp))" -ForegroundColor Cyan
    Write-Host "Update Mode: $UpdateExisting" -ForegroundColor Cyan
    
    # Parse agent types
    $agentTypesArray = $AgentTypes -split "," | ForEach-Object { $_.Trim() }
    
    $deployedAgents = @{}
    
    # Deploy each requested agent type
    foreach ($agentType in $agentTypesArray) {
        switch ($agentType.ToLower()) {
            "deny" {
                $agentDefinition = Get-AgentInstructions -InstructionParameter $DenyInstructions -JsonFilePath (Join-Path $PSScriptRoot "../agentInstructions/denyPolicyAgentInstructions.json") -AgentType "deny"
                $agent = Deploy-Agent -AgentName "DenyPolicyAgent" -AgentDefinition $agentDefinition -ModelOverride $ModelDeploymentName -UpdateMode $UpdateExisting -EnableMcp $false
                $deployedAgents["deny"] = $agent
            }
            "audit" {
                $agentDefinition = Get-AgentInstructions -InstructionParameter $AuditInstructions -JsonFilePath (Join-Path $PSScriptRoot "../agentInstructions/auditPolicyAgentInstructions.json") -AgentType "audit"
                $agent = Deploy-Agent -AgentName "AuditPolicyAgent" -AgentDefinition $agentDefinition -ModelOverride $ModelDeploymentName -UpdateMode $UpdateExisting -EnableMcp $false
                $deployedAgents["audit"] = $agent
            }
            "deployifnotexists" {
                $agentDefinition = Get-AgentInstructions -InstructionParameter $DineInstructions -JsonFilePath (Join-Path $PSScriptRoot "../agentInstructions/dinePolicyAgentInstructions.json") -AgentType "dine"
                $agent = Deploy-Agent -AgentName "DinePolicyAgent" -AgentDefinition $agentDefinition -ModelOverride $ModelDeploymentName -UpdateMode $UpdateExisting -EnableMcp $false
                $deployedAgents["deployIfNotExists"] = $agent
            }
            "modify" {
                $agentDefinition = Get-AgentInstructions -InstructionParameter $ModifyInstructions -JsonFilePath (Join-Path $PSScriptRoot "../agentInstructions/modifyPolicyAgentInstructions.json") -AgentType "modify"
                $agent = Deploy-Agent -AgentName "ModifyPolicyAgent" -AgentDefinition $agentDefinition -ModelOverride $ModelDeploymentName -UpdateMode $UpdateExisting -EnableMcp $false
                $deployedAgents["modify"] = $agent
            }
            "instructionsagent" {
                $agentDefinition = Get-AgentInstructions -InstructionParameter $MaintenanceInstructions -JsonFilePath (Join-Path $PSScriptRoot "../agentInstructions/instructionsAgentInstructions.json") -AgentType "instructionsAgent"
                $agent = Deploy-Agent -AgentName "InstructionsAgent" -AgentDefinition $agentDefinition -ModelOverride $ModelDeploymentName -UpdateMode $UpdateExisting -EnableMcp $true
                $deployedAgents["instructionsAgent"] = $agent
            }
            default {
                Write-Warning "Unknown agent type: $agentType"
            }
        }
    }
    
    # Output results for GitHub Actions
    Write-Host "`n=== Deployment Summary ==="
    foreach ($agentType in $deployedAgents.Keys) {
        $agent = $deployedAgents[$agentType]
        $resolvedId = if ($agent._resolvedId) { $agent._resolvedId } else { $agent.id }
        Write-Host "$agentType Agent: $($agent.name) (ID: $resolvedId)"
    }
    
    # Output for GitHub Actions environment variables
    Write-Host "`n=== GitHub Actions Outputs ==="
    if ($deployedAgents.ContainsKey("deny")) {
        $id = if ($deployedAgents["deny"]._resolvedId) { $deployedAgents["deny"]._resolvedId } else { $deployedAgents["deny"].id }
        Write-Host "DENY_AGENT_ID=$id"
    }
    if ($deployedAgents.ContainsKey("audit")) {
        $id = if ($deployedAgents["audit"]._resolvedId) { $deployedAgents["audit"]._resolvedId } else { $deployedAgents["audit"].id }
        Write-Host "AUDIT_AGENT_ID=$id"
    }
    if ($deployedAgents.ContainsKey("deployIfNotExists")) {
        $id = if ($deployedAgents["deployIfNotExists"]._resolvedId) { $deployedAgents["deployIfNotExists"]._resolvedId } else { $deployedAgents["deployIfNotExists"].id }
        Write-Host "DINE_AGENT_ID=$id"
    }
    if ($deployedAgents.ContainsKey("modify")) {
        $id = if ($deployedAgents["modify"]._resolvedId) { $deployedAgents["modify"]._resolvedId } else { $deployedAgents["modify"].id }
        Write-Host "MODIFY_AGENT_ID=$id"
    }
    if ($deployedAgents.ContainsKey("instructionsAgent")) {
        $id = if ($deployedAgents["instructionsAgent"]._resolvedId) { $deployedAgents["instructionsAgent"]._resolvedId } else { $deployedAgents["instructionsAgent"].id }
        Write-Host "INSTRUCTIONS_AGENT_ID=$id"
    }
    
    Write-Host "`nSpecialized agent deployment completed successfully!"
}
catch {
    Write-Error "Deployment failed: $($_.Exception.Message)"
    exit 1
}