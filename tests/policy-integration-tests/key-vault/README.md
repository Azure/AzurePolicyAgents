# Policy Integration Test - Sample Test Cases for Key Vault

## Introduction

This folder contains a sample test case for Azure Key Vault related policies.

The test case is designed to test the following policy assignments:

| Policy Assignment Name | Policy Assignment Scope | Description |
| :-------------------- | :--------------------- | :---------- |
| `pa-d-kv` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for the Azure Key Vault initiative |
| `pa-d-tags` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for resource tags initiative |
| `pa-d-pedns` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for Azure Private Endpoint DNS Records Policy Initiative (deploy DNS records for Private Endpoints) |
| `pa-d-diag-settings` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for Azure Diagnostic Settings Policy Initiative (deploy diagnostic settings for all applicable Azure resources) |


The following policies are in scope for testing:

| Policy Assignment | Policy Reference ID | Policy Name | Policy Effect |
| :---------------- | :---------------- | :------------ | :------------ |
| `pa-d-tags` | `TAG-006` | Resource Group inherit the 'dataclass' tag from subscription | `Modify` |
| `pa-d-tags` | `TAG-007` | Resource Group inherit the 'owner' tag from subscription | `Modify` |
| `pa-d-kv` | `KV-002` | Key Vault should have purge protection enabled | `Modify` |
| `pa-d-kv` | `KV-003` | Key Vault permission model should be configured to use Azure RBAC | `Deny` |
| `pa-d-kv` | `KV-004` | Azure Key Vault should disable public network access | `Audit` |
| `pa-d-pedns` | `PEDNS-005` | Private DNS Record for Key Vault PE must exist | `DeployIfNotExists` |
| `pa-d-diag-settings` | `DS-029` | Diagnostic Settings for Key Vault Must Be Configured | `DeployIfNotExists` |
