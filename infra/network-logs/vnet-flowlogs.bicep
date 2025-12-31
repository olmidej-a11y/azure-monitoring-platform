targetScope = 'resourceGroup'

@description('Region.')
param location string = resourceGroup().location

@description('Virtual network resource ID to enable flow logs for.')
param vnetResourceId string

@description('Storage account resource ID for flow logs.')
param storageAccountId string

@description('Log Analytics workspace resource ID for Traffic Analytics.')
param workspaceResourceId string

@description('Log Analytics workspace region.')
param workspaceRegion string = location

@description('Enable Traffic Analytics.')
param enableTrafficAnalytics bool = true

@description('Traffic Analytics interval in minutes.')
@allowed([10, 60])
param trafficAnalyticsInterval int = 60

@description('Flow log retention in days.')
param retentionDays int = 7

// Network Watcher must exist per region.
resource nw 'Microsoft.Network/networkWatchers@2022-09-01' existing = {
  name: 'NetworkWatcher_${location}'
}

// VNet flow logs
resource flow 'Microsoft.Network/networkWatchers/flowLogs@2022-09-01' = {
  name: '${nw.name}/${last(split(vnetResourceId, '/'))}-flowlogs'
  location: location
  properties: {
    targetResourceId: vnetResourceId
    storageId: storageAccountId
    enabled: true
    retentionPolicy: {
      days: retentionDays
      enabled: true
    }
    format: {
      type: 'JSON'
      version: 2
    }
    flowAnalyticsConfiguration: enableTrafficAnalytics ? {
      networkWatcherFlowAnalyticsConfiguration: {
        enabled: true
        workspaceId: reference(workspaceResourceId, '2022-10-01', 'Full').properties.customerId
        workspaceRegion: workspaceRegion
        workspaceResourceId: workspaceResourceId
        trafficAnalyticsInterval: trafficAnalyticsInterval
      }
    } : null
  }
}
