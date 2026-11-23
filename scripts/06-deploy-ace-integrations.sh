#!/usr/bin/env bash
# ==============================================================================
# 06-deploy-ace-integrations.sh
# Krok 6: Wdrożenie konfiguracji ACE (MQ Policy, Serverconf dla ACH, opcjonalny BarAuth)
#         oraz instancji Integration Runtime (podstawowa oraz ACH / HL7 - LTS).
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00-common.sh"
source "${SCRIPT_DIR}/../env.sh"

log_step "KROK 6: Wdrożenie konfiguracji i instancji ACE Integration Runtime (w tym ACH - LTS)"

validate_cli
validate_ocp_connection

# 1. Pobranie informacji o wersji i licencji z CSV operatora App Connect
log_step "6.1. Odczyt wersji i licencji z zainstalowanego operatora App Connect..."
SUB_NAME=$(oc get deployment ibm-appconnect-operator -n "${OPERATOR_NAMESPACE}" -o jsonpath='{.metadata.labels.olm\.owner}' 2>/dev/null || true)
INST_VER=""
INST_LIC=""

if [[ -n "${SUB_NAME}" ]]; then
    INST_VER=$(oc get csv "${SUB_NAME}" -n "${OPERATOR_NAMESPACE}" -o json 2>/dev/null | jq -r '.metadata.annotations."alm-examples" | fromjson | [.[] | select(.kind == "IntegrationRuntime")] | .[] | select(.metadata.name == "ir-01-quickstart") | .spec.version' 2>/dev/null || true)
    INST_LIC=$(oc get csv "${SUB_NAME}" -n "${OPERATOR_NAMESPACE}" -o json 2>/dev/null | jq -r '.metadata.annotations."alm-examples" | fromjson | [.[] | select(.kind == "IntegrationRuntime")] | .[] | select(.metadata.name == "ir-01-quickstart") | .spec.license.license' 2>/dev/null || true)
fi

# Domyślne wartości LTS dla ACE 13.0 LTS w razie braku danych w CSV
INST_VER="${INST_VER:-${ACE_VERSION:-13.0.9.0-r1}}"
INST_LIC="${INST_LIC:-${ACE_LICENSE:-L-RJGW-BUAA2R}}"
log_info "Wersja Integration Runtime: ${INST_VER}, Licencja: ${INST_LIC}"

# 2. Tworzenie obiektów Configuration CR
log_step "6.2. Tworzenie Configuration: policyproject (ace-qmgr-demo-policy)"
oc apply -f "${SCRIPT_DIR}/../05-ace/02-ace-config-mq-policy.yaml" -n "${CP4I_NAMESPACE}"

log_step "6.3. Tworzenie Configuration: serverconf (umed-default-qmgr dla ACH)"
oc apply -f "${SCRIPT_DIR}/../05-ace/03-ace-config-serverconf-ach.yaml" -n "${CP4I_NAMESPACE}"

# Opcjonalne tworzenie barauth tylko, jeśli zdefiniowano BAR_USER i BAR_PASSWORD
if [[ -n "${BAR_USER:-}" && -n "${BAR_PASSWORD:-}" ]]; then
    log_step "6.4. Tworzenie Configuration: barauth (local-barauth)"
    BAR_AUTH_B64=$(echo -n '{"authType": "BASIC_AUTH", "credentials": {"username": "'"${BAR_USER}"'", "password": "'"${BAR_PASSWORD}"'"}}' | base64)
    cat <<EOF | oc apply -n "${CP4I_NAMESPACE}" -f -
apiVersion: appconnect.ibm.com/v1beta1
kind: Configuration
metadata:
  name: local-barauth
  namespace: ${CP4I_NAMESPACE}
spec:
  type: barauth
  description: "Autoryzacja do pobierania plikow BAR"
  data: ${BAR_AUTH_B64}
EOF
fi

# 3. Wdrożenie IntegrationRuntime (podstawowa instancja)
log_step "6.5. Wdrożenie instancji IntegrationRuntime: ${ACE_IR_NAME}"
cat <<EOF | oc apply -n "${CP4I_NAMESPACE}" -f -
apiVersion: appconnect.ibm.com/v1beta1
kind: IntegrationRuntime
metadata:
  name: ${ACE_IR_NAME}
  namespace: ${CP4I_NAMESPACE}
  labels:
    backup.appconnect.ibm.com/component: integrationruntime
spec:
  license:
    accept: true
    license: ${INST_LIC}
    use: ${LICENSE_USE}
  replicas: 1
  version: ${INST_VER}
  template:
    spec:
      containers:
        - name: runtime
          resources:
            limits:
              cpu: 500m
              memory: 512Mi
            requests:
              cpu: 250m
              memory: 256Mi
  configurations:
    - ace-qmgr-demo-policy
EOF

# 4. Wdrożenie IntegrationRuntime dla App Connect for Healthcare (ACH / HL7 MLLP)
log_step "6.6. Wdrożenie instancji IntegrationRuntime dla ACH: ${ACE_ACH_IR_NAME} (wzorowane na 23-ace-is-ach-hl7-instance.yaml z barem z Dashboardu)"
cat <<EOF | oc apply -n "${CP4I_NAMESPACE}" -f -
apiVersion: appconnect.ibm.com/v1beta1
kind: IntegrationRuntime
metadata:
  name: ${ACE_ACH_IR_NAME}
  namespace: ${CP4I_NAMESPACE}
  annotations:
    productChargedContainers: "${ACH_PRODUCT_CHARGED_CONTAINERS}"
    productID: "${ACH_PRODUCT_ID}"
    productName: "${ACH_PRODUCT_NAME}"
    productMetric: "${ACH_PRODUCT_METRIC}"
  labels:
    backup.appconnect.ibm.com/component: integrationruntime
spec:
  license:
    accept: true
    license: ${INST_LIC}
    use: ${LICENSE_USE}
  replicas: 1
  version: ${INST_VER}
  routes:
    disabled: true
  service:
    endpointType: http
    ports:
      - name: mllp
        port: 1111
        targetPort: 1111
        protocol: TCP
        nodePort: 30131
    type: NodePort
  barURL:
    - https://${ACE_DASHBOARD_NAME}-dash.${CP4I_NAMESPACE}:3443/v1/directories/jgr-ach-hl7?archive=true
  template:
    metadata:
      annotations:
        productChargedContainers: "${ACH_PRODUCT_CHARGED_CONTAINERS}"
        productID: "${ACH_PRODUCT_ID}"
        productName: "${ACH_PRODUCT_NAME}"
        productMetric: "${ACH_PRODUCT_METRIC}"
    spec:
      containers:
        - name: runtime
          resources:
            limits:
              cpu: 1
              memory: 1Gi
            requests:
              cpu: 1
              memory: 1Gi
  configurations:
    - ace-qmgr-demo-policy
    - umed-default-qmgr
EOF

# 5. Weryfikacja gotowości
log_step "6.7. Weryfikacja gotowości instancji IntegrationRuntime..."
wait_for_cr_ready "integrationruntime" "${ACE_IR_NAME}" "${CP4I_NAMESPACE}" 60
wait_for_cr_ready "integrationruntime" "${ACE_ACH_IR_NAME}" "${CP4I_NAMESPACE}" 60

log_success "Krok 6 zakończony pomyślnie. Instancje ACE Integration Runtime oraz ACH są wdrożone."
