#!/usr/bin/env bash
# ==============================================================================
# 02-install-operators.sh
# Krok 2: Instalacja subskrypcji operatorów CP4I 16.2.0 (LTS):
#         - IBM Cloud Pak Foundational Services (v4.19)
#         - IBM Integration Platform Navigator (v8.3-sc2)
#         - IBM MQ (v4.0-sc2)
#         - IBM App Connect (v13.6)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00-common.sh"
source "${SCRIPT_DIR}/../env.sh"

log_step "KROK 2: Wdrożenie Operatorów CP4I 16.2.0 (LTS / SC2)"

validate_cli
validate_ocp_connection

# Funkcja pomocnicza do tworzenia subskrypcji
create_subscription() {
    local sub_name="$1"
    local pkg_name="$2"
    local default_channel="$3"
    local cat_src="${4:-$CATALOG_SOURCE}"
    local cat_src_ns="${5:-$CATALOG_SOURCE_NAMESPACE}"
    local target_ns="${6:-$OPERATOR_NAMESPACE}"
    local approval="${INSTALL_PLAN_APPROVAL:-Automatic}"

    # Weryfikacja kanału z PackageManifest w klastrze (ostrzeżenie w razie różnic)
    local detected_channel=""
    detected_channel=$(oc get packagemanifest "${pkg_name}" -n "${cat_src_ns}" -o jsonpath='{.status.defaultChannel}' 2>/dev/null || true)
    
    local channel="${default_channel}"
    if [[ -n "${detected_channel}" && "${detected_channel}" != "${channel}" ]]; then
        log_warn "Domyślny kanał w katalogu to '${detected_channel}', ale skrypt używa kanału LTS '${channel}' z env.sh"
    fi

    log_info "Tworzenie subskrypcji '${sub_name}' (Pakiet: ${pkg_name}, Kanał: ${channel}, Źródło: ${cat_src}, Approval: ${approval})..."

    cat <<EOF | oc apply -n "${target_ns}" -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ${sub_name}
  namespace: ${target_ns}
spec:
  channel: ${channel}
  installPlanApproval: ${approval}
  name: ${pkg_name}
  source: ${cat_src}
  sourceNamespace: ${cat_src_ns}
EOF
}

# 1. Common Services Operator
log_step "2.1. Instalacja IBM Cloud Pak foundational services (Common Services ${CS_CHANNEL})"
create_subscription "ibm-common-service-operator" "ibm-common-service-operator" "${CS_CHANNEL}"
wait_for_operator_csv "ibm-common-service-operator" "${OPERATOR_NAMESPACE}"

# 2. Platform Navigator (Platform UI) Operator
log_step "2.2. Instalacja IBM Integration Platform Navigator Operator (${PN_CHANNEL})"
create_subscription "ibm-integration-platform-navigator" "ibm-integration-platform-navigator" "${PN_CHANNEL}"
wait_for_operator_csv "ibm-integration-platform-navigator-operator" "${OPERATOR_NAMESPACE}"

# 3. IBM MQ Operator
log_step "2.3. Instalacja IBM MQ Operator (${MQ_CHANNEL})"
create_subscription "ibm-mq" "ibm-mq" "${MQ_CHANNEL}"
wait_for_operator_csv "ibm-mq-operator" "${OPERATOR_NAMESPACE}"

# 4. IBM App Connect Operator
log_step "2.4. Instalacja IBM App Connect Operator (${ACE_CHANNEL})"
create_subscription "ibm-appconnect" "ibm-appconnect" "${ACE_CHANNEL}"
wait_for_operator_csv "ibm-appconnect-operator" "${OPERATOR_NAMESPACE}"

log_success "Krok 2 zakończony pomyślnie. Wszyscy wymagani operatorzy są zainstalowani i gotowi."
