function Get-GitRoot {
  $gitRootDir = & git rev-parse --show-toplevel 2>&1
  if (Test-Path $gitRootDir) {
    Convert-Path $gitRootDir
  }
}

Function getTestConfig {
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory = $true, HelpMessage = 'Specify the test config file path.')]
    [ValidateScript({ Test-Path $_ -PathType Leaf })][string]$TestConfigFilePath
  )

  $testConfig = Get-Content $TestConfigFilePath | ConvertFrom-Json -Depth 99 -AsHashtable
  $testConfig
}

function getCurrentUTCString {
  "$([DateTime]::UtcNow.ToString('u')) UTC"
}

function updateAzResourceTags {
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory = $true, HelpMessage = 'Specify the resource Id.')]
    [ValidateNotNullOrEmpty()][string]$resourceId,

    [Parameter(Mandatory = $true, HelpMessage = 'Specify the new resource tags.')]
    [hashtable]$tags,

    [Parameter(Mandatory = $false, HelpMessage = 'Set to true to revert the tags back to what it was after the update.')]
    [bool]$revertBack = $false
  )
  $uri = 'https://management.azure.com{0}/providers/Microsoft.Resources/tags/default?api-version=2021-04-01' -f $resourceId
  $token = ConvertFrom-SecureString (Get-AzAccessToken).token -AsPlainText
  $headers = @{
    'Authorization' = "Bearer $token"
    'Content-Type'  = 'application/json'
  }
  $body = @{
    properties = @{
      tags = $tags
    }
  } | ConvertTo-Json -Depth 10
  if ($revertBack) {
    Write-Verbose "Get Existing tags before setting new tags for resource '$resourceId'."
    try {
      $existingTagsResponse = Invoke-WebRequest -Uri $uri -Method GET -Headers $headers
      $existingTags = ($existingTagsResponse.content | ConvertFrom-Json -depth 5 -AsHashtable).properties.tags
      Write-Verbose "Existing Tags are:" -Verbose
      Write-Verbose $($existingTags | ConvertTo-Json) -verbose
    } Catch {
      Throw $_.Exception
    }
  }
  Write-Verbose "Updating tags for resource '$resourceId'. New Tags:" -Verbose
  Write-Verbose $tags -Verbose
  try {
    $response = Invoke-WebRequest -Uri $uri -Method PUT -Headers $headers -Body $body -SkipHttpErrorCheck
  } catch {
    Throw $_.Exception
  }
  if ($revertBack) {
    Write-Verbose "Revert tags back for resource '$resourceId'. Old Tags." -Verbose
    $revertBackBody = @{
      properties = @{
        tags = $existingTags
      }
    } | ConvertTo-Json -Depth 10
    try {
      $revertBackResponse = Invoke-WebRequest -Uri $uri -Method PUT -Headers $headers -Body $revertBackBody
      Write-Verbose "Revert back response status code: $($revertBackResponse.StatusCode)" -verbose
    } Catch {
      Throw $_.Exception
    }
  }
  Write-Verbose "Tag Update response status code: $($response.StatusCode)" -Verbose
  Write-Verbose "Tag Update response content: '$($response.content)'" -Verbose
  $response
}

function getResourceViaARMAPI {
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory = $true)][string]$resourceId,
    [Parameter(Mandatory = $true)][string]$apiVersion
  )
  $uri = "https://management.azure.com{0}?api-version={1}" -f $resourceId, $apiVersion
  Write-Verbose "[$(getCurrentUTCString)]: Trying getting resource via the Resource provider API endpoint '$uri'" -Verbose
  $token = ConvertFrom-SecureString (Get-AzAccessToken).token -AsPlainText
  $headers = @{
    'Authorization' = "Bearer $token"
  }
  try {
    $request = Invoke-WebRequest -Uri $uri -Method "GET" -Headers $headers
    if ($request.StatusCode -ge 200 -and $request.StatusCode -lt 300) {
      $resourceExists = $true
    }
  } catch {
    $resourceExists = $false
  }
  if ($resourceExists) {
    $resource = ($request.Content | ConvertFrom-Json -Depth 99)
  }
  $resource
}

