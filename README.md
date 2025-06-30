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

### Prerequisites

- Azure subscription with Contributor permissions
- GitHub repository (use this as a template)
- Azure AI Foundry project with deployed agents

### Setup Steps

1. **Create Repository**: Use this repository as a template
2. **Deploy AI Infrastructure**: Use the Bicep templates in `infra/bicep/`
3. **Configure Authentication**: Set up federated identity credentials
4. **Add GitHub Secrets**: Configure required secrets and variables
5. **Test Setup**: Create a pull request with a policy definition

### Basic Usage

1. Add your policy definitions as JSON files in `policyDefinitions/`
2. Create a pull request with your changes
3. The workflow automatically deploys and tests your policies
4. Review AI-generated test results in PR comments
5. Merge when tests pass and feedback is addressed

For detailed setup instructions, see [Getting Started Guide](docs/Getting-Started.md).

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
## 🛠️ Configuration

### Required GitHub Secrets

| Secret Name | Description |
|-------------|-------------|
| `AZURE_CLIENT_ID` | User-Assigned Managed Identity Client ID |
| `AZURE_TENANT_ID` | Azure AD Tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Target Azure Subscription ID |

### Required GitHub Variables

| Variable Name | Description |
|---------------|-------------|
| `PROJECT_ENDPOINT` | Azure AI Foundry Project Endpoint |
| `ASSISTANT_ID` | Azure AI Agent/Assistant ID |

## 🧪 Example Policy Definition

Create policy definitions in `policyDefinitions/` folder:

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

## 🔍 Testing & Validation

The workflow automatically:

1. **Detects Changes**: Monitors `policyDefinitions/*.json` files in pull requests
2. **Deploys Policies**: Uses Bicep templates to deploy policies to Azure
3. **AI Testing**: Leverages Azure AI Foundry agents to generate test scenarios
4. **Reports Results**: Posts detailed feedback as pull request comments

### Sample Test Output

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

## � Troubleshooting

### Common Issues

- **Authentication Failures**: Verify your managed identity Client ID and federated credentials
- **Permission Errors**: Ensure Contributor permissions on the target subscription
- **AI Agent Issues**: Check that your `ASSISTANT_ID` and `PROJECT_ENDPOINT` are correct
- **Policy Deployment Failures**: Review Bicep template logs and policy JSON structure

For detailed troubleshooting, see the [Getting Started Guide](docs/Getting-Started.md).

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
