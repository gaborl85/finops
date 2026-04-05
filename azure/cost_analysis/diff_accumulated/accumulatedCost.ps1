<#
.SYNOPSIS
    Compares accumulated costs between any two months across Azure subscriptions.

.DESCRIPTION
    This script retrieves accumulated cost data from Azure Cost Management for two months
    and generates a clean diff report. It processes all subscriptions automatically and
    strips ANSI escape codes for plain text output.

.PARAMETER SourceMonth
    Source month in YYYY-MM format (e.g., "2025-11"). Required.

.PARAMETER TargetMonth
    Target month in YYYY-MM format (e.g., "2025-12"). Required.

.EXAMPLE
    .\accumulatedCost.ps1 -SourceMonth "2025-11" -TargetMonth "2025-12"

.EXAMPLE
    .\accumulatedCost.ps1 -SourceMonth "2025-09" -TargetMonth "2025-10"

.NOTES
    Version: 2.0.0
    Requires: Azure CLI, Azure Cost CLI, PowerShell 5.1+
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$SourceMonth, # e.g., "2025-09"

    [Parameter(Mandatory=$true)]
    [string]$TargetMonth  # e.g., "2025-10"
)

# ---- Calculate date ranges
# Parse source month
try {
    $SourceDate = [datetime]::ParseExact($SourceMonth, "yyyy-MM", $null)
    $fromSource = $SourceDate.ToString("yyyy-MM-01")
    $toSource = $SourceDate.AddMonths(1).AddDays(-1).ToString("yyyy-MM-dd")
}
catch {
    Write-Error "Invalid SourceMonth format. Please use 'yyyy-MM'."
    exit 1
}

# Parse target month
try {
    $TargetDate = [datetime]::ParseExact($TargetMonth, "yyyy-MM", $null)
    $fromTarget = $TargetDate.ToString("yyyy-MM-01")
    $toTarget = $TargetDate.AddMonths(1).AddDays(-1).ToString("yyyy-MM-dd")
}
catch {
    Write-Error "Invalid TargetMonth format. Please use 'yyyy-MM'."
    exit 1
}

# ---- Create Dynamic Labels
# Generate month names for display
$SourceMonthName = $SourceDate.ToString("MMMM yyyy")
$TargetMonthName = $TargetDate.ToString("MMMM yyyy")

# Get all subscription IDs
$subs = az account list --query "[].[id,name]" -o tsv

foreach ($line in $subs) {
    $parts = $line.Trim() -split "`t"
    if ($parts.Count -lt 2) { continue }

    $id = $parts[0].Trim()
    $name = $parts[1].Trim()

    if (-not $id -or -not $name) { continue }

    Write-Host "`n=== Processing Subscription: $name ($id) ===`n"


    $sourceFile = "$SourceMonth-$name.json"
    $targetFile = "$TargetMonth-$name.json"
    $out = "diff_accumulatedCost-$name-$SourceMonth-vs-$TargetMonth.txt"

    # Source
    azure-cost accumulatedCost -s $id --timeframe Custom --from $fromSource --to $toSource -o json |
        Out-File $sourceFile -Encoding utf8
    if ($LASTEXITCODE -ne 0) { Write-Warning "Skipping $name ($id) - ($SourceMonthName export failed)"; continue }
    if (-not (Test-Path $sourceFile) -or (Get-Item $sourceFile).Length -eq 0) { Write-Warning "Skipping $name ($id) - ($SourceMonthName empty)"; continue }

    # Target
    azure-cost accumulatedCost -s $id --timeframe Custom --from $fromTarget --to $toTarget -o json |
        Out-File $targetFile -Encoding utf8
    if ($LASTEXITCODE -ne 0) { Write-Warning "Skipping $name ($id) - ($TargetMonthName export failed)"; continue }
    if (-not (Test-Path $targetFile) -or (Get-Item $targetFile).Length -eq 0) { Write-Warning "Skipping $name ($id) - ($TargetMonthName empty)"; continue }

    # Diff with ANSI codes
    $diffWithAnsi = azure-cost diff --compare-from $sourceFile --compare-to $targetFile

    # Strip ANSI escape codes using regex
    $ansiRegex = '\x1b\[[0-9;]*m'
    $cleanOutput = $diffWithAnsi -replace $ansiRegex, ''

    # Also replace box drawing characters for even cleaner output
    $cleanOutput = $cleanOutput -replace '┌|┬|┐|├|┼|┤|└|┴|┘|│|─|╭|╮|╰|╯', '|'

    # Write the clean output
    $cleanOutput | Out-File $out -Encoding utf8
    Write-Host "ANSI-stripped report saved to: $out"
}