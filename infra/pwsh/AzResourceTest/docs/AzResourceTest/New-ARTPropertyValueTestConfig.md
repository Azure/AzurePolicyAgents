---
document type: cmdlet
external help file: AzResourceTest-help.xml
HelpUri: 'https://github.com/Azure/AzurePolicyAgents/blob/main/infra/pwsh/AzResourceTest/docs/AzResourceTest/New-ARTPropertyValueTestConfig.md'
Locale: en-AU
Module Name: AzResourceTest
ms.date: 02/23/2026
PlatyPS schema version: 2024-05-01
title: New-ARTPropertyValueTestConfig
---

# New-ARTPropertyValueTestConfig

## SYNOPSIS

Create a new instance of the PropertyValueTestConfig object. This object is used to define a test that checks the value of a property.

## SYNTAX

### __AllParameterSets

```
New-ARTPropertyValueTestConfig [-testName] <string> [-token] <string> [-resourceId] <string>
 [-valueType] <string> [-property] <string> [-condition] <string> [-value] <string>
 [-resourceType <string>] [-apiVersion <string>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

Create a new instance of the PropertyValueTestConfig object.
This object is used to define a test that checks the value of a property.

## EXAMPLES

### Example 1

PS C:\> $token = ConvertFrom-SecureString (Get-AzAccessToken -ResourceUrl 'https://management.azure.com/').token -AsPlainText
PS C:\> $resourceId = '/subscriptions/179e669d-ba52-4df3-816f-efb8caa30241/resourceGroups/myrg/providers/Microsoft.Storage/storageAccounts/mystorage'
PS C:\> $test = New-ARTPropertyValueTestConfig 'Network ACL Default Action Should be Deny' $token $resourceId 'string' 'properties.networkAcls.defaultAction' 'equals' 'Deny'

Create a new instance of the PropertyValueTestConfig object by passing parameters in the correct order "testName", "token", "resourceId", "valueType", "property", "condition", and "value".

### Example 2

PS C:\> $token = ConvertFrom-SecureString (Get-AzAccessToken -ResourceUrl 'https://management.azure.com/').token -AsPlainText
PS C:\> $resourceId = '/subscriptions/179e669d-ba52-4df3-816f-efb8caa30241/resourceGroups/myrg/providers/Microsoft.Network/networkSecurityGroups/mynsg'
PS C:\> $test = New-ARTPropertyValueTestConfig 'Destination port range must not be wildcard(*)' $token $resourceId 'string' 'properties.securityRules[*].properties.destinationPortRange' 'notequals' '*'

Create a new instance of the PropertyValueTestConfig object by passing parameters in the correct order "testName", "token", "resourceId", "valueType", "property", "condition", and "value".
The property contains '[*]', which means it is an array property and each element of the array will be checked individually.
Note there can only be up to one (1) '[*]' in the property path.

## PARAMETERS

### -apiVersion

The Azure Resource Manager API version.

```yaml
Type: System.String
DefaultValue: None
SupportsWildcards: false
Aliases: []
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

### -condition

The condition of the value comparison.
Supported values are 'equals', 'notEquals', 'greater', 'less', 'greaterequal', 'lessequal'.

```yaml
Type: System.String
DefaultValue: None
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 5
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

### -property

The resource property to check.
The property can contain up to one (1) instance of '[*]', which means it is an array property and each element of the array will be checked individually.

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

### -resourceType

The resource type.

```yaml
Type: System.String
DefaultValue: None
SupportsWildcards: false
Aliases: []
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

### -value

The desired value of the property.

```yaml
Type: System.String
DefaultValue: None
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 6
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -valueType

Type of the resource property value.
Supported types are 'string', 'number', 'boolean'.

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

### PropertyValueTestConfig

The output is an instance of the PropertyValueTestConfig object, which contains the test configuration for checking the value of a resource property.

## NOTES

## RELATED LINKS
