# FinOps Toolkit

A comprehensive portfolio of scripts and tools for Financial Operations (FinOps) across cloud platforms. This toolkit helps organizations optimize cloud spending, detect cost anomalies, and maintain financial governance.

## 🎯 Project Vision

Build a modular collection of FinOps tools that enable:
- **Cost Visibility**: Understand where money is being spent
- **Cost Optimization**: Identify opportunities to reduce waste
- **Cost Governance**: Enforce policies and budgets
- **Multi-Cloud Support**: Work across Azure, AWS, GCP, and other providers

## 📦 Modules

### Azure Cost Analysis
**Location:** [`azure/cost_analysis/`](azure/cost_analysis/)

Tools for analyzing Azure costs with parameterized comparisons and anomaly detection.

**Features:**
- Accumulated cost comparisons between any two time periods
- Resource-level cost analysis with top increases
- Automatic anomaly detection (new costs, removed costs, significant changes)
- Clean, readable reports with ANSI-stripped output
- Multi-subscription support with friendly naming

**Scripts:**
- [`diff_accumulated/accumulatedCost.ps1`](azure/cost_analysis/diff_accumulated/accumulatedCost.ps1) - Compare total costs
- [`diff_resource/diff_costByResource.ps1`](azure/cost_analysis/diff_resource/diff_costByResource.ps1) - Resource-level analysis

[📖 Full Documentation](azure/cost_analysis/README.md)

### Future Modules (Planned)

- **AWS Cost Analysis** - Similar tools for AWS Cost Explorer
- **GCP Cost Analysis** - Google Cloud cost management tools
- **Budget Management** - Cross-cloud budget tracking and alerting
- **Tagging Governance** - Enforce and audit resource tagging
- **Reservation Optimization** - Analyze and recommend reserved instances
- **Waste Detection** - Identify unused or underutilized resources

## 🚀 Getting Started

### Kilo Integration

This project can be used with Kilo, an AI-powered coding assistant. The project includes a Kilo configuration file:

**Location:** [`.kilo/kilo.jsonc`](.kilo/kilo.jsonc)

The configuration defines:
- Project metadata (name, version, description)
- Dependencies and devDependencies
- Agent instructions for documentation updates

### Prerequisites

- PowerShell 5.1 or higher (PowerShell Core 7+ recommended)
- Cloud provider CLI tools (Azure CLI, AWS CLI, etc.)
- Appropriate cloud permissions for cost management

### Installation

1. Clone this repository:
```bash
git clone <your-repo-url>
cd finops
```

2. Navigate to the specific module you want to use:
```bash
cd azure/cost_analysis
```

3. Follow the module-specific README for setup and usage instructions.

## 📁 Repository Structure

```
finops/
├── README.md                          # This file - main project overview
├── LICENSE                            # MIT License
├── .gitignore                         # Git ignore rules
└── azure/
    └── cost_analysis/
        ├── README.md                  # Module-specific documentation
        ├── requirements.txt           # Module dependencies
        ├── diff_accumulated/
        │   └── accumulatedCost.ps1   # Accumulated cost comparison
        └── diff_resource/
            └── diff_costByResource.ps1 # Resource-level analysis
```

## 🤝 Contributing

Contributions are welcome! Whether you want to:
- Add support for new cloud providers
- Create new FinOps tools
- Improve existing scripts
- Fix bugs or improve documentation

### Development Guidelines

1. **Modularity**: Keep tools organized by cloud provider and function
2. **Parameterization**: Avoid hardcoded values; use parameters
3. **Documentation**: Include clear README files and inline comments
4. **Error Handling**: Implement robust error handling and validation
5. **Consistency**: Follow PowerShell best practices and naming conventions

### Contribution Process

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/new-tool`
3. Make your changes with clear commit messages
4. Add or update documentation
5. Test thoroughly
6. Submit a Pull Request

## 📄 License

MIT License - See [LICENSE](LICENSE) file for details.

## 👥 Authors

FinOps Community Contributors

## 🐛 Issues & Support

If you encounter issues or have suggestions:
- File an issue on the GitHub repository
- Include module name, error messages, and steps to reproduce
- Check existing issues before creating new ones

## 📚 Resources

### FinOps Foundation
- [FinOps Foundation](https://www.finops.org/)
- [FinOps Framework](https://www.finops.org/framework/)
- [FinOps Principles](https://www.finops.org/framework/principles/)

### Cloud Provider Documentation
- [Azure Cost Management](https://docs.microsoft.com/azure/cost-management-billing/)
- [AWS Cost Management](https://aws.amazon.com/aws-cost-management/)
- [GCP Cost Management](https://cloud.google.com/cost-management)

### Tools & CLIs
- [Azure Cost CLI](https://github.com/mivano/azure-cost-cli)
- [Azure CLI](https://docs.microsoft.com/cli/azure/)
- [AWS CLI](https://aws.amazon.com/cli/)
- [gcloud CLI](https://cloud.google.com/sdk/gcloud)

## 🔄 Version History

See [CHANGELOG.md](CHANGELOG.md) for detailed version history and migration guides.

**Latest Release:** v2.0.0 (2026-01-13)
- Modular structure with separate cloud provider modules
- Parameterized scripts for flexible date ranges
- Anomaly detection capabilities
- Comprehensive documentation

## 💡 Use Cases

- **Monthly Cost Reviews**: Compare costs month-over-month
- **Anomaly Detection**: Identify unexpected cost spikes
- **Budget Management**: Track spending against budgets
- **Chargeback/Showback**: Allocate costs to teams or projects
- **Optimization**: Find opportunities to reduce waste
- **Governance**: Ensure compliance with cost policies

---

**Note:** This is an active project. Check individual module READMEs for specific features and usage instructions.