function newResourceGroupViaARMAPI {
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory = $true)][string]$subscriptionId,
    [Parameter(Mandatory = $true)][string]$resourceGroupName,
    [Parameter(Mandatory = $true)][string]$location,
    [Parameter(Mandatory = $false)][hashtable]$tags,
    [Parameter(Mandatory = $false)][string]$apiVersion = '2021-04-01'
  )
  $uri = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}?api-version={2}" -f $subscriptionId, $resourceGroupName, $apiVersion
  Write-Verbose "[$(getCurrentUTCString)]: Trying creating resource group via the Resource provider API endpoint '$uri'" -Verbose
  $token = ConvertFrom-SecureString (Get-AzAccessToken).token -AsPlainText
  $headers = @{
    'Authorization' = "Bearer $token"
    'Content-Type'  = 'application/json'
  }
  $body = @{
    location = $location
  }
  if ($PSBoundParameters.ContainsKey('tags')) {
    $body.tags = $tags
  }
  $body = $body | ConvertTo-Json -Depth 10
  try {
    $request = Invoke-WebRequest -Uri $uri -Method "PUT" -Headers $headers -Body $body
    if ($request.StatusCode -ge 200 -and $request.StatusCode -lt 300) {
      $resourceGroupCreated = $true
    }
  } catch {
    Write-Error $_.Exception.Message
    $resourceGroupCreated = $false
  }
  if ($resourceGroupCreated) {
    Write-Verbose "Resource group '$resourceGroupName' created successfully." -Verbose
    $resourceGroupId = ($request.Content | ConvertFrom-Json -Depth 99).id
    $resourceGroupId
  } else {
    Write-Error "Failed to create resource group '$resourceGroupName'."
  }
}

Function getTemplateScope {
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory = $true, HelpMessage = 'Specify the Bicep file path.')]
    [ValidateScript({ Test-Path $_ -PathType Leaf })][string]$BicepFilePath
  )

  $armTemplate = convertBicepToArm -BicepFilePath $BicepFilePath
  $schema = $armTemplate.'$schema'
  Write-Verbose "Arm template Schema: $schema" -Verbose
  switch ($($schema -split ('/'))[-1].tolower()) {
    $('subscriptiondeploymenttemplate.json#') {
      $scope = 'subscription'
    }
    $('managementgroupdeploymenttemplate.json#') {
      $scope = 'managementGroup'
    }
    $('deploymenttemplate.json#') {
      $scope = 'resourceGroup'
    }
    $('tenantdeploymenttemplate.json#') {
      $scope = 'tenant'
    }
    default {
      Write-Error "Invalid template scope"
      exit -1
    }
  }
  $scope
}

function convertBicepToArm {
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory = $true, HelpMessage = 'Specify the Bicep file path.')]
    [ValidateScript({ Test-Path $_ -PathType Leaf })][string]$BicepFilePath
  )
  try {
    $bicepOutput = & bicep build $BicepFilePath --stdout 2>&1
    if ($LASTEXITCODE -ne 0) {
      Throw "Failed to convert the bicep file to ARM template. Error: $bicepOutput"
    }
    $armTemplate = $bicepOutput | ConvertFrom-Json -Depth 99
  } catch {
    Throw "Failed to convert the bicep file to ARM template. Error: $($_.Exception.Message)"
  }

  $armTemplate
}

