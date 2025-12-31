targetScope = 'subscription'

@description('Azure region for monitoring resources')
param location string

@description('Monitoring resource group name')
param monitoringRgName string

@description('Log Analytics workspace name')
param workspaceName string

@description('Retention period for Log Analytics')
param retentionInDays int

@description('Tags applied to monitoring resources')
param tags object = {}

@description('Existing NSG name to enable diagnostics and flow logs for')
param nsgName string

@description('Resource group where the NSG exists')
param nsgResourceGroup string

@description('Network Watcher resource group name (Azure default is NetworkWatcherRG)')
param networkWatcherRgName string = 'NetworkWatcherRG'

@description('Storage account name for NSG flow logs')
param flowLogStorageAccountName string

param enableAutomation bool = true
param enableLogicAppRemediation bool = false
param enableVnetFlowLogs bool = false
param enableVnetCreate bool = false
param enableDevVm bool = false

param automationAccountName string = ''
param targetVmResourceGroupName string = ''
param targetVmSubscriptionId string = subscription().subscriptionId
param assignVmContributor bool = true
param automationRoleAssignmentName string = ''

param actionGroupName string = ''
param emailReceiverAddress string = ''
param logicAppTriggerUrl string = ''
param enableBudgetAlert bool = false
param budgetName string = 'budget-monitoring'
param budgetAmount int = 50
param budgetStartDate string = '2025-01-01'
param budgetEndDate string = '2030-01-01'

param logicAppName string = ''
param remediationTargetVmResourceId string = ''
param remediationTargetVmResourceGroupName string = targetVmResourceGroupName
param vnetResourceId string = ''
param vnetResourceGroupName string = 'rg-layicorp-network'
param vnetName string = 'vnet-hub-layicorp'
param vnetAddressPrefix string = '10.0.0.0/16'
param vnetSubnetName string = 'default'
param vnetSubnetPrefix string = '10.0.0.0/24'
param devVmName string = 'vm-dev-demo'
param devVmSize string = 'Standard_B1s'
param devVmAdminUsername string = 'azureuser'
@secure()
param devVmAdminPublicKey string = ''
param devVmSubnetName string = 'default'
param devVmTags object = {}

// Monitoring resource group
resource monitoringRg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: monitoringRgName
  location: location
  tags: tags
}

// Log Analytics workspace
module logAnalytics '../workspace/log-analytics.bicep' = {
  name: 'law-${monitoringRgName}'
  scope: monitoringRg
  params: {
    location: location
    workspaceName: workspaceName
    retentionInDays: retentionInDays
    tags: tags
  }
}

// Microsoft Sentinel
module sentinel '../sentinel/sentinel-enable.bicep' = {
  name: 'sentinel-${monitoringRgName}'
  scope: monitoringRg
  params: {
    workspaceName: workspaceName
  }
  dependsOn: [
    logAnalytics
  ]
}

// Flow logs storage account
module flowLogStorage '../network-logs/storage-logs.bicep' = {
  name: 'flowlog-storage-${monitoringRgName}'
  scope: monitoringRg
  params: {
    location: location
    storageAccountName: flowLogStorageAccountName
    tags: tags
  }
}

// VNet
module vnet '../network/vnet.bicep' = if (enableVnetCreate) {
  name: 'vnet-${vnetName}'
  scope: resourceGroup(vnetResourceGroupName)
  params: {
    location: location
    vnetName: vnetName
    addressPrefix: vnetAddressPrefix
    subnetName: vnetSubnetName
    subnetPrefix: vnetSubnetPrefix
    tags: tags
  }
}

var effectiveVnetResourceId = enableVnetCreate ? vnet!.outputs.vnetResourceId : vnetResourceId

