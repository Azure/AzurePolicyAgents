# Azure Policy AI Agent Testing Framework - Getting Started Guide

## Overview

The Azure Policy AI Agent Testing Framework is an automated CI/CD pipeline — available for both **GitHub Actions** and **Azure DevOps** — that tests Azure Policy definitions across all effect types. It uses five specialized AI agents in Azure AI Foundry—four experts in specific policy effect types (deny, audit, modify, deployIfNotExists) plus an Instructions Maintenance Agent that analyses failures and automatically improves agent instructions—to generate test scripts, execute them in Azure, and provide detailed analysis.

This framework transforms manual policy testing into an autonomous validation pipeline, reducing testing time from hours to minutes while ensuring comprehensive coverage and zero resource leakage.

## Prerequisites

This framework uses two separate Azure identities. Keeping them separate follows least privilege: the broad deploy-time permissions live on a bootstrap identity that is only used once, while the day-to-day test workflows run as a managed identity with a narrower role set.

| Identity | Roles (scope) | Purpose |
|----------|---------------|---------|
| Bootstrap service principal | Contributor, User Access Administrator (subscription) | One-time deployment of the framework infrastructure (`agentsSetup.bicep`). |
| Runtime managed identity (UMI) | Contributor, Resource Policy Contributor, Policy Insights Data Writer, Role Based Access Control Administrator (subscription); Azure AI Developer (resource group) | Authenticates the runtime test pipelines (GitHub Actions or Azure DevOps) that create policies, deploy test resources, and call the AI agents. |

Before you begin, you'll need:

- An Azure subscription where you can create a service principal and assign it the **Contributor** and **User Access Administrator** roles at subscription scope. These two roles are the least-privilege set required to deploy the infrastructure.
- Azure CLI and PowerShell installed locally
- A **GitHub** repository **or** an **Azure DevOps** project hosting this code
- Basic understanding of Azure Policy and either GitHub Actions or Azure DevOps Pipelines

## Quick Start

Setup has two parts: **Common Setup** (the shared Azure identity used to deploy),
then **one** CI-specific track — either **GitHub Actions Setup** or **Azure
DevOps Setup**. Complete Common Setup first, then follow only the section that
matches your CI system.

---

## Common Setup (both CI systems)

### Step 1: Get the Repository

**GitHub** — create a new repository from this template:

1. Click **"Use this template"** button at the top of the repository
2. Select **"Create a new repository"**
3. Choose your organization/username
4. Name your repository (e.g., `my-policy-testing`)
5. Select **Public** or **Private**
6. Click **"Create repository"**

**Azure DevOps** — import this repository into Azure Repos (**Repos → Import a
repository**), or point an Azure DevOps pipeline at your GitHub copy. The
ready-made pipeline definitions live in the `pipelines/` folder.

### Step 2: Create the Bootstrap Service Principal

Both CI systems authenticate to Azure with **workload identity federation**
(passwordless). Create the bootstrap identity and grant it the two least-privilege
roles here; you add the CI-specific federated credential in your chosen track
below.

```bash
# Login to Azure
az login
az account set --subscription "Your-Subscription-Name-or-ID"

# IDs needed later
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

# Create the app registration and its service principal (OIDC only - no client secret)
APP_ID=$(az ad app create --display-name "sp-policy-agents-bootstrap" --query appId -o tsv)
az ad sp create --id "$APP_ID"

# Assign the two least-privilege roles the deployment needs at subscription scope.
#   Contributor               - deploy the AI Foundry, Log Analytics, App Insights
#                               and the runtime managed identity.
#   User Access Administrator - create the role assignments defined in
#                               agentsSetup.bicep, including granting the runtime
#                               managed identity its RBAC roles.
az role assignment create --assignee "$APP_ID" --role "Contributor" --scope "/subscriptions/$SUBSCRIPTION_ID"
az role assignment create --assignee "$APP_ID" --role "User Access Administrator" --scope "/subscriptions/$SUBSCRIPTION_ID"

# Identity values you'll need in the following steps
echo "AZURE_CLIENT_ID=$APP_ID"
echo "AZURE_TENANT_ID=$TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID"
```

This bootstrap service principal is only used to deploy the infrastructure.
Afterwards the runtime pipelines authenticate as the user-assigned managed
identity (UMI) created by the deployment.

### What the Deployment Creates

Deploying `agentsSetup.bicep` (via your CI track below, or manually) provisions:

