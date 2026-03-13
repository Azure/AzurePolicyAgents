using module ./AzResourceTest-type.psm1

#function to query Azure resource graph using the rest API
function invokeARGQuery {
  [CmdletBinding()]
  [OutputType([object])]
  param (
    [parameter(Mandatory = $true)]
    [string]$query,

    [parameter(Mandatory = $false)]
    [string[]]$scope,

    [parameter(Mandatory = $true)]
    [ValidateSet('tenant', 'subscription', 'managementGroup')]
    [string]$scopeType,

    [parameter(Mandatory = $false)]
    [ValidateRange(1, 1000)]
    [int]$top = 1000,

    [parameter(Mandatory = $false)]
    [int]$skip = 0,

    [parameter(Mandatory = $true)]
    [string]$token,

    [parameter(Mandatory = $false)]
    [ValidateRange(30, 600)]
    [int]$timeoutSeconds = 300,

    [parameter(Mandatory = $false)]
    [ValidateRange(1, 5)]
    [int]$maxRetries = 3
  )

  # Build the request URI
  $uri = 'https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2024-04-01'

  # Build request headers
  $headers = @{
    'Authorization' = "Bearer $token"
    'Content-Type'  = 'application/json'
  }

  # Build request body
  $body = @{
    query   = $query
    options = @{
      '$top'  = $top
      '$skip' = $skip
    }
  }

  # Add subscriptions if provided
  if ($scopeType -ieq 'subscription' -and $scope -and $scope.Count -gt 0) {
    $body.subscriptions = $subscriptions
  } elseif ($scopeType -ieq 'managementGroup' -and $scope -and $scope.Count -gt 0) {
    # If scope is management group, convert to management group names
    $body.managementGroups = $scope
  }

  $jsonBody = $body | ConvertTo-Json -Depth 10

  Write-Verbose "[$(getCurrentUTCString)]: Querying Azure Resource Graph via REST API"
  Write-Verbose "[$(getCurrentUTCString)]: Query: $query"
  Write-Verbose "[$(getCurrentUTCString)]: Request URI: $uri"

  $retryCount = 0
  $success = $false
  $result = $null

  do {
    try {
      $retryCount++
      Write-Verbose "[$(getCurrentUTCString)]: Attempt $retryCount/$maxRetries"

      $response = Invoke-WebRequest -Uri $uri -Method POST -Headers $headers -Body $jsonBody -TimeoutSec $timeoutSeconds

      if ($response.StatusCode -eq 200) {
        $result = ($response.Content | ConvertFrom-Json -Depth 99)
        $success = $true
        Write-Verbose "[$(getCurrentUTCString)]: Successfully retrieved $($result.count) resources from Azure Resource Graph"

        # Handle truncated results
        if ($result.truncated -eq $true) {
          Write-Warning "[$(getCurrentUTCString)]: Results were truncated. Consider using pagination or refining your query."
        }

        # Return the data array which contains the actual results
        return $result.data
      } else {
        Write-Warning "[$(getCurrentUTCString)]: Unexpected status code: $($response.StatusCode)"
      }
    } catch {
      $statusCode = $null
      if ($_.Exception.Response) {
        $statusCode = [int]$_.Exception.Response.StatusCode
      }

      Write-Verbose "[$(getCurrentUTCString)]: Error occurred during Azure Resource Graph query"
      Write-Verbose "[$(getCurrentUTCString)]: HTTP Status Code: $statusCode"
      Write-Verbose "[$(getCurrentUTCString)]: Error: $($_.Exception.Message)"

      # Handle specific error scenarios
      if ($statusCode -eq 429 -or $statusCode -eq 503) {
        # Rate limiting or service unavailable - retry with exponential backoff
        if ($retryCount -lt $maxRetries) {
          $waitSeconds = [math]::Pow(2, $retryCount) + (Get-Random -Minimum 1 -Maximum 5)
          Write-Verbose "[$(getCurrentUTCString)]: Rate limited or service unavailable. Waiting $waitSeconds seconds before retry."
          Start-Sleep -Seconds $waitSeconds
        }
      } elseif ($statusCode -eq 400) {
        # Bad request - don't retry
        Write-Error "[$(getCurrentUTCString)]: Bad request. Please check your query syntax and parameters."
        return $null
      } elseif ($statusCode -eq 401 -or $statusCode -eq 403) {
        # Authentication/authorization error - don't retry
        Write-Error "[$(getCurrentUTCString)]: Authentication or authorization failed. Please check your permissions."
        return $null
      } else {
        # Other errors - retry with standard backoff
        if ($retryCount -lt $maxRetries) {
          $waitSeconds = Get-Random -Minimum 5 -Maximum 15
          Write-Verbose "[$(getCurrentUTCString)]: Retrying in $waitSeconds seconds..."
          Start-Sleep -Seconds $waitSeconds
        }
      }
    }
  } while ($retryCount -lt $maxRetries -and !$success)

  if (!$success) {
    Write-Error "[$(getCurrentUTCString)]: Failed to query Azure Resource Graph after $maxRetries attempts."
    return $null
  }

  return $result
}

#Function goes through the actual configuration and returns the value of the property
function getActualConfigPropertyValue {
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory = $true)][object]$actualConfig,
    [Parameter(Mandatory = $true)][string]$propertyToCheck
  )
  $propertyChain = $propertyToCheck -split ('\.')
  $actualValue = $actualConfig
  $arrayValues = @()
  $iWildCardProcessed = 0
  foreach ($p in $propertyChain) {
    if ($p -match '\[\*\]$' -and $iWildCardProcessed -eq 0) {
      $iWildCardProcessed++
      Write-Verbose "[$(getCurrentUTCString)]: Wildcard detected in the property chain. Processing all elements in the array $p." -verbose
      foreach ($v in $actualValue) {
        $propertyName = $p -replace '\[\*\]$', ''
        $arrayValues += $v.$propertyName
      }
    } else {
      if ($arrayValues.count -gt 0) {
        $i = 0
        foreach ($v in $arrayValues) {
          $arrayValues[$i] = $v.$p
          $i++
        }
      } else {
        $actualValue = $actualValue.$p
      }

    }
  }
  if ($arrayValues.count -gt 0) {
    $actualValue = $arrayValues
  }
  Write-verbose "Actual Value: $actualValue" -verbose
  $actualValue
}

