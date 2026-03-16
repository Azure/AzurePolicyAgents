#function to create a Terraform backend configuration file for local backend
function setTfLocalBackend {
  [CmdletBinding()]
  [OutputType([string])]
  param (
    [parameter(Mandatory = $true, HelpMessage = "Path to the Terraform template directory.")]
    [string]$path,

    [parameter(Mandatory = $false, HelpMessage = "The path to the Terraform state file that to be configured in the backend config.")]
    [string]$localPath = "./terraform.tfstate",

    [parameter(Mandatory = $false, HelpMessage = "The path to non-default workspaces that to be configured in the backend config.")]
    [AllowEmptyString()][AllowNull()]
    [string]$localWorkspaceDir
  )

  $backendConfig = "terraform {`n"
  $backendConfig += "  backend `local` {`n"
  $backendConfig += "    path = `"$localPath`"`n"
  if ($localWorkspaceDir) {
    $backendConfig += "    workspace_dir = `"$localWorkspaceDir`"`n"
  }
  $backendConfig += "  }`n"
  $backendConfig += "}`n"
  Write-Verbose "Backend configuration content:"  -Verbose
  Write-Verbose $backendConfig -Verbose
  $backendConfig | Out-File -FilePath $path -Encoding utf8
  Write-Verbose "Terraform backend configuration file created '$path'. It sets local path to '$localPath' and workspace directory to '$localWorkspaceDir'."
}

#Function to check if Terraform is initialized
function isTFInitialized {
  [CmdletBinding()]
  [OutputType([bool])]
  param (
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Container })]
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
    Write-Verbose "No .tfvars file found in the specified path: $path." -verbose
    return $null
  }
}

#Function to apply terraform template
function applyDestroyTF {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true, HelpMessage = "Path to the Terraform template directory.")]
    [validateScript({ Test-Path $_ -PathType Container })]
    [string]$tfPath,

    [Parameter(Mandatory = $true, HelpMessage = "Terraform action (apply or destroy).")]
    [ValidateSet('apply', 'destroy')]
    [string]$tfAction,

    [parameter(Mandatory = $false, HelpMessage = "Path to the Terraform template file that contains the backend configuration.")]
    [ValidateNotNullOrEmpty()]
    [string]$backendConfigFileName = 'backend.tf',

    [parameter(Mandatory = $false, HelpMessage = "The path to the Terraform state file that to be configured in the backend config.")]
    [string]$localBackendPath = "./terraform.tfstate",

    [parameter(Mandatory = $false, HelpMessage = "The path to non-default workspaces that to be configured in the backend config.")]
    [AllowEmptyString()][AllowNull()]
    [string]$localBackendWorkspaceDir
  )
  $backendConfigFilePath = join-path $tfPath $backendConfigFileName
  Write-Verbose "Create Terraform backend configuration file at '$backendConfigFilePath'." -verbose
  $localBackendParams = @{
    path      = $backendConfigFilePath
    localPath = $localBackendPath
  }
  if ($localBackendWorkspaceDir) {
    $localBackendParams.add('localWorkspaceDir', $localBackendWorkspaceDir)
  }
  setTfLocalBackend @localBackendParams

  Write-Verbose "Finding .tfvars file in the specified path: $tfPath." -verbose
  $tfVarsFile = findTFVarsFile -path $tfPath
  # If multiple .tfvars files are found, throw an error
  if ($tfVarsFile.Count -gt 1) {
    Write-Error "Multiple .tfvars files found in the specified path: $tfPath. Please specify a single .tfvars file."
    Exit 1
  } else {
    Write-Verbose "Number of .tfvars files found: $($tfVarsFile.Count):" -verbose
    foreach ($file in $tfVarsFile) {
      Write-Verbose "  - '$file'" -verbose
    }
  }

  Write-Verbose "Make sure the Terraform template is initialized in the path: $tfPath." -verbose
  $currentDir = Get-Location
  if (-not (isTFInitialized -path $tfPath)) {
    Write-Verbose "Terraform is not initialized in the specified path: $tfPath. Trying to initialize..."
    try {
      Set-Location -Path $tfPath
      terraform init -input=false
      $exitCode = $?
      if ($exitCode -ne $true) {
        #set the location back to the original
        Set-Location -Path $currentDir
        Write-Error "Terraform initialization failed in the specified path: $tfPath. Please check the output for details."
        Exit 1
      }
      #set the location back to the original
      Set-Location -Path $currentDir

    } catch {
      Write-Error "Failed to initialize Terraform in the specified path: $tfPath. Error: $_. Try manually running 'terraform init' in the directory."
      #set the location back to the original
      Set-Location -Path $currentDir
      Exit 1
    }
  } else {
    Write-Verbose "Terraform is already initialized in the specified path: $tfPath."
  }
  # Run the Terraform command
  Set-Location -Path $tfPath
  if ($tfVarsFile) {
    Write-Verbose "Running Terraform Plan using .tfvars file: $tfVarsFile" -verbose
    terraform plan --var-file="$tfVarsFile"
    Write-Verbose "Running Terraform $tfAction using .tfvars file: $tfVarsFile" -verbose
    terraform $tfAction --var-file="$tfVarsFile" -auto-approve
  } else {
    Write-Verbose "Running Terraform Plan without variables." -verbose
    terraform plan
    Write-Verbose "No .tfvars file found. Running Terraform $tfAction without variables." -verbose
    terraform $tfAction -auto-approve
  }
  $script:tfExitCode = $?
  Set-Location -Path $currentDir
  if ($script:tfExitCode -ne $true) {
    Write-Error "Terraform $tfAction failed in the specified path: $tfPath. Please check the output for details."
  }
}

# Function to sanitize the terraform project and uninitialize it
function uninitializeTFProject {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true, HelpMessage = "Path to the Terraform template directory.")]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$tfPath
  )

  #Check if the the terraform project is initialized
  if (-not (isTFInitialized -path $tfPath)) {
    Write-Verbose "Terraform project at '$tfPath' is not initialized. No need to uninitialize." -Verbose
    return
  } else {
    Write-Verbose "Terraform project at '$tfPath' is initialized. Proceeding to uninitialize." -Verbose
    $tfLockFile = Join-Path -Path $tfPath -ChildPath ".terraform.lock.hcl"
    $tfChildDir = Join-Path -Path $tfPath -ChildPath ".terraform"
    if ( Test-Path -Path $tfLockFile -PathType Leaf) {
      Write-Verbose "[$(getCurrentUTCString)]: Removing Terraform lock file at '$tfLockFile'." -Verbose
      Remove-Item -Path $tfLockFile -Force | Out-Null
    }
    if (Test-Path -Path $tfChildDir -PathType Container) {
      Write-Verbose "[$(getCurrentUTCString)]: Removing Terraform child directory at '$tfChildDir'." -Verbose
      Remove-Item -Path $tfChildDir -Recurse -Force | Out-Null
    }
  }
}
