#!/bin/bash
# ===================================================================================
# Matrix Module - Matrix Synapse specific configuration
# ===================================================================================

# --- Functions ---
generate_synapse_config() {
    log_step "Генерація конфігурації Synapse"
    
    local config_dir="${BASE_DIR}/synapse/config"
    
    # Generate initial config
    log_info "Створення початкової конфігурації..."
    docker run --rm \
        -v "${config_dir}:/data" \
        -e SYNAPSE_SERVER_NAME="${DOMAIN}" \
        -e SYNAPSE_REPORT_STATS=no \
        matrixdotorg/synapse:latest generate &>> "${LOG_FILE}"
    
    # Set proper permissions
    chown -R 991:991 "${config_dir}"
    chmod 600 "${config_dir}/homeserver.yaml"
    
    # Configure database
    configure_database
    
    # Configure registration and federation
    configure_registration_and_federation
    
    log_success "Конфігурацію Synapse створено"
}

configure_database() {
    log_info "Налаштування бази даних..."
    
    local homeserver_config="${BASE_DIR}/synapse/config/homeserver.yaml"
    
    # Replace SQLite with PostgreSQL configuration
    cat >> "${homeserver_config}" << EOF

# Database configuration
database:
  name: psycopg2
  args:
    user: matrix_user
    password: ${POSTGRES_PASSWORD}
    database: matrix_db
    host: postgres
    port: 5432
    cp_min: 5
    cp_max: 10
EOF
}

configure_registration_and_federation() {
    log_info "Налаштування реєстрації та федерації..."
    
    local homeserver_config="${BASE_DIR}/synapse/config/homeserver.yaml"
    
    # Configure registration
    if [[ "${ALLOW_PUBLIC_REGISTRATION}" == "true" ]]; then
        sed -i "s|enable_registration: false|enable_registration: true|" "${homeserver_config}"
    fi
    
    # Configure federation
    if [[ "${ENABLE_FEDERATION}" == "false" ]]; then
        echo "federation_enabled: false" >> "${homeserver_config}"
    fi
    
    # Add metrics configuration
    cat >> "${homeserver_config}" << EOF

# Metrics configuration
enable_metrics: true
metrics_port: 9000
EOF
}

generate_element_config() {
    if [[ "${INSTALL_ELEMENT}" != "true" ]]; then
        return 0
    fi
    
    log_step "Налаштування Element Web"
    
    cat > "${BASE_DIR}/element/config.json" << EOF
{
    "default_server_name": "${DOMAIN}",
    "default_server_config": {
        "m.homeserver": {
            "base_url": "https://${DOMAIN}",
            "server_name": "${DOMAIN}"
        },
        "m.identity_server": {
            "base_url": "https://vector.im"
        }
    },
    "default_identity_server": "https://vector.im",
    "disable_custom_homeserver": false,
    "show_labs_settings": true,
    "brand": "Matrix (${DOMAIN})"
}
EOF
    
    log_success "Element Web налаштовано"
}

post_installation_setup() {
    log_step "Пост-інсталяційне налаштування"
    
    # Generate Element config
    generate_element_config
    
    # Create management script
    create_management_script
    
    # Create documentation
    create_local_documentation
    
    log_success "Пост-інсталяційне налаштування завершено"
}

