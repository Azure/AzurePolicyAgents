using module ./AzResourceTest-type.psm1
using module ./AzResourceTest-helper.psm1

#function to detect the template scope based on the schema defined in the ARM template
Function getTemplateScope {
  [CmdletBinding()]
  [OutputType([string])]
  Param (
    [Parameter(Mandatory = $true, HelpMessage = 'Specify the template File content.')]
    [object]$templateFileContent
  )

  $schema = $templateFileContent.'$schema'
  Write-Verbose "[$(getCurrentUTCString)]: Arm template Schema: $schema" -Verbose
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
      Write-Error "[$(getCurrentUTCString)]: Invalid template scope"
      exit -1
    }
  }
  $scope
}

#function to invoke the deployment what-if REST API
function getArmDeploymentWhatIfResult {
  [CmdletBinding(positionalbinding = $false)]
  [OutputType([object])]
  param (
    [parameter(Mandatory = $true)]
    [ValidateScript({ test-path $_ -PathType Leaf })]
    [string]$templateFilePath,

    [parameter(Mandatory = $false)]
    [ValidateScript({ test-path $_ -PathType Leaf })]
    [string]$parameterFilePath,

    [parameter(Mandatory = $false, HelpMessage = 'The deployment target resource Id. Leave it blank if the deployment scope is at the tenant level.')]
    [string]$deploymentTargetResourceId = '',

    [parameter(Mandatory = $false)]
    [ValidateSet('FullResourcePayloads', 'ResourceIdOnly')]
    [string]$resultFormat = 'FullResourcePayloads',

    [parameter(Mandatory = $false)]
    [ValidateRange(100, 1000)]
    [int]$httpTimeoutSeconds = 300,

    [parameter(Mandatory = $false)]
    [ValidateRange(300, 1000)]
    [int]$longRunningJobTimeoutSeconds = 300,

    [parameter(Mandatory = $false)]
    [ValidateRange(3, 10)]
    [int]$maxRetry = 3,

    [parameter(Mandatory = $false)]
    [string]$azureLocation = 'australiaeast',

    [Parameter(Mandatory = $true)]
    [string]$token
  )
  $WarningPreference = 'SilentlyContinue'
  Write-Verbose "[$(getCurrentUTCString)]: What-If validation for Bicep Template using ARM Deployment What-If REST API." -verbose

  #Process template file
  Write-Verbose "[$(getCurrentUTCString)]: Process template file '$templateFilePath'" -Verbose
  $templateFileItem = Get-Item $templateFilePath
  Write-Verbose "[$(getCurrentUTCString)]: TemplateFilePath: '$($templateFileItem.FullName)'" -Verbose
  if ($templateFileItem.Extension -ieq '.bicep') {
    Write-Verbose "[$(getCurrentUTCString)]: '$templateFilePath' is a bicep file. Convert to Json" -verbose
    $templateFileContent = bicep build $templateFilePath --stdout | convertFrom-Json -Depth 99
  } elseif ($templateFileItem.Extension -ieq '.json') {
    Write-Verbose "[$(getCurrentUTCString)]: '$templateFilePath' is a json file. Get the content" -Verbose
    $templateFileContent = Get-Content -Path $templateFilePath -Raw | convertFrom-Json -Depth 99
  } else {
    Throw "Template File '$templateFilePath' must be either a .json or .bicep file."
  }
  $deploymentScope = getTemplateScope -templateFileContent $templateFileContent
  $defaultRetryAfterSeconds = 15
  Write-Verbose "[$(getCurrentUTCString)]: $deploymentScope Level Deployment. Template file: '$templateFilePath'" -Verbose

  $body = @{
    properties = @{
      mode           = 'Incremental'
      whatIfSettings = @{
        resultFormat = $resultFormat
      }
      template       = $templateFileContent
    }
  }
  #Add location to the request body if the deployment scope is not resource group
  if ($deploymentScope -ine 'resourcegroup') {
    $body.add('location', $azureLocation)
  }

  #Process parameter file
  If ($parameterFilePath) {
    Write-Verbose "[$(getCurrentUTCString)]: ParameterFilePath: '$parameterFilePath'" -Verbose
    $parameterFile = Get-Item $parameterFilePath
    if ($parameterFile.Extension -ieq '.bicepparam') {
      Write-Verbose "'$parameterFilePath' is a bicep parameter file. Convert to Json" -Verbose
      $parameterFileContent = bicep build-params "$parameterFilePath" --stdout
    } elseif ($parameterFile.Extension -ieq '.json') {
      Write-Verbose "[$(getCurrentUTCString)]: '$parameterFilePath' is a json parameter file." -Verbose
      $parameterFileContent = Get-Content -Path $parameterFilePath -Raw
    }
    #Read parameters from parameter file
    $parameters = (ConvertFrom-JSON $parameterFileContent -Depth 99).parameters
    $body.properties.Add('parameters', $parameters)
  }

  $headers = @{
    'Authorization' = "Bearer $token"
  }
  $bodyJson = $body | ConvertTo-Json -Depth 99 -EscapeHandling 'EscapeNonAscii'
  #Create what-if deployment and retry if failed
  $retryCount = 0
  $whatIfSuccessful = $false
  Do {
    try {
      $retryCount++
      Write-Verbose "[$(getCurrentUTCString)]: Attempt $retryCount/$maxRetry`: What-If Template validation." -verbose
      $whatIfDeploymentUri = buildWhatIfDeploymentUri -deploymentTargetResourceId $deploymentTargetResourceId
      Write-Verbose "[$(getCurrentUTCString)]: What-If Deployment URI: '$whatIfDeploymentUri'" -verbose
      Write-Verbose "[$(getCurrentUTCString)]: Create What-If deployment via URL '$whatIfDeploymentUri'..." -verbose
      #What-If API reference: https://learn.microsoft.com/en-us/rest/api/resources/deployments/what-if?view=rest-resources-2021-04-01&tabs=HTTP

      $request = Invoke-WebRequest -Uri $whatIfDeploymentUri -Headers $headers -method 'POST' -body $bodyJson -ConnectionTimeoutSeconds $httpTimeoutSeconds -ContentType 'application/json'
      if ($request.StatusCode -eq 200) {
        $whatIfSuccessful = $true
        Write-Verbose "[$(getCurrentUTCString)]: What-If deployment completed successfully. No need to wait for long-running operations." -verbose
        $result = $request.Content | ConvertFrom-Json -Depth 99
      } elseif ($request.StatusCode -eq 202) {
        Write-Verbose "[$(getCurrentUTCString)]: What-If deployment accepted. Will retrieve results by polling the long-running job..." -verbose
        $responseHeaders = $request.Headers | ConvertTo-Json -Depth 99 -Compress
        Write-Verbose "[$(getCurrentUTCString)]: Initial response headers: $responseHeaders" -verbose
        $longRunningOperationUrl = $request.Headers.Location[0]
        $retryAfterSeconds = [int]$request.Headers.'Retry-After'[0]

        $shouldWait = $true
        $waitStartTime = get-date
        Do {
          Write-Verbose "[$(getCurrentUTCString)]: What-If long running job URL: $longRunningOperationUrl" -verbose
          if ($retryAfterSeconds) {
            Write-Verbose "[$(getCurrentUTCString)]: Retry-After header found from initial HTTP response. Will retry after $retryAfterSeconds seconds." -verbose
            Start-Sleep -Seconds $retryAfterSeconds
          } else {
            Write-Verbose "[$(getCurrentUTCString)]: Retry-After header not found from initial HTTP response. Will retry after $defaultRetryAfterSeconds seconds." -verbose
            Start-Sleep -Seconds $defaultRetryAfterSeconds
          }
          $longRunningJobResult = Invoke-WebRequest -Uri $longRunningOperationUrl -Headers $headers -Method Get -ConnectionTimeoutSeconds $httpTimeoutSeconds -ErrorVariable longRunningJobError
          if (!$longRunningJobError) {
            Write-Verbose "[$(getCurrentUTCString)]: Long running job status: $($longRunningJobResult.StatusCode)" -verbose
            $now = Get-date
            if ($longRunningJobResult.StatusCode -eq 200 -or ($now - $waitStartTime).TotalSeconds -gt $longRunningJobTimeoutSeconds) {
              $shouldWait = $false
              if ($longRunningJobResult.StatusCode -eq 200) {
                Write-Verbose "[$(getCurrentUTCString)]: Long running job completed." -verbose
                $result = $longRunningJobResult.Content | ConvertFrom-Json -Depth 99
                $whatIfSuccessful = $true
              } else {
                Throw "[$(getCurrentUTCString)]: Long Running Job did not complete within the timeout period. Status Code: $($result.StatusCode)"
              }
            }
          }
        }until (!$shouldWait)
      } else {
        Write-Verbose "[$(getCurrentUTCString)]: Failed to create what-if deployment. HTTP response status code: $($request.StatusCode)" -verbose
      }
    } Catch {
      $statusCodeDescription = $_.Exception.Response.StatusCode
      $statusCode = [int]$statusCodeDescription
      Write-Verbose "[$(getCurrentUTCString)]: Error occurred while creating the what-if deployment."
      Write-Verbose "[$(getCurrentUTCString)]: HTTP response status code: $statusCode - $statusCodeDescription " -Verbose
      Write-Verbose "[$(getCurrentUTCString)]: Error: $_" -verbose
      if ($retryCount -le $maxRetry) {
        Write-Verbose "[$(getCurrentUTCString)]: Will retry in $defaultRetryAfterSeconds seconds." -verbose
        Start-Sleep -Seconds $defaultRetryAfterSeconds
      } else {
        Write-Verbose "[$(getCurrentUTCString)]: Max retry count reached. Will not retry." -verbose
      }
    }

  } until ($retryCount -ge $maxRetry -or $whatIfSuccessful -eq $true)
  if ($result) {
    $result
  } else {
    Write-Error "[$(getCurrentUTCString)]: Failed to create the what-if deployment after $maxRetry retries."
    exit -1
  }
}

