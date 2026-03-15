# AzResourceTest PowerShell Module

## Overview

The `AzResourceTest` PowerShell module enables you to test Azure Policies before they are assigned to production environments. Based on different policy effects, it uses various Azure APIs to ensure each policy acts according to its intention.

The module leverages [Pester](https://pester.dev/) as the test framework and integrates with the following Azure APIs to validate policy behavior:

- **Azure Resource Graph (ARG)** — Query resource configurations and policy compliance states.
- **Azure Resource Manager (ARM) What-If API** — Simulate deployments to detect `Deny` policy violations without creating resources.
- **Azure Policy Insights — Policy State API** — Check the compliance state of resources against specific policy assignments.
- **Azure Policy Insights — Policy Restriction API** — Validate resource configurations (ARM and Terraform AzAPI) against policies with `Deny` and `Audit` effects.
- **Azure Resource Provider APIs** — Verify resource existence for resource types not supported by Azure Resource Graph.

## Supported Policy Effects

| Policy Effect | Testing Method | Description |
| :------------ | :------------- | :---------- |
| **Deny** | ARM What-If API | Submits a Bicep/ARM template with policy-violating configurations to the What-If API and verifies the deployment is rejected. |
| **Deny** (Manual) | ARM What-If API (manual response) | Validates a manually obtained What-If API response (e.g., from a subscription tag update) for expected policy violations. |
| **Deny / Audit** (Terraform) | Azure Policy Restriction API | Submits a Terraform plan (AzAPI provider) to the Policy Restriction API to detect policy violations. |
| **Deny / Audit** (ARM) | Azure Policy Restriction API | Submits an ARM resource configuration to the Policy Restriction API to detect policy violations. |
| **Audit / AuditIfNotExists** | Azure Resource Graph (Policy State) | Queries the policy compliance state of a deployed resource and asserts the expected compliance result. |
| **Modify / Append** | Azure Resource Graph (Property Value/Count) | Verifies that a deployed resource has the expected property values or counts after policy remediation. |
| **DeployIfNotExists** | Azure Resource Graph / Resource Provider API | Checks whether the expected resource (e.g., diagnostic settings, DNS record) was automatically created by the policy. |

## Prerequisites

- **PowerShell** 7.0 or later
- **Pester** 5.5.0 or later
- **Az PowerShell Modules**: `Az.Accounts`, `Az.PolicyInsights`, `Az.Resources`
- An authenticated Azure session (via `Connect-AzAccount` or equivalent)
- **Azure CLI** — Required when testing Terraform configurations, as Terraform only supports Azure CLI for authentication
- Policies must be assigned in the target Azure environment before running tests

## Installation

The module must be imported using the `using module` statement at the top of each test script because the module contains PowerShell class definitions. Classes loaded via `Import-Module` are not accessible in the caller's scope, so `using module` is required.

```powershell
using module /path/to/AzResourceTest/AzResourceTest.psd1
```

> **NOTE**: The `using module` statement must appear at the very beginning of the script, before any other statements. It does not support variables in the path — the path must be a literal string or a relative path.

## Module Commands

The module exports the following functions:

| Command | Description |
| :------ | :---------- |
| `Test-ARTResourceConfiguration` | Executes test cases defined by one or more test configuration objects and produces Pester test results. |
| `New-ARTPropertyValueTestConfig` | Creates a test configuration that checks the value of a resource property (e.g., `properties.minimumTlsVersion`). |
| `New-ARTPropertyCountTestConfig` | Creates a test configuration that checks the count of a property value or the existence of a property (e.g., tag existence, array item count). |
| `New-ARTPolicyStateTestConfig` | Creates a test configuration that checks the policy compliance state (`Compliant` or `NonCompliant`) of a resource. |
| `New-ARTWhatIfDeploymentTestConfig` | Creates a test configuration that validates a Bicep/ARM template deployment via the ARM What-If API for `Deny` policy violations. |
| `New-ARTResourceExistenceTestConfig` | Creates a test configuration that checks whether a resource exists or does not exist. |
| `New-ARTManualWhatIfTestConfig` | Creates a test configuration that validates a manually obtained ARM What-If API response for `Deny` policy violations. |
| `New-ARTTerraformPolicyRestrictionTestConfig` | Creates a test configuration that validates a Terraform plan (AzAPI provider) against the Azure Policy Restriction API. |
| `New-ARTArmPolicyRestrictionTestConfig` | Creates a test configuration that validates an ARM resource configuration against the Azure Policy Restriction API. |
| `Get-ARTResourceConfiguration` | Helper function to query Azure Resource Graph for the configuration of an existing resource. Useful for developing and debugging test cases. |

## Usage

For detailed usage examples, test configurations, and integration with CI/CD pipelines, refer to the [Policy Integration Tests](../../../tests/policy-integration-tests/README.md) documentation.
