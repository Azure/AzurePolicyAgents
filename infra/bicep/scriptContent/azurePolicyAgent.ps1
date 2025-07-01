# Installing Metro-AI Powershell module for declarative managemnet of Azure AI Agent

# Parameter help description
param (
	[string]$AIAgentEndpoint,
    [string]$ModelDeploymentName
)

Install-Module -Name Metro.AI -Force

# Setting Metro AI agent context
Set-MetroAIContext -Endpoint $AIAgentEndpoint -ApiType Agent

$AgentDefinition = Invoke-RestMethod -uri "https://gist.githubusercontent.com/krnese/c4ee2c9db19cdd09028d3e7da4ff8141/raw/c7e3b78cb62d22b7779f2200fcae2a0633a32b4c/azurePolicyAgent.json" 

try {
    $NewAgent = New-MetroAIAgent -Name "Azure Policy Agent" -InputObject $AgentDefinition
    Write-Host "Azure Policy Agent has been created successfully with the ID: $($NewAgent.id)"
} catch {
    Write-Host "Failed to create agent. Error: $($_.Exception.Message)"
    Write-Host "Agent definition: $($AgentDefinition | ConvertTo-Json -Depth 3)"
    throw
}

# Create outputs for the deployment script to capture
$DeploymentScriptOutputs = @{
    agentId = $NewAgent.id
    agentName = $NewAgent.name ?? "Azure Policy Agent"
    status = "Success"
    timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
}

# Write the outputs to the deployment script outputs file
# This is how deployment scripts can return values to the ARM template
$OutputsJson = $DeploymentScriptOutputs | ConvertTo-Json -Compress
Write-Host "Setting deployment script outputs: $OutputsJson"

# Set the outputs using the AZ_SCRIPTS_OUTPUT_PATH environment variable
$OutputPath = $env:AZ_SCRIPTS_OUTPUT_PATH
if ($OutputPath) {
    Write-Host "Writing outputs to: $OutputPath"
    $DeploymentScriptOutputs | ConvertTo-Json | Out-File -FilePath $OutputPath -Encoding utf8
} else {
    Write-Warning "AZ_SCRIPTS_OUTPUT_PATH not found. Outputs will not be captured by the deployment script."
}

Write-Output "Azure Policy Agent has been created successfully with the ID: $($NewAgent.id)"

