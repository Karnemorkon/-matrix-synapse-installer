#!/bin/bash
# ===================================================================================
# Bridges Module - Mautrix bridges configuration
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
    log_info "Генерація конфігурацій мостів..."
    
    IFS=',' read -ra BRIDGES <<< "$BRIDGES_TO_INSTALL"
    
    for bridge_num in "${BRIDGES[@]}"; do
        case $bridge_num in
            1) setup_bridge "signal" ;;
            2) setup_bridge "whatsapp" ;;
            3) setup_bridge "telegram" ;;
            4) setup_bridge "discord" ;;
            5) 
                setup_bridge "signal"
                setup_bridge "whatsapp"
                setup_bridge "telegram"
                setup_bridge "discord"
                ;;
        esac
    done
    
    log_success "Конфігурації мостів створено"
}

setup_bridge() {
    local bridge_name="$1"
    local bridge_dir="$BASE_DIR/${bridge_name}-bridge"
    local config_dir="$bridge_dir/config"
    
    log_info "Налаштування моста: $bridge_name"
    
    # Create directories
    mkdir -p "$config_dir"
    mkdir -p "$bridge_dir/data"
    
    # Generate bridge configuration
    generate_bridge_config "$bridge_name" "$config_dir"
    
    # Generate registration file
    generate_registration_file "$bridge_name" "$config_dir"
    
    log_success "Міст $bridge_name налаштовано"
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
    if [[ "${CONFIG[INSTALL_BRIDGES]}" != "true" ]]; then
        return 0
    fi
    
    local base_dir="${CONFIG[BASE_DIR]}"
    local docs_dir="${base_dir}/docs"
    
    cat > "${docs_dir}/BRIDGES.md" << 'EOF'
# Налаштування мостів Matrix

## Загальна інформація

Мости дозволяють інтегрувати Matrix з іншими месенджерами. Після встановлення потрібно налаштувати кожен міст окремо.

## Кроки налаштування

1. Створіть користувача Matrix
2. Увійдіть в Element Web або інший клієнт
3. Знайдіть бота моста та почніть діалог
4. Слідуйте інструкціям для підключення

## Команди мостів

### Signal Bridge
- `!signal help` - показати допомогу
- `!signal login` - увійти в Signal
- `!signal logout` - вийти з Signal

### WhatsApp Bridge
- `!wa help` - показати допомогу
- `!wa login` - увійти в WhatsApp
- `!wa logout` - вийти з WhatsApp

### Telegram Bridge
- `!tg help` - показати допомогу
- `!tg login` - увійти в Telegram
- `!tg logout` - вийти з Telegram

### Discord Bridge
- `!discord help` - показати допомогу
- `!discord login` - увійти в Discord
- `!discord logout` - вийти з Discord

## Усунення проблем

Якщо міст не працює:

1. Перевірте логи: `./bin/matrix-control.sh logs <bridge-name>-bridge`
2. Перезапустіть міст: `docker compose restart <bridge-name>-bridge`
3. Перевірте конфігурацію в `<bridge-name>-bridge/config/config.yaml`

## Додаткова інформація

Детальну документацію можна знайти на: https://docs.mau.fi/
EOF
    
    log_success "Документацію мостів створено"
}

# Export functions
export -f generate_bridge_configs setup_bridge add_bridge_services
