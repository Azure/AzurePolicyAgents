<#
.SYNOPSIS
    Creates, deletes and sweeps ephemeral Azure AI Foundry policy test agents.

.DESCRIPTION
    Each policy in a pull request is tested by its own short-lived Foundry agent cloned from the
    long-lived specialised agent for that effect type. This script manages the lifecycle of those
    ephemeral agents so that concurrent per-policy test jobs never share an agent and never clash
    on naming. See docs/Scripts-Reference.md for the full lifecycle and naming scheme.

.PARAMETER Action
    Create clones a base agent into a new uniquely named agent.
    Delete removes a single ephemeral agent by id or name.
    Sweep removes every agent whose name starts with a given prefix.

.PARAMETER Endpoint
    Azure AI Foundry project endpoint.

.PARAMETER BaseAgentId
    Identifier of the long-lived specialised agent to clone. Required for Create.

.PARAMETER AgentName
    Name assigned to the ephemeral agent. Required for Create, optional for Delete.

.PARAMETER AgentId
    Identifier of the ephemeral agent to remove. Required for Delete when AgentName is not supplied.

.PARAMETER NamePrefix
    Name prefix used to select ephemeral agents for removal. Required for Sweep.

.PARAMETER OutputName
    GitHub Actions output key that receives the created agent id. Defaults to agent-id.

.PARAMETER MaxAttempts
    Number of attempts for each Foundry call before giving up.
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Create', 'Delete', 'Sweep')]
    [string]$Action,

    [Parameter(Mandatory = $true)]
    [string]$Endpoint,

    [Parameter()]
    [string]$BaseAgentId,

    [Parameter()]
    [string]$AgentName,

    [Parameter()]
    [string]$AgentId,

    [Parameter()]
    [string]$NamePrefix,

    [Parameter()]
    [string]$OutputName = 'agent-id',

    [Parameter()]
    [int]$MaxAttempts = 4
)

$WarningPreference = 'SilentlyContinue'

function Install-MetroAIIfMissing {
    if (Get-Module -ListAvailable -Name Metro.AI) {
        Write-Host "Metro.AI module already available."
        return
    }
    Write-Host "Installing Metro.AI PowerShell module..."
    Install-PSResource -Name Metro.AI -TrustRepository -Scope CurrentUser -ErrorAction SilentlyContinue
    if (-not (Get-Module -ListAvailable -Name Metro.AI)) {
        Install-Module -Name Metro.AI -Force -AllowClobber -Scope CurrentUser
    }
}

function Set-CIOutput {
    param([string]$Name, [string]$Value)
    if ($env:GITHUB_OUTPUT) {
        "$Name=$Value" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
    }
}

# Retries a Foundry call to absorb transient throttling and propagation delays.
function Invoke-WithRetry {
    param(
        [scriptblock]$ScriptBlock,
        [string]$Description,
        [int]$Attempts
    )

    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        try {
            return & $ScriptBlock
        }
        catch {
            if ($attempt -eq $Attempts) { throw }
            $delay = [Math]::Pow(2, $attempt)
            Write-Host "$Description failed (attempt $attempt of $Attempts): $($_.Exception.Message). Retrying in $delay seconds..."
            Start-Sleep -Seconds $delay
        }
    }
}

# Foundry Agents preview returns the definition under versions.latest.definition for existing agents.
function Get-AgentDefinition {
    param([object]$Agent)
    if ($Agent.versions -and $Agent.versions.latest -and $Agent.versions.latest.definition) {
        return $Agent.versions.latest.definition
    }
    if ($Agent.definition) { return $Agent.definition }
    return $null
}

# Extracts MCP server tool configuration from a base agent definition so clones keep the same tools.
function Get-McpServersFromDefinition {
    param([object]$Definition)

    $servers = @()
    foreach ($tool in @($Definition.tools)) {
        if ($tool.type -ne 'mcp') { continue }
        $server = @{
            server_label = $tool.server_label
            server_url   = $tool.server_url
        }
        if ($tool.allowed_tools) { $server.allowed_tools = @($tool.allowed_tools) }
        if ($server.server_label -and $server.server_url) { $servers += $server }
    }
    return $servers
}

