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
    log_step "Встановлення всіх необхідних залежностей"
    
    # Оновлюємо списки пакетів
    log_info "Оновлення списків пакетів..."
    if ! log_command "apt update -y"; then
        log_error "Помилка оновлення пакетів"
        return 1
    fi
    
    # Встановлюємо базові системні пакети
    log_info "Встановлення базових системних пакетів..."
    if ! log_command "apt install -y curl wget git apt-transport-https ca-certificates gnupg lsb-release"; then
        log_error "Помилка встановлення базових пакетів"
        return 1
    fi
    
    # Встановлюємо Python та залежності для веб API
    log_info "Встановлення Python залежностей..."
    if ! log_command "apt install -y python3 python3-pip python3-venv python3-dev build-essential libssl-dev libffi-dev"; then
        log_error "Помилка встановлення Python залежностей"
        return 1
    fi
    
    # Встановлюємо веб сервери тільки якщо не використовується Cloudflare Tunnel
    if [[ "${USE_CLOUDFLARE_TUNNEL}" != "true" ]]; then
        log_info "Встановлення веб серверів..."
        if ! log_command "apt install -y nginx supervisor"; then
            log_error "Помилка встановлення веб серверів"
            return 1
        fi
    else
        log_info "Пропуск встановлення nginx (активний Cloudflare Tunnel)"
    fi
    
    # Встановлюємо утиліти для системного адміністрування
    log_info "Встановлення системних утиліт..."
    if ! log_command "apt install -y cron rsync unzip jq net-tools"; then
        log_error "Помилка встановлення системних утиліт"
        return 1
    fi
    
    # Встановлюємо залежності для безпеки
    log_info "Встановлення залежностей безпеки..."
    if ! log_command "apt install -y ufw fail2ban openssl"; then
        log_error "Помилка встановлення залежностей безпеки"
        return 1
    fi
    
    # Встановлюємо SSL сертифікати
    log_info "Встановлення SSL залежностей..."
    if ! log_command "apt install -y certbot python3-certbot-nginx"; then
        log_error "Помилка встановлення SSL залежностей"
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
    
    # Встановлюємо Python пакети для веб API через virtualenv
    log_info "Встановлення Python пакетів для веб API у virtualenv..."
    VENV_DIR="/opt/matrix-venv"
    if ! command -v python3 -m venv &> /dev/null; then
        log_error "python3-venv не встановлено. Встановіть пакет python3-venv."
        return 1
    fi
    mkdir -p "$VENV_DIR"
    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    if ! pip install --upgrade pip; then
        log_error "Не вдалося оновити pip у virtualenv"
        deactivate
        return 1
    fi
    if ! pip install flask flask-cors pyyaml requests psutil docker; then
        log_error "Помилка встановлення Python пакетів у virtualenv"
        deactivate
        return 1
    fi
    deactivate
    log_success "Python пакети встановлено у virtualenv: $VENV_DIR"
    
    # Перевіряємо Docker Compose
    if docker compose version >> "${LOG_FILE}" 2>&1; then
        log_success "Docker Compose доступний"
    else
        log_error "Docker Compose недоступний"
        exit 1
    fi
    
    # Встановлюємо Docker Compose plugin
    log_info "Встановлення docker-compose-plugin..."
    if ! log_command "apt install -y docker-compose-plugin"; then
        log_error "Помилка встановлення docker-compose-plugin"
        return 1
    fi
    
    log_success "Всі залежності встановлено успішно"
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

