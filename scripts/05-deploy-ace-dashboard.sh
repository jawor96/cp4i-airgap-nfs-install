#!/usr/bin/env bash
# ==============================================================================
# 05-deploy-ace-dashboard.sh
# Krok 5: Wdrożenie instancji App Connect Dashboard (ACH Content Server i Control UI - LTS)
#         z pamięcią masową RWX (NFS).
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00-common.sh"
source "${SCRIPT_DIR}/../env.sh"

log_step "KROK 5: Wdrożenie instancji App Connect Dashboard (ACH - LTS)"

validate_cli
validate_ocp_connection

# 1. Pobranie informacji o wersji i licencji z CSV operatora App Connect
log_step "5.1. Odczyt wersji i licencji z zainstalowanego operatora App Connect..."
SUB_NAME=$(oc get deployment ibm-appconnect-operator -n "${OPERATOR_NAMESPACE}" -o jsonpath='{.metadata.labels.olm\.owner}' 2>/dev/null || true)
INST_VER=""
INST_LIC=""

if [[ -n "${SUB_NAME}" ]]; then
    INST_VER=$(oc get csv "${SUB_NAME}" -n "${OPERATOR_NAMESPACE}" -o json 2>/dev/null | jq -r '.metadata.annotations."alm-examples" | fromjson | [.[] | select(.kind == "Dashboard")] | .[] | select(.metadata.name == "db-01-quickstart") | .spec.version' 2>/dev/null || true)
    INST_LIC=$(oc get csv "${SUB_NAME}" -n "${OPERATOR_NAMESPACE}" -o json 2>/dev/null | jq -r '.metadata.annotations."alm-examples" | fromjson | [.[] | select(.kind == "Dashboard")] | .[] | select(.metadata.name == "db-01-quickstart") | .spec.license.license' 2>/dev/null || true)
fi

# Domyślne wartości LTS dla ACE 13.0 LTS w razie braku danych w CSV
INST_VER="${INST_VER:-${ACE_VERSION:-13.0.9.0-r1}}"
INST_LIC="${INST_LIC:-${ACE_LICENSE:-L-RJGW-BUAA2R}}"
log_info "Wersja App Connect: ${INST_VER}, Licencja: ${INST_LIC}, StorageClass RWX: ${NFS_FILE_STORAGE_CLASS}"

# 2. Wdrożenie Dashboard CR
log_step "5.2. Wdrożenie instancji App Connect Dashboard (${ACE_DASHBOARD_NAME}) na NFS (RWX)"
cat <<EOF | oc apply -n "${CP4I_NAMESPACE}" -f -
apiVersion: appconnect.ibm.com/v1beta1
kind: Dashboard
metadata:
  name: ${ACE_DASHBOARD_NAME}
  namespace: ${CP4I_NAMESPACE}
  labels:
    backup.appconnect.ibm.com/component: dashboard
spec:
  authentication:
    integrationKeycloak:
      enabled: true
  authorization:
    integrationKeycloak:
      enabled: true
  displayMode: IntegrationRuntimes
  license:
    accept: true
    license: ${INST_LIC}
    use: ${LICENSE_USE}
  pod:
    containers:
      content-server:
        resources:
          limits:
            memory: 512Mi
          requests:
            cpu: 50m
            memory: 50Mi
      control-ui:
        resources:
          limits:
            memory: 512Mi
          requests:
            cpu: 50m
            memory: 125Mi
  replicas: 1
  storage:
    size: 5Gi
    type: persistent-claim
    class: ${NFS_FILE_STORAGE_CLASS}
  version: ${INST_VER}
EOF

# 3. Oczekiwanie na gotowość Dashboard
log_step "5.3. Oczekiwanie na uruchomienie App Connect Dashboard..."
wait_for_cr_ready "dashboard" "${ACE_DASHBOARD_NAME}" "${CP4I_NAMESPACE}" 90

# 4. Pobranie adresu URL Dashboardu
DASHBOARD_URL=$(oc get dashboard "${ACE_DASHBOARD_NAME}" -n "${CP4I_NAMESPACE}" -o jsonpath='{.status.endpoints[?(@.name=="ui")].uri}' 2>/dev/null || true)
if [[ -n "${DASHBOARD_URL}" ]]; then
    log_success "App Connect Dashboard jest dostępny pod adresem: ${DASHBOARD_URL}"
fi

log_success "Krok 5 zakończony pomyślnie. App Connect Dashboard jest gotowy."
