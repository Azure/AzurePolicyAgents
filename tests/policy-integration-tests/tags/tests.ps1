using module ../../../infra/pwsh/AzResourceTest/AzResourceTest.psd1

$helperFunctionScriptPath = (resolve-path -relativeBasePath $PSScriptRoot -path '../../../scripts/pipelines/helper/helper-functions.ps1').path

#load helper
. $helperFunctionScriptPath

<#
Test cases:
- TAG-001: Subscription Should have required tag for SolutionID tag (deny)
- TAG-002: Subscription Should have required tag value for dataclass tag (deny)
- TAG-003: Subscription Should have required tag for owner tag (deny)
- TAG-004: Subscription Should have required tag for supportteam tag (deny)
- TAG-013: Resource Group Should have required tag value for dataclass tag (deny)
- TAG-014: Resource Should have required tag value for dataclass tag (deny)
- TAG-015: Subscription Should have required tag value for environment tag (deny)
- TAG-016: Resource Group Should have required tag value for environment tag (deny)
- TAG-017: Resource Should have required tag value for environment tag (deny)

- TAG-005: Inherit the tag from the Subscription to Resource Group if missing (SolutionID)
- TAG-006: Inherit the tag from the Subscription to Resource Group if missing (dataclass)
- TAG-007: Inherit the tag from the Subscription to Resource Group if missing (owner)
- TAG-008: Inherit the tag from the Subscription to Resource Group if missing (supportteam)
- TAG-018: Inherit the tag from the Subscription to Resource Group if missing (environment)
#>

#variables
$deploymentOutputs = $env:bicepDeploymentOutputs
$outputFilePath = $env:outputFilePath
$outputFormat = $env:outputFormat

$gitRoot = Get-GitRoot
$globalTestConfigFilePath = join-path $gitRoot 'tests' '.shared' '.config' 'policy_integration_test_config.jsonc'
$localTestConfigFilePath = join-path $PSScriptRoot 'config.json'
$globalTestConfig = getTestConfig -TestConfigFilePath $globalTestConfigFilePath
$localTestConfig = getTestConfig -TestConfigFilePath $localTestConfigFilePath
$token = $(az account get-access-token --resource 'https://management.azure.com/' | convertfrom-json).accessToken
#Parse deployment outputs
Write-Verbose "Deployment Outputs: $deploymentOutputs" -Verbose
$deploymentOutputsJson = $deploymentOutputs | ConvertFrom-Json -Depth 99
$resourceId = $deploymentOutputsJson.resourceId.value

$testMG = $localTestConfig.testManagementGroup
$testSubscriptionName = $localTestConfig.testSubscription
$testResourceGroup = $localTestConfig.testResourceGroup
$testSubscriptionId = $globalTestConfig.Subscriptions.$testSubscriptionName.id
$whatIfMaxRetry = $globalTestConfig.whatIfMaxRetry
$resourceWhatIfFailedTemplatePath = join-path $PSScriptRoot 'main.bad.resource.bicep'
$rgWhatIfFailedTemplatePath = join-path $PSScriptRoot 'main.bad.rg.bicep'
$resourceWhatIfDeploymentTargetResourceId = '/subscriptions/{0}/resourceGroups/{1}' -f $testSubscriptionId, $testResourceGroup
$testSubscriptionResourceId = '/subscriptions/{0}' -f $testSubscriptionId

$taggingPolicyAssignmentName = 'pa-d-tags'
$taggingAssignmentId = '/providers/Microsoft.Management/managementGroups/{0}/providers/Microsoft.Authorization/policyAssignments/{1}' -f $testMG, $taggingPolicyAssignmentName
$testTitle = "Tagging Configuration Test"
$contextTitle = "Tag Configuration"
$testSuiteName = 'TagTest'


$subViolatingPolicies = @(
  @{
    policyAssignmentId          = $taggingAssignmentId
    policyDefinitionReferenceId = 'TAG-001'
  },
  @{
    policyAssignmentId          = $taggingAssignmentId
    policyDefinitionReferenceId = 'TAG-002'
  },
  @{
    policyAssignmentId          = $taggingAssignmentId
    policyDefinitionReferenceId = 'TAG-003'
  },
  @{
    policyAssignmentId          = $taggingAssignmentId
    policyDefinitionReferenceId = 'TAG-004'
  }
  @{
    policyAssignmentId          = $taggingAssignmentId
    policyDefinitionReferenceId = 'TAG-015'
  }
)

