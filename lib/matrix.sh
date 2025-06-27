#!/bin/bash
# ===================================================================================
# Matrix Module - Matrix Synapse specific functionality
# ===================================================================================

# --- Constants ---
readonly SYNAPSE_IMAGE="matrixdotorg/synapse:latest"
readonly SYNAPSE_ADMIN_IMAGE="awesometechs/synapse-admin:latest"
readonly ELEMENT_VERSION="v1.11.104"
readonly POSTGRES_IMAGE="postgres:alpine"

# --- Functions ---
setup_directory_structure() {
    log_info "Створення структури директорій"
    
    local base_dir="${CONFIG[BASE_DIR]}"
    
    # Create main directories
    local directories=(
        "${base_dir}"
        "${base_dir}/synapse/config"
        "${base_dir}/synapse/data"
        "${base_dir}/postgres/data"
        "${base_dir}/element"
        "${base_dir}/certs"
        "${base_dir}/bin"
        "${base_dir}/docs"
        "${base_dir}/logs"
    )
    
    for dir in "${directories[@]}"; do
        log_command "mkdir -p '${dir}'"
    done
    
    # Create bridge directories if needed
    if [[ "${CONFIG[INSTALL_BRIDGES]}" == "true" ]]; then
        setup_bridge_directories
    fi
    
    # Create monitoring directories if needed
    if [[ "${CONFIG[SETUP_MONITORING]}" == "true" ]]; then
        setup_monitoring_directories
    fi
    
    log_success "Структуру директорій створено"
}

setup_bridge_directories() {
    local base_dir="${CONFIG[BASE_DIR]}"
    
    local bridges=()
    [[ "${CONFIG[INSTALL_SIGNAL_BRIDGE]}" == "true" ]] && bridges+=("signal-bridge")
    [[ "${CONFIG[INSTALL_WHATSAPP_BRIDGE]}" == "true" ]] && bridges+=("whatsapp-bridge")
    [[ "${CONFIG[INSTALL_TELEGRAM_BRIDGE]}" == "true" ]] && bridges+=("telegram-bridge")
    [[ "${CONFIG[INSTALL_DISCORD_BRIDGE]}" == "true" ]] && bridges+=("discord-bridge")
    
    for bridge in "${bridges[@]}"; do
        log_command "mkdir -p '${base_dir}/${bridge}/config'"
        log_command "mkdir -p '${base_dir}/${bridge}/data'"
    done
}

setup_monitoring_directories() {
    local base_dir="${CONFIG[BASE_DIR]}"
    
    local directories=(
        "${base_dir}/monitoring/prometheus"
        "${base_dir}/monitoring/grafana/dashboards"
        "${base_dir}/monitoring/grafana/datasources"
        "${base_dir}/monitoring/alertmanager"
    )
    
    for dir in "${directories[@]}"; do
        log_command "mkdir -p '${dir}'"
    done
}

generate_synapse_config() {
    log_info "Генерація конфігурації Synapse"
    
    local base_dir="${CONFIG[BASE_DIR]}"
    local domain="${CONFIG[DOMAIN]}"
    
    # Generate initial config
    log_command "docker run --rm -v '${base_dir}/synapse/config:/data' -e SYNAPSE_SERVER_NAME='${domain}' -e SYNAPSE_REPORT_STATS=no '${SYNAPSE_IMAGE}' generate"
    
    # Set proper permissions
    log_command "chown -R 991:991 '${base_dir}/synapse/config'"
    log_command "chown -R 991:991 '${base_dir}/synapse/data'"
    
    # Customize homeserver.yaml
    customize_homeserver_config
    
    log_success "Конфігурацію Synapse згенеровано"
}

