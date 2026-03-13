#borrowed from the AVM project
#get deployment operation filtered to the 'create' provisioning operation
Function getDeploymentOperation {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string] $deploymentId,

    [Parameter(Mandatory = $true)]
    [string]$apiToken
  )
  $url = "https://management.azure.com/$deploymentId/operations?api-version=2021-04-01"
  $headers = @{
    'Authorization' = "Bearer $apiToken"
    'Content-Type'  = 'application/json'
  }
  Write-Verbose "Getting deployment operation for deployment via url $url" -verbose
  $request = invoke-webrequest -Uri $url -Method Get -Headers $headers -ErrorAction SilentlyContinue
  if ($request.StatusCode -ge 200 -and $request.StatusCode -le 299) {
    $result = ($request.Content | ConvertFrom-Json).value
  } else {
    Write-Verbose "Unable to get deployment operation for deployment $deploymentId via url $url. Error: $($request.Content). Status Code: $($request.StatusCode)"
    $result = $null
  }
  #Filter on ProvisioningOperation and only return 'Create'
  $filteredResult = $result | where-object { $_.properties.provisioningOperation -ieq 'create' }
  $filteredResult
}

#Get all deployments that match a given deployment name in a given scope
function getDeploymentTargetResourceListInner {

  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $deploymentId,

    [Parameter(Mandatory = $true)]
    [string] $apiToken
  )

  $resultSet = [System.Collections.ArrayList]@()

  ##############################################
  # Get all deployment children based on scope #
  ##############################################
  if ($deploymentScope -imatch '/resourceGroups/') {
    $resourceGroupName = $deploymentId.split( '/ resourceGroups/')[1].Split('/')[0]
    Write-Verbose "Resource Group scoped deployment. Resource Group Name: $resourceGroupName"
    if (Get-AzResourceGroup -Name $resourceGroupName -ErrorAction 'SilentlyContinue') {
      #[array]$deploymentTargets = (Get-AzResourceGroupDeploymentOperation -DeploymentName $name -ResourceGroupName $resourceGroupName).TargetResource | Where-Object { $_ -ne $null }
      [array]$deploymentTargets = (getDeploymentOperation -deploymentId $deploymentId -apiToken $apiToken).properties.targetResource.id | Where-Object { $_ -ne $null }
    } else {
      # In case the resource group itself was already deleted, there is no need to try and fetch deployments from it
      # In case we already have any such resources in the list, we should remove them
      [array]$resultSet = $resultSet | Where-Object { $_ -notmatch "/resourceGroups/$resourceGroupName/" }
    }
  } else {
    $deploymentTargets = (getDeploymentOperation -deploymentId $deploymentId -apiToken $apiToken).properties.targetResource.id | Where-Object { $_ -ne $null }
  }

  ###########################
  # Manage nested resources #
  ###########################
  foreach ($deployment in ($deploymentTargets | Where-Object { $_ -notmatch '/deployments/' } )) {
    Write-Verbose ('Found deployed resource [{0}]' -f $deployment)
    [array]$resultSet += $deployment
  }

  #############################
  # Manage nested deployments #
  #############################
  foreach ($deployment in ($deploymentTargets | Where-Object { $_ -match '/deployments/' } )) {
    [array]$resultSet += getDeploymentTargetResourceListInner -deploymentId $deployment -apiToken $apiToken
  }

  return $resultSet
}

#Get all deployments that match a given deployment name in a given scope using a retry mechanic
function getDeploymentTargetResourceList {

  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $deploymentId,

    [Parameter(Mandatory = $false)]
    [int] $SearchRetryLimit = 40,

    [Parameter(Mandatory = $false)]
    [int] $SearchRetryInterval = 60
  )
  $searchRetryCount = 1
  #Get ARM REST API token
  $apiToken = ConvertFrom-SecureString (Get-AzAccessToken -ResourceUrl 'https://management.azure.com/').Token -AsPlainText
  #write-verbose "api token: $apiToken" -verbose


  do {
    $innerInputObject = @{
      deploymentId = $deploymentId
      apiToken     = $apiToken
      ErrorAction  = 'SilentlyContinue'
    }
    [array]$targetResources = getDeploymentTargetResourceListInner @innerInputObject
    if ($targetResources) {
      break
    }
    Write-Verbose ('No deployment found by name [{0}] in scope [{1}]. Retrying in [{2}] seconds [{3}/{4}]' -f $name, $scope, $searchRetryInterval, $searchRetryCount, $searchRetryLimit) -Verbose
    Start-Sleep $searchRetryInterval
    $searchRetryCount++
  } while ($searchRetryCount -le $searchRetryLimit)

  if (-not $targetResources) {
    throw "No deployment target resources found for [$name]"
  }

  return $targetResources
}

