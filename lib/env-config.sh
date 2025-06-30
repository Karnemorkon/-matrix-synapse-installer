#!/bin/bash
# ===================================================================================
# Модуль Конфігурації через Змінні Середовища
# ===================================================================================

# --- Константи ---
if [[ -z "${BASE_DIR:-}" ]]; then
  BASE_DIR="/DATA/matrix"
fi
readonly ENV_FILE="${BASE_DIR}/.env"
readonly ENV_TEMPLATE_FILE="${SCRIPT_DIR}/templates/.env.template"

# --- Змінні за замовчуванням ---
declare -A DEFAULT_VALUES=(
    ["MATRIX_DOMAIN"]="matrix.example.com"
    ["MATRIX_BASE_DIR"]="/DATA/matrix"
    ["MATRIX_POSTGRES_PASSWORD"]=""
    ["MATRIX_ALLOW_PUBLIC_REGISTRATION"]="false"
    ["MATRIX_ENABLE_FEDERATION"]="false"
    ["MATRIX_INSTALL_ELEMENT"]="true"
    ["MATRIX_INSTALL_BRIDGES"]="false"
    ["MATRIX_SETUP_MONITORING"]="true"
    ["MATRIX_SETUP_BACKUP"]="true"
    ["MATRIX_USE_CLOUDFLARE_TUNNEL"]="false"
    ["MATRIX_INSTALL_SIGNAL_BRIDGE"]="false"
    ["MATRIX_INSTALL_WHATSAPP_BRIDGE"]="false"
    ["MATRIX_INSTALL_DISCORD_BRIDGE"]="false"
    ["MATRIX_SSL_ENABLED"]="true"
    ["MATRIX_FIREWALL_ENABLED"]="true"
    ["MATRIX_RATE_LIMITING"]="true"
    ["MATRIX_GRAFANA_PASSWORD"]=""
    ["MATRIX_PROMETHEUS_ENABLED"]="true"
    ["MATRIX_BACKUP_RETENTION_DAYS"]="30"
    ["MATRIX_BACKUP_SCHEDULE"]="0 2 * * *"
    ["MATRIX_CLOUDFLARE_TUNNEL_TOKEN"]=""
    ["MATRIX_WEB_DASHBOARD_PORT"]="8081"
    ["MATRIX_WEB_DASHBOARD_ENABLED"]="true"
)

# --- Функції ---

# Ініціалізація конфігурації з змінних середовища
init_env_config() {
    log_step "Ініціалізація конфігурації з змінних середовища"
    
    # Перевіряємо чи є змінні середовища
    if [[ -n "${MATRIX_DOMAIN:-}" ]]; then
        log_info "Використовуються змінні середовища для конфігурації"
        load_from_env_variables
    else
        log_info "Змінні середовища не знайдено, використовуються значення за замовчуванням"
        load_default_values
    fi
    
    # Створюємо .env файл
    create_env_file
    
    log_success "Конфігурацію з змінних середовища ініціалізовано"
}

