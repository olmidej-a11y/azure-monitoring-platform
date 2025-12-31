targetScope = 'resourceGroup'

@description('Azure region for the Automation Account')
param location string

@description('Automation Account name')
param automationAccountName string

@description('Tags applied to automation resources')
param tags object = {}

// Automation Account with system-assigned managed identity.
resource automation 'Microsoft.Automation/automationAccounts@2021-06-22' = {
  name: automationAccountName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: 'Basic'
    }
  }
}

var automationPrincipalId = automation.identity.principalId

// Outputs
output automationAccountNameOut string = automation.name
output automationAccountResourceId string = automation.id
output automationPrincipalId string = automationPrincipalId
