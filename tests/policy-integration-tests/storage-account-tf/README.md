# Policy Integration Test - Sample Test Cases for Azure Storage Account

## Introduction

This folder contains a sample test case for Azure Storage Account related policies.

The test case is designed to test the following policy assignments:

| Policy Assignment Name | Policy Assignment Scope | Description |
| :-------------------- | :--------------------- | :---------- |
| `pa-d-storage` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for the Azure Storage Account initiative |
| `pa-d-tags` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for resource tags initiative |
| `pa-d-diag-settings` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for Azure Diagnostic Settings Policy Initiative (deploy diagnostic settings for all applicable Azure resources) |

The following policies are in scope for testing:

| Policy Assignment | Policy Reference ID | Policy Name | Policy Effect |
| :---------------- | :---------------- | :------------ | :------------ |
| `pa-d-tags` | `TAG-010` | Resource inherit the 'dataclass' tag from resource group | `Modify` |
| `pa-d-tags` | `TAG-011` | Resource inherit the 'owner' tag from resource group | `Modify` |
| `pa-d-storage` | `STG-006` | Storage accounts should prevent cross tenant object replication | `Deny` |
| `pa-d-storage` | `STG-007` | Storage accounts should prevent shared key access | `Audit` |
| `pa-d-storage` | `STG-008` | Secure transfer to storage accounts should be enabled | `Deny` |
| `pa-d-storage` | `STG-009` | Restrict Storage Account with public network access | `Audit` |
| `pa-d-storage` | `STG-010` | Storage accounts should have the specified minimum TLS version | `Deny` |
| `pa-d-storage` | `STG-012` | Storage accounts should prevent permitted copy scopes from any storage accounts | `Deny` |
| `pa-d-diag-settings` | `DS-052` | Diagnostic Settings for Storage Account Must Be Configured | `DeployIfNotExists` |