# Завантаження значень з змінних середовища
load_from_env_variables() {
    # Основні налаштування
    DOMAIN="${MATRIX_DOMAIN:-${DEFAULT_VALUES[MATRIX_DOMAIN]}}"
    BASE_DIR="${MATRIX_BASE_DIR:-${DEFAULT_VALUES[MATRIX_BASE_DIR]}}"
    POSTGRES_PASSWORD="${MATRIX_POSTGRES_PASSWORD:-$(generate_secure_token 32)}"
    
    # Функції
    ALLOW_PUBLIC_REGISTRATION="${MATRIX_ALLOW_PUBLIC_REGISTRATION:-${DEFAULT_VALUES[MATRIX_ALLOW_PUBLIC_REGISTRATION]}}"
    ENABLE_FEDERATION="${MATRIX_ENABLE_FEDERATION:-${DEFAULT_VALUES[MATRIX_ENABLE_FEDERATION]}}"
    INSTALL_ELEMENT="${MATRIX_INSTALL_ELEMENT:-${DEFAULT_VALUES[MATRIX_INSTALL_ELEMENT]}}"
    INSTALL_BRIDGES="${MATRIX_INSTALL_BRIDGES:-${DEFAULT_VALUES[MATRIX_INSTALL_BRIDGES]}}"
    SETUP_MONITORING="${MATRIX_SETUP_MONITORING:-${DEFAULT_VALUES[MATRIX_SETUP_MONITORING]}}"
    SETUP_BACKUP="${MATRIX_SETUP_BACKUP:-${DEFAULT_VALUES[MATRIX_SETUP_BACKUP]}}"
    USE_CLOUDFLARE_TUNNEL="${MATRIX_USE_CLOUDFLARE_TUNNEL:-${DEFAULT_VALUES[MATRIX_USE_CLOUDFLARE_TUNNEL]}}"
    
    # Мости
    INSTALL_SIGNAL_BRIDGE="${MATRIX_INSTALL_SIGNAL_BRIDGE:-${DEFAULT_VALUES[MATRIX_INSTALL_SIGNAL_BRIDGE]}}"
    INSTALL_WHATSAPP_BRIDGE="${MATRIX_INSTALL_WHATSAPP_BRIDGE:-${DEFAULT_VALUES[MATRIX_INSTALL_WHATSAPP_BRIDGE]}}"
    INSTALL_DISCORD_BRIDGE="${MATRIX_INSTALL_DISCORD_BRIDGE:-${DEFAULT_VALUES[MATRIX_INSTALL_DISCORD_BRIDGE]}}"
    
    # Безпека
    SSL_ENABLED="${MATRIX_SSL_ENABLED:-${DEFAULT_VALUES[MATRIX_SSL_ENABLED]}}"
    FIREWALL_ENABLED="${MATRIX_FIREWALL_ENABLED:-${DEFAULT_VALUES[MATRIX_FIREWALL_ENABLED]}}"
    RATE_LIMITING="${MATRIX_RATE_LIMITING:-${DEFAULT_VALUES[MATRIX_RATE_LIMITING]}}"
    
    # Моніторинг
    GRAFANA_PASSWORD="${MATRIX_GRAFANA_PASSWORD:-$(generate_secure_token 16)}"
    PROMETHEUS_ENABLED="${MATRIX_PROMETHEUS_ENABLED:-${DEFAULT_VALUES[MATRIX_PROMETHEUS_ENABLED]}}"
    
    # Резервне копіювання
    BACKUP_RETENTION_DAYS="${MATRIX_BACKUP_RETENTION_DAYS:-${DEFAULT_VALUES[MATRIX_BACKUP_RETENTION_DAYS]}}"
    BACKUP_SCHEDULE="${MATRIX_BACKUP_SCHEDULE:-${DEFAULT_VALUES[MATRIX_BACKUP_SCHEDULE]}}"
    
    # Cloudflare
    CLOUDFLARE_TUNNEL_TOKEN="${MATRIX_CLOUDFLARE_TUNNEL_TOKEN:-${DEFAULT_VALUES[MATRIX_CLOUDFLARE_TUNNEL_TOKEN]}}"
    
    # Веб інтерфейс
    WEB_DASHBOARD_PORT="${MATRIX_WEB_DASHBOARD_PORT:-${DEFAULT_VALUES[MATRIX_WEB_DASHBOARD_PORT]}}"
    WEB_DASHBOARD_ENABLED="${MATRIX_WEB_DASHBOARD_ENABLED:-${DEFAULT_VALUES[MATRIX_WEB_DASHBOARD_ENABLED]}}"
    
    log_info "Конфігурацію завантажено з змінних середовища"
}