#function to compare the count of properties in the actual configuration with the desired configuration
function comparePropertyCount {
  [CmdletBinding()]
  [OutputType([bool])]
  Param (
    [Parameter(Mandatory = $true)][object]$actualConfig,
    [Parameter(Mandatory = $true)][object]$desiredConfig
  )
  $count = @()
  $totalCount = 0
  foreach ($p in $desiredConfig.property) {
    $actualValue = getActualConfigPropertyValue -actualConfig $actualConfig -propertyToCheck $p
    $count += $actualValue.count
    $totalCount = $totalCount + $actualValue.count
  }
  $comparisonResult = $false

  switch ($desiredConfig.condition) {
    'equals' {
      $individualResults = $count | Foreach-Object { $_ -eq $($desiredConfig.count) } | get-unique
      $concatResult = $totalCount -eq $($desiredConfig.count)
    }
    'notEquals' {
      $individualResults = $count | Foreach-Object { $_ -ne $($desiredConfig.count) } | get-unique
      $concatResult = $totalCount -ne $($desiredConfig.count)
    }
    'greater' {
      $individualResults = $count | Foreach-Object { $_ -gt $($desiredConfig.count) } | get-unique
      $concatResult = $totalCount -gt $($desiredConfig.count)
    }
    'less' {
      $individualResults = $count | Foreach-Object { $_ -lt $($desiredConfig.count) } | get-unique
      $concatResult = $totalCount -lt $($desiredConfig.count)
    }
    'greaterequal' {
      $individualResults = $count | Foreach-Object { $_ -ge $($desiredConfig.count) } | get-unique
      $concatResult = $totalCount -ge $($desiredConfig.count)
    }
    'lessequal' {
      $individualResults = $count | Foreach-Object { $_ -le $($desiredConfig.count) } | get-unique
      $concatResult = $totalCount -le $($desiredConfig.count)
    }
  }
  if ($desiredConfig.property.count -gt 1) {
    if ($desiredConfig.operator -eq 'and') {
      Write-Verbose "[$(getCurrentUTCString)]: Check if the the count for every property $($desiredConfig.condition) to $($desiredConfig.count)" -Verbose
      if ($individualResults -eq $true) { $comparisonResult = $true }
    } elseif ($desiredConfig.operator -eq 'or') {
      Write-Verbose "[$(getCurrentUTCString)]: Check if the the count for any properties $($desiredConfig.condition) to $($desiredConfig.count)" -Verbose
      if ($individualResults -ne $false) { $comparisonResult = $true }

    } elseif ($desiredConfig.operator -eq 'concat') {
      Write-Verbose "[$(getCurrentUTCString)]: Check if the count of combination of all properties $($desiredConfig.condition) to $($desiredConfig.count)" -Verbose
      $comparisonResult = $concatResult
    }
  } else {
    $comparisonResult = $individualResults
  }
  $comparisonResult
}

#function to compare the value of a property in the actual configuration with the desired configuration
function comparePropertyValue {
  [CmdletBinding()]
  [OutputType([bool])]
  Param (
    [Parameter(Mandatory = $true)][object]$actualConfig,
    [Parameter(Mandatory = $true)][object]$desiredConfig
  )
  switch ($desiredConfig.valueType) {
    'string' {
      $desiredValue = $desiredConfig.value
    }
    'number' {
      $desiredValue = [float]$desiredConfig.value
    }
    'boolean' {
      $desiredValue = [bool]::Parse($desiredConfig.value)
    }
  }
  $propertyToCheck = $desiredConfig.property
  $actualValue = getActualConfigPropertyValue -actualConfig $actualConfig -propertyToCheck $propertyToCheck
  Write-Verbose "[$(getCurrentUTCString)]: The resource configuration for $propertyToCheck is '$actualValue'" -Verbose
  $comparisonResults = @()
  foreach ($v in $actualValue) {
    switch ($desiredConfig.condition) {
      'equals' {
        Write-Verbose "[$(getCurrentUTCString)]: Check if the actual value '$v' equals (-eq) to the desired value '$desiredValue'" -Verbose
        $comparisonResults += $v -eq $desiredValue
      }
      'notEquals' {
        Write-Verbose "[$(getCurrentUTCString)]: Check if the actual value '$v' not equals (-ne) to the desired value '$desiredValue'" -Verbose
        $comparisonResults += $v -ne $desiredValue
      }
      'greater' {
        Write-Verbose "[$(getCurrentUTCString)]: Check if the actual value '$v' is greater than (-gt) the desired value '$desiredValue'" -Verbose
        $comparisonResults += $v -gt $desiredValue
      }
      'less' {
        Write-Verbose "[$(getCurrentUTCString)]: Check if the actual value '$v' is less than (-lt) the desired value '$desiredValue'" -Verbose
        $comparisonResults += $v -lt $desiredValue
      }
      'greaterequal' {
        Write-Verbose "[$(getCurrentUTCString)]: Check if the actual value '$v' is greater than or equal to (-ge) the desired value '$desiredValue'" -Verbose
        $comparisonResults += $v -ge $desiredValue
      }
      'lessequal' {
        Write-Verbose "[$(getCurrentUTCString)]: Check if the actual value '$v' is less than or equal to (-le) the desired value '$desiredValue'" -Verbose
        $comparisonResults += $v -le $desiredValue
      }
      'match' {
        Write-Verbose "[$(getCurrentUTCString)]: Check if the actual value '$v' matches (-match) the desired value '$desiredValue'" -Verbose
        $comparisonResults += $v -match $desiredValue
      }
      'notmatch' {
        Write-Verbose "[$(getCurrentUTCString)]: Check if the actual value '$v' does not match (-notmatch) the desired value '$desiredValue'" -Verbose
        $comparisonResults += $v -notmatch $desiredValue
      }
      'like' {
        Write-Verbose "[$(getCurrentUTCString)]: Check if the actual value '$v' is like (-like) the desired value '$desiredValue'" -Verbose
        $comparisonResults += $v -like $desiredValue
      }
      'notlike' {
        Write-Verbose "[$(getCurrentUTCString)]: Check if the actual value '$v' is not like (-notlike) the desired value '$desiredValue'" -Verbose
        $comparisonResults += $v -notlike $desiredValue
      }
    }
  }
  if ($comparisonResults.contains($false)) {
    $comparisonResult = $false
  } else {
    $comparisonResult = $true
  }
  Write-Verbose "[$(getCurrentUTCString)]: Comparison Result is $comparisonResult"
  $comparisonResult
}

#Determines the Azure Resource Graph table based on the resource type
function getARGTable {
  [CmdletBinding()]
  [OutputType([string])]
  param (
    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$resourceType
  )

  switch -Regex ($resourceType) {
    "^microsoft\.resources\/subscriptions$" { $table = "resourcecontainers" }
    # resource type for resource group is 'microsoft.resources/resourceGroups' but in ARG it is 'microsoft.resources/subscriptions/resourceGroups'
    "^microsoft\.resources\/(subscriptions\/)?resourcegroups$" { $table = "resourcecontainers"; $resourceType = "microsoft.resources/subscriptions/resourcegroups" }
    "^microsoft\.management\/managementgroups$" { $table = "resourcecontainers" }
    "^microsoft\.authorization\/(policyassignment|policydefinition|policysetdefinition|policyexemptions|policystates|policymetadata)$" { $table = "policyresources" }
    "^microsoft\.insights\/(datacollectionruleassociations|tenantactiongroups)$" { $table = "insightsresources" }
    "^microsoft\.web\/sites\/(config|workflows)$" { $table = "appserviceresources" }
    "^microsoft\.web\/sites\/slots\/config$" { $table = "appserviceresources" }
    "^microsoft\.authorization\/(roleassignments|roledefinitions)$" { $table = "authorizationresources" }
    "^microsoft\.network\/(private)?dnszones\/\D+$" { $table = "dnsresources" }
    "^microsoft\.compute\/virtualmachinescalesets\/virtualmachines$" { $table = "computeresources" }
    default { $table = "resources" }
  }

  $table
}