customize_homeserver_config() {
    local homeserver_config="${CONFIG[BASE_DIR]}/synapse/config/homeserver.yaml"
    local postgres_password="${CONFIG[POSTGRES_PASSWORD]}"
    
    log_info "Налаштування homeserver.yaml"
    
    # Configure PostgreSQL database
    sed -i "s|#url: postgres://user:password@host:port/database|url: postgres://matrix_user:${postgres_password}@postgres:5432/matrix_db|" "${homeserver_config}"
    sed -i "/database:/a\\  name: pg" "${homeserver_config}"
    
    # Configure registration
    if [[ "${CONFIG[ALLOW_PUBLIC_REGISTRATION]}" == "true" ]]; then
        sed -i "s|enable_registration: false|enable_registration: true|" "${homeserver_config}"
    fi
    
    # Configure federation
    if [[ "${CONFIG[ENABLE_FEDERATION]}" == "false" ]]; then
        if ! grep -q "federation_enabled: false" "${homeserver_config}"; then
            sed -i "/^server_name:/a federation_enabled: false" "${homeserver_config}"
        fi
    fi
    
    # Add metrics configuration if monitoring is enabled
    if [[ "${CONFIG[SETUP_MONITORING]}" == "true" ]]; then
        if ! grep -q "enable_metrics: true" "${homeserver_config}"; then
            cat >> "${homeserver_config}" << EOF

# Metrics for monitoring
enable_metrics: true
metrics_port: 9000
EOF
        fi
    fi
    
    # Configure app services for bridges
    if [[ "${CONFIG[INSTALL_BRIDGES]}" == "true" ]]; then
        configure_bridge_app_services
    fi
    
    log_success "homeserver.yaml налаштовано"
}

configure_bridge_app_services() {
    local homeserver_config="${CONFIG[BASE_DIR]}/synapse/config/homeserver.yaml"
    
    log_info "Налаштування app services для мостів"
    
    if ! grep -q "app_service_config_files:" "${homeserver_config}"; then
        cat >> "${homeserver_config}" << EOF

# Mautrix Bridges Configuration
app_service_config_files:
EOF
    fi
    
    # Add bridge registration files
    local bridges=()
    [[ "${CONFIG[INSTALL_SIGNAL_BRIDGE]}" == "true" ]] && bridges+=("/data/signal-registration.yaml")
    [[ "${CONFIG[INSTALL_WHATSAPP_BRIDGE]}" == "true" ]] && bridges+=("/data/whatsapp-registration.yaml")
    [[ "${CONFIG[INSTALL_TELEGRAM_BRIDGE]}" == "true" ]] && bridges+=("/data/telegram-registration.yaml")
    [[ "${CONFIG[INSTALL_DISCORD_BRIDGE]}" == "true" ]] && bridges+=("/data/discord-registration.yaml")
    
    for bridge_reg in "${bridges[@]}"; do
        if ! grep -q "^\s*-\s*${bridge_reg}" "${homeserver_config}"; then
            echo "  - ${bridge_reg}" >> "${homeserver_config}"
        fi
    done
}

setup_element_web() {
    if [[ "${CONFIG[INSTALL_ELEMENT]}" != "true" ]]; then
        return 0
    fi
    
    log_info "Налаштування Element Web"
    
    local base_dir="${CONFIG[BASE_DIR]}"
    local domain="${CONFIG[DOMAIN]}"
    local element_dir="${base_dir}/element"
    
    # Download Element Web
    local element_tar="element-${ELEMENT_VERSION}.tar.gz"
    local element_url="https://github.com/element-hq/element-web/releases/download/${ELEMENT_VERSION}/${element_tar}"
    
    log_command "curl -L '${element_url}' -o '${base_dir}/${element_tar}'"
    log_command "tar -xzf '${base_dir}/${element_tar}' -C '${element_dir}' --strip-components=1"
    log_command "rm '${base_dir}/${element_tar}'"
    
    # Create Element configuration
    cat > "${element_dir}/config.json" << EOF
{
    "default_server_name": "${domain}",
    "default_server_config": {
        "m.homeserver": {
            "base_url": "https://${domain}",
            "server_name": "${domain}"
        },
        "m.identity_server": {
            "base_url": "https://vector.im"
        }
    },
    "default_identity_server": "https://vector.im",
    "disable_custom_homeserver": false,
    "show_labs_settings": true,
    "brand": "Matrix (${domain})",
    "default_theme": "light",
    "room_directory": {
        "servers": ["${domain}"]
    }
}
EOF
    
    log_success "Element Web налаштовано"
}

