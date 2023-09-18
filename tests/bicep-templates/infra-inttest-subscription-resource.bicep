targetScope = 'subscription'

param resourceGroupName string
param resourceGroupLocation string
param principalId string
param roleDefinitionResourceId string

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: resourceGroupName
  location: resourceGroupLocation
}

module roleAssignment './modules/roleassignment.bicep' = if (subscription().displayName == 'Visual Studio Enterprise Subscription') {
  name: 'roleAssignmentName'
  scope: resourceGroup
  params: {
    principalId: principalId
    roleDefinitionResourceId: roleDefinitionResourceId
  }
}
