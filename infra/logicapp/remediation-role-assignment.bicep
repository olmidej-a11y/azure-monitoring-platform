targetScope = 'resourceGroup'

@description('Target VM resourceId to restart')
param targetVmResourceId string

@description('PrincipalId of the Logic App managed identity')
param logicAppPrincipalId string

var targetVmName = last(split(targetVmResourceId, '/'))

resource targetVm 'Microsoft.Compute/virtualMachines@2023-03-01' existing = {
  name: targetVmName
}

@description('Assign VM Contributor to Logic App identity on the VM scope')
resource vmRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(targetVmResourceId, logicAppPrincipalId, 'vmcontrib')
  scope: targetVm
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '9980e02c-c2be-4d73-94e8-173b1dc7cf3c')
    principalId: logicAppPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output roleAssignmentId string = vmRole.id
