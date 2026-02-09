# Azure Cost Analysis Module

PowerShell scripts for comprehensive Azure cost analysis, providing parameterized cost comparisons, anomaly detection, and detailed reporting across all Azure subscriptions.

## 🎯 Features

- 📊 **Parameterized Cost Comparisons**: Compare any two months using command-line parameters
- 💰 **Accumulated Cost Analysis**: Track total costs across time periods with ANSI-stripped output
- 🔍 **Resource-Level Analysis**: Detailed cost breakdown by individual Azure resources
- 🚨 **Anomaly Detection**: Automatically identify new costs, removed costs, and significant changes
- 📈 **Top 50 Cost Increases**: Focus on the most impactful cost changes
- 💵 **Multi-Currency Support**: Automatic currency detection and formatting
- 📄 **Subscription-Based Reports**: Individual reports per subscription with friendly names
- 🎨 **Clean Output**: ANSI escape codes and box-drawing characters stripped for readability
- 🔐 **Multi-Subscription Support**: Process all Azure subscriptions automatically

## 📋 Requirements

- PowerShell 5.1 or higher (PowerShell Core 7+ recommended)
- [Azure Cost CLI](https://github.com/mivano/azure-cost-cli) installed and configured
- Azure CLI (`az`) installed and authenticated
- Access to Azure subscriptions with Cost Management permissions
- Scripts fail fast if required CLIs are missing

## 🚀 Installation

1. Install Azure Cost CLI:
```bash
# Using dotnet tool
dotnet tool install -g azure-cost-cli

# Or download from releases
# https://github.com/mivano/azure-cost-cli/releases
```

2. Authenticate with Azure:
```bash
az login
```

3. Verify access to subscriptions:
```bash
az account list --output table
```

## 💻 Usage

### Accumulated Cost Analysis

Compare accumulated costs between any two months across all subscriptions:

```powershell
# Navigate to the script directory
cd diff_accumulated

# Compare costs between two months
.\accumulatedCost.ps1 -SourceMonth "2025-11" -TargetMonth "2025-12" -WhatIf
```
*Use `-WhatIf`/`-Confirm` for safe previews.*

**Parameters:**
- `-SourceMonth`: Source month in `YYYY-MM` format (e.g., "2025-11") - **Required**
- `-TargetMonth`: Target month in `YYYY-MM` format (e.g., "2025-12") - **Required**

**Output Files:**
- `YYYY-MM-SubscriptionName.json` - Raw cost data for each subscription
- `diff_accumulatedCost-SubscriptionName-YYYY-MM-vs-YYYY-MM.txt` - Clean diff report

**Example:**
```powershell
.\accumulatedCost.ps1 -SourceMonth "2025-09" -TargetMonth "2025-10"
```

### Resource-Level Cost Analysis

Analyze costs at the resource level with anomaly detection:

```powershell
# Navigate to the script directory
cd diff_resource

# Compare resource costs between two months
.\diff_costByResource.ps1 -SourceMonth "2025-11" -TargetMonth "2025-12" -WhatIf
```
*Use `-WhatIf`/`-Confirm` for safe previews.*

# With custom thresholds
.\diff_costByResource.ps1 -SourceMonth "2025-11" -TargetMonth "2025-12" `
    -SignificantChangeThreshold 0.3 `
    -MinimumCostThreshold 5.0
```

**Parameters:**
- `-SourceMonth`: Source month in `YYYY-MM` format - **Required**
- `-TargetMonth`: Target month in `YYYY-MM` format - **Required**
- `-SignificantChangeThreshold`: Percentage threshold for significant changes (default: 0.5 = 50%) - *Optional*
- `-MinimumCostThreshold`: Minimum cost in currency units to consider (default: 1.0) - *Optional*

**Output Files:**
- `YYYY-MM-resources-SubscriptionName.json` - Raw resource cost data
- `diff-resources-top50-SubscriptionName.txt` - Top 50 cost increases with anomalies

**Example:**
```powershell
# More sensitive detection (30% threshold, 5 EUR minimum)
.\diff_costByResource.ps1 -SourceMonth "2025-11" -TargetMonth "2025-12" `
    -SignificantChangeThreshold 0.3 `
    -MinimumCostThreshold 5.0
```

## 📊 Output Report Structure

### Accumulated Cost Reports

Clean, ANSI-stripped diff reports showing:
- Total cost comparison between source and target months
- Cost breakdown by service
- Absolute and percentage changes
- Easy-to-read plain text format

**Example Output:**
```
Azure Cost Diff (Accumulated)
Source: (2025-11-01 to 2025-11-30)
Target: (2025-12-01 to 2025-12-31)

| TOTAL COSTS | 9,499.42 EUR | 1,620.68 EUR | -7,878.74 EUR |
| Service A   | 5,234.12 EUR | 1,123.45 EUR | -4,110.67 EUR |
| Service B   | 4,265.30 EUR |   497.23 EUR | -3,768.07 EUR |
```

### Resource-Level Reports

Comprehensive reports including:

#### 1. Top 50 Cost Increases
Table showing resources with the highest cost increases:
- Service name
- Resource group
- Location
- Source month cost
- Target month cost
- Change amount
- "New?" indicator for newly created resources
- Full resource name/path

#### 2. Summary Section
- Total costs for new resources and increases
- Aggregate change metrics

#### 3. Detected Anomalies

**💰 New Costs Detected:**
- Resources that appeared in the target month
- Sorted by cost impact
- Useful for identifying new deployments or services

**💸 Costs Removed:**
- Resources that disappeared in the target month
- Potential cost savings or decommissioned resources
- Helps track cleanup efforts

**📊 Significant Cost Changes:**
- Resources exceeding the change threshold
- Both increases and decreases
- Percentage change calculations
- Helps identify scaling events or configuration changes

**Example Output:**
```
                    Azure Cost Diff (Resource Level)
                    Source: (2025-11-01 to 2025-11-30)
                    Target: (2025-12-01 to 2025-12-31)

Service          ResourceGrp    Location    Source         Target         Change         New?  Name
-------          -----------    --------    ------         ------         ------         ----  ----
Virtual Machines rg-prod-01     westeurope  1,234.56 EUR   2,345.67 EUR   +1,111.11 EUR       vm-prod-web-01
Storage          rg-storage     eastus      0.00 EUR       567.89 EUR     +567.89 EUR    YES  storageaccount123

Summary
-------
Comparison                          Source           Target           Change
----------                          ------           ------           ------
TOTAL COSTS (new + increases)       1,234.56 EUR     2,913.56 EUR     +1,679.00 EUR

=== DETECTED ANOMALIES ===

💰 NEW COSTS DETECTED:
Resource                Service    Resource Group  Location   November 2025  December 2025  Change
--------                -------    --------------  --------   -------------  -------------  ------
storageaccount123       Storage    rg-storage      eastus     0.00 EUR       567.89 EUR     +567.89 EUR

📊 SIGNIFICANT COST CHANGES:
Resource                Service            Resource Group  Location    November 2025  December 2025  Change          Percent
--------                -------            --------------  --------    -------------  -------------  ------          -------
vm-prod-web-01          Virtual Machines   rg-prod-01      westeurope  1,234.56 EUR   2,345.67 EUR   +1,111.11 EUR  +90.00%

Total anomalies detected: 2
```

## 📁 Directory Structure

```
cost_analysis/
├── README.md                          # This file
├── requirements.txt                   # Dependencies (if needed)
├── diff_accumulated/
│   └── accumulatedCost.ps1           # Accumulated cost comparison script
└── diff_resource/
    └── diff_costByResource.ps1       # Resource-level analysis script
```

## 📝 Script Details

### accumulatedCost.ps1

**Purpose:** Compare total accumulated costs between two months with clean output

**Key Features:**
- Parameterized date ranges (no hardcoded months)
- Dynamic output file naming with subscription names
- ANSI escape code stripping for clean text output
- Box-drawing character replacement
- Error handling for invalid date formats
- Processes all subscriptions automatically

**How it works:**
1. Parses source and target month parameters
2. Validates date formats and calculates first/last day of each month
3. Retrieves all Azure subscriptions (ID and name)
4. For each subscription:
   - Exports accumulated cost data as JSON using azure-cost CLI
   - Runs diff comparison between the two months
   - Strips ANSI codes and formatting characters
   - Saves clean report to text file with subscription name

**Technical Details:**
- Uses `[datetime]::ParseExact()` for date validation
- Leverages `azure-cost accumulatedCost` command
- Regex-based ANSI code stripping: `\x1b\[[0-9;]*m`
- Box-drawing character replacement for plain text compatibility

### diff_costByResource.ps1

**Purpose:** Detailed resource-level cost analysis with anomaly detection

**Key Features:**
- Parameterized date ranges and thresholds
- Composite key handling for non-resource items (refunds, purchases, reservations)
- Top 50 cost increases focus
- Automatic anomaly detection with three categories
- Configurable sensitivity thresholds
- Summary statistics and totals
- Handles empty ResourceId rows gracefully

**How it works:**
1. Parses parameters and validates date formats with try-catch blocks
2. Retrieves all Azure subscriptions with names using tab-separated output
3. For each subscription:
   - Exports resource-level cost data for both months as JSON
   - Builds cost maps using composite keys (ResourceId or fallback key)
   - Identifies resources with cost increases (change > 0)
   - Sorts by change amount and selects top 50
   - Detects anomalies in three categories
   - Generates formatted report with tables
   - Appends anomaly analysis sections

**Technical Details:**
- Composite key function handles missing ResourceId fields
- Uses hashtables for efficient cost lookups
- Anomaly detection logic:
  - **New Cost**: `sourceCost == 0 && targetCost >= threshold`
  - **Removed Cost**: `sourceCost >= threshold && targetCost == 0`
  - **Significant Change**: `percentChange >= threshold && both costs >= minimum`
- Resource display name extraction from Azure Resource IDs
- Centered header formatting function
- Format-Table with custom column expressions

## 🔧 Configuration

### Default Settings

**accumulatedCost.ps1:**
- Output format: Clean text (ANSI-stripped)
- File naming: Uses subscription names
- Date format: YYYY-MM
- Encoding: UTF-8

**diff_costByResource.ps1:**
- Significant change threshold: 50% (0.5)
- Minimum cost threshold: 1.0 (currency units)
- Top results shown: 50 resources
- Anomaly categories: New costs, removed costs, significant changes
- Encoding: UTF-8
- Table width: 500 characters

### Customization Examples

#### More Sensitive Anomaly Detection
```powershell
# Detect 30% changes, minimum 5 EUR
.\diff_costByResource.ps1 -SourceMonth "2025-11" -TargetMonth "2025-12" `
    -SignificantChangeThreshold 0.3 `
    -MinimumCostThreshold 5.0
```

#### Less Sensitive (Major Changes Only)
```powershell
# Detect 100% changes (doubling), minimum 10 EUR
.\diff_costByResource.ps1 -SourceMonth "2025-11" -TargetMonth "2025-12" `
    -SignificantChangeThreshold 1.0 `
    -MinimumCostThreshold 10.0
```

#### Very Sensitive (Catch Everything)
```powershell
# Detect 10% changes, minimum 0.50 EUR
.\diff_costByResource.ps1 -SourceMonth "2025-11" -TargetMonth "2025-12" `
    -SignificantChangeThreshold 0.1 `
    -MinimumCostThreshold 0.5
```

## 🎯 Use Cases

### Monthly Cost Reviews
Run both scripts at the end of each month to:
- Compare total costs month-over-month
- Identify which resources drove cost changes
- Detect unexpected new costs

### Budget Monitoring
Use resource-level analysis to:
- Track spending by resource group
- Identify cost overruns early
- Validate cost allocation

### Anomaly Investigation
When costs spike unexpectedly:
- Run resource analysis with sensitive thresholds
- Review "New Costs" section for unexpected deployments
- Check "Significant Changes" for scaling events

### Cost Optimization
Regularly review reports to:
- Find resources with removed costs (successful optimization)
- Identify candidates for rightsizing
- Track impact of optimization efforts

### Chargeback/Showback
Generate reports for:
- Team-specific cost allocation
- Project cost tracking
- Department budget management

## 🐛 Troubleshooting

### Common Issues

**Issue:** "Invalid SourceMonth format" error
- **Solution:** Ensure date format is exactly `YYYY-MM` (e.g., "2025-11", not "2025-11-01")

**Issue:** "azure-cost: command not found"
- **Solution:** Install Azure Cost CLI: `dotnet tool install -g azure-cost-cli`

**Issue:** Empty or missing output files
- **Solution:** Check Azure CLI authentication: `az account show`
- Verify Cost Management permissions on subscriptions

**Issue:** Script skips subscriptions
- **Solution:** Check warning messages for specific errors
- Verify subscription has cost data for the specified months

**Issue:** Anomaly detection too sensitive/not sensitive enough
- **Solution:** Adjust `-SignificantChangeThreshold` and `-MinimumCostThreshold` parameters

### Debug Tips

1. **Test with single subscription:**
   ```powershell
   # Modify script to process only one subscription for testing
   ```

2. **Check raw JSON output:**
   ```powershell
   # Examine the generated JSON files to verify data
   Get-Content "2025-11-SubscriptionName.json" | ConvertFrom-Json
   ```

3. **Verify date calculations:**
   ```powershell
   # Test date parsing
   [datetime]::ParseExact("2025-11", "yyyy-MM", $null)
   ```

## 🤝 Contributing

Contributions to improve the Azure Cost Analysis module are welcome!

### Ideas for Contributions
- Add support for custom date ranges (not just full months)
- Implement cost forecasting based on trends
- Add export to CSV or Excel formats
- Create visualization/charting capabilities
- Add support for Azure Reservations analysis
- Implement budget threshold alerting

### Contribution Guidelines
1. Test with multiple subscriptions
2. Handle edge cases (empty data, missing fields)
3. Follow PowerShell best practices
4. Update documentation
5. Add examples for new features

## 📚 Additional Resources

- [Azure Cost Management Documentation](https://docs.microsoft.com/azure/cost-management-billing/)
- [Azure Cost CLI GitHub](https://github.com/mivano/azure-cost-cli)
- [Azure CLI Cost Management Commands](https://docs.microsoft.com/cli/azure/costmanagement)
- [FinOps Foundation](https://www.finops.org/)

## 🔄 Version History

See [../../CHANGELOG.md](../../CHANGELOG.md) for detailed version history and migration guides.

**Current Version:** v2.0.0 (2026-01-13)

## 📄 License

MIT License - See main project [LICENSE](../../LICENSE) file for details.

---

**Part of the [FinOps PowerShell Toolkit](../../README.md)**