generate_docker_compose() {
    log_info "Створення Docker Compose конфігурації"
    
    local base_dir="${CONFIG[BASE_DIR]}"
    local compose_file="${base_dir}/docker-compose.yml"
    
    # Create .env file
    create_env_file
    
    # Generate main docker-compose.yml
    cat > "${compose_file}" << EOF
version: '3.8'

services:
  postgres:
    image: ${POSTGRES_IMAGE}
    restart: unless-stopped
    volumes:
      - ./postgres/data:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: matrix_db
      POSTGRES_USER: matrix_user
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U matrix_user -d matrix_db"]
      interval: 10s
      timeout: 5s
      retries: 5

  synapse:
    image: ${SYNAPSE_IMAGE}
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    volumes:
      - ./synapse/config:/data
      - ./synapse/data:/synapse/data
$(generate_bridge_volumes)
    environment:
      SYNAPSE_SERVER_NAME: ${CONFIG[DOMAIN]}
      SYNAPSE_REPORT_STATS: "no"
      SYNAPSE_CONFIG_PATH: /data/homeserver.yaml
    ports:
      - "8008:8008"
      - "8448:8448"$(generate_metrics_port)
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8008/_matrix/client/versions || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3

  synapse-admin:
    image: ${SYNAPSE_ADMIN_IMAGE}
    restart: unless-stopped
    depends_on:
      - synapse
    environment:
      SYNAPSE_URL: http://synapse:8008
      SYNAPSE_SERVER_NAME: ${CONFIG[DOMAIN]}
    ports:
      - "8080:80"

$(generate_element_service)
$(generate_bridge_services)
$(generate_cloudflare_service)
$(generate_portainer_service)
$(generate_monitoring_services)

$(generate_volumes)
EOF
    
    log_success "Docker Compose конфігурацію створено"
}

create_env_file() {
    local base_dir="${CONFIG[BASE_DIR]}"
    local env_file="${base_dir}/.env"
    
    cat > "${env_file}" << EOF
# Matrix Synapse Environment Variables
POSTGRES_PASSWORD=${CONFIG[POSTGRES_PASSWORD]}
DOMAIN=${CONFIG[DOMAIN]}
EOF
    
    if [[ "${CONFIG[USE_CLOUDFLARE_TUNNEL]}" == "true" ]]; then
        echo "CLOUDFLARE_TUNNEL_TOKEN=${CONFIG[CLOUDFLARE_TUNNEL_TOKEN]}" >> "${env_file}"
    fi
    
    chmod 600 "${env_file}"
}

generate_bridge_volumes() {
    if [[ "${CONFIG[INSTALL_BRIDGES]}" != "true" ]]; then
        return 0
    fi
    
    local volumes=""
    
    [[ "${CONFIG[INSTALL_SIGNAL_BRIDGE]}" == "true" ]] && volumes+="\n      - ./signal-bridge/config/registration.yaml:/data/signal-registration.yaml:ro"
    [[ "${CONFIG[INSTALL_WHATSAPP_BRIDGE]}" == "true" ]] && volumes+="\n      - ./whatsapp-bridge/config/registration.yaml:/data/whatsapp-registration.yaml:ro"
    [[ "${CONFIG[INSTALL_TELEGRAM_BRIDGE]}" == "true" ]] && volumes+="\n      - ./telegram-bridge/config/registration.yaml:/data/telegram-registration.yaml:ro"
    [[ "${CONFIG[INSTALL_DISCORD_BRIDGE]}" == "true" ]] && volumes+="\n      - ./discord-bridge/config/registration.yaml:/data/discord-registration.yaml:ro"
    
    echo -e "${volumes}"
}

generate_metrics_port() {
    if [[ "${CONFIG[SETUP_MONITORING]}" == "true" ]]; then
        echo -e "\n      - \"9000:9000\""
    fi
}

generate_element_service() {
    if [[ "${CONFIG[INSTALL_ELEMENT]}" != "true" ]]; then
        return 0
    fi
    
    cat << EOF
  element:
    image: vectorim/element-web:latest
    restart: unless-stopped
    volumes:
      - ./element:/app
    ports:
      - "80:80"
EOF
}

generate_cloudflare_service() {
    if [[ "${CONFIG[USE_CLOUDFLARE_TUNNEL]}" != "true" ]]; then
        return 0
    fi
    
    cat << EOF
  cloudflared:
    image: cloudflare/cloudflared:latest
    restart: unless-stopped
    command: tunnel run --token \${CLOUDFLARE_TUNNEL_TOKEN}
    environment:
      - TUNNEL_TOKEN=\${CLOUDFLARE_TUNNEL_TOKEN}
EOF
}

generate_portainer_service() {
    if [[ "${CONFIG[INSTALL_PORTAINER]}" != "true" ]]; then
        return 0
    fi
    
    cat << EOF
  portainer:
    image: portainer/portainer-ce:latest
    restart: unless-stopped
    ports:
      - "8000:8000"
      - "9443:9443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
EOF
}

generate_volumes() {
    local volumes=""
    
    if [[ "${CONFIG[INSTALL_PORTAINER]}" == "true" ]]; then
        volumes+="\nvolumes:\n  portainer_data:"
    fi
    
    if [[ "${CONFIG[SETUP_MONITORING]}" == "true" ]]; then
        if [[ -z "${volumes}" ]]; then
            volumes+="\nvolumes:"
        fi
        volumes+="\n  prometheus_data:\n  grafana_data:"
    fi
    
    echo -e "${volumes}"
}

