using './agentsSetup.bicep'

// Basic resource parameters
param rgName = 'AzKnPolicyAgent' // Name of the resource group for all resources
param resourceName = 'AzKnPolicyFoundry' // Resource name prefix for all resources
param location = 'swedencentral' // check for model availability and capacity in the model specific parameters below

// AI agent parameters
param agentModelCapacity = 150 // Model capacity
param agentModelName = 'gpt-4.1' // Model name
param agentModelVersion = '2025-04-14' // Model version
param agentModelDeploymentName = 'gpt-4.1' // Model deployment
param agentModelSkuName = 'GlobalStandard' // Model SKU name

// Additional param for agent tooling
param addKnowledge = 'groundingWithBing' // Add knowledge to the AI Agents - 'none', 'groundingWithBing', or 'aiSearch'
