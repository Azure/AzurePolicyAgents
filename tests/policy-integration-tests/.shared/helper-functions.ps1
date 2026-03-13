function Get-GitRoot {
  $gitRootDir = Invoke-expression 'git rev-parse --show-toplevel 2>&1' -ErrorAction SilentlyContinue
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

  $testConfig = Get-Content $TestConfigFilePath | ConvertFrom-Json
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
  $uri = 'https://management.azure.com/subscriptions/{0}/providers/Microsoft.Resources/tags/default?api-version=2021-04-01' -f $testSubscriptionId
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
    } Catch {
      Throw $_.Exception
    }
  }
  Write-Verbose "Tag Update response status code: $($response.StatusCode)" -Verbose
  Write-Verbose "Tag Update response content: '$($response.content)" -verbose
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
  $armTemplate = invoke-expression "bicep build $bicepFilePath --stdout | ConvertFrom-Json -depth 99" -ErrorVariable bicepBuildError -ErrorAction SilentlyContinue

  if ($bicepBuildError) {
    Throw "Failed to convert the bicep file to ARM template. Error: $($bicepBuildError.Exception.Message)"
    exit -1
  }

  $armTemplate
}

#this function validates the bicep file for the Bicep templates used by Policy Integration tests
function validateBicep {
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