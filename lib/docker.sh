#!/bin/bash
# ===================================================================================
# Docker Module - Docker installation and management
# ===================================================================================

# --- Configuration ---
readonly DOCKER_COMPOSE_VERSION="2.24.0"
readonly DOCKER_GPG_KEY_URL="https://download.docker.com/linux/ubuntu/gpg"
readonly DOCKER_REPO_URL="https://download.docker.com/linux/ubuntu"

# --- Functions ---
install_docker_dependencies() {
    log_info "Встановлення Docker та залежностей..."
    
    # Update package lists
    log_command "apt-get update"
    
    # Install basic packages
    log_info "Встановлення базових пакетів"
    log_command "apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release software-properties-common"
    
    # Install Docker if not present
    if ! command -v docker &>/dev/null; then
        install_docker_engine
    else
        log_success "Docker вже встановлено: $(docker --version)"
    fi
    
    # Install Docker Compose if not present
    if ! command -v docker-compose &>/dev/null; then
        install_docker_compose
    else
        log_success "Docker Compose вже встановлено: $(docker-compose --version)"
    fi
    
    # Start and enable Docker service
    log_command "systemctl start docker"
    log_command "systemctl enable docker"
    
    # Add current user to docker group if not root
    if [[ ${SUDO_USER:-} ]]; then
        log_command "usermod -aG docker ${SUDO_USER}"
        log_info "Користувача ${SUDO_USER} додано до групи docker"
    fi
    
    # Configure Docker
    configure_docker
    
    log_success "Docker встановлено та налаштовано"
}

install_docker_engine() {
    log_info "Встановлення Docker Engine"
    
    # Add Docker's official GPG key
    log_command "install -m 0755 -d /etc/apt/keyrings"
    
    if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
        log_command "curl -fsSL $DOCKER_GPG_KEY_URL | gpg --dearmor -o /etc/apt/keyrings/docker.gpg"
        log_command "chmod a+r /etc/apt/keyrings/docker.gpg"
    fi
    
    # Add Docker repository
    if [[ ! -f /etc/apt/sources.list.d/docker.list ]]; then
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] $DOCKER_REPO_URL $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    fi
    
    # Update package lists and install Docker
    log_command "apt-get update"
    log_command "apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
    
    log_success "Docker Engine встановлено"
}

install_docker_compose() {
    log_info "Встановлення Docker Compose..."
    
    # Try to install via package manager first
    if log_command "apt-get install -y docker-compose-plugin"; then
        log_success "Docker Compose встановлено через пакетний менеджер"
        return 0
    fi
    
    # Fallback to manual installation
    log_warn "Встановлення через пакетний менеджер не вдалося, встановлюю вручну"
    
    local compose_version="$DOCKER_COMPOSE_VERSION"
    
    log_command "curl -L \"https://github.com/docker/compose/releases/download/v${compose_version}/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose"
    log_command "chmod +x /usr/local/bin/docker-compose"
    
    # Create symlink for compatibility
    log_command "ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose"
    
    log_success "Docker Compose встановлено вручну"
}

configure_docker() {
    log_info "Налаштування Docker..."
    
    # Create docker group if it doesn't exist
    if ! getent group docker > /dev/null 2>&1; then
        log_command "groupadd docker"
    fi
    
    # Configure Docker daemon
    log_command "mkdir -p /etc/docker"
    
    cat > /etc/docker/daemon.json << 'EOF'
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2",
    "live-restore": true
}
EOF
    
    # Restart Docker to apply configuration
    log_command "systemctl restart docker"
    
    log_success "Docker налаштовано"
}