# Генерація Docker Compose конфігурації з офіційними образами
generate_docker_compose() {
    log_step "Створення Docker Compose конфігурації"
    
    # --- Створюємо базову структуру docker-compose.yml ---
    local compose_file="${BASE_DIR}/docker-compose.yml"
    cat > "${compose_file}" <<EOF
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: matrix-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: matrix
      POSTGRES_USER: matrix
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./postgres/init:/docker-entrypoint-initdb.d:ro
    networks:
      - matrix-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U matrix -d matrix"]
      interval: 30s
      timeout: 10s
      retries: 3

  redis:
    image: redis:7-alpine
    container_name: matrix-redis
    restart: unless-stopped
    volumes:
      - redis_data:/data
    networks:
      - matrix-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3

  synapse:
    image: matrixdotorg/synapse:latest
    container_name: matrix-synapse
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    volumes:
      - synapse_data:/data
      # Мапимо лише файл конфігурації, а не всю директорію, щоб уникнути read-only
      - ./synapse/config/homeserver.yaml:/data/homeserver.yaml:ro
    environment:
      - SYNAPSE_SERVER_NAME=${DOMAIN}
      - SYNAPSE_REPORT_STATS=no
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    networks:
      - matrix-network
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8008/_matrix/client/versions || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3

  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: matrix-cloudflared
    restart: unless-stopped
    command: tunnel run --token ${CLOUDFLARE_TUNNEL_TOKEN}
    environment:
      - TUNNEL_TOKEN=${CLOUDFLARE_TUNNEL_TOKEN}
    networks:
      - matrix-network
    profiles:
      - cloudflare
EOF
    # ... далі додавання інших сервісів умовно ...
    if [[ "${USE_CLOUDFLARE_TUNNEL}" != "true" ]]; then
        generate_nginx_config
        cat "${BASE_DIR}/nginx/docker-compose.nginx.yml" >> "${compose_file}"
    else
        log_info "Пропуск додавання nginx у docker-compose.yml (активний Cloudflare Tunnel)"
    fi
    # ... інші сервіси ...
    cat >> "${compose_file}" <<EOF

networks:
  matrix-network:
    driver: bridge

volumes:
  postgres_data:
  redis_data:
  synapse_data:
EOF
    log_success "Docker Compose конфігурацію створено"
}