#Function to check if a resource exists in Azure. Use the method parameter to specify using Azure Resource Graph or Resource Provider API
function checkResourceExistence {
  [CmdletBinding()]
  [OutputType([bool])]
  Param (
    [Parameter(Mandatory = $true)][object]$desiredConfig
  )
  $resourceExists = $false
  if (!$desiredConfig.apiVersion) {

    $resourceType = getResourceType -resourceId $($desiredConfig.resourceId)
    $table = getARGTable -resourceType $resourceType
    Write-Verbose "[$(getCurrentUTCString)]: Searching resource '$($desiredConfig.resourceId)' (resource type '$resourceType') in Azure resource graph table '$table'." -verbose
    $query = @"
$table
| where id =~ '$($desiredConfig.resourceId)'
"@
    $QueryResult = invokeARGQuery -query $query -scopeType 'tenant' -token $desiredConfig.token
    #should only return $true when there is exactly 1 resource found.
    if ($QueryResult.count -eq 1) { $resourceExists = $true }
  } else {

    Write-Verbose "[$(getCurrentUTCString)]: Trying getting resource via the Resource provider API" -Verbose
    $params = @{
      resourceId = $desiredConfig.resourceId
      apiVersion = $desiredConfig.apiVersion
      token      = $desiredConfig.token
    }

    $resource = getResourceViaARMAPI @params
    if ($resource) {
      $resourceExists = $true
    } else {
      $resourceExists = $false
    }
  }
  Write-Verbose "[$(getCurrentUTCString)]: Resource exists: $resourceExists" -verbose
  #compare resource existence with condition
  if ($desiredConfig.condition -ieq 'exists') {
    $resourceExists
  } else {
    !$resourceExists
  }
}

#function to get resource via ARM api using a HTTP GET request
function getResourceViaARMAPI {
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory = $true)][string]$resourceId,
    [Parameter(Mandatory = $true)][string]$apiVersion,
    [Parameter(Mandatory = $true)][string]$token
  )
  $uri = "https://management.azure.com{0}?api-version={1}" -f $resourceId, $apiVersion
  Write-Verbose "[$(getCurrentUTCString)]: Trying getting resource via the Resource provider API endpoint '$uri'" -Verbose

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

#function to get the compliance state of a resource via Azure Resource Graph
function getResourcePolicyState {
  [CmdletBinding()]
  [OutputType([bool])]
  param (
    [Parameter(Mandatory = $true)][object]$desiredConfig
  )
  #firstly try to get the compliance state via the Azure Resource Graph query
  #build ARG query
  $query = @"
policyresources
| where type =~ 'microsoft.policyinsights/policystates'
| where properties.resourceId =~ '$($desiredConfig.resourceId)'
| extend complianceState = properties.complianceState
"@

  #add policyAssignmentId to the query
  if ($($desiredConfig.policyAssignmentId)) {
    $query = @"
$query
| where properties.policyAssignmentId =~ '$($desiredConfig.policyAssignmentId)'
"@
  }

  #add policyDefinitionReferenceId to the query
  if ($($desiredConfig.policyDefinitionReferenceId)) {
    $query = @"
$query
| where properties.policyDefinitionReferenceId =~ '$($desiredConfig.policyDefinitionReferenceId)'
"@
  }
  Write-Verbose "[$(getCurrentUTCString)]: Trying getting resource policy compliance state via Azure Resource Graph" -Verbose
  Write-Verbose "[$(getCurrentUTCString)]: The Azure Resource Graph query is:" -Verbose
  Write-Verbose $query -verbose

  #Invoke ARG query
  $QueryResult = invokeARGQuery -query $query -scopeType 'tenant' -token $desiredConfig.token
  $complianceStates = $QueryResult

  Write-verbose "[$(getCurrentUTCString)]: Number of policy state resources found: $($complianceStates.count)" -verbose
  #firstly set the return result to true. if any policy compliance state is not compliant, then set the result to false
  $result = $true
  if ($complianceStates.count -eq 0) {
    Write-Verbose "[$(getCurrentUTCString)]: No policy compliance state is found for '$($desiredConfig.resourceId)' via Azure Resource Graph.  Will fall back to Azure Policy Insights REST API." -Verbose
    $complianceStates = getResourcePolicyStateViaAPI -desiredConfig $desiredConfig -policyStateType 'latest'
  }
  if ($complianceStates.count -eq 0) {
    Write-Verbose "[$(getCurrentUTCString)]: No policy compliance state is found for '$($desiredConfig.resourceId) via Azure Policy Insights REST API'." -Verbose
    $result = $false
  } else {
    foreach ($c in $complianceStates) {
      Write-Verbose "[$(getCurrentUTCString)]: The compliance state of '$($c.properties.resourceId)' is '$($c.properties.complianceState)'. Required state is '$($desiredConfig.requiredComplianceState)'." -Verbose
      if ($c.complianceState -ine "$($desiredConfig.requiredComplianceState)") {
        $result = $false
      }
    }
  }
  $result
}

#function to get the compliance state of a resource via Azure Resource Manager REST API
function getResourcePolicyStateViaAPI {
  [CmdletBinding()]
  [OutputType([bool])]
  param (
    [Parameter(Mandatory = $true)][object]$desiredConfig,
    [Parameter(Mandatory = $false, HelpMessage = "'latest' represents the latest policy state(s), whereas 'default' represents all policy state(s)")]
    [ValidateSet('latest', 'default')]
    [string]$policyStateType = 'latest'
  )
  if ($($desiredConfig.policyAssignmentId)) {
    $uri = "https://management.azure.com{0}/providers/Microsoft.PolicyInsights/policyStates/{1}/queryResults?api-version=2019-10-01&`$filter=policyAssignmentId eq '{2}'" -f $($desiredConfig.resourceId), $policyStateType, $($desiredConfig.policyAssignmentId)
  } else {
    $uri = "https://management.azure.com{0}/providers/Microsoft.PolicyInsights/policyStates/{1}/queryResults?api-version=2019-10-01" -f $($desiredConfig.resourceId), $policyStateType
  }

  Write-Verbose "[$(getCurrentUTCString)]: Trying getting resource policy compliance state via the Azure Policy Insights API endpoint '$uri'" -Verbose
  $headers = @{
    'Authorization' = "Bearer $($desiredConfig.token)"
  }
  try {
    $request = Invoke-WebRequest -Uri $uri -Method "POST" -Headers $headers
    if ($request.StatusCode -ge 200 -and $request.StatusCode -lt 300) {
      $policyStates = ($request.Content | ConvertFrom-Json -Depth 99).value
    }
  } catch {
    Throw "[$(getCurrentUTCString)]: Failed to get policy state for resource '$($desiredConfig.resourceId)' via Azure Policy Insights REST API. Error: $($_.Exception.Message)"
  }
  if ($policyStates) {
    Write-Verbose "[$(getCurrentUTCString)]: $($policyStates.count) policy states returned." -Verbose
    if ($($desiredConfig.policyDefinitionReferenceId)) {
      Write-Verbose "[$(getCurrentUTCString)]: Filter on the policyDefinitionReferenceId." -Verbose
      $policyStates = $policyStates | Where-Object { $_.policyDefinitionReferenceId -ieq $($desiredConfig.policyDefinitionReferenceId) }
    }
  } else {
    Write-Verbose "[$(getCurrentUTCString)]: No policy states returned." -Verbose
  }
  $policyStates
}

