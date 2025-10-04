# 🧠 DevOps QR Code Project

This project is a **self-hosted DevOps environment** running entirely on a **Raspberry Pi cluster**.  
It demonstrates full lifecycle automation — from code to deployment, monitoring, and disaster recovery — all managed via **GitHub Actions**, **Docker**, and **Kubernetes**.

---

## 🌐 Hosted Services

All services run under my personal domain **[qr.blainweb.com](https://qr.blainweb.com)** and are deployed to my self-managed Kubernetes cluster on the Raspberry Pi.

| Service | Description | Stack |
|----------|--------------|--------|
| **QR Code App** | Users can submit URLs to generate QR codes, which are stored in cloud object storage. | Frontend: Next.js / Backend: FastAPI |
| **CV / Portfolio Website** | Personal website showcasing my work, projects, and professional background. | React / Static Hosting |
| **Grafana Dashboards** | Observability and monitoring for the cluster, workloads, and backups. | Grafana + Prometheus stack |
| **Velero Backups** | Automated cluster and volume backups with disaster recovery validation. | Velero + Backblaze B2 |

---

## ⚙️ Application Overview

### 🖥️ Frontend (Next.js)
- Built using **Next.js** and **TypeScript**.
- Provides a clean interface to submit URLs and display generated QR codes.
- Runs on **Port 3000** in Docker, reverse-proxied via NGINX on the Raspberry Pi.

### 🧩 Backend (FastAPI)
- Developed with **Python** and **FastAPI**.
- Accepts URLs from the frontend and generates corresponding **QR codes**.
- Stores QR code images in **Backblaze B2** (S3-compatible storage).
- Runs on **Port 8000** and communicates internally via Kubernetes services.

---

## 🐳 Containerization

Both the frontend and backend are fully **Dockerized** with independent `Dockerfile`s.

- Containers are built and versioned via **GitHub Actions**.
- Each service has its own image to allow independent scaling and redeployment.
- Docker images are deployed to the Raspberry Pi’s Kubernetes cluster using manifests and Helm charts.
- Configuration and environment secrets are injected securely at runtime.

---

## 🔐 Secrets Management

All sensitive credentials are stored securely in **GitHub Actions Secrets**, including:

| Secret | Description |
|---------|-------------|
| `B2_KEY_ID` | Backblaze B2 Key ID |
| `B2_APP_KEY` | Backblaze B2 Application Key |
| `S3_BUCKET_NAME` | Name of the B2 S3-compatible bucket |
| `API_KEY` | Internal API key for the FastAPI backend |
| `KUBE_CONFIG` | Encoded kubeconfig for Raspberry Pi cluster access |

These secrets are injected during CI/CD workflows to:
- Authenticate with Backblaze for backup and QR code uploads.
- Deploy to the Pi’s Kubernetes cluster via `kubectl`.
- Configure environment variables in containers securely without exposing credentials in code.

---

## 🔁 CI/CD Pipeline (GitHub Actions)

All automation runs via **GitHub Actions**, using a **self-hosted ARM64 runner** located on the Raspberry Pi.

### Workflow Overview
| Workflow | Description |
|-----------|--------------|
| **Build & Test** | Runs linting, builds Docker images, and ensures API/frontend integrity. |
| **Deploy** | Pulls from GitHub, rebuilds containers, applies Kubernetes manifests, and restarts services. |
| **Velero Restore Test** | Automatically tests that Velero can back up and restore Kubernetes namespaces successfully. |
| **Velero Cleanup** | Cleans up old Velero test backups and restores weekly to manage storage space. |

### Key Features
- **Automated Deployments:** Pushing to `master` triggers a full rebuild and redeploy.
- **Fail-Soft Logic:** If Backblaze API rate limits or caps are hit, the pipeline continues gracefully.
- **Rolling Updates:** Uses Kubernetes rollout for zero-downtime deployments.
- **Infrastructure as Code:** Helm charts and manifests define all deployments, services, and secrets.

---

## ☁️ Backups & Disaster Recovery (Velero + Backblaze B2)

Velero is installed via Helm and configured to back up Kubernetes resources and persistent volumes to **Backblaze B2**, an S3-compatible storage provider.

### Backup Details
- **Provider:** `aws` (S3-compatible)
- **Bucket:** `velero-blain-backups`
- **Endpoint:** `https://s3.eu-central-003.backblazeb2.com`
- **Schedule:** Daily automated backups at 03:00 UTC
- **Retention:** Keeps 5 most recent test backups
- **Fail-Soft:** If B2 transaction caps are hit, deploy continues and marks the backup stage as skipped

### Validation & Cleanup
- `scripts/velero-restore-test.sh` automatically tests a full backup/restore workflow.
- `scripts/velero-cleanup.sh` deletes old test backups and restores weekly to conserve space.

---

## 📊 Monitoring & Observability

- **Grafana** dashboards display metrics from Kubernetes, application performance, and Velero backup status.
- **Prometheus** scrapes system and container metrics from all Pi nodes.
- Dashboards are accessible through secure local-only access (or VPN tunnel for remote monitoring).

---

## 🌍 Hosting Architecture

```plaintext
[Raspberry Pi Cluster]
├── k3s / Kubernetes
│   ├── FastAPI Pod (api)
│   ├── Next.js Pod (frontend)
│   ├── Velero + Node Agent
│   ├── Grafana + Prometheus Stack
│   └── Ingress Controller (NGINX)
│
├── GitHub Actions Runner (self-hosted, ARM64)
└── Persistent Volume (Backups via Velero → Backblaze B2)

🧩 Tech Stack Summary
Category	Technology
Frontend	Next.js (React, TypeScript)
Backend	FastAPI (Python)
Storage	Backblaze B2 (S3-compatible)
Orchestration	Kubernetes (k3s)
CI/CD	GitHub Actions (Self-Hosted ARM64 Runner)
Containerization	Docker
Monitoring	Grafana, Prometheus
Backups	Velero
Hosting	Raspberry Pi (ARM64, Ubuntu Server)
Domain	qr.blainweb.com
🎯 Project Goals

The project demonstrates:

End-to-end DevOps automation from commit to deployment.

Running a production-style environment on ARM hardware.

Real-world CI/CD, backup, and observability practices.

Secure secrets management and self-hosted cloud operations.

Hands-on experience with Kubernetes, Velero, and Backblaze integrations.

✅ Current Status

All apps (frontend, backend, and supporting services) are live and deployed.

Nightly Velero backups are configured and validated.

Grafana dashboards monitor system and cluster health.

CI/CD pipeline deploys automatically via GitHub on every master branch update.