#this function validates the bicep file for the Bicep templates used by Policy Integration tests
function validateBicep {
  [OutputType([bool])]
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory = $true, HelpMessage = 'Specify the Bicep file path.')]
    [ValidateScript({ Test-Path $_ -PathType Leaf })][string]$BicepFilePath
  )
  $bIsValid = $true
  $armTemplate = convertBicepToArm -BicepFilePath $BicepFilePath


  # template must not have parameters
  if ($armTemplate.psobject.properties.name -contains 'parameters') {
    foreach ($p in $(Get-member -InputObject $armTemplate.parameters -MemberType NoteProperty).name) {
      If ($(get-member -inputobject $armTemplate.parameters.$p -MemberType NoteProperty).name -inotcontains 'defaultvalue') {
        Write-Error "The template should have default value for the parameter '$(($p | get-member -membertype NoteProperty)[0].name)'"
        $bIsValid = $false
      }
    }
  } else {
    Write-Verbose "The template does not have parameters" -Verbose
  }

  #template must have name and resourceId output

  if ($armTemplate.psobject.properties.name -notcontains 'outputs') {
    Write-Error "The template should have outputs"
    $bIsValid = $false
  } else {
    Write-Verbose "The template contains outputs" -Verbose
  }

  if ($armTemplate.outputs.psobject.properties.name -notcontains 'name') {
    Write-Error "The template should have name output"
    $bIsValid = $false
  } else {
    Write-Verbose "The template contains name output" -Verbose
  }

  if ($armTemplate.outputs.psobject.properties.name -notcontains 'resourceId') {
    Write-Error "The template should have resourceId output"
    $bIsValid = $false
  } else {
    Write-Verbose "The template contains resourceId output" -Verbose
  }

  if ($bIsValid) {
    Write-Verbose "The template is valid." -Verbose
  } else {
    Write-Error "The template is invalid."
  }
  $bIsValid

}

