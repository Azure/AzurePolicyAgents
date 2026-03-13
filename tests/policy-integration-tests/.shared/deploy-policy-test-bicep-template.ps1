#Requires -Modules Az.Resources
#Requires -Version 7.0

<#
===================================================================
AUTHOR: Tao Yang
DATE: 23/05/2024
NAME: deploy-policy-test-bicep-template.ps1
VERSION: 1.0.0
COMMENT: Deploy test bicep template for policy integration testing
===================================================================
#>
[CmdletBinding()]
Param (

  [Parameter(Mandatory = $true, HelpMessage = 'Specify the directory path for the test case.')]
  [string]$TestPath,

  [Parameter(Mandatory = $false, HelpMessage = 'Specify the Bicep file name.')]
  [string]$BicepFileName = 'main.test.bicep',

  [Parameter(Mandatory = $false, HelpMessage = 'Specify the Test configuration file name.')]
  [string]$TestConfigFileName = 'config.json',

  [parameter(Mandatory = $false, HelpMessage = 'number appended to the ARM deployment name.')]
  [int]$BuildNumber = $(Get-Random -Minimum 100000 -Maximum 999999),

  [parameter(Mandatory = $false, HelpMessage = 'Maximum deployment retry attempt.')]
  [ValidateRange(2, 5)]
  [int]$maxRetry = 3,

  [parameter(Mandatory = $false)]
  [string]$bicepModuleSubscriptionId = '',

  [parameter(Mandatory = $false)]
  [string]$deploymentResultFilePath = ''
)

#Get the test config
$helperFunctionScriptPath = join-path  $PSScriptRoot 'helper-functions.ps1'
#load helper
. $helperFunctionScriptPath

$BicepFilePath = Join-Path $TestPath -ChildPath $BicepFileName
$testConfigFilePath = Join-Path $TestPath -ChildPath $TestConfigFileName
$resourceGroupApiVersion = '2021-04-01'
$additionalResourceGroups = @()
$testGlobalConfigFilePath = join-path $PSScriptRoot 'policy_integration_test_config.jsonc'
Write-Verbose "Loading Global Test configuration from ''$testGlobalConfigFilePath'..." -verbose
$globalTestConfig = getTestConfig -TestConfigFilePath $testGlobalConfigFilePath
$tags = $globalTestConfig.tags | ConvertTo-Json | ConvertFrom-Json -AsHashTable
Write-Verbose "Loading Local Test configuration from ''$testConfigFilePath'..." -verbose
$localTestConfig = getTestConfig -TestConfigFilePath $testConfigFilePath
$testLocation = $localTestConfig.location
$testSubName = $localTestConfig.testSubscription
$testSubId = $globalTestConfig.subscriptions.$testSubName.id

if ($localTestConfig.PSObject.properties.name.contains('removeTestResourceGroup')) {
  $removeTestResourceGroup = $localTestConfig.removeTestResourceGroup
} else {
  $removeTestResourceGroup = $false
}
try {
  $testResourceGroupName = $localTestConfig.testResourceGroup
} catch {
  Write-Verbose "Test resource group is not specified." -verbose
}

if ($localTestConfig.PSObject.properties.name.contains('tagsForResourceGroup')) {
  $tagsForResourceGroup = $localTestConfig.tagsForResourceGroup
} else {
  $tagsForResourceGroup = $false
}

