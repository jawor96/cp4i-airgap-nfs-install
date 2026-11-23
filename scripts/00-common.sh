#!/usr/bin/env bash
# ==============================================================================
# 00-common.sh
# Biblioteka wspólnych funkcji dla skryptów instalacyjnych CP4I
# ==============================================================================
[[ -n "${_CP4I_COMMON_SH_LOADED:-}" ]] && return
_CP4I_COMMON_SH_LOADED=1

# Kolorowanie logów
log_info() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

log_success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

log_warn() {
    echo -e "\033[1;33m[WARN]\033[0m $1"
}

log_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1" >&2
}

log_step() {
    echo -e "\n\033[1;35m>>> $1\033[0m"
}

# Walidacja narzędzi klienckich
validate_cli() {
    local missing=0
    for cmd in oc jq base64 openssl; do
        if ! command -v "$cmd" &>/dev/null; then
            log_error "Wymagane narzędzie '$cmd' nie jest zainstalowane na stacji roboczej."
            missing=1
        fi
    done
    if [[ $missing -ne 0 ]]; then
        exit 1
    fi
}

# Sprawdzenie połączenia z klastrem OCP
validate_ocp_connection() {
    local user
    if ! user=$(oc whoami 2>/dev/null); then
        log_error "Brak aktywnej sesji OpenShift CLI. Zaloguj się za pomocą 'oc login' przed uruchomieniem."
        exit 1
    fi
    local cluster_name
    cluster_name=$(oc config view --minify --output 'jsonpath={.clusters[].name}' 2>/dev/null | cut -d':' -f1 || echo "ocp-cluster")
    log_info "Zalogowano do klastra: ${cluster_name} jako użytkownik: ${user}"
}

# Oczekiwanie na gotowość CatalogSource
wait_for_catalog_source() {
    local cat_name="$1"
    local cat_ns="${2:-openshift-marketplace}"
    local max_retries="${3:-30}"
    log_info "Oczekiwanie na gotowość CatalogSource '${cat_name}' w '${cat_ns}'..."
    
    local i=1
    while true; do
        local state
        state=$(oc get catalogsource "${cat_name}" -n "${cat_ns}" -o jsonpath='{.status.connectionState.lastObservedState}' 2>/dev/null || true)
        if [[ "${state}" == "READY" ]]; then
            log_success "CatalogSource '${cat_name}' jest gotowy (READY)."
            break
        fi
        if [[ $i -ge $max_retries ]]; then
            log_warn "Osiągnięto limit czasu oczekiwania na CatalogSource '${cat_name}'. Ostatni stan: '${state}'."
            break
        fi
        sleep 5
        ((i++))
    done
}

# Oczekiwanie na gotowość Operatora (CSV Succeeded)
wait_for_operator_csv() {
    local deployment_name="$1"
    local op_ns="${2:-openshift-operators}"
    local max_retries="${3:-60}"
    log_info "Oczekiwanie na CSV operatora dla deploymentu '${deployment_name}' w '${op_ns}'..."

    local i=1
    while true; do
        # W trybie Manual approval zatwierdzamy oczekujący InstallPlan
        if [[ "${INSTALL_PLAN_APPROVAL:-Automatic}" == "Manual" ]]; then
            local unapproved_ip
            unapproved_ip=$(oc get installplan -n "${op_ns}" -o jsonpath='{.items[?(@.spec.approved==false)].metadata.name}' 2>/dev/null || true)
            if [[ -n "${unapproved_ip}" ]]; then
                for ip in ${unapproved_ip}; do
                    log_info "Zatwierdzanie InstallPlan: ${ip} w ${op_ns}..."
                    oc patch installplan "${ip}" -n "${op_ns}" --type=merge --patch '{"spec":{"approved":true}}' || true
                done
            fi
        fi

        local sub_name
        sub_name=$(oc get deployment "${deployment_name}" -n "${op_ns}" --ignore-not-found -o jsonpath='{.metadata.labels.olm\.owner}' 2>/dev/null || true)
        if [[ -n "${sub_name}" ]]; then
            local phase
            phase=$(oc get csv "${sub_name}" -n "${op_ns}" --ignore-not-found -o jsonpath='{.status.phase}' 2>/dev/null || true)
            if [[ "${phase}" == "Succeeded" ]]; then
                log_success "Operator '${deployment_name}' zainstalowany pomyślnie (CSV: ${sub_name}, Faza: Succeeded)."
                return 0
            fi
        fi
        if [[ $i -ge $max_retries ]]; then
            log_error "Limit czasu oczekiwania na operator '${deployment_name}' został przekroczony."
            return 1
        fi
        sleep 10
        ((i++))
    done
}

# Oczekiwanie na gotowość Custom Resource (Status Ready / Running)
wait_for_cr_ready() {
    local cr_type="$1"
    local cr_name="$2"
    local cr_ns="$3"
    local max_retries="${4:-90}" # 15 minut

    log_info "Oczekiwanie na gotowość zasobu '${cr_type}/${cr_name}' w '${cr_ns}'..."
    local i=1
    while true; do
        local is_ready="false"
        if [[ "${cr_type}" == "platformnavigator" || "${cr_type}" == "PlatformNavigator" ]]; then
            local ready_status
            ready_status=$(oc get "${cr_type}" "${cr_name}" -n "${cr_ns}" --ignore-not-found -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
            if [[ "${ready_status}" == "True" ]]; then
                is_ready="true"
            fi
        else
            local phase
            phase=$(oc get "${cr_type}" "${cr_name}" -n "${cr_ns}" --ignore-not-found -o jsonpath='{.status.phase}' 2>/dev/null || true)
            if [[ "${phase}" == "Ready" || "${phase}" == "Running" ]]; then
                is_ready="true"
            fi
        fi

        if [[ "${is_ready}" == "true" ]]; then
            log_success "Zasób '${cr_type}/${cr_name}' osiągnął stan gotowości (Ready)."
            return 0
        fi

        if [[ $i -ge $max_retries ]]; then
            log_error "Osiągnięto limit czasu oczekiwania na '${cr_type}/${cr_name}'."
            return 1
        fi
        sleep 10
        ((i++))
    done
}
