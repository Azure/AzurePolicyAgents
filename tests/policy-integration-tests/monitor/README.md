# Policy Integration Test - Sample Test Cases for Azure Monitor

## Introduction

This folder contains a sample test case for Azure Monitor related policies.

The test case is designed to test the following policy assignments:

| Policy Assignment Name | Policy Assignment Scope | Description |
| :-------------------- | :--------------------- | :---------- |
| `pa-d-monitor` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for the Azure Monitor initiative |

The following policies are in scope for testing:

| Policy Assignment | Policy Reference ID | Policy Name | Policy Effect |
| :---------------- | :---------------- | :------------ | :------------ |
| `pa-d-monitor` | MON-001 | Restrict Azure Monitor Action Group Send Email Notification to External Email Addresses | Deny |
| `pa-d-monitor` | MON-002 | Restrict Azure Monitor Action Group Send SMS Notification to Unauthorized country codes | Deny |
| `pa-d-monitor` | MON-003 | Restrict Azure Monitor Action Group Trigger Actions to Cross-Subscription Azure Automation or not on the Allowed List | Deny |
| `pa-d-monitor` | MON-004 | Restrict Azure Monitor Action Group Trigger Actions to Cross-Subscription Event Hubs or not on the Allowed List | Deny |
| `pa-d-monitor` | MON-005 | Restrict Azure Monitor Action Group Trigger Actions to Cross-Subscription Function Apps or not on the Allowed List | Deny |
| `pa-d-monitor` | MON-006 | Restrict Azure Monitor Action Group Trigger Actions to Cross-Subscription Logic Apps or not on the Allowed List | Deny |
| `pa-d-monitor` | MON-007 | Restrict Azure Monitor Action Group Trigger Actions to Webhooks that are not on the Allowed List | Deny |
| `pa-d-monitor` | MON-008 | Restrict Azure Monitor Action Group Trigger Actions to Webhooks that are not using HTTPS | Deny |
