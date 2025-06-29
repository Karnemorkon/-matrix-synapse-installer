#!/bin/bash
# ===================================================================================
# Bridges Module - Matrix bridge configuration
# ===================================================================================

# --- Constants ---
readonly MAUTRIX_REGISTRY="dock.mau.dev/mautrix"

# --- Bridge Configuration ---
declare -A BRIDGE_IMAGES=(
    ["signal"]="dock.mau.dev/mautrix/signal:latest"
    ["whatsapp"]="dock.mau.dev/mautrix/whatsapp:latest"
    ["telegram"]="dock.mau.dev/mautrix/telegram:latest"
    ["discord"]="dock.mau.dev/mautrix/discord:latest"
)

declare -A BRIDGE_PORTS=(
    ["signal"]="29328"
    ["whatsapp"]="29318"
    ["telegram"]="29317"
    ["discord"]="29334"
)

declare -A BRIDGE_APP_IDS=(
    [signal]="io.mau.bridge.signal"
    [whatsapp]="io.mau.bridge.whatsapp"
    [telegram]="io.mau.bridge.telegram"
    [discord]="io.mau.bridge.discord"
)

# --- Functions ---
generate_bridge_configs() {
    if [[ "${INSTALL_BRIDGES}" != "true" ]]; then
        return 0
    fi
    
    log_step "Налаштування мостів Matrix"
    
    # Створюємо директорію для мостів
    mkdir -p "${BASE_DIR}/bridges"
    
    # Лічильник встановлених мостів
    local bridges_installed=0
    
    # Signal Bridge
    if [[ "${INSTALL_SIGNAL_BRIDGE:-false}" == "true" ]]; then
        log_info "Налаштування Signal Bridge..."
        setup_bridge "signal"
        bridges_installed=$((bridges_installed + 1))
    fi
    
    # WhatsApp Bridge
    if [[ "${INSTALL_WHATSAPP_BRIDGE:-false}" == "true" ]]; then
        log_info "Налаштування WhatsApp Bridge..."
        setup_bridge "whatsapp"
        bridges_installed=$((bridges_installed + 1))
    fi
    
    # Discord Bridge
    if [[ "${INSTALL_DISCORD_BRIDGE:-false}" == "true" ]]; then
        log_info "Налаштування Discord Bridge..."
        setup_bridge "discord"
        bridges_installed=$((bridges_installed + 1))
    fi
    
    if [[ $bridges_installed -gt 0 ]]; then
        log_success "Налаштовано $bridges_installed мостів"
        
        # Створюємо загальний файл реєстрації мостів для Synapse
        create_bridge_registration_file
        
        log_info "Для завершення налаштування мостів потрібно:"
        log_info "1. Налаштувати кожен міст окремо після встановлення"
        log_info "2. Додати реєстраційні файли до конфігурації Synapse"
        log_info "3. Перезапустити Synapse після налаштування мостів"
    else
        log_warning "Не вибрано жодного моста для встановлення"
    fi
}

setup_bridge() {
    local bridge_name="$1"
    local bridge_dir="${BASE_DIR}/bridges/${bridge_name}"
    local config_dir="$bridge_dir/config"
    local data_dir="$bridge_dir/data"
    
    log_info "Налаштування моста: $bridge_name"
    
    # Create directories
    mkdir -p "$config_dir"
    mkdir -p "$data_dir"
    
    # Generate bridge configuration
    generate_bridge_config "$bridge_name" "$config_dir"
    
    # Generate registration file
    generate_registration_file "$bridge_name" "$config_dir"
    
    # Create documentation
    create_bridge_documentation "$bridge_name" "$bridge_dir"
    
    # Set proper permissions
    chown -R 991:991 "$bridge_dir" 2>/dev/null || true
    chmod -R 750 "$bridge_dir"
    
    log_success "Міст $bridge_name налаштовано в $bridge_dir"
}

generate_bridge_config() {
    local bridge_name="$1"
    local config_dir="$2"
    local config_file="$config_dir/config.yaml"
    
    case $bridge_name in
        "signal")
            generate_signal_config "$config_file"
            ;;
        "whatsapp")
            generate_whatsapp_config "$config_file"
            ;;
        "telegram")
            generate_telegram_config "$config_file"
            ;;
        "discord")
            generate_discord_config "$config_file"
            ;;
    esac
}

