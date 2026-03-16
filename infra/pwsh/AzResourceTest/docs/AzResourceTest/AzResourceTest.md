---
document type: module
Help Version: 2.0.0
HelpInfoUri: ''
Locale: en-AU
Module Guid: 80151c62-60f1-41f0-8c07-290e45340ea3
Module Name: AzResourceTest
ms.date: 02/23/2026
PlatyPS schema version: 2024-05-01
title: AzResourceTest Module
---

# AzResourceTest Module

## Description

Azure resource configuration tests using Pester and Azure Resource Graph

## AzResourceTest Cmdlets

### [Get-ARTResourceConfiguration](Get-ARTResourceConfiguration.md)

Get the configuration of an existing Azure resource via Azure Resource Graph search.

### [New-ARTArmPolicyRestrictionTestConfig](New-ARTArmPolicyRestrictionTestConfig.md)

Create a new instance of the ArmPolicyRestrictionTestConfig object. This object is used to define a test that checks the ARM resource configuration against the Azure Policy Restriction REST API for a given resource.

### [New-ARTManualWhatIfTestConfig](New-ARTManualWhatIfTestConfig.md)

Create a new instance of the ManualWhatIfTestConfig object. This object is used to define a test that checks the What-If validation result that is obtained from an external Azure Resource Manager REST API response.

### [New-ARTPolicyStateTestConfig](New-ARTPolicyStateTestConfig.md)

Create a new instance of the PolicyStateTestConfig object.

### [New-ARTPropertyCountTestConfig](New-ARTPropertyCountTestConfig.md)

Create a new instance of the PropertyCountTestConfig object. This object is used to define a test that checks the count of a property value.

### [New-ARTPropertyValueTestConfig](New-ARTPropertyValueTestConfig.md)

Create a new instance of the PropertyValueTestConfig object. This object is used to define a test that checks the value of a property.

### [New-ARTResourceExistenceTestConfig](New-ARTResourceExistenceTestConfig.md)

Create a new instance of the ResourceExistenceTestConfig object. This object is used to define a test that checks the existence of a resource.

### [New-ARTTerraformPolicyRestrictionTestConfig](New-ARTTerraformPolicyRestrictionTestConfig.md)

Create a new instance of the TerraformPolicyRestrictionTestConfig object. This object is used to define a test that checks the resource configuration from Terraform plan result against the Azure Policy Restriction REST API for a given resource.

### [New-ARTWhatIfDeploymentTestConfig](New-ARTWhatIfDeploymentTestConfig.md)

Create a new instance of the WhatIfDeploymentTestConfig object. This object is used to define a test that checks the What-If template validation for a given Bicep or ARM
template.

### [Test-ARTResourceConfiguration](Test-ARTResourceConfiguration.md)

Invoke Azure resource tests by passing defined test cases.

