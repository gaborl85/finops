<#
.SYNOPSIS
Compares resource-level Azure costs between two months and writes a report with anomaly detection.

.DESCRIPTION
Exports monthly resource costs per subscription, computes deltas, writes a top-50 increase report,
and appends detected anomalies.

.PARAMETER SourceMonth
Source month in yyyy-MM format.

.PARAMETER TargetMonth
Target month in yyyy-MM format.

.PARAMETER SignificantChangeThreshold
Fractional threshold (e.g., 0.5 = 50%) for anomaly detection.

.PARAMETER MinimumCostThreshold
Minimum cost to consider for anomaly detection.

.OUTPUTS
None. Writes report files to the current directory.

.NOTES
Requires Azure CLI and the azure-cost CLI to be installed and authenticated.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^\d{4}-\d{2}$')]
    [string]$SourceMonth,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^\d{4}-\d{2}$')]
    [string]$TargetMonth,

    [Parameter()]
    [ValidateRange(0, [double]::MaxValue)]
    [double]$SignificantChangeThreshold = 0.5,

    [Parameter()]
    [ValidateRange(0, [double]::MaxValue)]
    [double]$MinimumCostThreshold = 1.0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

function Get-MonthRange {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^\d{4}-\d{2}$')]
        [string]$Month,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Label
    )

    try {
        $date = [datetime]::ParseExact($Month, 'yyyy-MM', [System.Globalization.CultureInfo]::InvariantCulture)
        return [PSCustomObject]@{
            Date    = $date
            From    = $date.ToString('yyyy-MM-01', [System.Globalization.CultureInfo]::InvariantCulture)
            To      = $date.AddMonths(1).AddDays(-1).ToString('yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture)
            Display = $date.ToString('MMMM yyyy', [System.Globalization.CultureInfo]::InvariantCulture)
        }
    } catch {
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            [System.FormatException]::new("Invalid $Label format. Use yyyy-MM (e.g., 2025-11)."),
            'InvalidMonthFormat',
            [System.Management.Automation.ErrorCategory]::InvalidData,
            $Month
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }
}

$sourceInfo = Get-MonthRange -Month $SourceMonth -Label 'SourceMonth'
$targetInfo = Get-MonthRange -Month $TargetMonth -Label 'TargetMonth'

$sourceDate = $sourceInfo.Date
$targetDate = $targetInfo.Date
$fromSource = $sourceInfo.From
$toSource = $sourceInfo.To
$fromTarget = $targetInfo.From
$toTarget = $targetInfo.To
$sourceMonthName = $sourceInfo.Display
$targetMonthName = $targetInfo.Display

$sourceLabel = "Source: ($fromSource to $toSource)"
$targetLabel = "Target: ($fromTarget to $toTarget)"

