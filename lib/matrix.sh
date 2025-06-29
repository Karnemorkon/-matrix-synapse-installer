#!/bin/bash
# ===================================================================================
# Модуль Matrix - Обробка конфігурації та налаштування Matrix Synapse
# ===================================================================================

# --- Функції ---
setup_directory_structure() {
    log_step "Створення структури директорій"
    
    # Створюємо основні директорії
    mkdir -p "${BASE_DIR}"/{data,config,logs,backups,bin,docs}
    mkdir -p "${BASE_DIR}/data"/{synapse,postgres,prometheus,grafana}
    mkdir -p "${BASE_DIR}/config"/{synapse,prometheus,grafana,nginx}
    
    # Створюємо директорію Element якщо потрібно
    if [[ "${INSTALL_ELEMENT}" == "true" ]]; then
        mkdir -p "${BASE_DIR}/element"
    fi
    
    # Створюємо директорії мостів якщо потрібно
    if [[ "${INSTALL_BRIDGES}" == "true" ]]; then
        mkdir -p "${BASE_DIR}/bridges"/{telegram,whatsapp,discord}
    fi
    
    # Встановлюємо правильні права
    chown -R 991:991 "${BASE_DIR}/data/synapse"
    chmod -R 755 "${BASE_DIR}"
    
    log_success "Структуру директорій створено"
}

generate_synapse_config() {
    log_step "Генерація конфігурації Synapse"
    
    local config_dir="${BASE_DIR}/config/synapse"
    local data_dir="${BASE_DIR}/data/synapse"
    
    # Генеруємо початкову конфігурацію якщо вона не існує
    if [[ ! -f "${data_dir}/homeserver.yaml" ]]; then
        log_info "Створення початкової конфігурації..."
        docker run --rm \
            -v "${data_dir}:/data" \
            -e SYNAPSE_SERVER_NAME="${DOMAIN}" \
            -e SYNAPSE_REPORT_STATS=no \
            matrixdotorg/synapse:latest generate
    fi
    
    # Налаштовуємо базу даних
    log_info "Налаштування бази даних..."
    cat > "${config_dir}/database.yaml" << EOF
database:
  name: psycopg2
  args:
    user: synapse
    password: ${POSTGRES_PASSWORD}
    database: synapse
    host: postgres
    port: 5432
    cp_min: 5
    cp_max: 10
EOF
    
    # Налаштовуємо реєстрацію та федерацію
    log_info "Налаштування реєстрації та федерації..."
    cat > "${config_dir}/registration.yaml" << EOF
enable_registration: ${ALLOW_PUBLIC_REGISTRATION}
enable_registration_without_verification: ${ALLOW_PUBLIC_REGISTRATION}
federation_domain_whitelist: []
EOF
    
    if [[ "${ENABLE_FEDERATION}" == "false" ]]; then
        echo "federation_domain_whitelist: []" >> "${config_dir}/registration.yaml"
    fi
    
    # Створюємо конфігурацію логування
    cat > "${config_dir}/logging.yaml" << EOF
version: 1
formatters:
  precise:
    format: '%(asctime)s - %(name)s - %(lineno)d - %(levelname)s - %(request)s - %(message)s'
handlers:
  file:
    class: logging.handlers.TimedRotatingFileHandler
    formatter: precise
    filename: /data/homeserver.log
    when: midnight
    backupCount: 3
    encoding: utf8
  console:
    class: logging.StreamHandler
    formatter: precise
loggers:
  synapse.storage.SQL:
    level: INFO
root:
  level: INFO
  handlers: [file, console]
disable_existing_loggers: false
EOF
    
    log_success "Конфігурацію Synapse створено"
}

generate_element_config() {
    if [[ "${INSTALL_ELEMENT}" != "true" ]]; then
        return 0
    fi
    
    log_info "Створення конфігурації Element Web..."
    
    local element_dir="${BASE_DIR}/element"
    mkdir -p "${element_dir}"
    
    cat > "${element_dir}/config.json" << EOF
{
    "default_server_config": {
        "m.homeserver": {
            "base_url": "https://${DOMAIN}",
            "server_name": "${DOMAIN}"
        },
        "m.identity_server": {
            "base_url": "https://vector.im"
        }
    },
    "disable_custom_urls": false,
    "disable_guests": true,
    "disable_login_language_selector": false,
    "disable_3pid_login": false,
    "brand": "Element",
    "integrations_ui_url": "https://scalar.vector.im/",
    "integrations_rest_url": "https://scalar.vector.im/api",
    "integrations_widgets_urls": [
        "https://scalar.vector.im/_matrix/integrations/v1",
        "https://scalar.vector.im/api",
        "https://scalar-staging.vector.im/_matrix/integrations/v1",
        "https://scalar-staging.vector.im/api",
        "https://scalar-staging.riot.im/scalar/api"
    ],
    "bug_report_endpoint_url": "https://element.io/bugreports/submit",
    "defaultCountryCode": "UA",
    "showLabsSettings": false,
    "features": {
        "feature_new_spinner": true,
        "feature_pinning": true,
        "feature_custom_status": true,
        "feature_custom_tags": true,
        "feature_state_counters": true
    },
    "default_federate": ${ENABLE_FEDERATION},
    "default_theme": "light",
    "roomDirectory": {
        "servers": [
            "${DOMAIN}"
        ]
    }
}
EOF
    
    log_success "Конфігурацію Element створено"
}

