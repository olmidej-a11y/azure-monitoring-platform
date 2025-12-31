targetScope = 'resourceGroup'

@description('Alert location.')
param location string = resourceGroup().location

@description('Log Analytics workspace resource ID.')
param workspaceResourceId string

@description('Action group resource ID. Leave empty to create alert without notifications.')
param actionGroupId string = ''

@description('Alert name.')
param alertName string = 'firewall-deny-spike'

var query = '''
AzureDiagnostics
| where Category in ("AzureFirewallNetworkRule","AzureFirewallApplicationRule")
| summarize DenyCount = count() by bin(TimeGenerated, 5m)
| where DenyCount > 20
'''

resource alert 'Microsoft.Insights/scheduledQueryRules@2021-08-01' = {
  name: alertName
  location: location
  properties: {
    displayName: 'Firewall deny spike detected'
    description: 'Detects spikes in Azure Firewall deny actions.'
    severity: 2
    enabled: true
    scopes: [
      workspaceResourceId
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT10M'
    criteria: {
      allOf: [
        {
          query: query
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: empty(actionGroupId) ? null : {
      actionGroups: [
        actionGroupId
      ]
    }
  }
}
