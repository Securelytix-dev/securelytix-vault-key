#!/usr/bin/env bash

#############################################################################
# Securelytix Dev SDK Interactive Installer
#
# A production-ready interactive installation script for the Securelytix
# Dev SDK that guides users through the complete installation process.
#
# Usage:
#   curl -fsSL https://charts.securelytix.tech/install.sh | bash
#
#   OR download and run locally:
#
#   ./install.sh                    # Interactive mode
#   ./install.sh --help             # Show help
#   ./install.sh -v                 # Verbose mode
#
# Requirements:
#   - Helm 3.x
#   - kubectl configured with cluster access
#   - Kubernetes 1.20+
#   - Securelytix API key (get one at https://securelytix.tech)
#
# Author: Securelytix DevOps (https://securelytix.tech)
#############################################################################

set -euo pipefail

# Script version
VERSION="1.0.0"

# Flags
VERBOSE="${VERBOSE:-false}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BRIGHT_GREEN='\033[1;32m'
WHITE='\033[0;37m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration variables
NAMESPACE="securelytix"
RELEASE_NAME="vault-key"
HELM_REPO_NAME="securelytix"
HELM_REPO_URL="https://charts.securelytix.tech"
HELM_CHART="${HELM_REPO_NAME}/vault-key"
API_KEY=""
DATABASE_URL=""
LICENSE_BASE_URL="https://website-backend.securelytix.tech"
USE_BUNDLED_PG="false"
CREATE_NAMESPACE="true"

# State tracking
HELM_REPO_ADDED=false
NAMESPACE_CREATED=false
INSTALLATION_STARTED=false
CURRENT_STEP=0
TOTAL_STEPS=6

#############################################################################
# Helper Functions
#############################################################################

print_color() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

