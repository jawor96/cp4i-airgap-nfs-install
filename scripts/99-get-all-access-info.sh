#!/usr/bin/env bash
# ==============================================================================
# 99-get-all-access-info.sh
# Podsumowanie adresów URL, konsol, portów oraz danych logowania do wszystkich
# wdrożonych komponentów CP4I, MQ, ACE Dashboard oraz ACH.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00-common.sh"
source "${SCRIPT_DIR}/../env.sh"

echo "================================================================================"
echo "          DANE DOSTĘPOWE DO ŚRODOWISKA IBM CLOUD PAK FOR INTEGRATION"
echo "================================================================================"

# 1. Platform UI
bash "${SCRIPT_DIR}/../03-platform-ui/03-get-access-info.sh"

# 2. IBM MQ
echo ""
echo "--------------------------------------------------------------------------------"
echo " IBM MQ Queue Manager (${QMGR_NAME} / ${QM_NAME_UPPER})"
echo "--------------------------------------------------------------------------------"
MQ_SVC_HOST="${QMGR_NAME}-ibm-mq.${CP4I_NAMESPACE}.svc.cluster.local"
MQ_PORT="1414"
MQ_CHL_INTERNAL="ACE.TO.MQ (SVRCONN wewnątrz klastra)"
MQ_CHL_EXTERNAL="EXTAPP.TO.MQ (TLS 1.3 przez Passthrough SNI Route)"
MQ_ROUTE=$(oc get route "${QMGR_NAME}-tls-route" -n "${CP4I_NAMESPACE}" -o jsonpath='{.spec.host}' 2>/dev/null || echo "Brak zdefiniowanej trasy")

echo " Wewnętrzny adres usługi (K8s Service) : ${MQ_SVC_HOST}:${MQ_PORT}"
echo " Kanał wewnętrzny dla ACE / ACH        : ${MQ_CHL_INTERNAL}"
echo " Kanał zewnętrzny (SNI Route TLS)      : ${MQ_CHL_EXTERNAL}"
echo " Trasa zewnętrzna SNI (Route TLS)      : ${MQ_ROUTE}:443"
echo " Konsola Web MQ                        : Dostępna bezpośrednio z poziomu Platform UI"

# 3. App Connect Dashboard
echo ""
echo "--------------------------------------------------------------------------------"
echo " App Connect Dashboard (${ACE_DASHBOARD_NAME})"
echo "--------------------------------------------------------------------------------"
DASH_URL=$(oc get dashboard "${ACE_DASHBOARD_NAME}" -n "${CP4I_NAMESPACE}" -o jsonpath='{.status.endpoints[?(@.name=="ui")].uri}' 2>/dev/null || echo "Brak")
echo " Adres URL Dashboardu                  : ${DASH_URL}"
echo " Dostęp przez Platform UI              : Kafelek 'App Connect' w Platform UI"

# 4. ACE Integration Runtime & ACH (Healthcare)
echo ""
echo "--------------------------------------------------------------------------------"
echo " App Connect Integration Runtimes & ACH (Healthcare)"
echo "--------------------------------------------------------------------------------"
echo " Runtime bazowy (${ACE_IR_NAME})       : Zarządzany z poziomu App Connect Dashboard"
echo " Runtime ACH HL7 (${ACE_ACH_IR_NAME})   : Port MLLP TCP: 1111 (NodePort: 30131)"
echo " Kolejki wejściowe ACH w MQ            : HL7.INPUT.Q, HL7.OUTPUT.Q, HL7.ERROR.Q"

echo "================================================================================"