# Завантаження значень за замовчуванням
load_default_values() {
    DOMAIN="${DEFAULT_VALUES[MATRIX_DOMAIN]}"
    BASE_DIR="${DEFAULT_VALUES[MATRIX_BASE_DIR]}"
    POSTGRES_PASSWORD="$(generate_secure_token 32)"
    
    ALLOW_PUBLIC_REGISTRATION="${DEFAULT_VALUES[MATRIX_ALLOW_PUBLIC_REGISTRATION]}"
    ENABLE_FEDERATION="${DEFAULT_VALUES[MATRIX_ENABLE_FEDERATION]}"
    INSTALL_ELEMENT="${DEFAULT_VALUES[MATRIX_INSTALL_ELEMENT]}"
    INSTALL_BRIDGES="${DEFAULT_VALUES[MATRIX_INSTALL_BRIDGES]}"
    SETUP_MONITORING="${DEFAULT_VALUES[MATRIX_SETUP_MONITORING]}"
    SETUP_BACKUP="${DEFAULT_VALUES[MATRIX_SETUP_BACKUP]}"
    USE_CLOUDFLARE_TUNNEL="${DEFAULT_VALUES[MATRIX_USE_CLOUDFLARE_TUNNEL]}"
    
    INSTALL_SIGNAL_BRIDGE="${DEFAULT_VALUES[MATRIX_INSTALL_SIGNAL_BRIDGE]}"
    INSTALL_WHATSAPP_BRIDGE="${DEFAULT_VALUES[MATRIX_INSTALL_WHATSAPP_BRIDGE]}"
    INSTALL_DISCORD_BRIDGE="${DEFAULT_VALUES[MATRIX_INSTALL_DISCORD_BRIDGE]}"
    
    SSL_ENABLED="${DEFAULT_VALUES[MATRIX_SSL_ENABLED]}"
    FIREWALL_ENABLED="${DEFAULT_VALUES[MATRIX_FIREWALL_ENABLED]}"
    RATE_LIMITING="${DEFAULT_VALUES[MATRIX_RATE_LIMITING]}"
    
    GRAFANA_PASSWORD="$(generate_secure_token 16)"
    PROMETHEUS_ENABLED="${DEFAULT_VALUES[MATRIX_PROMETHEUS_ENABLED]}"
    
    BACKUP_RETENTION_DAYS="${DEFAULT_VALUES[MATRIX_BACKUP_RETENTION_DAYS]}"
    BACKUP_SCHEDULE="${DEFAULT_VALUES[MATRIX_BACKUP_SCHEDULE]}"
    
    CLOUDFLARE_TUNNEL_TOKEN="${DEFAULT_VALUES[MATRIX_CLOUDFLARE_TUNNEL_TOKEN]}"
    
    WEB_DASHBOARD_PORT="${DEFAULT_VALUES[MATRIX_WEB_DASHBOARD_PORT]}"
    WEB_DASHBOARD_ENABLED="${DEFAULT_VALUES[MATRIX_WEB_DASHBOARD_ENABLED]}"
    
    log_info "Використовуються значення за замовчуванням"
}

# Створення .env файлу
create_env_file() {
    log_info "Створення .env файлу"
    
    mkdir -p "$(dirname "$ENV_FILE")"
    
    cat > "$ENV_FILE" << EOF
# Matrix Synapse Configuration
# Згенеровано $(date)

# Основні налаштування
DOMAIN="${DOMAIN}"
BASE_DIR="${BASE_DIR}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD}"

# Функції
ALLOW_PUBLIC_REGISTRATION="${ALLOW_PUBLIC_REGISTRATION}"
ENABLE_FEDERATION="${ENABLE_FEDERATION}"
INSTALL_ELEMENT="${INSTALL_ELEMENT}"
INSTALL_BRIDGES="${INSTALL_BRIDGES}"
SETUP_MONITORING="${SETUP_MONITORING}"
SETUP_BACKUP="${SETUP_BACKUP}"
USE_CLOUDFLARE_TUNNEL="${USE_CLOUDFLARE_TUNNEL}"

# Мости
INSTALL_SIGNAL_BRIDGE="${INSTALL_SIGNAL_BRIDGE}"
INSTALL_WHATSAPP_BRIDGE="${INSTALL_WHATSAPP_BRIDGE}"
INSTALL_DISCORD_BRIDGE="${INSTALL_DISCORD_BRIDGE}"

# Безпека
SSL_ENABLED="${SSL_ENABLED}"
FIREWALL_ENABLED="${FIREWALL_ENABLED}"
RATE_LIMITING="${RATE_LIMITING}"

# Моніторинг
GRAFANA_PASSWORD="${GRAFANA_PASSWORD}"
PROMETHEUS_ENABLED="${PROMETHEUS_ENABLED}"

# Резервне копіювання
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS}"
BACKUP_SCHEDULE="${BACKUP_SCHEDULE}"

