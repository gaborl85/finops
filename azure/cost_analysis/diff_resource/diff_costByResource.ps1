<#
.SYNOPSIS
    Analyzes resource-level costs with anomaly detection across Azure subscriptions.

.DESCRIPTION
    This script compares resource-level costs between two months, identifies anomalies
    (new costs, removed costs, significant changes), and generates detailed reports
    with the top 50 cost increases. Handles resources without ResourceId (refunds, 
    reservations, purchases) using composite keys.

.PARAMETER SourceMonth
    Source month in YYYY-MM format (e.g., "2025-11"). Required.

.PARAMETER TargetMonth
    Target month in YYYY-MM format (e.g., "2025-12"). Required.

.PARAMETER SignificantChangeThreshold
    Percentage threshold for significant changes (default: 0.5 = 50%). Optional.

.PARAMETER MinimumCostThreshold
    Minimum cost in currency units to consider for anomaly detection (default: 1.0). Optional.

.EXAMPLE
    .\diff_costByResource.ps1 -SourceMonth "2025-11" -TargetMonth "2025-12"

.EXAMPLE
    # More sensitive detection (30% threshold, 5 EUR minimum)
    .\diff_costByResource.ps1 -SourceMonth "2025-11" -TargetMonth "2025-12" `
        -SignificantChangeThreshold 0.3 `
        -MinimumCostThreshold 5.0

.NOTES
    Version: 2.0.0
    Requires: Azure CLI, Azure Cost CLI, PowerShell 5.1+
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$SourceMonth, # e.g., "2025-09"

    [Parameter(Mandatory=$true)]
    [string]$TargetMonth,  # e.g., "2025-10"
    
    [Parameter(Mandatory=$false)]
    [double]$SignificantChangeThreshold = 0.5,
    
    [Parameter(Mandatory=$false)]
    [double]$MinimumCostThreshold = 1.0
)

# ---- Calculate date ranges ----
# Parse source month
try {
    $sourceDate = [datetime]::ParseExact($SourceMonth, "yyyy-MM", $null)
    $fromSource = $sourceDate.ToString("yyyy-MM-01")
    $toSource = $sourceDate.AddMonths(1).AddDays(-1).ToString("yyyy-MM-dd")
    $sourceMonthName = $sourceDate.ToString("MMMM yyyy")
} catch {
    Write-Error "Invalid SourceMonth format. Use YYYY-MM (e.g., 2025-11)"
    exit 1
}

# Parse target month
try {
    $targetDate = [datetime]::ParseExact($TargetMonth, "yyyy-MM", $null)
    $fromTarget = $targetDate.ToString("yyyy-MM-01")
    $toTarget = $targetDate.AddMonths(1).AddDays(-1).ToString("yyyy-MM-dd")
    $targetMonthName = $targetDate.ToString("MMMM yyyy")
} catch {
    Write-Error "Invalid TargetMonth format. Use YYYY-MM (e.g., 2025-12)"
    exit 1
}

# Create labels for output
$sourceLabel = "Source: ($fromSource to $toSource)"
$targetLabel = "Target: ($fromTarget to $toTarget)"

