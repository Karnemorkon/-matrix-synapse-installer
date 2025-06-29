#!/bin/bash
# ===================================================================================
# Модуль Конфігурації - Управління конфігурацією встановлення
# ===================================================================================

# --- Змінні Конфігурації ---
# CONFIG_DIR та CONFIG_FILE тепер встановлюються в головному скрипті перед підключенням модулів
# Це забезпечує узгоджені шляхи у всіх модулях

# Значення за замовчуванням
DEFAULT_DOMAIN="matrix.example.com"
DEFAULT_BASE_DIR="/DATA/matrix"
DEFAULT_INSTALL_BRIDGES="false"
DEFAULT_SETUP_MONITORING="true"
DEFAULT_SETUP_BACKUP="true"
DEFAULT_USE_CLOUDFLARE="false"

# --- Функції ---
init_config() {
    mkdir -p "${CONFIG_DIR}"
    
    # Встановлюємо правильне володіння якщо використовуємо sudo
    if [[ -n "${SUDO_USER:-}" ]]; then
        local actual_user_id=$(id -u "${SUDO_USER}")
        local actual_group_id=$(id -g "${SUDO_USER}")
        chown -R "${actual_user_id}:${actual_group_id}" "${CONFIG_DIR}"
        # Також виправляємо володіння батьківської директорії
        local parent_dir="$(dirname "${CONFIG_DIR}")"
        if [[ -d "${parent_dir}" ]]; then
            chown "${actual_user_id}:${actual_group_id}" "${parent_dir}" 2>/dev/null || true
        fi
    fi
    
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
    # Забезпечуємо існування директорії конфігурації
    mkdir -p "${CONFIG_DIR}"
    
    cat > "${CONFIG_FILE}" << EOF
# Конфігурація Matrix Synapse Installer
# Згенеровано $(date)

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

# Конфігурація мостів
INSTALL_SIGNAL_BRIDGE="${INSTALL_SIGNAL_BRIDGE:-false}"
INSTALL_WHATSAPP_BRIDGE="${INSTALL_WHATSAPP_BRIDGE:-false}"
INSTALL_DISCORD_BRIDGE="${INSTALL_DISCORD_BRIDGE:-false}"
EOF

    # Встановлюємо правильне володіння якщо використовуємо sudo
    if [[ -n "${SUDO_USER:-}" ]]; then
        local actual_user_id=$(id -u "${SUDO_USER}")
        local actual_group_id=$(id -g "${SUDO_USER}")
        chown "${actual_user_id}:${actual_group_id}" "${CONFIG_FILE}"
        chown -R "${actual_user_id}:${actual_group_id}" "${CONFIG_DIR}"
    fi
    
    log_success "Конфігурацію збережено в ${CONFIG_FILE}"
}

