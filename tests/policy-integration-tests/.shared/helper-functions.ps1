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

