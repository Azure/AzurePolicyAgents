<#
==========================================================
AUTHOR: Tao Yang
DATE: 15/03/2026
NAME: post-test-cleanup.ps1
VERSION: 1.0.0
COMMENT: Post test cleanup for policy integration testing
==========================================================
#>

# remove terraform deployed resources first
if ($script:terraformProvisioningState -ieq 'Succeeded') {
  Write-output "Remove Terraform deployed test resources."
  $tfDestroyParams = @{
    terraformPath               = $script:testTerraformDirectoryPath
    tfBackendConfigFileName     = $script:GlobalConfig_testTerraformBackendConfigFileName
    tfAction                    = 'destroy'
    tfBackendStateFileDirectory = $script:terraformBackendStateFileDirectory
    tfStateFileName             = $script:GlobalConfig_testTerraformStateFileName
    uninitializeTerraform       = $true
  }
  . ../.shared/deploy-destroy-policy-test-terraform-template.ps1 @tfDestroyParams
}

#determine if deployed resources should be removed based on deployment state and configuration
if ($script:bicepProvisioningState -ieq 'Succeeded' -or $script:LocalConfig_removeTestResourceGroup -eq 'true') {
  #delete deployed resources
  Write-output "Remove Bicep deployed test resources."
  . ../.shared/delete-policy-test-deployed-resources.ps1
}