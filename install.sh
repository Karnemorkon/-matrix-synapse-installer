#!/bin/bash
# ===================================================================================
# Matrix Synapse Auto Installer - Main Entry Point
# Version: 3.0 Refactored
# ===================================================================================

set -euo pipefail

# --- Configuration ---
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_NAME="Matrix Synapse Installer"
readonly PROJECT_VERSION="3.0"

# Source all modules
source "${SCRIPT_DIR}/lib/logger.sh"
source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/validator.sh"
source "${SCRIPT_DIR}/lib/docker.sh"
source "${SCRIPT_DIR}/lib/matrix.sh"
source "${SCRIPT_DIR}/lib/bridges.sh"
source "${SCRIPT_DIR}/lib/monitoring.sh"
source "${SCRIPT_DIR}/lib/backup.sh"
source "${SCRIPT_DIR}/lib/security.sh"

# --- Main Function ---
main() {
    # Initialize logging
    init_logger
    
    # Show banner
    show_banner
    
    # Check prerequisites
    check_root_privileges
    validate_system_requirements
    
    # Load or create configuration
    if [[ -f "${CONFIG_FILE}" ]]; then
        log_info "Знайдено існуючу конфігурацію: ${CONFIG_FILE}"
        load_config
        
        if ask_yes_no "Використати існуючу конфігурацію?"; then
            log_info "Використовую існуючу конфігурацію"
        else
            interactive_config
        fi
    else
        log_info "Створюю нову конфігурацію"
        interactive_config
    fi
    
    # Validate configuration
    validate_config
    
    # Show configuration summary
    show_config_summary
    
    if ! ask_yes_no "Продовжити встановлення?"; then
        log_info "Встановлення скасовано користувачем"
        exit 0
    fi
    
    # Execute installation steps
    execute_installation
    
    # Show completion message
    show_completion_message
}

# --- Helper Functions ---
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
    
    # Step 1: Install dependencies
    log_step "Встановлення залежностей"
    install_docker_dependencies
    
    # Step 2: Setup directory structure
    log_step "Створення структури директорій"
    setup_directory_structure
    
    # Step 3: Generate configurations
    log_step "Генерація конфігураційних файлів"
    generate_synapse_config
    
    if [[ "${INSTALL_BRIDGES}" == "true" ]]; then
        generate_bridge_configs
    fi
    
    # Step 4: Setup security
    log_step "Налаштування безпеки"
    setup_security
    
    # Step 5: Setup monitoring
    if [[ "${SETUP_MONITORING}" == "true" ]]; then
        log_step "Налаштування моніторингу"
        setup_monitoring_stack
    fi
    
    # Step 6: Setup backup system
    if [[ "${SETUP_BACKUP}" == "true" ]]; then
        log_step "Налаштування системи резервного копіювання"
        setup_backup_system
    fi
    
    # Step 7: Generate Docker Compose
    log_step "Створення Docker Compose конфігурації"
    generate_docker_compose
    
    # Step 8: Start services
    log_step "Запуск сервісів"
    start_matrix_services
    
    # Step 9: Post-installation setup
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

# Check if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
