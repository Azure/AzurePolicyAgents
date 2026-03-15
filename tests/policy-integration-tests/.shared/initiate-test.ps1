#Requires -Modules Az.Resources
#Requires -Version 7.0


<#
=======================================================
AUTHOR: Tao Yang
DATE: 14/03/2026
NAME: initiate-test.ps1
VERSION: 1.0.0
COMMENT: Initiate test for policy integration testing
=======================================================
#>

[CmdletBinding()]
Param (

  [Parameter(Mandatory = $true, HelpMessage = 'Specify the global configuration file path.')]
  [string]$globalConfigFilePath,

  [Parameter(Mandatory = $true, HelpMessage = 'Specify the test directory.')]
  [string]$TestDirectory
)

#load helper functions
$helperFunctionScriptPath = join-path $PSScriptRoot 'helper-functions.ps1'
#load helper
. $helperFunctionScriptPath
$globalConfigVariableNamePrefix = 'GlobalConfig_'
$localConfigVariableNamePrefix = 'LocalConfig_'
#Generate Azure oauth token
#check if it's signed in to Azure using Azure PowerShell
if (Get-AzContext) {
  $script:token = ConvertFrom-SecureString (Get-AzAccessToken -ResourceUrl 'https://management.azure.com/').Token -AsPlainText
} elseif ($(az account show 2>&1) ) {
  $script:token = (az account get-access-token --resource https://management.azure.com/ --query accessToken -o tsv)
}

If (-not $script:token) {
  throw "Failed to acquire Azure access token. Please sign in to Azure using Azure PowerShell if you are using Bicep templates or Azure CLI if you are using Terraform."
}
#load Global config
$globalTestConfig = getTestConfig -TestConfigFilePath $globalConfigFilePath

#create an variable for each config from global config for later use in test scripts
Write-Output "Loading global config from file: $globalConfigFilePath"
foreach ($config in $globalTestConfig.GetEnumerator()) {
  $name = $globalConfigVariableNamePrefix + $config.Key
  # Set variable
  Set-Variable -Name $name -Value $config.Value -Scope Script
}

#load Local config
$testLocalConfigFileName = $script:GlobalConfig_testLocalConfigFileName
$localConfigFilePath = Join-Path $TestDirectory $testLocalConfigFileName
$localTestConfig = getTestConfig -TestConfigFilePath $localConfigFilePath

#create an variable for each config from local config for later use in test scripts
Write-Output "Loading local config from file: $localConfigFilePath"
foreach ($config in $localTestConfig.GetEnumerator()) {

  $name = $localConfigVariableNamePrefix + $config.Key
  # Set variable
  Set-Variable -Name $name -Value $config.Value -Scope Script
}
#Tags for resource group
if (!$script:LocalConfig_tagsForResourceGroup) {
  $script:LocalConfig_tagsForResourceGroup = $false
}

#Additional calculated variables
$script:whatIfComplyBicepTemplatePath = Join-Path $TestDirectory $script:GlobalConfig_whatIfComplyBicepTemplateName
$script:whatIfViolateBicepTemplatePath = Join-Path $TestDirectory $script:GlobalConfig_whatIfViolateBicepTemplateName
$script:terraformBackendStateFileDirectory = Join-Path $TestDirectory 'tf-state'
$script:terraformViolateDirectoryPath = Join-Path $TestDirectory $script:GlobalConfig_terraformViolateDirectoryName
$script:terraformComplyDirectoryPath = Join-Path $TestDirectory $script:GlobalConfig_terraformComplyDirectoryName
$script:testTerraformDirectoryPath = join-path $TestDirectory $script:GlobalConfig_testTerraformDirectoryName
$script:testTitle = "$script:LocalConfig_testName Configuration Test"
$script:contextTitle = "$script:LocalConfig_testName Configuration"
$script:testSuiteName = $script:LocalConfig_testName
$script:outputFilePath = "$script:GlobalConfig_testOutputFilePrefix-$script:LocalConfig_testName.xml"

$testSubscriptionName = $script:LocalConfig_testSubscription

Write-Verbose "Test Subscription Name: $testSubscriptionName" -Verbose
$script:testSubscriptionId = $script:GlobalConfig_subscriptions.$testSubscriptionName.id
Write-Verbose "Test Subscription ID: $script:testSubscriptionId" -Verbose

#make sure the test resource group is created if the test resource group is specified and the test is expected to have deny policies
if ($script:LocalConfig_testDenyPolicies -and $script:LocalConfig_testResourceGroup.length -gt 0) {
  Write-Output "Since deny policies are tested, ensuring the resource group '$script:LocalConfig_testResourceGroup' exists for testing."
  #make sure the resource group exists
  $rgParams = @{
    subscriptionId    = $script:testSubscriptionId
    resourceGroupName = $script:LocalConfig_testResourceGroup
    location          = $script:LocalConfig_location
    tags              = $script:LocalConfig_tagsForResourceGroup ? $tags : $null
    apiVersion        = $script:GlobalConfig_resourceGroupApiVersion
  }
  #set the deployment target to the resource group for later use in tests
  $script:deploymentTarget = createResourceGroupIfNotExist @rgParams
} else {
  $script:deploymentTarget = $null
}

#Set deployment related outputs to null first
$script:bicepDeploymentOutputs = $null
$script:bicepProvisioningState = $null
$script:bicepDeploymentName = $null
$script:bicepDeploymentId = $null
$script:deploymentTarget = $null
$script:bicepDeploymentScope = $null
$script:terraformDeploymentOutputs = $null
$script:terraformProvisioningState = $null

#deploy test bicep template if exists
if (test-path $(join-path $TestDirectory $script:GlobalConfig_testBicepTemplateName)) {
  Write-Output "Test Bicep template found: $script:GlobalConfig_testBicepTemplateName. Proceeding with deployment."

  . (Join-Path $PSScriptRoot 'deploy-policy-test-bicep-template.ps1') -TestPath $TestDirectory -BicepFileName $script:GlobalConfig_testBicepTemplateName

  #capture deployment results
  $deploymentProvisioningState = $script:bicepProvisioningState

  #check deployment provisioning state. If deployment failed, skip tests since the required resources for testing won't be provisioned.
  If ($deploymentProvisioningState -ne 'Succeeded') {
    Write-Output "Deployment provisioning state is '$deploymentProvisioningState'. Tests will be skipped."
    exit 1
  }
} else {
  Write-Output "Test Bicep template not found: $script:GlobalConfig_testBicepTemplateName. Proceeding without deployment."
}

#deploy Terraform template if exist

if (test-path $script:testTerraformDirectoryPath) {
  Write-Output "Test Terraform template found: $script:GlobalConfig_testTerraformDirectoryName. Proceeding with deployment."
  if (!$(az account show 2>&1) ) {
    Throw "Azure CLI is not logged in. Please log in to Azure using Azure CLI to deploy Terraform template."
    Exit 1
  }
  $tfDeploymentParams = @{
    terraformPath               = $script:testTerraformDirectoryPath
    tfBackendConfigFileName     = $script:GlobalConfig_testTerraformBackendConfigFileName
    tfBackendStateFileDirectory = $script:terraformBackendStateFileDirectory
    tfStateFileName             = $script:GlobalConfig_testTerraformStateFileName
    tfAction                    = 'apply'
    uninitializeTerraform       = $false
  }
  . (Join-Path $PSScriptRoot 'deploy-destroy-policy-test-terraform-template.ps1') @tfDeploymentParams
} else {
  Write-Output "Test Terraform template not found: $script:GlobalConfig_testTerraformDirectoryName. Skipping Terraform deployment."
}

#Post deployment tasks
if ($script:bicepProvisioningState -ieq 'Succeeded' -or $script:terraformProvisioningState -ieq 'Succeeded') {
  Write-Output "Deployment succeeded. proceeding with post deployment tasks before running tests."
  #if deployment succeeded, Make sure subsequent actions are taken and enough wait time is given for policies to be effective before running tests.
  $postDeploymentTasksParams = @{
    testSubscriptionId                                  = $script:testSubscriptionId
    testAuditPoliciesFromDeployedResources              = $script:LocalConfig_testAuditPoliciesFromDeployedResources
    testAppendModifyPolicies                            = $script:LocalConfig_testAppendModifyPolicies
    testDeployIfNotExistsPolicies                       = $script:LocalConfig_testDeployIfNotExistsPolicies
    waitTimeForDeployIfNotExistsPoliciesAfterDeployment = $script:GlobalConfig_waitTimeForDeployIfNotExistsPoliciesAfterDeployment
    waitTimeForAppendModifyPoliciesAfterDeployment      = $script:GlobalConfig_waitTimeForAppendModifyPoliciesAfterDeployment
    waitTimeForAuditPoliciesAfterComplianceScan         = $script:GlobalConfig_waitTimeForAuditPoliciesAfterComplianceScan
  }
  if ($script:LocalConfig_testResourceGroup.length -gt 0) {
    $postDeploymentTasksParams.add('testResourceGroup', $script:LocalConfig_testResourceGroup)
  }
  postDeploymentTasks @postDeploymentTasksParams
}


#Parse deployment outputs
Write-Verbose "[$(getCurrentUTCString)]: Bicep Deployment Outputs:  $script:bicepDeploymentOutputs" -Verbose
