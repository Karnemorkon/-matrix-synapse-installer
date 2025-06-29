#!/bin/bash
# ===================================================================================
# Спільний Модуль - Функції, які використовуються в кількох модулях
# ===================================================================================

# --- Константи ---
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# --- Спільні Функції ---

# Генерація безпечних токенів
generate_secure_token() {
    local length="${1:-32}"
    openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
}

# Валідація IP адреси
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

# Валідація порту
validate_port() {
    local port="$1"
    if [[ $port =~ ^[0-9]+$ ]] && [[ $port -ge 1 && $port -le 65535 ]]; then
        return 0
    fi
    return 1
}

# Перевірка чи порт вільний
is_port_available() {
    local port="$1"
    ! netstat -tuln | grep -q ":$port "
}

# Створення директорії з правильними правами
create_secure_directory() {
    local dir="$1"
    local owner="${2:-991:991}"
    local permissions="${3:-750}"
    
    mkdir -p "$dir"
    chown "$owner" "$dir"
    chmod "$permissions" "$dir"
}

# Безпечне копіювання файлів
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

# Перевірка чи Docker контейнер запущений
is_container_running() {
    local container_name="$1"
    docker ps --format "table {{.Names}}" | grep -q "^${container_name}$"
}

# Отримання статусу контейнера
get_container_status() {
    local container_name="$1"
    docker ps --format "table {{.Names}}\t{{.Status}}" | grep "^${container_name}" | awk '{print $2}'
}

# Безпечне виконання команди з логуванням
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

# Перевірка чи файл існує та читабельний
check_file_readable() {
    local file="$1"
    if [[ -f "$file" && -r "$file" ]]; then
        return 0
    fi
    return 1
}

# Створення резервної копії файлу
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

# Валідація конфігураційного файлу YAML
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

# Отримання системної інформації
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

# Перевірка мережевого з'єднання
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

# Експортуємо функції
export -f generate_secure_token validate_ip validate_port is_port_available
export -f create_secure_directory secure_copy is_container_running
export -f get_container_status safe_execute check_file_readable
export -f backup_file validate_yaml_file get_system_info check_network_connectivity 