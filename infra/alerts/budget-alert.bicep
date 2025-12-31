targetScope = 'subscription'

@description('Budget name.')
param budgetName string

@description('Budget amount in subscription currency.')
param amount int

@description('Time grain for the budget.')
@allowed([
  'Monthly'
  'Quarterly'
  'Annually'
])
param timeGrain string = 'Monthly'

@description('Budget start date (yyyy-MM-dd).')
param startDate string

@description('Budget end date (yyyy-MM-dd).')
param endDate string

@description('Contact emails for budget notifications.')
param contactEmails array = []

resource budget 'Microsoft.Consumption/budgets@2023-05-01' = {
  name: budgetName
  properties: {
    category: 'Cost'
    amount: amount
    timeGrain: timeGrain
    timePeriod: {
      startDate: '${startDate}T00:00:00Z'
      endDate: '${endDate}T00:00:00Z'
    }
    notifications: {
      actual80: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 80
        contactEmails: contactEmails
      }
      actual100: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 100
        contactEmails: contactEmails
      }
    }
  }
}

output budgetId string = budget.id
