# FinOps Toolkit

A portfolio of scripts for Financial Operations (FinOps) across cloud platforms. Helps organizations optimize cloud spending, detect cost anomalies, and maintain financial governance.

## Project Vision

Build a modular collection of FinOps tools that enable:
- Cost Visibility: Understand where money is being spent
- Cost Optimization: Identify opportunities to reduce waste
- Cost Governance: Enforce policies and budgets
- Multi-Cloud Support: Work across Azure, AWS, GCP, and other providers

## Modules

### Azure Cost Analysis
Location: `azure/cost_analysis/`

Tools for analyzing Azure costs with parameterized comparisons and anomaly detection.

Features:
- Accumulated cost comparisons between any two time periods
- Resource-level cost analysis with top increases
- Automated anomaly detection (new costs, removed costs, significant changes)
- Clean, readable reports with ANSI-stripped output
- Multi-subscription support with friendly naming

Scripts:
- `diff_accumulated/accumulatedCost.ps1` – Compare total costs
- `diff_resource/diff_costByResource.ps1` – Resource-level analysis

Full Documentation: `azure/cost_analysis/README.md`

### Future Modules (Planned)

- AWS Cost Analysis – tools for AWS Cost Explorer
- GCP Cost Analysis – Google Cloud cost management tools
- Budget Management – cross‑cloud budget tracking and alerting
- Tagging Governance – enforce and audit resource tagging
- Reservation Optimization – analyze and recommend reserved instances
- Waste Detection – identify unused or underutilized resources

## Getting Started

Prerequisites
- PowerShell 5.1 or higher (PowerShell Core 7+ recommended)
- Cloud provider CLI tools (Azure CLI, AWS CLI, etc.)
- Appropriate cloud permissions for cost management

Installation

```bash
git clone <your-repo-url>
cd finops
```

Navigate to a module, e.g.:

```bash
cd azure/cost_analysis
```

Follow the module‑specific README for setup and usage.

## Repository Structure

```
finops/
├── README.md
├── LICENSE
├── .gitignore
└── azure/
    └── cost_analysis/
        ├── README.md
        ├── requirements.txt
        ├── diff_accumulated/
        │   └── accumulatedCost.ps1
        └── diff_resource/
            └── diff_costByResource.ps1
```

## Contributing

Contributions are welcome. Typical workflow:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/new-tool`
3. Make changes with clear commit messages
4. Update documentation as needed
5. Test thoroughly
6. Submit a Pull Request

## License

MIT License – see LICENSE file.

## Authors

FinOps Community Contributors

## Issues & Support

Report issues on GitHub. Include module name, error messages, and reproduction steps. Check existing issues before opening new ones.

## Resources

- FinOps Foundation – https://www.finops.org/
- Azure Cost Management – https://docs.microsoft.com/azure/cost-management-billing/
- AWS Cost Management – https://aws.amazon.com/aws-cost-management/
- GCP Cost Management – https://cloud.google.com/cost-management

## Version History

See CHANGELOG.md for detailed version history and migration guides.

**Latest Release:** v2.0.0 (2026-01-13)

## Use Cases

- Monthly Cost Reviews
- Anomaly Detection
- Budget Management
- Chargeback/Showback
- Optimization
- Governance

---