create_management_script() {
    log_info "Створення скрипта управління..."
    
    cat > "${BASE_DIR}/bin/matrix-control.sh" << 'EOF'
#!/bin/bash
# Matrix Synapse Control Script

MATRIX_DIR="$(dirname "$(dirname "$0")")"
cd "$MATRIX_DIR"

show_usage() {
    cat << USAGE
Matrix Synapse Control Script

Використання: $0 <команда> [параметри]

Команди:
  start                    Запустити всі сервіси
  stop                     Зупинити всі сервіси
  restart                  Перезапустити всі сервіси
  status                   Показати статус сервісів
  logs [service]           Показати логи (всіх сервісів або конкретного)
  update                   Оновити Docker образи
  health                   Перевірити здоров'я системи
  backup                   Створити резервну копію
  user create <username>   Створити нового користувача
  user list               Показати список користувачів

Приклади:
  $0 start
  $0 logs synapse
  $0 user create admin
USAGE
}

case "$1" in
    start)
        echo "🚀 Запуск Matrix системи..."
        docker compose up -d
        ;;
    stop)
        echo "🛑 Зупинка Matrix системи..."
        docker compose down
        ;;
    restart)
        echo "🔄 Перезапуск Matrix системи..."
        docker compose restart
        ;;
    status)
        echo "📊 Статус Matrix системи:"
        docker compose ps
        ;;
    logs)
        if [ -n "$2" ]; then
            echo "📋 Логи сервісу $2:"
            docker compose logs -f "$2"
        else
            echo "📋 Логи всіх сервісів:"
            docker compose logs -f
        fi
        ;;
    update)
        echo "⬆️ Оновлення Docker образів..."
        docker compose pull
        echo "🔄 Перезапуск з новими образами..."
        docker compose up -d
        ;;
    health)
        echo "🏥 Перевірка здоров'я системи:"
        echo -n "Synapse API: "
        if curl -sf http://localhost:8008/_matrix/client/versions > /dev/null; then
            echo "✅ OK"
        else
            echo "❌ Недоступний"
        fi
        
        echo -n "База даних: "
        if docker compose exec -T postgres pg_isready -U matrix_user > /dev/null 2>&1; then
            echo "✅ OK"
        else
            echo "❌ Недоступна"
        fi
        ;;
    backup)
        if [ -f "/DATA/matrix-backups/backup-matrix.sh" ]; then
            echo "💾 Створення резервної копії..."
            /DATA/matrix-backups/backup-matrix.sh
        else
            echo "❌ Скрипт резервного копіювання не знайдено"
        fi
        ;;
    user)
        case "$2" in
            create)
                if [ -z "$3" ]; then
                    echo "❌ Вкажіть ім'я користувача"
                    echo "Використання: $0 user create <username>"
                    exit 1
                fi
                echo "👤 Створення користувача $3..."
                docker compose exec synapse register_new_matrix_user \
                    -c /data/homeserver.yaml \
                    -u "$3" \
                    -a \
                    http://localhost:8008
                ;;
            list)
                echo "👥 Список користувачів:"
                docker compose exec postgres psql -U matrix_user -d matrix_db \
                    -c "SELECT name, admin, deactivated FROM users ORDER BY name;"
                ;;
            *)
                echo "❌ Невідома команда користувача: $2"
                echo "Доступні команди: create, list"
                ;;
        esac
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
EOF
    
    chmod +x "${BASE_DIR}/bin/matrix-control.sh"
    log_success "Скрипт управління створено"
}

create_local_documentation() {
    log_info "Створення локальної документації..."
    
    cat > "${BASE_DIR}/docs/README.md" << EOF
# Matrix Synapse Installation

## Доступ до сервісів

- **Matrix Synapse**: http://localhost:8008
- **Synapse Admin**: http://localhost:8080
$(if [[ "${INSTALL_ELEMENT}" == "true" ]]; then echo "- **Element Web**: http://localhost:80"; fi)
$(if [[ "${SETUP_MONITORING}" == "true" ]]; then echo "- **Grafana**: http://localhost:3000 (admin/admin123)"; echo "- **Prometheus**: http://localhost:9090"; fi)
$(if [[ "${USE_CLOUDFLARE_TUNNEL}" == "true" ]]; then echo "- **Cloudflare Tunnel**: Налаштуйте маршрутизацію в панелі Cloudflare"; fi)

## Управління системою

Використовуйте скрипт управління:

\`\`\`bash
# Статус системи
./bin/matrix-control.sh status

# Перезапуск
./bin/matrix-control.sh restart

# Логи
./bin/matrix-control.sh logs

# Створення користувача
./bin/matrix-control.sh user create admin
\`\`\`

## Створення першого користувача

\`\`\`bash
cd ${BASE_DIR}
docker compose exec synapse register_new_matrix_user \\
    -c /data/homeserver.yaml \\
    -a \\
    -u admin \\
    -p your_password \\
    http://localhost:8008
\`\`\`

## Конфігурація

- Домен: ${DOMAIN}
- Публічна реєстрація: ${ALLOW_PUBLIC_REGISTRATION}
- Федерація: ${ENABLE_FEDERATION}
- Element Web: ${INSTALL_ELEMENT}
- Моніторинг: ${SETUP_MONITORING}
- Cloudflare Tunnel: ${USE_CLOUDFLARE_TUNNEL}
EOF
    
    log_success "Локальну документацію створено"
}

get_service_urls() {
    echo "Matrix Synapse: http://localhost:8008"
    echo "Synapse Admin: http://localhost:8080"
    
    if [[ "${INSTALL_ELEMENT}" == "true" ]]; then
        echo "Element Web: http://localhost:80"
    fi
    
    if [[ "${SETUP_MONITORING}" == "true" ]]; then
        echo "Grafana: http://localhost:3000 (admin/admin123)"
        echo "Prometheus: http://localhost:9090"
    fi
    
    if [[ "${USE_CLOUDFLARE_TUNNEL}" == "true" ]]; then
        echo "Cloudflare Tunnel: Налаштуйте маршрутизацію в панелі Cloudflare"
    fi
}

# Export functions
export -f generate_synapse_config configure_database configure_registration_and_federation
export -f generate_element_config post_installation_setup create_management_script
export -f create_local_documentation get_service_urls
