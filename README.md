# Azure Policy Agents

A comprehensive toolkit for automated Azure Policy development, testing, and validation using GitHub Actions and Azure AI Foundry agents.

> **🚀 Ready to get started?** Follow our [Getting Started Guide](docs/Getting-Started.md) for step-by-step setup instructions.

## 🚀 Overview

Azure Policy Agents streamlines the Azure Policy development lifecycle by providing:

- **Automated Policy Testing**: GitHub Actions workflow that automatically deploys and tests Azure Policy definitions
- **AI-Powered Validation**: Uses Azure AI Foundry agents to generate intelligent test scenarios and validate policy behavior
- **Infrastructure as Code**: Bicep templates for deploying policies and AI infrastructure
- **Local Development Support**: Integration with VS Code through Model Context Protocol (MCP) Server for policy authoring and Azure resource interaction

## ✨ Key Features

- **🔄 Automated GitHub Workflows**: Deploy and test policies on PR creation with AI-powered analysis
- **🤖 AI-Powered Policy Analysis**: Generate intelligent test scenarios and validate policy behavior
- **🛠️ Development Tools**: Bicep templates, PowerShell utilities, and VS Code integration
- **📊 Detailed Reporting**: Comprehensive feedback on policy effectiveness and best practices

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

1. **Use this repository as a template** to create your own Azure Policy Agents repository
2. **Deploy the Azure AI infrastructure** using the provided Bicep templates  
3. **Configure GitHub authentication** with federated identity credentials
4. **Add your policy definitions** to the `policyDefinitions/` folder
5. **Create pull requests** to automatically test your policies

**Prerequisites**: Azure subscription with Owner permissions, Azure CLI or PowerShell

📖 **[Complete Setup Guide](docs/Getting-Started.md)** - Step-by-step instructions with commands and screenshots

## 🔧 How It Works

### Workflow Architecture

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
    ├── Send policy definitions to Azure AI Foundry agent
    ├── AI generates intelligent test scenarios
    ├── Execute simulated policy enforcement tests
    └── Post comprehensive results as PR comments
```

### Key Components

- **PolicyAgent.yml**: Main GitHub Actions workflow
- **deploy-policies.ps1**: Handles policy deployment using Bicep templates
- **test-policies.ps1**: Orchestrates AI-powered testing
- **deployDef.ps1**: Core utility for policy deployment
- **policyDef.bicep**: Bicep template for creating Azure Policy definitions

**Triggers**: Pull requests with changes to `policyDefinitions/*.json` files or pushes to main branch

## 🧪 Usage

### Adding Policy Definitions

1. Create JSON policy definition files in the `policyDefinitions/` folder
2. Commit your changes and create a pull request
3. The workflow will automatically deploy and test your policies
4. Review AI-generated feedback in the PR comments

### Example Policy

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

### Example AI Feedback

```markdown
## Azure Policy Test Results

### ✅ Policy Test Completed Successfully for `allowed-locations.json`
The Policy 'Allowed locations for resources' successfully validated.

**Details:**
- Policy correctly blocks resource deployment to unauthorized regions
- Test scenarios confirmed expected deny behavior  
- No syntax or logic issues detected
```

## 🔧 Configuration

The workflow requires these secrets and variables in your GitHub repository:

**Required Secrets** (from Bicep deployment outputs):
- `AZURE_CLIENT_ID` - User-Assigned Managed Identity Client ID
- `AZURE_TENANT_ID` - Azure AD Tenant ID  
- `AZURE_SUBSCRIPTION_ID` - Target Azure Subscription ID

**Required Variables** (from Bicep deployment outputs):
- `PROJECT_ENDPOINT` - Azure AI Foundry Project Endpoint
- `ASSISTANT_ID` - Azure AI Agent/Assistant ID

**Authentication**: Uses federated identity credentials with user-assigned managed identity

For complete configuration instructions, see the [Getting Started Guide](docs/Getting-Started.md).

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

## 🌟 Acknowledgments

- Microsoft Azure Policy team
- VS Code MCP community
- Contributors and maintainers

---

**Made with ❤️ for the Azure Policy community**