#Create deployment result artifacts
If ($deploymentResultFilePath -ne '') {
  Write-Verbose "  - Deployment result will be saved to '$deploymentResultFilePath'..." -verbose
  If (!(test-path $deploymentResultFilePath)) {
    Write-Output "[$(getCurrentUTCString)]: Creating the deployment result file '$deploymentResultFilePath'..."
    New-Item -Path $deploymentResultFilePath -ItemType File -Force | Out-Null
  }
  $deploymentResult = [ordered]@{
    bicepRemoveTestResourceGroup = $removeTestResourceGroup
    bicepTestSubscriptionId      = $testSubId
  }
  if ($testResourceGroupName -ne '') {
    $deploymentResult.Add('bicepTestResourceGroup', $testResourceGroupName)
  }
}
#create the test resource group if it's specified in the local config file and doesn't exist
if ($testResourceGroupName) {
  $testResourceGroupResourceId = '/subscriptions/{0}/resourceGroups/{1}' -f $testSubId, $testResourceGroupName
  $existingTestResourceGroup = getResourceViaARMAPI -ResourceId $testResourceGroupResourceId -apiVersion $resourceGroupApiVersion
  if (!($existingTestResourceGroup)) {
    if ($tagsForResourceGroup) {
      Write-Output "[$(getCurrentUTCString)]: Resource group '$testResourceGroupName' doesn't exist. Creating the resource group '$testResourceGroupName' with predefined tags..."
      $testResourceGroup = newResourceGroupViaARMAPI -subscriptionId $testSubId -resourceGroupName $testResourceGroupName -location $testLocation -apiVersion $resourceGroupApiVersion-Tag $tags
    } else {
      Write-Output "[$(getCurrentUTCString)]: Resource group '$testResourceGroupName' doesn't exist. Creating the resource group '$testResourceGroupName' without any tags..."
      $testResourceGroup = newResourceGroupViaARMAPI -subscriptionId $testSubId -resourceGroupName $testResourceGroupName -location $testLocation -apiVersion $resourceGroupApiVersion
    }

  } else {
    Write-Output "[$(getCurrentUTCString)]: Resource group '$testResourceGroupName' already exists."
  }
}