generate_docker_compose() {
    log_info "Генерація Docker Compose конфігурації..."
    
    local compose_file="$BASE_DIR/docker-compose.yml"
    local env_file="$BASE_DIR/.env"
    
    # Create .env file
    create_env_file "$env_file"
    
    # Create docker-compose.yml
    cat > "$compose_file" << EOF
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: matrix-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: \${POSTGRES_DB}
      POSTGRES_USER: \${POSTGRES_USER}
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
      POSTGRES_INITDB_ARGS: "--encoding=UTF-8 --lc-collate=C --lc-ctype=C"
    volumes:
      - ./postgres/data:/var/lib/postgresql/data
      - ./postgres/init:/docker-entrypoint-initdb.d
    networks:
      - matrix-net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U \${POSTGRES_USER} -d \${POSTGRES_DB}"]
      interval: 30s
      timeout: 10s
      retries: 3

  synapse:
    image: matrixdotorg/synapse:latest
    container_name: matrix-synapse
    restart: unless-stopped
    environment:
      SYNAPSE_SERVER_NAME: \${DOMAIN}
      SYNAPSE_REPORT_STATS: "no"
    volumes:
      - ./synapse/data:/data
      - ./synapse/config:/data/config
    ports:
      - "8008:8008"
      - "8448:8448"
    networks:
      - matrix-net
    depends_on:
      postgres:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8008/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3

  element:
    image: vectorim/element-web:latest
    container_name: matrix-element
    restart: unless-stopped
    volumes:
      - ./element/config.json:/app/config.json:ro
    ports:
      - "8080:80"
    networks:
      - matrix-net
    depends_on:
      - synapse

  synapse-admin:
    image: awesometechnologies/synapse-admin:latest
    container_name: matrix-synapse-admin
    restart: unless-stopped
    ports:
      - "8081:80"
    networks:
      - matrix-net
    depends_on:
      - synapse

EOF

    # Add monitoring services if enabled
    if [[ "$SETUP_MONITORING" == "true" ]]; then
        add_monitoring_services "$compose_file"
    fi
    
    # Add bridge services if enabled
    if [[ "$INSTALL_BRIDGES" == "true" ]]; then
        add_bridge_services "$compose_file"
    fi
    
    # Add networks section
    cat >> "$compose_file" << 'EOF'

networks:
  matrix-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16

volumes:
  postgres_data:
  synapse_data:
EOF

    log_success "Docker Compose конфігурацію створено: $compose_file"
}

create_env_file() {
    local env_file="$1"
    
    cat > "$env_file" << EOF
# Matrix Synapse Configuration
DOMAIN=$DOMAIN
POSTGRES_DB=matrix_db
POSTGRES_USER=matrix_user
POSTGRES_PASSWORD=$DB_PASSWORD

# Synapse Configuration
SYNAPSE_SERVER_NAME=$DOMAIN
SYNAPSE_REPORT_STATS=no

# Admin Configuration
ADMIN_EMAIL=$ADMIN_EMAIL

# Generated on $(date)
EOF
    
    chmod 600 "$env_file"
    log_success "Файл змінних оточення створено: $env_file"
}

start_matrix_services() {
    log_info "Запуск Matrix сервісів..."
    
    cd "$BASE_DIR"
    
    # Pull latest images
    log_command "docker-compose pull"
    
    # Start services
    log_command "docker-compose up -d"
    
    # Wait for services to be healthy
    wait_for_services
    
    log_success "Matrix сервіси запущено"
}

wait_for_services() {
    log_info "Очікування готовності сервісів..."
    
    local services=("postgres" "synapse")
    local max_attempts=30
    local attempt=1
    
    for service in "${services[@]}"; do
        log_info "Очікування сервісу: $service"
        
        while [[ $attempt -le $max_attempts ]]; do
            if docker-compose ps "$service" | grep -q "healthy\|Up"; then
                log_success "Сервіс $service готовий"
                break
            fi
            
            show_progress $attempt $max_attempts "Очікування $service"
            sleep 10
            ((attempt++))
        done
        
        if [[ $attempt -gt $max_attempts ]]; then
            log_error "Сервіс $service не запустився за відведений час"
            return 1
        fi
        
        attempt=1
    done
    
    log_success "Всі сервіси готові"
}

setup_directory_structure() {
    log_info "Створення структури директорій..."
    
    local directories=(
        "$BASE_DIR"
        "$BASE_DIR/synapse/data"
        "$BASE_DIR/synapse/config"
        "$BASE_DIR/postgres/data"
        "$BASE_DIR/postgres/init"
        "$BASE_DIR/element"
        "$BASE_DIR/nginx"
        "$BASE_DIR/logs"
        "$BASE_DIR/bin"
        "$BASE_DIR/docs"
    )
    
    if [[ "$SETUP_MONITORING" == "true" ]]; then
        directories+=(
            "$BASE_DIR/prometheus"
            "$BASE_DIR/grafana/data"
            "$BASE_DIR/grafana/provisioning/dashboards"
            "$BASE_DIR/grafana/provisioning/datasources"
            "$BASE_DIR/alertmanager"
        )
    fi
    
    if [[ "$SETUP_BACKUP" == "true" ]]; then
        directories+=(
            "$BASE_DIR-backups"
        )
    fi
    
    for dir in "${directories[@]}"; do
        log_command "mkdir -p \"$dir\""
        log_debug "Створено директорію: $dir"
    done
    
    # Set proper permissions
    log_command "chown -R 991:991 \"$BASE_DIR/synapse\""
    log_command "chown -R 472:472 \"$BASE_DIR/grafana\" 2>/dev/null || true"
    
    log_success "Структуру директорій створено"
}

