# Policy Integration Tests - Global Configuration

## Overview

The [global configuration file](./.shared/policy_integration_test_config.jsonc) is used to store variables that are shared across multiple test cases.

There are mandatory settings that must be defined for the tests to run. Users can also add additional variables to the global configuration file as needed for their specific test cases.

The global configuration file is loaded at the beginning of the test execution, and the variables defined in it are available for use in all test scripts.

>:exclamation: **IMPORTANT**: All the variables are made available in the test scripts as script-based variables with the prefix `$Script:GlobalConfig_`. For example, a variable named `namePrefix` in the global configuration file can be accessed in the test scripts as `$script:GlobalConfig_namePrefix`.

## Mandatory Variables

The following mandatory variables are defined in the global configuration file:

| Name | Expected Data Type | Description | Example |
| :--- | :----------------- | :---------- | :------ |
| `tags` | Object | Tags to be applied to all resources created by the tests. | `{"owner": "cloud-platform-team", "dataclass": "official", "supportteam": "cloud-platform-team", "environment": "dev", "appid": "00000"}` |
| `namePrefix` | String | Prefix to be applied to the names of all resources created by the tests. This helps to easily identify and filter test resources in the Azure portal. | `poltest` |
| `deploymentPrefix` | String | Prefix to be applied to the names of all deployments created by the tests. This helps to easily identify and filter test deployments in the Azure portal. | `poltest` |
| `testBicepTemplateName` | String | Name of the Bicep template used for testing. This template should be located in the directory of each test case. If it is not found, the test will not deploy any Bicep templates during testing. | `main.test.bicep` |
| `whatIfViolateBicepTemplateName` | String | Name of the Bicep template used for What-If deployments that are expected to violate the policy. This template should be located in the directory of each test case. | `main.bad.bicep` |
| `whatIfComplyBicepTemplateName` | String | Name of the Bicep template used for What-If deployments that are expected to comply with the policy. This template should be located in the directory of each test case. | `main.good.bicep` |
| `testTerraformDirectoryName` | String | Name of the directory containing the Terraform configuration used for testing. This directory should be located in the directory of each test case. If not found, the test will not deploy any Terraform configurations during testing. | `main-test-terraform` |
| `terraformViolateDirectoryName` | String | Name of the Terraform directory used to validate against Policy Violation API that is expected to violate deny or audit policies. | `main-bad-terraform` |
| `terraformComplyDirectoryName` | String | Name of the Terraform directory used to validate against Policy Violation API that is expected to comply with the policy. | `main-good-terraform` |
| `testTerraformBackendConfigFileName` | String | Name of the Terraform file that contains the backend configuration. This file should be located in the `testTerraformDirectoryName` directory. | `backend.tf` |
| `testTerraformStateFileName` | String | Terraform state file name. | `terraform_state.tfstate` |
| `testLocalConfigFileName` | String | Name of the local configuration file used for testing. This file will be created in the same directory as the test scripts during testing and will contain the configuration for the tests. | `config.json` |
| `initialEvalMaximumWaitTime` | Integer | Maximum wait time in minutes for the initial evaluation of the policy assignment to complete. This is needed to ensure that the tests do not proceed until the policy assignment is fully evaluated and any non-compliant resources are identified. | `20` |
| `waitTimeForAuditPoliciesAfterComplianceScan` | Integer | Minutes to wait after the compliance scan for audit policies before proceeding with the tests. This is needed to ensure that the compliance state of resources is updated before the tests check for compliance. | `1` |
| `waitTimeForAppendModifyPoliciesAfterDeployment` | Integer | Minutes to wait after the deployment of append and modify policies before proceeding with the tests. This is needed to ensure that the policies are fully deployed and in effect before the tests check for compliance. | `1` |
| `waitTimeForDeployIfNotExistsPoliciesAfterDeployment` | Integer | Minutes to wait after the deployment of deployIfNotExists policies before proceeding with the tests. This is needed to ensure that the policies are fully deployed and have had enough time to create any necessary resources before the tests check for compliance. | `5` |
| `whatIfMaxRetry` | Integer | Maximum number of retries for the What-If deployment operation in case of transient failures. This is needed to improve the reliability of the tests by allowing for retries in case of temporary issues with the deployment. | `5` |
| `testScriptName` | String | Name of the test script used for testing. This script should be located in the directory of each test case. | `tests.ps1` |
| `testOutputFilePrefix` | String | Prefix to be applied to the names of the output files generated by the tests. This helps to easily identify and filter test output files in the Azure portal and in the test results. | `TEST-Resource-Config` |
| `testOutputFormat` | String | Pester test output format. | `NUnitXml` |
| `subscriptions` | Object | Subscriptions and details about each subscription used in the tests. Each subscription entry contains properties such as `id`, `networkResourceGroup`, `vNet`, `peSubnet`, and `resourceSubnet`. | See example below |

>:exclamation: **IMPORTANT**: Unless you have specific requirements for your test cases, it is recommended to keep the above variables in the global configuration file to maintain consistency across test cases and to ensure that the tests run smoothly.

### `subscriptions` Object Structure

Each subscription entry within the `subscriptions` must contain the following mandatory properties:

| Name | Expected Data Type | Description | Example |
| :--- | :----------------- | :---------- | :------ |
| `id` | String | The subscription ID. | `f27ab1cb-9c1a-4bdb-9e18-bb11ec9205db` |

To support the sample test cases provided in this repository, the following properties are also defined for the subscriptions:

| Name | Expected Data Type | Description | Example |
| :--- | :----------------- | :---------- | :------ |
| `networkResourceGroup` | String | The resource group containing network resources for this subscription. | `rg-ae-d-net-spoke` |
| `vNet` | String | The virtual network name in this subscription. | `vnet-ae-d-mgmt-01` |
| `peSubnet` | String | The subnet used for private endpoints. | `sn-private-endpoint` |
| `resourceSubnet` | String | The subnet used for resources such as VMs. | `sn-vm` |

> :memo: **NOTE**: You may add or remove optional properties for the subscriptions as needed for your specific test cases. The above properties are defined to support the sample test cases provided in this repository, but they may not be necessary for all test cases.

## Optional Variables

The following optional variables are not required for the tests to run, but are required by the sample test cases provided in this repository:

| Name | Expected Data Type | Description | Example |
| :--- | :----------------- | :---------- | :------ |
| `privateDNSSubscription` | String | Subscription where the private DNS zones are located. This is needed to create private endpoints in the tests. | `sub-d-connectivity-01` |
| `privateDNSResourceGroup` | String | Resource group where the private DNS zones are located. This is needed to create private endpoints in the tests. | `rg-ae-d-net-hub` |
| `diagnosticSettingsAPIVersion` | String | API version for diagnostic settings. | `2021-05-01-preview` |
| `resourceGroupApiVersion` | String | API version for resource groups. | `2025-04-01` |
| `diagnosticSettingsIdSuffix` | String | Suffix for the resource ID of the diagnostic settings created by the policy. This is used for testing of the diagnostic settings DINE policies. | `/providers/microsoft.insights/diagnosticSettings/setByPolicyLAW` |

> :memo: **NOTE**: You may add or remove optional properties in the global configuration file as needed for your specific test cases.
