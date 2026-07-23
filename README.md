# 🧠 k8s-gitops-platform-project

This project is a **fully self-hosted DevOps environment** running entirely on a **Raspberry Pi cluster**.  
It demonstrates **end-to-end automation** — from code commit to build, deployment, monitoring, and disaster recovery — all managed via **GitHub Actions**, **Argo CD**, **Docker**, **Kubernetes (k3s)**, and **Terraform**.

---

## 🌐 Hosted Services

All services run under the **\*.blainweb.com** domain, routed through a **Cloudflare Tunnel** to the Raspberry Pi.

| Service | Description | Stack |
|----------|--------------|--------|
| **QR Code App** | Users submit URLs to generate QR codes stored in S3-compatible cloud storage. | Frontend: Next.js / Backend: FastAPI |
| **CV / Portfolio Website** | Personal website showcasing projects and experience. | React / Static Hosting |
| **Grafana Dashboards** | Cluster and workload observability with real-time metrics and alerting. Metrics forward to Grafana Cloud via remote_write; logs ship via Grafana Alloy → Loki. | Grafana + Prometheus + Grafana Cloud + Alloy |
| **Velero Backups** | Automated cluster backups and recovery validation. | Velero + Backblaze B2 |
| **Argo CD** | GitOps-based continuous delivery that syncs GitHub changes to Kubernetes. | Argo CD + Helm |
| **Cloudflare Tunnel** | Secure tunnel routing all subdomains to the Pi without exposing ports. | cloudflared |
| **DNS Management** | DNS records for all subdomains managed as code. | Terraform + Cloudflare |

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
- Both deployments include **liveness and readiness probes** — Kubernetes only routes traffic to healthy pods and restarts unresponsive ones automatically.

---

## 🔐 Secrets Management

All sensitive credentials are stored securely in **GitHub Actions Secrets**.

| Secret | Description |
|---------|-------------|
| `B2_KEY_ID` | Backblaze B2 Key ID (app storage) |
| `B2_APP_KEY` | Backblaze B2 Application Key (app storage) |
| `B2_ACCESS_KEY_ID` | Backblaze B2 Key ID (Terraform state bucket) |
| `B2_SECRET_ACCESS_KEY` | Backblaze B2 Secret (Terraform state bucket) |
| `S3_BUCKET_NAME` | S3-compatible bucket name |
| `API_KEY` | Internal API key for FastAPI |
| `KUBE_CONFIG` | Encoded kubeconfig for Raspberry Pi cluster access |
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token with DNS edit permissions |
| `CLOUDFLARE_ZONE_ID` | Cloudflare Zone ID for blainweb.com |
| `GHCR_READ_TOKEN` | Read-only GHCR token used as the k3s image pull secret for private container images |
| `GH_PAT` | GitHub Personal Access Token used by the GitOps commit-back step to push updated image tags to `master` |
| `GRAFANA_CLOUD_REMOTE_WRITE_TOKEN` | Bearer token for Prometheus → Grafana Cloud remote_write (written to a gitignored `password_file` by CI) |
| `GRAFANA_CLOUD_LOKI_TOKEN` | Bearer token for Grafana Alloy → Grafana Cloud Loki log shipping |
| `DISCORD_WEBHOOK_URL` | Discord webhook URL for Grafana alert notifications |
| `PI_SSH_KEY` | Private SSH key for GitHub Actions → Raspberry Pi connections |
| `PI_SSH_HOST` | Hostname/IP of the Raspberry Pi |
| `PI_SSH_USER` | SSH username for Pi connections |

Secrets are injected during CI/CD to:  
- Authenticate with **Backblaze B2**.  
- Deploy applications to the Pi's Kubernetes cluster.  
- Manage DNS records via **Terraform + Cloudflare**.  
- Pull private images from GHCR into k3s.  
- Ship metrics and logs to **Grafana Cloud** without storing credentials in the repo (the `password_file` pattern writes tokens to a gitignored path at runtime).  
- Configure runtime environment variables securely (never exposed in code).

---

## 🔁 CI/CD Pipeline (GitHub Actions)

The **Raspberry Pi** runs a **self-hosted ARM64 GitHub Actions runner full-time**, enabling a completely autonomous CI/CD workflow.

### Workflow Overview

