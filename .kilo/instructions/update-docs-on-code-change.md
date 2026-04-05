# Update Documentation on Code Change (FinOps)

## Overview

Ensure documentation stays synchronized with code changes for the FinOps PowerShell Toolkit.

## When to Update Documentation

### Trigger Conditions

Automatically check if documentation updates are needed when:

- New scripts or modules are added
- Script parameters or interfaces change
- Dependencies change (e.g., new CLI tools required)
- Configuration options are modified
- Installation or setup procedures change
- Cloud provider support changes

## Documentation Update Rules

### README.md Updates

**Always update README.md when:**

- Adding new cloud provider modules (Azure, AWS, GCP)
- Adding new scripts or tools
- Modifying installation or setup process
- Changing prerequisites or dependencies
- Adding new CLI commands or options
- Changing configuration options

### Module Documentation Updates

**Sync module READMEs when:**

- New scripts are added to a module
- Script parameters change
- Output format changes
- Error handling is modified

### Changelog Management

**Add changelog entries for:**

- New features (under "Added")
- Bug fixes (under "Fixed")
- Breaking changes (under "Changed" with **BREAKING** prefix)
- New cloud providers (under "Added")
- New scripts (under "Added")

## Standard Documentation Files

Maintain these documentation files:

- **README.md**: Project overview, quick start
- **CHANGELOG.md**: Version history
- **Module READMEs**: Module-specific documentation (e.g., `azure/cost_analysis/README.md`)
- **Script comments**: PowerShell-based help content

## Documentation Quality Standards

### PowerShell Script Documentation

Include comment-based help in all scripts:

```powershell
<#
.SYNOPSIS
    Brief description of the script.

.DESCRIPTION
    Detailed description.

.PARAMETER SourceMonth
    Source month in YYYY-MM format.

.EXAMPLE
    .\script.ps1 -SourceMonth "2025-11" -TargetMonth "2025-12"
#>
```

### README Format

- Include requirements section
- Provide usage examples
- Document all parameters
- Include troubleshooting section

## Review Checklist

Before considering documentation complete:

- [ ] README.md reflects current project state
- [ ] All new scripts are documented
- [ ] Parameter changes are reflected in documentation
- [ ] CHANGELOG.md is updated
- [ ] Installation instructions are current
- [ ] Module READMEs are synced with code

## Goal

- Keep documentation close to code
- Maintain living documentation that evolves with scripts
- Consider documentation as part of feature completeness