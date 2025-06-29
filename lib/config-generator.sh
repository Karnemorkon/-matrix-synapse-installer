#!/bin/bash

# ===================================================================================
# Configuration Generator Module
# ===================================================================================

# Generate Synapse configuration
generate_synapse_config() {
    local config_dir="$1"
    local domain="$2"
    local base_dir="$3"
    local postgres_password="$4"
    local allow_public_registration="$5"
    local enable_federation="$6"
    
    log_step "Створення конфігурації Synapse"
    
    mkdir -p "$config_dir"
    
    cat > "${config_dir}/homeserver.yaml" << EOF
# Matrix Synapse Homeserver Configuration
# Generated on $(date)

server_name: "${domain}"
pid_file: /data/homeserver.pid
listeners:
  - port: 8008
    tls: false
    type: http
    x_forwarded: true
    resources:
      - names: [client, federation]
        compress: false

database:
  name: psycopg2
  args:
    database: matrix_db
    user: matrix_user
    password: "${postgres_password}"
    host: postgres
    cp_min: 5
    cp_max: 10

log_config: "/data/log.yaml"
media_store_path: "/data/media_store"
registration_shared_secret: "$(openssl rand -base64 32)"
report_stats: false
macaroon_secret_key: "$(openssl rand -base64 32)"
form_secret: "$(openssl rand -base64 32)"

# Federation settings
federation_domain_whitelist:
  - "${domain}"

# Registration settings
enable_registration: ${allow_public_registration}
enable_registration_without_verification: false

# Security settings
trusted_key_servers:
  - server_name: "matrix.org"

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

# Content repository
max_upload_size: "50M"
max_image_pixels: "32M"

# User directory
user_directory_search_all_users: false

# Room settings
room_invite_state_types:
  - "m.room.join_rules"
  - "m.room.power_levels"
  - "m.room.visibility"

# Retention settings
retention:
  enabled: true
  default_policy:
    min_lifetime: 1d
    max_lifetime: 1y

# Experimental features
experimental_features:
  msc3266_enabled: true
  msc2409_enabled: true
EOF

    # Create log configuration
    cat > "${config_dir}/log.yaml" << EOF
version: 1
formatters:
  precise:
    format: '%(asctime)s - %(name)s - %(lineno)d - %(levelname)s - %(request)s - %(message)s'
handlers:
  console:
    class: logging.StreamHandler
    formatter: precise
  file:
    class: logging.handlers.RotatingFileHandler
    filename: /data/homeserver.log
    maxBytes: 10485760
    backupCount: 5
    formatter: precise
loggers:
  synapse:
    level: INFO
  synapse.storage.SQL:
    level: WARNING
  synapse.handlers.typing:
    level: WARNING
  synapse.handlers.presence:
    level: WARNING
  synapse.handlers.message:
    level: WARNING
root:
  level: INFO
  handlers: [console, file]
EOF

    log_success "Конфігурація Synapse створена"
}

# Generate bridge configurations
generate_bridge_configs() {
    local bridges_dir="$1"
    local domain="$2"
    local base_dir="$3"
    
    log_step "Створення конфігурацій мостів"
    
    mkdir -p "$bridges_dir"
    
    # Signal Bridge
    if [[ "${INSTALL_SIGNAL_BRIDGE:-false}" == "true" ]]; then
        generate_signal_config "$bridges_dir/signal" "$domain"
    fi
    
    # WhatsApp Bridge
    if [[ "${INSTALL_WHATSAPP_BRIDGE:-false}" == "true" ]]; then
        generate_whatsapp_config "$bridges_dir/whatsapp" "$domain"
    fi
    
    # Discord Bridge
    if [[ "${INSTALL_DISCORD_BRIDGE:-false}" == "true" ]]; then
        generate_discord_config "$bridges_dir/discord" "$domain"
    fi
    
    log_success "Конфігурації мостів створені"
}

generate_signal_config() {
    local bridge_dir="$1"
    local domain="$2"
    
    mkdir -p "$bridge_dir/config"
    
    cat > "$bridge_dir/config/config.yaml" << EOF
# Signal Bridge Configuration
# Generated on $(date)

homeserver:
  address: http://synapse:8008
  domain: ${domain}

appservice:
  address: http://signal-bridge:29328
  hostname: 0.0.0.0
  port: 29328
  database: sqlite:///data/signal.db
  id: signal
  bot_username: signalbot
  bot_displayname: Signal Bridge Bot
  as_token: "$(openssl rand -base64 32)"
  hs_token: "$(openssl rand -base64 32)"

bridge:
  username_template: "signal_{userid}"
  displayname_template: "{displayname} (Signal)"
  command_prefix: "!signal"

signal:
  socket_path: /signald/signald.sock
  outgoing_attachment_dir: /signald/attachments
  avatar_dir: /signald/avatars
  data_dir: /signald/data

logging:
  version: 1
  formatters:
    colored:
      (): mautrix.util.ColorFormatter
      format: "[%(asctime)s] [%(levelname)s@%(name)s] %(message)s"
    normal:
      format: "[%(asctime)s] [%(levelname)s@%(name)s] %(message)s"
  handlers:
    file:
      class: logging.handlers.RotatingFileHandler
      formatter: normal
      filename: /data/signal.log
      maxBytes: 10485760
      backupCount: 10
    console:
      class: logging.StreamHandler
      formatter: colored
  loggers:
    mau:
      level: DEBUG
    aiohttp:
      level: INFO
  root:
    level: DEBUG
    handlers: [file, console]
EOF

    # Create registration file
    cat > "$bridge_dir/config/registration.yaml" << EOF
# Signal Bridge Registration
# Generated on $(date)

id: signal
url: http://signal-bridge:29328
as_token: "$(openssl rand -base64 32)"
hs_token: "$(openssl rand -base64 32)"
sender_localpart: signalbot
namespaces:
  users:
    - exclusive: true
      regex: "@signal_.*"
  aliases: []
  rooms: []
EOF
}

