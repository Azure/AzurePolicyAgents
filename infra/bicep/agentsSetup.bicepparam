using './agentsSetup.bicep'

// Basic resource parameters
param rgName = 'KNfooxai' // Name of the resource group for all resources
param resourceName = 'knfooxai' // Resource name prefix for all resources
param location = 'swedencentral' // check for model availability and capacity in the model specific parameters below

// Setup type
param setupType = 'azureAIAgents' // 'azureAIAgents' or 'azureOpenAIAssistants'

// Proxy agent parameters
param proxyAgentName = 'aiproxy' // Agent name for the first proxy agent
param proxyAgentInstructions = loadTextContent('./agentInstructions/defaultProxyAgentInstructions.txt') // Instructions for the agents

// AI agent parameters
param agentModelCapacity = 150 // Model capacity - will apply to all AI Agents/Assistant APIs
param agentModelName = 'gpt-4.1' // Model name - will apply to all AI Agents/Assistant APIs
param agentModelVersion = '2025-04-14' // Model version - will apply to all AI Agents/Assistant APIs
param agentModelDeploymentName = 'gpt-4.1' // Model deployment name - will apply to all AI Agents/Assistant APIs
param agentModelSkuName = 'GlobalStandard' // Model SKU name - will apply to all AI Agents/Assistant APIs

// Additional param for agent tooling
param addKnowledge = 'groundingWithBing' // Add knowledge to the AI Agents - 'none', 'groundingWithBing', or 'aiSearch'

// Additional parameter for sample setups and demos
param sampleScenario = 'none' // Add sample scenarios - 'none' or 'finance'
