param(
  [Parameter(Mandatory=$true)]
  [string] $SubscriptionId,

  [Parameter(Mandatory=$true)]
  [string] $TargetResourceGroup,

  [Parameter(Mandatory=$false)]
  [string] $TagName = "PatchGroup",

  [Parameter(Mandatory=$false)]
  [string] $TagValue = "prod",

  [Parameter(Mandatory=$false)]
  [ValidateSet("Windows","Linux")]
  [string] $OsType = "Windows"
)

$ErrorActionPreference = "Stop"

Connect-AzAccount -Identity
Set-AzContext -Subscription $SubscriptionId | Out-Null

$vms = Get-AzVM -ResourceGroupName $TargetResourceGroup |
  Where-Object { $_.Tags.ContainsKey($TagName) -and ($_.Tags[$TagName] -eq $TagValue) }

if (-not $vms -or $vms.Count -eq 0) {
  Write-Output "No VMs found with tag $TagName=$TagValue in $TargetResourceGroup"
  return
}

foreach ($vm in $vms) {
  Write-Output "Patching VM: $($vm.Name) ($OsType)"

  if ($OsType -eq "Windows") {
    $script = @'
powershell -NoProfile -ExecutionPolicy Bypass -Command "Install-PackageProvider -Name NuGet -Force; Set-PSRepository -Name PSGallery -InstallationPolicy Trusted; Install-Module PSWindowsUpdate -Force; Import-Module PSWindowsUpdate; Get-WindowsUpdate; Install-WindowsUpdate -AcceptAll -IgnoreReboot -Verbose"
'@
    $res = Invoke-AzVMRunCommand -ResourceGroupName $TargetResourceGroup -VMName $vm.Name -CommandId "RunPowerShellScript" -ScriptString $script
    $res.Value | ForEach-Object { Write-Output $_.Message }
  } else {
    $script = @'
sudo apt-get update && sudo apt-get -y upgrade
'@
    $res = Invoke-AzVMRunCommand -ResourceGroupName $TargetResourceGroup -VMName $vm.Name -CommandId "RunShellScript" -ScriptString $script
    $res.Value | ForEach-Object { Write-Output $_.Message }
  }
}