#function to determine resource type based on the resource id
function getResourceType {
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory = $true)][string]$resourceId
  )

  $commonResourceTypeRegex = '^\/\S+\/providers\/([a-zA-Z]+\.[a-zA-Z]+\/[a-zA-Z]+)\/(\S+)$' # matches /subscriptions/.../resourceGroups/.../providers/Microsoft.Compute/virtualMachines/...
  $resourceGroupRegex = '^\/subscriptions\/[{]?[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}[}]?\/resourceGroups\/[-\w\._\(\)]+$'
  $subscriptionRegex = '^\/subscriptions\/[{]?[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}[}]?$'
  $managementGroupRegex = '^\/providers\/Microsoft.Management\/managementGroups\/(\S+)$'
  switch -regex ($resourceId) {
    $commonResourceTypeRegex {
      $match = Select-string -InputObject $resourceId -Pattern $commonResourceTypeRegex
      $resourceType = $match.Matches.Groups[1].Value
      #try to figure out if the resource type is a child resource type
      $regexMatchGroup2 = $match.Matches.Groups[2].Value
      $sections = $regexMatchGroup2 -split ('/')
      for ($i = 0; $i -lt $sections.count; $i++) {
        if ($($i % 2) -eq 1) {
          #if the index is odd, then it is a part of the resource type
          $resourceType = '{0}/{1}' -f $resourceType, $sections[$i]
        }
      }
    }
    $resourceGroupRegex {
      $resourceType = 'Microsoft.Resources/Subscriptions/ResourceGroups' #resource type in ARG is 'microsoft.resources/subscriptions/resourcegroups'
    }
    $subscriptionRegex {
      $resourceType = 'Microsoft.Resources/Subscriptions' #resource type in ARG is 'microsoft.resources/subscriptions'
    }
    $managementGroupRegex {
      $resourceType = 'Microsoft.Management/ManagementGroups'
    }
    default {
      Write-Error "[$(getCurrentUTCString)]: Unable to detect the resource type for '$resourceId'."
    }
  }
  $resourceType
}

#function to get the current UTC time
function getCurrentUTCString {
  "$([DateTime]::UtcNow.ToString('u')) UTC"
}

#function to process the policy violation
function processPolicyViolation {
  [CmdletBinding()]
  [OutputType([bool])]
  param (
    [Parameter(Mandatory = $true)][object]$desiredPolicyViolation,
    [Parameter(Mandatory = $true)][object]$actualPolicyViolations
  )
  $bPolicyViolationMatch = $true
  foreach ($p in $desiredPolicyViolation) {
    if ($p.policyDefinitionReferenceId) {
      Write-Verbose "[$(getCurrentUTCString)]: Looking for policy violation for policy assignment '$($p.policyAssignmentId)' and policy definition reference id '$($p.policyDefinitionReferenceId)'." -verbose
      $matchingViolation = $actualPolicyViolations | where-object { $_.info.policyAssignmentId -ieq $p.policyAssignmentId -and $_.info.policyDefinitionReferenceId -ieq $p.policyDefinitionReferenceId }
    } else {
      Write-Verbose "[$(getCurrentUTCString)]: Looking for policy violation for policy assignment '$($p.policyAssignmentId)'." -verbose
      $matchingViolation = $actualPolicyViolations | where-object { $_.info.policyAssignmentId -ieq $p.policyAssignmentId }
    }

    if (!$matchingViolation) {
      $bPolicyViolationMatch = $false
      if ($p.policyDefinitionReferenceId) {
        Write-Verbose "[$(getCurrentUTCString)]: Policy violation not found for policy assignment '$($p.policyAssignmentId)' and policy definition reference id '$($p.policyDefinitionReferenceId)'" -verbose
      } else {
        Write-Verbose "[$(getCurrentUTCString)]: Policy violation not found for policy assignment '$($p.policyAssignmentId)'" -verbose
      }
    } else {
      if ($p.policyDefinitionReferenceId) {
        Write-Verbose "[$(getCurrentUTCString)]: Policy violation found for policy assignment '$($p.policyAssignmentId)' and policy definition reference id '$($p.policyDefinitionReferenceId)'" -verbose
      } else {
        Write-Verbose "[$(getCurrentUTCString)]: Policy violation found for policy assignment '$($p.policyAssignmentId)'" -verbose
      }
    }
  }
  $bPolicyViolationMatch
}

#function to compare the actual configuration of a resource with the desired configuration
function getResourceConfig {
  [CmdletBinding()]
  [OutputType([object])]
  Param (
    [Parameter(Mandatory = $true)][string]$resourceId,
    [Parameter(Mandatory = $true)][string]$token,
    [Parameter(Mandatory = $false)][string]$resourcetype,
    [Parameter(Mandatory = $false)][string]$apiVersion
  )
  if ($apiVersion) {
    Write-Verbose "[$(getCurrentUTCString)]: API Version is specified, get current configuration for: $resourceId via ARM Rest API" -verbose
    $config = getResourceViaARMAPI -resourceId $resourceId -apiVersion $apiVersion -token $token
    if (!$config) {
      Write-Error "[$(getCurrentUTCString)]: Failed to get the current configuration for: $resourceId via ARM Rest API"
      Exit 1
    }
  } else {
    Write-Verbose "[$(getCurrentUTCString)]: API Version is not specified, get current configuration for: $resourceId via Azure Resource Graph query" -verbose
    Write-Verbose "[$(getCurrentUTCString)]: Detecting resource type for: $resourceId" -Verbose
    if ($resourcetype) {
      $resourceType = $resourcetype
    } else {
      $resourceType = getResourceType -resourceId $resourceId
    }
    Write-Verbose "[$(getCurrentUTCString)]: Resource type: $resourceType" -Verbose
    Write-Verbose "[$(getCurrentUTCString)]: Get current configuration for: $resourceId" -verbose
    $config = Get-ARTResourceConfiguration -ScopeType 'tenant' -resourceType $resourceType -Token $token -resourceIds $resourceId | convertfrom-Json -depth 99
  }
  $config
}

