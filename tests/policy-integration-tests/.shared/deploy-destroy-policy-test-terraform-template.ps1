<#
==================================================================================
AUTHOR: Tao Yang
DATE: 15/07/2025
NAME: deploy-destroy-policy-test-terraform-template.ps1
VERSION: 1.0.0
COMMENT: Deploy or destroy test Terraform template for policy integration testing
==================================================================================
#>
[CmdletBinding()]
Param (
  [Parameter(Mandatory = $true, HelpMessage = 'Required. Specify the Terraform file path.')]
  [ValidateNotNullOrEmpty()]
  [string]$terraformPath,

  [parameter(Mandatory = $false, HelpMessage = "Name of the Terraform template file that contains the backend configuration.")]
  [string]$tfBackendConfigFileName = 'backend.tf',

  [parameter(Mandatory = $true, HelpMessage = "Required. The path to the Terraform state file that to be configured in the backend config.")]
  [string]$tfBackendStateFileDirectory,

  [parameter(Mandatory = $false, HelpMessage = "Optional. The file name for the terraform state file.")]
  [string]$tfStateFileName = 'terraform_state.tfstate',

  [parameter(Mandatory = $false, HelpMessage = "Optional. The file name for the deployment result file.")]
  [string]$deploymentResultFileName = 'result.json',

  [parameter(Mandatory = $false, HelpMessage = "Optional. The path to non-default workspaces that to be configured in the backend config.")]
  [AllowEmptyString()][AllowNull()]
  [string]$tfWorkspaceDir,

  [Parameter(Mandatory = $true, HelpMessage = "Terraform action (apply or destroy).")]
  [ValidateSet('apply', 'destroy')]
  [string]$tfAction,

  [Parameter(Mandatory = $false, HelpMessage = "Un-initialize Terraform after terraform apply or destroy.")]
  [bool]$uninitializeTerraform = $false
)

#region functions
function createResultFile {
  param (
    [Parameter(Mandatory = $false)]
    [string]$fileName = 'result.json',

    [Parameter(Mandatory = $true)]
    [string]$directory,

    [Parameter(Mandatory = $true)]
    [boolean]$terraformDeployment,

    [Parameter(Mandatory = $false)]
    [string]$provisioningState,

    [Parameter(Mandatory = $false)]
    [string]$deploymentOutputs
  )
  $result = @{
    terraformDeployment = $terraformDeployment
  }
  if ($provisioningState) {
    $result.add('terraformProvisioningState', $provisioningState)
  }
  if ($deploymentOutputs) {
    $result.add('terraformDeploymentOutputs', $deploymentOutputs)
  }
  $result | ConvertTo-Json -Depth 99 | Out-File -FilePath (Join-Path -Path $directory -ChildPath $fileName) -Encoding utf8
}
#endregion

#region main
#Check if the terraform directory exists
if (-not (Test-Path -Path $terraformPath )) {
  Write-Output "The specified Terraform path '$terraformPath' does not exist. 'Terraform $tfAction' Skipped."
  if ($tfAction -eq 'apply') {
    #create empty pipeline variable for terraformDeploymentOutputs
    $deploymentOutputs = '{}'
    Write-Output "##vso[task.setvariable variable=terraformDeploymentOutputs]$deploymentOutputs"
    Write-Output "##vso[task.setvariable variable=terraformDeploymentOutputs;isOutput=true]$deploymentOutputs}"
    #create an empty folder for the artifact so the publish artifact task does not fail

    if (-not (Test-Path -Path $tfBackendStateFileDirectory)) {
      New-Item -Path $tfBackendStateFileDirectory -ItemType Directory -Force | Out-Null
    }
    #create result file
    createResultFile -fileName $deploymentResultFileName -directory $tfBackendStateFileDirectory -terraformDeployment $false
  }
  exit
}
#Get the test config
$helperFunctionScriptPath = join-path $PSScriptRoot 'helper-functions.ps1'
$tfHelperFunctionScriptPath = join-path $PSScriptRoot 'terraform-helper-functions.ps1'

#load helper functions
. $helperFunctionScriptPath
. $tfHelperFunctionScriptPath

$tfBackendStateFilePath = join-path -Path $tfBackendStateFileDirectory -ChildPath $tfStateFileName
#apply or destroy terraform template
if ($tfAction -ieq 'apply') {
  if (-not (Test-Path -Path $tfBackendStateFileDirectory)) {
    New-Item -Path $tfBackendStateFileDirectory -ItemType Directory -Force | Out-Null
  }

  Write-Verbose "[$(getCurrentUTCString)]: Applying Terraform template at '$terraformPath'." -Verbose
} else {

  Write-Verbose "[$(getCurrentUTCString)]: Destroying resources previously created by Terraform template at '$terraformPath'." -Verbose
}

$params = @{
  tfPath                = $terraformPath
  tfAction              = $tfAction
  backendConfigFileName = $tfBackendConfigFileName
  localBackendPath      = $tfBackendStateFilePath
}
if ($tfWorkspaceDir.length -gt 0) {
  $params.add('localBackendWorkspaceDir', $tfWorkspaceDir)
}
applyDestroyTF @params

#remove the backend config file if it exists
$backendConfigFilePath = join-path $terraformPath $tfBackendConfigFileName
if (Test-Path -Path $backendConfigFilePath -PathType Leaf) {
  Write-Verbose "[$(getCurrentUTCString)]: Removing backend configuration file at '$backendConfigFilePath'." -Verbose
  Remove-Item -Path $backendConfigFilePath -Force -ErrorAction SilentlyContinue
} else {
  Write-Verbose "[$(getCurrentUTCString)]: Backend configuration file '$backendConfigFilePath' does not exist, skipping removal." -Verbose
}

#If terraform apply, parse the terraform output and store as the pipeline variable
if ($tfAction -eq 'apply') {
  $script:terraformProvisioningState = $script:tfExitCode ? 'Succeeded' : 'Failed'

  Write-Verbose "[$(getCurrentUTCString)]: Parsing Terraform output." -Verbose
  $tfState = Get-Content -path $tfBackendStateFilePath -raw | ConvertFrom-Json -depth 99
  $script:terraformDeploymentOutputs = $tfState.outputs | ConvertTo-Json -depth 99 -EnumsAsString -EscapeHandling 'EscapeNonAscii' -Compress
  createResultFile -fileName $deploymentResultFileName -directory $tfBackendStateFileDirectory -terraformDeployment $true -provisioningState $provisioningState -deploymentOutputs $script:terraformDeploymentOutputs
  $tfStateFile = Get-item -Path $tfBackendStateFilePath -ErrorAction Stop
  $tfStateFileDir = $tfStateFile.DirectoryName

  $tfStateFileName = $tfStateFile.Name
}

if ($uninitializeTerraform -eq $true) {
  Write-Verbose "[$(getCurrentUTCString)]: Uninitializing Terraform at '$terraformPath'." -Verbose
  uninitializeTFProject -tfPath $terraformPath
}

Write-Output "Done."
#endregion
