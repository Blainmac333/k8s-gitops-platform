#!/usr/bin/env bash
set -euo pipefail

KEEP=5
NS=velero
LABEL='app=velero-restore-test'

usage() {
  echo "Usage: $0 [--keep N]" >&2
}

# -------- args --------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep)
      KEEP="${2:-}"; shift 2;;
    -h|--help)
      usage; exit 0;;
    *)
      echo "Unknown arg: $1" >&2; usage; exit 1;;
  esac
done

if ! [[ "$KEEP" =~ ^[0-9]+$ ]]; then
  echo "❌ --keep must be an integer (got: '$KEEP')" >&2
  exit 1
fi

echo "== Velero cleanup =="
echo "Namespace          : $NS"
echo "Label selector     : $LABEL"
echo "Keep most recent   : $KEEP"

echo
echo "--> Collecting test backups…"
# Output as: name|timestamp (RFC3339)
mapfile -t PAIRS < <(
  kubectl -n "$NS" get backup -l "$LABEL" \
    -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.metadata.creationTimestamp}{"\n"}{end}' \
  | sed '/^$/d' || true
)

TOTAL=${#PAIRS[@]}
if (( TOTAL == 0 )); then
  echo "No test backups found — nothing to do."
  exit 0
fi

# Sort by timestamp ascending (oldest first)
IFS=$'\n' read -r -d '' -a SORTED < <(printf '%s\n' "${PAIRS[@]}" | sort -t'|' -k2,2 && printf '\0')

echo "Found $TOTAL test backups."
if (( TOTAL <= KEEP )); then
  echo "Nothing to delete (<= $KEEP present)."
else
  DEL=$(( TOTAL - KEEP ))
  echo
  echo "--> Deleting $DEL backups older than the most-recent $KEEP:"
  printf '%s\n' "${SORTED[@]}" | head -n "$DEL" | while IFS='|' read -r NAME TS; do
    echo "Deleting backup: $NAME (created $TS)"
    # Deleting the Backup CR triggers object cleanup in the BSL
    kubectl -n "$NS" delete backup "$NAME" --wait=false || true
  done
fi

echo
echo "--> Tidying old test restores (older than 7 days)…"
mapfile -t RPAIRS < <(
  kubectl -n "$NS" get restore -l "$LABEL" \
    -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.metadata.creationTimestamp}{"\n"}{end}' \
  | sed '/^$/d' || true
)

if (( ${#RPAIRS[@]} > 0 )); then
  NOW_S=$(date -u +%s)
  for LINE in "${RPAIRS[@]}"; do
    NAME="${LINE%%|*}"
    TS="${LINE##*|}"
    # Convert RFC3339 -> epoch (GNU date first, BSD/macOS fallback next)
    TS_S=$(date -u -d "$TS" +%s 2>/dev/null || date -u -jf "%Y-%m-%dT%H:%M:%SZ" "$TS" +%s)
    AGE_D=$(( (NOW_S - TS_S) / 86400 ))
    if (( AGE_D >= 7 )); then
      echo "Deleting restore: $NAME (age ${AGE_D}d)"
      kubectl -n "$NS" delete restore "$NAME" --wait=false || true
    fi
  done
else
  echo "No test restores found."
fi

echo
echo "Cleanup complete ✅"