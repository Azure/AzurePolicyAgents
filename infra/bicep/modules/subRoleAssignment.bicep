targetScope = 'subscription'

param objectId string = ''

param roleDefinitionId string = ''

param principalType string = ''

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().subscriptionId, objectId, roleDefinitionId, subscription().displayName)
  scope: subscription()
  properties: {
    principalId: objectId
    roleDefinitionId: roleDefinitionId
    principalType: principalType
  }
}
