---
document type: cmdlet
external help file: AzResourceTest-help.xml
HelpUri: 'https://github.com/Azure/AzurePolicyAgents/blob/main/infra/pwsh/AzResourceTest/docs/AzResourceTest/Get-ARTResourceConfiguration.md'
Locale: en-AU
Module Name: AzResourceTest
ms.date: 02/23/2026
PlatyPS schema version: 2024-05-01
title: Get-ARTResourceConfiguration
---

# Get-ARTResourceConfiguration

## SYNOPSIS

Get the configuration of an existing Azure resource via Azure Resource Graph search.

## SYNTAX

### CustomQuery

```
Get-ARTResourceConfiguration -ScopeType <string> -Token <string> -customQuery <string>
 [-Scope <string>] [<CommonParameters>]
```

### PredefinedQuery

```
Get-ARTResourceConfiguration -ScopeType <string> -Token <string> -resourceType <string>
 [-Scope <string>] [-azureResourceGraphTable <string>] [-resourceIds <string[]>]
 [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

Get the configuration of an existing Azure resource via Azure Resource Graph search.

## EXAMPLES

### Example 1

PS C:\> $token = ConvertFrom-SecureString (Get-AzAccessToken -ResourceUrl 'https://management.azure.com/').token -AsPlainText
PS C:\> Get-ARTResourceConfiguration -Scope "mySubscription" -Token $token -ScopeType "subscription" -resourceType "Microsoft.Compute/virtualMachines"

Get all the virtual machines in the subscription "mySubscription".

### Example 2

PS C:\> $token = ConvertFrom-SecureString (Get-AzAccessToken -ResourceUrl 'https://management.azure.com/').token -AsPlainText
PS C:\> Get-ARTResourceConfiguration -ScopeType "tenant" -resourceType "Microsoft.Storage/storageAccounts" -Token $token -resourceIds '/subscriptions/179e669d-ba52-4df3-816f-efb8caa30241/resourceGroups/myRg/providers/Microsoft.Storage/storageAccounts/mystorageaccount'

Get a specific storage account by searching the resource ID in the tenant scope.

## PARAMETERS

### -azureResourceGraphTable

Optional.
The table to search for in Azure Resource Graph.

```yaml
Type: System.String
DefaultValue: None
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: PredefinedQuery
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -customQuery

The custom ARG search query.

```yaml
Type: System.String
DefaultValue: None
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: CustomQuery
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -resourceIds

The resource IDs to search for in Azure Resource Graph.

```yaml
Type: System.String[]
DefaultValue: None
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: PredefinedQuery
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -resourceType

The resource type to search for in Azure Resource Graph.

```yaml
Type: System.String
DefaultValue: None
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: PredefinedQuery
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Scope

The scope for the ARG search query.
This can be a subscription ID, subscription name, or a management group name.

```yaml
Type: System.String
DefaultValue: None
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: CustomQuery
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
- Name: PredefinedQuery
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ScopeType

The scope type for the ARG search query.
Possible values are 'subscription', 'managementGroup', and 'tenant'.

```yaml
Type: System.String
DefaultValue: None
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: CustomQuery
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
- Name: PredefinedQuery
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Token

The Azure OAuth token.
This is required to invoke the Azure Resource Manager REST APIs.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: CustomQuery
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
- Name: PredefinedQuery
  Position: Named
  IsRequired: true
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

### System.String

Resource configuration in JSON format.

## NOTES

## RELATED LINKS