interactive_config() {
    log_step "Інтерактивна конфігурація"
    
    # Спочатку ініціалізуємо конфігурацію
    init_config
    
    # Конфігурація домену
    read -p "Введіть ваш домен для Matrix [${DEFAULT_DOMAIN}]: " DOMAIN
    DOMAIN=${DOMAIN:-$DEFAULT_DOMAIN}
    
    # Базова директорія
    read -p "Базова директорія для встановлення [${DEFAULT_BASE_DIR}]: " BASE_DIR
    BASE_DIR=${BASE_DIR:-$DEFAULT_BASE_DIR}
    
    # Пароль бази даних
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
    
    # Публічна реєстрація
    ALLOW_PUBLIC_REGISTRATION=$(ask_yes_no "Дозволити публічну реєстрацію користувачів?" "false")
    
    # Федерація
    ENABLE_FEDERATION=$(ask_yes_no "Увімкнути федерацію з іншими Matrix серверами?" "false")
    
    # Element Web
    INSTALL_ELEMENT=$(ask_yes_no "Встановити Element Web клієнт?" "true")
    
    # Мости - детальний вибір
    INSTALL_BRIDGES=$(ask_yes_no "Встановити мости для інтеграції з іншими месенджерами?" "false")
    
    if [[ "${INSTALL_BRIDGES}" == "true" ]]; then
        log_info "Виберіть мости для встановлення:"
        echo
        
        # Signal Bridge
        INSTALL_SIGNAL_BRIDGE=$(ask_yes_no "  📱 Signal Bridge (інтеграція з Signal)?" "false")
        
        # WhatsApp Bridge
        INSTALL_WHATSAPP_BRIDGE=$(ask_yes_no "  💬 WhatsApp Bridge (інтеграція з WhatsApp)?" "false")
        
        # Discord Bridge
        INSTALL_DISCORD_BRIDGE=$(ask_yes_no "  🎮 Discord Bridge (інтеграція з Discord)?" "false")
        
        # Перевірка чи вибрано хоча б один міст
        if [[ "${INSTALL_SIGNAL_BRIDGE}" == "false" && \
              "${INSTALL_WHATSAPP_BRIDGE}" == "false" && \
              "${INSTALL_DISCORD_BRIDGE}" == "false" ]]; then
            log_warning "Не вибрано жодного моста. Мости не будуть встановлені."
            INSTALL_BRIDGES="false"
        else
            log_success "Вибрано мости для встановлення"
        fi
    else
        # Якщо мости не встановлюються, встановлюємо всі значення в false
        INSTALL_SIGNAL_BRIDGE="false"
        INSTALL_WHATSAPP_BRIDGE="false"
        INSTALL_DISCORD_BRIDGE="false"
    fi
    
    # Моніторинг
    SETUP_MONITORING=$(ask_yes_no "Налаштувати систему моніторингу (Prometheus + Grafana)?" "true")
    
    # Резервне копіювання
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
    
    # Валідуємо домен
    if [[ ! "${DOMAIN}" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        log_error "Некоректний формат домену: ${DOMAIN}"
        exit 1
    fi
    
    # Валідуємо базову директорію
    if [[ ! -d "$(dirname "${BASE_DIR}")" ]]; then
        log_error "Батьківська директорія не існує: $(dirname "${BASE_DIR}")"
        exit 1
    fi
    
    # Валідуємо пароль
    if [[ -z "${POSTGRES_PASSWORD}" ]]; then
        log_error "Пароль бази даних не може бути порожнім"
        exit 1
    fi
    
    # Валідуємо Cloudflare токен якщо потрібно
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
    
    # Показати вибрані мости
    if [[ "${INSTALL_BRIDGES}" == "true" ]]; then
        echo "Вибрані мости:"
        [[ "${INSTALL_SIGNAL_BRIDGE:-false}" == "true" ]] && echo "  📱 Signal Bridge"
        [[ "${INSTALL_WHATSAPP_BRIDGE:-false}" == "true" ]] && echo "  💬 WhatsApp Bridge"
        [[ "${INSTALL_DISCORD_BRIDGE:-false}" == "true" ]] && echo "  🎮 Discord Bridge"
    fi
    
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

get_service_urls() {
    local urls=""
    
    # Matrix Synapse
    urls+="   Matrix Synapse: http://${DOMAIN}:8008\n"
    
    # Element Web - основний домен
    if [[ "${INSTALL_ELEMENT}" == "true" ]]; then
        urls+="   Element Web: https://${DOMAIN}\n"
    fi
    
    # Synapse Admin - тільки локально
    urls+="   Synapse Admin: http://localhost:8080 (локальний доступ)\n"
    
    # Сервіси моніторингу
    if [[ "${SETUP_MONITORING}" == "true" ]]; then
        urls+="   Grafana: http://localhost:3000 (локальний доступ)\n"
        urls+="   Prometheus: http://localhost:9090 (локальний доступ)\n"
    fi
    
    echo -e "${urls}"
}

# Експортуємо функції
export -f init_config load_config save_config interactive_config validate_config show_config_summary ask_yes_no get_service_urls
