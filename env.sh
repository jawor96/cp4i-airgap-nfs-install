#!/usr/bin/env bash
# ==============================================================================
# Centralny plik konfiguracyjny zmiennych środowiskowych dla instalacji CP4I
# Środowisko: Red Hat OpenShift Container Platform (OCP) Air-Gapped + NFS Storage
# Wydanie: IBM Cloud Pak for Integration (CP4I) 16.2.0 (cykl LTS / SC2)
# ==============================================================================

# Przestrzeń nazw (Namespace / Project) dla instancji CP4I (Platform UI, MQ, ACE)
export CP4I_NAMESPACE="${CP4I_NAMESPACE:-cp4i}"

# Przestrzeń nazw dla operatorów (standardowo openshift-operators dla trybu cluster-wide)
export OPERATOR_NAMESPACE="${OPERATOR_NAMESPACE:-openshift-operators}"

# Przestrzeń nazw dla IBM Cloud Pak foundational services (Common Services)
export CS_NAMESPACE="${CS_NAMESPACE:-ibm-common-services}"

# Przestrzeń nazw dla cert-manager operator
export CERT_MANAGER_NAMESPACE="${CERT_MANAGER_NAMESPACE:-cert-manager-operator}"
export CERT_MANAGER_CLUSTER_RESOURCE_NS="${CERT_MANAGER_CLUSTER_RESOURCE_NS:-cert-manager}"

# ==============================================================================
# Konfiguracja StorageClass dla NFS
# ==============================================================================
# W środowisku NFS definiujemy klasę pamięci masowej (np. nfs-client, managed-nfs-storage)
export NFS_STORAGE_CLASS="${NFS_STORAGE_CLASS:-mq-nfs-v41}"
export NFS_FILE_STORAGE_CLASS="${NFS_FILE_STORAGE_CLASS:-$NFS_STORAGE_CLASS}" # Używane przez ACE Dashboard (RWX)
export NFS_BLOCK_STORAGE_CLASS="${NFS_BLOCK_STORAGE_CLASS:-$NFS_STORAGE_CLASS}" # Używane przez Platform UI / Common Services / MQ

# ==============================================================================
# Źródła katalogów (CatalogSource) i zatwierdzanie planów instalacji
# ==============================================================================
# W środowisku Air-Gapped katalogi operatorów IBM pochodzą ze zmirrorowanego źródła
export CATALOG_SOURCE="${CATALOG_SOURCE:-ibm-operator-catalog}"
export CATALOG_SOURCE_NAMESPACE="${CATALOG_SOURCE_NAMESPACE:-openshift-marketplace}"

# Źródło katalogu dla Red Hat Cert-Manager (po oc-mirror zwykle redhat-operator-index lub custom)
export CERT_MANAGER_CATALOG="${CERT_MANAGER_CATALOG:-redhat-operators}"

# Tryb zatwierdzania aktualizacji operatorów (Automatic lub Manual)
export INSTALL_PLAN_APPROVAL="${INSTALL_PLAN_APPROVAL:-Automatic}"

# ==============================================================================
# Wersje i kanały Operatorów CP4I dla wydania 16.2.0 (LTS / SC2)
# Tabela zgodności IBM CP4I 16.2.0:
# - IBM Cloud Pak foundational services: v4.19 (LTS)
# - IBM Integration Platform Navigator: v8.3-sc2 (LTS 16.2.0 SC2)
# - IBM MQ Operator: v4.0-sc2 (SC2) -> QueueManager: 10.0.0.5-r2 (lub 10.0.0.x)
# - IBM App Connect Operator: v13.6 -> Integration Runtime: 13.0.9.0-r1
# - Red Hat OpenShift Cert-Manager: stable-v1
# ==============================================================================
export CP4I_RELEASE="${CP4I_RELEASE:-16.2.0}"
export CS_CHANNEL="${CS_CHANNEL:-v4.19}"
export PN_CHANNEL="${PN_CHANNEL:-v8.3-sc2}"
export PN_VERSION="${PN_VERSION:-16.2.0}"
export PN_LICENSE="${PN_LICENSE:-L-VAD2-N2WPMY}"

export MQ_CHANNEL="${MQ_CHANNEL:-v4.0-sc2}"
export MQ_VERSION="${MQ_VERSION:-10.0.1.0-r1}"
export MQ_LICENSE="${MQ_LICENSE:-L-VCNK-GTT2F3}" # Klucz licencyjny MQ 10.0.1 dla CP4I 16.2.x

export ACE_CHANNEL="${ACE_CHANNEL:-v13.6}"
export ACE_VERSION="${ACE_VERSION:-13.0.9.0-r1}" # Wersja wspierana przez kanał v13.6
export ACE_LICENSE="${ACE_LICENSE:-L-RJGW-BUAA2R}" # Klucz licencyjny ACE 13.0.8 / 13.0.9 dla CP4I 16.2.0

export CERT_MANAGER_CHANNEL="${CERT_MANAGER_CHANNEL:-stable-v1}"

# ==============================================================================
# Nazwy instancji komponentów
# ==============================================================================
export PLATFORM_NAVIGATOR_NAME="${PLATFORM_NAVIGATOR_NAME:-cp4i-navigator}"
export QMGR_NAME="${QMGR_NAME:-qmgr-demo}"
export QM_NAME_UPPER="${QM_NAME_UPPER:-QMGRDEMO}"
export ACE_DASHBOARD_NAME="${ACE_DASHBOARD_NAME:-ace-dashboard}"
export ACE_IR_NAME="${ACE_IR_NAME:-ace-mqapi-runtime}"
export ACE_ACH_IR_NAME="${ACE_ACH_IR_NAME:-ace-ach-hl7-runtime}"

# Typ licencji (NonProduction / Production)
export LICENSE_USE="${LICENSE_USE:-CloudPakForIntegrationNonProduction}"
export MQ_LICENSE_USE="${MQ_LICENSE_USE:-NonProduction}"

# ==============================================================================
# Adnotacje licencyjne dla IBM License Service (App Connect for Healthcare - ACH)
# Zgodnie z oficjalną dokumentacją ACH 13.0.x:
# https://www.ibm.com/docs/en/app-connect/13.0.x?topic=iu-installing-license-service-adding-annotations-app-connect-healthcare-in-containers
# ==============================================================================
export ACH_PRODUCT_NAME="${ACH_PRODUCT_NAME:-IBM App Connect for Healthcare}"
export ACH_PRODUCT_ID="${ACH_PRODUCT_ID:-563f8a6f0cea439eacc2cad8215dea7d}"
export ACH_PRODUCT_METRIC="${ACH_PRODUCT_METRIC:-INSTALL}"
export ACH_PRODUCT_CHARGED_CONTAINERS="${ACH_PRODUCT_CHARGED_CONTAINERS:-All}"
