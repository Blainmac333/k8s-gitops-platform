🧠 DevOps QR Code Project

This project is a fully self-hosted DevOps environment running entirely on a Raspberry Pi cluster.
It demonstrates end-to-end automation — from code commit to build, deployment, monitoring, and disaster recovery — all managed through GitHub Actions, Argo CD, Docker, and Kubernetes (k3s).

🌐 Hosted Services

All services are hosted under the *.blainweb.com domain and deployed to a self-managed Kubernetes cluster running on a Raspberry Pi.

Service	Description	Stack
QR Code App	Users submit URLs to generate QR codes stored in S3-compatible cloud storage.	Frontend: Next.js / Backend: FastAPI
CV / Portfolio Website	Personal website showcasing projects and experience.	React / Static Hosting
Grafana Dashboards	Cluster and workload observability with real-time metrics.	Grafana + Prometheus
Velero Backups	Automated cluster backups and recovery tests.	Velero + Backblaze B2
Argo CD	GitOps-based continuous delivery system that monitors GitHub and syncs changes to Kubernetes.	Argo CD + Helm
⚙️ Application Overview
🖥️ Frontend (Next.js)

Built with Next.js and TypeScript.

Provides a sleek interface for generating and retrieving QR codes.

Runs on port 3000, served through Kubernetes and reverse-proxied by Caddy → Traefik → k3s.

🧩 Backend (FastAPI)

Built using Python and FastAPI.

Handles incoming URLs and generates QR codes.

Stores generated images in Backblaze B2 (S3-compatible).

Runs on port 8000, accessible via internal Kubernetes services.

🐳 Containerization & Deployment

Both frontend and backend have independent Dockerfiles.

Images are built via GitHub Actions on every push to master.

Versioned container images are pushed to GitHub Container Registry (GHCR).

Deployments are defined as Kubernetes manifests managed by Argo CD.

Each deployment uses revisionHistoryLimit: 2 to retain only the last two versions for clean rollbacks.

🔐 Secrets Management

All sensitive values are stored in GitHub Actions Secrets.

Secret	Description
B2_KEY_ID	Backblaze B2 Key ID
B2_APP_KEY	Backblaze B2 Application Key
S3_BUCKET_NAME	Name of S3-compatible bucket
API_KEY	Internal API key for FastAPI
KUBE_CONFIG	Encoded kubeconfig for the Pi cluster
AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY	For AWS S3-compatible services (optional future use)

Secrets are securely injected during CI/CD to:

Authenticate with Backblaze B2.

Deploy applications via the Pi’s cluster.

Configure runtime environment variables without exposing credentials in Git.

🔁 CI/CD Pipeline (GitHub Actions)

The Raspberry Pi runs a self-hosted ARM64 GitHub Actions runner full-time, enabling a fully autonomous CI/CD workflow.

Pipeline Overview
Workflow	Description
Build & Push	Builds Docker images for backend and frontend, tags them with the Git commit SHA, and pushes to GHCR.
Deploy (GitOps)	Updates Kubernetes manifests with the new image tags, commits back to master, and Argo CD automatically syncs the cluster.
Velero Restore Test	Verifies cluster backup/restore integrity using Velero.
Velero Cleanup	Deletes old backups/restores weekly to manage B2 storage efficiently.
Key Features

✅ Full GitOps Deployment Flow — Argo CD automatically syncs and heals the cluster whenever manifests in Git change.

🔁 Zero-Downtime Rolling Updates — Kubernetes manages rollout and rollback.

🔒 Immutable Builds — Each build is tied to a unique commit SHA tag.

🔄 Self-Healing Cluster — Argo CD detects and fixes drift from the desired Git state.

💻 ARM64 Native Builds — The Pi runner handles builds optimized for ARM hardware.

🚀 GitOps with Argo CD

Argo CD provides a visual and automated interface for managing deployments.
It continuously watches the Git repository and ensures that the live Kubernetes state matches the desired configuration in Git.

Features

Real-time sync of master branch → Kubernetes cluster.

Auto-healing: If a pod or deployment is manually changed, Argo restores it from Git.

Automatic cleanup of old resources (via prune policy).

Accessible via: https://argocd.blainweb.com

Integrated with Caddy and Traefik for HTTPS ingress and Let’s Encrypt certificates.

Argo CD Application Configuration

Namespace: argocd

Target Repo: DevOps-Project

Sync Policy: Automated (auto-sync, self-heal, prune)

Managed Paths: k8s/

Namespace for apps: qr

☁️ Backups & Disaster Recovery (Velero + Backblaze B2)

Velero automatically backs up Kubernetes resources and persistent volumes to Backblaze B2.

Configuration Details:

Provider: aws (S3-compatible)

Bucket: velero-blain-backups

Endpoint: https://s3.eu-central-003.backblazeb2.com

Schedule: Daily @ 03:00 UTC

Retention: 5 most recent test backups

Validation Script: scripts/velero-restore-test.sh

Cleanup Script: scripts/velero-cleanup.sh

If Backblaze rate limits are hit, the pipeline marks backup stages as skipped to maintain uptime.

📊 Monitoring & Observability

Grafana + Prometheus are deployed for full cluster and application visibility.

Prometheus scrapes metrics from all Pi nodes and containers.

Grafana dashboards display:

CPU, memory, and disk usage

Pod health and uptime

Velero backup stats

Access via: https://grafana.blainweb.com
 (secured access only)

🌍 Hosting Architecture
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

🧩 Tech Stack Summary
Category	Technology
Frontend	Next.js (React, TypeScript)
Backend	FastAPI (Python)
Storage	Backblaze B2 (S3-compatible)
Orchestration	Kubernetes (k3s)
Continuous Delivery	Argo CD (GitOps)
CI/CD	GitHub Actions (Self-Hosted ARM64 Runner)
Monitoring	Grafana, Prometheus
Backups	Velero
Reverse Proxy	Caddy → Traefik
Hosting	Raspberry Pi (ARM64, Ubuntu Server)
Domain	blainweb.com
🎯 Project Goals

This project demonstrates:

✅ End-to-end DevOps automation — from commit to live deployment.

🧩 Full GitOps workflow via Argo CD.

🧠 Self-hosted CI/CD, monitoring, and recovery pipeline on ARM hardware.

🔐 Secure secrets and image management using GitHub + GHCR.

💾 Real-world backup & disaster recovery using Velero and Backblaze B2.

📈 Production-style observability and monitoring stack.

✅ Current Status

All apps (frontend, backend, Grafana, Argo CD, Velero) are live and healthy.

Argo CD automatically syncs new deployments from master.

Velero runs daily verified backups to Backblaze B2.

Grafana dashboards monitor system health.

GitHub Actions deploy pipeline runs entirely on the Raspberry Pi’s self-hosted ARM64 runner.