# reasoning_effort requires a full replacement update body. Non-fatal if it fails.
function Set-AgentReasoningEffort {
    param([string]$TargetAgentId, [string]$EffortValue)

    if ([string]::IsNullOrWhiteSpace($EffortValue)) { return }

    try {
        $current = Get-MetroAIAgent -AgentId $TargetAgentId
        $definition = Get-AgentDefinition -Agent $current
        if (-not $definition) { throw "Could not resolve the agent definition for '$TargetAgentId'." }

        $body = @{
            name       = $current.name
            definition = @{
                kind         = $definition.kind
                model        = $definition.model
                instructions = $definition.instructions
                reasoning    = @{ effort = $EffortValue }
            }
        }
        if ($definition.response_format) { $body.definition.response_format = $definition.response_format }
        if ($definition.tools) { $body.definition.tools = $definition.tools }
        if ($definition.tool_resources) { $body.definition.tool_resources = $definition.tool_resources }
        if ($current.description) { $body.description = $current.description }

        Invoke-MetroAIApiCall -Service 'agents' -Operation 'update' -Path $TargetAgentId -Method 'Post' `
            -ContentType 'application/json' -Body $body | Out-Null
        Write-Host "Applied reasoning_effort=$EffortValue to $TargetAgentId"
    }
    catch {
        Write-Host "Could not apply reasoning_effort to $TargetAgentId (non-fatal): $($_.Exception.Message)"
    }
}

function Remove-EphemeralAgent {
    param([string]$TargetAgentId)

    try {
        Invoke-WithRetry -Description "Delete agent $TargetAgentId" -Attempts $MaxAttempts -ScriptBlock {
            Remove-MetroAIAgent -AgentId $TargetAgentId -Confirm:$false -ErrorAction Stop | Out-Null
        }
        Write-Host "Deleted ephemeral agent: $TargetAgentId"
        return $true
    }
    catch {
        Write-Host "Failed to delete ephemeral agent '$TargetAgentId': $($_.Exception.Message)"
        return $false
    }
}

Install-MetroAIIfMissing
Set-MetroAIContext -Endpoint $Endpoint -ApiType Agent -SkipValidation

switch ($Action) {
    'Create' {
        if ([string]::IsNullOrWhiteSpace($BaseAgentId)) { throw "BaseAgentId is required for Create." }
        if ([string]::IsNullOrWhiteSpace($AgentName)) { throw "AgentName is required for Create." }

        Write-Host "Cloning base agent '$BaseAgentId' into ephemeral agent '$AgentName'..."

        $baseAgent = Invoke-WithRetry -Description "Read base agent $BaseAgentId" -Attempts $MaxAttempts -ScriptBlock {
            Get-MetroAIAgent -AgentId $BaseAgentId -ErrorAction Stop
        }
        $baseDefinition = Get-AgentDefinition -Agent $baseAgent
        if (-not $baseDefinition) { throw "Base agent '$BaseAgentId' returned no definition to clone." }
        if (-not $baseDefinition.model) { throw "Base agent '$BaseAgentId' has no model to clone." }

        $createParams = @{
            Name         = $AgentName
            Model        = $baseDefinition.model
            Instructions = $baseDefinition.instructions
            Description  = "Ephemeral clone of $BaseAgentId for a single policy test run."
        }
        $mcpServers = Get-McpServersFromDefinition -Definition $baseDefinition
        if ($mcpServers.Count -gt 0) {
            $createParams['McpServersConfiguration'] = $mcpServers
            Write-Host "Cloning MCP server(s): $(($mcpServers | ForEach-Object { $_.server_label }) -join ', ')"
        }

        $created = Invoke-WithRetry -Description "Create agent $AgentName" -Attempts $MaxAttempts -ScriptBlock {
            New-MetroAIAgent @createParams -ErrorAction Stop
        }

        # In the Foundry Agents preview the root id is the addressable identifier and equals the name.
        $createdId = if ($created.id) { $created.id } else { $AgentName }
        try {
            $full = Get-MetroAIAgent -AgentId $createdId -ErrorAction Stop
            if ($full.id) { $createdId = $full.id }
        }
        catch {
            Write-Host "Could not re-read created agent '$createdId' (continuing): $($_.Exception.Message)"
        }

        $effort = if ($baseDefinition.reasoning -and $baseDefinition.reasoning.effort) {
            $baseDefinition.reasoning.effort
        }
        elseif ($baseDefinition.reasoning_effort) {
            $baseDefinition.reasoning_effort
        }
        else { $null }
        Set-AgentReasoningEffort -TargetAgentId $createdId -EffortValue $effort

        Write-Host "Ephemeral agent ready. ID: $createdId"
        Set-CIOutput -Name $OutputName -Value $createdId
    }

    'Delete' {
        $target = if (-not [string]::IsNullOrWhiteSpace($AgentId)) { $AgentId } else { $AgentName }
        if ([string]::IsNullOrWhiteSpace($target)) {
            Write-Host "No AgentId or AgentName supplied - nothing to delete."
            break
        }
        Remove-EphemeralAgent -TargetAgentId $target | Out-Null
    }

    'Sweep' {
        if ([string]::IsNullOrWhiteSpace($NamePrefix)) { throw "NamePrefix is required for Sweep." }

        Write-Host "Sweeping ephemeral agents with name prefix: $NamePrefix"
        $agents = @()
        try {
            $agents = @(Get-MetroAIAgent -ErrorAction Stop)
        }
        catch {
            Write-Host "Could not list agents for sweep: $($_.Exception.Message)"
            break
        }

        $stale = @($agents | Where-Object { $_.name -and $_.name.StartsWith($NamePrefix) })
        if ($stale.Count -eq 0) {
            Write-Host "No ephemeral agents left to sweep."
            break
        }

        Write-Host "Found $($stale.Count) ephemeral agent(s) to remove."
        $removed = 0
        foreach ($agent in $stale) {
            $targetId = if ($agent.id) { $agent.id } else { $agent.name }
            if (Remove-EphemeralAgent -TargetAgentId $targetId) { $removed++ }
        }
        Write-Host "Sweep complete. Removed $removed of $($stale.Count) ephemeral agent(s)."
    }
}