#function to build the what-if deployment uri
function buildWhatIfDeploymentUri {
  [CmdletBinding()]
  [OutputType([string])]
  param (
    [parameter(Mandatory = $false)]
    [ValidateScript({ $_ -imatch '^\d{4}-\d{2}-\d{2}(-preview)?$' })]
    [string]$apiVersion = '2025-04-01', #default to the latest api version as of July 2025, documented in ARM API specs https://github.com/Azure/azure-rest-api-specs/blob/main/specification/resources/resource-manager/Microsoft.Resources/deployments/stable/2025-04-01/deployments.json

    [parameter(Mandatory = $true)]
    [ValidateNotNull()]
    [string]$deploymentTargetResourceId
  )
  $deploymentName = "{0}{1}" -f $( -join ((97..122) | Get-Random -Count 5 | Foreach-Object { [char]$_ })), $(Get-Random -Minimum 100 -Maximum 999)
  $deploymentUri = 'https://management.azure.com{0}/providers/Microsoft.Resources/deployments/{1}/whatIf?api-version={2}' -f $deploymentTargetResourceId, $deploymentName, $apiVersion
  $deploymentUri
}

function getWhatIfDeploymentResult {
  [CmdletBinding()]
  [OutputType([bool])]
  param (
    [Parameter(Mandatory = $true)][object]$desiredConfig
  )

  #get the what-if result
  $whatIfRequestParams = @{
    templateFilePath           = $desiredConfig.templateFilePath
    deploymentTargetResourceId = $desiredConfig.deploymentTargetResourceId
    token                      = $desiredConfig.token
  }
  if ($desiredConfig.parameterFilePath) {
    $whatIfRequestParams.add('parameterFilePath', $desiredConfig.parameterFilePath)
  }
  if ($desiredConfig.httpTimeoutSeconds) {
    $whatIfRequestParams.add('httpTimeoutSeconds', $desiredConfig.httpTimeoutSeconds)
  }
  if ($desiredConfig.longRunningJobTimeoutSeconds) {
    $whatIfRequestParams.add('longRunningJobTimeoutSeconds', $desiredConfig.longRunningJobTimeoutSeconds)
  }
  if ($desiredConfig.maxRetry) {
    $whatIfRequestParams.add('maxRetry', $desiredConfig.maxRetry)
  }
  if ($desiredConfig.azureLocation) {
    $whatIfRequestParams.add('azureLocation', $desiredConfig.azureLocation)
  }

  $whatIfResult = getArmDeploymentWhatIfResult @whatIfRequestParams -Verbose

  #compare the what-if result with the desired configuration
  Write-Verbose "[$(getCurrentUTCString)]: What-if deployment status: $($whatIfResult.status). Desired What-If status: $($desiredConfig.requiredWhatIfStatus)" -verbose
  $bStatusMatch = $whatIfResult.status -match $desiredConfig.requiredWhatIfStatus

  #Compare the desired policyViolation (only when the status is 'Failed')
  $bPolicyViolationMatch = $true
  if ($whatIfResult.status -ieq 'Failed' -and $desiredConfig.policyViolation.count -gt 0) {
    Write-Verbose "[$(getCurrentUTCString)]: Checking policy violations" -verbose
    Write-Verbose "[$(getCurrentUTCString)]: Policy Violations from the What-If deployment result:" -verbose
    Write-Verbose $($whatIfResult.error.details.additionalInfo | ConvertTo-Json -Depth 99) -verbose
    $WhatIfResultPolicyViolations = $whatIfResult.error.details.additionalInfo | where-object { $_.type -ieq 'PolicyViolation' }
    $bPolicyViolationMatch = processPolicyViolation -desiredPolicyViolation $desiredConfig.policyViolation -actualPolicyViolations $WhatIfResultPolicyViolations
  }
  $ComparisonResult = $bStatusMatch -and $bPolicyViolationMatch
  $ComparisonResult
}

