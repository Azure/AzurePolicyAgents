using module ./AzResourceTest-type.psm1
using module ./AzResourceTest-helper.psm1

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