# Генерація конфігурації Synapse для Docker
generate_synapse_docker_config() {
    log_info "Генерація конфігурації Synapse для Docker"
    
    local synapse_config="${BASE_DIR}/synapse/config/homeserver.yaml"
    # --- Генеруємо секрет для реєстрації, якщо не визначено ---
    if [[ -z "${REGISTRATION_SHARED_SECRET:-}" ]]; then
        REGISTRATION_SHARED_SECRET="$(openssl rand -base64 32)"
    fi
    
    cat > "${synapse_config}" << EOF
# Matrix Synapse Configuration for Docker
# Generated by Matrix Synapse Installer v4.0

server_name: "${DOMAIN}"
pid_file: /data/homeserver.pid
listeners:
  - port: 8008
    tls: false
    type: http
    x_forwarded: true
    resources:
      - names: [client]
        compress: true
      - names: [federation]
        compress: false

database:
  name: psycopg2
  args:
    database: matrix
    user: matrix
    password: ${POSTGRES_PASSWORD}
    host: postgres
    cp_min: 5
    cp_max: 10

redis:
  enabled: true
  host: redis
  port: 6379

log_config: "/data/${DOMAIN}.log.config"

media_store_path: "/data/media_store"

registration_shared_secret: "${REGISTRATION_SHARED_SECRET}"

report_stats: false

enable_metrics: true
metrics_port: 9090

enable_room_list_search: true

max_upload_size: "50M"

dynamic_thumbnails: true
thumbnail_requirements:
  thumbnail_width: 32
  thumbnail_height: 32
  thumbnail_method: crop
  thumbnail_type: image/png

# Federation settings
federation_domain_whitelist:
  - ${DOMAIN}

# Rate limiting
rc_message:
  per_second: 0.2
  burst_count: 10

rc_registration:
  per_second: 0.17
  burst_count: 3

rc_login:
  address:
    per_second: 0.1
    burst_count: 3
  account:
    per_second: 0.1
    burst_count: 3
  failed_attempts:
    per_second: 0.1
    burst_count: 3

# Security settings
trusted_key_servers:
  - server_name: "matrix.org"

# Email settings (optional)
email:
  enable_notifs: false
  smtp_host: localhost
  smtp_port: 25
  require_transport_security: false
  notif_from: "noreply@${DOMAIN}"
  app_name: Matrix
  notif_template_html: notif_mail.html
  notif_template_text: notif_mail.txt

# Password policy
password_config:
  localdb_enabled: true
  policy:
    min_length: 8
    require_digit: true
    require_symbol: true
    require_lowercase: true
    require_uppercase: true

# User consent
user_consent_version: "1.0"
user_consent_server_notice_content:
  msgtype: m.text
  body: >-
    To continue using this homeserver you must review and agree to the
    terms and conditions at https://${DOMAIN}/_matrix/consent

# Room settings
room_invite_state_types:
  - m.room.join_rules
  - m.room.power_levels
  - m.room.visibility
  - m.room.avatar
  - m.room.encryption
  - m.room.name
  - m.room.topic
  - m.room.canonical_alias
  - m.room.aliases
  - m.room.history_visibility

# Retention policy
retention:
  enabled: true
  default_policy:
    min_lifetime: 1d
    max_lifetime: 1y
  allowed_lifetime_min: 1m
  allowed_lifetime_max: 1y

# Background tasks
background_tasks:
  enabled: true
  max_pending_background_tasks: 100

# Event cache
event_cache_size: "10K"

# Caches
caches:
  global_factor: 0.5
  sync_response_cache_duration: 2m

# Experimental features
experimental_features:
  msc1849_enabled: true
  msc2176_enabled: true
  msc2409_enabled: true
  msc2654_enabled: true
  msc2716_enabled: true
  msc2790_enabled: true
  msc2836_enabled: true
  msc2946_enabled: true
  msc3026_enabled: true
  msc3083_enabled: true
  msc3244_enabled: true
  msc3266_enabled: true
  msc3288_enabled: true
  msc3316_enabled: true
  msc3401_enabled: true
  msc3440_enabled: true
  msc3706_enabled: true
  msc3720_enabled: true
  msc3786_enabled: true
  msc3787_enabled: true
  msc3812_enabled: true
  msc3818_enabled: true
  msc3819_enabled: true
  msc3827_enabled: true
  msc3869_enabled: true
  msc3881_enabled: true
  msc3882_enabled: true
  msc3886_enabled: true
  msc3902_enabled: true
  msc3905_enabled: true
  msc3906_enabled: true
  msc3908_enabled: true
  msc3911_enabled: true
  msc3912_enabled: true
  msc3916_enabled: true
  msc3927_enabled: true
  msc3930_enabled: true
  msc3931_enabled: true
  msc3932_enabled: true
  msc3933_enabled: true
  msc3934_enabled: true
  msc3935_enabled: true
  msc3936_enabled: true
  msc3937_enabled: true
  msc3938_enabled: true
  msc3939_enabled: true
  msc3940_enabled: true
  msc3941_enabled: true
  msc3942_enabled: true
  msc3943_enabled: true
  msc3944_enabled: true
  msc3945_enabled: true
  msc3946_enabled: true
  msc3947_enabled: true
  msc3948_enabled: true
  msc3949_enabled: true
  msc3950_enabled: true
  msc3951_enabled: true
  msc3952_enabled: true
  msc3953_enabled: true
  msc3954_enabled: true
  msc3955_enabled: true
  msc3956_enabled: true
  msc3957_enabled: true
  msc3958_enabled: true
  msc3959_enabled: true
  msc3960_enabled: true
  msc3961_enabled: true
  msc3962_enabled: true
  msc3963_enabled: true
  msc3964_enabled: true
  msc3965_enabled: true
  msc3966_enabled: true
  msc3967_enabled: true
  msc3968_enabled: true
  msc3969_enabled: true
  msc3970_enabled: true
  msc3971_enabled: true
  msc3972_enabled: true
  msc3973_enabled: true
  msc3974_enabled: true
  msc3975_enabled: true
  msc3976_enabled: true
  msc3977_enabled: true
  msc3978_enabled: true
  msc3979_enabled: true
  msc3980_enabled: true
  msc3981_enabled: true
  msc3982_enabled: true
  msc3983_enabled: true
  msc3984_enabled: true
  msc3985_enabled: true
  msc3986_enabled: true
  msc3987_enabled: true
  msc3988_enabled: true
  msc3989_enabled: true
  msc3990_enabled: true
  msc3991_enabled: true
  msc3992_enabled: true
  msc3993_enabled: true
  msc3994_enabled: true
  msc3995_enabled: true
  msc3996_enabled: true
  msc3997_enabled: true
  msc3998_enabled: true
  msc3999_enabled: true
  msc4000_enabled: true
EOF
    
    log_success "Конфігурацію Synapse для Docker створено"
}

