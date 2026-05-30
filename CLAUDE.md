# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**FinOps Toolkit** is a modular collection of PowerShell scripts for cloud financial operations and cost management. The toolkit helps organizations optimize cloud spending, detect cost anomalies, and maintain financial governance across cloud platforms.

**Current Modules:**
- Azure Cost Analysis: Scripts for analyzing and comparing Azure costs with anomaly detection

**Planned Modules:** AWS, GCP, Budget management, Tagging governance, Reservation optimization

## Repository Structure

```
finops/
├── README.md                          # Project portfolio overview
├── CHANGELOG.md                       # Version history and migration guides
├── LICENSE                            # MIT License
├── azure/
│   └── cost_analysis/
│       ├── README.md                  # Module documentation
│       ├── requirements.txt           # Setup and tool requirements
│       ├── CHANGELOG.md               # Module-specific changelog
│       ├── diff_accumulated/
│       │   └── accumulatedCost.ps1   # Compare total costs between two months
│       └── diff_resource/
│           └── diff_costByResource.ps1 # Resource-level cost analysis with anomaly detection
```

## Core Technologies

- **Language**: PowerShell (5.1+, Core 7+ recommended)
- **External Tools**:
  - Azure CLI (`az`) - Azure authentication and subscription management
  - Azure Cost CLI (`azure-cost`) - Queries cost data from Azure Cost Management
- **Output Format**: Plain text (ANSI-stripped), JSON intermediate files

## Key Scripts

### accumulatedCost.ps1 (azure/cost_analysis/diff_accumulated/)

**Purpose:** Compare accumulated costs between two months across all Azure subscriptions.

**Usage:**
```powershell
.\accumulatedCost.ps1 -SourceMonth "2025-11" -TargetMonth "2025-12"
```

**Key Features:**
- Parameterized date ranges (YYYY-MM format)
- ANSI code and box-drawing character stripping for clean text output
- Dynamic output file naming using subscription names
- Automatic subscription iteration
- Error handling for invalid date formats

**Output Files:**
- `YYYY-MM-SubscriptionName.json` - Raw cost data
- `diff_accumulatedCost-SubscriptionName-YYYY-MM-vs-YYYY-MM.txt` - Clean diff report

### diff_costByResource.ps1 (azure/cost_analysis/diff_resource/)

**Purpose:** Detailed resource-level cost analysis with automated anomaly detection.

**Usage:**
```powershell
# Basic usage
.\diff_costByResource.ps1 -SourceMonth "2025-11" -TargetMonth "2025-12"

# With custom thresholds
.\diff_costByResource.ps1 -SourceMonth "2025-11" -TargetMonth "2025-12" `
    -SignificantChangeThreshold 0.3 `
    -MinimumCostThreshold 5.0
```

**Parameters:**
- `-SourceMonth`: Source month (YYYY-MM format) - Required
- `-TargetMonth`: Target month (YYYY-MM format) - Required
- `-SignificantChangeThreshold`: Change percentage for anomalies (default: 0.5 = 50%)
- `-MinimumCostThreshold`: Minimum cost to consider in currency units (default: 1.0)

**Key Features:**
- Top 50 cost increases focus
- Three-category anomaly detection: new costs, removed costs, significant changes
- Composite key handling for non-resource items (refunds, reservations)
- Formatted tables with centered headers
- Currency-aware output

**Output Files:**
- `YYYY-MM-resources-SubscriptionName.json` - Raw resource cost data
- `diff-resources-top50-SubscriptionName.txt` - Formatted report with anomalies

## Development Workflow

### Common Commands

**Testing a script locally:**
```powershell
# Navigate to script directory
cd azure/cost_analysis/diff_accumulated

# Run with test parameters
.\accumulatedCost.ps1 -SourceMonth "2025-11" -TargetMonth "2025-12"

# Check output
ls -la *.txt  # View generated reports
```

**Verifying prerequisites:**
```powershell
# Check Azure CLI
az --version

# Check Azure Cost CLI
azure-cost --version

# Check PowerShell version
$PSVersionTable.PSVersion

# Verify Azure authentication
az account list --output table
```

### Code Style & Patterns

- **Parameter Names**: PascalCase (e.g., `$SourceMonth`, `$TargetMonth`)
- **Variables**: PascalCase for consistency
- **Error Handling**: Use try-catch blocks for user input validation (date parsing)
- **Output**: UTF-8 encoding
- **Comments**: Minimal - only explain non-obvious logic (regex patterns, composite keys)
- **Date Format**: Always `YYYY-MM` for month parameters; use `[datetime]::ParseExact()` for validation

### Key Implementation Details

**Composite Keys for Resources:**
The diff_costByResource script handles resources without explicit ResourceId fields (refunds, purchases, etc.) by creating composite keys from available fields:
```powershell
function Get-CompositeKey {
    if (-not [string]::IsNullOrWhiteSpace($item.ResourceId)) {
        return $item.ResourceId
    }
    return "$($item.ChargeType)|$($item.Service)|$($item.Description)"
}
```

**ANSI Code Stripping:**
Used to clean Azure CLI output for plain text compatibility:
```powershell
$cleanReport = $report -replace '\x1b\[[0-9;]*m', ''  # Remove ANSI codes
$cleanReport = $cleanReport -replace '[└│─├]', '-'  # Replace box-drawing
```

**Anomaly Detection Logic:**
- **New Cost**: `sourceCost == 0 && targetCost >= MinimumCostThreshold`
- **Removed Cost**: `sourceCost >= MinimumCostThreshold && targetCost == 0`
- **Significant Change**: `percentChange >= SignificantChangeThreshold && both costs >= MinimumCostThreshold`

## Versioning & Changelog

This project uses Semantic Versioning (MAJOR.MINOR.PATCH). When making changes:

1. Update `CHANGELOG.md` under `[Unreleased]` section with categories: Added, Changed, Fixed, Deprecated, Removed, Security
2. For breaking changes, include migration notes
3. When releasing, move unreleased changes to a dated version section
4. Update version numbers in script headers (e.g., `Version: 2.0.0`)

## File Naming Conventions

**Output Files:**
- `YYYY-MM-SubscriptionName.json` - Month-based accumulated cost data
- `YYYY-MM-resources-SubscriptionName.json` - Month-based resource cost data
- `diff_accumulatedCost-SubscriptionName-YYYY-MM-vs-YYYY-MM.txt` - Accumulated diff report
- `diff-resources-top50-SubscriptionName.txt` - Resource analysis report

**Script Files:**
- Use PascalCase with clear intent: `accumulatedCost.ps1`, `diff_costByResource.ps1`

## Important Constraints & Dependencies

1. **Azure Prerequisites**: All scripts require Azure CLI authentication (`az login`) and Azure Cost CLI installation
2. **Date Format**: Month parameters must be exactly `YYYY-MM` - no other formats supported
3. **Subscription Access**: Scripts require Cost Management Reader role on subscriptions
4. **PowerShell Version**: Core 7+ recommended, 5.1 minimum (Windows-only features not used)
5. **Encoding**: Always UTF-8 for output files to support international currencies and characters

## References

- [Azure Cost CLI GitHub](https://github.com/mivano/azure-cost-cli)
- [Azure Cost Management Docs](https://docs.microsoft.com/azure/cost-management-billing/)
- [FinOps Foundation](https://www.finops.org/)
- Main README: Architecture, use cases, and project roadmap
- CHANGELOG.md: Version history and migration guides between releases
