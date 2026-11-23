#!/usr/bin/env bash
# ==============================================================================
# Skrypt do pobierania adresu URL oraz danych logowania do Platform UI (CP4I 16.2.0)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../env.sh" ]]; then
    source "${SCRIPT_DIR}/../env.sh"
fi

NAMESPACE="${CP4I_NAMESPACE:-cp4i}"
NAVIGATOR_NAME="${PLATFORM_NAVIGATOR_NAME:-cp4i-navigator}"
CS_NS="${CS_NAMESPACE:-ibm-common-services}"

echo "=========================================================="
echo " Pobieranie danych dostępowych do Platform UI (CP4I)..."
echo "=========================================================="

# 1. Pobranie adresu URL Platform UI
echo -n "Pobieranie URL Platform UI... "
URL=$(oc get platformnavigator "${NAVIGATOR_NAME}" -n "${NAMESPACE}" -o jsonpath='{.status.endpoints[?(@.name=="navigator")].uri}' 2>/dev/null || true)

if [[ -z "${URL}" ]]; then
    echo "Platform UI nie posiada jeszcze gotowego endpointu (status Ready może być w trakcie oczekiwania)."
    echo "Sprawdź status: oc get platformnavigator ${NAVIGATOR_NAME} -n ${NAMESPACE}"
    exit 1
fi
echo "OK"

# 2. Pobranie danych logowania administratora (Keycloak SSO w CP4I 16.2.0)
USER="integration-admin"
PASSWORD=""

if oc get secret integration-admin-initial-temporary-credentials -n "${CS_NS}" &>/dev/null; then
    USER=$(oc get secret integration-admin-initial-temporary-credentials -n "${CS_NS}" -o jsonpath='{.data.username}' | base64 -d)
    PASSWORD=$(oc get secret integration-admin-initial-temporary-credentials -n "${CS_NS}" -o jsonpath='{.data.password}' | base64 -d)
elif oc get secret integration-admin-initial-temporary-credentials -n "${NAMESPACE}" &>/dev/null; then
    USER=$(oc get secret integration-admin-initial-temporary-credentials -n "${NAMESPACE}" -o jsonpath='{.data.username}' | base64 -d)
    PASSWORD=$(oc get secret integration-admin-initial-temporary-credentials -n "${NAMESPACE}" -o jsonpath='{.data.password}' | base64 -d)
fi

echo ""
echo "----------------------------------------------------------"
echo " Adres URL Platform UI : ${URL}"
echo " Użytkownik            : ${USER}"
echo " Hasło                 : ${PASSWORD}"
echo "----------------------------------------------------------"
echo "Uwaga: Przy pierwszym logowaniu system wymusi zmianę hasła."
echo "=========================================================="