generate_signal_config() {
    local config_file="$1"
    
    cat > "$config_file" << EOF
homeserver:
    address: http://synapse:8008
    domain: $DOMAIN

appservice:
    address: http://signal-bridge:29328
    hostname: 0.0.0.0
    port: 29328
    database: sqlite:///data/mautrix-signal.db
    id: signal
    bot_username: signalbot
    bot_displayname: Signal Bridge Bot
    bot_avatar: mxc://maunium.net/wPiVVdRgZAaiPMLkOsZqJdOX
    as_token: "$(generate_token)"
    hs_token: "$(generate_token)"

bridge:
    username_template: "signal_{userid}"
    displayname_template: "{displayname} (Signal)"
    command_prefix: "!signal"
    
    permissions:
        "$DOMAIN": user
        "@admin:$DOMAIN": admin

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
            filename: /data/bridge.log
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
}

generate_whatsapp_config() {
    local config_file="$1"
    
    cat > "$config_file" << EOF
homeserver:
    address: http://synapse:8008
    domain: $DOMAIN

appservice:
    address: http://whatsapp-bridge:29318
    hostname: 0.0.0.0
    port: 29318
    database: sqlite:///data/mautrix-whatsapp.db
    id: whatsapp
    bot_username: whatsappbot
    bot_displayname: WhatsApp Bridge Bot
    bot_avatar: mxc://maunium.net/NeXNQarUbrlYBiPCpprYsRqr
    as_token: "$(generate_token)"
    hs_token: "$(generate_token)"

bridge:
    username_template: "whatsapp_{userid}"
    displayname_template: "{displayname} (WhatsApp)"
    command_prefix: "!wa"
    
    permissions:
        "$DOMAIN": user
        "@admin:$DOMAIN": admin

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
            filename: /data/bridge.log
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
}

generate_telegram_config() {
    local config_file="$1"
    
    cat > "$config_file" << EOF
homeserver:
    address: http://synapse:8008
    domain: $DOMAIN

appservice:
    address: http://telegram-bridge:29317
    hostname: 0.0.0.0
    port: 29317
    database: sqlite:///data/mautrix-telegram.db
    id: telegram
    bot_username: telegrambot
    bot_displayname: Telegram Bridge Bot
    bot_avatar: mxc://maunium.net/tJCRmUyJDsgRNgqhOgoiHWbX
    as_token: "$(generate_token)"
    hs_token: "$(generate_token)"

bridge:
    username_template: "telegram_{userid}"
    alias_template: "telegram_{groupname}"
    displayname_template: "{displayname} (Telegram)"
    command_prefix: "!tg"
    
    permissions:
        "$DOMAIN": user
        "@admin:$DOMAIN": admin

telegram:
    api_id: 12345
    api_hash: "your_api_hash_here"
    bot_token: "your_bot_token_here"

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
            filename: /data/bridge.log
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
}

generate_discord_config() {
    local config_file="$1"
    
    cat > "$config_file" << EOF
homeserver:
    address: http://synapse:8008
    domain: $DOMAIN

appservice:
    address: http://discord-bridge:29334
    hostname: 0.0.0.0
    port: 29334
    database: sqlite:///data/mautrix-discord.db
    id: discord
    bot_username: discordbot
    bot_displayname: Discord Bridge Bot
    bot_avatar: mxc://maunium.net/BcrEmbrOVviWRyaBHZfKIhTX
    as_token: "$(generate_token)"
    hs_token: "$(generate_token)"

bridge:
    username_template: "discord_{userid}"
    displayname_template: "{displayname} (Discord)"
    command_prefix: "!discord"
    
    permissions:
        "$DOMAIN": user
        "@admin:$DOMAIN": admin

discord:
    bot_token: "your_discord_bot_token_here"

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
            filename: /data/bridge.log
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
}

generate_registration_file() {
    local bridge_name="$1"
    local config_dir="$2"
    local registration_file="$config_dir/registration.yaml"
    local port="${BRIDGE_PORTS[$bridge_name]}"
    
    cat > "$registration_file" << EOF
id: $bridge_name
url: http://${bridge_name}-bridge:$port
as_token: "$(generate_token)"
hs_token: "$(generate_token)"
sender_localpart: ${bridge_name}bot
namespaces:
  users:
    - exclusive: true
      regex: "@${bridge_name}_.*:$DOMAIN"
    - exclusive: true
      regex: "@${bridge_name}bot:$DOMAIN"
  aliases:
    - exclusive: true
      regex: "#${bridge_name}_.*:$DOMAIN"
  rooms: []
EOF
    
    # Add registration file to Synapse config
    add_bridge_to_synapse "$registration_file"
    
    log_success "Файл реєстрації для $bridge_name створено"
}

add_bridge_to_synapse() {
    local registration_file="$1"
    local homeserver_config="$BASE_DIR/synapse/config/homeserver.yaml"
    
    # Add registration file to app_service_config_files if not already present
    if ! grep -q "$registration_file" "$homeserver_config"; then
        sed -i "/^app_service_config_files:/a\\  - $registration_file" "$homeserver_config"
    fi
}

