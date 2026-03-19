---
document type: cmdlet
external help file: AzResourceTest-help.xml
HelpUri: 'https://github.com/Azure/AzurePolicyAgents/blob/main/infra/pwsh/AzResourceTest/docs/AzResourceTest/New-ARTPolicyStateTestConfig.md'
Locale: en-AU
Module Name: AzResourceTest
ms.date: 02/23/2026
PlatyPS schema version: 2024-05-01
title: New-ARTPolicyStateTestConfig
---

# New-ARTPolicyStateTestConfig

## SYNOPSIS

Create a new instance of the PolicyStateTestConfig object.

## SYNTAX

### __AllParameterSets

```
New-ARTPolicyStateTestConfig [-testName] <string> [-token] <string> [-resourceId] <string>
 [-policyAssignmentId] <string> [-requiredComplianceState] <string>
 [[-policyDefinitionReferenceId] <string>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

Create a new instance of the PolicyStateTestConfig object.
This object is used to define a test that checks the compliance state of a policy assignment or policy initiative assignment.

## EXAMPLES

### Example 1

PS C:\> $token = ConvertFrom-SecureString (Get-AzAccessToken -ResourceUrl 'https://management.azure.com/').token -AsPlainText
PS C:\> $resourceId = '/subscriptions/179e669d-ba52-4df3-816f-efb8caa30241/resourceGroups/myRg/providers/Microsoft.Storage/storageAccounts/mystorageaccount'
PS C:\> $policyAssignmentId = '/providers/Microsoft.Management/managementGroups/myMG/providers/Microsoft.Authorization/policyAssignments/myPolicyAssignment'
PS C:\> $test = New-ARTPolicyStateTestConfig 'Audit CMK Encryption policy should be Compliant' $token $resourceId $policyAssignmentId 'Compliant' 'ReferenceIdOfPolicyDefinition'

Create a new instance of the PolicyStateTestConfig object by passing parameters in the correct order "testName", "token", "resourceId", "policyAssignmentId", "requiredComplianceState", and "policyDefinitionReferenceId".

## PARAMETERS

### -Confirm

Prompts you for confirmation before running the cmdlet.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
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

### -policyAssignmentId

The policy assignment ID to check.

```yaml
Type: System.String
DefaultValue: None
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

### -policyDefinitionReferenceId

When a policy initiative is assigned, the policy definition reference ID to check.
If not specified, the test will check the compliance state of the policy assignment.

```yaml
Type: System.String
DefaultValue: None
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 5
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -requiredComplianceState

The desired compliance state of the policy assignment.

```yaml
Type: System.String
DefaultValue: None
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

### -resourceId

The resource ID to check.

```yaml
Type: System.String
DefaultValue: None
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
DefaultValue: None
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
DefaultValue: False
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

### PolicyStateTestConfig

The output is an instance of the PolicyStateTestConfig object, which contains the test configuration for checking the compliance state of a policy assignment or policy initiative assignment.

## NOTES

## RELATED LINKS
