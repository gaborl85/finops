<#
.SYNOPSIS
Compares accumulated Azure costs between two months and writes a cleaned diff report per subscription.

.DESCRIPTION
Exports accumulated cost for the source and target months per subscription, runs a diff, strips ANSI
escape codes and box characters, and writes a clean text report.

.PARAMETER SourceMonth
Source month in yyyy-MM format.

.PARAMETER TargetMonth
Target month in yyyy-MM format.

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
    [string]$TargetMonth
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
            [System.FormatException]::new("Invalid $Label format. Please use 'yyyy-MM'."),
            'InvalidMonthFormat',
            [System.Management.Automation.ErrorCategory]::InvalidData,
            $Month
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }
}

$sourceInfo = Get-MonthRange -Month $SourceMonth -Label 'SourceMonth'
$targetInfo = Get-MonthRange -Month $TargetMonth -Label 'TargetMonth'

$SourceDate = $sourceInfo.Date
$TargetDate = $targetInfo.Date
$fromSource = $sourceInfo.From
$toSource = $sourceInfo.To
$fromTarget = $targetInfo.From
$toTarget = $targetInfo.To
$SourceMonthName = $sourceInfo.Display
$TargetMonthName = $targetInfo.Display

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

foreach ($line in $subs) {
    $parts = $line.Trim() -split "`t"
    if ($parts.Count -lt 2) { continue }

    $id = $parts[0].Trim()
    $name = $parts[1].Trim()

    if (-not $id -or -not $name) { continue }

    $safeName = $name -replace '[\\/:*?"<>|]', '_'
    $sourceFile = "$SourceMonth-$safeName.json"
    $targetFile = "$TargetMonth-$safeName.json"
    $out = "diff_accumulatedCost-$safeName-$SourceMonth-vs-$TargetMonth.txt"

    Write-Verbose "Processing subscription: $name ($id)"

    if ($PSCmdlet.ShouldProcess($sourceFile, "Export accumulated cost for $SourceMonthName ($name)")) {
        azure-cost accumulatedCost -s $id --timeframe Custom --from $fromSource --to $toSource -o json |
            Out-File -FilePath $sourceFile -Encoding utf8
        if ($LASTEXITCODE -ne 0) { Write-Warning "Skipping $name ($id) - ($SourceMonthName export failed)"; continue }
        if (-not (Test-Path -LiteralPath $sourceFile) -or (Get-Item -LiteralPath $sourceFile).Length -eq 0) { Write-Warning "Skipping $name ($id) - ($SourceMonthName empty)"; continue }
    }

    if ($PSCmdlet.ShouldProcess($targetFile, "Export accumulated cost for $TargetMonthName ($name)")) {
        azure-cost accumulatedCost -s $id --timeframe Custom --from $fromTarget --to $toTarget -o json |
            Out-File -FilePath $targetFile -Encoding utf8
        if ($LASTEXITCODE -ne 0) { Write-Warning "Skipping $name ($id) - ($TargetMonthName export failed)"; continue }
        if (-not (Test-Path -LiteralPath $targetFile) -or (Get-Item -LiteralPath $targetFile).Length -eq 0) { Write-Warning "Skipping $name ($id) - ($TargetMonthName empty)"; continue }
    }

    $diffWithAnsi = azure-cost diff --compare-from $sourceFile --compare-to $targetFile
    if ($LASTEXITCODE -ne 0) { Write-Warning "Skipping $name ($id) - diff failed"; continue }

    $ansiRegex = '\x1b\[[0-9;]*m'
    $cleanOutput = $diffWithAnsi -replace $ansiRegex, ''
    $cleanOutput = $cleanOutput -replace '┌|┬|┐|├|┼|┤|└|┴|┘|│|─|╭|╮|╰|╯', '|'

    if ($PSCmdlet.ShouldProcess($out, "Write report for $name")) {
        $cleanOutput | Out-File -FilePath $out -Encoding utf8
        Write-Information "Report saved to: $out"
    }
}