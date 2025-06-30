# Azure Policy Agent - Getting Started Guide

## Overview

The Azure Policy Agent is a GitHub Action workflow that automates the deployment and testing of Azure Policy definitions. It deploys policy definitions to Azure and uses Azure AI Foundry agents to generate and execute test scenarios to validate policy behavior.

## Prerequisites

Before you begin, you'll need:

- An Azure subscription with Contributor permissions
- An Azure AI Foundry project with a deployed assistant/agent
- A GitHub repository set up as a template or fork of this repository

## Setup Instructions

### 1. Deploy Azure AI Infrastructure

First, deploy the required Azure AI infrastructure using the Bicep templates in the `infra/bicep` folder. This will create:
- Azure AI Foundry project
- AI models and agents
- User-assigned managed identity for GitHub authentication

### 2. Create Repository from Template

1. Create new repository from this template:

![Create template repo](media/template_repo.png)
![Create template repo](media/template_repo_2.png)

### 3. Configure Federated Identity Credentials

2. Update the user-assigned managed identity with federated credential details from your repository for pull_request entity:

![Federated credentials setup](media/fed_1.png)
![Federated credentials configuration](media/fed_2.png)

### 4. Configure GitHub Repository Secrets and Variables

3. Navigate to your GitHub repository → Settings → Secrets and variables → Actions

Add the following **Repository Secrets**:

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `AZURE_CLIENT_ID` | User-Assigned Managed Identity Client ID | `12345678-1234-1234-1234-123456789012` |
| `AZURE_TENANT_ID` | Azure AD Tenant ID | `87654321-4321-4321-4321-210987654321` |
| `AZURE_SUBSCRIPTION_ID` | Target Azure Subscription ID for tests| `abcdef12-3456-7890-abcd-ef1234567890` |

Add the following **Repository Variables**:

| Variable Name | Description | Example Value |
|---------------|-------------|---------------|
| `PROJECT_ENDPOINT` | Azure AI Foundry Project Endpoint | `https://projectname.services.ai.azure.com/api/projects/firstProject`|
| `ASSISTANT_ID` | Azure AI Agent/Assistant ID | `asst_Yh8QGJKa0wAZA7DZQA7DZLTk` |

### 5. Test Your Setup

4. Create a pull request in the `policyDefinitions` folder to validate that the workflow runs properly:

![Create pull request](media/pr_1.png)
![Pull request workflow](media/pr_2.png)

5. Continue to use this for your policy development!

## What It Does

The PolicyAgent workflow provides automated Azure Policy management:

### 🔄 **Automated Policy Deployment**
- Automatically detects changes to policy definition files in pull requests
- Uses PowerShell scripts to deploy Azure Policy definitions to your Azure subscription
- Leverages Bicep templates for Infrastructure as Code deployment
- Validates policy syntax and structure during deployment

### 🤖 **AI-Powered Policy Testing**
- Uses Azure AI Foundry Agent to intelligently analyze and test policies
- Generates realistic test scenarios for policy validation
- Creates PowerShell scripts to simulate policy enforcement scenarios
- Provides detailed feedback on policy effectiveness and potential issues

### 📊 **Comprehensive Reporting**
- Posts detailed test results as pull request comments
- Includes success/failure status for each policy tested
- Provides actionable insights and recommendations for policy improvements
- Shows policy enforcement behavior and expected outcomes

## How It Works

The workflow consists of two main components:

### 1. Policy Deployment (`PolicyDefinition` Job)
- Detects changed JSON files in the `policyDefinitions/` folder
- Uses the `deploy-policies.ps1` script to deploy policies to Azure
- Leverages the `deployDef.ps1` utility script and `policyDef.bicep` template
- Prepares policy content for AI analysis

### 2. AI Testing (`PolicyAgent` Job)
- Receives policy content from the deployment job
- Uses the `test-policies.ps1` script to interact with Azure AI Foundry
- Sends policy definitions to the configured AI agent/assistant
- Processes AI-generated test results and posts them as PR comments

## Repository Structure

Your repository contains these key components:

