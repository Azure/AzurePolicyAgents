---
document type: cmdlet
external help file: AzResourceTest-help.xml
HelpUri: 'https://github.com/Azure/AzurePolicyAgents/blob/main/infra/pwsh/AzResourceTest/docs/AzResourceTest/New-ARTPropertyCountTestConfig.md'
Locale: en-AU
Module Name: AzResourceTest
ms.date: 02/23/2026
PlatyPS schema version: 2024-05-01
title: New-ARTPropertyCountTestConfig
---

# New-ARTPropertyCountTestConfig

## SYNOPSIS

Create a new instance of the PropertyCountTestConfig object. This object is used to define a test that checks the count of a property value.

## SYNTAX

### __AllParameterSets

```
New-ARTPropertyCountTestConfig [-testName] <string> [-token] <string> [-resourceId] <string>
 [-property] <string[]> [-condition] <string> [-count] <int> [[-operator] <string>]
 [-resourceType <string>] [-apiVersion <string>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

Create a new instance of the PropertyCountTestConfig object.
This object is used to define a test that checks the count of a property value.

## EXAMPLES

### Example 1

PS C:\> $token = ConvertFrom-SecureString (Get-AzAccessToken -ResourceUrl 'https://management.azure.com/').token -AsPlainText
PS C:\> $resourceId = '/subscriptions/179e669d-ba52-4df3-816f-efb8caa30241/resourceGroups/myRg/providers/Microsoft.Storage/storageAccounts/mystorageaccount'
PS C:\> $test = New-ARTPropertyCountTestConfig 'Should Use Private Endpoints' $token $resourceId @('properties.privateEndpointConnections', 'properties.manualPrivateEndpointConnections') 'greaterequal' 1 'concat'

Create a new instance of the PropertyCountTestConfig object by passing parameters in the correct order "testName", "token", "resourceId", "property", "condition", "count", and "operator".

### Example 2

PS C:\> $token = ConvertFrom-SecureString (Get-AzAccessToken -ResourceUrl 'https://management.azure.com/').token -AsPlainText
PS C:\> $resourceId = '/subscriptions/179e669d-ba52-4df3-816f-efb8caa30241/resourceGroups/myRg/providers/Microsoft.Storage/storageAccounts/mystorageaccount'
PS C:\> $test = New-ARTPropertyCountTestConfig 'Should have environment tag' $token $resourceId 'tags.environment' 'equals' 1

Create a new instance of the PropertyCountTestConfig object by passing parameters in the correct order "testName", "token", "resourceId", "property", "condition", and "count".

### Example 3

PS C:\> $token = ConvertFrom-SecureString (Get-AzAccessToken -ResourceUrl 'https://management.azure.com/').token -AsPlainText
PS C:\> $resourceId = '/subscriptions/179e669d-ba52-4df3-816f-efb8caa30241/resourceGroups/NetworkWatcherRG/providers/microsoft.network/networkwatchers/networkWatcher_australiaeast/flowlogs/vnet01-flowlog'
PS C:\> $test = New-ARTPropertyCountTestConfig 'VNet Flow Log (Australia East) Must Be Configured to use Log Analytics Workspace' -token $token -resourceId $resourceId -property 'properties.flowAnalyticsConfiguration.networkWatcherFlowAnalyticsConfiguration.workspaceResourceId' -condition 'equals' -count 1 -apiVersion '2024-07-01'

Create a new instance of the PropertyCountTestConfig object by specifying the -apiVersion parameter. In this example, the API version is explicitly specified as '2024-07-01'. When the -apiVersion parameter is specified, the cmdlet will make an ARM GET API call instead of searching the resource via Azure Resource Graph. This is useful when the resource you are looking for is not supported by Azure Resource Graph.

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
  Position: 4
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

### -count

The desired count of the property value.

```yaml
Type: System.Int32
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

### -operator

The operator to use when multiple properties are provided.
Supported values are 'and', 'or', 'concat'.

```yaml
Type: System.String
DefaultValue: None
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 6
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

```yaml
Type: System.String[]
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

### PropertyCountTestConfig

The output is an instance of the PropertyCountTestConfig object, which contains the test configuration for checking the count of a resource property.

## NOTES

## RELATED LINKS
