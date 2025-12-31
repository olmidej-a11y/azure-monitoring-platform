param(
  [Parameter(Mandatory=$true)]
  [string] $AutomationAccountName,

  [Parameter(Mandatory=$true)]
  [string] $AutomationResourceGroup,

  [Parameter(Mandatory=$true)]
  [string] $SubscriptionId,

  [Parameter(Mandatory=$true)]
  [string] $TargetResourceGroup,

  [Parameter(Mandatory=$false)]
  [string] $ShutdownTagName = "AutoShutdown",

  [Parameter(Mandatory=$false)]
  [string] $ShutdownTagValue = "true",

  [Parameter(Mandatory=$false)]
  [string] $PatchTagName = "PatchGroup",

  [Parameter(Mandatory=$false)]
  [string] $PatchTagValue = "prod",

  [Parameter(Mandatory=$false)]
  [ValidateSet("Windows","Linux")]
  [string] $PatchOsType = "Windows",

  [Parameter(Mandatory=$false)]
  [string] $ShutdownScheduleName = "daily-shutdown",

  [Parameter(Mandatory=$false)]
  [string] $PatchScheduleName = "weekly-patching",

  [Parameter(Mandatory=$false)]
  [string] $CostReportScheduleName = "weekly-cost-report",

  [Parameter(Mandatory=$false)]
  [string] $ShutdownStartTimeUtc = "",

  [Parameter(Mandatory=$false)]
  [string] $PatchStartTimeUtc = "",

  [Parameter(Mandatory=$false)]
  [string] $CostReportStartTimeUtc = ""
)

$ErrorActionPreference = "Stop"

az account set --subscription $SubscriptionId | Out-Null

$location = az automation account show `
  --resource-group $AutomationResourceGroup `
  --name $AutomationAccountName `
  --query location -o tsv

if (-not $location) {
  throw "Failed to resolve Automation Account location."
}

$base = Split-Path -Parent $MyInvocation.MyCommand.Path
$runbookDir = Join-Path $base "runbooks"

$runbooks = @(
  @{ Name = "Shutdown-TaggedVMs"; File = (Join-Path $runbookDir "Shutdown-TaggedVMs.ps1") },
  @{ Name = "Weekly-Patch-TaggedVMs"; File = (Join-Path $runbookDir "Weekly-Patch-TaggedVMs.ps1") },
  @{ Name = "Cost-Optimisation-Report"; File = (Join-Path $runbookDir "Cost-Optimisation-Report.ps1") }
)

foreach ($rb in $runbooks) {
  Write-Host "Upserting $($rb.Name)..."
  $existing = $null
  try {
    $existing = az automation runbook show `
      --resource-group $AutomationResourceGroup `
      --automation-account-name $AutomationAccountName `
      --name $rb.Name 2>$null
  } catch {
    $existing = $null
  }

  if (-not $existing) {
    az automation runbook create `
      --resource-group $AutomationResourceGroup `
      --automation-account-name $AutomationAccountName `
      --name $rb.Name `
      --type PowerShell `
      --location $location | Out-Null
  }

  az automation runbook replace-content `
    --resource-group $AutomationResourceGroup `
    --automation-account-name $AutomationAccountName `
    --name $rb.Name `
    --content "@$($rb.File)" | Out-Null

  az automation runbook publish `
    --resource-group $AutomationResourceGroup `
    --automation-account-name $AutomationAccountName `
    --name $rb.Name | Out-Null
}