print_step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local label="Step ${CURRENT_STEP}/${TOTAL_STEPS}: $1"
    local width=79
    local pad=$(( width - ${#label} - 1 ))
    printf "\n"
    print_color "$BOLD$BRIGHT_GREEN" "╭$(printf '─%.0s' $(seq 1 $width))╮"
    print_color "$BOLD$BRIGHT_GREEN" "| ${label}$(printf ' %.0s' $(seq 1 $pad))|"
    print_color "$BOLD$BRIGHT_GREEN" "╰$(printf '─%.0s' $(seq 1 $width))╯"
    printf "\n"
}

print_success() { print_color "$GREEN" "✓ $*"; }
print_error()   { print_color "$RED"   "✗ $*"; }
print_warning() { print_color "$BRIGHT_GREEN" "⚠ $*"; }
print_info()    { print_color "$WHITE"  "ℹ $*"; }

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

prompt_secure() {
    local prompt_message=$1
    local user_input

    read -r -s -p "$(echo -e "${BRIGHT_GREEN}${prompt_message}:${NC} ")" user_input < /dev/tty
    echo ""
    echo "$user_input"
}

ask_yes_no() {
    local prompt_message=$1
    local default_value=${2:-"y"}
    local response

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
│   Dev SDK Installer  ◎  PII Tokenization for Kubernetes  ◎  v${VERSION}    │
│                                                                        │
╰────────────────────────────────────────────────────────────────────────╯
    "
    print_info "Protect your PII — tokenize structured data across all your services."
    print_info "Website: https://securelytix.tech | Docs: https://securelytix.tech/docs"
    echo ""
}

show_help() {
    cat << EOF
Securelytix Dev SDK Installer v${VERSION}

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    --version               Show version information

EXAMPLES:
    # Interactive installation (recommended)
    $0

    # Verbose mode for debugging
    $0 --verbose

    # Quick install via curl
    curl -fsSL https://charts.securelytix.tech/install.sh | bash

REQUIREMENTS:
    - Helm 3.x installed
    - kubectl configured with cluster access
    - Kubernetes 1.20+
    - Securelytix API key

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
    print_step "Checking Prerequisites"

    local all_checks_passed=true

    if command -v helm &> /dev/null; then
        local helm_version
        helm_version=$(helm version --short 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        print_success "Helm is installed: ${helm_version}"
    else
        print_error "Helm is not installed. Install it from https://helm.sh/docs/intro/install/"
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
        print_error "Prerequisites check failed. Please fix the above issues and retry."
        exit 1
    fi

    echo ""
}

setup_helm_repo() {
    print_step "Setting Up Helm Repository"

    print_info "Adding Securelytix Helm repo..."

    if helm repo add "$HELM_REPO_NAME" "$HELM_REPO_URL" 2>/dev/null; then
        HELM_REPO_ADDED=true
        print_success "Helm repo added: ${HELM_REPO_URL}"
    else
        print_warning "Repo may already exist — updating..."
    fi

    helm repo update "$HELM_REPO_NAME" 2>/dev/null
    print_success "Helm repo updated"
    echo ""
}

collect_credentials() {
    print_step "Collecting Credentials"

    print_info "You'll need a Securelytix API key. Get one at https://securelytix.tech"
    echo ""

    API_KEY=$(prompt_secure "Enter your Securelytix API key")

    if [[ -z "$API_KEY" ]]; then
        print_error "API key is required"
        exit 1
    fi

    print_success "API key received"
    echo ""
}

configure_database() {
    print_step "Configuring Database"

    echo ""
    print_info "The Securelytix Dev SDK requires a PostgreSQL database."
    echo ""

    if ask_yes_no "Use bundled PostgreSQL (recommended for dev/testing)?" "y"; then
        USE_BUNDLED_PG="true"
        print_success "Bundled PostgreSQL will be deployed"
    else
        USE_BUNDLED_PG="false"
        print_info "Enter your PostgreSQL connection string."
        print_info "Format: postgresql://user:pass@host:5432/dbname?sslmode=disable"
        echo ""
        DATABASE_URL=$(prompt "PostgreSQL connection string" "")

        if [[ -z "$DATABASE_URL" ]]; then
            print_error "Database URL is required when not using bundled PostgreSQL"
            exit 1
        fi

        print_success "External database configured"
    fi

    echo ""
}

configure_namespace() {
    print_step "Configuring Namespace"

    NAMESPACE=$(prompt "Kubernetes namespace" "$NAMESPACE")
    RELEASE_NAME=$(prompt "Helm release name" "$RELEASE_NAME")

    echo ""
    print_info "Checking namespace '${NAMESPACE}'..."

    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_info "Namespace '${NAMESPACE}' already exists"
        CREATE_NAMESPACE="false"
    else
        if ask_yes_no "Create namespace '${NAMESPACE}'?" "y"; then
            kubectl create namespace "$NAMESPACE"
            NAMESPACE_CREATED=true
            print_success "Namespace '${NAMESPACE}' created"
        else
            print_error "Namespace is required for installation"
            exit 1
        fi
    fi


    echo ""
}

review_config() {
    print_color "$BOLD$BRIGHT_GREEN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_color "$BOLD" "Review Configuration"
    print_color "$BOLD$BRIGHT_GREEN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    print_info "Release Name:       ${RELEASE_NAME}"
    print_info "Namespace:          ${NAMESPACE}"
    print_info "Helm Chart:         ${HELM_CHART}"
    print_info "Bundled PostgreSQL: ${USE_BUNDLED_PG}"
    print_info "License Base URL:   ${LICENSE_BASE_URL}"
    echo ""

    if ! ask_yes_no "Proceed with installation?" "y"; then
        print_info "Installation cancelled"
        exit 0
    fi

    echo ""
}

install_sdk() {
    print_step "Installing Securelytix Dev SDK"

    INSTALLATION_STARTED=true

    local helm_cmd=(
        helm install "$RELEASE_NAME" "$HELM_CHART"
        --namespace "$NAMESPACE"
        --set "secrets.apiKey=${API_KEY}"
        --set "secrets.licenseBaseUrl=${LICENSE_BASE_URL}"
    )

    if [[ "$USE_BUNDLED_PG" == "true" ]]; then
        helm_cmd+=(--set "postgresql.enabled=true")
    else
        helm_cmd+=(--set "secrets.databaseUrl=${DATABASE_URL}")
    fi

    print_verbose "Running: ${helm_cmd[*]}"

    if "${helm_cmd[@]}"; then
        echo ""
        print_success "Helm installation completed successfully!"
    else
        echo ""
        print_error "Helm installation failed"
        print_info "Run 'helm list -n ${NAMESPACE}' to check installation status"
        exit 1
    fi
}

verify_deployment() {
    print_step "Verifying Deployment"

    echo ""
    print_info "Checking pod status..."
    echo ""

    sleep 3

    kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/instance=${RELEASE_NAME}" || true

    echo ""
    print_info "Waiting for pods to be ready (timeout: 5 minutes)..."

    local timeout=300
    local elapsed=0
    local all_ready=false

    while [[ $elapsed -lt $timeout ]]; do
        local ready_count total_count

        ready_count=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/instance=${RELEASE_NAME}" \
            -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' 2>/dev/null | \
            grep -c "True" 2>/dev/null || echo "0")

        total_count=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/instance=${RELEASE_NAME}" \
            --no-headers 2>/dev/null | wc -l | tr -d '[:space:]' || echo "0")

        ready_count=$(echo "$ready_count" | tr -d '[:space:]')
        total_count=$(echo "$total_count" | tr -d '[:space:]')
        ready_count=${ready_count:-0}
        total_count=${total_count:-0}

        if [[ $ready_count -gt 0 ]] && [[ $ready_count -eq $total_count ]]; then
            all_ready=true
            break
        fi

        printf "\r${GREEN}Pods ready: ${ready_count}/${total_count} (${elapsed}s elapsed)${NC}"
        sleep 5
        elapsed=$((elapsed + 5))
    done

    echo ""
    echo ""

    if [[ "$all_ready" == "true" ]]; then
        print_success "All pods are ready!"
    else
        print_warning "Some pods are not ready yet — this may take a moment."
        print_info "Monitor progress with: kubectl get pods -n ${NAMESPACE} -w"
    fi

    echo ""
    print_color "$BOLD$BRIGHT_GREEN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_color "$BOLD$BRIGHT_GREEN" "Installation Complete!"
    print_color "$BOLD$BRIGHT_GREEN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    print_color "$BOLD" "1. Verify the SDK is running:"
    echo "   kubectl get pods -n ${NAMESPACE}"
    echo ""

    print_color "$BOLD" "2. Check health:"
    echo "   kubectl port-forward svc/${RELEASE_NAME} 8080:8080 -n ${NAMESPACE}"
    echo "   curl http://localhost:8080/health"
    echo ""

    print_color "$BOLD" "3. View logs:"
    echo "   kubectl logs -n ${NAMESPACE} -l app.kubernetes.io/instance=${RELEASE_NAME} --tail=50"
    echo ""

    print_color "$BOLD" "4. Uninstall:"
    echo "   ./uninstall.sh"
    echo ""

    print_success "Thank you for installing Securelytix Dev SDK!"
    print_info "Documentation: https://securelytix.tech/docs"
    print_info "Support: support@securelytix.tech"
}

cleanup_on_failure() {
    echo ""
    print_error "Installation failed. Initiating cleanup..."

    if [[ "$INSTALLATION_STARTED" == "true" ]]; then
        print_info "Removing Helm release: ${RELEASE_NAME}"
        helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" &> /dev/null || true
    fi

    if [[ "$NAMESPACE_CREATED" == "true" ]]; then
        print_info "Deleting namespace: ${NAMESPACE}"
        kubectl delete namespace "$NAMESPACE" &> /dev/null || true
    fi

    if [[ "$HELM_REPO_ADDED" == "true" ]]; then
        print_info "Removing Helm repository"
        helm repo remove "$HELM_REPO_NAME" &> /dev/null || true
    fi

    print_success "Cleanup completed"
    echo ""
    print_info "Please check the error messages above and try again."
    print_info "For help: support@securelytix.tech"
    exit 1
}

handle_interrupt() {
    echo ""
    print_warning "Installation interrupted by user"

    if ask_yes_no "Do you want to clean up partial installation?" "y"; then
        cleanup_on_failure
    else
        print_info "Partial installation left in place"
        print_info "To clean up manually: helm uninstall ${RELEASE_NAME} -n ${NAMESPACE}"
    fi

    exit 130
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
            --version)
                echo "Securelytix Dev SDK Installer v${VERSION}"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    trap handle_interrupt SIGINT SIGTERM
    trap cleanup_on_failure ERR

    print_banner
    check_prerequisites
    setup_helm_repo
    collect_credentials
    configure_database
    configure_namespace
    review_config
    install_sdk
    verify_deployment
}

main "$@"