#Get diagnostic settings for a given resource
function getDiagnosticSettingsResources {
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory = $true, HelpMessage = 'Specify the resource id of the resource.')]
    [string]$ResourceId
  )
  $url = "https://management.azure.com/{0}/providers/microsoft.insights/diagnosticSettings?api-version=2021-05-01-preview" -f $ResourceId
  $apiToken = ConvertFrom-SecureString (Get-AzAccessToken -ResourceUrl 'https://management.azure.com/').Token -AsPlainText
  $headers = @{
    'Authorization' = "Bearer $apiToken"
    'Content-Type'  = 'application/json'
  }
  Write-Verbose "Getting diagnostic settings for resource via url $url" -verbose
  try {
    $request = invoke-webrequest -Uri $url -Method Get -Headers $headers -ErrorAction SilentlyContinue
    if ($request.StatusCode -ge 200 -and $request.StatusCode -le 299) {
      $result = ($request.Content | ConvertFrom-Json).value.id
    } else {
      Write-Verbose "Unable to get diagnostic settings for resource $ResourceId via url $url. Error: $($request.Content). Status Code: $($request.StatusCode)"
      $result = $null
    }
  } catch {
    Write-Verbose "Unable to get diagnostic settings for resource $ResourceId via url $url. Error: $_"
    $result = $null
  }
  if ($result) {
    $result
  }
}

# Order the given resources as per the provided ordered resource type list
function getOrderedResourcesList {

  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [hashtable[]] $ResourcesToOrder,

    [Parameter(Mandatory = $false)]
    [string[]] $Order = @()
  )

  # Going from back to front of the list to stack in the correct order
  for ($orderIndex = ($order.Count - 1); $orderIndex -ge 0; $orderIndex--) {
    $searchItem = $order[$orderIndex]
    if ($elementsContained = $resourcesToOrder | Where-Object { $_.type -eq $searchItem }) {
      $resourcesToOrder = @() + $elementsContained + ($resourcesToOrder | Where-Object { $_.type -ne $searchItem })
    }
  }

  return $resourcesToOrder
}

