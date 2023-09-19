param roleDefinitionResourceId string
param principalId string

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, principalId, roleDefinitionResourceId)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionResourceId)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