post_installation_setup() {
    log_info "Виконання пост-інсталяційних налаштувань..."
    
    # Чекаємо поки сервіси запустяться
    sleep 10
    
    # Перевіряємо чи Synapse запущений
    if docker compose -f "${BASE_DIR}/docker-compose.yml" ps synapse | grep -q "Up"; then
        log_success "Synapse запущено успішно"
    else
        log_warning "Synapse може не запуститися. Перевірте логи: docker compose -f ${BASE_DIR}/docker-compose.yml logs synapse"
    fi
    
    # Створюємо скрипт контролю
    create_control_script
    
    # Копіюємо документацію
    cp "${SCRIPT_DIR}/README.md" "${BASE_DIR}/docs/" 2>/dev/null || true
    cp "${SCRIPT_DIR}/docs/"* "${BASE_DIR}/docs/" 2>/dev/null || true
    
    log_success "Пост-інсталяційне налаштування завершено"
}

create_control_script() {
    local control_script="${BASE_DIR}/bin/matrix-control.sh"
    
    cat > "${control_script}" << 'EOF'
#!/bin/bash
# Скрипт Контролю Matrix

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${BASE_DIR}/docker-compose.yml"

case "$1" in
    start)
        echo "Запуск Matrix сервісів..."
        docker compose -f "${COMPOSE_FILE}" up -d
        ;;
    stop)
        echo "Зупинка Matrix сервісів..."
        docker compose -f "${COMPOSE_FILE}" down
        ;;
    restart)
        echo "Перезапуск Matrix сервісів..."
        docker compose -f "${COMPOSE_FILE}" restart
        ;;
    status)
        docker compose -f "${COMPOSE_FILE}" ps
        ;;
    logs)
        if [[ -n "$2" ]]; then
            docker compose -f "${COMPOSE_FILE}" logs -f "$2"
        else
            docker compose -f "${COMPOSE_FILE}" logs -f
        fi
        ;;
    update)
        echo "Оновлення Matrix сервісів..."
        docker compose -f "${COMPOSE_FILE}" pull
        docker compose -f "${COMPOSE_FILE}" up -d
        ;;
    backup)
        echo "Створення резервної копії..."
        "${BASE_DIR}/bin/backup.sh"
        ;;
    user)
        case "$2" in
            create)
                if [[ -z "$3" ]]; then
                    echo "Використання: $0 user create <username>"
                    exit 1
                fi
                echo "Створення користувача $3..."
                docker compose -f "${COMPOSE_FILE}" exec synapse register_new_matrix_user -u "$3" -a -c /data/homeserver.yaml http://localhost:8008
                ;;
            *)
                echo "Доступні команди для користувачів: create"
                ;;
        esac
        ;;
    health)
        echo "Перевірка здоров'я системи..."
        curl -s http://localhost:8008/_matrix/federation/v1/version || echo "Synapse недоступний"
        ;;
    *)
        echo "Використання: $0 {start|stop|restart|status|logs|update|backup|user|health}"
        echo ""
        echo "Команди:"
        echo "  start    - Запустити всі сервіси"
        echo "  stop     - Зупинити всі сервіси"
        echo "  restart  - Перезапустити всі сервіси"
        echo "  status   - Показати статус сервісів"
        echo "  logs     - Показати логи (додайте назву сервісу для конкретних логів)"
        echo "  update   - Оновити всі сервіси"
        echo "  backup   - Створити резервну копію"
        echo "  user     - Управління користувачами"
        echo "  health   - Перевірити здоров'я системи"
        exit 1
        ;;
esac
EOF
    
    chmod +x "${control_script}"
}

get_service_urls() {
    local urls=""
    
    urls+="   Matrix Synapse: http://localhost:8008\n"
    urls+="   Synapse Admin: http://localhost:8080\n"
    
    if [[ "${INSTALL_ELEMENT}" == "true" ]]; then
        urls+="   Element Web: http://localhost:80\n"
    fi
    
    if [[ "${SETUP_MONITORING}" == "true" ]]; then
        urls+="   Grafana: http://localhost:3000 (admin/admin123)\n"
        urls+="   Prometheus: http://localhost:9090\n"
    fi
    
    echo -e "${urls}"
}

# Експортуємо функції
export -f setup_directory_structure generate_synapse_config generate_element_config post_installation_setup create_control_script get_service_urls