# Генерація конфігурації Nginx
generate_nginx_config() {
    if [[ "${USE_CLOUDFLARE_TUNNEL}" == "true" ]]; then
        log_info "Пропуск генерації Nginx (активний Cloudflare Tunnel)"
        return 0
    fi
    log_step "Генерація конфігурації Nginx"
    
    local nginx_conf_dir="${BASE_DIR}/nginx/conf.d"
    local nginx_ssl_dir="${BASE_DIR}/nginx/ssl"
    mkdir -p "$nginx_conf_dir" "$nginx_ssl_dir"

    # --- Вибір портів залежно від Cloudflare Tunnel ---
    if [[ "${USE_CLOUDFLARE_TUNNEL}" == "true" ]]; then
        NGINX_PORT_HTTP=8080
        NGINX_PORT_HTTPS=8443
    else
        NGINX_PORT_HTTP=80
        NGINX_PORT_HTTPS=443
    fi

    # --- Генерація docker-compose фрагменту для nginx ---
    cat > "${BASE_DIR}/nginx/docker-compose.nginx.yml" <<EOF
  nginx:
    image: nginx:alpine
    container_name: matrix-nginx
    restart: unless-stopped
    depends_on:
      - synapse
    ports:
      - "${NGINX_PORT_HTTP}:80"
      - "${NGINX_PORT_HTTPS}:443"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
      - ./element:/usr/share/nginx/html:ro
      - ./web/dashboard:/usr/share/nginx/dashboard:ro
    networks:
      - matrix-network
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF

    log_success "Конфігурацію Nginx згенеровано (порт HTTP: ${NGINX_PORT_HTTP})"
}

