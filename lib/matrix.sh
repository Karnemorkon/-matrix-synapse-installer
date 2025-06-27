#!/bin/bash
# ===================================================================================
# Matrix Module - Matrix Synapse specific functions
# ===================================================================================

# --- Functions ---
generate_synapse_config() {
    log_info "Генерація конфігурації Synapse..."
    
    local config_dir="$BASE_DIR/synapse/config"
    local homeserver_config="$config_dir/homeserver.yaml"
    local log_config="$config_dir/log.config"
    
    # Generate initial configuration
    docker run --rm \
        -v "$config_dir:/data" \
        -e SYNAPSE_SERVER_NAME="$DOMAIN" \
        -e SYNAPSE_REPORT_STATS=no \
        matrixdotorg/synapse:latest generate
    
    # Customize homeserver.yaml
    customize_homeserver_config "$homeserver_config"
    
    # Create log configuration
    create_log_config "$log_config"
    
    # Generate signing key if not exists
    if [[ ! -f "$config_dir/$DOMAIN.signing.key" ]]; then
        docker run --rm \
            -v "$config_dir:/data" \
            matrixdotorg/synapse:latest \
            generate_signing_key.py -o "/data/$DOMAIN.signing.key"
    fi
    
    log_success "Конфігурацію Synapse створено"
}

customize_homeserver_config() {
    local config_file="$1"
    
    log_info "Налаштування homeserver.yaml..."
    
    # Backup original config
    cp "$config_file" "$config_file.backup"
    
    # Update database configuration
    sed -i '/^database:/,/^[^ ]/ {
        /^database:/!{/^[^ ]/!d}
    }' "$config_file"
    
    cat >> "$config_file" << EOF

# Database configuration
database:
  name: psycopg2
  args:
    user: matrix_user
    password: $DB_PASSWORD
    database: matrix_db
    host: postgres
    port: 5432
    cp_min: 5
    cp_max: 10

# Media store configuration
media_store_path: /data/media_store
max_upload_size: 50M
max_image_pixels: 32M

# URL previews
url_preview_enabled: true
url_preview_ip_range_blacklist:
  - '127.0.0.0/8'
  - '10.0.0.0/8'
  - '172.16.0.0/12'
  - '192.168.0.0/16'
  - '100.64.0.0/10'
  - '169.254.0.0/16'
  - '::1/128'
  - 'fe80::/64'
  - 'fc00::/7'

# Registration
enable_registration: false
enable_registration_without_verification: false

# Security
bcrypt_rounds: 12
form_secret: "$(generate_secret)"
macaroon_secret_key: "$(generate_secret)"

# Federation
federation_domain_whitelist: []

# Metrics
enable_metrics: true
metrics_port: 9000

# Logging
log_config: "/data/config/log.config"

# App services (for bridges)
app_service_config_files: []

EOF

    log_success "homeserver.yaml налаштовано"
}

create_log_config() {
    local log_config="$1"
    
    cat > "$log_config" << 'EOF'
version: 1

formatters:
  precise:
    format: '%(asctime)s - %(name)s - %(lineno)d - %(levelname)s - %(request)s - %(message)s'

handlers:
  file:
    class: logging.handlers.TimedRotatingFileHandler
    formatter: precise
    filename: /data/logs/homeserver.log
    when: midnight
    backupCount: 3
    encoding: utf8

  console:
    class: logging.StreamHandler
    formatter: precise

loggers:
  synapse.storage.SQL:
    level: WARN

root:
  level: INFO
  handlers: [file, console]

disable_existing_loggers: false
EOF

    log_success "Конфігурацію логування створено"
}

generate_element_config() {
    log_info "Генерація конфігурації Element Web..."
    
    local element_config="$BASE_DIR/element/config.json"
    
    cat > "$element_config" << EOF
{
    "default_server_config": {
        "m.homeserver": {
            "base_url": "https://$DOMAIN",
            "server_name": "$DOMAIN"
        },
        "m.identity_server": {
            "base_url": "https://vector.im"
        }
    },
    "default_server_name": "$DOMAIN",
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
    "showLabsSettings": true,
    "features": {
        "feature_new_spinner": true,
        "feature_pinning": true,
        "feature_custom_status": true,
        "feature_custom_tags": true,
        "feature_state_counters": true
    },
    "default_federate": true,
    "default_theme": "light",
    "roomDirectory": {
        "servers": [
            "$DOMAIN"
        ]
    },
    "welcomeUserId": "@admin:$DOMAIN",
    "piwik": false,
    "enable_presence_by_hs_url": {
        "https://$DOMAIN": false
    },
    "settingDefaults": {
        "breadcrumbs": true
    }
}
EOF

    log_success "Конфігурацію Element Web створено"
}

create_admin_user() {
    log_info "Створення адміністратора..."
    
    local admin_username="admin"
    local admin_password=$(generate_password 16)
    
    # Wait for Synapse to be ready
    sleep 10
    
    cd "$BASE_DIR"
    docker-compose exec -T synapse register_new_matrix_user \
        -c /data/homeserver.yaml \
        -u "$admin_username" \
        -p "$admin_password" \
        -a \
        http://localhost:8008
    
    # Save admin credentials
    cat > "$BASE_DIR/admin-credentials.txt" << EOF
Matrix Admin Credentials
========================
Username: @$admin_username:$DOMAIN
Password: $admin_password
Server: https://$DOMAIN

Generated on: $(date)

IMPORTANT: Save these credentials securely and delete this file!
EOF
    
    chmod 600 "$BASE_DIR/admin-credentials.txt"
    
    log_success "Адміністратора створено. Дані збережено в $BASE_DIR/admin-credentials.txt"
}

post_installation_setup() {
    log_info "Пост-інсталяційне налаштування..."
    
    # Generate Element config
    generate_element_config
    
    # Create admin user
    create_admin_user
    
    # Setup logrotate
    setup_logrotate
    
    # Create management scripts
    create_management_scripts
    
    log_success "Пост-інсталяційне налаштування завершено"
}

setup_logrotate() {
    log_info "Налаштування ротації логів..."
    
    cat > /etc/logrotate.d/matrix-synapse << EOF
$BASE_DIR/synapse/data/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 991 991
    postrotate
        docker-compose -f $BASE_DIR/docker-compose.yml restart synapse
    endscript
}
EOF

    log_success "Ротацію логів налаштовано"
}

generate_secret() {
    openssl rand -hex 32
}

get_service_urls() {
    cat << EOF
   Matrix Server: https://$DOMAIN
   Element Web: http://$(hostname -I | awk '{print $1}'):8080
   Synapse Admin: http://$(hostname -I | awk '{print $1}'):8081
EOF
    
    if [[ "$SETUP_MONITORING" == "true" ]]; then
        cat << EOF
   Prometheus: http://$(hostname -I | awk '{print $1}'):9090
   Grafana: http://$(hostname -I | awk '{print $1}'):3000
EOF
    fi
}

# Export functions
export -f generate_synapse_config post_installation_setup
export -f create_admin_user get_service_urls
