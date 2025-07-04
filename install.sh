#!/bin/bash
# ===================================================================================
# Matrix Synapse Автоматичний Інсталятор - Головна Точка Входу
# Версія: 4.0 З підтримкою веб інтерфейсу та змінних середовища
# ===================================================================================

set -euo pipefail

# --- Конфігурація ---
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_NAME="Matrix Synapse Installer"
readonly PROJECT_VERSION="4.0"

# --- Раннє Налаштування Шляхів Конфігурації ---
# Це потрібно зробити перед підключенням модулів для забезпечення узгоджених шляхів
if [[ -n "${SUDO_USER:-}" ]]; then
    # Скрипт запущено з sudo, використовуємо домашню директорію оригінального користувача
    ACTUAL_USER_HOME=$(getent passwd "${SUDO_USER}" | cut -d: -f6)
    CONFIG_DIR="${ACTUAL_USER_HOME}/.config/matrix-installer"
else
    # Скрипт запущено безпосередньо як root
    CONFIG_DIR="/root/.config/matrix-installer"
fi
readonly CONFIG_FILE="${CONFIG_DIR}/config.conf"

# Підключаємо всі модулі
source "${SCRIPT_DIR}/lib/logger.sh"
source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/validator.sh"
source "${SCRIPT_DIR}/lib/docker.sh"
source "${SCRIPT_DIR}/lib/matrix.sh"
source "${SCRIPT_DIR}/lib/bridges.sh"
source "${SCRIPT_DIR}/lib/monitoring.sh"
source "${SCRIPT_DIR}/lib/backup.sh"
source "${SCRIPT_DIR}/lib/security.sh"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/error-handler.sh"
source "${SCRIPT_DIR}/lib/env-config.sh"

# --- Trap для rollback/cleanup ---
trap 'rollback_install; cleanup_install; exit 1' ERR

# --- Перевірки системних вимог ---
check_swap
check_docker_version
check_docker_compose_version

# --- Перевірка оновлення системних пакетів ---
check_system_updates

# --- Головна Функція ---
main() {
    # Ініціалізація логування
    init_logger
    
    # Ініціалізація обробника помилок
    init_error_handler
    
    # Показуємо банер
    show_banner
    
    # Перевіряємо аргументи командного рядка
    parse_command_line_args "$@"
    
    # Перевіряємо передумови
    check_root_privileges
    validate_system_requirements
    
    # Ініціалізація конфігурації змінних середовища
    init_env_config
    
    # Валідація конфігурації змінних середовища
    validate_env_config
    
    # Завантажуємо або створюємо конфігурацію
    if [[ -f "${CONFIG_FILE}" && "${FORCE_NEW_CONFIG:-false}" != "true" ]]; then
        log_info "Знайдено існуючу конфігурацію: ${CONFIG_FILE}"
        
        USE_EXISTING_CONFIG=$(ask_yes_no "Використати існуючу конфігурацію?" "false")
        if [[ "${USE_EXISTING_CONFIG}" == "true" ]]; then
            log_info "Використовую існуючу конфігурацію"
            load_config
        else
            log_info "Створюю нову конфігурацію"
            interactive_config
        fi
    else
        log_info "Створюю нову конфігурацію"
        interactive_config
    fi
    
    # Валідуємо конфігурацію
    validate_config
    
    # Показуємо підсумок конфігурації
    show_config_summary
    
    # Показуємо конфігурацію змінних середовища
    show_env_config
    
    CONTINUE_INSTALL=$(ask_yes_no "Продовжити встановлення?" "false")
    if [[ "${CONTINUE_INSTALL}" != "true" ]]; then
        log_info "Встановлення скасовано користувачем"
        exit 0
    fi
    
    # Виконуємо кроки встановлення
    execute_installation
    
    # Показуємо повідомлення про завершення
    show_completion_message
}

# --- Обробка аргументів командного рядка ---
parse_command_line_args() {
    local args=("$@")
    
    for arg in "${args[@]}"; do
        case "$arg" in
            --force-new-config)
                FORCE_NEW_CONFIG="true"
                log_info "Примусове створення нової конфігурації"
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            --version|-v)
                echo "Matrix Synapse Installer v${PROJECT_VERSION}"
                exit 0
                ;;
            *)
                log_warning "Невідомий аргумент: $arg"
                ;;
        esac
    done
}