```
AzurePolicyAgents/
├── .github/
│   ├── workflows/
│   │   └── PolicyAgent.yml          # Main GitHub Action workflow
│   └── scripts/
│       ├── deploy-policies.ps1      # Policy deployment script
│       ├── test-policies.ps1        # AI testing orchestration
│       └── get-changed-files.sh     # File change detection
├── policyDefinitions/
│   └── allowedLocations.json.sample # Sample policy definition
├── utilities/
│   └── policyAgent/
│       ├── deployDef.ps1           # Core deployment utility
│       ├── policyDef.bicep         # Bicep template for policies
│       └── policyDef.parameters.json # Template parameters
└── infra/
    └── bicep/                      # Azure AI infrastructure templates
        ├── agentsSetup.bicep
        └── agentInstructions/      # AI agent system prompts
```

## Policy Definition Format

Place your Azure Policy definitions as JSON files in the `policyDefinitions/` folder. Example:

```json
{
  "properties": {
    "displayName": "Allowed locations for resources",
    "policyType": "Custom",
    "mode": "Indexed",
    "description": "This policy restricts the locations where resources can be deployed",
    "metadata": {
      "category": "General"
    },
    "parameters": {
      "listOfAllowedLocations": {
        "type": "Array",
        "defaultValue": ["eastus", "westus2"],
        "metadata": {
          "displayName": "Allowed locations",
          "description": "The list of locations that can be specified when deploying resources"
        }
      }
    },
    "policyRule": {
      "if": {
        "not": {
          "field": "location",
          "in": "[parameters('listOfAllowedLocations')]"
        }
      },
      "then": {
        "effect": "deny"
      }
    }
  }
}
```

## Workflow Triggers

The PolicyAgent workflow runs when:
- **Pull Requests**: Created or updated with changes to `policyDefinitions/*.json` files
- **Push to Main**: Changes are pushed to the main branch

## Expected Results

After creating a pull request with policy changes, you'll see:

1. **GitHub Actions**: The workflow will run automatically
2. **Policy Deployment**: Policies are deployed to your Azure subscription
3. **AI Analysis**: The AI agent analyzes and tests your policies
4. **PR Comments**: Detailed results are posted as comments on your pull request

Example comment output:
```markdown
## Azure Policy Test Results

### Summary: Processed 1 policy definition(s)

### ✅ Policy Test Completed Successfully for `policyDefinitions/allowed-locations.json`
The Policy 'Allowed locations for resources' successfully validated the policy enforcement.

**Details:**
- Policy correctly denies resources in disallowed locations
- Test scenarios confirmed expected behavior
- No issues found with policy logic
```

## Troubleshooting

### Common Issues

#### Authentication Failures
```
Error: AADSTS700016: Application with identifier 'xxx' was not found
```
**Solution**: Verify your managed identity Client ID is correctly configured in GitHub secrets.

#### Permission Errors
```
Error: Insufficient privileges to complete the operation
```
**Solution**: Ensure your managed identity has Contributor permissions on the target subscription.

#### AI Agent Not Responding
```
Cannot find agent xxx. Please re-create it and retry
```
**Solution**: Verify your `ASSISTANT_ID` variable matches your Azure AI Foundry agent ID.

#### No Policy Files Found
```
No JSON files found in the 'policyDefinitions' directory
```
**Solution**: Ensure your policy files are in the `policyDefinitions/` folder with `.json` extensions.

#### Bicep Deployment Failures
Check the deployment logs for specific Bicep template errors. Common issues:
- Missing required parameters in `policyDef.parameters.json`
- Invalid policy definition structure
- Resource naming conflicts

### Debug Steps

1. **Check GitHub Actions Logs**: Review detailed logs in the Actions tab
2. **Verify Azure Permissions**: Test your managed identity permissions manually
3. **Validate AI Configuration**: Test your AI agent in the Azure AI Foundry portal
4. **Check File Paths**: Ensure policy files are in the correct directory structure
5. **Test Policy JSON**: Validate your policy JSON using Azure Policy tools

## Current Limitations

- Only supports JSON policy definition files in the `policyDefinitions/` folder
- Requires manual setup of Azure AI Foundry infrastructure
- AI-generated tests run in simulation mode and may not reflect all real-world scenarios
- Limited to pull request and main branch triggers
- Requires federated identity setup for each repository

## Next Steps

Once your setup is working:
1. Add your custom policy definitions to the `policyDefinitions/` folder
2. Create pull requests to test the automated workflow
3. Review AI-generated test results and refine your policies
4. Monitor Azure costs associated with AI agent usage
5. Customize the AI agent prompts in `infra/bicep/agentInstructions/` as needed