# Генерація конфігурації моніторингу
generate_monitoring_config() {
    log_info "Генерація конфігурації моніторингу"
    
    # Prometheus конфігурація
    local prometheus_config="${BASE_DIR}/monitoring/prometheus/prometheus.yml"
    
    cat > "${prometheus_config}" << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'matrix-synapse'
    static_configs:
      - targets: ['synapse:9090']
    metrics_path: /_synapse/metrics

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'nginx'
    static_configs:
      - targets: ['nginx:80']
    metrics_path: /nginx_status

  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres:5432']
    metrics_path: /metrics
EOF
    
    # Grafana конфігурація
    mkdir -p "${BASE_DIR}/monitoring/grafana/provisioning/datasources"
    mkdir -p "${BASE_DIR}/monitoring/grafana/provisioning/dashboards"
    
    local grafana_datasource="${BASE_DIR}/monitoring/grafana/provisioning/datasources/prometheus.yml"
    
    cat > "${grafana_datasource}" << EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
EOF
    
    # Loki конфігурація
    local loki_config="${BASE_DIR}/monitoring/loki/local-config.yaml"
    
    cat > "${loki_config}" << EOF
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
    final_sleep: 0s
  chunk_idle_period: 5m
  chunk_retain_period: 30s

schema_config:
  configs:
    - from: 2020-05-15
      store: boltdb
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb:
    directory: /tmp/loki/index

  filesystem:
    directory: /tmp/loki/chunks

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
EOF
    
    # Promtail конфігурація
    local promtail_config="${BASE_DIR}/monitoring/promtail/config.yml"
    
    cat > "${promtail_config}" << EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: system
    static_configs:
    - targets:
        - localhost
      labels:
        job: varlogs
        __path__: /var/log/*log

  - job_name: matrix
    static_configs:
    - targets:
        - localhost
      labels:
        job: matrix
        __path__: /var/log/matrix/*log
EOF
    
    log_success "Конфігурацію моніторингу створено"
}

# Генерація конфігурацій мостів для Docker
generate_bridge_docker_configs() {
    log_info "Генерація конфігурацій мостів для Docker"
    
    # Signal Bridge
    if [[ "${INSTALL_SIGNAL_BRIDGE:-false}" == "true" ]]; then
        mkdir -p "${BASE_DIR}/bridges/signal/config"
        mkdir -p "${BASE_DIR}/bridges/signal/data"
        
        local signal_config="${BASE_DIR}/bridges/signal/config/config.yaml"
        
        cat > "${signal_config}" << EOF
# Signal Bridge Configuration
# Generated by Matrix Synapse Installer v4.0

homeserver:
  address: http://synapse:8008
  domain: ${DOMAIN}

appservice:
  address: http://signal-bridge:29328
  hostname: 0.0.0.0
  port: 29328
  database: sqlite:///signal.db

signal:
  socket: /signald/data/signald.sock
  username: +1234567890  # Change this to your phone number

bridge:
  username_template: "signal_{userid}"
  displayname_template: "Signal {displayname}"
  avatar_template: "mxc://example.com/signal_{userid}"
  
  command_prefix: "!signal"
  
  permissions:
    "*": relay
    "@admin:${DOMAIN}": user
EOF
    fi
    
    # WhatsApp Bridge
    if [[ "${INSTALL_WHATSAPP_BRIDGE:-false}" == "true" ]]; then
        mkdir -p "${BASE_DIR}/bridges/whatsapp/config"
        
        local whatsapp_config="${BASE_DIR}/bridges/whatsapp/config/config.yaml"
        
        cat > "${whatsapp_config}" << EOF
# WhatsApp Bridge Configuration
# Generated by Matrix Synapse Installer v4.0

homeserver:
  address: http://synapse:8008
  domain: ${DOMAIN}

appservice:
  address: http://whatsapp-bridge:29318
  hostname: 0.0.0.0
  port: 29318
  database: sqlite:///whatsapp.db

whatsapp:
  session_path: /data/session
  qr_codes: true
  
bridge:
  username_template: "whatsapp_{userid}"
  displayname_template: "WhatsApp {displayname}"
  avatar_template: "mxc://example.com/whatsapp_{userid}"
  
  command_prefix: "!whatsapp"
  
  permissions:
    "*": relay
    "@admin:${DOMAIN}": user
EOF
    fi
    
    # Discord Bridge
    if [[ "${INSTALL_DISCORD_BRIDGE:-false}" == "true" ]]; then
        mkdir -p "${BASE_DIR}/bridges/discord/config"
        
        local discord_config="${BASE_DIR}/bridges/discord/config/config.yaml"
        
        cat > "${discord_config}" << EOF
# Discord Bridge Configuration
# Generated by Matrix Synapse Installer v4.0

homeserver:
  address: http://synapse:8008
  domain: ${DOMAIN}

appservice:
  address: http://discord-bridge:29334
  hostname: 0.0.0.0
  port: 29334
  database: sqlite:///discord.db

discord:
  token: YOUR_DISCORD_BOT_TOKEN  # Change this
  application_id: YOUR_APPLICATION_ID  # Change this
  
bridge:
  username_template: "discord_{userid}"
  displayname_template: "Discord {displayname}"
  avatar_template: "mxc://example.com/discord_{userid}"
  
  command_prefix: "!discord"
  
  permissions:
    "*": relay
    "@admin:${DOMAIN}": user
EOF
    fi
    
    log_success "Конфігурації мостів для Docker створено"
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

# --- Додаткові функції ---

# Встановлення додаткових залежностей для мостів та моніторингу
install_additional_dependencies() {
    log_step "Встановлення додаткових залежностей"
    
    # Встановлюємо залежності для мостів
    if [[ "${INSTALL_BRIDGES}" == "true" ]]; then
        log_info "Встановлення залежностей для мостів..."
        if ! log_command "apt install -y sqlite3"; then
            log_warning "Не вдалося встановити SQLite для мостів"
        fi
    fi
    
    # Встановлюємо залежності для моніторингу
    if [[ "${SETUP_MONITORING}" == "true" ]]; then
        log_info "Встановлення залежностей для моніторингу..."
        if ! log_command "apt install -y prometheus-node-exporter"; then
            log_warning "Не вдалося встановити Node Exporter"
        fi
    fi
    
    # Встановлюємо залежності для резервного копіювання
    if [[ "${SETUP_BACKUP}" == "true" ]]; then
        log_info "Встановлення залежностей для резервного копіювання..."
        if ! log_command "apt install -y tar gzip"; then
            log_warning "Не вдалося встановити утиліти архівування"
        fi
    fi
    
    log_success "Додаткові залежності встановлено"
}

# Перевірка наявності всіх необхідних команд
verify_dependencies() {
    log_step "Перевірка наявності залежностей"
    
    local missing_deps=()
    local required_commands=(
        "curl" "wget" "git" "python3" "pip3" "docker" "nginx" "supervisord" "cron" "rsync" "unzip" "jq" "ufw"
        "fail2ban-client" "openssl" "certbot" "ss" "ping" "free" "df"
    )
    # Перевіряємо всі стандартні залежності
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    # Окремо перевіряємо docker-compose: приймаємо або стару, або нову команду
    # Якщо немає docker-compose, але є 'docker compose', це теж ок
    if ! command -v docker-compose &> /dev/null; then
        if ! docker compose version &> /dev/null; then
            missing_deps+=("docker-compose")
        fi
    fi
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Відсутні залежності: ${missing_deps[*]}"
        return 1
    else
        log_success "Всі залежності доступні"
        return 0
    fi
}

# Очищення кешу пакетів
cleanup_package_cache() {
    log_info "Очищення кешу пакетів..."
    apt autoremove -y
    apt autoclean
    log_success "Кеш пакетів очищено"
}

# Завантаження Element Web клієнта
download_element_web() {
    log_info "Завантаження Element Web клієнта"
    
    local element_dir="${BASE_DIR}/element"
    local element_version="1.11.50"
    local element_url="https://github.com/vector-im/element-web/releases/download/v${element_version}/element-v${element_version}.tar.gz"
    
    # Створюємо директорію
    mkdir -p "${element_dir}"
    
    # Завантажуємо Element Web
    log_info "Завантаження Element Web v${element_version}..."
    if ! curl -L "${element_url}" | tar -xz -C "${element_dir}" --strip-components=1; then
        log_error "Помилка завантаження Element Web"
        return 1
    fi
    
    # Створюємо конфігурацію Element
    local config_file="${element_dir}/config.json"
    cat > "${config_file}" << EOF
{
    "default_server_config": {
        "m.homeserver": {
            "base_url": "https://${DOMAIN}"
        },
        "m.identity_server": {
            "base_url": "https://vector.im"
        }
    },
    "disable_guests": true,
    "brand": "Matrix Synapse",
    "integrations_ui_url": "https://scalar.vector.im/",
    "integrations_rest_url": "https://scalar.vector.im/api",
    "integrations_widgets_urls": [
        "https://scalar.vector.im/_matrix/integrations/v1",
        "https://scalar.vector.im/api",
        "https://staging.scalar.vector.im/_matrix/integrations/v1",
        "https://staging.scalar.vector.im/api",
        "https://develop.scalar.vector.im/_matrix/integrations/v1",
        "https://develop.scalar.vector.im/api"
    ],
    "bug_report_endpoint_url": "https://element.io/bugreports/submit",
    "uisi_autorageshake_app": "element-auto-uisi",
    "roomDirectory": {
        "servers": [
            "matrix.org"
        ]
    },
    "piwik": {
        "url": "https://piwik.riot.im/",
        "whitelistedHSUrls": ["https://matrix.org"],
        "whitelistedISUrls": ["https://vector.im", "https://matrix.org"],
        "siteId": 1
    },
    "enable_presence_by_hs_url": {
        "https://matrix.org": false
    },
    "settingDefaults": {
        "customTheme": false,
        "showImages": true,
        "autoplayGifsAndVideos": true,
        "enableSyntaxHighlightLanguageDetection": true,
        "autoplayVideo": true,
        "enableMarkdownByDefault": true,
        "showRedactions": true,
        "showJoinLeaves": false,
        "showAvatarChanges": true,
        "showDisplaynameChanges": true,
        "showTypingNotifications": true,
        "autoplayAudio": true,
        "enableSyntaxHighlightLanguageDetection": true,
        "showImages": true,
        "showTypingNotifications": true,
        "showRedactions": true,
        "showJoinLeaves": false,
        "showAvatarChanges": true,
        "showDisplaynameChanges": true,
        "autoplayGifsAndVideos": true,
        "autoplayVideo": true,
        "enableMarkdownByDefault": true,
        "autoplayAudio": true
    },
    "posthog": {
        "projectApiKey": "phc_Jzsm6DTm6V2705XhL28eT58Q3nm8CQbeQkXdSPKTg8U",
        "apiEndpoint": "https://s2.matrix.org/",
        "whitelistedHSUrls": ["https://matrix.org", "https://develop.element.io", "https://app.element.io", "https://test.element.io"]
    }
}
EOF
    
    # Встановлюємо правильні права
    chmod -R 755 "${element_dir}"
    
    if [[ -n "${SUDO_USER:-}" ]]; then
        local actual_user_id=$(id -u "${SUDO_USER}")
        local actual_group_id=$(id -g "${SUDO_USER}")
        chown -R "${actual_user_id}:${actual_group_id}" "${element_dir}"
    fi
    
    log_success "Element Web v${element_version} завантажено та налаштовано"
}

# Експортуємо функції
export -f install_docker_dependencies setup_directory_structure generate_docker_compose start_matrix_services install_additional_dependencies verify_dependencies cleanup_package_cache download_element_web
