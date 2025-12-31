targetScope = 'resourceGroup'

@description('Log Analytics workspace name in the same RG where this module is deployed.')
param workspaceName string

resource law 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: workspaceName
}

resource sentinel 'Microsoft.SecurityInsights/onboardingStates@2022-12-01-preview' = {
  name: 'default'
  scope: law
  properties: {}
}
