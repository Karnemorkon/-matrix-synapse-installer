#!/bin/bash
# ===================================================================================
# Configuration Module - Handle all configuration management
# ===================================================================================

# --- Default Configuration ---
readonly CONFIG_DIR="${CONFIG_DIR:-${HOME}/.config/matrix-installer}"
readonly CONFIG_FILE="${CONFIG_DIR}/config.conf"
readonly TEMPLATES_DIR="${SCRIPT_DIR}/templates"

# --- Default Values ---
declare -A DEFAULT_CONFIG=(
    [BASE_DIR]="/DATA/matrix"
    [DOMAIN]="matrix.example.com"
    [POSTGRES_PASSWORD]=""
    [ALLOW_PUBLIC_REGISTRATION]="false"
    [ENABLE_FEDERATION]="false"
    [INSTALL_ELEMENT]="true"
    [INSTALL_PORTAINER]="true"
    [USE_CLOUDFLARE_TUNNEL]="false"
    [CLOUDFLARE_TUNNEL_TOKEN]=""
    [USE_LETSENCRYPT]="false"
    [LETSENCRYPT_EMAIL]=""
    [INSTALL_BRIDGES]="false"
    [INSTALL_SIGNAL_BRIDGE]="false"
    [INSTALL_WHATSAPP_BRIDGE]="false"
    [INSTALL_TELEGRAM_BRIDGE]="false"
    [INSTALL_DISCORD_BRIDGE]="false"
    [SETUP_MONITORING]="false"
    [SETUP_BACKUP]="false"
    [BACKUP_SCHEDULE]="daily"
    [SETUP_EMAIL_ALERTS]="false"
    [ALERT_EMAIL]=""
    [SMTP_SERVER]=""
    [SMTP_USER]=""
    [SMTP_PASSWORD]=""
)

# --- Configuration Variables ---
declare -A CONFIG

# --- Functions ---
init_config() {
    mkdir -p "${CONFIG_DIR}"
    
    # Initialize CONFIG array with defaults
    for key in "${!DEFAULT_CONFIG[@]}"; do
        CONFIG["${key}"]="${DEFAULT_CONFIG["${key}"]}"
    done
}

load_config() {
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        log_warn "Configuration file not found: ${CONFIG_FILE}"
        return 1
    fi
    
    log_info "Loading configuration from: ${CONFIG_FILE}"
    
    # Source the config file
    source "${CONFIG_FILE}"
    
    # Load values into CONFIG array
    for key in "${!DEFAULT_CONFIG[@]}"; do
        if [[ -n "${!key:-}" ]]; then
            CONFIG["${key}"]="${!key}"
        fi
    done
    
    log_success "Configuration loaded successfully"
}

save_config() {
    log_info "Saving configuration to: ${CONFIG_FILE}"
    
    cat > "${CONFIG_FILE}" << EOF
# Matrix Synapse Installer Configuration
# Generated on $(date)

# Basic Settings
BASE_DIR="${CONFIG[BASE_DIR]}"
DOMAIN="${CONFIG[DOMAIN]}"
POSTGRES_PASSWORD="${CONFIG[POSTGRES_PASSWORD]}"
ALLOW_PUBLIC_REGISTRATION="${CONFIG[ALLOW_PUBLIC_REGISTRATION]}"
ENABLE_FEDERATION="${CONFIG[ENABLE_FEDERATION]}"

# Components
INSTALL_ELEMENT="${CONFIG[INSTALL_ELEMENT]}"
INSTALL_PORTAINER="${CONFIG[INSTALL_PORTAINER]}"

# Access Configuration
USE_CLOUDFLARE_TUNNEL="${CONFIG[USE_CLOUDFLARE_TUNNEL]}"
CLOUDFLARE_TUNNEL_TOKEN="${CONFIG[CLOUDFLARE_TUNNEL_TOKEN]}"
USE_LETSENCRYPT="${CONFIG[USE_LETSENCRYPT]}"
LETSENCRYPT_EMAIL="${CONFIG[LETSENCRYPT_EMAIL]}"

# Bridges
INSTALL_BRIDGES="${CONFIG[INSTALL_BRIDGES]}"
INSTALL_SIGNAL_BRIDGE="${CONFIG[INSTALL_SIGNAL_BRIDGE]}"
INSTALL_WHATSAPP_BRIDGE="${CONFIG[INSTALL_WHATSAPP_BRIDGE]}"
INSTALL_TELEGRAM_BRIDGE="${CONFIG[INSTALL_TELEGRAM_BRIDGE]}"
INSTALL_DISCORD_BRIDGE="${CONFIG[INSTALL_DISCORD_BRIDGE]}"

# Monitoring and Backup
SETUP_MONITORING="${CONFIG[SETUP_MONITORING]}"
SETUP_BACKUP="${CONFIG[SETUP_BACKUP]}"
BACKUP_SCHEDULE="${CONFIG[BACKUP_SCHEDULE]}"

# Email Alerts
SETUP_EMAIL_ALERTS="${CONFIG[SETUP_EMAIL_ALERTS]}"
ALERT_EMAIL="${CONFIG[ALERT_EMAIL]}"
SMTP_SERVER="${CONFIG[SMTP_SERVER]}"
SMTP_USER="${CONFIG[SMTP_USER]}"
SMTP_PASSWORD="${CONFIG[SMTP_PASSWORD]}"
EOF
    
    chmod 600 "${CONFIG_FILE}"
    log_success "Configuration saved successfully"
}

