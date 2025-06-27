#!/bin/bash
# ===================================================================================
# Configuration Module - Configuration management
# ===================================================================================

# --- Default Configuration ---
readonly DEFAULT_BASE_DIR="/DATA/matrix"
readonly DEFAULT_DOMAIN="matrix.example.com"
readonly DEFAULT_DB_PASSWORD=""
readonly CONFIG_DIR="$HOME/.config/matrix-installer"
readonly CONFIG_FILE="$CONFIG_DIR/config.conf"

# --- Configuration Variables ---
DOMAIN=""
BASE_DIR=""
DB_PASSWORD=""
ADMIN_EMAIL=""
CLOUDFLARE_TOKEN=""
INSTALL_BRIDGES="false"
SETUP_MONITORING="false"
SETUP_BACKUP="false"
USE_CLOUDFLARE_TUNNEL="false"
USE_LETSENCRYPT="false"
BRIDGES_TO_INSTALL=""

# --- Functions ---
init_config() {
    mkdir -p "$CONFIG_DIR"
    
    # Set default values if not already set
    DOMAIN=${DOMAIN:-$DEFAULT_DOMAIN}
    BASE_DIR=${BASE_DIR:-$DEFAULT_BASE_DIR}
    DB_PASSWORD=${DB_PASSWORD:-$(generate_password 32)}
}

interactive_config() {
    log_info "Інтерактивна конфігурація системи"
    echo
    
    # Domain configuration
    while true; do
        read -p "Введіть домен для Matrix сервера (наприклад: matrix.example.com): " input_domain
        if validate_domain "$input_domain"; then
            DOMAIN="$input_domain"
            break
        else
            log_error "Невірний формат домену. Спробуйте ще раз."
        fi
    done
    
    # Base directory
    read -p "Базова директорія для встановлення [$DEFAULT_BASE_DIR]: " input_dir
    BASE_DIR="${input_dir:-$DEFAULT_BASE_DIR}"
    
    # Database password
    while true; do
        read -s -p "Пароль для бази даних PostgreSQL (залиште порожнім для автогенерації): " input_password
        echo
        if [[ -z "$input_password" ]]; then
            DB_PASSWORD=$(generate_password 32)
            log_info "Згенеровано пароль для бази даних"
            break
        elif [[ ${#input_password} -ge 8 ]]; then
            DB_PASSWORD="$input_password"
            break
        else
            log_error "Пароль повинен містити мінімум 8 символів"
        fi
    done
    
    # Admin email
    read -p "Email адміністратора (для Let's Encrypt та сповіщень): " ADMIN_EMAIL
    
    # Access method
    echo
    log_info "Виберіть метод доступу:"
    echo "1) Cloudflare Tunnel (рекомендовано)"
    echo "2) Let's Encrypt SSL"
    echo "3) Без SSL (тільки для тестування)"
    
    while true; do
        read -p "Ваш вибір [1-3]: " access_choice
        case $access_choice in
            1)
                USE_CLOUDFLARE_TUNNEL="true"
                read -p "Введіть Cloudflare Tunnel токен: " CLOUDFLARE_TOKEN
                break
                ;;
            2)
                USE_LETSENCRYPT="true"
                break
                ;;
            3)
                log_warn "Увага: SSL не буде налаштовано!"
                break
                ;;
            *)
                log_error "Невірний вибір. Введіть 1, 2 або 3."
                ;;
        esac
    done
    
    # Bridges
    echo
    if ask_yes_no "Встановити мости для інтеграції з іншими месенджерами?"; then
        INSTALL_BRIDGES="true"
        
        echo "Доступні мости:"
        echo "1) Signal Bridge"
        echo "2) WhatsApp Bridge"
        echo "3) Telegram Bridge"
        echo "4) Discord Bridge"
        echo "5) Всі мости"
        
        read -p "Введіть номери мостів через кому (наприклад: 1,2,4): " bridge_choice
        BRIDGES_TO_INSTALL="$bridge_choice"
    fi
    
    # Monitoring
    echo
    if ask_yes_no "Налаштувати моніторинг (Prometheus + Grafana)?"; then
        SETUP_MONITORING="true"
    fi
    
    # Backup
    echo
    if ask_yes_no "Налаштувати автоматичне резервне копіювання?"; then
        SETUP_BACKUP="true"
    fi
    
    # Save configuration
    save_config
    log_success "Конфігурацію збережено в $CONFIG_FILE"
}

