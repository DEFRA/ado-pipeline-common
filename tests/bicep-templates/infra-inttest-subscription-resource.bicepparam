using './infra-inttest-subscription-resource.bicep'

param resourceGroupName = '#{{IntTest.Subscription.Scope.ResourceGroup}}'
param resourceGroupLocation = '#{{ location }}'
param principalId = '#{{ Ado.ServiceConnection.ServicePrincipalId }}'
param roleDefinitionResourceId = '#{{ Contributor.RoleId }}'