interactive_config() {
    log_info "Starting interactive configuration"
    
    # Basic settings
    echo
    echo "=== Основні налаштування ==="
    
    read_config_value "DOMAIN" "Введіть домен для Matrix сервера" "matrix.example.com" validate_domain
    read_config_value "BASE_DIR" "Базова директорія для встановлення" "/DATA/matrix" validate_directory_path
    read_password "POSTGRES_PASSWORD" "Пароль для бази даних PostgreSQL"
    
    CONFIG[ALLOW_PUBLIC_REGISTRATION]=$(ask_yes_no "Дозволити публічну реєстрацію?" "false")
    CONFIG[ENABLE_FEDERATION]=$(ask_yes_no "Увімкнути федерацію?" "false")
    
    # Components
    echo
    echo "=== Компоненти ==="
    CONFIG[INSTALL_ELEMENT]=$(ask_yes_no "Встановити Element Web?" "true")
    CONFIG[INSTALL_PORTAINER]=$(ask_yes_no "Встановити Portainer?" "true")
    
    # Access configuration
    echo
    echo "=== Налаштування доступу ==="
    CONFIG[USE_CLOUDFLARE_TUNNEL]=$(ask_yes_no "Використовувати Cloudflare Tunnel?" "false")
    
    if [[ "${CONFIG[USE_CLOUDFLARE_TUNNEL]}" == "true" ]]; then
        read_config_value "CLOUDFLARE_TUNNEL_TOKEN" "Токен Cloudflare Tunnel" "" validate_not_empty
    else
        CONFIG[USE_LETSENCRYPT]=$(ask_yes_no "Використовувати Let's Encrypt SSL?" "false")
        if [[ "${CONFIG[USE_LETSENCRYPT]}" == "true" ]]; then
            read_config_value "LETSENCRYPT_EMAIL" "Email для Let's Encrypt" "" validate_email
        fi
    fi
    
    # Bridges
    echo
    echo "=== Мости ==="
    CONFIG[INSTALL_BRIDGES]=$(ask_yes_no "Встановити мости для інтеграції з іншими месенджерами?" "false")
    
    if [[ "${CONFIG[INSTALL_BRIDGES]}" == "true" ]]; then
        CONFIG[INSTALL_SIGNAL_BRIDGE]=$(ask_yes_no "Signal Bridge?" "false")
        CONFIG[INSTALL_WHATSAPP_BRIDGE]=$(ask_yes_no "WhatsApp Bridge?" "false")
        CONFIG[INSTALL_TELEGRAM_BRIDGE]=$(ask_yes_no "Telegram Bridge?" "false")
        CONFIG[INSTALL_DISCORD_BRIDGE]=$(ask_yes_no "Discord Bridge?" "false")
    fi
    
    # Monitoring and backup
    echo
    echo "=== Моніторинг та резервне копіювання ==="
    CONFIG[SETUP_MONITORING]=$(ask_yes_no "Налаштувати моніторинг (Prometheus + Grafana)?" "false")
    CONFIG[SETUP_BACKUP]=$(ask_yes_no "Налаштувати автоматичне резервне копіювання?" "true")
    
    if [[ "${CONFIG[SETUP_BACKUP]}" == "true" ]]; then
        echo "Оберіть розклад резервного копіювання:"
        echo "1) Щодня"
        echo "2) Щотижня"
        echo "3) Вручну"
        
        local choice
        read -p "Ваш вибір (1-3) [1]: " choice
        choice=${choice:-1}
        
        case ${choice} in
            1) CONFIG[BACKUP_SCHEDULE]="daily" ;;
            2) CONFIG[BACKUP_SCHEDULE]="weekly" ;;
            3) CONFIG[BACKUP_SCHEDULE]="manual" ;;
            *) CONFIG[BACKUP_SCHEDULE]="daily" ;;
        esac
    fi
    
    # Email alerts
    if [[ "${CONFIG[SETUP_MONITORING]}" == "true" ]]; then
        CONFIG[SETUP_EMAIL_ALERTS]=$(ask_yes_no "Налаштувати email алерти?" "false")
        
        if [[ "${CONFIG[SETUP_EMAIL_ALERTS]}" == "true" ]]; then
            read_config_value "ALERT_EMAIL" "Email для алертів" "" validate_email
            read_config_value "SMTP_SERVER" "SMTP сервер (host:port)" "smtp.gmail.com:587" validate_not_empty
            read_config_value "SMTP_USER" "SMTP користувач" "" validate_email
            read_password "SMTP_PASSWORD" "SMTP пароль"
        fi
    fi
    
    # Save configuration
    save_config
    
    log_success "Інтерактивна конфігурація завершена"
}

