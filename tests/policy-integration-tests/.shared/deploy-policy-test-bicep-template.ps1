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

$additionalResourceGroups = @()

if ($script:LocalConfig_removeTestResourceGroup) {
  $removeTestResourceGroup = $script:LocalConfig_removeTestResourceGroup
} else {
  $removeTestResourceGroup = $false
}
try {
  $testResourceGroupName = $script:LocalConfig_testResourceGroup
} catch {
  Write-Verbose "Test resource group is not specified." -verbose
}

Write-Verbose "Test Subscription Id: $script:testSubscriptionId" -verbose

#Create deployment result artifacts
If ($deploymentResultFilePath -ne '') {
  Write-Verbose "  - Deployment result will be saved to '$deploymentResultFilePath'..." -verbose
  If (!(test-path $deploymentResultFilePath)) {
    Write-Output "[$(getCurrentUTCString)]: Creating the deployment result file '$deploymentResultFilePath'..."
    New-Item -Path $deploymentResultFilePath -ItemType File -Force | Out-Null
  }
  $deploymentResult = [ordered]@{
    bicepRemoveTestResourceGroup = $removeTestResourceGroup
    bicepTestSubscriptionId      = $script:testSubscriptionId
  }
  if ($testResourceGroupName -ne '') {
    $deploymentResult.Add('bicepTestResourceGroup', $testResourceGroupName)
  }
}
#create the test resource group if it's specified in the local config file and doesn't exist
if ($testResourceGroupName) {
  #make sure the resource group exists
  $resourceGroupId = createResourceGroupIfNotExist -subscriptionId $script:testSubscriptionId -resourceGroupName $testResourceGroupName -location $script:LocalConfig_location -tags $script:GlobalConfig_tags -apiVersion $script:GlobalConfig_resourceGroupApiVersion
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


  Write-Verbose "[$(getCurrentUTCString)]: Test Template Deployment Subscription Name: $script:LocalConfig_testSubscription" -verbose
  Write-Verbose "[$(getCurrentUTCString)]: Test Template Deployment Subscription Id: $script:testSubscriptionId" -verbose
  Write-Verbose "[$(getCurrentUTCString)]: Test Template Deployment Location: $script:LocalConfig_location" -verbose
  if ($templateScope -ieq 'resourcegroup') {
    $testResourceGroupName = $script:LocalConfig_testResourceGroup
    Write-Verbose "[$(getCurrentUTCString)]: Test Template Deployment Resource Group Name: $testResourceGroupName" -verbose
  }


  $templateName = (Split-Path -Path (Split-Path $BicepFilePath -Parent) -LeafBase).replace('-', '')
  $randomString = -join ((65..90) + (97..122) | Get-Random -Count 5 | foreach-object { [char]$_ })
  $deploymentNamePrefix = "$($script:GlobalConfig_deploymentPrefix)-$($templateName)-$($randomString)-$($BuildNumber)"

  #Create additional resource groups if specified in the test config
  if ($script:LocalConfig_additionalResourceGroups) {
    Write-Output "[$(getCurrentUTCString)]: Creating additional resource groups..."

    $rgReferenceNames = ($script:LocalConfig_additionalResourceGroups.PSObject.Properties | where-object { $_.MemberType -ieq 'noteproperty' }).name
    foreach ($rg in $rgReferenceNames) {
      $resourceGroupName = ($script:LocalConfig_additionalResourceGroups.$rg).resourceGroup
      $subscriptionName = ($script:LocalConfig_additionalResourceGroups.$rg).subscription
      $subscriptionId = $script:GlobalConfig_subscriptions.$subscriptionName.id
      $rgResourceId = '/subscriptions/{0}/resourceGroups/{1}' -f $subscriptionId, $resourceGroupName
      Write-Verbose "Checking if the resource group '$rgResourceId' exists..." -verbose
      $existingRg = getResourceViaARMAPI -ResourceId $rgResourceId -apiVersion $script:GlobalConfig_resourceGroupApiVersion
      if ($existingRg) {
        Write-Verbose "[$(getCurrentUTCString)]: Resource group '$rgResourceId' already exists. Skipping creation." -verbose
        $additionalResourceGroups += $existingRg.id
      } else {
        Write-Output "[$(getCurrentUTCString)]: Resource group '$rgResourceId' doesn't exist. Creating in location '$script:LocalConfig_location'..."
        #create the resource group using ARM REST API directly so we don't have to change the subscription in the Az context
        $additionalResourceGroups += newResourceGroupViaARMAPI -subscriptionId $subscriptionId -resourceGroupName $resourceGroupName -location $script:LocalConfig_location -apiVersion $script:GlobalConfig_resourceGroupApiVersion
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
  $subscription = Get-AzSubscription -SubscriptionId $script:testSubscriptionId
  Set-AzContext -SubscriptionId $script:testSubscriptionId
  switch ($templateScope) {
    'subscription' {
      $deployParams.Add('location', $script:LocalConfig_location)
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
      $deploymentJob | Wait-Job | out-null
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
    $deploymentId = '/subscriptions/{0}/providers/Microsoft.Resources/deployments/{1}' -f $script:testSubscriptionId, $deploymentName
  } else {
    $resourceGroupId = (Get-AzResourceGroup -Name $testResourceGroupName).ResourceId
    $deploymentId = '{0}/providers/Microsoft.Resources/deployments/{1}' -f $resourceGroupId, $deploymentName
  }

  Write-Output "[$(getCurrentUTCString)]: Deployment Id: $deploymentId"
  Write-Output "[$(getCurrentUTCString)]: Deployment Name: $deploymentName"
  Write-Output "[$(getCurrentUTCString)]: Deployment Provisioning State: $provisioningState"

  #create variables for deployment
  $script:bicepDeploymentName = $deploymentName
  $script:bicepProvisioningState = $provisioningState
  $script:bicepDeploymentId = $deploymentId
  $script:deploymentTarget = $deploymentTarget
  $script:bicepDeploymentScope = $templateScope

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
$script:bicepDeploymentOutputs = $deploymentOutputs

#Save deployment result to file if specified
If ($deploymentResultFilePath -ne '') {
  Write-Output "Saving deployment result to '$deploymentResultFilePath'..."
  $deploymentResult | ConvertTo-Json -depth 99 -EnumsAsString -EscapeHandling 'EscapeNonAscii' | Out-File -Path $deploymentResultFilePath -Force
}

Write-Output "Done."