# --- Показ довідки ---
show_help() {
    cat << 'EOF'
Matrix Synapse Installer v4.0

Використання:
  ./install.sh [опції]

Опції:
  --force-new-config       Примусове створення нової конфігурації
  --help, -h               Показати цю довідку
  --version, -v            Показати версію

Змінні середовища:
  MATRIX_DOMAIN                    Домен для Matrix сервера
  MATRIX_BASE_DIR                  Базова директорія для встановлення
  MATRIX_POSTGRES_PASSWORD         Пароль для PostgreSQL
  MATRIX_ALLOW_PUBLIC_REGISTRATION Дозволити публічну реєстрацію
  MATRIX_ENABLE_FEDERATION         Увімкнути федерацію
  MATRIX_INSTALL_ELEMENT           Встановити Element Web
  MATRIX_INSTALL_BRIDGES           Встановити мости
  MATRIX_SETUP_MONITORING          Налаштувати моніторинг
  MATRIX_SETUP_BACKUP              Налаштувати резервне копіювання
  MATRIX_USE_CLOUDFLARE_TUNNEL     Використовувати Cloudflare Tunnel
  MATRIX_INSTALL_SIGNAL_BRIDGE     Встановити Signal Bridge
  MATRIX_INSTALL_WHATSAPP_BRIDGE   Встановити WhatsApp Bridge
  MATRIX_INSTALL_DISCORD_BRIDGE    Встановити Discord Bridge
  MATRIX_SSL_ENABLED               Увімкнути SSL
  MATRIX_FIREWALL_ENABLED          Увімкнути файрвол
  MATRIX_RATE_LIMITING             Увімкнути обмеження швидкості
  MATRIX_GRAFANA_PASSWORD          Пароль для Grafana
  MATRIX_PROMETHEUS_ENABLED        Увімкнути Prometheus
  MATRIX_BACKUP_RETENTION_DAYS     Дні зберігання резервних копій
  MATRIX_BACKUP_SCHEDULE           Розклад резервного копіювання
  MATRIX_CLOUDFLARE_TUNNEL_TOKEN   Токен Cloudflare Tunnel
  MATRIX_WEB_DASHBOARD_PORT        Порт веб інтерфейсу
  MATRIX_WEB_DASHBOARD_ENABLED     Увімкнути веб інтерфейс

Приклади:
  # Інтерактивне встановлення
  ./install.sh

  # Встановлення з змінними середовища
  MATRIX_DOMAIN=matrix.example.com ./install.sh

  # Примусове створення нової конфігурації
  ./install.sh --force-new-config
EOF
}

# --- Допоміжні Функції ---
show_banner() {
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║                    🚀 Matrix Synapse Auto Installer 4.0                     ║
║                                                                              ║
║    Автоматизоване встановлення Matrix Synapse з підтримкою мостів,          ║
║         моніторингу, резервного копіювання та веб інтерфейсу                ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo
}

execute_installation() {
    log_info "Початок встановлення Matrix Synapse"
    
    # Крок 1: Встановлення залежностей
    log_step "Встановлення залежностей"
    install_docker_dependencies
    
    # Крок 1.5: Встановлення додаткових залежностей
    log_step "Встановлення додаткових залежностей"
    install_additional_dependencies
    
    # Крок 1.7: Перевірка залежностей
    log_step "Перевірка залежностей"
    if ! verify_dependencies; then
        log_error "Не всі залежності встановлено. Перевірте логи та спробуйте ще раз."
        exit 1
    fi
    
    # Крок 2: Налаштування структури директорій
    log_step "Створення структури директорій"
    setup_directory_structure
    
    # Крок 3: Генерація конфігурацій
    log_step "Генерація конфігураційних файлів"
    generate_synapse_config
    
    # Генеруємо конфігурацію Element якщо увімкнено
    if [[ "${INSTALL_ELEMENT}" == "true" ]]; then
        generate_element_config
    fi
    
    if [[ "${INSTALL_BRIDGES}" == "true" ]]; then
        generate_bridge_configs
    fi
    
    # Крок 4: Налаштування безпеки
    log_step "Налаштування безпеки"
    setup_security
    
    # Крок 5: Налаштування моніторингу
    if [[ "${SETUP_MONITORING}" == "true" ]]; then
        log_step "Налаштування моніторингу"
        setup_monitoring_stack
    fi
    
    # Крок 6: Налаштування системи резервного копіювання
    if [[ "${SETUP_BACKUP}" == "true" ]]; then
        log_step "Налаштування системи резервного копіювання"
        setup_backup_system
    fi
    
    # Крок 7: Налаштування веб інтерфейсу
    if [[ "${WEB_DASHBOARD_ENABLED}" == "true" ]]; then
        log_step "Налаштування веб інтерфейсу"
        log_info "Веб інтерфейс буде доступний через Nginx контейнер"
    fi
    
    # Крок 8: Генерація Docker Compose
    log_step "Створення Docker Compose конфігурації"
    generate_docker_compose

    # Крок 9: Завантаження Element Web
    if [[ "${INSTALL_ELEMENT}" == "true" ]]; then
        log_step "Завантаження Element Web"
        download_element_web
    fi

    # Крок 10: Запуск сервісів
    log_step "Запуск сервісів"
    start_matrix_services
    
    # Крок 11: Пост-інсталяційне налаштування
    log_step "Пост-інсталяційне налаштування"
    post_installation_setup
    
    # Крок 12: Очищення кешу
    log_step "Очищення системи"
    cleanup_package_cache
    
    # --- Видаляємо всі старі контейнери з іменами, що містять matrix-redis, matrix-postgres, matrix-synapse, matrix-nginx ---
    log_info "Видалення всіх старих контейнерів Matrix (redis, postgres, synapse, nginx) перед запуском..."
    docker ps -a --format '{{.Names}}' | grep -E 'matrix.*(redis|postgres|synapse|nginx)' | xargs -r docker rm -f
    # --- Далі стандартний запуск docker-compose ---
    
    log_success "Встановлення завершено успішно!"
}