# deploy test bicep template if it exists
if (Test-path $BicepFilePath -PathType Leaf) {
  if ($bicepModuleSubscriptionId -ne '') {
    Write-Output "[$(getCurrentUTCString)]: Set Az Context to the bicep module subscription '$bicepModuleSubscriptionId'."
    set-AzContext -subscriptionId $bicepModuleSubscriptionId
  }
  #Make sure the bicep file is valid
  Write-Output "[$(getCurrentUTCString)]: Validating the bicep file..."
  $isValidBicep = validateBicep -BicepFilePath $BicepFilePath

  if (!$isValidBicep) {
    Throw "The bicep file is not valid. Exiting..."
    exit 1
  }

  #Get Bicep template deployment scope
  $templateScope = getTemplateScope -BicepFilePath $BicepFilePath


  Write-Verbose "[$(getCurrentUTCString)]: Test Template Deployment Subscription Name: $testSubName" -verbose
  Write-Verbose "[$(getCurrentUTCString)]: Test Template Deployment Subscription Id: $testSubId" -verbose
  Write-Verbose "[$(getCurrentUTCString)]: Test Template Deployment Location: $testLocation" -verbose
  if ($templateScope -ieq 'resourcegroup') {
    $testResourceGroupName = $localTestConfig.testResourceGroup
    Write-Verbose "[$(getCurrentUTCString)]: Test Template Deployment Resource Group Name: $testResourceGroupName" -verbose
  }

  $deploymentPrefix = $globalTestConfig.deploymentPrefix
  $templateName = (Split-Path -Path (Split-Path $BicepFilePath -Parent) -LeafBase).replace('-', '')
  $randomString = -join ((65..90) + (97..122) | Get-Random -Count 5 | % { [char]$_ })
  $deploymentNamePrefix = "$($deploymentPrefix)-$($templateName)-$($randomString)-$($BuildNumber)"

  #Create additional resource groups if specified in the test config
  if ($localTestConfig.additionalResourceGroups) {
    Write-Output "[$(getCurrentUTCString)]: Creating additional resource groups..."

    $rgReferenceNames = ($localTestConfig.additionalResourceGroups.PSObject.Properties | where-object { $_.MemberType -ieq 'noteproperty' }).name
    foreach ($rg in $rgReferenceNames) {
      $resourceGroupName = ($localTestConfig.additionalResourceGroups.$rg).resourceGroup
      $subscriptionName = ($localTestConfig.additionalResourceGroups.$rg).subscription
      $subscriptionId = $globalTestConfig.subscriptions.$subscriptionName.id
      $rgResourceId = '/subscriptions/{0}/resourceGroups/{1}' -f $subscriptionId, $resourceGroupName
      Write-Verbose "Checking if the resource group '$rgResourceId' exists..." -verbose
      $existingRg = getResourceViaARMAPI -ResourceId $rgResourceId -apiVersion $resourceGroupApiVersion
      if ($existingRg) {
        Write-Verbose "[$(getCurrentUTCString)]: Resource group '$rgResourceId' already exists. Skipping creation." -verbose
        $additionalResourceGroups += $existingRg.id
      } else {
        Write-Output "[$(getCurrentUTCString)]: Resource group '$rgResourceId' doesn't exist. Creating in location '$testLocation'..."
        #create the resource group using ARM REST API directly so we don't have to change the subscription in the Az context
        $additionalResourceGroups += newResourceGroupViaARMAPI -subscriptionId $subscriptionId -resourceGroupName $resourceGroupName -location $testLocation -apiVersion $resourceGroupApiVersion
      }
    }
    Write-Verbose "[$(getCurrentUTCString)]: Additional resource groups:" -verbose
    Foreach ($rg in $additionalResourceGroups) {
      Write-Verbose "  - $rg" -verbose
    }
  }
  #Create deployment result hastable to store the deployment result
  If ($deploymentResultFilePath -ne '') {
    $deploymentResult.Add('bicepDeploymentScope', $templateScope)
    $deploymentResult.Add('bicepAdditionalResourceGroups', $additionalResourceGroups)
  }
  #Deploy the bicep template
  $deployParams = @{
    templateFile = $BicepFilePath
    AsJob        = $true
    name         = $deploymentNamePrefix
  }

  Write-Verbose "[$(getCurrentUTCString)]: Deploying the bicep template..." -verbose
  $subscription = Get-AzSubscription -SubscriptionId $testSubId
  Set-AzContext -SubscriptionId $testSubId
  switch ($templateScope) {
    'subscription' {
      $deployParams.Add('location', $testLocation)
      $deploymentJob = New-AzDeployment @deployParams
      $deploymentTarget = '/subscriptions/{0}' -f $subscription.Id
    }
    'resourcegroup' {
      $deployParams.Add('resourceGroupName', $testResourceGroupName)
      $deployParams.add('Mode', "Incremental")
      $deploymentTarget = $testResourceGroupResourceId
    }
    default {
      Throw "The template scope '$templateScope' is not supported. Only Subscription and ResourceGroup level deployments are supported for Azure Policy test templates."
      Exit 1
    }
  }
  If ($deploymentResultFilePath -ne '') {
    #Save deployment target to the deployment result file
    $deploymentResult.Add('bicepDeploymentTarget', $deploymentTarget)
  }

  #create template deployment and retry if failed
  $retryCount = 0
  $retryAfterSeconds = 15
  $deploymentSuccessful
  Do {
    try {
      $retryCount++
      $deploymentName = "$deploymentNamePrefix-$retryCount"
      $deployParams.name = $deploymentName
      Write-Verbose "[$(getCurrentUTCString)]: Deployment Attempt $retryCount`: Create $templateScope scope deployment job '$deploymentName'." -verbose
      switch ($templateScope) {
        'subscription' {
          $deploymentJob = New-AzDeployment @deployParams
        }
        'resourcegroup' {
          $deploymentJob = New-AzResourceGroupDeployment @deployParams
        }
      }
      Write-Verbose "[$(getCurrentUTCString)]: Wait for the $templateScope scope deployment job to complete..." -verbose
      $wait = $deploymentJob | Wait-Job
      $deployResult = $deploymentJob | Receive-Job
      $provisioningState = $deployResult.ProvisioningState
      if ($provisioningState -ieq 'succeeded') {
        $deploymentSuccessful = $true
      }
      Write-Verbose "[$(getCurrentUTCString)]: The $templateScope scope deployment job Completed with provisioning state: '$provisioningState'." -verbose
    } Catch {
      Write-Verbose "[$(getCurrentUTCString)]: Error occurred while deploying the test bicep template."
      Write-Verbose "[$(getCurrentUTCString)]: Error: $_" -verbose
      if ($retryCount -le $maxRetry) {
        Write-Verbose "[$(getCurrentUTCString)]: Will retry after $retryAfterSeconds seconds." -verbose
        Start-Sleep -Seconds $retryAfterSeconds
      } else {
        Write-Verbose "[$(getCurrentUTCString)]: Max retry count reached. Will not retry." -verbose
      }
    }
  } until ($retryCount -ge $maxRetry -or $deploymentSuccessful -eq $true)

  #retrieve deployment Id
  If ($templateScope -ieq 'subscription') {
    $deploymentId = $deployResult.Id
    $deploymentId = '/subscriptions/{0}/providers/Microsoft.Resources/deployments/{1}' -f $testSubId, $deploymentName
  } else {
    $resourceGroupId = (Get-AzResourceGroup -Name $testResourceGroupName).ResourceId
    $deploymentId = '{0}/providers/Microsoft.Resources/deployments/{1}' -f $resourceGroupId, $deploymentName
  }

  Write-Output "[$(getCurrentUTCString)]: Deployment Id: $deploymentId"
  Write-Output "[$(getCurrentUTCString)]: Deployment Name: $deploymentName"
  Write-Output "[$(getCurrentUTCString)]: Deployment Provisioning State: $provisioningState"

  #create environment variables for deployment
  $env:bicepDeploymentName = $deploymentName
  $env:provisioningState = $provisioningState
  $env:bicepDeploymentId = $deploymentId
  $env:bicepDeploymentTarget = $deploymentTarget

  If ($deploymentResultFilePath -ne '') {
    #save the deployment name and provisioning state to the deployment result file
    if ($deploymentName -ne '') {
      $deploymentResult.Add('bicepDeploymentId', $deploymentId)
    }
    if ($provisioningState -ne '') {
      $deploymentResult.Add('bicepProvisioningState', $provisioningState)
    }
  }
  if ($deploymentSuccessful -ne $true) {
    #Still save the applicable deployment details to the file if specified
    $deploymentResult | ConvertTo-Json -depth 99 -EnumsAsString -EscapeHandling 'EscapeNonAscii' | Out-File -Path $deploymentResultFilePath -Force
    Throw "Failed to deploy test template after $maxRetry attempts."
    Exit 1
  }

  #Get deployment outputs for the successful deployment
  $deploymentOutputs = $deployResult.Outputs | ConvertTo-Json -depth 99 -EnumsAsString -EscapeHandling 'EscapeNonAscii'

  if ($($deployResult.Outputs)) {
    $deploymentOutputs = $deployResult.Outputs | ConvertTo-Json -depth 99 -EnumsAsString -EscapeHandling 'EscapeNonAscii' -Compress

    Write-Output "[$(getCurrentUTCString)]: Saving Deployment Outputs..."
    Write-Output "[$(getCurrentUTCString)]: Deployment Outputs: $($deployResult.Outputs | ConvertTo-Json -depth 99 -EnumsAsString -EscapeHandling 'EscapeNonAscii')"
    #Save deployment outputs
    If ($deploymentResultFilePath -ne '') {
      Write-Verbose "  - Saving deployment outputs to '$deploymentResultFilePath'..." -verbose
      $deploymentResult.Add('bicepDeploymentOutputs', $deploymentOutputs)
    }
  } else {
    Write-Output "[$(getCurrentUTCString)]: No Deployment Outputs found."
  }
} else {
  Write-Output "The bicep file '$BicepFilePath' does not exist. Deployment skipped."
}
#Always create deploymentOutputs and deploymentId environment variable even if there are no outputs So it can be used in the next steps
$env:bicepDeploymentOutputs = $deploymentOutputs

#Save deployment result to file if specified
If ($deploymentResultFilePath -ne '') {
  Write-Output "Saving deployment result to '$deploymentResultFilePath'..."
  $deploymentResult | ConvertTo-Json -depth 99 -EnumsAsString -EscapeHandling 'EscapeNonAscii' | Out-File -Path $deploymentResultFilePath -Force
}

Write-Output "Done."
