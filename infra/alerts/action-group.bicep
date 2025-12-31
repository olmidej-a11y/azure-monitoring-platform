param actionGroupName string
param actionGroupShortName string = 'layi'

@description('email to receive alerts')
param emailReceiverAddress string = ''

@description('Logic App trigger URL for webhook. Leave empty if not using.')
param logicAppTriggerUrl string = ''

resource ag 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'global'
  properties: {
    groupShortName: actionGroupShortName
    enabled: true
    emailReceivers: emailReceiverAddress == '' ? [] : [
      {
        name: 'email'
        emailAddress: emailReceiverAddress
        useCommonAlertSchema: true
      }
    ]
    webhookReceivers: logicAppTriggerUrl == '' ? [] : [
      {
        name: 'logicapp-webhook'
        serviceUri: logicAppTriggerUrl
        useCommonAlertSchema: true
      }
    ]
  }
}

output actionGroupId string = ag.id
