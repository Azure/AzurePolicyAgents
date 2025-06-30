# Azure Policy Agents

A comprehensive toolkit for automated Azure Policy development, testing, and validation using GitHub Actions and Azure AI Foundry agents.

## 🚀 Overview

Azure Policy Agents streamlines the Azure Policy development lifecycle by providing:

- **Automated Policy Testing**: GitHub Actions workflow that automatically deploys and tests Azure Policy definitions
- **AI-Powered Validation**: Uses Azure AI Foundry agents to generate intelligent test scenarios and validate policy behavior
- **Infrastructure as Code**: Bicep templates for deploying policies and AI infrastructure
- **Local Development Support**: Integration with VS Code through Model Context Protocol (MCP) Server for policy authoring and Azure resource interaction

## ✨ Key Features

### 🔄 Automated GitHub Workflows

- **Policy Deployment**: Automatically deploys policy definitions to Azure when changes are detected
- **AI Testing**: Leverages Azure AI Foundry agents to generate and execute policy test scenarios  
- **Pull Request Integration**: Posts detailed test results as comments on pull requests
- **Change Detection**: Only processes changed policy definition files for efficiency

### 🤖 AI-Powered Policy Analysis

- **Intelligent Test Generation**: AI agents create realistic test scenarios based on policy logic
- **Behavior Validation**: Simulates policy enforcement to verify expected behavior
- **Detailed Reporting**: Provides comprehensive feedback on policy effectiveness
- **Best Practices Guidance**: AI-generated recommendations for policy improvements

### 🛠️ Development Tools

- **Bicep Templates**: Infrastructure as Code templates for policy deployment
- **PowerShell Utilities**: Scripts for policy deployment and testing orchestration
- **VS Code Integration**: MCP server for enhanced local development experience
- **Sample Policies**: Example policy definitions to get started quickly

## 📁 Project Structure

```
AzurePolicyAgents/
├── .github/
│   ├── workflows/
│   │   └── PolicyAgent.yml          # Main GitHub Action workflow
│   └── scripts/
│       ├── deploy-policies.ps1      # Policy deployment orchestration
│       ├── test-policies.ps1        # AI testing coordination
│       └── get-changed-files.sh     # File change detection
├── policyDefinitions/
│   └── allowedLocations.json.sample # Sample policy definition
├── utilities/
│   └── policyAgent/
│       ├── deployDef.ps1           # Core deployment utility
│       ├── policyDef.bicep         # Bicep template for policies
│       └── policyDef.parameters.json # Template parameters
├── infra/
│   └── bicep/                      # Azure AI infrastructure
│       ├── agentsSetup.bicep       # Main infrastructure template
│       └── agentInstructions/      # AI agent system prompts
└── docs/
    └── Getting-Started.md          # Setup and usage guide
```

## 🚀 Quick Start

Ready to get started? Follow these simple steps:

1. **Use this repository as a template** to create your own Azure Policy Agents repository
2. **Deploy the Azure AI infrastructure** using the provided Bicep templates  
3. **Configure GitHub authentication** with federated identity credentials
4. **Add your policy definitions** to the `policyDefinitions/` folder
5. **Create pull requests** to automatically test your policies

### Complete Setup Guide

For step-by-step instructions with commands and screenshots, see our comprehensive [Getting Started Guide](docs/Getting-Started.md).

### Prerequisites

- Azure subscription with Owner permissions
- Azure CLI or PowerShell installed  
- GitHub repository (created from this template)

## 🔧 How It Works

### Workflow Architecture

The Azure Policy Agent uses a two-job GitHub Actions workflow that automatically triggers on pull requests affecting policy definitions:

```
Pull Request with Policy Changes
    ↓
PolicyDefinition Job
    ├── Detect changed JSON files in policyDefinitions/
    ├── Deploy policies to Azure using Bicep templates
    ├── Validate policy syntax and structure
    └── Prepare policy content for AI analysis
    ↓
PolicyAgent Job
    ├── Receive policy content from previous job
    ├── Send policy definitions to Azure AI Foundry agent
    ├── AI generates intelligent test scenarios
    ├── Execute simulated policy enforcement tests
    └── Post comprehensive results as PR comments
```

### Key Components

