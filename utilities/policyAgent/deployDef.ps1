# Paths for params and deployment inputs
param (
    [string]$PolicyDefinitionFilePath = "./policyDefinitions/allowedLocations.json",
    [string]$BicepFilePath = "./utilities/policyAgent/policyDef.bicep",
    [string]$ParameterFilePath = "./utilities/policyAgent/policyDef.parameters.json",
    [string]$DeploymentName = "YourDeploymentName",
    [string]$Location = "eastus"
)

# Step 1: Read policy definition JSON and create parameter file
$policyDefinition = Get-Content -Path $policyDefinitionFilePath -Raw | ConvertFrom-Json

$parameterContent = @{
    "$schema" = "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#"
    "contentVersion" = "1.0.0.0"
    "parameters" = @{
        "policyDefinition" = @{
            "value" = $policyDefinition
        }
    }
}

$parameterContent | ConvertTo-Json -Depth 10 | Set-Content -Path $parameterFilePath

# Step 2: Deploy the compiled ARM template with parameters
New-AzSubscriptionDeployment -Location $Location `
                             -Name $DeploymentName `
                             -TemplateFile $BicepFilePath `
                             -TemplateParameterFile $ParameterFilePath `
                             -Verbose