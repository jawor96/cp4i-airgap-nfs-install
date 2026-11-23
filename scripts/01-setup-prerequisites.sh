#!/usr/bin/env bash
# ==============================================================================
# 01-setup-prerequisites.sh
# Krok 1: Weryfikacja środowiska, utworzenie przestrzeni nazw, sprawdzenie StorageClass NFS,
#         weryfikacja CatalogSource oraz instalacja Cert-Manager Operator i PKI CA.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00-common.sh"
source "${SCRIPT_DIR}/../env.sh"

log_step "KROK 1: Weryfikacja wymagań wstępnych i przygotowanie klastra OCP"

validate_cli
validate_ocp_connection

# 1. Sprawdzenie StorageClass NFS
log_step "1.1. Weryfikacja StorageClass NFS (${NFS_STORAGE_CLASS})"
if oc get sc "${NFS_STORAGE_CLASS}" &>/dev/null; then
    log_success "StorageClass '${NFS_STORAGE_CLASS}' istnieje w klastrze."
else
    log_warn "StorageClass '${NFS_STORAGE_CLASS}' nie został znaleziony w klastrze."
    log_info "Dostępne klasy StorageClass:"
    oc get sc
    log_info "Jeśli potrzebujesz utworzyć klasę, sprawdź 01-prerequisites/00-storageclass-nfs.yaml lub ustaw NFS_STORAGE_CLASS w env.sh"
fi

# 2. Utworzenie przestrzeni nazw (Namespaces)
log_step "1.2. Tworzenie przestrzeni nazw (cp4i, ibm-common-services, cert-manager-operator, cert-manager)"
oc apply -f "${SCRIPT_DIR}/../01-prerequisites/01-namespaces.yaml"

# 3. Weryfikacja / Aplikacja CatalogSource (Air-Gapped)
log_step "1.3. Weryfikacja CatalogSource dla środowiska Air-Gapped"
if oc get catalogsource "${CATALOG_SOURCE}" -n "${CATALOG_SOURCE_NAMESPACE}" &>/dev/null; then
    log_info "CatalogSource '${CATALOG_SOURCE}' już istnieje w '${CATALOG_SOURCE_NAMESPACE}'."
else
    log_info "Aplikowanie CatalogSources z 01-prerequisites/03-catalog-sources.yaml..."
    oc apply -f "${SCRIPT_DIR}/../01-prerequisites/03-catalog-sources.yaml"
fi
wait_for_catalog_source "${CATALOG_SOURCE}" "${CATALOG_SOURCE_NAMESPACE}"

# 4. Instalacja Cert-Manager Operator
log_step "1.4. Instalacja Cert-Manager Operator (Źródło: ${CERT_MANAGER_CATALOG}, Kanał: ${CERT_MANAGER_CHANNEL})"
oc apply -f "${SCRIPT_DIR}/../01-prerequisites/02-operator-group.yaml"

cat <<EOF | oc apply -n "${CERT_MANAGER_NAMESPACE}" -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-cert-manager-operator
  namespace: ${CERT_MANAGER_NAMESPACE}
spec:
  channel: ${CERT_MANAGER_CHANNEL}
  installPlanApproval: ${INSTALL_PLAN_APPROVAL}
  name: openshift-cert-manager-operator
  source: ${CERT_MANAGER_CATALOG}
  sourceNamespace: openshift-marketplace
EOF

wait_for_operator_csv "cert-manager-operator-controller-manager" "${CERT_MANAGER_NAMESPACE}"

# Oczekiwanie na gotowość webhooka cert-managera
log_info "Oczekiwanie na uruchomienie webhooka cert-managera..."
oc wait --for=condition=Available deploy/cert-manager-webhook -n cert-manager --timeout=300s 2>/dev/null || true

# 5. Utworzenie łańcucha PKI (Root CA + ClusterIssuer)
log_step "1.5. Tworzenie Root CA oraz ClusterIssuer (gitops-selfsigned-issuer)"
oc apply -f "${SCRIPT_DIR}/../01-prerequisites/04-clusterissuer-cert-manager.yaml"

log_info "Weryfikacja gotowości certyfikatu Root CA..."
oc wait --for=condition=Ready certificate/cp4i-root-ca-cert -n cert-manager --timeout=300s 2>/dev/null || true

log_success "Krok 1 zakończony pomyślnie. Klaster jest gotowy do instalacji operatorów CP4I."
