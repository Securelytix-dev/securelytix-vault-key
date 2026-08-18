#!/usr/bin/env bash

#############################################################################
# Securelytix Dev SDK Uninstaller
#
# A safe and interactive uninstallation script for the Securelytix Dev SDK
# that guides users through the complete removal process.
#
# Usage:
#   ./uninstall.sh                    # Interactive mode
#   ./uninstall.sh --help             # Show help
#   ./uninstall.sh -v                 # Verbose mode
#   ./uninstall.sh --force            # Skip confirmations (dangerous!)
#
# Requirements:
#   - Helm 3.x
#   - kubectl configured with cluster access
#
# Author: Securelytix DevOps (https://securelytix.tech)
#############################################################################

set -euo pipefail

VERSION="1.0.0"

VERBOSE="${VERBOSE:-false}"
FORCE="${FORCE:-false}"
NAMESPACE=""
RELEASE_NAME=""
DELETE_NAMESPACE="false"
REMOVE_HELM_REPO="false"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BRIGHT_GREEN='\033[1;32m'
WHITE='\033[0;37m'
BOLD='\033[1m'
NC='\033[0m'

#############################################################################
# Helper Functions
#############################################################################

print_color() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

print_success() { print_color "$GREEN"        "✓ $*"; }
print_error()   { print_color "$RED"          "✗ $*"; }
print_warning() { print_color "$BRIGHT_GREEN" "⚠ $*"; }
print_info()    { print_color "$WHITE"        "ℹ $*"; }

print_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        print_color "$WHITE" "[VERBOSE] $*"
    fi
}

prompt() {
    local prompt_message=$1
    local default_value=$2
    local user_input

    if [[ -n "$default_value" ]]; then
        read -r -p "$(echo -e "${BRIGHT_GREEN}${prompt_message} [${default_value}]:${NC} ")" user_input < /dev/tty
        echo "${user_input:-$default_value}"
    else
        read -r -p "$(echo -e "${BRIGHT_GREEN}${prompt_message}:${NC} ")" user_input < /dev/tty
        echo "$user_input"
    fi
}

ask_yes_no() {
    local prompt_message=$1
    local default_value=${2:-"n"}
    local response

    if [[ "$FORCE" == "true" ]]; then
        print_verbose "Force mode: answering 'yes' to: ${prompt_message}"
        return 0
    fi

    if [[ "$default_value" == "y" ]]; then
        read -r -p "$(echo -e "${BRIGHT_GREEN}${prompt_message} [Y/n]:${NC} ")" response < /dev/tty
        response=${response:-y}
    else
        read -r -p "$(echo -e "${BRIGHT_GREEN}${prompt_message} [y/N]:${NC} ")" response < /dev/tty
        response=${response:-n}
    fi

    [[ "$response" =~ ^[Yy]$ ]]
}

print_banner() {
    clear
    print_color "$BOLD$BRIGHT_GREEN" "
╭────────────────────────────────────────────────────────────────────────╮
│                                                                        │
│    _    __                    __   __            __                    │
│   | |  / /  ____ _  __  __   / /  / /_          / /__  ___    __  __  │
│   | | / /  / __ '/ / / / /  / /  / __/ ______  / //_/ / _ \  / / / / │
│   | |/ /  / /_/ / / /_/ /  / /  / /_  /_____/ / ,<   /  __/ / /_/ /  │
│   |___/   \__,_/  \__,_/  /_/   \__/         /_/|_|  \___/  \__, /   │
│                                                              /____/    │
│                                                                        │
│   Dev SDK Uninstaller  ◎  v${VERSION}                                      │
│                                                                        │
╰────────────────────────────────────────────────────────────────────────╯
    "
    print_warning "This will remove the Securelytix Dev SDK from your cluster"
    echo ""
}

show_help() {
    cat << EOF
Securelytix Dev SDK Uninstaller v${VERSION}

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    -f, --force             Skip all confirmations (use with caution!)
    --version               Show version information

EXAMPLES:
    # Interactive uninstallation (recommended)
    $0

    # Verbose mode for debugging
    $0 --verbose

    # Force mode (no confirmations)
    $0 --force

WHAT GETS REMOVED:
    - Helm release (pods, services, deployments, etc.)
    - Optionally: Kubernetes namespace
    - Optionally: Helm repository

WHAT IS PRESERVED:
    - Tokenized data stored in your external PostgreSQL (if used)
    - Kubernetes secrets (DockerHub pull secret, etc.)

REQUIREMENTS:
    - Helm 3.x installed
    - kubectl configured with cluster access

SUPPORT:
    - Email: support@securelytix.tech
    - Website: https://securelytix.tech

EOF
    exit 0
}

#############################################################################
# Core Functions
#############################################################################

