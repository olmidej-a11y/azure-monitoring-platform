targetScope = 'resourceGroup'

@description('Azure region for the monitoring resources.')
param location string = resourceGroup().location

@description('Log Analytics Workspace name.')
param workspaceName string

@description('Workspace SKU.')
@allowed([
  'PerGB2018'
])
param skuName string = 'PerGB2018'

@description('Retention in days (30 is a sensible lab default).')
param retentionInDays int = 30

@description('Tags applied to the workspace.')
param tags object = {}

resource law 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: skuName
    }
    retentionInDays: retentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

output workspaceId string = law.id
output workspaceCustomerId string = law.properties.customerId