function Ensure-Schedule {
  param(
    [string] $ScheduleName,
    [string] $StartTimeUtc,
    [string] $Frequency,
    [int] $Interval
  )

  $existing = $null
  try {
    $existing = az automation schedule show `
      --resource-group $AutomationResourceGroup `
      --automation-account-name $AutomationAccountName `
      --name $ScheduleName 2>$null
  } catch {
    $existing = $null
  }

  if (-not $existing) {
    Write-Host "Creating schedule $ScheduleName..."
    $startTime = Get-ValidStartTime -RequestedUtc $StartTimeUtc
    $args = @(
      "automation","schedule","create",
      "--resource-group", $AutomationResourceGroup,
      "--automation-account-name", $AutomationAccountName,
      "--name", $ScheduleName,
      "--start-time", $startTime,
      "--time-zone", "UTC",
      "--frequency", $Frequency,
      "--interval", $Interval
    )
    az @args | Out-Null
  }
}

function Get-ValidStartTime {
  param([string] $RequestedUtc)
  $now = (Get-Date).ToUniversalTime()
  $min = $now.AddMinutes(6)
  if ([string]::IsNullOrWhiteSpace($RequestedUtc)) {
    return $min.ToString("yyyy-MM-dd HH:mm:ss")
  }
  try {
    $requested = [DateTime]::Parse($RequestedUtc).ToUniversalTime()
    if ($requested -lt $min) {
      return $min.ToString("yyyy-MM-dd HH:mm:ss")
    }
    return $requested.ToString("yyyy-MM-dd HH:mm:ss")
  } catch {
    return $min.ToString("yyyy-MM-dd HH:mm:ss")
  }
}

Ensure-Schedule -ScheduleName $ShutdownScheduleName -StartTimeUtc $ShutdownStartTimeUtc -Frequency "Day" -Interval 1
Ensure-Schedule -ScheduleName $PatchScheduleName -StartTimeUtc $PatchStartTimeUtc -Frequency "Week" -Interval 1
Ensure-Schedule -ScheduleName $CostReportScheduleName -StartTimeUtc $CostReportStartTimeUtc -Frequency "Week" -Interval 1

Write-Host "Linking schedules to runbooks..."
function New-JobSchedule {
  param(
    [string] $RunbookName,
    [string] $ScheduleName,
    [hashtable] $Parameters
  )

  $jobScheduleId = (New-Guid).Guid
  $uri = "/subscriptions/$SubscriptionId/resourceGroups/$AutomationResourceGroup/providers/Microsoft.Automation/automationAccounts/$AutomationAccountName/jobSchedules/$jobScheduleId"
  $body = @{
    properties = @{
      runbook = @{ name = $RunbookName }
      schedule = @{ name = $ScheduleName }
      parameters = $Parameters
    }
  } | ConvertTo-Json -Depth 6

  $tempPath = [System.IO.Path]::GetTempFileName()
  $body | Out-File -FilePath $tempPath -Encoding utf8

  try {
    az rest --method put --uri $uri --uri-parameters "api-version=2015-10-31" --headers "Content-Type=application/json" --body "@$tempPath" | Out-Null
  } catch {
    $msg = $_.Exception.Message
    if ($msg -match "Conflict" -or $msg -match "AlreadyExists") {
      Write-Host "Job schedule already exists for $RunbookName / $ScheduleName. Skipping."
    } else {
      throw
    }
  } finally {
    if (Test-Path $tempPath) {
      Remove-Item $tempPath -Force
    }
  }
}

New-JobSchedule -RunbookName "Shutdown-TaggedVMs" -ScheduleName $ShutdownScheduleName -Parameters @{
  SubscriptionId = $SubscriptionId
  TargetResourceGroup = $TargetResourceGroup
  TagName = $ShutdownTagName
  TagValue = $ShutdownTagValue
}

New-JobSchedule -RunbookName "Weekly-Patch-TaggedVMs" -ScheduleName $PatchScheduleName -Parameters @{
  SubscriptionId = $SubscriptionId
  TargetResourceGroup = $TargetResourceGroup
  TagName = $PatchTagName
  TagValue = $PatchTagValue
  OsType = $PatchOsType
}

New-JobSchedule -RunbookName "Cost-Optimisation-Report" -ScheduleName $CostReportScheduleName -Parameters @{
  SubscriptionId = $SubscriptionId
  TargetResourceGroup = $TargetResourceGroup
}

Write-Host "Imported runbooks and scheduled jobs."