| Workflow | Trigger | Description |
|-----------|---------|--------------|
| **Build & Push** | Push to `master` | Builds Docker images for backend and frontend, scans them with Trivy, tags them with the Git commit SHA, and pushes to GHCR. |
| **Deploy (GitOps)** | After Build & Push | Updates Kubernetes manifests with new image tags, commits back to `master`, and Argo CD automatically syncs the cluster. |
| **Terraform** | PR / merge to `master` | Runs `terraform plan` on PRs (posts result as a PR comment) and `terraform apply` on merge for any DNS changes. |
| **Velero Restore Test** | Mondays 02:30 UTC | Creates a test backup of a temporary namespace, verifies full restore integrity, then prunes old test backups (keeps 5). |
| **Velero Cleanup** | Sundays 03:10 UTC | Deletes old test backups to manage storage space efficiently. |

### Key Features
- ✅ **Full GitOps Deployment Flow** — Argo CD auto-syncs and self-heals the cluster from Git changes.  
- 🔁 **Zero-Downtime Rolling Updates** — Kubernetes manages rollout and rollback.  
- 🔒 **Immutable Builds** — Each build is tied to a unique commit SHA tag.  
- 🔄 **Self-Healing Cluster** — Argo CD restores drifted resources to match Git.  
- 💻 **ARM64 Native Builds** — The Pi runner builds and deploys ARM-optimized containers.  
- 🌍 **IaC DNS** — DNS changes reviewed via PR before being applied to Cloudflare.  
- 🛡️ **Container Security Scanning** — Trivy scans every image for fixable CRITICAL CVEs before push; the build is blocked if any are found. CRITICAL/HIGH findings are also uploaded to the GitHub Security tab as SARIF reports.

---

## 🚀 GitOps with Argo CD

Argo CD continuously monitors the Git repository and ensures the live cluster state matches the configuration in Git.