#function to validate the ARM template compatibility with the policy restrictions API
function isARMCompatibleWithPolicyRestrictionAPI {
  [CmdletBinding()]
  [OutputType([object])]
  param (
    [Parameter(Mandatory = $true)][object]$template
  )
  $messages = @()
  $isCompatible = $true

  #make sure the template does not contain modules (nested deployments) because it's not supported.
  foreach ($resource in $template.resources) {
    if ($resource.type -ieq 'Microsoft.Resources/deployments') {
      $messages += "Modules are not supported in the Bicep template. Only resources are allowed when validating against the policy restrictions API."
      $isCompatible = $false
    }
  }
  #make sure the name of each resource is specified and does not contain any functions
  foreach ($resource in $template.resources) {
    if ($resource.name -match '^\[.*\]$') {
      $messages += "Resource name'$($resource.name)' is not hardcoded. It must be known at compile time and cannot be parameterised or defined as a variable. Please hardcode a name for the resource."
      $isCompatible = $false
    }
  }

  #make sure the resource location is hardcoded
  foreach ($resource in $template.resources) {
    if ($resource.location -and $($resource.location -match '^\[.*\]$')) {
      $messages += "The location for resource $($resource.name) is set to '$($resource.location)', which is not hardcoded. It must be known at compile time and cannot be parameterised or defined as a variable. Please hardcode a location for the resource."
      $isCompatible = $false
    }
  }
  $result = New-Object PSObject -Property @{
    isCompatible = $isCompatible
    messages     = , $messages
  }
  $result
}

