targetScope = 'resourceGroup'

@description('Azure region for the VNet.')
param location string = resourceGroup().location

@description('VNet name.')
param vnetName string

@description('VNet address prefix.')
param addressPrefix string = '10.0.0.0/16'

@description('Subnet name.')
param subnetName string = 'default'

@description('Subnet address prefix.')
param subnetPrefix string = '10.0.0.0/24'

@description('Tags applied to network resources')
param tags object = {}

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
        }
      }
    ]
  }
}

output vnetResourceId string = vnet.id
