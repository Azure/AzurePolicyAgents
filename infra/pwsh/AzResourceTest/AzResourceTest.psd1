@{

  # Script module or binary module file associated with this manifest.
  RootModule        = 'AzResourceTest.psm1'

  # Version number of this module.
  ModuleVersion     = '2.0.2'

  # Supported PSEditions
  # CompatiblePSEditions = @()

  # ID used to uniquely identify this module
  GUID              = 'd931d747-f3b0-4071-ac74-e7f6995ebe7d'

  # Author of this module
  Author            = 'Microsoft Corporation'

  # Company or vendor of this module
  CompanyName       = 'Microsoft Corporation'

  # Copyright statement for this module
  Copyright         = 'Copyright (c) Microsoft Corporation.'

  # Description of the functionality provided by this module
  Description       = 'Azure resource configuration tests using Pester and Azure Resource Graph'

  # Minimum version of the PowerShell engine required by this module
  PowerShellVersion = '7.0.0'

  # Name of the PowerShell host required by this module
  # PowerShellHostName = ''

  # Minimum version of the PowerShell host required by this module
  # PowerShellHostVersion = ''

  # Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
  # DotNetFrameworkVersion = ''

  # Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
  # ClrVersion = ''

  # Processor architecture (None, X86, Amd64) required by this module
  # ProcessorArchitecture = ''

  # Modules that must be imported into the global environment prior to importing this module
  RequiredModules   = @(
    @{ModuleName = "pester"; ModuleVersion = "5.5.0"; Guid = "a699dea5-2c73-4616-a270-1f7abb777e71" }
  )

  # Assemblies that must be loaded prior to importing this module
  # RequiredAssemblies = @()

  # Script files (.ps1) that are run in the caller's environment prior to importing this module.
  # ScriptsToProcess = @()

  # Type files (.ps1xml) to be loaded when importing this module
  # TypesToProcess = @()

  # Format files (.ps1xml) to be loaded when importing this module
  # FormatsToProcess = @()

  # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
  NestedModules     = @( 'AzResourceTest-helper.psm1', 'AzResourceTest-type.psm1')

  # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
  FunctionsToExport = @(
    'Test-ARTResourceConfiguration',
    'New-ARTPropertyValueTestConfig',
    'New-ARTPropertyCountTestConfig',
    'New-ARTPolicyStateTestConfig',
    'New-ARTWhatIfDeploymentTestConfig',
    'New-ARTResourceExistenceTestConfig',
    'New-ARTManualWhatIfTestConfig',
    'New-ARTTerraformPolicyRestrictionTestConfig',
    'New-ARTArmPolicyRestrictionTestConfig',
    'Get-ARTResourceConfiguration'
  )

  # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
  CmdletsToExport   = @()

  # Variables to export from this module
  VariablesToExport = @()

  # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
  AliasesToExport   = @()

  # DSC resources to export from this module
  # DscResourcesToExport = @()

  # List of all modules packaged with this module
  # ModuleList = @()

  # List of all files packaged with this module
  FileList          = @('AzResourceTest.psd1', 'AzResourceTest.psm1', 'AzResourceTest-helper.psm1', 'AzResourceTest-help.xml', 'AzResourceTest-type.psm1', 'Az.Resource.Tests.ps1')

  # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
  PrivateData       = @{

    PSData = @{

      # Tags applied to this module. These help with module discovery in online galleries.
      Tags                       = @('Azure', 'AzurePolicy', 'Pester')

      # A URL to the license for this module.
      LicenseUri                 = 'https://github.com/Azure/AzurePolicyAgents/blob/main/LICENSE'

      # A URL to the main website for this project.
      ProjectUri                 = 'https://github.com/Azure/AzurePolicyAgents/tree/main/infra/pwsh/AzResourceTest'

      # A URL to an icon representing this module.
      # IconUri = ''

      # ReleaseNotes of this module
      # ReleaseNotes = ''

      # Prerelease string of this module
      # Prerelease = ''

      # Flag to indicate whether the module requires explicit user acceptance for install/update/save
      # RequireLicenseAcceptance = $false

      # External dependent modules of this module
      ExternalModuleDependencies = @('Pester')

    } # End of PSData hashtable

  } # End of PrivateData hashtable

  # HelpInfo URI of this module
  # HelpInfoURI = ''

  # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
  # DefaultCommandPrefix = ''

}