#### 1. Policy Deployment (`PolicyDefinition` Job)
- **File Detection**: Uses `get-changed-files.sh` to identify modified policy files
- **Azure Deployment**: Leverages `deploy-policies.ps1` to orchestrate policy deployment
- **Bicep Templates**: Uses `deployDef.ps1` and `policyDef.bicep` for Infrastructure as Code
- **Content Preparation**: Encodes policy content for the AI testing job

#### 2. AI Testing (`PolicyAgent` Job)
- **AI Integration**: Uses `test-policies.ps1` to interact with Azure AI Foundry
- **Intelligent Analysis**: AI agent analyzes policy logic and generates test scenarios
- **Simulation Testing**: Creates and executes policy enforcement simulations
- **Results Reporting**: Posts detailed feedback as pull request comments

### Workflow Triggers

The workflow automatically runs when:
- **Pull Requests**: Created or updated with changes to `policyDefinitions/*.json` files
- **Push to Main Branch**: Direct commits to the main branch

### File Processing Flow

1. **Detection**: GitHub Actions detects changes in `policyDefinitions/*.json`
2. **Deployment**: PowerShell scripts deploy policies using Bicep templates (`utilities/policyAgent/`)
3. **Content Extraction**: Policy definitions are extracted and encoded for AI analysis
4. **AI Analysis**: Azure AI Foundry agent receives and analyzes policies
5. **Test Generation**: AI creates realistic test scenarios for each policy
6. **Result Compilation**: Test results are formatted and posted to the PR

## 🧪 Usage

### Adding Policy Definitions

1. Create JSON policy definition files in the `policyDefinitions/` folder
2. Follow the standard Azure Policy definition format
3. Commit your changes and create a pull request
4. The workflow will automatically deploy and test your policies
5. Review AI-generated feedback in the PR comments

### Example Policy

Here's a simple policy that restricts resource deployment locations:

```json
{
  "properties": {
    "displayName": "Allowed locations for resources",
    "policyType": "Custom",
    "mode": "Indexed", 
    "description": "This policy restricts the locations where resources can be deployed",
    "parameters": {
      "listOfAllowedLocations": {
        "type": "Array",
        "defaultValue": ["eastus", "westus2"]
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

### What Happens When You Create a PR

1. **Automated Deployment**: Your policy is deployed to Azure for testing
2. **AI Analysis**: The AI agent analyzes your policy logic and structure  
3. **Test Generation**: AI creates multiple test scenarios based on your policy rules
4. **Results**: Comprehensive test results are posted as PR comments

**Example AI Feedback:**
```markdown
## Azure Policy Test Results

### ✅ Policy Test Completed Successfully for `allowed-locations.json`
The Policy 'Allowed locations for resources' successfully validated.

**Details:**
- Policy correctly blocks resource deployment to unauthorized regions
- Test scenarios confirmed expected deny behavior  
- No syntax or logic issues detected
```
## 🔧 Technical Details

### Repository Structure & Components

```
AzurePolicyAgents/
├── .github/
│   ├── workflows/
│   │   └── PolicyAgent.yml          # Main GitHub Action workflow
│   └── scripts/
│       ├── deploy-policies.ps1      # Policy deployment orchestration
│       ├── test-policies.ps1        # AI testing coordinator
│       └── get-changed-files.sh     # File change detection utility
├── policyDefinitions/
│   └── allowedLocations.json.sample # Sample policy definition
├── utilities/
│   └── policyAgent/
│       ├── deployDef.ps1           # Core deployment utility
│       ├── policyDef.bicep         # Bicep template for policy creation
│       └── policyDef.parameters.json # Template parameter file
├── infra/
│   └── bicep/                      # Azure AI infrastructure templates
│       ├── agentsSetup.bicep       # Main infrastructure deployment
│       └── agentInstructions/      # AI agent system prompts and configs
└── docs/
    └── Getting-Started.md          # Complete setup guide