generate_bridge_services() {
    if [[ "${CONFIG[INSTALL_BRIDGES]}" != "true" ]]; then
        return 0
    fi
    
    local services=""
    
    [[ "${CONFIG[INSTALL_SIGNAL_BRIDGE]}" == "true" ]] && services+="$(generate_bridge_service "signal")\n"
    [[ "${CONFIG[INSTALL_WHATSAPP_BRIDGE]}" == "true" ]] && services+="$(generate_bridge_service "whatsapp")\n"
    [[ "${CONFIG[INSTALL_TELEGRAM_BRIDGE]}" == "true" ]] && services+="$(generate_bridge_service "telegram")\n"
    [[ "${CONFIG[INSTALL_DISCORD_BRIDGE]}" == "true" ]] && services+="$(generate_bridge_service "discord")\n"
    
    echo -e "${services}"
}

generate_bridge_service() {
    local bridge_name=$1
    local image="${BRIDGE_IMAGES[${bridge_name}]}"
    
    cat << EOF
  ${bridge_name}-bridge:
    image: ${image}
    restart: unless-stopped
    depends_on:
      - synapse
    volumes:
      - ./${bridge_name}-bridge/config:/data:z
      - ./${bridge_name}-bridge/data:/data_bridge:z
    environment:
      - MAUTRIX_CONFIG_PATH=/data/config.yaml
      - MAUTRIX_REGISTRATION_PATH=/data/registration.yaml
    labels:
      - "mautrix_bridge=${bridge_name}"
EOF
}

add_bridge_services() {
    local compose_file="$1"
    
    log_info "Додавання сервісів мостів до Docker Compose..."
    
    IFS=',' read -ra BRIDGES <<< "$BRIDGES_TO_INSTALL"
    
    for bridge_num in "${BRIDGES[@]}"; do
        case $bridge_num in
            1) add_signal_service "$compose_file" ;;
            2) add_whatsapp_service "$compose_file" ;;
            3) add_telegram_service "$compose_file" ;;
            4) add_discord_service "$compose_file" ;;
            5)
                add_signal_service "$compose_file"
                add_whatsapp_service "$compose_file"
                add_telegram_service "$compose_file"
                add_discord_service "$compose_file"
                ;;
        esac
    done
}

add_signal_service() {
    local compose_file="$1"
    
    cat >> "$compose_file" << 'EOF'

  signald:
    image: signald/signald:latest
    container_name: matrix-signald
    restart: unless-stopped
    volumes:
      - ./signal-bridge/signald:/signald
    networks:
      - matrix-net

  signal-bridge:
    image: dock.mau.dev/mautrix/signal:latest
    container_name: matrix-signal-bridge
    restart: unless-stopped
    volumes:
      - ./signal-bridge/config:/config
      - ./signal-bridge/data:/data
      - ./signal-bridge/signald:/signald
    networks:
      - matrix-net
    depends_on:
      - signald
      - synapse
EOF
}

add_whatsapp_service() {
    local compose_file="$1"
    
    cat >> "$compose_file" << 'EOF'

  whatsapp-bridge:
    image: dock.mau.dev/mautrix/whatsapp:latest
    container_name: matrix-whatsapp-bridge
    restart: unless-stopped
    volumes:
      - ./whatsapp-bridge/config:/config
      - ./whatsapp-bridge/data:/data
    networks:
      - matrix-net
    depends_on:
      - synapse
EOF
}

add_telegram_service() {
    local compose_file="$1"
    
    cat >> "$compose_file" << 'EOF'

  telegram-bridge:
    image: dock.mau.dev/mautrix/telegram:latest
    container_name: matrix-telegram-bridge
    restart: unless-stopped
    volumes:
      - ./telegram-bridge/config:/config
      - ./telegram-bridge/data:/data
    networks:
      - matrix-net
    depends_on:
      - synapse
EOF
}

add_discord_service() {
    local compose_file="$1"
    
    cat >> "$compose_file" << 'EOF'

  discord-bridge:
    image: dock.mau.dev/mautrix/discord:latest
    container_name: matrix-discord-bridge
    restart: unless-stopped
    volumes:
      - ./discord-bridge/config:/config
      - ./discord-bridge/data:/data
    networks:
      - matrix-net
    depends_on:
      - synapse
EOF
}

generate_token() {
    openssl rand -hex 32
}

create_bridge_documentation() {
    local bridge_name="$1"
    local bridge_dir="$2"
    
    local doc_file="$bridge_dir/README.md"
    
    case $bridge_name in
        "signal")
            cat > "$doc_file" << EOF
# Signal Bridge

## Опис
Міст для інтеграції Matrix з Signal месенджером.

