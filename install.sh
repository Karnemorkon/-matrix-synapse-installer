#!/bin/bash
# ===================================================================================
# Matrix Synapse Автоматичний Інсталятор - Головна Точка Входу
# Версія: 3.0 Рефакторована
# ===================================================================================

set -euo pipefail

# --- Конфігурація ---
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_NAME="Matrix Synapse Installer"
readonly PROJECT_VERSION="3.0"

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

# --- Головна Функція ---
main() {
    # Ініціалізація логування
    init_logger
    
    # Показуємо банер
    show_banner
    
    # Перевіряємо передумови
    check_root_privileges
    validate_system_requirements
    
    # Завантажуємо або створюємо конфігурацію
    if [[ -f "${CONFIG_FILE}" ]]; then
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

# --- Допоміжні Функції ---
show_banner() {
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║                    🚀 Matrix Synapse Auto Installer 3.0                     ║
║                                                                              ║
║    Автоматизоване встановлення Matrix Synapse з підтримкою мостів,          ║
║                    моніторингу та резервного копіювання                      ║
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
    
    # Крок 7: Генерація Docker Compose
    log_step "Створення Docker Compose конфігурації"
    generate_docker_compose
    
    # Крок 8: Запуск сервісів
    log_step "Запуск сервісів"
    start_matrix_services
    
    # Крок 9: Пост-інсталяційне налаштування
    log_step "Пост-інсталяційне налаштування"
    post_installation_setup
    
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

🛠️ УПРАВЛІННЯ СИСТЕМОЮ:
   ${BASE_DIR}/bin/matrix-control.sh status
   ${BASE_DIR}/bin/matrix-control.sh logs
   ${BASE_DIR}/bin/matrix-control.sh backup

📚 ДОКУМЕНТАЦІЯ:
   ${BASE_DIR}/docs/README.md

👤 СТВОРЕННЯ ПЕРШОГО КОРИСТУВАЧА:
   cd ${BASE_DIR}
   ./bin/matrix-control.sh user create admin

✅ Система готова до використання!
EOF
}

# Перевіряємо чи скрипт запущено безпосередньо
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
