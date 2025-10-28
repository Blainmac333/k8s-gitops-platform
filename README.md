# 🧠 DevOps QR Code Project

This project is a **fully self-hosted DevOps environment** running entirely on a **Raspberry Pi cluster**.  
It demonstrates **end-to-end automation** — from code commit to build, deployment, monitoring, and disaster recovery — all managed via **GitHub Actions**, **Argo CD**, **Docker**, and **Kubernetes (k3s)**.

---

## 🌐 Hosted Services

All services run under the **\*.blainweb.com** domain and are deployed to a self-managed Kubernetes cluster on the Raspberry Pi.

| Service | Description | Stack |
|----------|--------------|--------|
| **QR Code App** | Users submit URLs to generate QR codes stored in S3-compatible cloud storage. | Frontend: Next.js / Backend: FastAPI |
| **CV / Portfolio Website** | Personal website showcasing projects and experience. | React / Static Hosting |
| **Grafana Dashboards** | Cluster and workload observability with real-time metrics. | Grafana + Prometheus |
| **Velero Backups** | Automated cluster backups and recovery validation. | Velero + Backblaze B2 |
| **Argo CD** | GitOps-based continuous delivery that syncs GitHub changes to Kubernetes. | Argo CD + Helm |

---

## ⚙️ Application Overview

### 🖥️ Frontend (Next.js)
- Built with **Next.js** and **TypeScript**.  
- Provides a sleek interface for generating and retrieving QR codes.  
- Runs on **Port 3000**, served through **Caddy → Traefik → k3s**.

### 🧩 Backend (FastAPI)
- Developed using **Python** and **FastAPI**.  
- Handles incoming URLs and generates QR codes.  
- Stores generated images in **Backblaze B2 (S3-compatible)**.  
- Runs on **Port 8000**, accessible via internal Kubernetes services.

---

## 🐳 Containerization & Deployment

- Both frontend and backend have independent **Dockerfiles**.  
- Images are built via **GitHub Actions** on every push to `master`.  
- Versioned images are pushed to **GitHub Container Registry (GHCR)**.  
- Deployments are managed by **Argo CD** via Kubernetes manifests.  
- Each deployment uses `revisionHistoryLimit: 2` to retain only two previous rollouts for clean rollback capability.

---

## 🔐 Secrets Management

All sensitive credentials are stored securely in **GitHub Actions Secrets**.

| Secret | Description |
|---------|-------------|
| `B2_KEY_ID` | Backblaze B2 Key ID |
| `B2_APP_KEY` | Backblaze B2 Application Key |
| `S3_BUCKET_NAME` | S3-compatible bucket name |
| `API_KEY` | Internal API key for FastAPI |
| `KUBE_CONFIG` | Encoded kubeconfig for Raspberry Pi cluster access |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | Optional credentials for AWS S3-compatible services |

Secrets are injected during CI/CD to:  
- Authenticate with **Backblaze B2**.  
- Deploy applications to the Pi’s Kubernetes cluster.  
- Configure runtime environment variables securely (never exposed in code).

---

## 🔁 CI/CD Pipeline (GitHub Actions)

The **Raspberry Pi** runs a **self-hosted ARM64 GitHub Actions runner full-time**, enabling a completely autonomous CI/CD workflow.

### Workflow Overview

| Workflow | Description |
|-----------|--------------|
| **Build & Push** | Builds Docker images for backend and frontend, tags them with the Git commit SHA, and pushes to GHCR. |
| **Deploy (GitOps)** | Updates Kubernetes manifests with new image tags, commits back to `master`, and Argo CD automatically syncs the cluster. |
| **Velero Restore Test** | Validates backup and restore integrity using Velero. |
| **Velero Cleanup** | Deletes old backups/restores weekly to manage storage space efficiently. |

### Key Features
- ✅ **Full GitOps Deployment Flow** — Argo CD auto-syncs and self-heals the cluster from Git changes.  
- 🔁 **Zero-Downtime Rolling Updates** — Kubernetes manages rollout and rollback.  
- 🔒 **Immutable Builds** — Each build is tied to a unique commit SHA tag.  
- 🔄 **Self-Healing Cluster** — Argo CD restores drifted resources to match Git.  
- 💻 **ARM64 Native Builds** — The Pi runner builds and deploys ARM-optimized containers.