#Remove any artifacts that remain of the given resource
function invokeResourcePostRemoval {

  [CmdletBinding(SupportsShouldProcess)]
  param (
    [Parameter(Mandatory = $true)]
    [string] $ResourceId,

    [Parameter(Mandatory = $true)]
    [string] $Type
  )

  switch ($Type) {
    'Microsoft.AppConfiguration/configurationStores' {
      $subscriptionId = $ResourceId.Split('/')[2]
      $resourceName = Split-Path $ResourceId -Leaf

      # Fetch service in soft-delete
      $getPath = '/subscriptions/{0}/providers/Microsoft.AppConfiguration/deletedConfigurationStores?api-version=2021-10-01-preview' -f $subscriptionId
      $getRequestInputObject = @{
        Method = 'GET'
        Path   = $getPath
      }
      $softDeletedConfigurationStore = ((Invoke-AzRestMethod @getRequestInputObject).Content | ConvertFrom-Json).value | Where-Object { $_.properties.configurationStoreId -eq $ResourceId }

      if ($softDeletedConfigurationStore) {
        # Purge service
        $purgePath = '/subscriptions/{0}/providers/Microsoft.AppConfiguration/locations/{1}/deletedConfigurationStores/{2}/purge?api-version=2021-10-01-preview' -f $subscriptionId, $softDeletedConfigurationStore.properties.location, $resourceName
        $purgeRequestInputObject = @{
          Method = 'POST'
          Path   = $purgePath
        }
        Write-Verbose ('[*] Purging resource [{0}] of type [{1}]' -f $resourceName, $Type) -Verbose
        if ($PSCmdlet.ShouldProcess(('App Configuration Store with ID [{0}]' -f $softDeletedConfigurationStore.properties.configurationStoreId), 'Purge')) {
          $response = Invoke-AzRestMethod @purgeRequestInputObject
          if ($response.StatusCode -ne 200) {
            throw ('Purge of resource [{0}] failed with error code [{1}]' -f $ResourceId, $response.StatusCode)
          }
        }
      }
      break
    }
    'Microsoft.KeyVault/vaults' {
      $resourceName = Split-Path $ResourceId -Leaf

      $matchingKeyVault = Get-AzKeyVault -InRemovedState | Where-Object { $_.resourceId -eq $ResourceId }
      if ($matchingKeyVault -and -not $matchingKeyVault.EnablePurgeProtection) {
        Write-Verbose ('[*] Purging resource [{0}] of type [{1}]' -f $resourceName, $Type) -Verbose
        if ($PSCmdlet.ShouldProcess(('Key Vault with ID [{0}]' -f $matchingKeyVault.Id), 'Purge')) {
          try {
            $null = Remove-AzKeyVault -ResourceId $matchingKeyVault.Id -InRemovedState -Force -Location $matchingKeyVault.Location -ErrorAction 'Stop'
          } catch {
            if ($_.Exception.Message -like '*DeletedVaultPurge*') {
              Write-Warning ('Purge protection for key vault [{0}] enabled. Skipping. Scheduled purge date is [{1}]' -f $resourceName, $matchingKeyVault.ScheduledPurgeDate)
            } else {
              throw $_
            }
          }
        }
      }
      break
    }
    'Microsoft.CognitiveServices/accounts' {
      $resourceGroupName = $ResourceId.Split('/')[4]
      $resourceName = Split-Path $ResourceId -Leaf

      $matchingAccount = Get-AzCognitiveServicesAccount -InRemovedState | Where-Object { $_.AccountName -eq $resourceName }
      if ($matchingAccount) {
        Write-Verbose ('[*] Purging resource [{0}] of type [{1}]' -f $resourceName, $Type) -Verbose
        if ($PSCmdlet.ShouldProcess(('Cognitive services account with ID [{0}]' -f $matchingAccount.Id), 'Purge')) {
          $null = Remove-AzCognitiveServicesAccount -InRemovedState -Force -Location $matchingAccount.Location -ResourceGroupName $resourceGroupName -Name $matchingAccount.AccountName
        }
      }
      break
    }
    'Microsoft.ApiManagement/service' {
      $subscriptionId = $ResourceId.Split('/')[2]
      $resourceName = Split-Path $ResourceId -Leaf

      # Fetch service in soft-delete
      $getPath = '/subscriptions/{0}/providers/Microsoft.ApiManagement/deletedservices?api-version=2021-08-01' -f $subscriptionId
      $getRequestInputObject = @{
        Method = 'GET'
        Path   = $getPath
      }
      $softDeletedService = ((Invoke-AzRestMethod @getRequestInputObject).Content | ConvertFrom-Json).value | Where-Object { $_.properties.serviceId -eq $ResourceId }

      if ($softDeletedService) {
        # Purge service
        $purgePath = '/subscriptions/{0}/providers/Microsoft.ApiManagement/locations/{1}/deletedservices/{2}?api-version=2020-06-01-preview' -f $subscriptionId, $softDeletedService.location, $resourceName
        $purgeRequestInputObject = @{
          Method = 'DELETE'
          Path   = $purgePath
        }
        Write-Verbose ('[*] Purging resource [{0}] of type [{1}]' -f $resourceName, $Type) -Verbose
        if ($PSCmdlet.ShouldProcess(('API management service with ID [{0}]' -f $softDeletedService.properties.serviceId), 'Purge')) {
          $null = Invoke-AzRestMethod @purgeRequestInputObject
        }
      }
      break
    }
    'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems' {
      # Remove protected VM
      # Required if e.g. a VM was listed in an RSV and only that VM is removed
      $vaultId = $ResourceId.split('/backupFabrics/')[0]
      $resourceName = Split-Path $ResourceId -Leaf
      $softDeleteStatus = (Get-AzRecoveryServicesVaultProperty -VaultId $vaultId).SoftDeleteFeatureState
      if ($softDeleteStatus -ne 'Disabled') {
        if ($PSCmdlet.ShouldProcess(('Soft-delete on RSV [{0}]' -f $vaultId), 'Set')) {
          $null = Set-AzRecoveryServicesVaultProperty -VaultId $vaultId -SoftDeleteFeatureState 'Disable'
        }
      }

      $backupItemInputObject = @{
        BackupManagementType = 'AzureVM'
        WorkloadType         = 'AzureVM'
        VaultId              = $vaultId
        Name                 = $resourceName
      }
      if ($backupItem = Get-AzRecoveryServicesBackupItem @backupItemInputObject -ErrorAction 'SilentlyContinue') {
        Write-Verbose ('    [-] Removing Backup item [{0}] from RSV [{1}]' -f $backupItem.Name, $vaultId) -Verbose

        if ($backupItem.DeleteState -eq 'ToBeDeleted') {
          if ($PSCmdlet.ShouldProcess('Soft-deleted backup data removal', 'Undo')) {
            $null = Undo-AzRecoveryServicesBackupItemDeletion -Item $backupItem -VaultId $vaultId -Force
          }
        }

        if ($PSCmdlet.ShouldProcess(('Backup item [{0}] from RSV [{1}]' -f $backupItem.Name, $vaultId), 'Remove')) {
          $null = Disable-AzRecoveryServicesBackupProtection -Item $backupItem -VaultId $vaultId -RemoveRecoveryPoints -Force
        }
      }

      # Undo a potential soft delete state change
      $null = Set-AzRecoveryServicesVaultProperty -VaultId $vaultId -SoftDeleteFeatureState $softDeleteStatus.TrimEnd('d')
      break
    }
    ### CODE LOCATION: Add custom post-removal operation here
  }
}
#Remove the given resource(s)
function removeResourceListInner {

  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory = $false)]
    [Hashtable[]] $ResourcesToRemove = @()
  )

  begin {
    Write-Debug ('{0} entered' -f $MyInvocation.MyCommand)

  }

  process {
    $resourcesToRemove | ForEach-Object { Write-Verbose ('- Remove [{0}]' -f $_.resourceId) -Verbose }
    $resourcesToRetry = @()
    $processedResources = @()
    Write-Verbose '----------------------------------' -Verbose

    foreach ($resource in $resourcesToRemove) {
      $resourceName = Split-Path $resource.resourceId -Leaf
      $alreadyProcessed = $processedResources.count -gt 0 ? (($processedResources | Where-Object { $resource.resourceId -like ('{0}*' -f $_) }).Count -gt 0) : $false

      if ($alreadyProcessed) {
        # Skipping
        Write-Verbose ('[/] Skipping resource [{0}] of type [{1}]. Reason: Its parent resource was already processed' -f $resourceName, $resource.type) -Verbose
        [array]$processedResources += $resource.resourceId
        [array]$resourcesToRetry = $resourcesToRetry | Where-Object { $_.resourceId -notmatch $resource.resourceId }
      } else {
        Write-Verbose ('[-] Removing resource [{0}] of type [{1}]' -f $resourceName, $resource.type) -Verbose
        try {
          if ($PSCmdlet.ShouldProcess(('Resource [{0}]' -f $resource.resourceId), 'Remove')) {
            invokeResourceRemoval -Type $resource.type -ResourceId $resource.resourceId
          }

          # If we removed a parent remove its children
          [array]$processedResources += $resource.resourceId
          [array]$resourcesToRetry = $resourcesToRetry | Where-Object { $_.resourceId -notmatch $resource.resourceId }
        } catch {
          Write-Warning ('[!] Removal moved back for retry. Reason: [{0}]' -f $_.Exception.Message)
          [array]$resourcesToRetry += $resource
        }
      }

      # We want to purge resources even if they were not explicitly removed because they were 'alreadyProcessed'
      if ($PSCmdlet.ShouldProcess(('Post-resource-removal for [{0}]' -f $resource.resourceId), 'Execute')) {
        invokeResourcePostRemoval -Type $resource.type -ResourceId $resource.resourceId
      }
    }
    Write-Verbose '----------------------------------' -Verbose
    return $resourcesToRetry
  }
  end {
    Write-Debug ('{0} exited' -f $MyInvocation.MyCommand)
  }
}
#Remove all resources in the provided array from Azure
function removeResourceList {

  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory = $false)]
    [PSObject[]] $ResourcesToRemove = @(),

    [Parameter(Mandatory = $false)]
    [int] $RemovalRetryLimit = 3,

    [Parameter(Mandatory = $false)]
    [int] $RemovalRetryInterval = 15
  )

  $removalRetryCount = 1
  $resourcesToRetry = $resourcesToRemove

  do {
    if ($PSCmdlet.ShouldProcess(("[{0}] Resource(s) with a maximum of [$removalRetryLimit] attempts." -f (($resourcesToRetry -is [array]) ? $resourcesToRetry.Count : 1)), 'Remove')) {
      $resourcesToRetry = removeResourceListInner -ResourcesToRemove $resourcesToRetry
    } else {
      removeResourceListInner -ResourcesToRemove $resourcesToRemove -WhatIf
    }

    if (-not $resourcesToRetry) {
      break
    }
    Write-Verbose ('Retry removal of remaining [{0}] resources. Waiting [{1}] seconds. Round [{2}|{3}]' -f (($resourcesToRetry -is [array]) ? $resourcesToRetry.Count : 1), $removalRetryInterval, $removalRetryCount, $removalRetryLimit)
    $removalRetryCount++
    Start-Sleep $removalRetryInterval
  } while ($removalRetryCount -le $removalRetryLimit)

  if ($resourcesToRetry.Count -gt 0) {
    throw ('The removal failed for resources [{0}]' -f ((Split-Path $resourcesToRetry.resourceId -Leaf) -join ', '))
  } else {
    Write-Verbose 'The removal completed successfully'
  }
}


