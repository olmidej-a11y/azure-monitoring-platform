# Setup Guide (Beginner-Friendly)

This guide walks you through deploying the project safely with placeholders and minimal cost.  
Do not commit real secrets or personal data.

## 1) Prerequisites

- Azure CLI logged in
- Bicep CLI installed
- SSH public key (for optional VM)

## 2) Set subscription

```
az account set --subscription <SUBSCRIPTION_ID>
```

## 3) Update parameters (dev)

Edit `infra/env/dev.parameters.json` and replace placeholders:

- `monitoringRgName`, `workspaceName`
- `nsgName`, `nsgResourceGroup`
- `flowLogStorageAccountName`
- `vnetResourceGroupName`, `vnetName`
- `emailReceiverAddress`
- `devVmAdminPublicKey` (SSH public key)
- `logicAppTriggerUrl` (leave empty until Step 6)
- `automationRoleAssignmentName` (leave empty unless adopting existing assignment)
- `remediationTargetVmResourceId` (leave empty until VM exists)

## 4) Deploy (subscription scope)

```
az deployment sub create \
  --location <REGION> \
  --name dev-env-001 \
  --template-file infra/env/main.bicep \
  --parameters @infra/env/dev.parameters.json
```

## 4a) Deployment Toggles Workflow (Recommended Order)

Start with the safest defaults, then enable features one by one:

1) **Base deploy** (cost-safe)
   - `enableDevVm=false`
   - `enableBudgetAlert=false`
   - `enableLogicAppRemediation=false`
   - `enableVnetFlowLogs=false`

2) **Enable budget alert**
   - Set `enableBudgetAlert=true`
   - Set `budgetStartDate` to the current month (yyyy-MM-01)
   - Redeploy:
```
az deployment sub create \
  --location <REGION> \
  --name dev-env-001 \
  --template-file infra/env/main.bicep \
  --parameters @infra/env/dev.parameters.json
```

3) **Enable demo VM**
   - Set `enableDevVm=true`
   - Set `devVmAdminPublicKey`
   - Redeploy:
```
az deployment sub create \
  --location <REGION> \
  --name dev-env-001 \
  --template-file infra/env/main.bicep \
  --parameters @infra/env/dev.parameters.json
```

4) **Enable Logic App remediation**
   - Set `enableLogicAppRemediation=true`
   - Set `remediationTargetVmResourceId` to the VM resource ID:
```
az vm show -g <WORKLOAD_RG> -n <VM_NAME> --query id -o tsv
```
   - Redeploy:
```
az deployment sub create \
  --location <REGION> \
  --name dev-env-001 \
  --template-file infra/env/main.bicep \
  --parameters @infra/env/dev.parameters.json
```

5) **Wire Logic App into Action Group**
   - Get callback URL:
```
az rest --method post --uri "https://management.azure.com/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<MONITORING_RG>/providers/Microsoft.Logic/workflows/<LOGIC_APP_NAME>/triggers/manual/listCallbackUrl?api-version=2016-06-01"
```
   - Set `logicAppTriggerUrl`
   - Redeploy:
```
az deployment sub create \
  --location <REGION> \
  --name dev-env-001 \
  --template-file infra/env/main.bicep \
  --parameters @infra/env/dev.parameters.json
```

## 5) Post-deploy (runbooks)

Import and schedule runbooks:

```
powershell -ExecutionPolicy Bypass -File infra/automation/import-runbooks.ps1 `
  -AutomationAccountName <AUTOMATION_ACCOUNT> `
  -AutomationResourceGroup <MONITORING_RG> `
  -SubscriptionId <SUBSCRIPTION_ID> `
  -TargetResourceGroup <WORKLOAD_RG>
```

## 6) Optional demo VM

Enable VM deployment:

```
"enableDevVm": { "value": true },
"devVmAdminPublicKey": { "value": "<SSH_PUBLIC_KEY>" }
```

Redeploy and then tag VMs if needed:
- `AutoShutdown=true`
- `PatchGroup=prod`

## 7) Manual RBAC (if required)

If you cannot create role assignments via IaC, do it in the portal:
Resource group -> Access control (IAM) -> Add role assignment -> Virtual Machine Contributor -> Automation Account identity.

## Cleanup (optional)

Delete resources when finished:

```
az consumption budget delete --budget-name <BUDGET_NAME>
az group delete --name <RG_NAME> --yes --no-wait
```