---

## 🚀 GitOps with Argo CD

Argo CD continuously monitors the Git repository and ensures the live cluster state matches the configuration in Git.

### Features
- **Real-time Sync:** Watches the `master` branch and auto-applies changes.  
- **Self-Heal:** Detects and reverts manual changes to cluster resources.  
- **Pruning:** Cleans up old resources automatically.  
- **Visual Management:** View deployments via the **Argo CD UI** → [argocd.blainweb.com](https://argocd.blainweb.com).  
- Integrated with **Caddy + Traefik** for HTTPS ingress and Let’s Encrypt certificates.

### Configuration

| Property | Value |
|-----------|--------|
| **Namespace** | `argocd` |
| **Repository** | `DevOps-Project` |
| **Sync Policy** | Auto-sync, self-heal, prune |
| **App Namespace** | `qr` |
| **Managed Path** | `k8s/` |

---

## ☁️ Backups & Disaster Recovery (Velero + Backblaze B2)

Velero automatically backs up all cluster resources and persistent volumes to **Backblaze B2**.

### Configuration

| Setting | Value |
|----------|--------|
| **Provider** | `aws` (S3-compatible) |
| **Bucket** | `velero-blain-backups` |
| **Endpoint** | `https://s3.eu-central-003.backblazeb2.com` |
| **Schedule** | Daily at 03:00 UTC |
| **Retention** | 5 most recent test backups |

### Validation & Cleanup
- **Restore Test:** `scripts/velero-restore-test.sh` validates backup/restore.  
- **Cleanup:** `scripts/velero-cleanup.sh` removes outdated backups weekly.  
- **Fail-Soft Mode:** If Backblaze rate limits occur, the pipeline skips backup but continues deployment.

---

## 📊 Monitoring & Observability

- **Grafana** provides dashboards for system and app metrics.  
- **Prometheus** scrapes metrics from all nodes and containers.  
- Dashboards include:
  - CPU, memory, and disk usage  
  - Pod health and uptime  
  - Velero backup status  

Access via: **[grafana.blainweb.com](https://grafana.blainweb.com)** *(secured access only)*

---

## 🌍 Hosting Architecture

```plaintext
[Raspberry Pi Cluster]
├── k3s / Kubernetes
│   ├── FastAPI Pod (qr-backend)
│   ├── Next.js Pod (qr-frontend)
│   ├── Velero + Node Agent
│   ├── Grafana + Prometheus Stack
│   ├── Argo CD (GitOps controller)
│   └── Traefik Ingress Controller
│
├── GitHub Actions Runner (Self-Hosted ARM64, always-on)
└── Persistent Volumes → Backblaze B2 (via Velero)

---

## 🧩 Tech Stack Summary

| Category | Technology |
|-----------|-------------|
| **Frontend** | Next.js (React, TypeScript) |
| **Backend** | FastAPI (Python) |
| **Storage** | Backblaze B2 (S3-compatible) |
| **Orchestration** | Kubernetes (k3s) |
| **Continuous Delivery** | Argo CD (GitOps) |
| **CI/CD** | GitHub Actions (Self-Hosted ARM64 Runner) |
| **Monitoring** | Grafana, Prometheus |
| **Backups** | Velero |
| **Reverse Proxy** | Caddy → Traefik |
| **Hosting** | Raspberry Pi (ARM64, Ubuntu Server) |
| **Domain** | blainweb.com |

---

## 🎯 Project Goals

This project demonstrates:

- ✅ End-to-end DevOps automation from commit to live deployment.  
- 🧩 Full GitOps workflow with Argo CD.  
- 🧠 Self-hosted CI/CD, monitoring, and recovery on ARM hardware.  
- 🔐 Secure secrets and image management with GitHub + GHCR.  
- 💾 Real-world disaster recovery using Velero and Backblaze B2.  
- 📈 Production-grade observability and monitoring.

---

## ✅ Current Status

- All services (Frontend, Backend, Grafana, Argo CD, Velero) are live and healthy.  
- Argo CD auto-syncs all new deployments from `master`.  
- Velero performs daily verified backups to Backblaze B2.  
- Grafana dashboards actively monitor cluster health.  
- The GitHub Actions deploy pipeline runs entirely on the **self-hosted ARM64 Pi runner**.
