# Kubernetes DB Backup CronJob 🛡️

A robust and secure solution for automating database backups using Kubernetes CronJobs. This project streamlines scheduled backups, secret management, and cloud storage integration.

## ✨ Features

- **⏱️ Scheduled Backups**: Automated database backups via Kubernetes CronJob
- **🔐 Secure Secrets**: Kubernetes Secrets for credential management
- **☁️ Cloud Storage**: Support for AWS S3 and Azure Blob Storage
- **🗄️ Database Support**: Compatible with PostgreSQL and MySQL
- **⚙️ Easy Config**: Simple configuration using .conf files
- **🛠️ Ready Scripts**: Pre-configured deployment scripts

## 🚀 Getting Started

### Prerequisites

- Running Kubernetes cluster
- Configured kubectl with cluster access
- Namespace `db-backup` (create with command below)
```bash
kubectl create namespace db-backup
```

### Installation

1. Clone the repository:
```bash
git clone <repo-url>
cd <repo-directory>
```

2. Run the installation script:
```bash
chmod +x install.sh
./install.sh
```

The installation process will:
- Verify the `db-backup` namespace
- Apply Kubernetes resources sequentially
- Generate installation logs in `install.log`

### Verification

Check the deployment status:
```bash
# View CronJobs
kubectl get cronjob -n db-backup

# View Pods
kubectl get pods -n db-backup
```

## 🗑️ Uninstallation

Remove all deployed resources:

```bash
chmod +x uninstall.sh
./uninstall.sh
```

The uninstallation process will:
- Remove all created resources
- Generate logs in `uninstall.log`

## 🔧 Troubleshooting

Common issues and solutions:

| Issue | Solution |
|-------|----------|
| Resource errors | Verify YAML configurations |
| Access denied | Check cluster permissions |
| Namespace issues | Confirm `db-backup` namespace exists |

For detailed troubleshooting:
- Review `install.log` for deployment issues
- Check `uninstall.log` for cleanup problems
- Verify cluster permissions and connectivity

## 📝 Logs

Installation and uninstallation logs are stored in:
- `install.log`: Deployment process logs
- `uninstall.log`: Cleanup process logs

---

Happy Backing Up! 🛡️

*For support issues, please open a GitHub issue.*