## Налаштування
1. Встановіть Signal на ваш телефон
2. Запустіть signald: \`docker run -d --name signald -v /path/to/signal:/signald finn/signald\`
3. Зареєструйте пристрій: \`docker exec signald signald-cli -a +YOUR_PHONE_NUMBER register\`
4. Налаштуйте конфігурацію в \`config/config.yaml\`
5. Запустіть міст: \`docker run -d --name mautrix-signal -v /path/to/config:/data dock.mau.dev/mautrix/signal\`

## Команди
- \`!signal help\` - Показати допомогу
- \`!signal login\` - Увійти в Signal
- \`!signal logout\` - Вийти з Signal

## Документація
https://docs.mau.fi/bridges/python/signal/
EOF
            ;;
        "whatsapp")
            cat > "$doc_file" << EOF
# WhatsApp Bridge

## Опис
Міст для інтеграції Matrix з WhatsApp.

## Налаштування
1. Відскануйте QR-код з вашого телефону
2. Налаштуйте конфігурацію в \`config/config.yaml\`
3. Запустіть міст: \`docker run -d --name mautrix-whatsapp -v /path/to/config:/data dock.mau.dev/mautrix/whatsapp\`

## Команди
- \`!wa help\` - Показати допомогу
- \`!wa login\` - Увійти в WhatsApp
- \`!wa logout\` - Вийти з WhatsApp

## Документація
https://docs.mau.fi/bridges/python/whatsapp/
EOF
            ;;
        "discord")
            cat > "$doc_file" << EOF
# Discord Bridge

## Опис
Міст для інтеграції Matrix з Discord.

## Налаштування
1. Створіть Discord бота на https://discord.com/developers/applications
2. Налаштуйте конфігурацію в \`config/config.yaml\`
3. Запустіть міст: \`docker run -d --name mautrix-discord -v /path/to/config:/data dock.mau.dev/mautrix/discord\`

## Команди
- \`!discord help\` - Показати допомогу
- \`!discord login\` - Увійти в Discord
- \`!discord logout\` - Вийти з Discord

## Документація
https://docs.mau.fi/bridges/python/discord/
EOF
            ;;
        *)
            cat > "$doc_file" << EOF
# $bridge_name Bridge

## Опис
Міст для інтеграції Matrix з $bridge_name.

## Налаштування
1. Налаштуйте конфігурацію в \`config/config.yaml\`
2. Запустіть міст відповідно до документації

## Документація
Перевірте офіційну документацію для детальних інструкцій.
EOF
            ;;
    esac
    
    log_info "Документація створена: $doc_file"
}

create_bridge_registration_file() {
    log_info "Створення загального файлу реєстрації мостів..."
    
    local registration_file="${BASE_DIR}/bridges/bridges-registration.yaml"
    
    cat > "${registration_file}" << EOF
# Matrix Bridges Registration File
# Generated on $(date)
# This file contains registration information for all configured bridges

# Add this to your Synapse homeserver.yaml:
# app_service_config_files:
#   - /path/to/bridges/bridges-registration.yaml

# Bridge registrations will be added here during bridge setup
EOF
    
    # Додаємо реєстрації для кожного встановленого моста
    if [[ "${INSTALL_SIGNAL_BRIDGE:-false}" == "true" ]]; then
        cat >> "${registration_file}" << EOF

# Signal Bridge Registration
# File: ${BASE_DIR}/bridges/signal/registration.yaml
# Add this line to app_service_config_files in homeserver.yaml:
#   - ${BASE_DIR}/bridges/signal/registration.yaml
EOF
    fi
    
    if [[ "${INSTALL_WHATSAPP_BRIDGE:-false}" == "true" ]]; then
        cat >> "${registration_file}" << EOF

# WhatsApp Bridge Registration
# File: ${BASE_DIR}/bridges/whatsapp/registration.yaml
# Add this line to app_service_config_files in homeserver.yaml:
#   - ${BASE_DIR}/bridges/whatsapp/registration.yaml
EOF
    fi
    
    if [[ "${INSTALL_DISCORD_BRIDGE:-false}" == "true" ]]; then
        cat >> "${registration_file}" << EOF

# Discord Bridge Registration
# File: ${BASE_DIR}/bridges/discord/registration.yaml
# Add this line to app_service_config_files in homeserver.yaml:
#   - ${BASE_DIR}/bridges/discord/registration.yaml
EOF
    fi
    
    log_success "Файл реєстрації мостів створено: ${registration_file}"
    log_info "Додайте шляхи до реєстраційних файлів у homeserver.yaml після налаштування мостів"
}

# Export functions
export -f generate_bridge_configs setup_bridge add_bridge_services
