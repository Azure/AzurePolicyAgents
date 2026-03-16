---
document type: cmdlet
external help file: AzResourceTest-help.xml
HelpUri: ''
Locale: en-AU
Module Name: AzResourceTest
ms.date: 02/23/2026
PlatyPS schema version: 2024-05-01
title: New-ARTResourceExistenceTestConfig
---

# New-ARTResourceExistenceTestConfig

## SYNOPSIS

Create a new instance of the ResourceExistenceTestConfig object. This object is used to define a test that checks the existence of a resource.

## SYNTAX

### __AllParameterSets

```
New-ARTResourceExistenceTestConfig [-testName] <string> [-token] <string> [-resourceId] <string>
 [-condition] <string> [[-apiVersion] <string>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

Create a new instance of the ResourceExistenceTestConfig object. This object is used to define a test that checks the existence of a resource.

## EXAMPLES

### Example 1

PS C:\> $token = ConvertFrom-SecureString (Get-AzAccessToken -ResourceUrl 'https://management.azure.com/').token -AsPlainText
PS C:\> $diagnosticSettingsIdSuffix = '/providers/microsoft.insights/diagnosticSettings/setByPolicyLAW'
PS C:\> $diagnosticSettingsAPIVersion = '2021-05-01-preview'
PS C:\> $resourceId = '/subscriptions/179e669d-ba52-4df3-816f-efb8caa30241/resourceGroups/myrg/providers/Microsoft.Storage/storageAccounts/mystorage'
PS C:\> $diagnosticSettingsId = "{0}{1}" -f $resourceId, $diagnosticSettingsIdSuffix
PS C:\> $test = New-ARTResourceExistenceTestConfig 'Diagnostic Settings Must Be Configured' $token $diagnosticSettingsId 'exists' '2021-05-01-preview'

Create a new instance of the ResourceExistenceTestConfig object by passing required parameters in the correct order.
It can be used to check if the diagnostic setting for the storage account exists.
The resource provider's API version is required in this example because diagnosticSettings resources are not available in Azure resource graph.

### Example 2

PS C:\> $token = ConvertFrom-SecureString (Get-AzAccessToken -ResourceUrl 'https://management.azure.com/').token -AsPlainText
PS C:\> $blobPrivateDNSARecordId = "/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net/A/{2}" -f $privateDNSSubscriptionId, $privateDNSResourceGroup, $resourceName

PS C:\> $test = New-ARTResourceExistenceTestConfig 'Private DNS Record for Blob PE must exist' $token $blobPrivateDNSARecordId 'exists'

Create a new instance of the ResourceExistenceTestConfig object by passing required parameters in the correct order.
It can be used to check if the A record for the Private Endpoint exists in the storage blob's private DNS zone.
The resource provider's API version is not required in this example because Private DNS zone A records are available in Azure resource graph.

## PARAMETERS

### -apiVersion

The Azure resource provider API version.
When this parameter is not provided, the test will try to locate the resource using Azure Resource Graph.
This value must be provided if the specific resource type is not supported by Azure Resource Graph.

```yaml
Type: System.String
DefaultValue: None
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 4
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -condition

The desired condition of the resource existence test.
Supported values are 'exists' and 'notExists'.

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

### -resourceId

The resource Id to check.

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

Name of the pester test.

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

### ResourceExistenceTestConfig

The output is an instance of the ResourceExistenceTestConfig object, which contains the test configuration for checking the existence of a resource.

## NOTES

## RELATED LINKS

{{ Fill in the related links here }}