#function to compare resource configuration
function compareResourceConfiguration {
  [CmdletBinding()]
  [OutputType([bool])]
  Param (
    [Parameter(Mandatory = $true, ParameterSetName = 'propertyValue', Position = 0)]
    [PropertyValueTestConfig]$propertyValueTestConfig,

    [Parameter(Mandatory = $true, ParameterSetName = 'propertyCount', Position = 0)]
    [PropertyCountTestConfig]$propertyCountTestConfig,

    [Parameter(Mandatory = $true, ParameterSetName = 'policyState', Position = 0)]
    [PolicyStateTestConfig]$policyStateConfig,

    [Parameter(Mandatory = $true, ParameterSetName = 'resourceExistence', Position = 0)]
    [ResourceExistenceTestConfig]$resourceExistenceTestConfig,

    [Parameter(Mandatory = $true, ParameterSetName = 'whatIfDeployment', Position = 0)]
    [WhatIfDeploymentTestConfig]$WhatIfDeploymentTestConfig,

    [Parameter(Mandatory = $true, ParameterSetName = 'terraform', Position = 0)]
    [TerraformPolicyRestrictionTestConfig]$TerraformPolicyRestrictionTestConfig,

    [Parameter(Mandatory = $true, ParameterSetName = 'armPolicyRestriction', Position = 0)]
    [ArmPolicyRestrictionTestConfig]$ArmPolicyRestrictionTestConfig,

    [Parameter(Mandatory = $true, ParameterSetName = 'manualWhatIfValidation', Position = 0)]
    [ManualWhatIfTestConfig]$ManualWhatIfTestConfig

  )

  if ($PSCmdlet.ParameterSetName -eq 'propertyValue') {
    Write-Verbose "[$(getCurrentUTCString)]: Property Value comparison for $($propertyValueTestConfig.property)" -verbose
    #Get the actual configuration of the resource
    $getActualConfigParams = @{
      resourceId = $propertyValueTestConfig.resourceId
      apiVersion = $propertyValueTestConfig.apiVersion
      token      = $propertyValueTestConfig.token
    }
    if ($propertyValueTestConfig.resourceType) {
      $getActualConfigParams.add('resourcetype', $propertyValueTestConfig.resourceType)
    }
    if ($propertyValueTestConfig.apiversion) {
      $getActualConfigParams.add('apiversion', $propertyValueTestConfig.apiversion)
    }
    $actualConfig = getResourceConfig @getActualConfigParams
    $comparisonResult = comparePropertyValue -actualConfig $actualConfig -desiredConfig $propertyValueTestConfig -verbose
  }
  if ($PSCmdlet.ParameterSetName -eq 'propertyCount') {
    Write-Verbose "[$(getCurrentUTCString)]: Property count comparison for $($propertyCountTestConfig.property -join ',')" -verbose
    #Get the actual configuration of the resource
    $getActualConfigParams = @{
      resourceId = $propertyCountTestConfig.resourceId
      token      = $propertyCountTestConfig.token
    }
    if ($propertyCountTestConfig.resourceType) {
      $getActualConfigParams.add('resourcetype', $propertyCountTestConfig.resourceType)
    }
    if ($propertyCountTestConfig.apiversion) {
      $getActualConfigParams.add('apiversion', $propertyCountTestConfig.apiversion)
    }
    $actualConfig = getResourceConfig @getActualConfigParams
    $comparisonResult = comparePropertyCount -actualConfig $actualConfig -desiredConfig $propertyCountTestConfig -verbose
  }
  if ($PSCmdlet.ParameterSetName -eq 'policyState') {
    Write-Verbose "[$(getCurrentUTCString)]: Policy State validation for $($policyStateConfig.resourceId)" -verbose
    $comparisonResult = getResourcePolicyState -desiredConfig $policyStateConfig -verbose
  }
  if ($PSCmdlet.ParameterSetName -eq 'resourceExistence') {
    Write-Verbose "[$(getCurrentUTCString)]: Resource existence check for $($resourceExistenceTestConfig.resourceId)" -verbose
    $comparisonResult = checkResourceExistence -desiredConfig $resourceExistenceTestConfig -verbose
  }
  if ($PSCmdlet.ParameterSetName -eq 'whatIfDeployment') {
    Write-Verbose "[$(getCurrentUTCString)]: Template WhatIf Deployment Validation for $($WhatIfDeploymentTestConfig.templateFilePath)" -verbose
    $comparisonResult = getWhatIfDeploymentResult -desiredConfig $WhatIfDeploymentTestConfig -verbose
  }

  if ($PSCmdlet.ParameterSetName -eq 'manualWhatIfValidation') {
    Write-Verbose "[$(getCurrentUTCString)]: Manual WhatIf Result Validation for '$($ManualWhatIfTestConfig.testName)'" -verbose
    $comparisonResult = processPolicyViolation -desiredPolicyViolation $ManualWhatIfTestConfig.desiredPolicyViolation -actualPolicyViolations $ManualWhatIfTestConfig.actualPolicyViolation -verbose
  }

  if ($PSCmdlet.ParameterSetName -eq 'terraform') {
    Write-Verbose "[$(getCurrentUTCString)]: Terraform Policy Restriction validation for $($TerraformPolicyRestrictionTestConfig.testName)" -verbose
    $comparisonResult = checkTerraformPolicyRestriction -desiredConfig $TerraformPolicyRestrictionTestConfig -verbose
  }

  if ($PSCmdlet.ParameterSetName -eq 'armPolicyRestriction') {
    Write-Verbose "[$(getCurrentUTCString)]: Arm Policy Restriction validation for $($ArmPolicyRestrictionTestConfig.testName)" -verbose
    $comparisonResult = checkArmPolicyRestriction -desiredConfig $ArmPolicyRestrictionTestConfig -verbose
  }

  Write-Verbose "[$(getCurrentUTCString)]: Comparison result: $comparisonResult" -verbose
  $comparisonResult
}