generate_whatsapp_config() {
    local bridge_dir="$1"
    local domain="$2"
    
    mkdir -p "$bridge_dir/config"
    
    cat > "$bridge_dir/config/config.yaml" << EOF
# WhatsApp Bridge Configuration
# Generated on $(date)

homeserver:
  address: http://synapse:8008
  domain: ${domain}

appservice:
  address: http://whatsapp-bridge:29318
  hostname: 0.0.0.0
  port: 29318
  database: sqlite:///data/whatsapp.db
  id: whatsapp
  bot_username: whatsappbot
  bot_displayname: WhatsApp Bridge Bot
  as_token: "$(openssl rand -base64 32)"
  hs_token: "$(openssl rand -base64 32)"

bridge:
  username_template: "wa_{userid}"
  displayname_template: "{displayname} (WhatsApp)"
  command_prefix: "!wa"

whatsapp:
  os_name: Mautrix-WhatsApp bridge
  browser_name: unknown

logging:
  version: 1
  formatters:
    colored:
      (): mautrix.util.ColorFormatter
      format: "[%(asctime)s] [%(levelname)s@%(name)s] %(message)s"
    normal:
      format: "[%(asctime)s] [%(levelname)s@%(name)s] %(message)s"
  handlers:
    file:
      class: logging.handlers.RotatingFileHandler
      formatter: normal
      filename: /data/whatsapp.log
      maxBytes: 10485760
      backupCount: 10
    console:
      class: logging.StreamHandler
      formatter: colored
  loggers:
    mau:
      level: DEBUG
    aiohttp:
      level: INFO
  root:
    level: DEBUG
    handlers: [file, console]
EOF

    # Create registration file
    cat > "$bridge_dir/config/registration.yaml" << EOF
# WhatsApp Bridge Registration
# Generated on $(date)

id: whatsapp
url: http://whatsapp-bridge:29318
as_token: "$(openssl rand -base64 32)"
hs_token: "$(openssl rand -base64 32)"
sender_localpart: whatsappbot
namespaces:
  users:
    - exclusive: true
      regex: "@wa_.*"
  aliases: []
  rooms: []
EOF
}

generate_discord_config() {
    local bridge_dir="$1"
    local domain="$2"
    
    mkdir -p "$bridge_dir/config"
    
    cat > "$bridge_dir/config/config.yaml" << EOF
# Discord Bridge Configuration
# Generated on $(date)

homeserver:
  address: http://synapse:8008
  domain: ${domain}

appservice:
  address: http://discord-bridge:29334
  hostname: 0.0.0.0
  port: 29334
  database: sqlite:///data/discord.db
  id: discord
  bot_username: discordbot
  bot_displayname: Discord Bridge Bot
  as_token: "$(openssl rand -base64 32)"
  hs_token: "$(openssl rand -base64 32)"

bridge:
  username_template: "discord_{userid}"
  displayname_template: "{displayname} (Discord)"
  command_prefix: "!discord"

discord:
  bot_token: "YOUR_DISCORD_BOT_TOKEN"
  application_id: "YOUR_DISCORD_APPLICATION_ID"

logging:
  version: 1
  formatters:
    colored:
      (): mautrix.util.ColorFormatter
      format: "[%(asctime)s] [%(levelname)s@%(name)s] %(message)s"
    normal:
      format: "[%(asctime)s] [%(levelname)s@%(name)s] %(message)s"
  handlers:
    file:
      class: logging.handlers.RotatingFileHandler
      formatter: normal
      filename: /data/discord.log
      maxBytes: 10485760
      backupCount: 10
    console:
      class: logging.StreamHandler
      formatter: colored
  loggers:
    mau:
      level: DEBUG
    aiohttp:
      level: INFO
  root:
    level: DEBUG
    handlers: [file, console]
EOF

    # Create registration file
    cat > "$bridge_dir/config/registration.yaml" << EOF
# Discord Bridge Registration
# Generated on $(date)

id: discord
url: http://discord-bridge:29334
as_token: "$(openssl rand -base64 32)"
hs_token: "$(openssl rand -base64 32)"
sender_localpart: discordbot
namespaces:
  users:
    - exclusive: true
      regex: "@discord_.*"
  aliases: []
  rooms: []
EOF
}

