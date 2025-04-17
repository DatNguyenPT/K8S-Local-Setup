# 🛡️ Kubernetes DB Backup CronJob

This project provides a robust and secure way to automate database backups using Kubernetes CronJobs. It includes everything needed to schedule backups, securely manage secrets, and push backup files to cloud storage services such as AWS S3 and Azure Blob Storage.

---

## 📦 Features

- ⏱️ Scheduled database backups via Kubernetes `CronJob`
- 🔐 Secure secret management using Kubernetes `Secrets`
- ☁️ Multi-cloud support: AWS S3, Azure Blob
- 🧩 Easy integration with PostgreSQL and MySQL
- 📝 Simple configuration with `.conf` files
- 🛠️ Ready-to-use shell script for generating secrets

---

## 🚀 Setup Guide
- Follow the directory orders and intruction.txt inside each directory !!!

---

### 📌 Prerequisites

- Kubernetes cluster up and running
- `kubectl` configured and connected
- Namespace `dbs` created in your cluster:
  
  ```bash
  kubectl create namespace dbs