- Azure AI Foundry project (single project for all agents)
- Five specialized policy testing agents (Deny, Audit, DINE, Modify, Instructions Maintenance)
- Azure AI Services with GPT-5.4 deployment
- Log Analytics workspace for monitoring
- Bing Search connection for grounding
- The runtime managed identity (UMI) and its RBAC assignments

#### Manual deployment (optional, CI-agnostic)

```powershell
# Login to Azure
Connect-AzAccount
Set-AzContext -SubscriptionId "your-subscription-id"

# Deploy infrastructure
$deployment = New-AzSubscriptionDeployment `
  -Name "PolicyAgentInfra-$(Get-Date -Format 'yyyyMMddHHmm')" `
  -Location "<your-azure-region>" `
  -TemplateFile "./infra/bicep/agentsSetup.bicep" `
  -TemplateParameterFile "./infra/bicep/agentsSetup.bicepparam" `
  -Verbose

# Display outputs
Write-Host "`n=== Deployment Outputs ===" -ForegroundColor Green
Write-Host "Agent Endpoint: $($deployment.Outputs.agentEndpoint.Value)"
Write-Host "Model Deployment: $($deployment.Outputs.agentModelDeploymentName.Value)"
Write-Host "Resource Group: $($deployment.Outputs.resourceGroupName.Value)"

# Deploy the five specialized agents
& ./scripts/deploySpecializedAgents.ps1 `
  -ProjectEndpoint $deployment.Outputs.agentEndpoint.Value `
  -ModelDeploymentName $deployment.Outputs.agentModelDeploymentName.Value `
  -AgentTypes "deny,audit,deployIfNotExists,modify,instructionsAgent"
```

---

## GitHub Actions Setup

Complete **Common Setup** first. All commands reuse the `APP_ID`,
`SUBSCRIPTION_ID` and `TENANT_ID` values from Common Setup Step 2.

### Step 1: Add the Repository's Federated Credential

