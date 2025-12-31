targetScope = 'resourceGroup'

@description('PrincipalId of the Automation Account managed identity')
param automationPrincipalId string

@description('Assign Virtual Machine Contributor to the Automation Account managed identity on this resource group')
param assignVmContributor bool = true

@description('Existing role assignment name to adopt. Leave empty to create.')
param roleAssignmentName string = ''

var vmContributorRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '9980e02c-c2be-4d73-94e8-173b1dc7cf3c'
)

var defaultRoleAssignmentName = guid(resourceGroup().id, automationPrincipalId, vmContributorRoleDefinitionId)

resource vmContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (assignVmContributor && roleAssignmentName == '') {
  name: defaultRoleAssignmentName
  properties: {
    roleDefinitionId: vmContributorRoleDefinitionId
    principalId: automationPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource vmContributorAssignmentExisting 'Microsoft.Authorization/roleAssignments@2022-04-01' existing = if (assignVmContributor && roleAssignmentName != '') {
  name: roleAssignmentName
}

output vmContributorRoleAssignmentId string = assignVmContributor
  ? (roleAssignmentName != '' ? vmContributorAssignmentExisting.id : vmContributorAssignment.id)
  : ''