#function to get policy restriction for a specific azure resource
Function getAzPolicyRestriction {
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  Param (
    [Parameter(Mandatory = $true, HelpMessage = 'The resource id of the deployment scope.')]
    [ValidateNotNullOrEmpty()]
    [string]$scopeResourceId,

    [Parameter(Mandatory = $false, HelpMessage = 'The list of fields (name, location, tags and type) and values (name, location must contain values, type value is optional. tags must not contain values.) that should be evaluated for potential restrictions.')]
    [Hashtable[]]$pendingFields,

    [Parameter(Mandatory = $false, HelpMessage = "Whether to include policies with the 'audit' effect in the results.")]
    [bool]$includeAuditEffect = $true,

    [Parameter(Mandatory = $false, HelpMessage = 'The api-version of the resource content.')]
    [string]$resourceApiVersion,

    [Parameter(Mandatory = $false, HelpMessage = 'The resource content. This should include whatever properties are already known and can be a partial set of all resource properties.')]
    [hashtable]$resourceContent,

    [Parameter(Mandatory = $false, HelpMessage = "The scope where the resource is being created. For example, if the resource is a child resource this would be the parent resource's resource ID.")]
    [string]$resourceScope,

    [Parameter(Mandatory = $true)]
    [string]$token
  )
  $mgResourceIdRegex = '(?im)^\/providers\/microsoft\.management\/managementgroups\/(\S+)'
  $subResourceIdRegex = '(?im)^\/subscriptions\/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})$'
  $resourceGroupResourceIdRegex = '(?im)^\/subscriptions\/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\/resourcegroups/([a-zA-Z0-9_\-().]{0,89}[a-zA-Z0-9_\-()])$'

  #determine the scope type and name of the deployment scope
  If ($scopeResourceId -match $mgResourceIdRegex) {
    #deployment scope is a management group
    $scopeType = 'mg'
    $managementGroupName = $scopeResourceId -replace $mgResourceIdRegex, '$1'
  } elseif ($scopeResourceId -match $subResourceIdRegex) {
    #deployment scope is a subscription
    $scopeType = 'sub'
    $subscriptionId = $scopeResourceId -replace $subResourceIdRegex, '$1'
  } elseif ($scopeResourceId -match $resourceGroupResourceIdRegex) {
    #deployment scope is a resource group
    $scopeType = 'rg'
    $subscriptionId = $scopeResourceId -replace $resourceGroupResourceIdRegex, '$1'
    $resourceGroupName = $scopeResourceId -replace $resourceGroupResourceIdRegex, '$2'
  } else {
    Write-Error "[$(getCurrentUTCString)]: Invalid scope resource id '$scopeResourceId'. It must be a valid management group, subscription or resource group resource id."
    exit -1
  }
  #as of July 2025, the API version for policy restriction is '2024-10-01': https://github.com/Azure/azure-rest-api-specs/blob/main/specification/policyinsights/resource-manager/Microsoft.PolicyInsights/stable/2024-10-01/checkPolicyRestrictions.json'
  $apiVersion = '2024-10-01'
  Switch ($scopeType) {
    'mg' { $uri = 'https://management.azure.com/providers/Microsoft.Management/managementGroups/{0}/providers/Microsoft.PolicyInsights/checkPolicyRestrictions?api-version={1}' -f $ManagementGroupName, $apiVersion }
    'sub' { $uri = 'https://management.azure.com/subscriptions/{0}/providers/Microsoft.PolicyInsights/checkPolicyRestrictions?api-version={1}' -f $SubscriptionId, $apiVersion }
    'rg' { $uri = 'https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.PolicyInsights/checkPolicyRestrictions?api-version={2}' -f $SubscriptionId, $resourceGroupName, $apiVersion }
  }
  Write-Verbose "Request URI: '$uri'" -verbose

  $headers = @{
    Authorization  = "Bearer $token"
    'Content-Type' = 'application/json'
  }
  if ($scopeType -eq 'mg') {
    $body = @{
      pendingFields = @(@{field = 'type' })
    }
  } else {
    $arrPendingFields = @()
    foreach ($pendingField in $pendingFields) {
      $arrPendingFields += $pendingField
    }
    $body = @{
      pendingFields      = $arrPendingFields
      includeAuditEffect = $includeAuditEffect
    }

    $resourceDetails = @{
      apiVersion = $resourceApiVersion
    }
    $resourceDetails.Add('resourceContent', $resourceContent)
    if ($PSBoundParameters.ContainsKey('resourceScope')) {
      $resourceDetails.add('scope', $resourceScope)
    }
    $body.add('resourceDetails', $resourceDetails)
  }

  $jsonBody = $body | ConvertTo-Json -Depth 100
  Write-Verbose "Request Body:" -verbose
  Write-Verbose $jsonBody -verbose
  $request = Invoke-WebRequest -method POST -Uri $uri -Headers $headers -body $jsonBody
  $result = $request.Content | ConvertFrom-Json
  $result
}

#function to check if the resource Id belongs to a resource container (resource group, subscription or management group)
Function isResourceContainer {
  [CmdletBinding()]
  [OutputType([bool])]
  Param (
    [Parameter(Mandatory = $true, HelpMessage = 'The resource Id to check.')]
    [ValidateNotNullOrEmpty()]
    [string]$resourceId
  )
  $mgResourceIdRegex = '(?im)^\/providers\/microsoft\.management\/managementgroups\/(\S+)'
  $subResourceIdRegex = '(?im)^\/subscriptions\/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})$'
  $resourceGroupResourceIdRegex = '(?im)^\/subscriptions\/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\/resourcegroups/([a-zA-Z0-9_\-().]{0,89}[a-zA-Z0-9_\-()])$'
  if ($resourceId -match $resourceGroupResourceIdRegex -or $resourceId -match $subResourceIdRegex -or $resourceId -match $mgResourceIdRegex) {
    return $true
  } else {
    return $false
  }
}

#function to check if a string is a valid resource Id
Function isValidResourceId {
  [CmdletBinding()]
  [OutputType([bool])]
  Param (
    [Parameter(Mandatory = $true, HelpMessage = 'The resource Id to check.')]
    [ValidateNotNullOrEmpty()]
    [string]$resourceId
  )
  $tenantScopedIdRegex = '(?im)^\/providers\/microsoft\.(\S+)'
  $mgScopedIdRegex = '(?im)^\/providers\/microsoft\.management\/managementgroups\/(\S+)'
  $subAndRgScopedIdRegex = '(?im)^\/subscriptions\/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\/(\S+)$'
  if ($resourceId -match $tenantScopedIdRegex -or $resourceId -match $mgScopedIdRegex -or $resourceId -match $subAndRgScopedIdRegex) {
    return $true
  } else {
    return $false
  }
}

#function to check resource configuration against the policy restrictions API
Function processPolicyRestrictionAPIResult {
  [CmdletBinding()]
  [OutputType([bool])]
  param (
    [Parameter(Mandatory = $true)][PolicyRestrictionViolationInfo[]]$desiredPolicyViolations,
    [Parameter(Mandatory = $true)][array]$actualRestrictionForResource
  )
  $bMatchingPolicyViolation = $true
  foreach ($desiredPolicyViolation in $desiredPolicyViolations) {
    #check if the policy restriction result returned from Azure Policy Restriction API matches desired policy violation
    $resourceReference = $desiredPolicyViolation.resourceReference
    $policyEffect = $desiredPolicyViolation.policyEffect
    $policyAssignmentId = $desiredPolicyViolation.policyAssignmentId
    $policyDefinitionReferenceId = $desiredPolicyViolation.policyDefinitionReferenceId ? $desiredPolicyViolation.policyDefinitionReferenceId : $null
    Write-Verbose "[$(getCurrentUTCString)]: Checking policy restriction for '$resourceReference':" -Verbose
    Write-Verbose "  - Policy assignment Id: '$($desiredPolicyViolation.policyAssignmentId)'"
    if ($policyDefinitionReferenceId) {
      Write-Verbose "  - Policy definition reference Id: '$policyDefinitionReferenceId'"
    } else {
      Write-Verbose "  - No policy definition reference Id specified."
    }
    if ($resourceReference) {
      Write-Verbose "  - Resource reference: '$resourceReference'" -Verbose
    } else {
      Write-Verbose "  - No resource reference specified." -Verbose
    }
    if ($policyEffect) {
      Write-Verbose "  - Policy effect: '$policyEffect'" -Verbose
    } else {
      Write-Verbose "  - No policy effect specified." -Verbose
    }
    if ($actualRestrictionForResource.count -gt 0) {
      Write-Verbose "  - [$(getCurrentUTCString)]: Policy Restriction result contains policy restriction information for resource reference '$resourceReference'." -verbose
      #Write-Verbose $($actualRestrictionForResource | ConvertTo-Json -Depth 99) -verbose
      $actualFieldRestrictionForResource = $actualRestrictionForResource.policyRestrictions.fieldRestrictions
      $actualContentEvaluationResultForResource = $actualRestrictionForResource.policyRestrictions.contentEvaluationResult.policyEvaluations
      #check fieldRestrictions first
      foreach ($f in $actualFieldRestrictionForResource) {
        foreach ($r in $f.restrictions) {
          if ($r.policyEffect -ieq $policyEffect -and
            $r.policy.policyAssignmentId -ieq $policyAssignmentId -and
            ($policyDefinitionReferenceId ? $r.policy.policyDefinitionReferenceId -ieq $policyDefinitionReferenceId : $true)) {
            $matchingFieldRestriction = $true
            break
          }
        }
      }
      #then check contentEvaluationResult
      if (!$matchingFieldRestriction) {
        Write-Verbose "  - [$(getCurrentUTCString)]: No matching field restriction found for resource reference '$resourceReference'. Checking content evaluation result." -verbose

        $matchingContentEvaluationResult = $actualContentEvaluationResultForResource | Where-Object {
          $_.policyInfo.policyDefinitionEffect -ieq $policyEffect -and
          $_.policyInfo.policyAssignmentId -ieq $policyAssignmentId -and
          $_.policyInfo.policyDefinitionReferenceId -ieq $policyDefinitionReferenceId
        }
      } else {
        Write-Verbose "  - [$(getCurrentUTCString)]: Found matching field restriction for resource reference '$resourceReference'." -verbose
      }
      if ($matchingContentEvaluationResult) {
        Write-Verbose "  - [$(getCurrentUTCString)]: Found matching content evaluation result for resource reference '$resourceReference'." -verbose
        #Write-Verbose $($matchingContentEvaluationResult | ConvertTo-Json -Depth 99) -verbose
      }
      if (!$matchingFieldRestriction -and !$matchingContentEvaluationResult) {
        Write-Verbose "  - [$(getCurrentUTCString)]: No matching policy restriction found for resource reference '$resourceReference'." -verbose
        $bMatchingPolicyViolation = $false
      } else {
        Write-Verbose "  - [$(getCurrentUTCString)]: Matching policy restriction found for resource reference '$resourceReference'." -verbose
      }
    } else {
      Write-Verbose "  - [$(getCurrentUTCString)]: Policy Restriction for resource reference '$resourceReference' not found." -verbose
      $bMatchingPolicyViolation = $false
    }
    Write-Verbose "Matching policy result so far: $bMatchingPolicyViolation" -verbose
  }
  #return true if all the desired policy violations are matched with the actual policy violation
  $bMatchingPolicyViolation
}

