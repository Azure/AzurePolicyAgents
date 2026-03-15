# Policy Integration Tests - Local Configuration

## Overview

The local configuration file is used to store variables that are specific to each test case. This file is created during the test execution based on the `testLocalConfigFileName` variable defined in the global configuration file.

The Local Configuration file stores test-specific settings required for the tests to run. In addition to the mandatory configurations, users can also add additional variables to the local configuration file as needed for their specific test cases.

The global configuration file is loaded at the beginning of the test execution, and the variables defined in it are available for use in all test scripts.

>:exclamation: **IMPORTANT**: All the variables are made available in the test scripts as script-based variables with the prefix `$Script:LocalConfig_`. For example, a variable named `testName` in the local configuration file can be accessed in the test scripts as `$script:LocalConfig_testName`.

## Mandatory Variables

The following mandatory variables are defined in the local configuration file:

| Name | Expected Data Type | Description | Example |
| :--- | :----------------- | :---------- | :------ |
| `testName` | String | Name of the test case. This is used for to form the Pester test container | `storageAccount` |
| `tagsForResourceGroup` | Boolean | Indicates whether tags should be applied to the resource group created for testing. If set to true, the tags defined in the global configuration file will be applied to the resource group. | `true` |
| `testSubscription` | String | Name of the subscription used for testing. This should be one of the subscriptions defined in the global configuration file. | `sub-d-lz-corp-01` |
| `testResourceGroup` | String | Name of the resource group to be created for testing. This resource group will be used to deploy resources during the tests. | `rg-policy-integration-test` |
| `location` | String | Azure region where the test resources will be deployed. | `australiaeast` |
| `testAuditPoliciesFromDeployedResources` | Boolean | Indicates whether to test the compliance of deployed resources against audit policies. If set to true, the tests will initiate policy compliance scan after resource deployment, then check the compliance state of the deployed resources against any applicable audit policies. | `true` |
| `testAppendModifyPolicies` | Boolean | Indicates whether to test the compliance of deployed resources against append and modify policies. If set to true, the test script will take this into consideration when waiting for policy evaluation after deployment. | `true` |
| `testDeployIfNotExistsPolicies` | Boolean | Indicates whether to test the compliance of deployed resources against deployIfNotExists policies. If set to true, the test script will take this into consideration when waiting for policy evaluation after deployment. | `true` |
| `testDenyPolicies` | Boolean | Indicates whether to validate resource configuration against policies with `Deny` effect. | `true` |

>:exclamation: **IMPORTANT**: Please ensure all above listed mandatory variables are accurately defined for each test case.

## Optional Variables

The following optional variables are defined in the local configuration file to support the sample test cases provided in this repository. These variables may not be necessary for all test cases, and users can choose to include or exclude them as needed for their specific test cases.

| Name | Expected Data Type | Description | Example |
| :--- | :----------------- | :---------- | :------ |
| `testManagementGroup` | String | Name of the management group where the policy assignment for testing is located. This is needed to construct the resource ID of the policy assignment for testing. | `CONTOSO-DEV` |
| `assignmentName` | String | Name of the policy assignment for testing. This is needed to construct the resource ID of the policy assignment for testing. | `pa-d-storage` |

> :memo: **NOTE**: You may add or remove optional properties in each local configuration file as needed for your specific test cases.