show_completion_message() {
    cat << EOF

🎉 ВСТАНОВЛЕННЯ ЗАВЕРШЕНО УСПІШНО!

📋 ІНФОРМАЦІЯ ПРО СИСТЕМУ:
   Домен: ${DOMAIN}
   Базова директорія: ${BASE_DIR}
   Конфігураційний файл: ${CONFIG_FILE}

🔗 ДОСТУП ДО СЕРВІСІВ:
$(get_service_urls)

🌐 ВЕБ ІНТЕРФЕЙС:
$(if [[ "${WEB_DASHBOARD_ENABLED}" == "true" ]]; then
    echo "   Dashboard: http://${DOMAIN}/dashboard"
    echo "   API: http://${DOMAIN}/api"
else
    echo "   Веб інтерфейс вимкнено"
fi)

🛠️ УПРАВЛІННЯ СИСТЕМОЮ:
   ${BASE_DIR}/bin/matrix-control.sh status
   ${BASE_DIR}/bin/matrix-control.sh logs
   ${BASE_DIR}/bin/matrix-control.sh backup
   ${BASE_DIR}/bin/matrix-control.sh update

📚 ДОКУМЕНТАЦІЯ:
   ${BASE_DIR}/docs/README.md

👤 СТВОРЕННЯ ПЕРШОГО КОРИСТУВАЧА:
   cd ${BASE_DIR}
   docker compose exec synapse register_new_matrix_user -c /data/homeserver.yaml http://localhost:8008

⚙️ ЗМІННІ СЕРЕДОВИЩА:
   Файл .env створено: ${BASE_DIR}/.env
   Використовуйте змінні середовища для автоматизації

🐳 DOCKER COMPOSE:
   cd ${BASE_DIR}
   docker compose up -d
   docker compose logs -f

✅ Система готова до використання!
EOF
}

# --- Бекапи важливих файлів перед зміною ---
if [[ -f "${BASE_DIR}/.env" && ! -f "${BASE_DIR}/.env.bak" ]]; then
    cp "${BASE_DIR}/.env" "${BASE_DIR}/.env.bak"
fi
if [[ -f "${BASE_DIR}/docker-compose.yml" && ! -f "${BASE_DIR}/docker-compose.yml.bak" ]]; then
    cp "${BASE_DIR}/docker-compose.yml" "${BASE_DIR}/docker-compose.yml.bak"
fi
if [[ -f "${BASE_DIR}/synapse/config/homeserver.yaml" && ! -f "${BASE_DIR}/synapse/config/homeserver.yaml.bak" ]]; then
    cp "${BASE_DIR}/synapse/config/homeserver.yaml" "${BASE_DIR}/synapse/config/homeserver.yaml.bak"
fi
if [[ -f "${BASE_DIR}/nginx/conf.d/matrix.conf" && ! -f "${BASE_DIR}/nginx/conf.d/matrix.conf.bak" ]]; then
    cp "${BASE_DIR}/nginx/conf.d/matrix.conf" "${BASE_DIR}/nginx/conf.d/matrix.conf.bak"
fi

# --- Збереження імен docker-контейнерів при створенні ---
# Приклад: після створення контейнера
# docker run --name mycontainer ...
# echo "mycontainer" >> "${BASE_DIR}/install_containers.list"

# Перевіряємо чи скрипт запущено безпосередньо
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