#function to ensure the resource group exists and create if not exist.
function createResourceGroupIfNotExist {
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory = $true, HelpMessage = 'Specify the subscription ID.')]
    [ValidateNotNullOrEmpty()][string]$subscriptionId,

    [Parameter(Mandatory = $true, HelpMessage = 'Specify the resource group name.')]
    [ValidateNotNullOrEmpty()][string]$resourceGroupName,

    [Parameter(Mandatory = $true, HelpMessage = 'Specify the location.')]
    [ValidateNotNullOrEmpty()][string]$location,

    [Parameter(Mandatory = $false, HelpMessage = 'Specify the tags.')]
    [hashtable]$tags,

    [Parameter(Mandatory = $true, HelpMessage = 'Specify the Resoruce Group API version.')]
    [ValidateNotNullOrEmpty()][string]$apiVersion
  )

  $resourceGroupResourceId = '/subscriptions/{0}/resourceGroups/{1}' -f $subscriptionId, $resourceGroupName
  $existingResourceGroup = getResourceViaARMAPI -ResourceId $resourceGroupResourceId -apiVersion $apiVersion
  if (!($existingResourceGroup)) {
    if ($tags) {
      Write-Verbose "[$(getCurrentUTCString)]: Resource group '$resourceGroupName' doesn't exist. Creating the resource group '$resourceGroupName' with predefined tags..." -Verbose
      $resourceGroup = newResourceGroupViaARMAPI -subscriptionId $subscriptionId -resourceGroupName $resourceGroupName -location $location -apiVersion $apiVersion -tags $tags
    } else {
      Write-Verbose "[$(getCurrentUTCString)]: Resource group '$resourceGroupName' doesn't exist. Creating the resource group '$resourceGroupName' without any tags..." -Verbose
      $resourceGroup = newResourceGroupViaARMAPI -subscriptionId $subscriptionId -resourceGroupName $resourceGroupName -location $location -apiVersion $apiVersion
    }
    $resourceGroup
  } else {
    Write-Verbose "[$(getCurrentUTCString)]: Resource group '$resourceGroupName' already exists." -Verbose
    $existingResourceGroup.id
  }
}
#function for post bicep / terraform deployment tasks (compliance scan for audit policies and wait for the test start time to be reached)
function postDeploymentTasks {
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory = $true, HelpMessage = 'Test subscription Id.')]
    [string]$testSubscriptionId,

    [Parameter(Mandatory = $false, HelpMessage = 'Test resource group name.')]
    [string]$testResourceGroup = $null,

    [Parameter(Mandatory = $true, HelpMessage = 'If audit policies are tested.')]
    [bool]$testAuditPoliciesFromDeployedResources,

    [Parameter(Mandatory = $true, HelpMessage = 'If append/modify policies are tested.')]
    [bool]$testAppendModifyPolicies,

    [Parameter(Mandatory = $true, HelpMessage = 'If deployIfNotExists policies are tested.')]
    [bool]$testDeployIfNotExistsPolicies,

    [Parameter(Mandatory = $true, HelpMessage = 'Wait time in minutes for deployIfNotExists policies.')]
    [int]$waitTimeForDeployIfNotExistsPoliciesAfterDeployment,

    [Parameter(Mandatory = $true, HelpMessage = 'Wait time in minutes for append/modify policies.')]
    [int]$waitTimeForAppendModifyPoliciesAfterDeployment,

    [Parameter(Mandatory = $true, HelpMessage = 'Wait time in minutes for audit policies after compliance scan.')]
    [int]$waitTimeForAuditPoliciesAfterComplianceScan
  )
  #capture deployment results
  $deploymentCompletionTime = Get-Date


  #Calculate the maximum wait time for append, modify and DINE policies
  $waitTimeMinute = 0
  if ($testAppendModifyPolicies) {
    $waitTimeMinute = $waitTimeForAppendModifyPoliciesAfterDeployment
  }
  if ($testDeployIfNotExistsPolicies) {
    if ($waitTimeMinute) {
      $waitTimeMinute = [math]::Max($waitTimeMinute, $waitTimeForDeployIfNotExistsPoliciesAfterDeployment)
    } else {
      $waitTimeMinute = $waitTimeForDeployIfNotExistsPoliciesAfterDeployment
    }
  }
  Write-Verbose "[$(getCurrentUTCString)]: Calculated wait time for policies to be effective after deployment: $waitTimeMinute minutes." -Verbose
  $testStartTime = $deploymentCompletionTime.AddMinutes($waitTimeMinute)

  if ($testAuditPoliciesFromDeployedResources) {
    Write-Output "Since audit policies are tested, run policy compliance scan before proceeding with tests."
    Set-AzContext -Subscription $testSubscriptionId | Out-Null
    if ($testResourceGroup) {
      Write-Output "[$(getCurrentUTCString)]: Waiting for Policy compliance scan to finish for resource group '$testResourceGroup'."
      $job = Start-AzPolicyComplianceScan -ResourceGroupName $testResourceGroup -AsJob
    } else {
      Write-Output "[$(getCurrentUTCString)]: Waiting for Policy compliance scan to finish for the entire subscription '$testSubscriptionId'."
      $job = Start-AzPolicyComplianceScan -AsJob
    }

    $job | wait-job
    Write-Output "[$(getCurrentUTCString)]: Policy compliance scan finished. Wait $waitTimeForAuditPoliciesAfterComplianceScan minute for the results to be available before starting tests."
    Start-Sleep -Seconds ($waitTimeForAuditPoliciesAfterComplianceScan * 60)
  }
  #Make sure the test start time is reached before starting tests, to allow append, modify and deployIfNotExists policies to be effective.
  $currentTime = Get-Date
  if ($currentTime -lt $testStartTime) {
    $waitTimeSpan = New-TimeSpan -Start $currentTime -End $testStartTime
    $totalSecondsToWait = [math]::Ceiling($waitTimeSpan.TotalSeconds)
    Write-Output "[$(getCurrentUTCString)]: Waiting for $totalSecondsToWait seconds for all in-scope policies to be effective before starting tests."
    Start-Sleep -Seconds $totalSecondsToWait
  } else {
    Write-Output "[$(getCurrentUTCString)]: Current time has passed the calculated test start time. Starting tests now."
  }
}