#bicep helper functions

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

#Terraform helper functions

#Function to check if Terraform is initialized
function isTFInitialized {
  [CmdletBinding()]
  [OutputType([bool])]
  param (
    [Parameter(Mandatory = $true)]
    [string]$path
  )
  $isInit = $true
  $tfLockFile = Join-Path -Path $path -ChildPath ".terraform.lock.hcl"
  $tfChildDir = Join-Path -Path $path -ChildPath ".terraform"
  if ( -not (Test-Path -Path $tfLockFile -PathType Leaf)) {
    $isInit = $false
  }
  if ( -not (Test-Path -Path $tfChildDir -PathType Container)) {
    $isInit = $false
  }
  $isInit
}

#Function to find the .tfvars file in the specified path
function findTFVarsFile {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string]$path
  )
  $tfVarsFile = Get-ChildItem -Path $path -Filter "*.tfvars" -Recurse -ErrorAction SilentlyContinue
  if ($tfVarsFile) {
    return $tfVarsFile.name
  } else {
    Write-Verbose "No .tfvars file found in the specified path: $path."
    return $null
  }
}

#Function to run Terraform plan and convert the output to JSON
function getTFPlanResult {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [validateScript({ Test-Path $_ -PathType Container })]
    [string]$path
  )

  #Make sure the Terraform template is initialized
  $currentDir = Get-Location
  if (-not (isTFInitialized -path $path)) {
    Write-Verbose "Terraform is not initialized in the specified path: $path. Trying to initialize..."

    try {
      Set-Location -Path $path
      terraform init -input=false
      $exitCode = $?
      if ($exitCode -ne $true) {
        #set the location back to the original
        Set-Location -Path $currentDir
        Write-Error "Terraform initialization failed in the specified path: $path. Please check the output for details."
        Exit 1
      }
      #set the location back to the original
      Set-Location -Path $currentDir

    } catch {
      Write-Error "Failed to initialize Terraform in the specified path: $path. Error: $_. Try manually running 'terraform init' in the directory."
      #set the location back to the original
      Set-Location -Path $currentDir
      Exit 1
    }
  } else {
    Write-Verbose "Terraform is already initialized in the specified path: $path."
  }

  # Run the Terraform plan command
  # Check if a .tfvars file exists in the specified path
  $tfVarsFile = findTFVarsFile -path $path
  # If multiple .tfvars files are found, throw an error
  if ($tfVarsFile.Count -gt 1) {
    Write-Error "Multiple .tfvars files found in the specified path: $path. Please specify a single .tfvars file."
    Exit 1
  }
  $tfPlanFileName = "output.tfplan"
  $tfPlanFilePath = Join-Path -Path $path -ChildPath $tfPlanFileName
  if ($tfVarsFile) {
    Set-Location -Path $path
    Write-Verbose "Using .tfvars file: $tfVarsFile"
    terraform plan --var-file="$tfVarsFile" -out='output.tfplan' | out-null
  } else {
    Set-Location -Path $path
    Write-Verbose "No .tfvars file found. Running Terraform plan without variables."
    terraform plan -out='output.tfplan' | out-null
  }
  $tfplanExitCode = $?

  if ($tfplanExitCode -ne $true) {
    Write-Error "Terraform plan failed in the specified path: $path. Please check the output for details."
    Exit 1
  }

  #Convert the plan file to JSON
  $tfPlanJsonFileName = "output.tfplan.json"
  $tfPlanJsonFilePath = Join-Path -Path $path -ChildPath $tfPlanJsonFileName
  Write-Verbose "Converting the Terraform plan file to JSON: $tfPlanJsonFileName"
  terraform show -no-color -json $tfPlanFileName >$tfPlanJsonFileName
  $tfPlanConvertExitCode = $?
  if ($tfPlanConvertExitCode -ne $true) {
    Write-Error "Failed to convert the Terraform plan file to JSON in the specified path: $path. Please check the output for details."
    Exit 1
  }
  # Read the JSON file and convert it to a PowerShell object
  $tfPlanJson = Get-Content -Path $tfPlanJsonFileName -Raw | ConvertFrom-Json
  #Set the location back to the original
  Set-Location -Path $currentDir
  Write-Verbose "Cleaning up temporary files..."
  if (Test-Path -Path $tfPlanFilePath -PathType Leaf) {
    Write-Verbose "Removing temporary plan file: '$tfPlanFileName'..."
    Remove-Item -Path $tfPlanFilePath -Force
  }
  If (Test-Path -Path $tfPlanJsonFilePath -PathType Leaf) {
    Write-Verbose "Removing temporary JSON file: '$tfPlanJsonFileName'..."
    Remove-Item -Path $tfPlanJsonFilePath -Force
  }
  $tfPlanJson
}

