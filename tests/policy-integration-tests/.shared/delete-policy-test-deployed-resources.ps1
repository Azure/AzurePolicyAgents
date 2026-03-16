#Requires -Modules Az.Resources
#Requires -Version 7.0

<#
=======================================================================
AUTHOR: Tao Yang
DATE: 24/06/2024
NAME: delete-policy-test-deployed-resources.ps1
VERSION: 1.0.0
COMMENT: - Delete resources deployed by policy integration tests
        - Inspired by the resource removal script from the AVM project
=======================================================================
#>
#variables
$deploymentId = $script:bicepDeploymentId
$deploymentTarget = $script:deploymentTarget
$deploymentScope = $script:bicepDeploymentScope
$additionalResourceGroups = $script:LocalConfig_additionalResourceGroups -eq '$(additionalResourceGroups)' ? $null : $script:LocalConfig_additionalResourceGroups
$removeTestResourceGroup = $script:LocalConfig_removeTestResourceGroup
$testSubscriptionId = $script:testSubscriptionId
$testResourceGroup = $script:LocalConfig_testResourceGroup

Write-Verbose "Deployment Id: $deploymentId" -verbose
Write-Verbose "Deployment Target: $deploymentTarget" -verbose
Write-Verbose "Deployment Scope: $deploymentScope" -verbose
Write-Verbose "Test Subscription Id: $testSubscriptionId" -verbose
Write-Verbose "Test Resource Group: $testResourceGroup" -verbose
Write-Verbose "Remove Test Resource Group: $removeTestResourceGroup" -verbose

If ($null -ne $additionalResourceGroups) {
  #Convert from Json to array
  $additionalResourceGroups = $additionalResourceGroups | ConvertFrom-Json
  Write-Verbose "Additional Resource Groups:" -verbose
  foreach ($resourceGroup in $additionalResourceGroups) {
    Write-Verbose "  - $resourceGroup" -verbose
  }
} else {
  Write-Verbose "No additional resource groups found from deployment output." -verbose
}

$resourceGroupApiVersion = '2021-04-01'
# The removal sequence is a general order-recommendation
$removalSequence = @(
  'Microsoft.Authorization/locks',
  'Microsoft.Authorization/roleAssignments',
  'Microsoft.Insights/diagnosticSettings',
  'Microsoft.Network/privateEndpoints/privateDnsZoneGroups',
  'Microsoft.Network/privateEndpoints',
  'Microsoft.Network/azureFirewalls',
  'Microsoft.Network/virtualHubs',
  'Microsoft.Network/virtualWans',
  'Microsoft.OperationsManagement/solutions',
  'Microsoft.OperationalInsights/workspaces/linkedServices',
  'Microsoft.OperationalInsights/workspaces',
  'Microsoft.KeyVault/vaults',
  'Microsoft.Authorization/policyExemptions',
  'Microsoft.Authorization/policyAssignments',
  'Microsoft.Authorization/policySetDefinitions',
  'Microsoft.Authorization/policyDefinitions',
  'Microsoft.Sql/managedInstances',
  'Microsoft.MachineLearningServices/workspaces',
  'Microsoft.Resources/resourceGroups',
  'Microsoft.Compute/virtualMachines'
)

#Load helper functions
$helperFunctionScriptPath = join-path $PSScriptRoot 'helper-functions.ps1'
$removalHelperScriptPath = join-path $PSScriptRoot 'resource-removal-helper.ps1'

. $helperFunctionScriptPath
. $removalHelperScriptPath

if ($deploymentId.length -gt 0) {
  Write-Verbose "Removing resources deployed by deployment id '$deploymentId'..." -verbose
  try {
    removeDeployment -deploymentId $deploymentId -removalSequence $removalSequence
  } catch {
    Write-Verbose "Failed to remove resources deployed by deployment id '$deploymentId'. Error: $_" -verbose
  }

} else {
  Write-Verbose "Deployment Id is not provided. Nothing to be removed." -Verbose
}


If ($removeTestResourceGroup -eq 'true') {
  Write-Verbose "The Local Configuration explicitly specified to remove the test resource group." -verbose
  if ($deploymentScope -ieq 'resourceGroup') {
    if ($null -ne $deploymentTarget) {
      Write-Verbose "Removing test resource group '$deploymentTarget'..." -verbose
      removeAzureResource -resourceId $deploymentTarget -apiVersion $resourceGroupApiVersion
    } elseif ($null -ne $testResourceGroup) {
      $resourceGroupId = '/subscriptions/{0}/resourceGroups/{1}' -f $testSubscriptionId, $testResourceGroup
      #check if the resource group exists
      $resourceGroup = getResourceViaARMAPI -resourceId $resourceGroupId -apiVersion $resourceGroupApiVersion -errorAction SilentlyContinue
      if ($null -eq $resourceGroup) {
        Write-Verbose "The test resource group '$resourceGroupId' does not exist." -verbose
      } else {
        Write-Verbose "Removing test resource group '$resourceGroupId'..." -verbose
        removeAzureResource -resourceId $resourceGroupId -apiVersion $resourceGroupApiVersion
      }
    } else {
      Write-Verbose "No test resource group found to remove." -verbose
    }
  } else {
    Write-Verbose "The Deployment target '$deploymentTarget' is scoped at '$deploymentScope' level. It cannot be removed." -verbose
  }
} else {
  Write-Verbose "The Local Configuration did not explicitly specify to delete the test resource group." -verbose
}

#Delete additional resource groups if specified
if ($null -ne $additionalResourceGroups) {
  Write-Verbose "Removing additional resource groups..." -verbose
  foreach ($resourceGroupId in $additionalResourceGroups) {
    #check if the resource group exists
    $resourceGroup = getResourceViaARMAPI -resourceId $resourceGroupId -apiVersion $resourceGroupApiVersion -errorAction SilentlyContinue
    if ($null -eq $resourceGroup) {
      Write-Verbose "  - The additional resource group '$resourceGroupId' does not exist." -verbose
    } else {
      Write-Verbose "  - Removing additional resource group '$resourceGroupId'..." -verbose
      removeAzureResource -resourceId $resourceGroupId -apiVersion $resourceGroupApiVersion
    }
  }
} else {
  Write-Verbose "No additional resource groups found to remove." -verbose
}
