// RG-scoped module; deploy to the same RG as the firewall being monitored.
targetScope = 'resourceGroup'

@description('Azure Firewall name (must exist in this resource group).')
param firewallName string

@description('Log Analytics workspace resource ID.')
param workspaceResourceId string

@description('Diagnostic setting name.')
param diagName string = 'diag-to-law'

resource firewall 'Microsoft.Network/azureFirewalls@2023-11-01' existing = {
  name: firewallName
}

resource fwDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagName
  scope: firewall
  properties: {
    workspaceId: workspaceResourceId
    logs: [
      { category: 'AzureFirewallApplicationRule', enabled: true }
      { category: 'AzureFirewallNetworkRule', enabled: true }
      { category: 'AzureFirewallDnsProxy', enabled: true }
      { category: 'AzureFirewallFatFlowLog', enabled: true }
      { category: 'AzureFirewallFirewallLogs', enabled: true }
    ]
    metrics: [
      { category: 'AllMetrics', enabled: true }
    ]
  }
}
