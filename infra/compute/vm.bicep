targetScope = 'resourceGroup'

@description('Azure region for the VM.')
param location string = resourceGroup().location

@description('VM name.')
param vmName string

@description('VM size.')
param vmSize string = 'Standard_B1s'

@description('Admin username.')
param adminUsername string

@secure()
@description('SSH public key.')
param adminPublicKey string

@description('Virtual network resource ID.')
param vnetResourceId string

@description('Subnet name in the VNet.')
param subnetName string = 'default'

@description('Network security group resource ID (optional).')
param nsgResourceId string = ''

@description('Tags applied to the VM resources.')
param tags object = {}

var subnetId = '${vnetResourceId}/subnets/${subnetName}'

resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: '${vmName}-nic'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetId
          }
        }
      }
    ]
    networkSecurityGroup: nsgResourceId == '' ? null : {
      id: nsgResourceId
    }
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: vmName
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: adminPublicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

output vmId string = vm.id