# Generate monitoring configuration
generate_monitoring_config() {
    local monitoring_dir="$1"
    local grafana_password="$2"
    
    log_step "Створення конфігурації моніторингу"
    
    mkdir -p "$monitoring_dir"
    
    # Prometheus configuration
    cat > "$monitoring_dir/prometheus.yml" << EOF
# Prometheus Configuration
# Generated on $(date)

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

  - job_name: 'synapse'
    static_configs:
      - targets: ['synapse:8008']
    metrics_path: '/_synapse/metrics'
    scrape_interval: 30s

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-exporter:9187']
EOF

    # Grafana configuration
    cat > "$monitoring_dir/grafana.ini" << EOF
# Grafana Configuration
# Generated on $(date)

[security]
admin_user = admin
admin_password = ${grafana_password}

[server]
http_port = 3000
domain = localhost
root_url = http://localhost:3000/

[database]
type = sqlite3
path = /var/lib/grafana/grafana.db

[session]
provider = file

[log]
mode = console file
level = info

[paths]
data = /var/lib/grafana
logs = /var/log/grafana
plugins = /var/lib/grafana/plugins
provisioning = /etc/grafana/provisioning
EOF

    log_success "Конфігурація моніторингу створена"
}

# Generate backup configuration
generate_backup_config() {
    local backup_dir="$1"
    local retention_days="$2"
    local schedule="$3"
    
    log_step "Створення конфігурації резервного копіювання"
    
    mkdir -p "$backup_dir"
    
    # Backup script
    cat > "$backup_dir/backup.sh" << 'EOF'
#!/bin/bash

# Matrix Backup Script
# Generated on $(date)

set -euo pipefail

# Configuration
BACKUP_DIR="/DATA/matrix/backups"
MATRIX_DIR="/DATA/matrix"
RETENTION_DAYS="${retention_days}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/matrix-backup-${TIMESTAMP}.tar.gz"
LOG_FILE="${BACKUP_DIR}/backup.log"

# Logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" | tee -a "$LOG_FILE"
}

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Start backup
log "Початок резервного копіювання"

# Stop services for consistent backup
cd "$MATRIX_DIR"
docker compose stop

# Create backup
tar -czf "$BACKUP_FILE" \
    --exclude="${MATRIX_DIR}/backups" \
    --exclude="${MATRIX_DIR}/logs" \
    -C "$(dirname "$MATRIX_DIR")" "$(basename "$MATRIX_DIR")"

# Start services
docker compose start

# Remove old backups
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +${RETENTION_DAYS} -delete

# Check backup size
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
log_success "Резервну копію створено: $BACKUP_FILE (розмір: $BACKUP_SIZE)"

# Cleanup old logs
find "$BACKUP_DIR" -name "*.log" -mtime +7 -delete
EOF

    chmod +x "$backup_dir/backup.sh"
    
    # Cron configuration
    cat > "$backup_dir/cron.txt" << EOF
# Cron configuration for Matrix backup
# Generated on $(date)

# Add this line to crontab for automatic backups
${schedule} ${backup_dir}/backup.sh
EOF

    log_success "Конфігурація резервного копіювання створена"
}

# Generate all configurations
generate_all_configs() {
    local base_dir="$1"
    local domain="$2"
    local postgres_password="$3"
    local allow_public_registration="$4"
    local enable_federation="$5"
    local grafana_password="$6"
    local retention_days="$7"
    local schedule="$8"
    
    log_step "Створення всіх конфігураційних файлів"
    
    # Create base directories
    mkdir -p "$base_dir"
    
    # Generate Synapse configuration
    generate_synapse_config "$base_dir/synapse" "$domain" "$base_dir" "$postgres_password" "$allow_public_registration" "$enable_federation"
    
    # Generate bridge configurations
    generate_bridge_configs "$base_dir/bridges" "$domain" "$base_dir"
    
    # Generate monitoring configuration
    if [[ "${SETUP_MONITORING:-false}" == "true" ]]; then
        generate_monitoring_config "$base_dir/monitoring" "$grafana_password"
    fi
    
    # Generate backup configuration
    if [[ "${SETUP_BACKUP:-false}" == "true" ]]; then
        generate_backup_config "$base_dir/backups" "$retention_days" "$schedule"
    fi
    
    # Set proper permissions
    chown -R 991:991 "$base_dir" 2>/dev/null || true
    chmod -R 750 "$base_dir"
    
    log_success "Всі конфігураційні файли створені"
}

# Export functions
export -f generate_synapse_config generate_bridge_configs generate_monitoring_config generate_backup_config generate_all_configs 