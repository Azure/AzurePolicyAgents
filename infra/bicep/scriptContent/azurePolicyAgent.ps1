# Starting the Azure Policy Agent deployment using the provided Bicep template
# Remember to modify the agentsSetup.bicepparam file to match your environment with unique naming for the project endpoint

# Login to Azure and set the subscription context

Connect-AzAccount

# Set the subscription ID - replace with your actual subscription ID

$SubscriptionId = "fcbf5e04-699b-436a-88ef-d72081f7ad52"
Set-AzContext -SubscriptionId $SubscriptionId

$AzureDeploymentLocation = "swedencentral"
$AzurePolicyAgentDeployment = New-AzSubscriptionDeployment `
                            -Name "AzurePolicyAgentDeployment" `
                            -Location $AzureDeploymentLocation  `
                            -TemplateFile './infra/bicep/agentsSetup.bicep' `
                            -TemplateParameterFile './infra/bicep/agentsSetup.bicepparam' `
                            -Verbose

# Installing Metro-AI Powershell module for declarative management of Azure AI Agent (and to bypass current limmitations of deploymentScripts)

Install-Module -Name Metro.AI -Force

# Setting Metro AI agent context using the deployment outputs

Set-MetroAIContext -Endpoint $AzurePolicyAgentDeployment.Outputs.agentEndpoint.value -ApiType Agent

# Creating the Azure Policy Agent using the provided JSON definition

$AgentDefinition = Invoke-RestMethod -uri "https://gist.githubusercontent.com/krnese/c4ee2c9db19cdd09028d3e7da4ff8141/raw/c7e3b78cb62d22b7779f2200fcae2a0633a32b4c/azurePolicyAgent.json" 

try {
    $NewAgent = New-MetroAIAgent -Name "Azure Policy Agent" -InputObject $AgentDefinition
    Write-Host "Azure Policy Agent has been created successfully with the ID: $($NewAgent.id)"
} catch {
    Write-Host "Failed to create agent. Error: $($_.Exception.Message)"
    Write-Host "Agent definition: $($AgentDefinition | ConvertTo-Json -Depth 3)"
    throw
}