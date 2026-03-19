---
document type: cmdlet
external help file: AzResourceTest-help.xml
HelpUri: ''
Locale: en-AU
Module Name: AzResourceTest
ms.date: 02/23/2026
PlatyPS schema version: 2024-05-01
title: Test-ARTResourceConfiguration
---

# Test-ARTResourceConfiguration

## SYNOPSIS

Invoke Azure resource tests by passing defined test cases.

## SYNTAX

### ProduceOutputFile

```
Test-ARTResourceConfiguration [-OutputFile] <string> [[-OutputFormat] <string>] -tests <Object[]>
 -testTitle <string> -contextTitle <string> -testSuiteName <string> [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

Invoke Azure resource tests by passing defined test cases.

## EXAMPLES

### Example 1

PS C:\> $tests = @()
PS C:\> $resourceId = '/subscriptions/179e669d-ba52-4df3-816f-efb8caa30241/resourceGroups/myrg/providers/Microsoft.Storage/storageAccounts/mystorage'
PS C:\> $token = ConvertFrom-SecureString (Get-AzAccessToken -ResourceUrl 'https://management.azure.com/').token -AsPlainText
PS C:\> $tests += New-ARTPropertyValueTestConfig 'Network ACL Default Action Should be Deny' $token $resourceId 'string' 'properties.networkAcls.defaultAction' 'equals' 'Deny'
PS C:\> $tests += New-ARTPropertyValueTestConfig 'Double Encryption must be enabled' $token $resourceId 'boolean' 'properties.encryption.requireInfrastructureEncryption' 'equals' $true
PS C:\> $params = @{
  tests = $tests
  testTitle = 'Storage Account Configuration Test'
  contextTitle = 'Storage Configuration'
  testSuiteName = 'StorageAccountTest'
  OutputFile = join-path $PSScriptRoot "TEST-Resource-Config-$testSuiteName.XML"
  OutputFormat = 'NUnitXml'
}
PS C:\> Test-ARTResourceConfiguration @params

Define two tests for an existing storage account and pass the defined test cases to the Azure Resource Test.

## PARAMETERS

### -contextTitle

The title of the Pester Context block.

```yaml
Type: System.String
DefaultValue: None
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -OutputFile

The path to the output file.

```yaml
Type: System.String
DefaultValue: None
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: ProduceOutputFile
  Position: 5
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -OutputFormat

The output format of the test result.
Supported values are 'NUnitXml' and 'LegacyNUnitXML'.

```yaml
Type: System.String
DefaultValue: None
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: ProduceOutputFile
  Position: 6
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -tests

The tests to run against the resource configuration.

```yaml
Type: System.Object[]
DefaultValue: None
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -testSuiteName

The name of the test suite.

```yaml
Type: System.String
DefaultValue: None
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -testTitle

The title of the Pester Test.
This is the name of the Pester Describe block.

```yaml
Type: System.String
DefaultValue: None
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
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

The Pester test result.

## NOTES

## RELATED LINKS