# Function to detect anomalies in cost data
function Detect-CostAnomalies {
    param(
        [array]$SourceData,
        [array]$TargetData,
        [string]$SourceMonthName,
        [string]$TargetMonthName,
        [double]$SignificantChangeThreshold = 0.5,  # 50% change threshold
        [double]$MinimumCostThreshold = 1.0         # Minimum cost to consider
    )
    
    # Build SUM maps (key -> total cost)
    $sourceMap = @{}
    foreach ($r in $SourceData) {
        $k = ItemKey $r
        $c = [double]$r.Cost
        if ($sourceMap.ContainsKey($k)) { $sourceMap[$k] += $c } else { $sourceMap[$k] = $c }
    }

    $targetMap = @{}
    foreach ($r in $TargetData) {
        $k = ItemKey $r
        $c = [double]$r.Cost
        if ($targetMap.ContainsKey($k)) { $targetMap[$k] += $c } else { $targetMap[$k] = $c }
    }
    
    $anomalies = @()
    
    # Check all resources in December data
    foreach ($k in $targetMap.Keys) {
        $targetCost = [double]$targetMap[$k]
        $sourceCost = if ($sourceMap.ContainsKey($k)) { [double]$sourceMap[$k] } else { 0 }
        $change = $targetCost - $sourceCost
        $percentChange = if ($sourceCost -ne 0) { [math]::Abs($change / $sourceCost) } else { [double]::PositiveInfinity }
        
        # Skip if below minimum cost threshold
        if ($targetCost -lt $MinimumCostThreshold -and $sourceCost -lt $MinimumCostThreshold) {
            continue
        }
        
        # Check for new costs (appeared in Dec but not in Nov or Nov cost was 0)
        if (($sourceCost -eq 0 -or -not $sourceMap.ContainsKey($k)) -and $targetCost -ge $MinimumCostThreshold) {
            # Get representative row for metadata
            $rep = $TargetData | Where-Object { (ItemKey $_) -eq $k } | Select-Object -First 1
            $anomalies += [PSCustomObject]@{
                Type = "NewCost"
                Name = (ResourceDisplayName $rep)
                Service = $rep.ServiceName
                ResourceGroup = $rep.ResourceGroupName
                Location = $rep.ResourceLocation
                SourceCost = $sourceCost
                TargetCost = $targetCost
                Change = $change
                PercentChange = if ($sourceCost -eq 0) { "N/A" } else { ("{0:P2}" -f $percentChange) }
                Message = "New cost detected"
            }
        }
        # Check for removed costs (existed in Nov but not in Dec or Dec cost is 0)
        elseif ($sourceCost -ge $MinimumCostThreshold -and $targetCost -eq 0) {
            # Get representative row for metadata
            $rep = $SourceData | Where-Object { (ItemKey $_) -eq $k } | Select-Object -First 1
            $anomalies += [PSCustomObject]@{
                Type = "RemovedCost"
                Name = (ResourceDisplayName $rep)
                Service = $rep.ServiceName
                ResourceGroup = $rep.ResourceGroupName
                Location = $rep.ResourceLocation
                SourceCost = $sourceCost
                TargetCost = $targetCost
                Change = $change
                PercentChange = ("{0:P2}" -f $percentChange)
                Message = "Cost removed"
            }
        }
        # Check for significant changes
        elseif ($sourceCost -ge $MinimumCostThreshold -and $targetCost -ge $MinimumCostThreshold -and $percentChange -ge $SignificantChangeThreshold) {
            # Get representative row for metadata
            $rep = $TargetData | Where-Object { (ItemKey $_) -eq $k } | Select-Object -First 1
            $anomalies += [PSCustomObject]@{
                Type = "SignificantChange"
                Name = (ResourceDisplayName $rep)
                Service = $rep.ServiceName
                ResourceGroup = $rep.ResourceGroupName
                Location = $rep.ResourceLocation
                SourceCost = $sourceCost
                TargetCost = $targetCost
                Change = $change
                PercentChange = ("{0:P2}" -f $percentChange)
                Message = if ($change -gt 0) { "Significant cost increase" } else { "Significant cost decrease" }
            }
        }
    }
    
    return $anomalies
}

# Function to append anomalies to file
function Append-AnomaliesToFile {
    param(
        [array]$Anomalies,
        [string]$Currency,
        [string]$OutFile,
        [string]$SourceMonthName,
        [string]$TargetMonthName
    )
    
    if ($Anomalies.Count -eq 0) {
        "`nNo anomalies detected" | Out-File $OutFile -Encoding utf8 -Append
        return
    }
    
    "`n=== DETECTED ANOMALIES ===" | Out-File $OutFile -Encoding utf8 -Append
    
    # Group by type
    $newCosts = $Anomalies | Where-Object { $_.Type -eq "NewCost" }
    $removedCosts = $Anomalies | Where-Object { $_.Type -eq "RemovedCost" }
    $significantChanges = $Anomalies | Where-Object { $_.Type -eq "SignificantChange" } | Sort-Object Change -Descending
    
    # Append new costs
    if ($newCosts.Count -gt 0) {
        "`n💰 NEW COSTS DETECTED:" | Out-File $OutFile -Encoding utf8 -Append
        $newCosts | Sort-Object Change -Descending | Select-Object -First 10 |
            Format-Table -Property @(
                @{Name="Resource"; Expression={ if ($_.Name.Length -gt 50) { $_.Name.Substring(0,50) + "…" } else { $_.Name } }},
                @{Name="Service"; Expression={ $_.Service }},
                @{Name="Resource Group"; Expression={ $_.ResourceGroup }},
                @{Name="Location"; Expression={ $_.Location }},
                @{Name=$SourceMonthName; Expression={ "{0:N2} {1}" -f $_.SourceCost, $Currency }},
                @{Name=$TargetMonthName; Expression={ "{0:N2} {1}" -f $_.TargetCost, $Currency }},
                @{Name="Change"; Expression={ "{0}{1:N2} {2}" -f $(if ($_.Change -ge 0){"+"}else{""}), $_.Change, $Currency }}
            ) | Out-String -Width 500 | Out-File $OutFile -Encoding utf8 -Append
    }
    
    # Append removed costs
    if ($removedCosts.Count -gt 0) {
        "`n💸 COSTS REMOVED:" | Out-File $OutFile -Encoding utf8 -Append
        $removedCosts | Sort-Object Change | Select-Object -First 10 |
            Format-Table -Property @(
                @{Name="Resource"; Expression={ if ($_.Name.Length -gt 50) { $_.Name.Substring(0,50) + "…" } else { $_.Name } }},
                @{Name="Service"; Expression={ $_.Service }},
                @{Name="Resource Group"; Expression={ $_.ResourceGroup }},
                @{Name="Location"; Expression={ $_.Location }},
                @{Name=$SourceMonthName; Expression={ "{0:N2} {1}" -f $_.SourceCost, $Currency }},
                @{Name=$TargetMonthName; Expression={ "{0:N2} {1}" -f $_.TargetCost, $Currency }},
                @{Name="Change"; Expression={ "{0}{1:N2} {2}" -f $(if ($_.Change -ge 0){"+"}else{""}), $_.Change, $Currency }}
            ) | Out-String -Width 500 | Out-File $OutFile -Encoding utf8 -Append
    }
    
    # Append significant changes
    if ($significantChanges.Count -gt 0) {
        "`n📊 SIGNIFICANT COST CHANGES:" | Out-File $OutFile -Encoding utf8 -Append
        $significantChanges | Select-Object -First 15 |
            Format-Table -Property @(
                @{Name="Resource"; Expression={ if ($_.Name.Length -gt 50) { $_.Name.Substring(0,50) + "…" } else { $_.Name } }},
                @{Name="Service"; Expression={ $_.Service }},
                @{Name="Resource Group"; Expression={ $_.ResourceGroup }},
                @{Name="Location"; Expression={ $_.Location }},
                @{Name=$SourceMonthName; Expression={ "{0:N2} {1}" -f $_.SourceCost, $Currency }},
                @{Name=$TargetMonthName; Expression={ "{0:N2} {1}" -f $_.TargetCost, $Currency }},
                @{Name="Change"; Expression={ "{0}{1:N2} {2}" -f $(if ($_.Change -ge 0){"+"}else{""}), $_.Change, $Currency }},
                @{Name="Percent"; Expression={ $_.PercentChange }}
            ) | Out-String -Width 500 | Out-File $OutFile -Encoding utf8 -Append
    }
    
    "`nTotal anomalies detected: $($Anomalies.Count)" | Out-File $OutFile -Encoding utf8 -Append
}

