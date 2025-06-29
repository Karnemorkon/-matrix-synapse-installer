#!/bin/bash
# ===================================================================================
# Модуль Docker - Встановлення та управління Docker
# ===================================================================================

# --- Конфігурація ---
readonly DOCKER_COMPOSE_VERSION="2.24.0"
readonly DOCKER_GPG_KEY_URL="https://download.docker.com/linux/ubuntu/gpg"
readonly DOCKER_REPO_URL="https://download.docker.com/linux/ubuntu"

# --- Функції ---
install_docker_dependencies() {
    log_step "Встановлення Docker залежностей"
    
    # Оновлюємо списки пакетів
    log_info "Оновлення списків пакетів..."
    if ! log_command "apt update -y"; then
        log_error "Помилка оновлення пакетів"
        return 1
    fi
    
    # Встановлюємо базові пакети
    log_info "Встановлення базових пакетів..."
    if ! log_command "apt install -y curl apt-transport-https ca-certificates gnupg lsb-release"; then
        log_error "Помилка встановлення базових пакетів"
        return 1
    fi
    
    # Встановлюємо Docker
    if ! systemctl is-active --quiet docker; then
        log_info "Встановлення Docker Engine..."
        
        # Визначаємо ОС
        if [[ -f /etc/debian_version ]]; then
            # Debian/Ubuntu
            install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            chmod a+r /etc/apt/keyrings/docker.gpg
            
            # Додаємо репозиторій Docker
            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
                $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
                tee /etc/apt/sources.list.d/docker.list > /dev/null
        else
            log_error "Непідтримувана операційна система"
            exit 1
        fi
        
        # Встановлюємо пакети Docker
        if ! log_command "apt update -y"; then
            log_error "Помилка оновлення після додавання репозиторію Docker"
            return 1
        fi
        
        if ! log_command "apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"; then
            log_error "Помилка встановлення Docker"
            return 1
        fi
        
        # Запускаємо та увімкнуємо Docker
        systemctl start docker
        systemctl enable docker
        
        log_success "Docker Engine встановлено"
    else
        log_success "Docker вже встановлено"
    fi
    
    # Перевіряємо Docker Compose
    if docker compose version >> "${LOG_FILE}" 2>&1; then
        log_success "Docker Compose доступний"
    else
        log_error "Docker Compose недоступний"
        exit 1
    fi
}

setup_directory_structure() {
    log_step "Створення структури директорій"
    
    # Створюємо базову директорію
    mkdir -p "${BASE_DIR}"
    
    # Створюємо піддиректорії
    mkdir -p "${BASE_DIR}/synapse/config"
    mkdir -p "${BASE_DIR}/synapse/data"
    mkdir -p "${BASE_DIR}/element"
    mkdir -p "${BASE_DIR}/docs"
    mkdir -p "${BASE_DIR}/bin"
    
    # Створюємо директорії мостів якщо потрібно
    if [[ "${INSTALL_BRIDGES}" == "true" ]]; then
        mkdir -p "${BASE_DIR}/signal-bridge/config"
        mkdir -p "${BASE_DIR}/whatsapp-bridge/config"
        mkdir -p "${BASE_DIR}/telegram-bridge/config"
        mkdir -p "${BASE_DIR}/discord-bridge/config"
    fi
    
    # Створюємо директорії моніторингу якщо потрібно
    if [[ "${SETUP_MONITORING}" == "true" ]]; then
        mkdir -p "${BASE_DIR}/monitoring/prometheus"
        mkdir -p "${BASE_DIR}/monitoring/grafana/dashboards"
        mkdir -p "${BASE_DIR}/monitoring/grafana/datasources"
    fi
    
    log_success "Структуру директорій створено"
}

