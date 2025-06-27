targetScope = 'subscription'

@description('The policy definition object to be deployed.')
param policyDefinition object

resource resPolicyDefinitions 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: policyDefinition.name // Ensure the name is unique for the policy definition
  properties: {
    description: policyDefinition.properties.description
    displayName: policyDefinition.properties.displayName
    metadata: policyDefinition.properties.metadata
    mode: policyDefinition.properties.mode
    parameters: policyDefinition.properties.parameters
    policyType: policyDefinition.properties.policyType
    policyRule: policyDefinition.properties.policyRule
  }
}

resource resPolicyAssignments 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: '${resPolicyDefinitions.name}-assignment'
  properties: {
    displayName: resPolicyDefinitions.properties.displayName
    policyDefinitionId: resPolicyDefinitions.id
  }
}

output policyDefinitionId string = resPolicyDefinitions.id
output policyDefinitionName string = resPolicyDefinitions.name
output policyDefinitionObject object = resPolicyDefinitions.properties
output policyDefinitionParameters object = resPolicyDefinitions.properties.parameters
output policyDefinitionRule object = resPolicyDefinitions.properties.policyRule
output policyAssignmentId string = resPolicyAssignments.id
output policyAssignmentName string = resPolicyAssignments.name
output policyAssignmentObject object = resPolicyAssignments.properties
