param(
  [Parameter(Mandatory=$true)]
  [string] $SubscriptionId,

  [Parameter(Mandatory=$true)]
  [string] $TargetResourceGroup,

  [Parameter(Mandatory=$false)]
  [string] $TagName = "AutoShutdown",

  [Parameter(Mandatory=$false)]
  [string] $TagValue = "true"
)

$ErrorActionPreference = "Stop"

Connect-AzAccount -Identity
Set-AzContext -Subscription $SubscriptionId | Out-Null

$vms = Get-AzVM -ResourceGroupName $TargetResourceGroup -Status |
  Where-Object {
    $_.Tags.ContainsKey($TagName) -and ($_.Tags[$TagName].ToString().ToLower() -eq $TagValue.ToLower())
  }

if (-not $vms -or $vms.Count -eq 0) {
  Write-Output "No VMs found with tag $TagName=$TagValue in $TargetResourceGroup"
  return
}

foreach ($vm in $vms) {
  $state = ($vm.Statuses | Where-Object Code -like "PowerState/*").DisplayStatus
  Write-Output "VM: $($vm.Name) state: $state"

  if ($state -ne "VM deallocated" -and $state -ne "VM stopped") {
    Write-Output "Stopping VM $($vm.Name)..."
    Stop-AzVM -ResourceGroupName $TargetResourceGroup -Name $vm.Name -Force | Out-Null
    Write-Output "Stopped VM $($vm.Name)"
  } else {
    Write-Output "Skipping VM $($vm.Name). Already stopped."
  }
}