# Cloudflare
CLOUDFLARE_TUNNEL_TOKEN="${CLOUDFLARE_TUNNEL_TOKEN}"

# Веб інтерфейс
WEB_DASHBOARD_PORT="${WEB_DASHBOARD_PORT}"
WEB_DASHBOARD_ENABLED="${WEB_DASHBOARD_ENABLED}"
EOF

    # Встановлюємо правильні права
    chmod 600 "$ENV_FILE"
    
    if [[ -n "${SUDO_USER:-}" ]]; then
        local actual_user_id=$(id -u "${SUDO_USER}")
        local actual_group_id=$(id -g "${SUDO_USER}")
        chown "${actual_user_id}:${actual_group_id}" "$ENV_FILE"
    fi
    
    log_success ".env файл створено: $ENV_FILE"
}

# Валідація конфігурації змінних середовища
validate_env_config() {
    log_step "Валідація конфігурації змінних середовища"
    
    local errors=0
    
    # Перевіряємо обов'язкові змінні
    if [[ -z "${DOMAIN}" ]]; then
        log_error "DOMAIN не може бути порожнім"
        ((errors++))
    fi
    
    if [[ -z "${POSTGRES_PASSWORD}" ]]; then
        log_error "POSTGRES_PASSWORD не може бути порожнім"
        ((errors++))
    fi
    
    if [[ -z "${BASE_DIR}" ]]; then
        log_error "BASE_DIR не може бути порожнім"
        ((errors++))
    fi
    
    # Перевіряємо формат домену
    if [[ ! "${DOMAIN}" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        log_error "Некоректний формат домену: ${DOMAIN}"
        ((errors++))
    fi
    
    # Перевіряємо Cloudflare токен якщо потрібно
    if [[ "${USE_CLOUDFLARE_TUNNEL}" == "true" && -z "${CLOUDFLARE_TUNNEL_TOKEN}" ]]; then
        log_error "CLOUDFLARE_TUNNEL_TOKEN не може бути порожнім коли USE_CLOUDFLARE_TUNNEL=true"
        ((errors++))
    fi
    
    if [[ $errors -eq 0 ]]; then
        log_success "Конфігурація змінних середовища валідна"
        return 0
    else
        log_error "Знайдено $errors помилок у конфігурації"
        return 1
    fi
}

# Показ конфігурації змінних середовища
show_env_config() {
    log_step "Конфігурація змінних середовища"
    
    echo "=== Основні налаштування ==="
    echo "Домен: ${DOMAIN}"
    echo "Базова директорія: ${BASE_DIR}"
    echo "Пароль PostgreSQL: [ПРИХОВАНО]"
    
    echo -e "\n=== Функції ==="
    echo "Публічна реєстрація: ${ALLOW_PUBLIC_REGISTRATION}"
    echo "Федерація: ${ENABLE_FEDERATION}"
    echo "Element Web: ${INSTALL_ELEMENT}"
    echo "Мости: ${INSTALL_BRIDGES}"
    echo "Моніторинг: ${SETUP_MONITORING}"
    echo "Резервне копіювання: ${SETUP_BACKUP}"
    echo "Cloudflare Tunnel: ${USE_CLOUDFLARE_TUNNEL}"
    
    if [[ "${INSTALL_BRIDGES}" == "true" ]]; then
        echo -e "\n=== Мости ==="
        echo "Signal Bridge: ${INSTALL_SIGNAL_BRIDGE}"
        echo "WhatsApp Bridge: ${INSTALL_WHATSAPP_BRIDGE}"
        echo "Discord Bridge: ${INSTALL_DISCORD_BRIDGE}"
    fi
    
    echo -e "\n=== Безпека ==="
    echo "SSL: ${SSL_ENABLED}"
    echo "Файрвол: ${FIREWALL_ENABLED}"
    echo "Rate Limiting: ${RATE_LIMITING}"
    
    echo -e "\n=== Веб інтерфейс ==="
    echo "Увімкнено: ${WEB_DASHBOARD_ENABLED}"
    echo "Порт: ${WEB_DASHBOARD_PORT}"
}

# Експорт функцій
export -f init_env_config load_from_env_variables load_default_values
export -f create_env_file validate_env_config show_env_config 