#Format the provide resource IDs into objects of resourceID, name & type
function getResourceIdsAsFormattedObjectList {

  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $false)]
    [string[]] $ResourceIds = @()
  )

  $formattedResources = [System.Collections.ArrayList]@()

  # If any resource is deployed at a resource group level, we store all resources in this resource group in this array. Essentially it's a cache.
  $allResourceGroupResources = @()

  foreach ($resourceId in $resourceIds) {

    $idElements = $resourceId.Split('/')

    switch ($idElements.Count) {
      { $PSItem -eq 5 } {
        if ($idElements[3] -eq 'managementGroups') {
          # management-group level management group (e.g. '/providers/Microsoft.Management/managementGroups/testMG')
          $formattedResources += @{
            resourceId = $resourceId
            type       = $idElements[2, 3] -join '/'
          }
        } else {
          # subscription level resource group (e.g. '/subscriptions/<subId>/resourceGroups/myRG')
          $formattedResources += @{
            resourceId = $resourceId
            type       = 'Microsoft.Resources/resourceGroups'
          }
        }
        break
      }
      { $PSItem -eq 6 } {
        # subscription-level resource group
        $formattedResources += @{
          resourceId = $resourceId
          type       = $idElements[4, 5] -join '/'
        }
        break
      }
      { $PSItem -eq 7 } {
        if (($resourceId.Split('/'))[3] -ne 'resourceGroups') {
          # subscription-level resource
          $formattedResources += @{
            resourceId = $resourceId
            type       = $idElements[4, 5] -join '/'
          }
        } else {
          # resource group-level
          if ($allResourceGroupResources.Count -eq 0) {
            $allResourceGroupResources = Get-AzResource -ResourceGroupName $resourceGroupName -Name '*'
          }
          $expandedResources = $allResourceGroupResources | Where-Object { $_.ResourceId.startswith($resourceId) }
          $expandedResources = $expandedResources | Sort-Object -Descending -Property { $_.ResourceId.Split('/').Count }
          foreach ($resource in $expandedResources) {
            $formattedResources += @{
              resourceId = $resource.ResourceId
              type       = $resource.Type
            }
          }
        }
        break
      }
      { $PSItem -ge 8 } {
        # child-resource level
        # Find the last resource type reference in the resourceId.
        # E.g. Microsoft.Automation/automationAccounts/provider/Microsoft.Authorization/roleAssignments/... returns the index of 'Microsoft.Authorization'
        $indexOfResourceType = $idElements.IndexOf(($idElements -like 'Microsoft.**')[-1])
        $type = $idElements[$indexOfResourceType, ($indexOfResourceType + 1)] -join '/'

        # Concat rest of resource type along the ID
        $partCounter = $indexOfResourceType + 1
        while (-not ($partCounter + 2 -gt $idElements.Count - 1)) {
          $type += ('/{0}' -f $idElements[($partCounter + 2)])
          $partCounter = $partCounter + 2
        }

        $formattedResources += @{
          resourceId = $resourceId
          type       = $type
        }
        break
      }
      Default {
        throw "Failed to process resource ID [$resourceId]"
      }
    }
  }

  return $formattedResources
}