#function to check AZ API TF Plan result against the policy restrictions API
function azApiTFPlanPolicyRestrictionCheck {
  [CmdletBinding()]
  [OutputType([System.Array])]
  param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [PSObject]$tfPlan,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$token
  )
  $policyRestrictions = @()
  foreach ($tfResource in $tfPlan.planned_values.root_module.resources) {
    Write-Verbose "Processing resource: $($tfResource.name) of type '$($tfResource.type)'..." -verbose
    if ($tfResource.type -ine 'azapi_resource') {
      Write-Warning "  - Unsupported resource - the resource type for $($tfResource.name) is '$($tfResource.type)'. Only AzAPI resources are supported. Skipping this resource."
    } else {
      Write-Verbose "  - Supported resource - the resource type for $($tfResource.name) is '$($tfResource.type)'. Proceeding with the policy restriction check." -verbose
      $resourceType = $($tfResource.values.type -split ('@'))[0]
      $apiVersion = $($tfResource.values.type -split ('@'))[1]
      $deploymentScope = getTFResourceDeploymentScope -tfPlan $tfPlan -resourceName $tfResource.name
      $parentId = getTFResourceParentId -tfPlan $tfPlan -resourceName $tfResource.name
      Write-Verbose "  - Resource type: '$resourceType'" -verbose
      Write-Verbose "  - API version: '$apiVersion'" -verbose
      Write-Verbose "  - Deployment scope: '$deploymentScope'" -verbose
      if ($parentId) {
        Write-Verbose "  - Parent ID: '$parentId'" -verbose
      } else {
        Write-Verbose "  - Parent ID: UNKNOWN" -verbose
      }
      $pendingFields = @(
        @{
          field  = 'name'
          values = @($tfResource.values.name)
        }
        @{
          field = 'tags'
        }
      )
      if ($tfResource.values.location) {
        $pendingFields += @{
          field  = 'location'
          values = @($tfResource.values.location)
        }
      }
      $resourceContent = $tfResource.values.body | ConvertTo-Json -Depth 99 | ConvertFrom-Json -Depth 99 -AsHashTable
      if ($null -eq $resourceContent) {
        $resourceContent = @{}
      }
      Write-Verbose "  - Resource content: $($resourceContent | ConvertTo-Json -Depth 99)" -verbose
      $resourceContent.add('type', $resourceType)
      $policyRestrictionParams = @{
        scopeResourceId    = $deploymentScope
        includeAuditEffect = $true
        resourceApiVersion = $apiVersion
        pendingFields      = $pendingFields
        resourceContent    = $resourceContent
        token              = $token
      }
      if ($parentId) {
        $policyRestrictionParams['resourceScope'] = $parentId
      }

      Write-Verbose "  - Calling the Policy Restrictions API..." -verbose
      $policyRestrictions += [PSCustomObject]@{
        name               = $tfResource.name
        address            = $tfResource.address
        policyRestrictions = $(getAzPolicyRestriction @policyRestrictionParams)
      }
    }
  }
  , $policyRestrictions
}

#function to get the resource deployment scope from the Terraform plan output file
function getTFResourceDeploymentScope {
  [CmdletBinding()]
  [OutputType([string])]
  param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [PSObject]$tfPlan,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$resourceName
  )
  $parentId = $null
  $tfPlanResource = $tfPlan.planned_values.root_module.resources | Where-Object { $_.name -ieq $resourceName }
  if (!$tfPlanResource) {
    Write-Error "Resource '$resourceName' not found in the Terraform plan."
    return $null
  } else {
    if ($tfPlanResource.values.parent_id.length -gt 0) {
      $parentId = $tfPlanResource.values.parent_id
      Write-Verbose "Parent ID for resource '$resourceName' is: $parentId"
    } else {
      Write-Warning "Parent ID for resource '$resourceName' is not known from the Terraform plan. Checking tfPlan Configurations..."
      $tfPlanResourceConfig = $tfPlan.configuration.root_module.resources | Where-Object { $_.name -ieq $resourceName }
      if (!$tfPlanResourceConfig) {
        Write-Error "Resource '$resourceName' not found in the Terraform plan configurations."
        return $null
      } else {
        if ($tfPlanResourceConfig.expressions.parent_id.references) {
          foreach ($ref in $tfPlanResourceConfig.expressions.parent_id.references) {
            #look up the reference value in $tfplan.planned_values.root_module.resources
            $refResource = $tfPlan.planned_values.root_module.resources | Where-Object { $_.address -ieq $ref }
            if ($refResource) {
              break
            }
          }
          Write-Verbose "Found the parent resource '$($refResource.name)'."
          if ($refResource) {
            #Look up the parent_id in the reference resource
            $parentId = getTFResourceDeploymentScope -tfPlan $tfPlan -resourceName $refResource.name
            if (!$(isResourceContainer -resourceId $parentId)) {
              #If the parent resource is not a resource group, subscription or management group, we need to keep looking for the parent resource
              Write-Verbose "The parent resource '$($refResource.name)' is not a resource group, subscription or management group. Looking for the parent resource..."
              #Recursively call the function to
              $parentId = getTFResourceDeploymentScope -tfPlan $tfPlan -resourceName $refResource.name
            }
          }
        }
      }
    }
    return $parentId
  }
}

#function to get the resource parent_id from the Terraform plan output file
function getTFResourceParentId {
  [CmdletBinding()]
  [OutputType([string])]
  param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [PSObject]$tfPlan,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$resourceName
  )
  $parentId = $null
  $tfPlanResource = $tfPlan.planned_values.root_module.resources | Where-Object { $_.name -ieq $resourceName }
  if (!$tfPlanResource) {
    Write-Error "Resource '$resourceName' not found in the Terraform plan."
    return $null
  } else {
    if ($tfPlanResource.values.parent_id.length -gt 0) {
      $parentId = $tfPlanResource.values.parent_id
      Write-Verbose "Parent ID for resource '$resourceName' is: $parentId"
    } else {
      Write-Warning "Parent ID for resource '$resourceName' is not known from the Terraform plan..."
    }
    return $parentId
  }
}

#function to check Terraform policy violations from policy restriction API results
Function checkTerraformPolicyRestriction {
  [CmdletBinding()]
  [OutputType([bool])]
  param (
    [Parameter(Mandatory = $true)][object]$desiredConfig
  )
  Write-Verbose "[$(getCurrentUTCString)]: Processing policy restriction API results for $($desiredConfig.testName)" -verbose
  $token = $desiredConfig.token

  #Get the Terraform plan results
  Write-Verbose "[$(getCurrentUTCString)]: Get Terraform plan results for $($desiredConfig.terraformDirectory)" -verbose
  $tfPlan = getTFPlanResult -Path $desiredConfig.terraformDirectory -Verbose

  Write-Verbose "[$(getCurrentUTCString)]: Get policy restriction results for the terraform plan result for $($desiredConfig.terraformDirectory)" -verbose
  $policyRestrictions = azApiTFPlanPolicyRestrictionCheck -tfPlan $tfPlan -token $token
  Write-Verbose "[$(getCurrentUTCString)]: Policy Restriction results for $($desiredConfig.terraformDirectory):" -verbose
  Write-Verbose $($policyRestrictions | ConvertTo-Json -Depth 99) -verbose
  $matchingPolicyViolation = processPolicyRestrictionAPIResult -desiredPolicyViolations $desiredConfig.policyViolation -actualRestrictionForResource $policyRestrictions

  Write-Verbose "[$(getCurrentUTCString)]: Policy Restriction validation result for $($desiredConfig.testName): $bMatchingPolicyViolation" -verbose
  #return true if all the desired policy violations are matched with the actual policy violation
  $matchingPolicyViolation
}
