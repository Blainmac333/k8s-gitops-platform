# Credential Management

This document covers how admin credentials are managed for Grafana and Argo CD, and how to reset them if needed.

---

## Grafana

### How credentials are set

Grafana reads its admin username and password from environment variables injected via a `.env` file on the Pi. A safe template is committed to the repo at `grafana.env.example` — the actual file lives only on the Pi and is never committed.

**File:** `grafana.env` (on Pi, not in git)
```
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=your-password-here
GF_SERVER_ROOT_URL=https://grafana.blainweb.com
```

### Initial setup / recovery

1. SSH into the Pi.
2. Copy the example file if `grafana.env` doesn't exist:
   ```bash
   cp grafana.env.example grafana.env
   ```
3. Edit it with your real password:
   ```bash
   nano grafana.env
   ```
4. Restart the Grafana container to apply:
   ```bash
   docker compose restart grafana
   # or, if using docker run directly:
   docker stop grafana && docker start grafana
   ```

### Resetting the password

If you need to change the password, update `grafana.env` on the Pi and restart Grafana as above. You can also reset it from the Grafana CLI without restarting:
```bash
docker exec -it grafana grafana-cli admin reset-admin-password NEW_PASSWORD
```

---

## Argo CD

### How credentials are set

ArgoCD's admin password is set via a **bcrypt hash** stored directly in the Helm chart values at `infra/argocd/helmchart.yaml`. This means the password is defined in Git (as a hash, not plaintext) and survives any redeployment.

**File:** `infra/argocd/helmchart.yaml`
```yaml
configs:
  secret:
    argoAdminPassword: "$2a$10$..."   # bcrypt hash of the password
    argoAdminPasswordMtime: "YYYY-MM-DDT00:00:00Z"
```

The plaintext password is stored only in your password manager. The bcrypt hash is safe to commit.

### Changing the password

1. Generate a new bcrypt hash on the Pi:
   ```bash
   sudo apt install apache2-utils   # if not already installed
   htpasswd -nbBC 10 "" YOUR_NEW_PASSWORD | tr -d ':\n' | sed 's/$2y/$2a/'
   ```
2. Copy the output (starts with `$2a$10$...`).
3. Create a new branch and update `infra/argocd/helmchart.yaml`:
   - Replace the `argoAdminPassword` value with the new hash.
   - Update `argoAdminPasswordMtime` to today's date.
4. Commit, push, and open a PR. After merge, Argo CD will sync and apply the new password automatically.

### Recovering a lost password

If the current hash in `helmchart.yaml` is unknown or you are locked out:

1. Generate a new bcrypt hash as above using your desired password.
2. Update `helmchart.yaml` with the new hash and today's timestamp via a PR.
3. After the PR merges and Argo CD syncs, log in with the new password.

Alternatively, recover the current password directly from the cluster (only works if `argocd-initial-admin-secret` still exists):
```bash
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d && echo
```
This secret is often deleted after first login, so it may not be present.

---

## Summary

| Service  | Credential storage         | Where to update               | Plaintext in git? |
|----------|----------------------------|-------------------------------|-------------------|
| Grafana  | `grafana.env` on Pi        | Edit file on Pi, restart      | No                |
| Argo CD  | bcrypt hash in `helmchart.yaml` | PR to update the hash    | No (hash only)    |
