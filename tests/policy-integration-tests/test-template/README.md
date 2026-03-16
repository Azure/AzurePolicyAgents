# Test Template for Azure Policy Integration Tests

## Introduction

This folder contains a template for creating Azure Policy integration tests. You can copy the entire folder and use it as a starting point for your own tests.

## Instructions

### 1. Copy the `test-template` folder and rename it to something relevant to your test case

Make a copy of this folder and give it a name that reflects the specific policy or scenario you are testing. For example, if you are testing a policy related to storage accounts, you could name the folder `storage-account`.

### 2. Update the local configuration file (`config.json`) with the specific settings for your test case

Use the document [Policy Integration Tests - Local Configuration](../TEST-LOCAL-CONFIG.md) as a reference to understand the mandatory and optional variables that you need to define in the [`config.json`](config.json) file for your test case.

### 3. Define the Bicep and/or Terraform templates for your test case

- If you plan to use Bicep or Terraform templates to deploy test resources for `Audit`, `AuditIfNotExists`, `Append`, `Modify`, or `DeployIfNotExists` policies, make sure to create the necessary templates and place them in the test case folder.

  - For Bicep template: Finalize [`main.test.bicep`](main.test.bicep) for the resources to be deployed during testing.
  - For Terraform: Finalize the Terraform files in the [`main-test-terraform`](main-test-terraform) directory for the resources to be deployed during testing.

- If you plan to use Bicep templates for testing `Deny` policies, define the [`main.bad.bicep`](main.bad.bicep) template for the resources that violate the policy, and optionally the [`main.good.bicep`](main.good.bicep) template for the resources that comply with the policy. Together, these define both positive and negative scenarios.
- If you plan to use Terraform for testing `Deny` or `Audit` policies against the Policy restriction API, define the Terraform files in the [`main-bad-terraform`](main-bad-terraform) directory for the resources that violate the policy, and optionally the Terraform files in the [`main-good-terraform`](main-good-terraform) directory for the resources that comply with the policy. Together, these define both positive and negative scenarios.

### 4. Update the test script (`tests.ps1`) with the specific test logic for your test case

Update the [`tests.ps1`](tests.ps1) file with the specific test logic for your test case. Use the example tests as references.

The `tests.ps1` script has prepopulated sections that are common for all test cases. You will need to populate the `#region defining tests` section with the specific tests for your test case. You can also add additional sections as needed for your test logic.

Use the documents [Policy Integration Tests - Local Configuration](../TEST-LOCAL-CONFIG.md) and [Policy Integration Tests - Global Configuration](../TEST-GLOBAL-CONFIG.md) as references to understand how to access the configuration variables in your test script and to ensure that your test logic aligns with the configurations defined in both the local and global configuration files.

## Executing the Tests

### Prerequisites

Prior to executing the tests, ensure that you have the following prerequisites in place:

- The policy assignments that you intend to test are already created and properly configured in your Azure environment and already finished the initial policy evaluation. This is crucial to ensure that the tests can accurately validate the compliance state of the deployed resources against the policies.
- Have the Azure PowerShell module installed on the computer where you will be running the tests.
- If you are using Bicep templates in your tests, ensure that the standalone version of the Bicep CLI is installed and properly configured on your machine.
- If you are using Terraform templates in your tests, ensure that Terraform is installed and properly configured on your machine.
- If you are using Terraform templates, ensure Azure CLI is installed and properly configured on your machine, as it is required for authentication when running Terraform commands that interact with Azure.
- The identity running the tests has sufficient permissions to deploy resources in the target subscription and resource group.
- The identity running the tests has at least `Reader` role on the tenant root management group level. This is required to ensure the `AzResourceTest` module can retrieve information from various APIs.
- Signed in to Azure using `Connect-AzAccount`.
- If you are using Terraform templates, also sign in to Azure CLI using `az login`.

### Running the Tests

To run the tests, execute the `tests.ps1` script in your test case folder. For example, if your test case folder is named `storage-account`, you would run the following command in PowerShell:

```powershell
cd .\storage-account
.\tests.ps1
```

Depending on the number and complexity of the tests defined in your `tests.ps1` script, the test execution may take some time to complete. The script will output the test results in the terminal as `stdout`, indicating which tests passed or failed.

A dedicated test output file in `XML` format will also be generated in the test case folder after the test execution, which contains detailed information about each test. You can inject the test results into other third-party tools such as Azure DevOps.
