---
document type: cmdlet
external help file: AzResourceTest-help.xml
HelpUri: ''
Locale: en-AU
Module Name: AzResourceTest
ms.date: 02/23/2026
PlatyPS schema version: 2024-05-01
title: New-ARTManualWhatIfTestConfig
---

# New-ARTManualWhatIfTestConfig

## SYNOPSIS

Create a new instance of the ManualWhatIfTestConfig object.

## SYNTAX

### __AllParameterSets

```
New-ARTManualWhatIfTestConfig [-testName] <string> [-actualPolicyViolation] <Object[]>
 [[-desiredPolicyViolation] <PolicyViolationInfo[]>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

Create a new instance of the ManualWhatIfTestConfig object. This object is used to define a test that checks the What-If validation result that is obtained from an external Azure Resource Manager REST API response.

## EXAMPLES

### Example 1

# Calling an external function to update the tags on a subscription and then retrieve the failed policy violations from the error response.
PS C:\> $subTagUpdateTestResponse = updateAzResourceTags -resourceId $testSubscriptionResourceId -tags $subViolatingTags -revertBack $true
PS C:\> $subTagUpdatePolicyActualViolations = ($subTagUpdateTestResponse.content | convertfrom-Json -depth 10).error.additionalInfo | Where-Object { $_.type -ieq 'policyviolation' }
PS C:\> $taggingPolicyAssignmentId = '/providers/Microsoft.Management/managementGroups/my-mg/providers/Microsoft.Authorization/policyAssignments/tagging-assignment'
PS C:\> $violatingPolicies = @(
  @{
    policyAssignmentId = $taggingPolicyAssignmentId
    policyDefinitionReferenceId = 'tag01'
  }
  @{
    policyAssignmentId = $taggingPolicyAssignmentId
    policyDefinitionReferenceId = 'tag02'
  }
)
PS C:\> $test = New-ARTManualWhatIfTestConfig -testName 'Subscription Tagging Policy violating update should fail' -actualPolicyViolation $subTagUpdatePolicyActualViolations -desiredPolicyViolation $violatingPolicies

Create a new instance of the ManualWhatIfTestConfig object by passing parameters in the correct order "testName", "actualPolicyViolation", and "desiredPolicyViolation".

## PARAMETERS

### -actualPolicyViolation

The actual policy violation returned from ARM REST API calls for the manual What-If validation test.

```yaml
Type: System.Object[]
DefaultValue: None
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

### -desiredPolicyViolation

The desired policy violation information for the manual What-If validation test.

```yaml
Type: PolicyViolationInfo[]
DefaultValue: None
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 2
  IsRequired: false
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

### ManualWhatIfTestConfig

The output is an instance of the ManualWhatIfTestConfig object, which contains the test configuration for checking the What-If validation result that is obtained from an external Azure Resource Manager REST API response.

## NOTES

## RELATED LINKS
