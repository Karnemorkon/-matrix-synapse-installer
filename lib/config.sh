#!/bin/bash
# ===================================================================================
# Configuration Module - Manages installation configuration
# ===================================================================================

# --- Configuration Variables ---
readonly CONFIG_DIR="${HOME}/.config/matrix-installer"
readonly CONFIG_FILE="${CONFIG_DIR}/config.conf"

# Default values
DEFAULT_DOMAIN="matrix.example.com"
DEFAULT_BASE_DIR="/DATA/matrix"
DEFAULT_INSTALL_BRIDGES="false"
DEFAULT_SETUP_MONITORING="true"
DEFAULT_SETUP_BACKUP="true"
DEFAULT_USE_CLOUDFLARE="false"

# --- Functions ---
init_config() {
    mkdir -p "${CONFIG_DIR}"
    log_info "Ініціалізація конфігурації"
}

load_config() {
    if [[ -f "${CONFIG_FILE}" ]]; then
        source "${CONFIG_FILE}"
        log_info "Конфігурацію завантажено з ${CONFIG_FILE}"
    else
        log_warning "Файл конфігурації не знайдено"
    fi
}

save_config() {
    # Ensure config directory exists
    mkdir -p "${CONFIG_DIR}"
    
    cat > "${CONFIG_FILE}" << EOF
# Matrix Synapse Installer Configuration
# Generated on $(date)

DOMAIN="${DOMAIN}"
BASE_DIR="${BASE_DIR}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD}"
ALLOW_PUBLIC_REGISTRATION="${ALLOW_PUBLIC_REGISTRATION}"
ENABLE_FEDERATION="${ENABLE_FEDERATION}"
INSTALL_ELEMENT="${INSTALL_ELEMENT}"
INSTALL_BRIDGES="${INSTALL_BRIDGES}"
SETUP_MONITORING="${SETUP_MONITORING}"
SETUP_BACKUP="${SETUP_BACKUP}"
USE_CLOUDFLARE_TUNNEL="${USE_CLOUDFLARE_TUNNEL}"
CLOUDFLARE_TUNNEL_TOKEN="${CLOUDFLARE_TUNNEL_TOKEN:-}"
EOF
    log_success "Конфігурацію збережено в ${CONFIG_FILE}"
}

interactive_config() {
    log_step "Інтерактивна конфігурація"
    
    # Initialize config first
    init_config
    
    # Domain configuration
    read -p "Введіть ваш домен для Matrix [${DEFAULT_DOMAIN}]: " DOMAIN
    DOMAIN=${DOMAIN:-$DEFAULT_DOMAIN}
    
    # Base directory
    read -p "Базова директорія для встановлення [${DEFAULT_BASE_DIR}]: " BASE_DIR
    BASE_DIR=${BASE_DIR:-$DEFAULT_BASE_DIR}
    
    # Database password
    while true; do
        read -sp "Створіть пароль для бази даних PostgreSQL: " POSTGRES_PASSWORD
        echo
        if [[ -z "${POSTGRES_PASSWORD}" ]]; then
            echo "Пароль не може бути порожнім. Спробуйте ще раз."
            continue
        fi
        read -sp "Повторіть пароль: " POSTGRES_PASSWORD_CONFIRM
        echo
        [[ "$POSTGRES_PASSWORD" == "$POSTGRES_PASSWORD_CONFIRM" ]] && break
        echo "Паролі не співпадають. Спробуйте ще раз."
    done
    
    # Public registration
    ALLOW_PUBLIC_REGISTRATION=$(ask_yes_no "Дозволити публічну реєстрацію користувачів?" "false")
    
    # Federation
    ENABLE_FEDERATION=$(ask_yes_no "Увімкнути федерацію з іншими Matrix серверами?" "false")
    
    # Element Web
    INSTALL_ELEMENT=$(ask_yes_no "Встановити Element Web клієнт?" "true")
    
    # Bridges
    INSTALL_BRIDGES=$(ask_yes_no "Встановити мости для інтеграції з іншими месенджерами?" "false")
    
    # Monitoring
    SETUP_MONITORING=$(ask_yes_no "Налаштувати систему моніторингу (Prometheus + Grafana)?" "true")
    
    # Backup
    SETUP_BACKUP=$(ask_yes_no "Налаштувати автоматичне резервне копіювання?" "true")
    
    # Cloudflare Tunnel
    USE_CLOUDFLARE_TUNNEL=$(ask_yes_no "Використовувати Cloudflare Tunnel для доступу?" "false")
    
    if [[ "${USE_CLOUDFLARE_TUNNEL}" == "true" ]]; then
        while true; do
            read -p "Введіть токен Cloudflare Tunnel: " CLOUDFLARE_TUNNEL_TOKEN
            if [[ -n "${CLOUDFLARE_TUNNEL_TOKEN}" ]]; then
                break
            else
                echo "Токен не може бути порожнім. Спробуйте ще раз."
            fi
        done
    fi
    
    save_config
}

validate_config() {
    log_step "Валідація конфігурації"
    
    # Validate domain
    if [[ ! "${DOMAIN}" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        log_error "Некоректний формат домену: ${DOMAIN}"
        exit 1
    fi
    
    # Validate base directory
    if [[ ! -d "$(dirname "${BASE_DIR}")" ]]; then
        log_error "Батьківська директорія не існує: $(dirname "${BASE_DIR}")"
        exit 1
    fi
    
    # Validate password
    if [[ -z "${POSTGRES_PASSWORD}" ]]; then
        log_error "Пароль бази даних не може бути порожнім"
        exit 1
    fi
    
    # Validate Cloudflare token if needed
    if [[ "${USE_CLOUDFLARE_TUNNEL}" == "true" && -z "${CLOUDFLARE_TUNNEL_TOKEN}" ]]; then
        log_error "Cloudflare Tunnel токен не може бути порожнім"
        exit 1
    fi
    
    log_success "Конфігурація валідна"
}

show_config_summary() {
    log_step "Підсумок конфігурації"
    echo "Домен: ${DOMAIN}"
    echo "Базова директорія: ${BASE_DIR}"
    echo "Публічна реєстрація: ${ALLOW_PUBLIC_REGISTRATION}"
    echo "Федерація: ${ENABLE_FEDERATION}"
    echo "Element Web: ${INSTALL_ELEMENT}"
    echo "Мости: ${INSTALL_BRIDGES}"
    echo "Моніторинг: ${SETUP_MONITORING}"
    echo "Резервне копіювання: ${SETUP_BACKUP}"
    echo "Cloudflare Tunnel: ${USE_CLOUDFLARE_TUNNEL}"
}

ask_yes_no() {
    local question="$1"
    local default="${2:-false}"
    local default_text="[y/N]"
    
    if [[ "${default}" == "true" ]]; then
        default_text="[Y/n]"
    fi
    
    while true; do
        read -p "${question} ${default_text}: " answer
        case "${answer,,}" in
            y|yes) echo "true"; return ;;
            n|no) echo "false"; return ;;
            "") echo "${default}"; return ;;
            *) echo "Будь ласка, введіть 'yes' або 'no'" >&2 ;;
        esac
    done
}

# Export functions
export -f init_config load_config save_config interactive_config validate_config show_config_summary ask_yes_no
