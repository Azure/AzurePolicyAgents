---
document type: cmdlet
external help file: AzResourceTest-help.xml
HelpUri: 'https://github.com/Azure/AzurePolicyAgents/blob/main/infra/pwsh/AzResourceTest/docs/AzResourceTest/New-ARTWhatIfDeploymentTestConfig.md'
Locale: en-AU
Module Name: AzResourceTest
ms.date: 02/23/2026
PlatyPS schema version: 2024-05-01
title: New-ARTWhatIfDeploymentTestConfig
---

# New-ARTWhatIfDeploymentTestConfig

## SYNOPSIS

Create a new instance of the WhatIfDeploymentTestConfig object. This object is used to define a test that checks the What-If template validation for a given Bicep or ARM template.

## SYNTAX

### __AllParameterSets

```
New-ARTWhatIfDeploymentTestConfig [-testName] <string> [-token] <string>
 [-templateFilePath] <string> [-deploymentTargetResourceId] <string>
 [-requiredWhatIfStatus] <string> [[-policyViolation] <PolicyViolationInfo[]>]
 [-parameterFilePath <string>] [-httpTimeoutSeconds <int>] [-longRunningJobTimeoutSeconds <int>]
 [-maxRetry <int>] [-azureLocation <string>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

Create a new instance of the WhatIfDeploymentTestConfig object.
This object is used to define a test that checks the What-If template validation for a given Bicep or ARM template.

## EXAMPLES

### Example 1

PS C:\> $token = ConvertFrom-SecureString (Get-AzAccessToken -ResourceUrl 'https://management.azure.com/').token -AsPlainText
PS C:\> $whatIfDeploymentTargetResourceId = '/subscriptions/179e669d-ba52-4df3-816f-efb8caa30241'
PS C:\> $whatIfSuccessTemplatePath = join-path $PSScriptRoot 'good.bicep'
PS C:\> $test = New-ARTWhatIfDeploymentTestConfig 'Policy abiding deployment should succeed' $token $whatIfSuccessTemplatePath $whatIfDeploymentTargetResourceId 'Succeeded'

Create a new instance of the WhatIfDeploymentTestConfig object by passing required parameters in the correct order "testName", "token", "templateFilePath", "deploymentTargetResourceId", "requiredWhatIfStatus".

### Example 2

PS C:\> $token = ConvertFrom-SecureString (Get-AzAccessToken -ResourceUrl 'https://management.azure.com/').token -AsPlainText
PS C:\> $storagePolicyAssignmentId = '/providers/Microsoft.Management/managementGroups/my-mg/providers/Microsoft.Authorization/policyAssignments/storage-assignment'
PS C:\> $violatingPolicies = @(
  @{
    policyAssignmentId = $storagePolicyAssignmentId
    policyDefinitionReferenceId = 'deny-storage-account-minimum-tls-version'
  }
  @{
    policyAssignmentId = $storagePolicyAssignmentId
    policyDefinitionReferenceId = 'deny-storage-account-secure-transfer'
  }
)
PS C:\> $whatIfDeploymentTargetResourceId = '/subscriptions/179e669d-ba52-4df3-816f-efb8caa30241'
PS C:\> $whatIfFailedTemplatePath = join-path $PSScriptRoot 'bad.bicep'
PS C:\> $test = New-ARTWhatIfDeploymentTestConfig 'Policy violating deployment should fail' $token $whatIfFailedTemplatePath $whatIfDeploymentTargetResourceId 'Failed' $violatingPolicies

Create a new instance of the WhatIfDeploymentTestConfig object by passing parameters in the correct order "testName", "token", "templateFilePath", "deploymentTargetResourceId", "requiredWhatIfStatus", and "policyViolation".

## PARAMETERS

### -azureLocation

The Azure location for the deployment.
The default value is 'australiaeast'.
This value is used when the deployment scope is not at Resource Group level.

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

### -deploymentTargetResourceId

The resource ID of the deployment target.
For example, the subscription or resource group resource ID.

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

### -httpTimeoutSeconds

The HTTP timeout in seconds for the What-If deployment REST API request.
The default value is 300 seconds.

```yaml
Type: System.Int32
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

### -longRunningJobTimeoutSeconds

The maximum time in seconds for the long-running what-if evaluation to finish.
The default value is 300 seconds.

```yaml
Type: System.Int32
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

### -maxRetry

The maximum number of retries for the long-running what-if evaluation.
The default value is 3.

```yaml
Type: System.Int32
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

### -parameterFilePath

Optional.
The path to the parameter file for the Bicep or ARM template.

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

### -policyViolation

The desired policy violation information for the What-If deployment test.

```yaml
Type: PolicyViolationInfo[]
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

### -requiredWhatIfStatus

The required status of the What-If deployment.
Supported values are 'Failed' and 'Succeeded'.

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

### -templateFilePath

The path to the Azure Bicep or ARM template file.

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

### WhatIfDeploymentTestConfig

The output is an instance of the WhatIfDeploymentTestConfig object, which contains the test configuration for checking the What-If deployment status.

## NOTES

## RELATED LINKS
