---
document type: cmdlet
external help file: AzResourceTest-help.xml
HelpUri: 'https://github.com/Azure/AzurePolicyAgents/blob/main/infra/pwsh/AzResourceTest/docs/AzResourceTest/New-ARTArmPolicyRestrictionTestConfig.md'
Locale: en-AU
Module Name: AzResourceTest
ms.date: 02/23/2026
PlatyPS schema version: 2024-05-01
title: New-ARTArmPolicyRestrictionTestConfig
---

# New-ARTArmPolicyRestrictionTestConfig

## SYNOPSIS

Create a new instance of the ArmPolicyRestrictionTestConfig object.

## SYNTAX

### __AllParameterSets

```
New-ARTArmPolicyRestrictionTestConfig [-testName] <string> [-token] <string>
 [-deploymentTargetResourceId] <string> [-resourceConfig] <PolicyRestrictionResourceConfig>
 [-policyViolation] <PolicyRestrictionViolationInfo[]> [-WhatIf] [-Confirm] [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

Create a new instance of the ArmPolicyRestrictionTestConfig object. This object is used to define a test that checks the ARM resource configuration against the Azure Policy Restriction REST API for a given resource.

## EXAMPLES

### Example 1

PS C:\> $token = ConvertFrom-SecureString (Get-AzAccessToken -ResourceUrl 'https://management.azure.com/').token -AsPlainText
PS C:\> $storageAccountName = 'mystorageaccount'
PS C:\> $deploymentTargetResourceId = '/subscriptions/179e669d-ba52-4df3-816f-efb8caa30241/resourceGroups/myrg'
PS C:\> $resourcePropertiesJson = @"
"properties": {
  "publicNetworkAccess": "Enabled"
}
"@
PS C:\> $resourceConfig = @{
  resourceName       = $storageAccountName
  resourceType       = 'Microsoft.Storage/storageAccounts'
  apiVersion         = '2024-01-01'
  resourceContent    = $resourcePropertiesJson
  location = 'australiaeast'
  includeAuditEffect = $true
}
PS C:\> $violatingPolicies = @(
  @{
    policyAssignmentId= '/providers/Microsoft.Management/managementGroups/myMG/providers/Microsoft.Authorization/policyAssignments/myPolicyAssignment'
    policyDefinitionReferenceId = 'STG-001'
    resourceReference = $storageAccountName
    policyEffect      = 'Deny'
  }
)
PS C:\> $test = New-ARTArmPolicyRestrictionTestConfig 'Storage Account should violate deny policies' $token $deploymentTargetResourceId $resourceConfig $violatingPolicies

Create a new instance of the ArmPolicyRestrictionTestConfig object by passing required parameters in the correct order "testName", "token", "deploymentTargetResourceId", "resourceConfig" and "policyViolation".

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

### -deploymentTargetResourceId

The resource ID of the deployment scope.

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

### -policyViolation

The desired policy violation information for the ARM policy restriction test.

```yaml
Type: PolicyRestrictionViolationInfo[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 4
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -resourceConfig

The ARM resource configuration for the policy restriction validation.

```yaml
Type: PolicyRestrictionResourceConfig
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

Shows what would happen if the cmdlet runs. The cmdlet is not run.

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

### ArmPolicyRestrictionTestConfig

The output is an instance of the ArmPolicyRestrictionTestConfig object, which contains the configuration for the ARM policy restriction test. This object can be used to run the Pester tests against the Azure Policy Restriction REST API.

## NOTES

## RELATED LINKS