# ---- Helper Functions ----
function ItemKey($r) {
  # Prefer ResourceId if available
  if (-not [string]::IsNullOrWhiteSpace($r.ResourceId)) { return $r.ResourceId }

  # Fallback key for non-resource lines (refunds/purchases/reservations/etc.)
  "{0}|{1}|{2}|{3}|{4}|{5}" -f `
    $r.ChargeType, $r.ServiceName, $r.ServiceTier, $r.Meter, $r.ResourceLocation, $r.ResourceGroupName
}

function ItemName($r) {
  if (-not [string]::IsNullOrWhiteSpace($r.ResourceId)) { return $r.ResourceId }

  $parts = @()
  if ($r.ChargeType) { $parts += $r.ChargeType }
  if ($r.ServiceName) { $parts += $r.ServiceName }
  if ($r.Meter) { $parts += $r.Meter }
  if ($r.ResourceLocation) { $parts += $r.ResourceLocation }
  ($parts -join " • ")
}

function ResourceDisplayName($r) {
  if ([string]::IsNullOrWhiteSpace($r.ResourceId)) {
    return (ItemName $r)
  }

  $parts = $r.ResourceId.Trim('/') -split '/'

  # Everything after "providers/<provider>"
  $providerIndex = [Array]::IndexOf($parts, 'providers')
  if ($providerIndex -ge 0 -and $providerIndex + 2 -lt $parts.Length) {
    return ($parts[($providerIndex + 2)..($parts.Length - 1)] -join '/')
  }

  # Fallback: last segment
  return $parts[-1]
}

function Center([string]$text, [int]$width = 90) {
  if ([string]::IsNullOrEmpty($text)) { return "" }
  if ($text.Length -ge $width) { return $text }
  $pad = [math]::Floor(($width - $text.Length) / 2)
  (" " * $pad) + $text
}

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
        $sourceCost = [double]($sourceMap[$k] ?? 0)
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
$subs = az account list --query "[].[id,name]" -o tsv

foreach ($line in $subs) {
  $parts = $line.Trim() -split "`t"
  if ($parts.Count -lt 2) { continue }
  
  $id = $parts[0].Trim()
  $name = $parts[1].Trim()
  
  if (-not $id -or -not $name) { continue }

  Write-Host "`n=== Subscription: $name ($id) ==="

  $sourceFile = "$($SourceMonth)-resources-$name.json"
  $targetFile = "$($TargetMonth)-resources-$name.json"
  $outFile = "diff-resources-top50-$name.txt"

  # Export source month
  azure-cost costByResource -s $id --timeframe Custom --from $fromSource --to $toSource -o json |
    Out-File $sourceFile -Encoding utf8
  if ($LASTEXITCODE -ne 0) { Write-Warning "Skipping $id (Nov export failed)"; continue }
  if (-not (Test-Path $sourceFile) -or (Get-Item $sourceFile).Length -eq 0) { Write-Warning "Skipping $id (Nov empty)"; continue }

  # Export target month
  azure-cost costByResource -s $id --timeframe Custom --from $fromTarget --to $toTarget -o json |
    Out-File $targetFile -Encoding utf8
  if ($LASTEXITCODE -ne 0) { Write-Warning "Skipping $id (Dec export failed)"; continue }
  if (-not (Test-Path $targetFile) -or (Get-Item $targetFile).Length -eq 0) { Write-Warning "Skipping $id (Dec empty)"; continue }

  # Load JSON
  $sourceData = Get-Content $sourceFile -Raw | ConvertFrom-Json
  $targetData = Get-Content $targetFile -Raw | ConvertFrom-Json

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

  # Build diff rows (one row per key): include new + increased (Change > 0)
  $diff = foreach ($k in $targetMap.Keys) {
    $targetCost = [double]$targetMap[$k]
    $sourceCost = [double]($sourceMap[$k] ?? 0)
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
  ) | Out-File $outFile -Encoding utf8

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
    Out-File $outFile -Encoding utf8 -Append

    # ---- Append Summary (for all included items, not just top50) ----
    $srcTotal = ($diff | Measure-Object Source -Sum).Sum
    $tgtTotal = ($diff | Measure-Object Target -Sum).Sum
    $chgTotal = ($diff | Measure-Object Change   -Sum).Sum
"" | Out-File $outFile -Encoding utf8 -Append
"Summary" | Out-File $outFile -Encoding utf8 -Append
"-------" | Out-File $outFile -Encoding utf8 -Append

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
  Out-File $outFile -Encoding utf8 -Append

Write-Host "Saved: $outFile"

# Detect and append anomalies to file
$anomalies = Detect-CostAnomalies -SourceData $sourceData -TargetData $targetData `
  -SourceMonthName $sourceMonthName -TargetMonthName $targetMonthName `
  -SignificantChangeThreshold $SignificantChangeThreshold -MinimumCostThreshold $MinimumCostThreshold
Append-AnomaliesToFile -Anomalies $anomalies -Currency $currency -OutFile $outFile `
  -SourceMonthName $sourceMonthName -TargetMonthName $targetMonthName

Write-Host "Anomalies appended to: $outFile"
}