add_monitoring_services() {
    local compose_file="$1"
    
    cat >> "$compose_file" << EOF

  prometheus:
    image: prom/prometheus:latest
    container_name: matrix-prometheus
    restart: unless-stopped
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"
    networks:
      - matrix-net

  grafana:
    image: grafana/grafana:latest
    container_name: matrix-grafana
    restart: unless-stopped
    volumes:
      - ./grafana/data:/var/lib/grafana
      - ./grafana/provisioning/dashboards:/etc/grafana/provisioning/dashboards
      - ./grafana/provisioning/datasources:/etc/grafana/provisioning/datasources
    ports:
      - "3000:3000"
    networks:
      - matrix-net
    depends_on:
      prometheus:
        condition: service_healthy

EOF
}

add_bridge_services() {
    local compose_file="$1"
    
    cat >> "$compose_file" << EOF

  nginx:
    image: nginx:latest
    container_name: matrix-nginx
    restart: unless-stopped
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
    ports:
      - "80:80"
      - "443:443"
    networks:
      - matrix-net
    depends_on:
      - element
      - synapse-admin

EOF
}

check_docker_status() {
    log_info "Перевірка статусу Docker"
    
    if ! systemctl is-active --quiet docker; then
        log_error "Docker не запущено"
        return 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker недоступний"
        return 1
    fi
    
    log_success "Docker працює коректно"
    return 0
}

pull_docker_images() {
    local compose_file=$1
    
    log_info "Завантаження Docker образів"
    
    if [[ ! -f "${compose_file}" ]]; then
        log_error "Docker Compose файл не знайдено: ${compose_file}"
        return 1
    fi
    
    cd "$(dirname "${compose_file}")" || return 1
    
    if log_command "docker-compose pull"; then
        log_success "Docker образи завантажено"
        return 0
    else
        log_error "Помилка завантаження Docker образів"
        return 1
    fi
}

start_docker_services() {
    local compose_file=$1
    
    log_info "Запуск Docker сервісів"
    
    if [[ ! -f "${compose_file}" ]]; then
        log_error "Docker Compose файл не знайдено: ${compose_file}"
        return 1
    fi
    
    cd "$(dirname "${compose_file}")" || return 1
    
    if log_command "docker-compose up -d --remove-orphans"; then
        log_success "Docker сервіси запущено"
        return 0
    else
        log_error "Помилка запуску Docker сервісів"
        return 1
    fi
}

stop_docker_services() {
    local compose_file=$1
    
    log_info "Зупинка Docker сервісів"
    
    if [[ ! -f "${compose_file}" ]]; then
        log_error "Docker Compose файл не знайдено: ${compose_file}"
        return 1
    fi
    
    cd "$(dirname "${compose_file}")" || return 1
    
    if log_command "docker-compose down"; then
        log_success "Docker сервіси зупинено"
        return 0
    else
        log_error "Помилка зупинки Docker сервісів"
        return 1
    fi
}

get_docker_service_status() {
    local compose_file=$1
    
    if [[ ! -f "${compose_file}" ]]; then
        echo "Docker Compose файл не знайдено"
        return 1
    fi
    
    cd "$(dirname "${compose_file}")" || return 1
    docker-compose ps
}

cleanup_docker() {
    log_info "Очищення Docker системи"
    
    # Remove unused containers
    log_command "docker container prune -f"
    
    # Remove unused images
    log_command "docker image prune -f"
    
    # Remove unused volumes
    log_command "docker volume prune -f"
    
    # Remove unused networks
    log_command "docker network prune -f"
    
    log_success "Docker систему очищено"
}

# Export functions
export -f install_docker_dependencies generate_docker_compose
export -f start_matrix_services setup_directory_structure
