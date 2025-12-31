targetScope = 'resourceGroup'

param location string
param logicAppName string
param tags object = {}

@description('Target VM resourceId to restart')
param targetVmResourceId string

resource logic 'Microsoft.Logic/workflows@2019-05-01' = {
  name: logicAppName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        targetVmResourceId: {
          type: 'string'
          defaultValue: targetVmResourceId
        }
      }
      triggers: {
        manual: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            schema: {}
          }
        }
      }
      actions: {
        StartVM: {
          type: 'Http'
          inputs: {
            method: 'POST'
            uri: '${environment().resourceManager}${substring(targetVmResourceId, 1)}/start?api-version=2024-03-01'
            authentication: {
              type: 'ManagedServiceIdentity'
            }
          }
        }
        RestartVM: {
          type: 'Http'
          runAfter: {
            StartVM: [
              'Succeeded'
              'Failed'
            ]
          }
          inputs: {
            method: 'POST'
            uri: '${environment().resourceManager}${substring(targetVmResourceId, 1)}/restart?api-version=2024-03-01'
            authentication: {
              type: 'ManagedServiceIdentity'
            }
          }
        }
      }
      outputs: {}
    }
  }
}

output logicAppName string = logic.name
output logicAppPrincipalId string = logic.identity.principalId
