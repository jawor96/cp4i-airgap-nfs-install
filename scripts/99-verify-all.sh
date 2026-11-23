#!/usr/bin/env bash
# ==============================================================================
# 99-verify-all.sh
# Kompleksowa weryfikacja stanu instalacji CP4I, MQ, ACE i ACH
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00-common.sh"
source "${SCRIPT_DIR}/../env.sh"

echo "=========================================================="
echo " PEŁNY RAPORT STANU INSTALACJI CP4I"
echo "=========================================================="

validate_cli
validate_ocp_connection

# 1. Sprawdzenie Operatorów (CSV)
log_step "1. Stan Operatorów OLM (CSV):"
oc get csv -n "${OPERATOR_NAMESPACE}" -o custom-columns='NAME:.metadata.name,DISPLAY:.spec.displayName,VERSION:.spec.version,PHASE:.status.phase' | grep -E '^NAME|ibm|cert-manager' || true

# 2. Sprawdzenie Instancji Platform UI
log_step "2. Stan Platform UI (PlatformNavigator):"
oc get platformnavigator -n "${CP4I_NAMESPACE}" -o custom-columns='NAME:.metadata.name,REPLICAS:.spec.replicas,READY:.status.conditions[?(@.type=="Ready")].status,MESSAGE:.status.conditions[?(@.type=="Ready")].message' || true

# 3. Sprawdzenie Instancji IBM MQ
log_step "3. Stan IBM MQ (QueueManager):"
oc get queuemanager -n "${CP4I_NAMESPACE}" -o custom-columns='NAME:.metadata.name,PHASE:.status.phase,VERSION:.status.currentVersion,RECONCILED:.status.conditions[?(@.type=="Reconciled")].status' || true

# 4. Sprawdzenie Instancji App Connect Dashboard
log_step "4. Stan App Connect Dashboard:"
oc get dashboard -n "${CP4I_NAMESPACE}" -o custom-columns='NAME:.metadata.name,PHASE:.status.phase,REPLICAS:.spec.replicas,STORAGE:.spec.storage.class' || true

# 5. Sprawdzenie Instancji ACE Integration Runtime
log_step "5. Stan ACE Integration Runtime (w tym ACH):"
oc get integrationruntime -n "${CP4I_NAMESPACE}" -o custom-columns='NAME:.metadata.name,PHASE:.status.phase,REPLICAS:.spec.replicas,VERSION:.spec.version' || true

# 6. Sprawdzenie PVC na NFS
log_step "6. Stan wolumenów PersistentVolumeClaims (NFS):"
oc get pvc -n "${CP4I_NAMESPACE}" -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,VOLUME:.spec.volumeName,CAPACITY:.status.capacity.storage,ACCESSMODES:.spec.accessModes,STORAGECLASS:.spec.storageClassName' || true

# 7. Sprawdzenie Podów w namespace
log_step "7. Podsumowanie Podów w przestrzeni ${CP4I_NAMESPACE}:"
oc get pods -n "${CP4I_NAMESPACE}" --sort-by=.metadata.name

echo ""
echo "=========================================================="
log_success "Weryfikacja zakończona."
echo "=========================================================="