# ---- Process each subscription ----
$azCmd = Get-Command -Name az -ErrorAction SilentlyContinue
$costCmd = Get-Command -Name azure-cost -ErrorAction SilentlyContinue
if (-not $azCmd -or -not $costCmd) {
    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
        [System.Exception]::new('Required CLI(s) missing: az and/or azure-cost.'),
        'MissingCliDependency',
        [System.Management.Automation.ErrorCategory]::ResourceUnavailable,
        $null
    )
    $PSCmdlet.ThrowTerminatingError($errorRecord)
}

$subs = az account list --query "[].[id,name]" -o tsv
if ($LASTEXITCODE -ne 0 -or -not $subs) {
    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
        [System.Exception]::new('Failed to list Azure subscriptions. Ensure Azure CLI is authenticated.'),
        'SubscriptionListFailed',
        [System.Management.Automation.ErrorCategory]::OpenError,
        $null
    )
    $PSCmdlet.ThrowTerminatingError($errorRecord)
}

foreach ($line in $subs) {
    $parts = $line.Trim() -split "`t"
    if ($parts.Count -lt 2) { continue }
    
    $id = $parts[0].Trim()
    $name = $parts[1].Trim()
    
    if (-not $id -or -not $name) { continue }

    Write-Host "`n=== Subscription: $name ($id) ==="

    $safeName = $name -replace '[\\/:*?"<>|]', '_'
    $sourceFile = "$SourceMonth-resources-$safeName.json"
    $targetFile = "$TargetMonth-resources-$safeName.json"
    $outFile = "diff-resources-top50-$safeName.txt"

    Write-Verbose "Processing subscription: $name ($id)"

    if ($PSCmdlet.ShouldProcess($sourceFile, "Export resource costs for $sourceMonthName ($name)")) {
        azure-cost costByResource -s $id --timeframe Custom --from $fromSource --to $toSource -o json |
            Out-File -FilePath $sourceFile -Encoding utf8
        if ($LASTEXITCODE -ne 0) { Write-Warning "Skipping $id ($sourceMonthName export failed)"; continue }
        if (-not (Test-Path -LiteralPath $sourceFile) -or (Get-Item -LiteralPath $sourceFile).Length -eq 0) { Write-Warning "Skipping $id ($sourceMonthName empty)"; continue }
    }

    if ($PSCmdlet.ShouldProcess($targetFile, "Export resource costs for $targetMonthName ($name)")) {
        azure-cost costByResource -s $id --timeframe Custom --from $fromTarget --to $toTarget -o json |
            Out-File -FilePath $targetFile -Encoding utf8
        if ($LASTEXITCODE -ne 0) { Write-Warning "Skipping $id ($targetMonthName export failed)"; continue }
        if (-not (Test-Path -LiteralPath $targetFile) -or (Get-Item -LiteralPath $targetFile).Length -eq 0) { Write-Warning "Skipping $id ($targetMonthName empty)"; continue }
    }

    $sourceData = Get-Content -LiteralPath $sourceFile -Raw | ConvertFrom-Json
    $targetData = Get-Content -LiteralPath $targetFile -Raw | ConvertFrom-Json

    # Determine currency (assume consistent; fallback EUR)
    $currency = ($targetData | Where-Object Currency | Select-Object -First 1 -ExpandProperty Currency)
    if (-not $currency) { $currency = "EUR" }

    # Build SUM maps (key -> total cost)
    $sourceMap = @{}
    foreach ($r in $sourceData) {
        $k = ItemKey $r
        $c = [double]$r.Cost
        if ($sourceMap.ContainsKey($k)) { $sourceMap[$k] += $c } else { $sourceMap[$k] = $c }
    }

    $targetMap = @{}
    foreach ($r in $targetData) {
        $k = ItemKey $r
        $c = [double]$r.Cost
        if ($targetMap.ContainsKey($k)) { $targetMap[$k] += $c } else { $targetMap[$k] = $c }
    }

    $diff = foreach ($k in $targetMap.Keys) {
        $targetCost = [double]$targetMap[$k]
        $sourceCost = if ($sourceMap.ContainsKey($k)) { [double]$sourceMap[$k] } else { 0 }
        $change  = $targetCost - $sourceCost

        if ($change -le 0) { continue }

        # Grab one representative target row for display metadata
        $rep = $targetData | Where-Object { (ItemKey $_) -eq $k } | Select-Object -First 1

        [pscustomobject]@{
            Name        = (ResourceDisplayName $rep)
            Service     = $rep.ServiceName
            Location    = $rep.ResourceLocation
            ResourceGrp = $rep.ResourceGroupName
            Source      = [math]::Round($sourceCost, 3)
            Target      = [math]::Round($targetCost, 3)
            Change      = [math]::Round($change, 3)
            IsNew       = (-not $sourceMap.ContainsKey($k) -or $sourceCost -eq 0)
        }
    }

    # Top 50 by increase
    $top50 = $diff | Sort-Object Change -Descending | Select-Object -First 50

    # Write header
    @(
        Center "Azure Cost Diff (Resource Level)"
        Center $sourceLabel
        Center $targetLabel
        ""
    ) | Out-File -FilePath $outFile -Encoding utf8

    # Write table (append)
    $top50 |
        Select-Object `
          Service,
          ResourceGrp,
          Location,
          @{n="Source";e={ "{0:N2} {1}" -f $_.Source, $currency }},
          @{n="Target";e={ "{0:N2} {1}" -f $_.Target, $currency }},
          @{n="Change";e={ "{0}{1:N2} {2}" -f ($(if ($_.Change -ge 0){"+"}else{""})), $_.Change, $currency }},
          @{n="New?";e={ if ($_.IsNew) { "YES" } else { "" } }},
          @{n="Name";e={ if ($_.Name.Length -gt 140) { $_.Name.Substring(0,140) + "…" } else { $_.Name } }} |
        Format-Table -AutoSize -Wrap |
        Out-String -Width 500 |
        Out-File -FilePath $outFile -Encoding utf8 -Append

        # ---- Append Summary (for all included items, not just top50) ----
        $srcTotal = ($diff | Measure-Object Source -Sum).Sum
        $tgtTotal = ($diff | Measure-Object Target -Sum).Sum
        $chgTotal = ($diff | Measure-Object Change   -Sum).Sum
"" | Out-File -FilePath $outFile -Encoding utf8 -Append
"Summary" | Out-File -FilePath $outFile -Encoding utf8 -Append
"-------" | Out-File -FilePath $outFile -Encoding utf8 -Append

@(
  [pscustomobject]@{
    Comparison = "TOTAL COSTS (new + increases)"
    Source     = ("{0:N2} {1}" -f $srcTotal, $currency)
    Target     = ("{0:N2} {1}" -f $tgtTotal, $currency)
    Change     = ("{0}{1:N2} {2}" -f ($(if ($chgTotal -ge 0){"+"}else{""})), $chgTotal, $currency)
  }
) |
  Format-Table -AutoSize |
  Out-String -Width 200 |
  Out-File -FilePath $outFile -Encoding utf8 -Append

Write-Information "Saved: $outFile"

# Detect and append anomalies to file
$anomalies = Detect-CostAnomalies -SourceData $sourceData -TargetData $targetData `
  -SourceMonthName $sourceMonthName -TargetMonthName $targetMonthName `
  -SignificantChangeThreshold $SignificantChangeThreshold -MinimumCostThreshold $MinimumCostThreshold
Append-AnomaliesToFile -Anomalies $anomalies -Currency $currency -OutFile $outFile `
  -SourceMonthName $sourceMonthName -TargetMonthName $targetMonthName

Write-Information "Anomalies appended to: $outFile"
}