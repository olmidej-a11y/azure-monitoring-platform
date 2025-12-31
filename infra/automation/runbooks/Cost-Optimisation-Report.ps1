param(
  [Parameter(Mandatory=$true)]
  [string] $SubscriptionId,

  [Parameter(Mandatory=$true)]
  [string] $TargetResourceGroup
)

$ErrorActionPreference = "Stop"

Connect-AzAccount -Identity
Set-AzContext -Subscription $SubscriptionId | Out-Null

Write-Output "Cost optimization report for RG: $TargetResourceGroup"
Write-Output "Checking for stopped but allocated VMs (common waste)..."

$vms = Get-AzVM -ResourceGroupName $TargetResourceGroup -Status

foreach ($vm in $vms) {
  $state = ($vm.Statuses | Where-Object Code -like "PowerState/*").DisplayStatus
  if ($state -eq "VM stopped") {
    Write-Output "WASTE CANDIDATE: $($vm.Name) is stopped but not deallocated. Consider Stop-AzVM -Force to deallocate."
  }
}

Write-Output "Done."