```

### AI Agent Capabilities

The Azure AI Foundry agent is configured to:
- **Policy Logic Analysis**: Understand complex policy rules and conditions
- **Test Scenario Generation**: Create realistic scenarios that test policy behavior
- **Compliance Validation**: Verify policies meet intended compliance requirements
- **Best Practice Recommendations**: Suggest improvements based on Azure Policy patterns
- **Detailed Reporting**: Provide comprehensive feedback on policy effectiveness

### Policy Definition Requirements

Each policy must follow the standard Azure Policy definition format:

## 🧪 How It Works

### Workflow Process

1. **Trigger**: Workflow runs on pull requests affecting `policyDefinitions/*.json`
2. **Deployment**: Uses PowerShell and Bicep to deploy policies to Azure
3. **AI Analysis**: Sends policy content to Azure AI Foundry agent
4. **Testing**: AI generates and executes test scenarios
5. **Reporting**: Posts comprehensive results as PR comments

### Key Components

- **PolicyAgent.yml**: Main GitHub Actions workflow
- **deploy-policies.ps1**: Handles policy deployment using Bicep templates
- **test-policies.ps1**: Orchestrates AI-powered testing
- **deployDef.ps1**: Core utility for policy deployment
- **policyDef.bicep**: Bicep template for creating Azure Policy definitions

## 🔧 Local Development (Optional)

For enhanced local development, you can install the Azure Resource Graph MCP Server:

**[📦 Install Azure Resource Graph MCP Server](https://insiders.vscode.dev/redirect/mcp/install?name=Azure%20Resource%20Graph&config=%7B%22command%22%3A%22npx%22%2C%22args%22%3A%5B%22-y%22%2C%22@krnese/azure-resource-graph-mcp@latest%22%5D%2C%22env%22%3A%7B%22AZURE_SUBSCRIPTION_ID%22%3A%22YOUR_SUBSCRIPTION_ID%22%7D%7D)**

Or manually add to your VS Code `settings.json`:

```json
{
  "mcp": {
    "servers": {
      "azure-rg-mcp": {
        "command": "npx",
        "args": ["-y", "@krnese/azure-resource-graph-mcp@latest"],
        "env": {
          "AZURE_SUBSCRIPTION_ID": "your-subscription-id-here"
        }
      }
    }
  }
}
```
```json
{
  "properties": {
    "displayName": "Your Policy Display Name",
    "policyType": "Custom",
    "mode": "Indexed",
    "description": "Clear description of what this policy does",
    "metadata": {
      "category": "General"
    },
    "parameters": {
      "parameterName": {
        "type": "String|Array|Object",
        "defaultValue": "default-value",
        "metadata": {
          "displayName": "Parameter Display Name",
          "description": "Parameter description"
        }
      }
    },
    "policyRule": {
      "if": {
        // Policy condition logic
      },
      "then": {
        "effect": "deny|audit|modify|deployIfNotExists"
      }
    }
  }
}
```

### Supported Effects
- **deny**: Blocks non-compliant resource operations
- **audit**: Logs non-compliant resources for reporting
- **modify**: Automatically corrects non-compliant resources
- **deployIfNotExists**: Deploys additional resources when conditions are met

## 🔍 Testing Process

### What Gets Tested

The AI agent automatically tests:
- **Policy Syntax**: Validates JSON structure and Azure Policy schema compliance
- **Logic Effectiveness**: Tests if policy conditions work as intended
- **Resource Coverage**: Verifies policy applies to intended resource types
- **Edge Cases**: AI identifies and tests potential policy bypass scenarios
- **Best Practices**: Checks alignment with Azure Policy design patterns

## 🛠️ Configuration

### GitHub Repository Setup

The workflow requires these secrets and variables to be configured in your repository:

**Required Secrets** (from Bicep deployment outputs):

| Secret Name | Description |
|-------------|-------------|
| `AZURE_CLIENT_ID` | User-Assigned Managed Identity Client ID |
| `AZURE_TENANT_ID` | Azure AD Tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Target Azure Subscription ID |

**Required Variables** (from Bicep deployment outputs):

| Variable Name | Description |
|---------------|-------------|
| `PROJECT_ENDPOINT` | Azure AI Foundry Project Endpoint |
| `ASSISTANT_ID` | Azure AI Agent/Assistant ID |

### Authentication Setup

The workflow uses federated identity credentials for secure authentication:
- **User-Assigned Managed Identity**: Created by the Bicep infrastructure templates
- **Federated Credentials**: Must be configured for your GitHub repository
- **Azure Permissions**: Managed identity needs Contributor access to your subscription

For complete configuration instructions, see the [Getting Started Guide](docs/Getting-Started.md).

## 🔧 Local Development (Optional)

For enhanced local development, you can install the Azure Resource Graph MCP Server:

**[📦 Install Azure Resource Graph MCP Server](https://insiders.vscode.dev/redirect/mcp/install?name=Azure%20Resource%20Graph&config=%7B%22command%22%3A%22npx%22%2C%22args%22%3A%5B%22-y%22%2C%22@krnese/azure-resource-graph-mcp@latest%22%5D%2C%22env%22%3A%7B%22AZURE_SUBSCRIPTION_ID%22%3A%22YOUR_SUBSCRIPTION_ID%22%7D%7D)**

Or manually add to your VS Code `settings.json`:

```json
{
  "mcp": {
    "servers": {
      "azure-rg-mcp": {
        "command": "npx",
        "args": ["-y", "@krnese/azure-resource-graph-mcp@latest"],
        "env": {
          "AZURE_SUBSCRIPTION_ID": "your-subscription-id-here"
        }
      }
    }
  }
}
```

## 📊 Monitoring and Costs

### What to Monitor

- **GitHub Actions**: Check workflow execution in the Actions tab
- **Azure Costs**: Monitor AI Foundry usage and compute costs
- **Policy Deployments**: Track deployed policies in Azure Policy portal
- **Resource Usage**: Monitor any test resource creation/deletion

### Cost Optimization

- **AI Usage**: AI agents only run when policies are changed in PRs
- **Resource Cleanup**: Test resources are automatically cleaned up after testing
- **Efficient Triggers**: Workflow only processes changed policy files

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Workflow

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes and test with sample policies
4. Ensure your changes work with the GitHub Actions workflow
5. Commit your changes: `git commit -m 'Add some feature'`
6. Push to the branch: `git push origin feature/your-feature`
7. Submit a pull request

## 🐛 Troubleshooting

### Common Issues

- **Authentication Failures**: Verify your managed identity Client ID and federated credentials
- **Permission Errors**: Ensure Contributor permissions on the target subscription
- **AI Agent Issues**: Check that your `ASSISTANT_ID` and `PROJECT_ENDPOINT` are correct
- **Policy Deployment Failures**: Review Bicep template logs and policy JSON structure

For detailed troubleshooting, see the [Getting Started Guide](docs/Getting-Started.md).

## 📚 Documentation

- [Getting Started Guide](docs/Getting-Started.md) - Complete setup and usage instructions
- [Contributing Guide](CONTRIBUTING.md) - How to contribute to the project  
- [Security Policy](SECURITY.md) - Security guidelines and reporting

## 🌟 Current Limitations

- Only supports JSON policy definition files in `policyDefinitions/` folder  
- Requires manual setup of Azure AI Foundry infrastructure via Bicep deployment
- AI-generated tests are simulated and may not cover all real-world scenarios
- Limited to pull request and main branch workflow triggers
- Requires federated identity configuration for each repository

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙋‍♀️ Support

- **Issues**: Report bugs and request features via [GitHub Issues](https://github.com/Azure/AzurePolicyAgents/issues)
- **Discussions**: Join conversations in [GitHub Discussions](https://github.com/Azure/AzurePolicyAgents/discussions)
- **Documentation**: Start with our [Getting Started Guide](docs/Getting-Started.md)

---

## � Documentation

- [Getting Started Guide](docs/Getting-Started.md) - Comprehensive setup and usage instructions
- [Contributing Guide](CONTRIBUTING.md) - How to contribute to the project
- [Security Policy](SECURITY.md) - Security guidelines and reporting

## 🌟 Current Limitations

- Only supports JSON policy definition files in `policyDefinitions/` folder  
- Requires manual setup of Azure AI Foundry infrastructure
- AI-generated tests are simulated and may not cover all real-world scenarios
- Limited to pull request and main branch workflow triggers
- Requires federated identity configuration for each repository

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙋‍♀️ Support

- **Issues**: Report bugs and request features via [GitHub Issues](https://github.com/Azure/AzurePolicyAgents/issues)
- **Discussions**: Join conversations in [GitHub Discussions](https://github.com/Azure/AzurePolicyAgents/discussions)

## 🌟 Acknowledgments

- Microsoft Azure Policy team
- VS Code MCP community
- Contributors and maintainers

---

**Made with ❤️ for the Azure Policy community**