#Gets resource locks on a resource or a specific resource lock.
function invokeResourceLockRetrieval {
  [OutputType([System.Management.Automation.PSCustomObject])]
  param (
    [Parameter(Mandatory = $true)]
    [string] $ResourceId,

    [Parameter(Mandatory = $false)]
    [string] $Type = ''
  )
  if ($Type -eq 'Microsoft.Authorization/locks') {
    $lockName = ($ResourceId -split '/')[-1]
    $lockScope = ($ResourceId -split '/providers/Microsoft.Authorization/locks')[0]
    return Get-AzResourceLock -LockName $lockName -Scope $lockScope -ErrorAction SilentlyContinue
  } else {
    return Get-AzResourceLock -Scope $ResourceId -ErrorAction SilentlyContinue
  }
}

#Remove a specific resource
function invokeResourceRemoval {

  [CmdletBinding(SupportsShouldProcess)]
  param (
    [Parameter(Mandatory = $true)]
    [string] $ResourceId,

    [Parameter(Mandatory = $true)]
    [string] $Type
  )
  # Remove unhandled resource locks, for cases when the resource
  # collection is incomplete, usually due to previous removal failing.
  if ($PSCmdlet.ShouldProcess("Possible locks on resource with ID [$ResourceId]", 'Handle')) {
    invokeResourceLockRemoval -ResourceId $ResourceId -Type $Type
  }

  switch ($Type) {
    'Microsoft.Insights/diagnosticSettings' {
      $parentResourceId = $ResourceId.Split('/providers/{0}' -f $Type)[0]
      $resourceName = Split-Path $ResourceId -Leaf
      if ($PSCmdlet.ShouldProcess("Diagnostic setting [$resourceName]", 'Remove')) {
        $null = Remove-AzDiagnosticSetting -ResourceId $parentResourceId -Name $resourceName
      }
      break
    }
    'Microsoft.Authorization/locks' {
      if ($PSCmdlet.ShouldProcess("Lock with ID [$ResourceId]", 'Remove')) {
        invokeResourceLockRemoval -ResourceId $ResourceId -Type $Type
      }
      break
    }
    'Microsoft.KeyVault/vaults/keys' {
      $resourceName = Split-Path $ResourceId -Leaf
      Write-Verbose ('[/] Skipping resource [{0}] of type [{1}]. Reason: It is handled by different logic.' -f $resourceName, $Type) -Verbose
      # Also, we don't want to accidently remove keys of the dependency key vault
      break
    }
    'Microsoft.KeyVault/vaults/accessPolicies' {
      $resourceName = Split-Path $ResourceId -Leaf
      Write-Verbose ('[/] Skipping resource [{0}] of type [{1}]. Reason: It is handled by different logic.' -f $resourceName, $Type) -Verbose
      break
    }
    'Microsoft.ServiceBus/namespaces/authorizationRules' {
      if ((Split-Path $ResourceId '/')[-1] -eq 'RootManageSharedAccessKey') {
        Write-Verbose ('[/] Skipping resource [RootManageSharedAccessKey] of type [{0}]. Reason: The Service Bus''s default authorization key cannot be removed' -f $Type) -Verbose
      } else {
        if ($PSCmdlet.ShouldProcess("Resource with ID [$ResourceId]", 'Remove')) {
          $null = Remove-AzResource -ResourceId $ResourceId -Force -ErrorAction 'Stop'
        }
      }
      break
    }
    'Microsoft.Compute/diskEncryptionSets' {
      # Pre-Removal
      # -----------
      # Remove access policies on key vault
      $resourceGroupName = $ResourceId.Split('/')[4]
      $resourceName = Split-Path $ResourceId -Leaf

      $diskEncryptionSet = Get-AzDiskEncryptionSet -Name $resourceName -ResourceGroupName $resourceGroupName
      $keyVaultResourceId = $diskEncryptionSet.ActiveKey.SourceVault.Id
      $keyVaultName = Split-Path $keyVaultResourceId -Leaf
      $objectId = $diskEncryptionSet.Identity.PrincipalId

      if ($PSCmdlet.ShouldProcess(('Access policy [{0}] from key vault [{1}]' -f $objectId, $keyVaultName), 'Remove')) {
        $null = Remove-AzKeyVaultAccessPolicy -VaultName $keyVaultName -ObjectId $objectId
      }

      # Actual removal
      # --------------
      if ($PSCmdlet.ShouldProcess("Resource with ID [$ResourceId]", 'Remove')) {
        $null = Remove-AzResource -ResourceId $ResourceId -Force -ErrorAction 'Stop'
      }
      break
    }
    'Microsoft.RecoveryServices/vaults/backupstorageconfig' {
      # Not a 'resource' that can be removed, but represents settings on the RSV. The config is deleted with the RSV
      break
    }
    'Microsoft.Authorization/roleAssignments' {
      $idElem = $ResourceId.Split('/')
      $scope = $idElem[0..($idElem.Count - 5)] -join '/'
      $roleAssignmentsOnScope = Get-AzRoleAssignment -Scope $scope
      $null = $roleAssignmentsOnScope | Where-Object { $_.RoleAssignmentId -eq $ResourceId } | Remove-AzRoleAssignment
      break
    }
    'Microsoft.RecoveryServices/vaults' {
      # Pre-Removal
      # -----------
      # Remove protected VMs
      if ((Get-AzRecoveryServicesVaultProperty -VaultId $ResourceId).SoftDeleteFeatureState -ne 'Disabled') {
        if ($PSCmdlet.ShouldProcess(('Soft-delete on RSV [{0}]' -f $ResourceId), 'Set')) {
          $null = Set-AzRecoveryServicesVaultProperty -VaultId $ResourceId -SoftDeleteFeatureState 'Disable'
        }
      }

      $backupItems = Get-AzRecoveryServicesBackupItem -BackupManagementType 'AzureVM' -WorkloadType 'AzureVM' -VaultId $ResourceId
      foreach ($backupItem in $backupItems) {
        Write-Verbose ('Removing Backup item [{0}] from RSV [{1}]' -f $backupItem.Name, $ResourceId) -Verbose

        if ($backupItem.DeleteState -eq 'ToBeDeleted') {
          if ($PSCmdlet.ShouldProcess('Soft-deleted backup data removal', 'Undo')) {
            $null = Undo-AzRecoveryServicesBackupItemDeletion -Item $backupItem -VaultId $ResourceId -Force
          }
        }

        if ($PSCmdlet.ShouldProcess(('Backup item [{0}] from RSV [{1}]' -f $backupItem.Name, $ResourceId), 'Remove')) {
          $null = Disable-AzRecoveryServicesBackupProtection -Item $backupItem -VaultId $ResourceId -RemoveRecoveryPoints -Force
        }
      }

      # Actual removal
      # --------------
      if ($PSCmdlet.ShouldProcess("Resource with ID [$ResourceId]", 'Remove')) {
        $null = Remove-AzResource -ResourceId $ResourceId -Force -ErrorAction 'Stop'
      }
      break
    }
    'Microsoft.OperationalInsights/workspaces' {
      $resourceGroupName = $ResourceId.Split('/')[4]
      $resourceName = Split-Path $ResourceId -Leaf
      # Force delete workspace (cannot be recovered)
      if ($PSCmdlet.ShouldProcess("Log Analytics Workspace [$resourceName]", 'Remove')) {
        Write-Verbose ('[*] Purging resource [{0}] of type [{1}]' -f $resourceName, $Type) -Verbose
        $null = Remove-AzOperationalInsightsWorkspace -ResourceGroupName $resourceGroupName -Name $resourceName -Force -ForceDelete
      }
      break
    }
    'Microsoft.MachineLearningServices/workspaces' {
      $subscriptionId = $ResourceId.Split('/')[2]
      $resourceGroupName = $ResourceId.Split('/')[4]
      $resourceName = Split-Path $ResourceId -Leaf

      # Purge service
      $purgePath = '/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.MachineLearningServices/workspaces/{2}?api-version=2023-06-01-preview&forceToPurge=true' -f $subscriptionId, $resourceGroupName, $resourceName
      $purgeRequestInputObject = @{
        Method = 'DELETE'
        Path   = $purgePath
      }
      Write-Verbose ('[*] Purging resource [{0}] of type [{1}]' -f $resourceName, $Type) -Verbose
      if ($PSCmdlet.ShouldProcess("Machine Learning Workspace [$resourceName]", 'Purge')) {
        $purgeResource = Invoke-AzRestMethod @purgeRequestInputObject
        if ($purgeResource.StatusCode -notlike '2*') {
          $responseContent = $purgeResource.Content | ConvertFrom-Json
          throw ('{0} : {1}' -f $responseContent.error.code, $responseContent.error.message)
        }

        # Wait for workspace to be purged. If it is not purged it has a chance of being soft-deleted via RG deletion (not purged)
        # The consecutive deployments will fail because it is not purged.
        $retryCount = 0
        $retryLimit = 240
        $retryInterval = 15
        do {
          $retryCount++
          if ($retryCount -ge $retryLimit) {
            Write-Warning ('    [!] Workspace [{0}] was not purged after {1} seconds. Continuing with resource removal.' -f $resourceName, ($retryCount * $retryInterval))
            break
          }
          Write-Verbose ('    [⏱️] Waiting {0} seconds for workspace to be purged.' -f $retryInterval) -Verbose
          Start-Sleep -Seconds $retryInterval
          $workspace = Get-AzMLWorkspace -Name $resourceName -ResourceGroupName $resourceGroupName -SubscriptionId $subscriptionId -ErrorAction SilentlyContinue
          $workspaceExists = $workspace.count -gt 0
        } while ($workspaceExists)
      }
      break
    }
    ### CODE LOCATION: Add custom removal action here
    Default {
      if ($PSCmdlet.ShouldProcess("Resource with ID [$ResourceId]", 'Remove')) {
        $null = Remove-AzResource -ResourceId $ResourceId -Force -ErrorAction 'Stop'
      }
    }
  }
}

