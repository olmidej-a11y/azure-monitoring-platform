targetScope = 'subscription'

@description('Azure region where shared monitoring resources should exist')
param location string

@description('Network Watcher resource group name (Azure default is NetworkWatcherRG)')
param networkWatcherRgName string = 'NetworkWatcherRG'

// Baseline resources for shared monitoring dependencies.

resource networkWatcherRg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: networkWatcherRgName
  location: location
}

module networkWatcher '../network-logs/network-watcher-enable.bicep' = {
  name: 'baseline-network-watcher-${location}'
  scope: networkWatcherRg
  params: {
    location: location
  }
}

output networkWatcherResourceGroup string = networkWatcherRgName