### Features
- **Real-time Sync:** Watches the `master` branch and auto-applies changes.  
- **Self-Heal:** Detects and reverts manual changes to cluster resources.  
- **Pruning:** Cleans up old resources automatically.  
- **Visual Management:** View deployments via the **Argo CD UI** → [argocd.blainweb.com](https://argocd.blainweb.com).  
- Integrated with **Caddy + Traefik** for HTTPS ingress and Let's Encrypt certificates.

### Configuration

| Property | Value |
|-----------|--------|
| **Namespace** | `argocd` |
| **Repository** | `DevOps-Project` |
| **Sync Policy** | Auto-sync, self-heal, prune |
| **App Namespace** | `qr` |
| **Managed Path** | `k8s/` |

---

## 🌐 DNS Management (Terraform + Cloudflare)

DNS records for all subdomains are managed as Infrastructure-as-Code using Terraform, defined in the `terraform/` directory.

- Changes go through a **PR → plan comment → merge → auto-apply** flow
- State is stored remotely in **Backblaze B2** (`terraform-state-blain` bucket)
- All subdomains route through the **Cloudflare Tunnel (qr-pi)** via proxied CNAME records

| Subdomain | Type | Target |
|-----------|------|--------|
| `qr.blainweb.com` | CNAME | Cloudflare Tunnel |
| `cv.blainweb.com` | CNAME | Cloudflare Tunnel |
| `grafana.blainweb.com` | CNAME | Cloudflare Tunnel |

---

## ☁️ Backups & Disaster Recovery (Velero + Backblaze B2)

Velero automatically backs up all cluster resources and persistent volumes to **Backblaze B2**.

### Production Backup Configuration

| Setting | Value |
|----------|--------|
| **Provider** | `aws` (S3-compatible) |
| **Bucket** | `velero-blain-backups` |
| **Endpoint** | `https://s3.eu-central-003.backblazeb2.com` |
| **Schedule** | Daily at 03:00 UTC (`infra/velero/schedule-daily.yaml`) |
| **Namespaces** | `qr`, `kube-system` |
| **Retention (TTL)** | 168 hours (7 days) |

### Validation & Cleanup
- **Restore Test** (Mondays 02:30 UTC): `scripts/velero-restore-test.sh` creates a fresh backup of a throwaway namespace, performs a full restore, and verifies data integrity. This is independent of the production daily backup.
- **Cleanup** (Sundays 03:10 UTC): `scripts/velero-cleanup.sh` removes old test backups, retaining the 5 most recent.
- **Fail-Soft Mode:** If Backblaze rate limits are hit, the restore test skips gracefully without failing the pipeline.

### Metrics
Velero exposes metrics on port `8085`, scraped by Prometheus via NodePort `31085`. The metrics service selector targets only the Velero server pod (`name: velero`) to avoid routing to the node-agent, which does not expose backup metrics.

---

## 📊 Monitoring & Observability

> **In transition:** The monitoring stack is migrating from fully self-hosted to a hybrid model using **Grafana Cloud**. Local Prometheus and Grafana continue to run on the Pi; removal of the local Grafana instance is a planned backlog item. The sections below reflect the current live state.

### Metrics Pipeline

**Prometheus** runs locally on the Pi and scrapes all cluster components via NodePort services and Docker targets. Metrics are **forwarded to Grafana Cloud** via `remote_write`, using a `password_file` secrets pattern — the token is written to a gitignored path by GitHub Actions at deploy time, keeping credentials out of the repository entirely.

### Log Pipeline

**Grafana Alloy** runs on the Pi and ships container and system logs to **Grafana Cloud Loki**. This gives centralised log storage and querying without requiring a self-hosted Loki instance. Alloy authenticates using `GRAFANA_CLOUD_LOKI_TOKEN` injected via CI.

### Dashboards & Access

- CPU, memory, and disk usage  
- Pod health and container uptime  
- Velero backup status and last successful timestamp  

Access via: **[grafana.blainweb.com](https://grafana.blainweb.com)** *(secured access only)* — dashboards query Grafana Cloud as the data source.

### Prometheus Scrape Targets

The following targets are scraped locally; all data is also forwarded to Grafana Cloud via `remote_write`.

| Job | Target | Description |
|-----|--------|-------------|
| `prometheus` | `prometheus:9090` | Prometheus self-metrics |
| `node-exporter` | `node-exporter:9100` | Pi host CPU, memory, disk |
| `cadvisor` | `cadvisor:8080` | Docker container metrics |
| `kube-state-metrics` | `host.docker.internal:30090` | Kubernetes object state |
| `cadvisor-k8s` | `host.docker.internal:31090` | Kubernetes pod/container metrics |
| `velero` | `host.docker.internal:31085` | Velero backup metrics |

### Grafana Alert Rules

Alert rules are provisioned from `monitoring/grafana-provisioning/alerting/rules.yaml` and evaluated every minute.

| Alert | Condition | Severity |
|-------|-----------|----------|
| **Pod Crash Looping** | Container restarts > 3 in 15 minutes | Critical |
| **Node CPU High** | CPU usage > 80% for 5 minutes | Warning |
| **Node Memory High** | Memory usage > 85% for 5 minutes | Warning |
| **Node Disk Usage High** | Disk usage > 80% for 5 minutes | Warning |
| **Deployment Has No Ready Pods** | Available replicas < 1 for 5 minutes | Critical |
| **Velero Backup Not Completing** | `daily-backup` schedule not succeeded in 25+ hours | Warning |
| **PersistentVolume Almost Full** | PV usage > 85% for 5 minutes | Warning |
| **Pod OOMKilled** | Container terminated with OOMKilled reason | Warning |
| **Monitoring Stack Down** | Prometheus or kube-state-metrics unreachable for 2 minutes | Critical |

Alerts are delivered via **Discord** webhook. The Velero alert targets only the `schedule="daily-backup"` production metric and has a 5-minute grace period to avoid false positives from transient scrape gaps.

---

## 🌍 Hosting Architecture

```plaintext
[Cloudflare Edge]
├── Proxied CNAME records managed by Terraform
└── Tunnel (qr-pi) → cloudflared on Pi → Caddy (port 80)

[Raspberry Pi Cluster]
├── k3s / Kubernetes
│   ├── FastAPI Pod (qr-backend)
│   ├── Next.js Pod (qr-frontend)
│   ├── Velero Server + Node Agent
│   ├── Argo CD (GitOps controller)
│   └── Traefik Ingress Controller
│
├── Docker
│   ├── Caddy (reverse proxy)
│   ├── Grafana + Prometheus (monitoring stack — local; Grafana removal pending)
│   ├── Grafana Alloy (log collector → Grafana Cloud Loki)
│   ├── cAdvisor + Node Exporter (metrics collectors)
│   └── GitHub Actions Runner (Self-Hosted ARM64, always-on)
│
├── Persistent Volumes → Backblaze B2 (via Velero)
│
└── Outbound telemetry → Grafana Cloud
    ├── Prometheus remote_write → Grafana Cloud Metrics
    └── Grafana Alloy → Grafana Cloud Loki (logs)
```

---

## 🔒 Linux & SSH Hardening

The Raspberry Pi nodes run **Ubuntu Server (headless)**, migrated from the default desktop image to reduce attack surface and resource overhead. SSH access is hardened with the following controls:

- **Key-based authentication only** — password authentication is disabled in `sshd_config`.
- **SSH keys managed via GitHub Actions Secrets** (`PI_SSH_KEY`, `PI_SSH_HOST`, `PI_SSH_USER`) — the runner authenticates non-interactively during CI/CD without any stored plain-text credentials.
- The Pi accepts no inbound public internet connections — all external traffic enters via the **Cloudflare Tunnel**, and SSH is only reachable on the local network.

Full migration notes are documented in `ssh-hardening-headless-migration.md`.

---

## 🛠️ Incidents & Lessons Learned

Real operational issues encountered and resolved — included here because they demonstrate the kind of hands-on debugging that production systems require.

| Incident | Root Cause | Fix |
|----------|------------|-----|
| **Prometheus cardinality overage** | High-cardinality labels (per-request label dimensions) caused metric series to spike, exceeding Grafana Cloud's free-tier limit. | Identified offending jobs via the Grafana Cloud usage dashboard, dropped high-cardinality labels using `metric_relabel_configs`, and added a `sample_limit` guard in the scrape config. |
| **YAML duplicate-key crash loop** | A duplicate key in a Kubernetes manifest (`env:` block) was silently accepted by `kubectl apply` but caused the pod to enter a crash loop at runtime. | Traced via pod logs and `kubectl describe`; fixed the manifest and added YAML linting (`yamllint`) to the CI pipeline to catch this class of error before deployment. |
| **GHCR token expiry / image pull failure** | The k3s image pull secret (`GHCR_READ_TOKEN`) expired, causing new pod deployments to fail with `ImagePullBackOff`. | Rotated the token in GitHub Secrets and re-ran the CI workflow to re-provision the k3s pull secret. Documented token rotation as a recurring maintenance task. |

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
| **Monitoring** | Grafana, Prometheus, Grafana Cloud |
| **Log Shipping** | Grafana Alloy → Grafana Cloud Loki |
| **Alerting** | Grafana Alerting → Discord |
| **Backups** | Velero |
| **Reverse Proxy** | Caddy → Traefik |
| **DNS / Tunneling** | Cloudflare Tunnel, Terraform |
| **IaC State** | Backblaze B2 |
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
- 📈 Production-grade observability, alerting, and monitoring.  
- 🌍 Infrastructure-as-Code DNS management via Terraform with full GitOps review flow.

---

## ✅ Current Status

- All services (Frontend, Backend, Grafana, Argo CD, Velero) are live and healthy.  
- Argo CD auto-syncs all new deployments from `master`.  
- Velero performs daily verified backups to Backblaze B2 with 7-day retention.  
- Grafana dashboards actively monitor cluster health with Discord alerting for 9 alert conditions.  
- Metrics forward to **Grafana Cloud** via Prometheus `remote_write`; logs ship via **Grafana Alloy → Loki** (Grafana Cloud). Local Grafana instance removal is in progress.  
- The GitHub Actions deploy pipeline runs entirely on the **self-hosted ARM64 Pi runner**.  
- Terraform manages all DNS records for blainweb.com subdomains, with state stored in Backblaze B2.  
- Trivy scans every image build for fixable CRITICAL CVEs — results visible in the GitHub Security tab.  
- Liveness and readiness probes active on all deployments; Kubernetes auto-restarts unhealthy pods and withholds traffic until they pass.  
- Pi nodes run **Ubuntu Server (headless)** with SSH hardened to key-based auth only; password authentication disabled.