#function to check ARM resource configuration against the policy restrictions API
function checkArmPolicyRestriction {
  [CmdletBinding()]
  [OutputType([bool])]
  param (
    [Parameter(Mandatory = $true)][object]$desiredConfig
  )
  Write-Verbose "[$(getCurrentUTCString)]: Processing policy restriction API results for $($desiredConfig.testName)" -verbose
  $token = $desiredConfig.token

  Write-Verbose "[$(getCurrentUTCString)]: Get policy restriction the ARM configuration for $($desiredConfig.resourceConfig.resourceName)" -verbose
  #get policy restrictions
  $pendingFields = @(
    @{
      field  = 'name'
      values = @($desiredConfig.resourceConfig.resourceName)
    }
    @{
      field = 'tags'
    }
  )
  if ($desiredConfig.resourceConfig.location) {
    $pendingFields += @{
      field  = 'location'
      values = @($desiredConfig.resourceConfig.location)
    }
  }
  if ($null -eq $desiredConfig.resourceConfig.resourceContent) {
    $resourceContent = @{}
  } else {
    $resourceContent = $desiredConfig.resourceConfig.resourceContent | convertFrom-Json -Depth 99 -AsHashtable
  }
  $resourceContent.add('type', $desiredConfig.resourceConfig.resourceType)
  $policyRestrictionParams = @{
    scopeResourceId    = $desiredConfig.deploymentTargetResourceId
    includeAuditEffect = $desiredConfig.resourceConfig.includeAuditEffect
    resourceApiVersion = $desiredConfig.resourceConfig.apiVersion
    pendingFields      = $pendingFields
    resourceContent    = $resourceContent
    token              = $token
  }
  if ($desiredConfig.resourceConfig.resourceScope) {
    $policyRestrictionParams['resourceScope'] = $desiredConfig.resourceConfig.resourceScope
  }
  Write-Verbose "  - Calling the Policy Restrictions API..." -verbose
  $policyRestrictions = [PSCustomObject]@{
    name               = $desiredConfig.resourceConfig.resourceName
    policyRestrictions = $(getAzPolicyRestriction @policyRestrictionParams)
  }
  Write-Verbose "[$(getCurrentUTCString)]: Policy Restriction results for $($desiredConfig.resourceConfig.resourceName):" -verbose
  Write-Verbose $($policyRestrictions | ConvertTo-Json -Depth 99) -verbose
  $matchingPolicyViolation = processPolicyRestrictionAPIResult -desiredPolicyViolations $desiredConfig.policyViolation -actualRestrictionForResource $policyRestrictions

  Write-Verbose "[$(getCurrentUTCString)]: Policy Restriction validation result for $($desiredConfig.testName): $bMatchingPolicyViolation" -verbose
  #return true if all the desired policy violations are matched with the actual policy violation
  $matchingPolicyViolation
}


