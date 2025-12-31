// RG-scoped module; deploy to the same RG as the NSG being monitored.

targetScope = 'resourceGroup'

@description('NSG name ')
param nsgName string

@description('Log Analytics workspace resource id')
param workspaceResourceId string

@description('Diagnostic setting name')
param diagName string = 'diag-to-law'

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' existing = {
  name: nsgName
}

resource diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagName
  scope: nsg
  properties: {
    workspaceId: workspaceResourceId
    logs: [
      {
        category: 'NetworkSecurityGroupEvent'
        enabled: true
      }
      {
        category: 'NetworkSecurityGroupRuleCounter'
        enabled: true
      }
    ]
    metrics: []
  }
}