check_prerequisites() {
    print_info "Checking prerequisites..."
    echo ""

    local all_checks_passed=true

    if command -v helm &> /dev/null; then
        local helm_version
        helm_version=$(helm version --short 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        print_success "Helm is installed: ${helm_version}"
    else
        print_error "Helm is not installed"
        all_checks_passed=false
    fi

    if command -v kubectl &> /dev/null; then
        local kubectl_version
        kubectl_version=$(kubectl version --client --short 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        print_success "kubectl is installed: ${kubectl_version}"
    else
        print_error "kubectl is not installed"
        all_checks_passed=false
    fi

    if command -v kubectl &> /dev/null; then
        if kubectl cluster-info &> /dev/null; then
            local context
            context=$(kubectl config current-context 2>/dev/null || echo "unknown")
            print_success "Connected to cluster: ${context}"
        else
            print_error "Cannot connect to Kubernetes cluster"
            all_checks_passed=false
        fi
    fi

    if [[ "$all_checks_passed" == "false" ]]; then
        echo ""
        print_error "Prerequisites check failed"
        exit 1
    fi

    echo ""
}

find_installations() {
    print_info "Searching for Securelytix Dev SDK installations..."
    echo ""

    local releases
    releases=$(helm list --all-namespaces -o json 2>/dev/null | \
        grep -E '"name"|"namespace"|"chart"' | \
        grep -B1 -A1 "vault-key" || echo "")

    if [[ -z "$releases" ]]; then
        print_warning "No Securelytix Dev SDK installations found"
        echo ""
        print_info "If you believe this is incorrect:"
        print_info "  - Check specific namespace: helm list -n <namespace>"
        print_info "  - List all releases: helm list --all-namespaces"
        exit 0
    fi

    print_success "Found installation(s):"
    echo ""
    helm list --all-namespaces | head -1
    helm list --all-namespaces | grep vault-key
    echo ""
}

select_installation() {
    local releases
    releases=$(helm list --all-namespaces -o json 2>/dev/null | \
        python3 -c "
import json, sys
data = json.load(sys.stdin)
for r in data:
    if 'vault-key' in r.get('chart','') or r.get('name','') == 'vault-key':
        print(f\"{r['name']}|{r['namespace']}\")
" 2>/dev/null || echo "")

    if [[ -z "$releases" ]]; then
        print_error "Could not find any vault-key installations"
        exit 1
    fi

    local count
    count=$(echo "$releases" | wc -l | tr -d '[:space:]')

    if [[ "$count" -eq 1 ]]; then
        RELEASE_NAME=$(echo "$releases" | cut -d'|' -f1)
        NAMESPACE=$(echo "$releases" | cut -d'|' -f2)
        print_info "Found installation: ${RELEASE_NAME} in namespace ${NAMESPACE}"
    else
        if [[ "$FORCE" == "true" ]]; then
            print_error "Force mode cannot be used with multiple installations"
            exit 1
        fi

        echo "Please select which installation to remove:"
        echo ""

        local i=1
        while IFS='|' read -r name ns; do
            echo "  ${i}) ${name} (namespace: ${ns})"
            i=$((i + 1))
        done <<< "$releases"
        echo ""

        local selection
        selection=$(prompt "Enter selection number" "1")

        RELEASE_NAME=$(echo "$releases" | sed -n "${selection}p" | cut -d'|' -f1)
        NAMESPACE=$(echo "$releases" | sed -n "${selection}p" | cut -d'|' -f2)
    fi

    print_verbose "Selected release: ${RELEASE_NAME}"
    print_verbose "Selected namespace: ${NAMESPACE}"
}

show_removal_plan() {
    print_color "$BOLD$BRIGHT_GREEN" "Removal Plan:"
    echo ""
    print_color "$BOLD" "The following will be removed:"
    echo ""

    print_info "Helm Release:  ${RELEASE_NAME}"
    print_info "Namespace:     ${NAMESPACE}"
    echo ""

    local pods services deployments
    pods=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/instance=${RELEASE_NAME}" --no-headers 2>/dev/null | wc -l | tr -d '[:space:]')
    services=$(kubectl get svc -n "$NAMESPACE" -l "app.kubernetes.io/instance=${RELEASE_NAME}" --no-headers 2>/dev/null | wc -l | tr -d '[:space:]')
    deployments=$(kubectl get deployments -n "$NAMESPACE" -l "app.kubernetes.io/instance=${RELEASE_NAME}" --no-headers 2>/dev/null | wc -l | tr -d '[:space:]')

    print_info "Resources to be removed:"
    echo "  - Pods:        ${pods}"
    echo "  - Services:    ${services}"
    echo "  - Deployments: ${deployments}"
    echo ""

    if [[ "${pods:-0}" -gt 0 ]]; then
        print_info "Current pods:"
        kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/instance=${RELEASE_NAME}" 2>/dev/null | head -10
        echo ""
    fi

    if ask_yes_no "Also delete namespace '${NAMESPACE}'?" "n"; then
        DELETE_NAMESPACE="true"
        print_warning "Namespace '${NAMESPACE}' will be deleted (including ALL resources in it)"
        echo ""
    fi

    if helm repo list 2>/dev/null | grep -q "securelytix"; then
        if ask_yes_no "Remove Securelytix Helm repository?" "n"; then
            REMOVE_HELM_REPO="true"
        fi
    fi

    echo ""
    print_color "$BOLD" "Summary:"
    echo "  Release to remove:  ${RELEASE_NAME}"
    echo "  Namespace:          ${NAMESPACE}"
    echo "  Delete namespace:   ${DELETE_NAMESPACE}"
    echo "  Remove Helm repo:   ${REMOVE_HELM_REPO}"
    echo ""
}

perform_uninstall() {
    print_color "$BOLD$BRIGHT_GREEN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_color "$BOLD$BRIGHT_GREEN" "Starting Uninstallation"
    print_color "$BOLD$BRIGHT_GREEN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if ! ask_yes_no "Are you sure you want to proceed?" "n"; then
        print_info "Uninstallation cancelled"
        exit 0
    fi

    echo ""
    print_info "Removing Helm release: ${RELEASE_NAME}..."

    if helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" 2>&1; then
        print_success "Helm release removed successfully"
    else
        print_error "Failed to remove Helm release"
        print_info "You can try manually: helm uninstall ${RELEASE_NAME} -n ${NAMESPACE}"
        exit 1
    fi

    echo ""
    print_info "Waiting for resources to be cleaned up..."
    sleep 5

    local remaining_pods
    remaining_pods=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/instance=${RELEASE_NAME}" --no-headers 2>/dev/null | wc -l | tr -d '[:space:]')

    if [[ "${remaining_pods:-0}" -gt 0 ]]; then
        print_warning "${remaining_pods} pod(s) still terminating — this is normal and will resolve shortly."
    else
        print_success "All pods have been removed"
    fi

    if [[ "$DELETE_NAMESPACE" == "true" ]]; then
        echo ""
        print_warning "Deleting namespace: ${NAMESPACE}..."

        if kubectl delete namespace "$NAMESPACE" 2>&1; then
            print_success "Namespace deleted successfully"
        else
            print_error "Failed to delete namespace"
            print_info "Try manually: kubectl delete namespace ${NAMESPACE}"
        fi
    fi

    if [[ "$REMOVE_HELM_REPO" == "true" ]]; then
        echo ""
        print_info "Removing Helm repository..."

        if helm repo remove securelytix 2>&1; then
            print_success "Helm repository removed successfully"
        else
            print_warning "Failed to remove Helm repository (may not exist)"
        fi
    fi
}

show_completion() {
    echo ""
    print_color "$BOLD$BRIGHT_GREEN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_color "$BOLD$BRIGHT_GREEN" "Uninstallation Complete!"
    print_color "$BOLD$BRIGHT_GREEN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    print_success "Securelytix Dev SDK has been removed from your cluster"
    echo ""

    print_info "What was removed:"
    echo "  ✓ Helm release: ${RELEASE_NAME}"
    [[ "$DELETE_NAMESPACE" == "true" ]] && echo "  ✓ Namespace: ${NAMESPACE}"
    [[ "$REMOVE_HELM_REPO" == "true" ]] && echo "  ✓ Helm repository: securelytix"
    echo ""

    print_info "What is preserved:"
    echo "  • Tokenized data in your external PostgreSQL database (if used)"
    echo "  • Kubernetes secrets in namespace '${NAMESPACE}'"
    [[ "$DELETE_NAMESPACE" != "true" ]] && echo "  • Namespace: ${NAMESPACE}"
    echo ""

    print_info "To reinstall:"
    echo "  ./install.sh"
    echo ""

    print_info "Need help?"
    echo "  • Documentation: https://securelytix.tech/docs"
    echo "  • Support: support@securelytix.tech"
    echo ""
}

#############################################################################
# Main
#############################################################################

main() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                ;;
            -v|--verbose)
                VERBOSE="true"
                shift
                ;;
            -f|--force)
                FORCE="true"
                print_warning "Force mode enabled — confirmations will be skipped!"
                shift
                ;;
            --version)
                echo "Securelytix Dev SDK Uninstaller v${VERSION}"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    print_banner
    check_prerequisites
    find_installations
    select_installation
    show_removal_plan
    perform_uninstall
    show_completion
}

main "$@"