generate_docker_compose() {
    log_step "Генерація Docker Compose конфігурації"
    
    local compose_file="${BASE_DIR}/docker-compose.yml"
    
    cat > "${compose_file}" << EOF
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    restart: unless-stopped
    volumes:
      - ./synapse/data/postgres:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: matrix_db
      POSTGRES_USER: matrix_user
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U matrix_user -d matrix_db"]
      interval: 30s
      timeout: 10s
      retries: 3

  synapse:
    image: matrixdotorg/synapse:latest
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    volumes:
      - ./synapse/config:/data
      - ./synapse/data:/synapse/data
    environment:
      SYNAPSE_SERVER_NAME: ${DOMAIN}
      SYNAPSE_REPORT_STATS: "no"
      SYNAPSE_CONFIG_PATH: /data/homeserver.yaml
    ports:
      - "8008:8008"
      - "8448:8448"
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8008/_matrix/client/versions || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3

  synapse-admin:
    image: awesometechnologies/synapse-admin:latest
    restart: unless-stopped
    depends_on:
      synapse:
        condition: service_healthy
    environment:
      SYNAPSE_URL: http://synapse:8008
      SYNAPSE_SERVER_NAME: ${DOMAIN}
    ports:
      - "8080:80"
EOF

    # Додаємо Element Web якщо увімкнено
    if [[ "${INSTALL_ELEMENT}" == "true" ]]; then
        cat >> "${compose_file}" << EOF

  element:
    image: vectorim/element-web:latest
    restart: unless-stopped
    volumes:
      - ./element/config.json:/app/config.json:ro
    ports:
      - "80:80"
EOF
    fi
    
    # Додаємо Cloudflare Tunnel якщо увімкнено
    if [[ "${USE_CLOUDFLARE_TUNNEL}" == "true" ]]; then
        cat >> "${compose_file}" << EOF

  cloudflared:
    image: cloudflare/cloudflared:latest
    restart: unless-stopped
    command: tunnel run --token \${CLOUDFLARE_TUNNEL_TOKEN}
    environment:
      - TUNNEL_TOKEN=\${CLOUDFLARE_TUNNEL_TOKEN}
EOF
    fi
    
    # Додаємо моніторинг якщо увімкнено
    if [[ "${SETUP_MONITORING}" == "true" ]]; then
        cat >> "${compose_file}" << EOF

  prometheus:
    image: prom/prometheus:latest
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus:/etc/prometheus
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'

  grafana:
    image: grafana/grafana:latest
    restart: unless-stopped
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./monitoring/grafana:/etc/grafana/provisioning
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
      - GF_USERS_ALLOW_SIGN_UP=false
EOF
    fi
    
    # Додаємо секцію volumes тільки якщо моніторинг увімкнено
    if [[ "${SETUP_MONITORING}" == "true" ]]; then
        cat >> "${compose_file}" << EOF

volumes:
  prometheus_data:
  grafana_data:
EOF
    fi
    
    # Створюємо .env файл
    cat > "${BASE_DIR}/.env" << EOF
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
CLOUDFLARE_TUNNEL_TOKEN=${CLOUDFLARE_TUNNEL_TOKEN:-}
EOF
    
    # Додаємо мости якщо увімкнено
    if [[ "${INSTALL_BRIDGES}" == "true" ]]; then
        # Signal Bridge
        if [[ "${INSTALL_SIGNAL_BRIDGE:-false}" == "true" ]]; then
            cat >> "${compose_file}" << EOF

  signal-bridge:
    image: dock.mau.dev/mautrix/signal:latest
    restart: unless-stopped
    depends_on:
      synapse:
        condition: service_healthy
    volumes:
      - ./bridges/signal/config:/data
      - ./bridges/signal/data:/signald/data
    environment:
      - MAUTRIX_SIGNAL_CONFIG_PATH=/data/config.yaml
    ports:
      - "29328:29328"
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:29328/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF
        fi
        
        # WhatsApp Bridge
        if [[ "${INSTALL_WHATSAPP_BRIDGE:-false}" == "true" ]]; then
            cat >> "${compose_file}" << EOF

  whatsapp-bridge:
    image: dock.mau.dev/mautrix/whatsapp:latest
    restart: unless-stopped
    depends_on:
      synapse:
        condition: service_healthy
    volumes:
      - ./bridges/whatsapp/config:/data
    environment:
      - MAUTRIX_WHATSAPP_CONFIG_PATH=/data/config.yaml
    ports:
      - "29318:29318"
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:29318/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF
        fi
        
        # Discord Bridge
        if [[ "${INSTALL_DISCORD_BRIDGE:-false}" == "true" ]]; then
            cat >> "${compose_file}" << EOF

  discord-bridge:
    image: dock.mau.dev/mautrix/discord:latest
    restart: unless-stopped
    depends_on:
      synapse:
        condition: service_healthy
    volumes:
      - ./bridges/discord/config:/data
    environment:
      - MAUTRIX_DISCORD_CONFIG_PATH=/data/config.yaml
    ports:
      - "29334:29334"
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:29334/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF
        fi
    fi
    
    log_success "Docker Compose конфігурацію створено"
}

start_matrix_services() {
    log_step "Запуск Matrix сервісів"
    
    cd "${BASE_DIR}"
    
    # Спочатку валідуємо docker-compose.yml
    log_info "Перевірка синтаксису Docker Compose файлу..."
    if ! docker compose config > /dev/null 2>&1; then
        log_error "Помилка в синтаксисі Docker Compose файлу"
        log_info "Перевірте файл: ${BASE_DIR}/docker-compose.yml"
        docker compose config 2>&1 | tee -a "${LOG_FILE}"
        return 1
    fi
    
    # Завантажуємо образи з прогресом
    log_info "Завантаження Docker образів..."
    log_info "Це може зайняти кілька хвилин залежно від швидкості інтернету..."
    
    # Показуємо прогрес для docker pull
    if ! docker compose pull 2>&1 | tee -a "${LOG_FILE}"; then
        log_error "Помилка завантаження Docker образів"
        log_info "Перевірте підключення до інтернету та спробуйте ще раз"
        return 1
    fi
    
    # Запускаємо сервіси
    log_info "Запуск сервісів..."
    if ! docker compose up -d 2>&1 | tee -a "${LOG_FILE}"; then
        log_error "Помилка запуску сервісів"
        return 1
    fi
    
    # Чекаємо поки Synapse буде готовий
    log_info "Очікування запуску Synapse..."
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -sf http://localhost:8008/_matrix/client/versions > /dev/null 2>&1; then
            log_success "Matrix Synapse запущено успішно"
            return 0
        fi
        
        log_info "Спроба ${attempt}/${max_attempts}... (очікування 10 секунд)"
        sleep 10
        ((attempt++))
    done
    
    log_error "Matrix Synapse не запустився після ${max_attempts} спроб"
    log_info "Перевірте логи: cd ${BASE_DIR} && docker compose logs synapse"
    return 1
}

# Експортуємо функції
export -f install_docker_dependencies setup_directory_structure generate_docker_compose start_matrix_services