```bash
REPO_OWNER="your-github-org"     # Replace with your GitHub org/username
REPO_NAME="my-policy-testing"    # Replace with your repository name
GH_ENVIRONMENT="dev"             # Must match the environment the deploy workflow runs in

# The subject must match the token GitHub presents: the infra deploy workflow
# (Deploy Specialized Policy Agents) runs in the "$GH_ENVIRONMENT" environment.
az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters '{
    "name": "github-'$GH_ENVIRONMENT'-environment",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'$REPO_OWNER'/'$REPO_NAME':environment:'$GH_ENVIRONMENT'",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

Verify the credential and its subject:

```bash
az ad app federated-credential list --id "$APP_ID" -o table
```

The subject must read `repo:<org>/<repo>:environment:dev`. All workflows run in
the `dev` GitHub environment, which is also the value of `githubEnvironment` in
`infra/bicep/agentsSetup.bicepparam`. If you use a different environment name,
update **both** the credential subject and the `githubEnvironment` parameter.

### Step 2: Configure Secrets and the `dev` Environment

In your GitHub repository, navigate to **Settings → Secrets and variables →
Actions → Secrets → New repository secret**. Add these three secrets from Common
Setup Step 2:

| Secret Name | Source | Example Value |
|-------------|--------|---------------|
| `AZURE_CLIENT_ID` | `AZURE_CLIENT_ID` echoed in Common Setup | `12345678-1234-1234-1234-123456789abc` |
| `AZURE_TENANT_ID` | `AZURE_TENANT_ID` echoed in Common Setup | `87654321-4321-4321-4321-cba987654321` |
| `AZURE_SUBSCRIPTION_ID` | `AZURE_SUBSCRIPTION_ID` echoed in Common Setup | `abcdef12-3456-7890-abcd-ef1234567890` |

There is no client secret to store — authentication uses the federated credential
from Step 1. Also create a GitHub **environment** named `dev` (**Settings →
Environments → New environment**) so the workflows' `environment: dev` reference
resolves.

### Step 3: Deploy the Infrastructure

1. Navigate to your repository's **Actions** tab
2. Select **"Deploy Specialized Policy Agents"** workflow
3. Click **"Run workflow"** dropdown
4. Select deployment location: enter the Azure region to deploy to (any region where your chosen model is available)
5. Click **"Run workflow"** button
6. Wait for deployment to complete (approximately 10-15 minutes)
7. **Copy the output values** from the workflow summary

### Step 4: Configure Runtime Variables

Navigate to **Settings → Secrets and variables → Actions → Variables → New
repository variable**. Add these five variables from the deployment outputs:

| Variable Name | Description | Find In |
|---------------|-------------|---------|
| `AGENT_ENDPOINT` | Azure AI Foundry endpoint URL | Deployment output or workflow summary |
| `DENY_AGENT_ID` | Deny policy agent ID | Agent deployment script output |
| `AUDIT_AGENT_ID` | Audit policy agent ID | Agent deployment script output |
| `DINE_AGENT_ID` | DINE policy agent ID | Agent deployment script output |
| `MODIFY_AGENT_ID` | Modify policy agent ID | Agent deployment script output |

**Example values:**
```plaintext
AGENT_ENDPOINT=https://ai-project-abc123.australiaeast.api.azureml.ms
DENY_AGENT_ID=asst_DenyPolicyAgent123
AUDIT_AGENT_ID=asst_AuditPolicyAgent456
DINE_AGENT_ID=asst_DINEPolicyAgent789
MODIFY_AGENT_ID=asst_ModifyPolicyAgent012
```

### Step 5: Switch Runtime Authentication to the Managed Identity

The bootstrap service principal was only needed to deploy the infrastructure. The
deployment created a user-assigned managed identity (UMI) pre-granted the
least-privilege roles the test workflows require (Contributor, Resource Policy
Contributor, Policy Insights Data Writer, Azure AI Developer and Role Based Access
Control Administrator), along with its GitHub federated credential
(`repo:<org>/<repo>:environment:dev`). Update the repository **secrets** to the
UMI's values so runtime workflows stop using the broadly-privileged bootstrap
identity:

| Secret Name | New Value | Find In |
|-------------|-----------|---------|
| `AZURE_CLIENT_ID` | Managed identity client ID | Deployment output `azureClientId` |
| `AZURE_TENANT_ID` | Tenant ID | Deployment output `azureTenantId` |
| `AZURE_SUBSCRIPTION_ID` | Subscription ID | Deployment output `azureSubscriptionId` |

You can now remove the bootstrap service principal's subscription role
assignments if it is not used for anything else.

### Step 6: Run Your First Test

Commit a policy definition and open a pull request against `main` — see
[Creating Your First Policy Test](#creating-your-first-policy-test).

---

## Azure DevOps Setup

Complete **Common Setup** first. All commands reuse the `APP_ID` value from Common
Setup Step 2.

### Step 1: Create the Service Connection and Federated Credential

Azure DevOps authenticates through an Azure Resource Manager **service connection**
that uses workload identity federation. The pipelines in `pipelines/` expect it to
be named `policy-agents` (override with the `azureServiceConnection` pipeline
variable).

1. In Azure DevOps go to **Project Settings → Service connections → New service
   connection → Azure Resource Manager → Workload Identity federation (manual)**.
2. Enter the target **Subscription**, then the **Service Principal Id** (`$APP_ID`)
   and **Tenant Id** from Common Setup. Name the connection `policy-agents`.
3. Azure DevOps displays an **Issuer** (e.g.
   `https://vstoken.dev.azure.com/<org-guid>`) and a **Subject identifier**
   (`sc://<org>/<project>/policy-agents`). Copy both, then create the matching
   federated credential on the app registration:

```bash
# Paste the Issuer and Subject identifier shown by Azure DevOps
ADO_ISSUER="https://vstoken.dev.azure.com/<org-guid>"
ADO_SUBJECT="sc://<org>/<project>/policy-agents"

az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters '{
    "name": "azure-devops-policy-agents",
    "issuer": "'$ADO_ISSUER'",
    "subject": "'$ADO_SUBJECT'",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

4. Back in Azure DevOps, click **Verify and save** on the service connection to
   confirm the token exchange succeeds.

### Step 2: Create the Variable Group

The service connection supplies the client and tenant identity, so no
client/tenant secrets are needed. Create a **variable group** named
`policy-agents-dev` (**Pipelines → Library → + Variable group**) and add:

| Variable | Value |
|----------|-------|
| `AZURE_SUBSCRIPTION_ID` | Subscription ID from Common Setup |

Link this variable group to each pipeline you import from the `pipelines/` folder.
The agent endpoint and agent IDs are added after deployment (Step 4).

### Step 3: Deploy the Infrastructure

1. Create a pipeline from `pipelines/deploy-specialized-agents.yml`
   (**Pipelines → New pipeline → Existing Azure Pipelines YAML file**)
2. Ensure it is linked to the `policy-agents-dev` variable group and the
   `policy-agents` service connection from Steps 1 and 2
3. Click **Run**, choosing the `deployment_location` parameter
4. Wait for deployment to complete, then **copy the agent IDs and endpoint**
   printed in the *Validate Deployment* job

### Step 4: Add Runtime Variables to the Variable Group

Add these values from the deployment outputs to the `policy-agents-dev` variable
group (plus the optional `INSTRUCTIONS_AGENT_ID`):

| Variable | Description |
|----------|-------------|
| `AGENT_ENDPOINT` | Azure AI Foundry endpoint URL |
| `DENY_AGENT_ID` | Deny policy agent ID |
| `AUDIT_AGENT_ID` | Audit policy agent ID |
| `DINE_AGENT_ID` | DINE policy agent ID |
| `MODIFY_AGENT_ID` | Modify policy agent ID |

### Step 5: Switch Runtime Authentication to the Managed Identity

The bootstrap service principal was only needed to deploy the infrastructure. The
deployment created a user-assigned managed identity (UMI) pre-granted the
least-privilege roles the test pipelines require (Contributor, Resource Policy
Contributor, Policy Insights Data Writer, Azure AI Developer and Role Based Access
Control Administrator). The deployment does **not** create an Azure DevOps
federated credential for the UMI, so add one and back a second service connection
with it:

1. Create a new service connection (**Workload Identity federation (manual)**,
   *Managed Identity* credential) named e.g. `policy-agents-umi`, using the UMI's
   client ID (`azureClientId`) and tenant ID. Copy its Issuer and Subject.
2. Add the matching federated credential to the UMI (get its name/resource group
   from the deployment):

   ```bash
   az identity federated-credential create \
     --name "azure-devops-policy-agents-umi" \
     --identity-name "<umi-name>" \
     --resource-group "<deployment-resource-group>" \
     --issuer "https://vstoken.dev.azure.com/<org-guid>" \
     --subject "sc://<org>/<project>/policy-agents-umi" \
     --audiences "api://AzureADTokenExchange"
   ```

3. Set the `azureServiceConnection` pipeline variable to `policy-agents-umi` for
   the `policy-agent` and `update-agent-instructions` pipelines.

Once the runtime pipelines use the UMI, you can remove the bootstrap service
principal's subscription role assignments (and its service connection) if it is
not used for anything else.

### Step 6: Run Your First Test

Commit a policy definition and open a pull request against `main` — see
[Creating Your First Policy Test](#creating-your-first-policy-test).

## Creating Your First Policy Test

1. **Create a policy file**: Add a JSON policy definition to the `policyDefinitions/` folder
2. **Example policy** (`policyDefinitions/test-allowed-locations.json`):

```json
{
  "properties": {
    "displayName": "Test - Allowed locations for resources",
    "policyType": "Custom",
    "mode": "Indexed",
    "description": "Test policy that restricts resource deployment to specific locations",
    "metadata": {
      "category": "General"
    },
    "parameters": {
      "listOfAllowedLocations": {
        "type": "Array",
        "defaultValue": ["eastus", "westus2"],
        "metadata": {
          "displayName": "Allowed locations",
          "description": "List of allowed Azure regions for resource deployment"
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

3. **Create a pull request**: Commit your policy file and open a PR against `main`
4. **Watch the pipeline**: Monitor the **GitHub Actions** tab, or the **Pipelines** view in Azure DevOps
5. **Review results**: Check the PR comments (GitHub) or the pipeline run's PR comment/artifacts (Azure DevOps) for AI-generated test results

## What to Expect

When you create a pull request with policy changes:

1. **Pipeline triggers**: The GitHub Actions workflow or Azure DevOps pipeline automatically starts
2. **Policy Deployment**: Your policies are deployed to the Azure subscription
3. **AI Analysis**: The Azure AI agent analyzes your policy and generates tests
4. **Results Posted**: Detailed test results appear as PR comments

**Example Result**:
```markdown
## Azure Policy Test Results

### Summary: Processed 1 policy definition(s)

### ✅ Policy Test Completed Successfully for `policyDefinitions/test-allowed-locations.json`
The Policy 'Test - Allowed locations for resources' successfully validated.

**Details:**
- Policy correctly blocks resource deployment to unauthorized regions
- Test scenarios confirmed expected deny behavior
- No syntax or logic issues detected
```
![Results](media/pr_2.png)

## Troubleshooting

### Common Issues

#### Authentication Failures
```
Error: AADSTS700016: Application with identifier 'xxx' was not found
```
**Solution**: Verify the client ID is correct in your GitHub secrets or Azure DevOps service connection, and that a federated credential exists whose subject matches how your CI system signs in (GitHub `repo:<org>/<repo>:environment:dev`, Azure DevOps `sc://<org>/<project>/<service-connection>`).

#### Permission Errors
```
Error: Insufficient privileges to complete the operation
```
**Solution**:
- For the **bootstrap service principal** (Step 2), ensure it holds both **Contributor** and **User Access Administrator** at subscription scope — the deployment creates role assignments, which Contributor alone cannot do.
- For the **runtime managed identity** (used by the test workflows), ensure the deployment granted it Contributor, Resource Policy Contributor, Policy Insights Data Writer, Azure AI Developer and Role Based Access Control Administrator. The last role lets the DINE/modify tests assign roles to policy managed identities.

#### AI Agent Not Responding
```
Cannot find agent xxx. Please re-create it and retry
```
**Solution**: 
- Verify your `ASSISTANT_ID` variable matches your Azure AI Foundry agent ID
- Check that your AI agent is deployed and active in the Azure AI Foundry portal
- Ensure your `PROJECT_ENDPOINT` is correct and accessible

#### No Policy Files Found
```
No JSON files found in the 'policyDefinitions' directory
```
**Solution**: 
- Ensure your policy files are in the `policyDefinitions/` folder with `.json` extensions
- Check that your PR includes changes to files in the correct directory
- Verify file names don't contain special characters or spaces

#### Bicep Deployment Failures
Check the deployment logs for specific Bicep template errors. Common issues:
- Missing required parameters in `policyDef.parameters.json`
- Invalid policy definition JSON structure
- Resource naming conflicts in Azure
- Insufficient permissions to create policy definitions

#### Pipeline Not Triggering
**Solution**:
- Ensure you're modifying files in `policyDefinitions/*.json`
- **GitHub Actions:** check the workflow exists at `.github/workflows/PolicyAgent.yml` and is enabled in your repository settings
- **Azure DevOps:** check the pipeline was created from `pipelines/policy-agent.yml` and that PR triggers/branch policies are configured for `main`
- Verify you have the correct repository/project permissions

### Debug Steps

1. **Check pipeline logs**:
   - **GitHub Actions:** repository → Actions tab → the failed run → review each job's logs
   - **Azure DevOps:** Pipelines → the failed run → review each stage/job's logs

2. **Verify Azure Permissions**: 
   ```bash
   # Test your managed identity permissions
   az login --identity --username <client-id>
   az policy definition list --subscription <subscription-id>
   ```

3. **Validate AI Configuration**: 
   - Test your AI agent in the Azure AI Foundry portal
   - Verify the agent responds to basic queries
   - Check that the project endpoint is accessible

4. **Check File Structure**: 
   ```bash
   # Verify your repository structure
   ls -la policyDefinitions/
   cat policyDefinitions/your-policy.json | jq .
   ```

5. **Test Policy JSON**: 
   - Use Azure Policy extension in VS Code for validation
   - Test policy JSON in Azure portal policy definition creator
   - Validate JSON syntax using online JSON validators


## Quick Reference

### File Locations
- Policy definitions: `policyDefinitions/*.json`
- GitHub Actions workflows: `.github/workflows/` (e.g. `PolicyAgent.yml`)
- Azure DevOps pipelines: `pipelines/` (e.g. `policy-agent.yml`)
- Scripts: `scripts/`
- Infrastructure: `infra/bicep/`

### Required Secrets & Variables
- **GitHub Actions** — Secrets: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`; Variables: `AGENT_ENDPOINT`, `DENY_AGENT_ID`, `AUDIT_AGENT_ID`, `DINE_AGENT_ID`, `MODIFY_AGENT_ID`, `INSTRUCTIONS_AGENT_ID`
- **Azure DevOps** — Service connection `policy-agents` (workload identity federation) plus variable group `policy-agents-dev` containing `AZURE_SUBSCRIPTION_ID`, `AGENT_ENDPOINT`, `DENY_AGENT_ID`, `AUDIT_AGENT_ID`, `DINE_AGENT_ID`, `MODIFY_AGENT_ID`, `INSTRUCTIONS_AGENT_ID`

### Pipeline Triggers
- Pull requests with changes to `policyDefinitions/*.json`
- Push to `main` with changes to `policyDefinitions/*.json`

For complete details on how the system works, see the main [README](../README.md).

