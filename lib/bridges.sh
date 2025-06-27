#!/bin/bash
# ===================================================================================
# Bridges Module - Mautrix bridges functionality
# ===================================================================================

# --- Constants ---
readonly MAUTRIX_REGISTRY="dock.mau.dev/mautrix"

declare -A BRIDGE_IMAGES=(
    [signal]="${MAUTRIX_REGISTRY}/signal:latest"
    [whatsapp]="${MAUTRIX_REGISTRY}/whatsapp:latest"
    [telegram]="${MAUTRIX_REGISTRY}/telegram:latest"
    [discord]="${MAUTRIX_REGISTRY}/discord:latest"
)

declare -A BRIDGE_APP_IDS=(
    [signal]="io.mau.bridge.signal"
    [whatsapp]="io.mau.bridge.whatsapp"
    [telegram]="io.mau.bridge.telegram"
    [discord]="io.mau.bridge.discord"
)

# --- Functions ---
generate_bridge_configs() {
    if [[ "${CONFIG[INSTALL_BRIDGES]}" != "true" ]]; then
        return 0
    fi
    
    log_info "Генерація конфігурацій мостів"
    
    [[ "${CONFIG[INSTALL_SIGNAL_BRIDGE]}" == "true" ]] && generate_bridge_config "signal"
    [[ "${CONFIG[INSTALL_WHATSAPP_BRIDGE]}" == "true" ]] && generate_bridge_config "whatsapp"
    [[ "${CONFIG[INSTALL_TELEGRAM_BRIDGE]}" == "true" ]] && generate_bridge_config "telegram"
    [[ "${CONFIG[INSTALL_DISCORD_BRIDGE]}" == "true" ]] && generate_bridge_config "discord"
    
    log_success "Конфігурації мостів згенеровано"
}

generate_bridge_config() {
    local bridge_name=$1
    local base_dir="${CONFIG[BASE_DIR]}"
    local bridge_dir="${base_dir}/${bridge_name}-bridge"
    local config_file="${bridge_dir}/config/config.yaml"
    local image="${BRIDGE_IMAGES[${bridge_name}]}"
    
    log_info "Генерація конфігурації для ${bridge_name} bridge"
    
    # Create config directory
    mkdir -p "${bridge_dir}/config"
    mkdir -p "${bridge_dir}/data"
    
    # Generate config
    if docker run --rm \
        -v "${bridge_dir}/config:/data" \
        -e MAUTRIX_CONFIG_PATH=/data/config.yaml \
        -e MAUTRIX_REGISTRATION_PATH=/data/registration.yaml \
        "${image}" -g > "${config_file}" 2>> "${LOG_FILE}"; then
        
        chmod 600 "${config_file}"
        log_success "Конфігурацію ${bridge_name} bridge згенеровано"
    else
        log_error "Помилка генерації конфігурації ${bridge_name} bridge"
        return 1
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

generate_bridge_registrations() {
    if [[ "${CONFIG[INSTALL_BRIDGES]}" != "true" ]]; then
        return 0
    fi
    
    log_info "Генерація реєстраційних файлів мостів"
    
    local base_dir="${CONFIG[BASE_DIR]}"
    cd "${base_dir}" || return 1
    
    [[ "${CONFIG[INSTALL_SIGNAL_BRIDGE]}" == "true" ]] && generate_bridge_registration "signal"
    [[ "${CONFIG[INSTALL_WHATSAPP_BRIDGE]}" == "true" ]] && generate_bridge_registration "whatsapp"
    [[ "${CONFIG[INSTALL_TELEGRAM_BRIDGE]}" == "true" ]] && generate_bridge_registration "telegram"
    [[ "${CONFIG[INSTALL_DISCORD_BRIDGE]}" == "true" ]] && generate_bridge_registration "discord"
    
    log_success "Реєстраційні файли мостів згенеровано"
}

generate_bridge_registration() {
    local bridge_name=$1
    local app_id="${BRIDGE_APP_IDS[${bridge_name}]}"
    local service_name="${bridge_name}-bridge"
    local registration_path="/data/${bridge_name}-registration.yaml"
    local bridge_url="http://${service_name}:8000"
    
    log_info "Генерація реєстрації для ${bridge_name} bridge"
    
    if docker compose exec synapse generate_registration \
        --force \
        -u "${bridge_url}" \
        -c "${registration_path}" \
        "${app_id}" >> "${LOG_FILE}" 2>&1; then
        
        log_success "Реєстрацію ${bridge_name} bridge згенеровано"
    else
        log_error "Помилка генерації реєстрації ${bridge_name} bridge"
        return 1
    fi
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