// VNet flow logs + traffic analytics
module vnetFlowLogs '../network-logs/vnet-flowlogs.bicep' = if (enableVnetFlowLogs) {
  name: 'vnet-flowlogs-${monitoringRgName}'
  scope: resourceGroup(networkWatcherRgName)
  params: {
    location: location
    vnetResourceId: effectiveVnetResourceId
    storageAccountId: flowLogStorage.outputs.storageAccountId
    workspaceResourceId: logAnalytics.outputs.workspaceId
  }
}

// Demo VM for runbook targeting
module devVm '../compute/vm.bicep' = if (enableDevVm) {
  name: 'vm-${devVmName}'
  scope: resourceGroup(targetVmResourceGroupName)
  params: {
    location: location
    vmName: devVmName
    vmSize: devVmSize
    adminUsername: devVmAdminUsername
    adminPublicKey: devVmAdminPublicKey
    vnetResourceId: effectiveVnetResourceId
    subnetName: devVmSubnetName
    nsgResourceId: resourceId(targetVmSubscriptionId, nsgResourceGroup, 'Microsoft.Network/networkSecurityGroups', nsgName)
    tags: union(tags, devVmTags)
  }
}

// NSG diagnostic settings
module nsgDiagnostics '../diagnostics/diag-nsg.bicep' = {
  name: 'diag-nsg-${nsgName}'
  scope: resourceGroup(nsgResourceGroup)
  params: {
    nsgName: nsgName
    workspaceResourceId: logAnalytics.outputs.workspaceId
  }
}

// Scheduled query alerts
module logAlerts '../alerts/log-alerts.bicep' = {
  name: 'log-alerts-${monitoringRgName}'
  scope: monitoringRg
  params: {
    workspaceResourceId: logAnalytics.outputs.workspaceId
  }
}

module automation '../automation/automation-account.bicep' = if (enableAutomation) {
  name: 'automation-${monitoringRgName}'
  scope: monitoringRg
  params: {
    location: location
    automationAccountName: automationAccountName
    tags: tags
  }
}

module remediation '../logicapp/remediation.bicep' = if (enableLogicAppRemediation) {
  name: 'logicapp-${monitoringRgName}'
  scope: monitoringRg
  params: {
    location: location
    logicAppName: logicAppName
    tags: tags
    targetVmResourceId: remediationTargetVmResourceId
  }
}

module remediationRoleAssignment '../logicapp/remediation-role-assignment.bicep' = if (enableLogicAppRemediation) {
  name: 'logicapp-ra-${monitoringRgName}'
  scope: resourceGroup(remediationTargetVmResourceGroupName)
  params: {
    targetVmResourceId: remediationTargetVmResourceId
    logicAppPrincipalId: remediation!.outputs.logicAppPrincipalId
  }
}

module automationRoleAssignment '../automation/automation-role-assignment.bicep' = if (enableAutomation) {
  name: 'automation-ra-${monitoringRgName}'
  scope: resourceGroup(targetVmSubscriptionId, targetVmResourceGroupName)
  params: {
    automationPrincipalId: automation!.outputs.automationPrincipalId
    assignVmContributor: assignVmContributor
    roleAssignmentName: automationRoleAssignmentName
  }
}

module actionGroup '../alerts/action-group.bicep' = if (actionGroupName != '') {
  name: 'ag-${monitoringRgName}'
  scope: monitoringRg
  params: {
    actionGroupName: actionGroupName
    emailReceiverAddress: emailReceiverAddress
    // Provide logicAppTriggerUrl after the initial deploy.
    logicAppTriggerUrl: logicAppTriggerUrl
  }
}

module budgetAlert '../alerts/budget-alert.bicep' = if (enableBudgetAlert) {
  name: 'budget-${monitoringRgName}'
  scope: subscription()
  params: {
    budgetName: budgetName
    amount: budgetAmount
    timeGrain: 'Monthly'
    startDate: budgetStartDate
    endDate: budgetEndDate
    contactEmails: emailReceiverAddress == '' ? [] : [
      emailReceiverAddress
    ]
  }
}


// Outputs
output monitoringRgOut string = monitoringRg.name
output workspaceId string = logAnalytics.outputs.workspaceId