save_config() {
    cat > "$CONFIG_FILE" << EOF
# Matrix Synapse Installer Configuration
# Generated on $(date)

DOMAIN="$DOMAIN"
BASE_DIR="$BASE_DIR"
DB_PASSWORD="$DB_PASSWORD"
ADMIN_EMAIL="$ADMIN_EMAIL"
CLOUDFLARE_TOKEN="$CLOUDFLARE_TOKEN"
INSTALL_BRIDGES="$INSTALL_BRIDGES"
SETUP_MONITORING="$SETUP_MONITORING"
SETUP_BACKUP="$SETUP_BACKUP"
USE_CLOUDFLARE_TUNNEL="$USE_CLOUDFLARE_TUNNEL"
USE_LETSENCRYPT="$USE_LETSENCRYPT"
BRIDGES_TO_INSTALL="$BRIDGES_TO_INSTALL"
EOF
}

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        log_info "Конфігурацію завантажено з $CONFIG_FILE"
    else
        log_warn "Файл конфігурації не знайдено: $CONFIG_FILE"
        return 1
    fi
}

show_config_summary() {
    echo
    log_info "=== ПІДСУМОК КОНФІГУРАЦІЇ ==="
    echo "Домен: $DOMAIN"
    echo "Базова директорія: $BASE_DIR"
    echo "Email адміністратора: $ADMIN_EMAIL"
    echo "Cloudflare Tunnel: $USE_CLOUDFLARE_TUNNEL"
    echo "Let's Encrypt: $USE_LETSENCRYPT"
    echo "Мости: $INSTALL_BRIDGES"
    echo "Моніторинг: $SETUP_MONITORING"
    echo "Резервне копіювання: $SETUP_BACKUP"
    echo
}

validate_config() {
    local errors=0
    
    if [[ -z "$DOMAIN" ]]; then
        log_error "Домен не вказано"
        ((errors++))
    fi
    
    if [[ -z "$BASE_DIR" ]]; then
        log_error "Базова директорія не вказана"
        ((errors++))
    fi
    
    if [[ -z "$DB_PASSWORD" ]]; then
        log_error "Пароль бази даних не вказано"
        ((errors++))
    fi
    
    if [[ "$USE_CLOUDFLARE_TUNNEL" == "true" && -z "$CLOUDFLARE_TOKEN" ]]; then
        log_error "Cloudflare токен не вказано"
        ((errors++))
    fi
    
    if [[ "$USE_LETSENCRYPT" == "true" && -z "$ADMIN_EMAIL" ]]; then
        log_error "Email адміністратора потрібен для Let's Encrypt"
        ((errors++))
    fi
    
    if [[ $errors -gt 0 ]]; then
        log_error "Знайдено $errors помилок в конфігурації"
        return 1
    fi
    
    log_success "Конфігурація валідна"
    return 0
}

generate_password() {
    local length=${1:-32}
    openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
}

ask_yes_no() {
    local question="$1"
    local default="${2:-n}"
    
    while true; do
        if [[ "$default" == "y" ]]; then
            read -p "$question [Y/n]: " answer
            answer=${answer:-y}
        else
            read -p "$question [y/N]: " answer
            answer=${answer:-n}
        fi
        
        case ${answer,,} in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) log_error "Введіть 'y' або 'n'" ;;
        esac
    done
}

# Initialize configuration
init_config
