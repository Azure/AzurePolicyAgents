# Policy Integration Test - Sample Test Cases for Azure Resource Tags

## Introduction

This folder contains a sample test case for Azure Resource Tags related policies.

The test case is designed to test the following policy assignments:

| Policy Assignment Name | Policy Assignment Scope | Description |
| :-------------------- | :--------------------- | :---------- |
| `pa-d-tags` | `/providers/Microsoft.Management/managementGroups/CONTOSO-DEV` | Policy Assignment for resource tags initiative |

The following policies are in scope for testing:

| Policy Assignment | Policy Reference ID | Policy Name | Policy Effect |
| :---------------- | :---------------- | :------------ | :------------ |
| `pa-d-tags` | `TAG-001` | Subscription Should have required tag (appid) | `Deny` |
| `pa-d-tags` | `TAG-002` | Subscription Should have required tag value (dataclass) | `Deny` |
| `pa-d-tags` | `TAG-003` | Subscription Should have required tag (owner) | `Deny` |
| `pa-d-tags` | `TAG-004` | Subscription Should have required tag (supportteam) | `Deny` |
| `pa-d-tags` | `TAG-005` | Inherit the tag from the Subscription to Resource Group if missing (appid) | `Modify` |
| `pa-d-tags` | `TAG-006` | Inherit the tag from the Subscription to Resource Group if missing (dataclass) | `Modify` |
| `pa-d-tags` | `TAG-007` | Inherit the tag from the Subscription to Resource Group if missing (owner) | `Modify` |
| `pa-d-tags` | `TAG-008` | Inherit the tag from the Subscription to Resource Group if missing (supportteam) | `Modify` |
| `pa-d-tags` | `TAG-013` | Resource Group Should have required tag value for dataclass tag | `Deny` |
| `pa-d-tags` | `TAG-014` | Resource Should have required tag value for dataclass tag | `Deny` |
| `pa-d-tags` | `TAG-015` | Subscription Should have required tag value for environment tag | `Deny` |
| `pa-d-tags` | `TAG-016` | Resource Group Should have required tag value for environment tag | `Deny` |
| `pa-d-tags` | `TAG-017` | Resource Should have required tag value for environment tag | `Deny` |
| `pa-d-tags` | `TAG-018` | Inherit the tag from the Subscription to Resource Group if missing (environment) | `Modify` |
