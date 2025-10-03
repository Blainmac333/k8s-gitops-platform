#!/usr/bin/env bash
set -euo pipefail

# Unique test namespace + names
NS="velero-restore-test-$(date +%Y%m%d-%H%M)"
B="test-backup-$(date +%H%M%S)"
R="test-restore-$(date +%H%M%S)"

# Label (as key/value for Kubernetes) and selector form for kubectl -l
LABEL_KEY="app"
LABEL_VAL="velero-restore-test"
LABEL_SELECTOR="${LABEL_KEY}=${LABEL_VAL}"

echo "== Velero restore test =="
echo "Namespace : $NS"
echo "Backup    : $B"
echo "Restore   : $R"
echo "Label     : $LABEL_SELECTOR"
echo

# --- Preflight: ensure BSL usable; skip if Backblaze caps are exceeded ---
BSL_PHASE=$(kubectl -n velero get backupstoragelocation default -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
BSL_MSG=$(kubectl -n velero get backupstoragelocation default -o jsonpath='{.status.message}' 2>/dev/null || echo "")
if [[ "$BSL_PHASE" != "Available" ]]; then
  if [[ "$BSL_MSG" == *"Transaction cap exceeded"* ]]; then
    echo "⚠️  Skipping restore test: Backblaze B2 transaction cap exceeded."
    exit 0
  fi
  echo "❌ BSL not Available ($BSL_PHASE). Details:"
  kubectl -n velero describe backupstoragelocation default || true
  exit 1
fi

# 1) Create a test namespace and a simple object to verify later
echo "--> Create test namespace + object"
kubectl create ns "$NS"
kubectl -n "$NS" create configmap demo --from-literal=foo=bar

# 2) Take a Velero backup (label it so cleanup can find it)
echo "--> Create backup"
cat <<EOF | kubectl -n velero apply -f -
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: ${B}
  labels:
    ${LABEL_KEY}: ${LABEL_VAL}
spec:
  storageLocation: default
  includedNamespaces:
  - "${NS}"
  ttl: 24h
EOF

# Wait for backup to complete (or fail fast)
for i in {1..60}; do
  p=$(kubectl -n velero get backup "$B" -o jsonpath='{.status.phase}' 2>/dev/null || echo "?")
  echo "Backup phase: $p"
  [[ "$p" == "Completed" ]] && break
  [[ "$p" =~ Failed|PartiallyFailed|FailedValidation ]] && { kubectl -n velero describe backup "$B"; exit 1; }
  sleep 2
done

# 3) Simulate loss: remove the namespace
echo "--> Simulate loss (delete ns)"
kubectl delete ns "$NS" --wait=true

# 4) Restore the backup (label the restore too)
echo "--> Restore"
cat <<EOF | kubectl -n velero apply -f -
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: ${R}
  labels:
    ${LABEL_KEY}: ${LABEL_VAL}
spec:
  backupName: ${B}
EOF

# Wait for restore to complete (or fail fast)
for i in {1..60}; do
  rp=$(kubectl -n velero get restore "$R" -o jsonpath='{.status.phase}' 2>/dev/null || echo "?")
  echo "Restore phase: $rp"
  [[ "$rp" == "Completed" ]] && break
  [[ "$rp" =~ Failed|PartiallyFailed ]] && { kubectl -n velero describe restore "$R"; exit 1; }
  sleep 2
done

# 5) Verify the restored object
echo "--> Verify"
VAL=$(kubectl -n "$NS" get cm demo -o jsonpath='{.data.foo}' 2>/dev/null || echo "")
if [[ "$VAL" == "bar" ]]; then
  echo "Restore test OK ✅"
else
  echo "Restore test FAILED (expected foo=bar, got: '$VAL')" >&2
  exit 1
fi