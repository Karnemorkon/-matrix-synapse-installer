#!/bin/bash
# ===================================================================================
# Спільний Модуль - Функції, які використовуються в кількох модулях
# ===================================================================================

# --- Константи ---
if [[ -z "${SCRIPT_DIR:-}" ]]; then
  readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# --- Спільні Функції ---

# --- Генерація безпечних токенів ---
# Повертає випадковий токен заданої довжини
generate_secure_token() {
    local length="${1:-32}"
    openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
}

# --- Валідація IP адреси ---
# Перевіряє, чи рядок є коректною IPv4-адресою
validate_ip() {
    local ip="$1"
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if [[ $octet -lt 0 || $octet -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# --- Валідація порту ---
# Перевіряє, чи порт у допустимому діапазоні
validate_port() {
    local port="$1"
    if [[ $port =~ ^[0-9]+$ ]] && [[ $port -ge 1 && $port -le 65535 ]]; then
        return 0
    fi
    return 1
}

# --- Перевірка чи порт вільний ---
# Повертає 0, якщо порт не зайнятий
is_port_available() {
    local port="$1"
    ! netstat -tuln | grep -q ":$port "
}

# --- Створення директорії з правильними правами ---
# Створює директорію з вказаними правами та власником
create_secure_directory() {
    local dir="$1"
    local owner="${2:-991:991}"
    local permissions="${3:-750}"
    
    mkdir -p "$dir"
    chown "$owner" "$dir"
    chmod "$permissions" "$dir"
}

# --- Безпечне копіювання файлів ---
# Копіює файл з встановленням прав та власника
secure_copy() {
    local source="$1"
    local destination="$2"
    local owner="${3:-991:991}"
    local permissions="${4:-640}"
    
    if [[ -f "$source" ]]; then
        cp "$source" "$destination"
        chown "$owner" "$destination"
        chmod "$permissions" "$destination"
        return 0
    fi
    return 1
}

# --- Перевірка чи Docker контейнер запущений ---
# Повертає 0, якщо контейнер запущений
is_container_running() {
    local container_name="$1"
    docker ps --format "table {{.Names}}" | grep -q "^${container_name}$"
}

# --- Отримання статусу контейнера ---
# Повертає статус контейнера за іменем
get_container_status() {
    local container_name="$1"
    docker ps --format "table {{.Names}}\t{{.Status}}" | grep "^${container_name}" | awk '{print $2}'
}

# --- Безпечне виконання команди з логуванням ---
# Виконує команду, логуючи результат
safe_execute() {
    local command="$1"
    local description="${2:-Виконання команди}"
    
    log_info "$description: $command"
    if eval "$command" >> "${LOG_FILE}" 2>&1; then
        log_success "$description завершено успішно"
        return 0
    else
        log_error "$description завершилося помилкою"
        return 1
    fi
}

# --- Перевірка чи файл існує та читабельний ---
# Повертає 0, якщо файл існує і читабельний
check_file_readable() {
    local file="$1"
    if [[ -f "$file" && -r "$file" ]]; then
        return 0
    fi
    return 1
}

# --- Створення резервної копії файлу ---
# Копіює файл у директорію бекапів з міткою часу
backup_file() {
    local file="$1"
    local backup_dir="${2:-$(dirname "$file")/backups}"
    
    if [[ -f "$file" ]]; then
        mkdir -p "$backup_dir"
        local backup_name="$(basename "$file").backup.$(date +%Y%m%d_%H%M%S)"
        cp "$file" "$backup_dir/$backup_name"
        log_info "Створено резервну копію: $backup_dir/$backup_name"
        return 0
    fi
    return 1
}

# --- Валідація конфігураційного файлу YAML ---
# Перевіряє синтаксис YAML через python або grep
validate_yaml_file() {
    local file="$1"
    if command -v python3 &> /dev/null; then
        python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null
        return $?
    elif command -v python &> /dev/null; then
        python -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null
        return $?
    else
        # Проста перевірка синтаксису
        grep -q ":" "$file" 2>/dev/null
        return $?
    fi
}

# --- Отримання системної інформації ---
# Виводить коротку інформацію про систему
get_system_info() {
    echo "=== Інформація про систему ==="
    echo "ОС: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo "Ядро: $(uname -r)"
    echo "Архітектура: $(uname -m)"
    echo "RAM: $(free -h | awk 'NR==2{print $2}')"
    echo "Дисковий простір: $(df -h / | awk 'NR==2{print $4}') вільно"
    echo "Docker версія: $(docker --version 2>/dev/null || echo 'Не встановлено')"
    echo "Docker Compose версія: $(docker compose version 2>/dev/null | head -1 || echo 'Не встановлено')"
}

# --- Перевірка мережевого з'єднання ---
# Пінгує кілька хостів, повертає 0 якщо хоч один доступний
check_network_connectivity() {
    local hosts=("8.8.8.8" "1.1.1.1" "matrix.org")
    local success_count=0
    
    for host in "${hosts[@]}"; do
        if ping -c 1 "$host" &> /dev/null; then
            ((success_count++))
        fi
    done
    
    if [[ $success_count -gt 0 ]]; then
        return 0
    fi
    return 1
}

# --- Rollback інсталяції (ще ширше) ---
rollback_install() {
    log_warning "Виконується широкий rollback інсталяції..."
    # Відновлення .env
    if [[ -f "${BASE_DIR}/.env.bak" ]]; then
        mv -f "${BASE_DIR}/.env.bak" "${BASE_DIR}/.env"
        log_info "Відновлено .env з бекапу"
    fi
    # Відновлення docker-compose.yml
    if [[ -f "${BASE_DIR}/docker-compose.yml.bak" ]]; then
        mv -f "${BASE_DIR}/docker-compose.yml.bak" "${BASE_DIR}/docker-compose.yml"
        log_info "Відновлено docker-compose.yml з бекапу"
    fi
    # Відновлення Synapse config
    if [[ -f "${BASE_DIR}/synapse/config/homeserver.yaml.bak" ]]; then
        mv -f "${BASE_DIR}/synapse/config/homeserver.yaml.bak" "${BASE_DIR}/synapse/config/homeserver.yaml"
        log_info "Відновлено Synapse config з бекапу"
    fi
    # Відновлення nginx config
    if [[ -f "${BASE_DIR}/nginx/conf.d/matrix.conf.bak" ]]; then
        mv -f "${BASE_DIR}/nginx/conf.d/matrix.conf.bak" "${BASE_DIR}/nginx/conf.d/matrix.conf"
        log_info "Відновлено nginx config з бекапу"
    fi
    # Відновлення bridges config
    for bridge in signal whatsapp discord; do
        local bridge_conf="${BASE_DIR}/synapse/config/${bridge}-bridge.yaml"
        if [[ -f "$bridge_conf.bak" ]]; then
            mv -f "$bridge_conf.bak" "$bridge_conf"
            log_info "Відновлено $bridge конфіг з бекапу"
        fi
    done
    # Відновлення інших важливих конфігів (додавай за потреби)
    # ...
    # Видалення тимчасових директорій
    for d in "${BASE_DIR}/backups/install_tmp" "${BASE_DIR}/tmp"; do
        if [[ -d "$d" ]]; then
            rm -rf "$d"
            log_info "Видалено тимчасову директорію $d"
        fi
    done
    # Зупинка і видалення docker-контейнерів зі списку
    if [[ -f "${BASE_DIR}/install_containers.list" ]]; then
        while read -r cname; do
            if [[ -n "$cname" ]]; then
                if docker ps -a --format '{{.Names}}' | grep -q "^$cname$"; then
                    docker stop "$cname" || true
                    docker rm "$cname" || true
                    log_info "Зупинено і видалено контейнер $cname"
                fi
            fi
        done < "${BASE_DIR}/install_containers.list"
        rm -f "${BASE_DIR}/install_containers.list"
    fi
    # Зупинка docker-compose
    if command -v docker-compose &> /dev/null; then
        docker-compose down
    elif docker compose version &> /dev/null; then
        docker compose down
    fi
    log_success "Широкий rollback завершено"
}

# --- Перевірка оновлення системних пакетів ---
check_system_updates() {
    log_step "Перевірка оновлення системних пакетів"
    if ! command -v apt &> /dev/null; then
        log_warning "apt не знайдено, пропускаю перевірку оновлень"
        return 0
    fi
    local updates=$(apt list --upgradable 2>/dev/null | grep -v "Listing..." | wc -l)
    if [[ $updates -gt 0 ]]; then
        log_warning "Є $updates оновлень системних пакетів. Рекомендується виконати: apt update && apt upgrade"
    else
        log_success "Системні пакети актуальні"
    fi
}

# --- Cleanup після невдалої інсталяції ---
cleanup_install() {
    log_warning "Виконується cleanup після невдалої інсталяції..."
    # Видалити тимчасові файли, логи, залишки
    find "${BASE_DIR}" -name '*.tmp' -delete
    find "${BASE_DIR}" -name '*.log' -size +100M -delete
    log_success "Cleanup завершено"
}

# Експортуємо функції
export -f generate_secure_token validate_ip validate_port is_port_available
export -f create_secure_directory secure_copy is_container_running
export -f get_container_status safe_execute check_file_readable
export -f backup_file validate_yaml_file get_system_info check_network_connectivity
export -f rollback_install check_system_updates cleanup_install 