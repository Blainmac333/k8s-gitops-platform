# Alerting Runbook

This document covers all 9 Grafana alerts. For each: what it means, what to check, and how to fix it.

---

## 1. Pod Crash Looping

**What it means:** A pod has restarted more than 3 times in 15 minutes. The container is starting, crashing, and being restarted repeatedly by Kubernetes.

**What to check:**
```bash
kubectl get pods -A | grep -v Running
kubectl logs <pod-name> -n <namespace> --previous
kubectl describe pod <pod-name> -n <namespace>
```

**How to fix:**
- Check the previous logs — the exit reason is almost always there
- If it's a config error (bad env var, missing secret), fix the deployment manifest
- If it's an application crash, check the app logs for stack traces
- If it just started after a deploy, roll back: `kubectl rollout undo deployment/<name> -n <namespace>`

---

## 2. Node CPU High

**What it means:** CPU usage has been above 80% for more than 5 minutes. On a Pi this can cause slowdowns and cascading pod failures.

**What to check:**
```bash
kubectl top nodes
kubectl top pods -A --sort-by=cpu
```

**How to fix:**
- Identify the top CPU consumer from `kubectl top pods`
- If it's a runaway pod, restart it: `kubectl rollout restart deployment/<name> -n <namespace>`
- If it's sustained load, consider adding CPU limits to the deployment manifest
- Check if a CronJob or batch task triggered the spike — it may resolve on its own

---

## 3. Node Memory High

**What it means:** Memory usage has been above 85% for more than 5 minutes. At this level the kernel may start OOM-killing processes.

**What to check:**
```bash
kubectl top nodes
kubectl top pods -A --sort-by=memory
free -h  # run on the Pi directly
```

**How to fix:**
- Identify the top memory consumer from `kubectl top pods`
- Restart the offending pod if it appears to be leaking memory
- If memory is genuinely exhausted, consider reducing replica counts or tightening memory limits on non-critical workloads
- Check for OOMKilled events: `kubectl get events -A | grep OOMKill`

---

## 4. Node Disk Usage High

**What it means:** The root filesystem on the Pi is above 80% full. Kubernetes will start evicting pods if disk hits 85–90%.

**What to check:**
```bash
df -h  # run on the Pi directly
du -sh /var/log/* | sort -h
kubectl get pods -A  # check for evicted pods
```

**How to fix:**
- Clear old container images: `sudo crictl rmi --prune` or `sudo docker system prune -a` depending on runtime
- Check `/var/log` for large log files and rotate or delete old ones
- Check Velero backup storage if it's writing locally
- If a PV is the culprit, see the PersistentVolume Almost Full runbook entry below

---

## 5. Deployment Has No Ready Pods

**What it means:** A deployment outside of `kube-system` has had zero available replicas for more than 5 minutes. The service is completely down.

**What to check:**
```bash
kubectl get deployments -A | grep -v kube-system
kubectl describe deployment <name> -n <namespace>
kubectl get pods -n <namespace>
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

**How to fix:**
- Check events for ImagePullBackOff (bad image tag), Pending (resource pressure), or CrashLoopBackOff
- If ImagePullBackOff: verify the image tag exists in the registry and the GitOps pipeline deployed the correct SHA
- If Pending: check node resources with `kubectl top nodes` — the Pi may be under pressure
- If CrashLoopBackOff: follow the Pod Crash Looping runbook above

---

## 6. Velero Backup Not Completing

**What it means:** No successful Velero backup has completed in over 25 hours. Your cluster state is not being backed up.

**What to check:**
```bash
velero backup get
velero backup describe <latest-backup-name>
velero backup logs <latest-backup-name>
kubectl get pods -n velero
```

**How to fix:**
- Check backup logs for storage errors (S3/Backblaze connectivity, credentials)
- Verify the Velero pod is running: `kubectl get pods -n velero`
- Check that the GitHub Actions backup workflow ran: look at Actions → Velero schedule
- If credentials expired, update the Backblaze secret in the cluster and re-run the workflow manually
- Trigger a manual backup to test: `velero backup create manual-test --include-namespaces default`

---

## 7. PersistentVolume Almost Full

**What it means:** A PersistentVolume has exceeded 85% capacity. If it fills completely, the pod using it will crash or enter a read-only error state.

**What to check:**
```bash
kubectl get pvc -A
kubectl exec -n <namespace> <pod-name> -- df -h  # check from inside the pod
```

**How to fix:**
- Identify which PVC is full from the alert labels
- Delete old data inside the volume if possible (logs, temp files, old DB records)
- If it's a database PV, run a cleanup query or archive old rows
- If the workload genuinely needs more space, resize the PVC (requires the StorageClass to support expansion)

---

## 8. Pod OOMKilled

**What it means:** A container was killed by the Linux kernel because it exceeded its memory limit. This is different from a crash — the process was forcibly terminated.

**What to check:**
```bash
kubectl get events -A | grep OOMKill
kubectl describe pod <pod-name> -n <namespace>  # look for OOMKilled in Last State
kubectl top pods -n <namespace>
```

**How to fix:**
- Check the pod's current memory limit: `kubectl get pod <name> -n <namespace> -o yaml | grep -A5 resources`
- If the limit is too low for normal operation, increase it in the deployment manifest
- If memory usage is unexpected (leak), check application logs for the cause before just raising the limit
- If it's a one-off spike, monitor and only act if it recurs

---

## 9. Monitoring Stack Down

**What it means:** Prometheus or kube-state-metrics has been unreachable for 2 minutes. Your other alerts may not be firing — you are effectively blind.

**What to check:**
```bash
kubectl get pods -n monitoring
kubectl logs -n monitoring deployment/prometheus
kubectl logs -n monitoring deployment/kube-state-metrics
```

**How to fix:**
- If the pod is crashing, check logs for the root cause (config error, OOM, disk full)
- If the pod is pending, check node resources — the Pi may be under pressure
- If Prometheus storage is full, the TSDB will refuse writes; clear old data or reduce retention in the Prometheus config
- Restart if needed: `kubectl rollout restart deployment/prometheus -n monitoring`
- After restoring, verify alert rules are evaluating again in Grafana → Alerting → Alert rules
