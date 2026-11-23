#!/usr/bin/env bash
# ==============================================================================
# 03-deploy-platform-ui.sh
# Krok 3: Konfiguracja Common Services (NFS StorageClass), dynamiczne pobranie
#         wersji/licencji z CSV operatora, wdrożenie instancji Platform UI (PlatformNavigator 16.2.0)
#         oraz pobranie danych dostępowych.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00-common.sh"
source "${SCRIPT_DIR}/../env.sh"

log_step "KROK 3: Wdrożenie i konfiguracja Platform UI (CP4I 16.2.0 LTS)"

validate_cli
validate_ocp_connection

# 1. Konfiguracja StorageClass dla usług wspólnych (Common Services)
log_step "3.1. Ustawienie StorageClass NFS (${NFS_BLOCK_STORAGE_CLASS}) dla Common Services"
CS_CR_NAME=$(oc get commonservice -A -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "common-service")
CS_CR_NS=$(oc get commonservice -A -o jsonpath='{.items[0].metadata.namespace}' 2>/dev/null || echo "${CS_NAMESPACE}")

if oc get CommonService "${CS_CR_NAME}" -n "${CS_CR_NS}" &>/dev/null; then
    log_info "Aktualizacja istniejącego zasobu CommonService '${CS_CR_NAME}' w '${CS_CR_NS}'..."
    oc patch CommonService "${CS_CR_NAME}" -n "${CS_CR_NS}" --type=merge --patch '{"spec":{"storageClass":"'"${NFS_BLOCK_STORAGE_CLASS}"'"}}' || true
else
    log_info "Aplikowanie CommonService z 03-platform-ui/01-common-services-config.yaml..."
    oc apply -f "${SCRIPT_DIR}/../03-platform-ui/01-common-services-config.yaml" || true
fi

# 2. Pobranie informacji o wersji i licencji z CSV operatora Platform Navigator
log_step "3.2. Odczyt wersji i licencji z zainstalowanego operatora Platform Navigator..."
SUB_NAME=$(oc get deployment ibm-integration-platform-navigator-operator -n "${OPERATOR_NAMESPACE}" -o jsonpath='{.metadata.labels.olm\.owner}' 2>/dev/null || true)
INST_VER=""
INST_LIC=""

if [[ -n "${SUB_NAME}" ]]; then
    INST_VER=$(oc get csv "${SUB_NAME}" -n "${OPERATOR_NAMESPACE}" -o json 2>/dev/null | jq -r '.metadata.annotations."alm-examples" | fromjson | [.[] | select(.kind == "PlatformNavigator")] | .[] | select(.metadata.name == "integration-quickstart") | .spec.version' 2>/dev/null || true)
    INST_LIC=$(oc get csv "${SUB_NAME}" -n "${OPERATOR_NAMESPACE}" -o json 2>/dev/null | jq -r '.metadata.annotations."alm-examples" | fromjson | [.[] | select(.kind == "PlatformNavigator")] | .[] | select(.metadata.name == "integration-quickstart") | .spec.license.license' 2>/dev/null || true)
fi

# Domyślne wartości LTS dla CP4I 16.2.0
INST_VER="${INST_VER:-${PN_VERSION:-16.2.0}}"
INST_LIC="${INST_LIC:-L-VAD2-N2WPMY}"
log_info "Wersja Platform UI: ${INST_VER}, Licencja: ${INST_LIC}"

# 3. Wdrożenie instancji PlatformNavigator
log_step "3.3. Wdrożenie instancji PlatformNavigator (${PLATFORM_NAVIGATOR_NAME}) w ${CP4I_NAMESPACE}"
cat <<EOF | oc apply -n "${CP4I_NAMESPACE}" -f -
apiVersion: integration.ibm.com/v1beta1
kind: PlatformNavigator
metadata:
  name: ${PLATFORM_NAVIGATOR_NAME}
  namespace: ${CP4I_NAMESPACE}
spec:
  license:
    accept: true
    license: ${INST_LIC}
  replicas: 1
  version: ${INST_VER}
EOF

# 4. Oczekiwanie na gotowość Platform UI
log_step "3.4. Oczekiwanie na uruchomienie Platform UI (może to zająć kilka minut)..."
wait_for_cr_ready "platformnavigator" "${PLATFORM_NAVIGATOR_NAME}" "${CP4I_NAMESPACE}" 120

# 5. Wyświetlenie danych dostępowych
log_step "3.5. Pobieranie danych dostępowych do Platform UI"
bash "${SCRIPT_DIR}/../03-platform-ui/03-get-access-info.sh"

log_success "Krok 3 zakończony pomyślnie. Platform UI jest w pełni funkcjonalne."