read_config_value() {
    local key=$1
    local prompt=$2
    local default=$3
    local validator=${4:-}
    
    while true; do
        local value
        read -p "${prompt} [${default}]: " value
        value=${value:-${default}}
        
        if [[ -n "${validator}" ]] && ! ${validator} "${value}"; then
            log_error "Некоректне значення. Спробуйте ще раз."
            continue
        fi
        
        CONFIG["${key}"]="${value}"
        break
    done
}

read_password() {
    local key=$1
    local prompt=$2
    
    while true; do
        local password
        local password_confirm
        
        read -sp "${prompt}: " password
        echo
        read -sp "Повторіть пароль: " password_confirm
        echo
        
        if [[ "${password}" == "${password_confirm}" ]] && [[ -n "${password}" ]]; then
            CONFIG["${key}"]="${password}"
            break
        else
            log_error "Паролі не співпадають або порожні. Спробуйте ще раз."
        fi
    done
}

ask_yes_no() {
    local prompt=$1
    local default=${2:-false}
    local default_display
    
    if [[ "${default}" == "true" ]]; then
        default_display="Y/n"
    else
        default_display="y/N"
    fi
    
    while true; do
        local response
        read -p "${prompt} (${default_display}): " response
        
        case "${response,,}" in
            y|yes|так) echo "true"; return ;;
            n|no|ні) echo "false"; return ;;
            "") echo "${default}"; return ;;
            *) log_error "Будь ласка, введіть 'yes' або 'no'";;
        esac
    done
}

show_config_summary() {
    echo
    log_step "Підсумок конфігурації"
    
    cat << EOF
📋 ОСНОВНІ НАЛАШТУВАННЯ:
   Домен: ${CONFIG[DOMAIN]}
   Базова директорія: ${CONFIG[BASE_DIR]}
   Публічна реєстрація: ${CONFIG[ALLOW_PUBLIC_REGISTRATION]}
   Федерація: ${CONFIG[ENABLE_FEDERATION]}

🧩 КОМПОНЕНТИ:
   Element Web: ${CONFIG[INSTALL_ELEMENT]}
   Portainer: ${CONFIG[INSTALL_PORTAINER]}

🔐 ДОСТУП:
   Cloudflare Tunnel: ${CONFIG[USE_CLOUDFLARE_TUNNEL]}
   Let's Encrypt: ${CONFIG[USE_LETSENCRYPT]}

🌉 МОСТИ:
   Signal: ${CONFIG[INSTALL_SIGNAL_BRIDGE]}
   WhatsApp: ${CONFIG[INSTALL_WHATSAPP_BRIDGE]}
   Telegram: ${CONFIG[INSTALL_TELEGRAM_BRIDGE]}
   Discord: ${CONFIG[INSTALL_DISCORD_BRIDGE]}

📊 ДОДАТКОВО:
   Моніторинг: ${CONFIG[SETUP_MONITORING]}
   Резервне копіювання: ${CONFIG[SETUP_BACKUP]} (${CONFIG[BACKUP_SCHEDULE]})
   Email алерти: ${CONFIG[SETUP_EMAIL_ALERTS]}
EOF
}

# Initialize configuration on module load
init_config
