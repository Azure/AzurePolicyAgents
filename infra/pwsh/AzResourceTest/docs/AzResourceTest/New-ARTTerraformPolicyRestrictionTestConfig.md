---
document type: cmdlet
external help file: AzResourceTest-help.xml
HelpUri: ''
Locale: en-AU
Module Name: AzResourceTest
ms.date: 02/23/2026
PlatyPS schema version: 2024-05-01
title: New-ARTTerraformPolicyRestrictionTestConfig
---

# New-ARTTerraformPolicyRestrictionTestConfig

## SYNOPSIS

Create a new instance of the TerraformPolicyRestrictionTestConfig object.

## SYNTAX

### __AllParameterSets

```
New-ARTTerraformPolicyRestrictionTestConfig [-testName] <string> [-token] <string>
 [-terraformDirectory] <string> [-policyViolation] <PolicyRestrictionViolationInfo[]> [-WhatIf]
 [-Confirm] [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

Create a new instance of the TerraformPolicyRestrictionTestConfig object. This object is used to define a test that checks the resource configuration from Terraform plan result against the Azure Policy Restriction REST API for a given resource.

Only the resources created by Terraform AzAPI provider are supported.

## EXAMPLES

### Example 1

# Must run az cli command to get the access token because Terraform only supports az cli authentication.
PS C:\> $token = $(az account get-access-token --resource 'https://management.azure.com/' | convertfrom-json).accessToken
PS C:\> $terraformDirectory = 'C:\Terraform\MyProject'
PS C:\> $violatingPolicies = @(
  @{
    policyAssignmentId = '/providers/Microsoft.Management/managementGroups/myMG/providers/Microsoft.Authorization/policyAssignments/myPolicyAssignment'
    policyDefinitionReferenceId = 'STG-001'
    resourceReference = 'azapi_resource.storage_account'
    policyEffect = 'Deny'
  }
)
PS C:\> $test = New-ARTTerraformPolicyRestrictionTestConfig 'Storage Account should violate deny policies' $token $terraformDirectory $violatingPolicies

Create a new instance of the TerraformPolicyRestrictionTestConfig object by passing required parameters in the correct order "testName", "token", "terraformDirectory" and "policyViolation".

## PARAMETERS

### -Confirm

Prompts you for confirmation before running the cmdlet.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases:
- cf
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -policyViolation

The desired policy violation information for the Terraform Plan test.

```yaml
Type: PolicyRestrictionViolationInfo[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 3
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -terraformDirectory

The path to the Terraform file directory.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 2
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -testName

Name of the Pester test.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -token

The Azure OAuth token.
This is required to invoke the Azure Resource Manager REST APIs.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 1
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -WhatIf

Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases:
- wi
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### TerraformPolicyRestrictionTestConfig

The output is an instance of the TerraformPolicyRestrictionTestConfig object, which contains the configuration for the Terraform policy restriction test. This object can be used to run the Pester tests against the Azure Policy Restriction REST API.

## NOTES

## RELATED LINKS