start_matrix_services() {
    log_info "Запуск Matrix сервісів"
    
    local base_dir="${CONFIG[BASE_DIR]}"
    local compose_file="${base_dir}/docker-compose.yml"
    
    # Pull images first
    pull_docker_images "${compose_file}"
    
    # Start services
    start_docker_services "${compose_file}"
    
    # Wait for Synapse to be ready
    wait_for_synapse
    
    log_success "Matrix сервіси запущено"
}

wait_for_synapse() {
    log_info "Очікування запуску Synapse (максимум 3 хвилини)"
    
    local max_attempts=18
    local attempt=1
    
    while [[ ${attempt} -le ${max_attempts} ]]; do
        show_progress ${attempt} ${max_attempts} "Перевірка Synapse..."
        
        if curl -sf http://localhost:8008/_matrix/client/versions > /dev/null 2>&1; then
            echo
            log_success "Synapse запущено успішно!"
            return 0
        fi
        
        sleep 10
        ((attempt++))
    done
    
    echo
    log_error "Synapse не запустився після 3 хвилин очікування"
    log_error "Перевірте логи: docker compose -f ${CONFIG[BASE_DIR]}/docker-compose.yml logs synapse"
    return 1
}

post_installation_setup() {
    log_info "Пост-інсталяційне налаштування"
    
    # Generate bridge registrations if needed
    if [[ "${CONFIG[INSTALL_BRIDGES]}" == "true" ]]; then
        generate_bridge_registrations
    fi
    
    # Create management scripts
    create_management_scripts
    
    # Create documentation
    create_documentation
    
    log_success "Пост-інсталяційне налаштування завершено"
}

create_management_scripts() {
    log_info "Створення скриптів управління"
    
    local base_dir="${CONFIG[BASE_DIR]}"
    local bin_dir="${base_dir}/bin"
    
    # Create matrix-control.sh
    cat > "${bin_dir}/matrix-control.sh" << 'EOF'
#!/bin/bash
# Matrix Control Script

MATRIX_DIR="$(dirname "$(dirname "$0")")"
cd "${MATRIX_DIR}"

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
            docker compose logs -f "$2"
        else
            docker compose logs -f
        fi
        ;;
    update)
        echo "⬆️ Оновлення Docker образів..."
        docker compose pull
        docker compose up -d
        ;;
    backup)
        if [ -f "./bin/backup.sh" ]; then
            ./bin/backup.sh
        else
            echo "❌ Скрипт резервного копіювання не знайдено"
        fi
        ;;
    *)
        echo "Matrix Control Script"
        echo "Використання: $0 {start|stop|restart|status|logs [service]|update|backup}"
        exit 1
        ;;
esac
EOF
    
    chmod +x "${bin_dir}/matrix-control.sh"
    
    log_success "Скрипти управління створено"
}

get_service_urls() {
    local urls=""
    
    if [[ "${CONFIG[USE_CLOUDFLARE_TUNNEL]}" == "true" ]]; then
        urls+="   Matrix: https://${CONFIG[DOMAIN]}\n"
        [[ "${CONFIG[INSTALL_ELEMENT]}" == "true" ]] && urls+="   Element Web: https://${CONFIG[DOMAIN]} (налаштуйте в Cloudflare)\n"
        urls+="   Synapse Admin: https://${CONFIG[DOMAIN]}/admin (налаштуйте в Cloudflare)\n"
    else
        local server_ip
        server_ip=$(hostname -I | awk '{print $1}')
        urls+="   Matrix: http://${server_ip}:8008\n"
        [[ "${CONFIG[INSTALL_ELEMENT]}" == "true" ]] && urls+="   Element Web: http://${server_ip}:80\n"
        urls+="   Synapse Admin: http://${server_ip}:8080\n"
        [[ "${CONFIG[INSTALL_PORTAINER]}" == "true" ]] && urls+="   Portainer: https://${server_ip}:9443\n"
    fi
    
    if [[ "${CONFIG[SETUP_MONITORING]}" == "true" ]]; then
        local server_ip
        server_ip=$(hostname -I | awk '{print $1}')
        urls+="   Prometheus: http://${server_ip}:9090\n"
        urls+="   Grafana: http://${server_ip}:3000\n"
    fi
    
    echo -e "${urls}"
}
