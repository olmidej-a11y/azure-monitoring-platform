// Network Watcher is a regional singleton; keep the default name.

targetScope = 'resourceGroup'

@description('Azure region where Network Watcher should exist, e.g. westeurope')
param location string = resourceGroup().location

var normalizedLocation = toLower(trim(location))
var networkWatcherName = 'NetworkWatcher_${normalizedLocation}'

resource networkWatcher 'Microsoft.Network/networkWatchers@2023-11-01' = {
  name: networkWatcherName
  location: location
  properties: {}
}

output networkWatcherId string = networkWatcher.id
output networkWatcherNameOutput string = networkWatcher.name