$rgViolatingPolicies = @(
  @{
    policyAssignmentId          = $taggingAssignmentId
    policyDefinitionReferenceId = 'TAG-013'
  }
  @{
    policyAssignmentId          = $taggingAssignmentId
    policyDefinitionReferenceId = 'TAG-016'
  }
)

$resourceViolatingPolicies = @(
  @{
    policyAssignmentId          = $taggingAssignmentId
    policyDefinitionReferenceId = 'TAG-014'
  }
  @{
    policyAssignmentId          = $taggingAssignmentId
    policyDefinitionReferenceId = 'TAG-017'
  }
)


#region test sub update
$subViolatingTags = @{
  SolutionId1  = '10207' #this should violate the policy TAG-001: Subscription Should have required tag (SolutionID)
  owner1       = 'platform-team' #this should violate the policy TAG-003: Subscription Should have required tag (owner)
  dataclass    = 'official-internal' #this should violate the policy TAG-002: Subscription Should have required tag value (dataclass). 'official-internal' is not one of the allowed values
  supportteam1 = 'platform-team' #this should violate the policy TAG-004: Subscription Should have required tag (supportteam)
  environment  = "hell" #this should violate the policy TAG-015: Subscription Should have required tag value (environment). 'hell' is not one of the allowed values
}


$subTagUpdateTestResponse = updateAzResourceTags -resourceId $testSubscriptionResourceId -tags $subViolatingTags -revertBack $true
$subTagUpdatePolicyActualVioations = ($subTagUpdateTestResponse.content | convertfrom-Json -depth 10).error.additionalInfo | Where-Object { $_.type -ieq 'policyviolation' }
#endregion
#define tests
$tests = @()
$tests += New-ARTManualWhatIfTestConfig -testName 'Subscription Tagging Policy violating update should fail' -actualPolicyViolation $subTagUpdatePolicyActualVioations -desiredPolicyViolation $subViolatingPolicies
$tests += New-ARTWhatIfDeploymentTestConfig -testName 'Resource Group Tagging Policy violating deployment should fail' -token $token -templateFilePath $rgWhatIfFailedTemplatePath -deploymentTargetResourceId $testSubscriptionResourceId -requiredWhatIfStatus 'Failed' -policyViolation $rgViolatingPolicies -maxRetry $whatIfMaxRetry
$tests += New-ARTWhatIfDeploymentTestConfig -testName 'Resource Tagging Policy violating deployment should fail' -token $token -templateFilePath $resourceWhatIfFailedTemplatePath -deploymentTargetResourceId $resourceWhatIfDeploymentTargetResourceId -requiredWhatIfStatus 'Failed' -policyViolation $resourceViolatingPolicies -maxRetry $whatIfMaxRetry

#Modify / Append Policies
#TAG-005 rg-inherit-tag-from-sub (SolutionID)
$tests += New-ARTPropertyCountTestConfig 'TAG-005: Resource Group Should have SolutionID tag' $token $resourceId 'tags.SolutionID' 'equals' 1

#TAG-006 rg-inherit-tag-from-sub (dataclass)
$tests += New-ARTPropertyCountTestConfig 'TAG-006: Resource Group Should have dataclass tag' $token $resourceId 'tags.dataclass' 'equals' 1

#TAG-007 rg-inherit-tag-from-sub (owner)
$tests += New-ARTPropertyCountTestConfig 'TAG-007: Resource Group Should have ownedby tag' $token $resourceId 'tags.owner' 'equals' 1

#TAG-008 rg-inherit-tag-from-sub (supportteam)
$tests += New-ARTPropertyCountTestConfig 'TAG-008: Resource Group Should have supportteam tag' $token $resourceId 'tags.supportteam' 'equals' 1

#TAG-018 rg-inherit-tag-from-sub (environment)
$tests += New-ARTPropertyCountTestConfig 'TAG-018: Resource Group Should have environment tag' $token $resourceId 'tags.environment' 'equals' 1

#Invoke tests
$params = @{
  tests         = $tests
  testTitle     = $testTitle
  contextTitle  = $contextTitle
  testSuiteName = $testSuiteName
  OutputFile    = $outputFilePath
  OutputFormat  = $outputFormat

}
Test-ARTResourceConfiguration @params
