# Changelog

All notable changes to the FinOps PowerShell Toolkit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Kilo configuration file (`.kilo/kilo.jsonc`) for AI assistant integration
- Kilo documentation update instructions (`.kilo/instructions/update-docs-on-code-change.md`)

### Planned
- AWS cost analysis module
- GCP cost analysis module
- Budget alerting tools
- Cost forecasting capabilities
- Cross-cloud cost aggregation
- Tagging governance tools
- Reservation optimization analyzer

## [2.0.0] - 2026-01-13

### Added
- Modular project structure with separate modules for different cloud providers
- Main project README as portfolio overview
- Module-specific README for Azure Cost Analysis
- CHANGELOG.md for version history tracking
- Comprehensive documentation with examples and troubleshooting

### Changed
- **BREAKING**: Restructured repository into modular format
  - Moved scripts to `azure/cost_analysis/` directory structure
  - Separated accumulated and resource analysis into subdirectories
- **BREAKING**: Parameterized all date ranges (removed hardcoded months)
  - `accumulatedCost.ps1` now requires `-SourceMonth` and `-TargetMonth` parameters
  - `diff_costByResource.ps1` now requires `-SourceMonth` and `-TargetMonth` parameters
- Updated file naming to use subscription names instead of IDs
- Improved error handling with try-catch blocks for date parsing
- Enhanced variable naming consistency (PascalCase throughout)
- Updated month name display to include year (e.g., "November 2025")

### Fixed
- String splitting for subscription ID and name extraction
- Array bounds checking when parsing subscription data
- Indentation in try-catch blocks for better readability
- Error messages now reference correct parameter names

### Improved
- `accumulatedCost.ps1`:
  - ANSI escape code stripping for clean text output
  - Box-drawing character replacement
  - Dynamic output file naming
  - Better error messages with parameter names
  
- `diff_costByResource.ps1`:
  - Anomaly detection with three categories (new, removed, significant changes)
  - Configurable thresholds for sensitivity
  - Top 50 cost increases focus
  - Composite key handling for non-resource items
  - Summary statistics and totals
  - Formatted anomaly reports with emojis

## [1.0.0] - 2026-01-6
### Initial Release 

### Added
- Initial release of Azure cost comparison scripts
- Basic accumulated cost comparison functionality
- Basic resource-level cost comparison
- Support for multiple Azure subscriptions
- JSON output from Azure Cost CLI
- Diff comparison capabilities

### Features
- Hardcoded date ranges for specific month comparisons
- ANSI-formatted output
- Subscription ID-based file naming
- Basic cost aggregation

---

## Version History Summary

| Version | Date       | Key Changes |
|---------|------------|-------------|
| 2.0.0   | 2026-01-13 | Modular structure, parameterized scripts, anomaly detection |
| 1.0.0   | 2026-01-06 | Initial release with basic cost comparison |

## Migration Guide

### Upgrading from 1.0.0 to 2.0.0

#### File Location Changes
```bash
# Old structure
finops/
├── diff_accumulated_stripped_nov_dec.ps1
├── diff_resource_nov_dec.ps1
└── ...

# New structure
finops/
└── azure/
    └── cost_analysis/
        ├── diff_accumulated/
        │   └── accumulatedCost.ps1
        └── diff_resource/
            └── diff_costByResource.ps1
```

#### Script Usage Changes

**Old (v1.0.0):**
```powershell
# Hardcoded months in script
.\diff_accumulated_stripped_nov_dec.ps1
```

**New (v2.0.0):**
```powershell
# Parameterized - specify any months
.\accumulatedCost.ps1 -SourceMonth "2025-11" -TargetMonth "2025-12"
```

#### Output File Changes

**Old naming:**
- `november-<subscription-id>.json`
- `diff_accumulatedCost-<subscription-id>-stripped.txt`

**New naming:**
- `2025-11-SubscriptionName.json`
- `diff_accumulatedCost-SubscriptionName-2025-11-vs-2025-12.txt`

#### New Features to Leverage

1. **Anomaly Detection** (resource analysis):
   ```powershell
   .\diff_costByResource.ps1 -SourceMonth "2025-11" -TargetMonth "2025-12"
   # Check the anomalies section in the output
   ```

2. **Custom Thresholds**:
   ```powershell
   .\diff_costByResource.ps1 -SourceMonth "2025-11" -TargetMonth "2025-12" `
       -SignificantChangeThreshold 0.3 `
       -MinimumCostThreshold 5.0
   ```

3. **Subscription Names**:
   - Output files now use friendly subscription names
   - Easier to identify and organize reports

## Contributing

When adding entries to this changelog:
1. Add unreleased changes under `[Unreleased]` section
2. Use categories: Added, Changed, Deprecated, Removed, Fixed, Security
3. Include migration notes for breaking changes
4. Update version history summary table
5. Follow [Keep a Changelog](https://keepachangelog.com/) format