#Remove resource locks from a resource or a specific resource lock.
function invokeResourceLockRemoval {
  [CmdletBinding(SupportsShouldProcess)]
  param (
    [Parameter(Mandatory = $true)]
    [string] $ResourceId,

    [Parameter(Mandatory = $false)]
    [string] $Type,

    [Parameter(Mandatory = $false)]
    [int] $RetryLimit = 10,

    [Parameter(Mandatory = $false)]
    [int] $RetryInterval = 10
  )


  $resourceLock = invokeResourceLockRetrieval -ResourceId $ResourceId -Type $Type

  $isLocked = $resourceLock.count -gt 0
  if (-not $isLocked) {
    return
  }

  $resourceLock | ForEach-Object {
    Write-Warning ('    [-] Removing lock [{0}] on [{1}] of type [{2}].' -f $_.Name, $_.ResourceName, $_.ResourceType)
    if ($PSCmdlet.ShouldProcess(('Lock [{0}] on resource [{1}] of type [{2}].' -f $_.Name, $_.ResourceName, $_.ResourceType ), 'Remove')) {
      $null = $_ | Remove-AzResourceLock -Force
    }
  }

  $retryCount = 0
  do {
    $retryCount++
    if ($retryCount -ge $RetryLimit) {
      Write-Warning ('    [!] Lock was not removed after {1} seconds. Continuing with resource removal.' -f ($retryCount * $RetryInterval))
      break
    }
    Write-Verbose '    [⏱️] Waiting for lock to be removed.' -Verbose
    Start-Sleep -Seconds $RetryInterval

    # Rechecking the resource locks to see if they have been removed.
    $resourceLock = invokeResourceLockRetrieval -ResourceId $ResourceId -Type $Type
    $isLocked = $resourceLock.count -gt 0
  } while ($isLocked)

  Write-Verbose ('    [-] [{0}] resource lock(s) removed.' -f $resourceLock.count) -Verbose
}

