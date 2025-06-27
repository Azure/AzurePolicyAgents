# Azure Policy Agents

A comprehensive toolkit for Azure Policy development, testing, and validation that enhances your local development experience in VS Code and provides automated policy validation through GitHub workflows.

## 🚀 Overview

Azure Policy Agents is designed to streamline the Azure Policy development lifecycle by providing:

- **Local Development Support**: Integration with VS Code through Model Context Protocol (MCP) Server for intelligent policy authoring, compliance assessment, and all-up interaction with all your Azure resources via Resource Graph, for all your subscriptions subject to your Azure RBAC permission(s).

- **[📦 Install Azure Resource Graph MCP Server](https://insiders.vscode.dev/redirect/mcp/install?name=Azure%20Resource%20Graph&config=%7B%22command%22%3A%22npx%22%2C%22args%22%3A%5B%22-y%22%2C%22@krnese/azure-resource-graph-mcp@latest%22%5D%2C%22env%22%3A%7B%22AZURE_SUBSCRIPTION_ID%22%3A%22YOUR_SUBSCRIPTION_ID%22%7D%7D)**

- **Manual Installation**

    If you prefer manual installation, add this configuration to your VS Code `settings.json`:

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

- **Automated Testing**: GitHub workflows for continuous policy validation and testing
- **Policy Validation**: Comprehensive testing framework for Azure Policy definitions and initiatives
- **Development Tools**: Utilities and helpers for policy development best practices

- **Getting started with Azure Policy Agents**:
  See the [Getting Started Guide](docs/Getting-Started.md) for detailed instructions on how to set up and use Azure Policy Agents.

## ✨ Features

### 🔧 Local Development (VS Code + MCP Server)

- **Intelligent Policy Authoring**: Context-aware assistance for writing Azure Policy definitions
- **Real-time Validation**: Instant feedback on policy syntax and structure
- **Policy Templates**: Pre-built templates for common policy scenarios
- **Resource Provider Integration**: Auto-completion for Azure resource types and properties
- **Best Practices Guidance**: Built-in recommendations for policy design patterns

### 🔄 GitHub Workflows Integration

- **Automated Policy Testing**: Validate policy definitions on every commit
- **Compliance Checking**: Ensure policies meet organizational standards
- **Impact Analysis**: Assess policy effects before deployment
- **Continuous Integration**: Seamless integration with your CI/CD pipeline
- **Policy Deployment**: Automated deployment of validated policies to Azure

## 🛠️ Getting Started

### Prerequisites

### Installation


### Quick Start


## 📁 Project Structure

## 🧪 Testing & Validation

### GitHub Workflows

The project includes pre-configured GitHub workflows for:

- **Policy Validation**: Validates policy syntax and structure
- **Security Scanning**: Checks for security best practices
- **Compliance Testing**: Ensures policies meet compliance requirements
- **Deployment**: Automated deployment to Azure environments

#### Workflow Configuration

1. **Set up repository secrets**:
   - `AZURE_CLIENT_ID`
   - `AZURE_TENANT_ID`
   - `AZURE_SUBSCRIPTION_ID`

2. **Configure repository variables**:
   - `AZURE_RESOURCE_GROUP`: The resource group for policy deployment
   - `AZURE_LOCATION`: The Azure region for policy deployment
   - `Assistant_id`: The ID of the created Azure Policy Agent for policy development

### Creating a New Policy


### Testing a Policy

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Workflow

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes and add tests
4. Run the test suite: `npm test`
5. Commit your changes: `git commit -m 'Add some feature'`
6. Push to the branch: `git push origin feature/your-feature`
7. Submit a pull request

## 📚 Documentation

## 🔧 Configuration

### MCP Server Configuration

## 🐛 Troubleshooting

### Common Issues

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
