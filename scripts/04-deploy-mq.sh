#!/usr/bin/env bash
# ==============================================================================
# 04-deploy-mq.sh
# Krok 4: Wdrożenie podstawowej instalacji IBM MQ (v10.0.x / kanał v4.0-sc2):
#         - Certyfikaty TLS (Cert-Manager)
#         - Route passthrough SNI
#         - ConfigMaps MQSC i INI
#         - Dynamiczne pobranie wersji/licencji z CSV operatora MQ
#         - Adnotacje License Service dla IBM App Connect Enterprise (productMetric: FREE)
#         - Instancja QueueManager CR (SingleInstance na NFS + pki.trust)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00-common.sh"
source "${SCRIPT_DIR}/../env.sh"

log_step "KROK 4: Wdrożenie podstawowej instalacji IBM MQ (QueueManager - licencja ACE)"

validate_cli
validate_ocp_connection

# 1. Tworzenie certyfikatu TLS dla QueueManagera
log_step "4.1. Tworzenie certyfikatu TLS dla MQ"
oc apply -f "${SCRIPT_DIR}/../04-mq/01-mq-pki-certificate.yaml" -n "${CP4I_NAMESPACE}"

log_info "Oczekiwanie na gotowość certyfikatu TLS 'qmgr-demo-selfsigned-cert'..."
oc wait --for=condition=Ready certificate/qmgr-demo-selfsigned-cert -n "${CP4I_NAMESPACE}" --timeout=300s
log_success "Certyfikat TLS wygenerowany pomyślnie."

# 2. Tworzenie Route dla kanału MQ
log_step "4.2. Tworzenie OpenShift Route dla kanału MQ (Passthrough SNI)"
oc apply -f "${SCRIPT_DIR}/../04-mq/02-mq-tls-route.yaml" -n "${CP4I_NAMESPACE}"

# 3. Tworzenie ConfigMaps z MQSC i INI
log_step "4.3. Tworzenie ConfigMaps (MQSC i INI)"
oc apply -f "${SCRIPT_DIR}/../04-mq/03-mq-mqsc-configmap.yaml" -n "${CP4I_NAMESPACE}"
oc apply -f "${SCRIPT_DIR}/../04-mq/04-mq-ini-configmap.yaml" -n "${CP4I_NAMESPACE}"

# 4. Pobranie informacji o wersji i licencji z CSV operatora MQ
log_step "4.4. Odczyt wersji i licencji z zainstalowanego operatora IBM MQ..."
SUB_NAME=$(oc get deployment ibm-mq-operator -n "${OPERATOR_NAMESPACE}" -o jsonpath='{.metadata.labels.olm\.owner}' 2>/dev/null || true)
INST_MQ_VER=""
INST_LIC=""

if [[ -n "${SUB_NAME}" ]]; then
    INST_MQ_VER=$(oc get csv "${SUB_NAME}" -n "${OPERATOR_NAMESPACE}" -o json 2>/dev/null | jq -r '.metadata.annotations."alm-examples" | fromjson | [.[] | select(.kind == "QueueManager")] | .[] | select(.metadata.name == "quickstart-cp4i") | .spec.version' 2>/dev/null || true)
    INST_LIC=$(oc get csv "${SUB_NAME}" -n "${OPERATOR_NAMESPACE}" -o json 2>/dev/null | jq -r '.metadata.annotations."alm-examples" | fromjson | [.[] | select(.kind == "QueueManager")] | .[] | select(.metadata.name == "quickstart-cp4i") | .spec.license.license' 2>/dev/null || true)
fi

# Domyślne wartości LTS dla MQ v10 w razie braku danych w CSV
INST_MQ_VER="${INST_MQ_VER:-${MQ_VERSION:-10.0.1.0-r1}}"
INST_LIC="${INST_LIC:-${MQ_LICENSE:-L-VCNK-GTT2F3}}"
log_info "Wersja IBM MQ: ${INST_MQ_VER}, Licencja: ${INST_LIC}, StorageClass: ${NFS_BLOCK_STORAGE_CLASS}"

# 5. Wdrożenie instancji QueueManager z adnotacjami License Service dla ACE, PKI Trust i supplementalGroups NFS
log_step "4.5. Wdrożenie instancji QueueManager (${QMGR_NAME}) z adnotacjami licencyjnymi dla ACE, PKI Trust i uprawnieniami NFS"
cat <<EOF | oc apply -n "${CP4I_NAMESPACE}" -f -
apiVersion: mq.ibm.com/v1beta1
kind: QueueManager
metadata:
  name: ${QMGR_NAME}
  namespace: ${CP4I_NAMESPACE}
spec:
  annotations:
    productMetric: FREE
  license:
    accept: true
    license: ${INST_LIC}
    metric: VirtualProcessorCore
    use: ${MQ_LICENSE_USE}
  version: ${INST_MQ_VER}
  securityContext:
    initVolumeAsRoot: false
    readOnlyRootFilesystem: false
    supplementalGroups:
      - 65534
  pki:
    keys:
      - name: default
        secret:
          secretName: qmgr-demo-tls-secret
          items:
            - tls.key
            - tls.crt
    trust:
      - name: cp4ica
        secret:
          secretName: qmgr-demo-tls-secret
          items:
            - ca.crt
  queueManager:
    name: ${QM_NAME_UPPER}
    resources:
      limits:
        cpu: '1'
        memory: 1Gi
      requests:
        cpu: '1'
        memory: 1Gi
    availability:
      type: SingleInstance
    storage:
      allowVolumeExpansion: false
      defaultClass: ${NFS_BLOCK_STORAGE_CLASS}
      persistedData:
        enabled: true
        size: 2Gi
        type: persistent-claim
      queueManager:
        size: 2Gi
        type: persistent-claim
      recoveryLogs:
        enabled: true
        size: 2Gi
        type: persistent-claim
      scratch:
        enabled: true
      tmp:
        enabled: true
    ini:
      - configMap:
          name: mq-demo-ini
          items:
            - mq-demo-resources.ini
    mqsc:
      - configMap:
          name: mq-demo-mqsc
          items:
            - mq-demo-resources.mqsc
  web:
    console:
      authentication:
        provider: integration-keycloak
      authorization:
        provider: integration-keycloak
    enabled: true
    route:
      enabled: true
EOF

# 6. Oczekiwanie na gotowość QueueManagera
log_step "4.6. Oczekiwanie na fazę Running QueueManagera..."
wait_for_cr_ready "queuemanager" "${QMGR_NAME}" "${CP4I_NAMESPACE}" 60

log_success "Krok 4 zakończony pomyślnie. IBM MQ QueueManager jest uruchomiony z licencją powiązaną z ACE."