#Invoke the removal of all resources created from an ARM deployment (Only subscription and resource group level deployments are supported)
function removeDeployment {

  [CmdletBinding(SupportsShouldProcess)]
  param (
    [Parameter(Mandatory = $true)]
    [string] $deploymentId,

    [Parameter(Mandatory = $false)]
    [string[]] $RemovalSequence = @(),

    [Parameter(Mandatory = $false)]
    [int] $SearchRetryLimit = 40,

    [Parameter(Mandatory = $false)]
    [int] $SearchRetryInterval = 60
  )

  begin {
    Write-Debug ('{0} entered' -f $MyInvocation.MyCommand)
  }

  process {
    #extract subscription Id from deploymentId
    $regex = '(?im)^\/subscriptions\/([0-9A-F]{8}[-]?(?:[0-9A-F]{4}[-]?){3}[0-9A-F]{12})\/\S+'
    $match = Select-string -InputObject $deploymentId -Pattern $regex
    $subscriptionId = $match.Matches.Groups[1].Value
    # Fetch deployments
    # =================

    #Get deployed Resources
    Write-Verbose "[$(getCurrentUTCString)]: Getting deployed resources for deployment id: $deploymentId" -Verbose
    $deployedTargetResources = getDeploymentTargetResourceList -deploymentId $deploymentId

    #Also get the diagnostic settings resources for each detected resource. Diagnostic Settings must be removed before the resource can be removed.
    #More info: https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/diagnostic-settings
    Write-Verbose "[$(getCurrentUTCString)]: Getting diagnostic settings resources for the detected resources" -Verbose
    $diagnosticSettings = @()
    foreach ($resource in $resources) {
      $diagnosticSettings += getDiagnosticSettingsResources -ResourceId $resource
    }

    Write-Verbose "[$(getCurrentUTCString)]: Detected Diagnostic Settings created outside of the deployment:" -Verbose
    foreach ($item in $diagnosticSettings) {
      if ($deployedTargetResources -notcontains $item) {
        Write-Verbose "  - $item" -Verbose
        $deployedTargetResources += $item
      }
    }

    Write-Verbose "[$(getCurrentUTCString)]: Resources to be deleted:" -Verbose
    foreach ($resource in $deployedTargetResources) {
      Write-Verbose "  - $resource" -Verbose
    }


    if ($deployedTargetResources.Count -eq 0) {
      throw 'No deployment target resources found.'
    }

    [array] $deployedTargetResources = $deployedTargetResources | Select-Object -Unique

    Write-Verbose ('Total number of deployment target resources after fetching deployments [{0}]' -f $deployedTargetResources.Count) -Verbose

    # Pre-Filter & order items
    # ========================
    $rawTargetResourceIdsToRemove = $deployedTargetResources | Sort-Object -Property { $_.Split('/').Count } -Descending | Select-Object -Unique
    Write-Verbose ('Total number of deployment target resources after pre-filtering (duplicates) & ordering items [{0}]' -f $rawTargetResourceIdsToRemove.Count) -Verbose

    # Format items
    # ============
    [array] $resourcesToRemove = getResourceIdsAsFormattedObjectList -ResourceIds $rawTargetResourceIdsToRemove
    Write-Verbose ('Total number of deployment target resources after formatting items [{0}]' -f $resourcesToRemove.Count) -Verbose

    if ($resourcesToRemove.Count -eq 0) {
      return
    }

    # Filter resources
    # ================

    # Resource IDs in the below list are ignored by the removal
    $resourceIdsToIgnore = @(
      '/subscriptions/{0}/resourceGroups/NetworkWatcherRG' -f $subscriptionId
    )

    # Resource IDs starting with a prefix in the below list are ignored by the removal
    $resourceIdPrefixesToIgnore = @(
      '/subscriptions/{0}/providers/Microsoft.Security/autoProvisioningSettings/' -f $subscriptionId
      '/subscriptions/{0}/providers/Microsoft.Security/deviceSecurityGroups/' -f $subscriptionId
      '/subscriptions/{0}/providers/Microsoft.Security/iotSecuritySolutions/' -f $subscriptionId
      '/subscriptions/{0}/providers/Microsoft.Security/pricings/' -f $subscriptionId
      '/subscriptions/{0}/providers/Microsoft.Security/securityContacts/' -f $subscriptionId
      '/subscriptions/{0}/providers/Microsoft.Security/workspaceSettings/' -f $subscriptionId
    )
    [regex] $ignorePrefix_regex = '(?i)^(' + (($resourceIdPrefixesToIgnore | ForEach-Object { [regex]::escape($_) }) -join '|') + ')'


    if ($resourcesToIgnore = $resourcesToRemove | Where-Object { $_.resourceId -in $resourceIdsToIgnore -or $_.resourceId -match $ignorePrefix_regex }) {
      Write-Verbose 'Resources excluded from removal:' -Verbose
      $resourcesToIgnore | ForEach-Object { Write-Verbose ('- Ignore [{0}]' -f $_.resourceId) -Verbose }
    }

    [array] $resourcesToRemove = $resourcesToRemove | Where-Object { $_.resourceId -notin $resourceIdsToIgnore -and $_.resourceId -notmatch $ignorePrefix_regex }
    Write-Verbose ('Total number of deployments after filtering all dependency resources [{0}]' -f $resourcesToRemove.Count) -Verbose

    # Order resources
    # ===============
    [array] $resourcesToRemove = getOrderedResourcesList -ResourcesToOrder $resourcesToRemove -Order $RemovalSequence
    Write-Verbose ('Total number of deployments after final ordering of resources [{0}]' -f $resourcesToRemove.Count) -Verbose

    # Remove resources
    # ================
    if ($resourcesToRemove.Count -gt 0) {
      if ($PSCmdlet.ShouldProcess(('[{0}] resources' -f (($resourcesToRemove -is [array]) ? $resourcesToRemove.Count : 1)), 'Remove')) {
        removeResourceList -ResourcesToRemove $resourcesToRemove
      }
    } else {
      Write-Verbose 'Found [0] resources to remove'
    }
  }

  end {
    Write-Debug ('{0} exited' -f $MyInvocation.MyCommand)
  }
}

function removeAzureResource {
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory = $true, HelpMessage = 'Specify the resource id.')]
    [string]$resourceId,
    [Parameter(Mandatory = $true, HelpMessage = 'Specify the ARM API version.')]
    [string]$apiVersion
  )
  Write-Output "    - Deleting resource '$resourceId'"
  $uri = 'https://management.azure.com{0}?api-version={1}' -f $resourceId, $apiVersion
  $token = ConvertFrom-SecureString (Get-AzAccessToken).token -AsPlainText
  $headers = @{
    'Authorization' = "Bearer $token"
  }
  Write-Verbose "Deleting Resource $resourceId via the REST API using URI '$uri'." -Verbose
  $response = Invoke-WebRequest -Uri $uri -Method DELETE -Headers $headers
  If ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) {
    Write-Output "    - Response Code is '$($response.StatusCode)'."
  } else {
    Write-Error "    - Failed to delete resource '$resourceId'."
    Write-Error "    - Response Code is '$($response.StatusCode)'."
    Write-Error "    - Response: $($response.Content)"
  }
}
