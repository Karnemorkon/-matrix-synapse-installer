#!/bin/bash
# ===================================================================================
# Validator Module - System and input validation
# ===================================================================================

# --- System Requirements ---
readonly MIN_RAM_MB=1024
readonly MIN_DISK_GB=5
readonly REQUIRED_COMMANDS=("docker" "docker-compose" "curl" "wget" "openssl")

# --- Functions ---
check_root_privileges() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Цей скрипт повинен запускатися з правами root"
        log_info "Використайте: sudo $0"
        exit 1
    fi
    log_success "Права root підтверджено"
}

validate_system_requirements() {
    log_info "Перевірка системних вимог..."
    
    # Check OS
    if ! check_supported_os; then
        log_error "Непідтримувана операційна система"
        exit 1
    fi
    
    # Check RAM
    if ! check_ram_requirements; then
        log_warn "Недостатньо оперативної пам'яті (рекомендовано мінімум ${MIN_RAM_MB}MB)"
    fi
    
    # Check disk space
    if ! check_disk_space; then
        log_error "Недостатньо дискового простору"
        exit 1
    fi
    
    # Check network connectivity
    if ! check_network_connectivity; then
        log_error "Відсутнє підключення до інтернету"
        exit 1
    fi
    
    log_success "Системні вимоги виконано"
}

check_supported_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        case $ID in
            ubuntu)
                if version_compare "$VERSION_ID" "20.04"; then
                    log_success "Підтримувана ОС: Ubuntu $VERSION_ID"
                    return 0
                fi
                ;;
            debian)
                if version_compare "$VERSION_ID" "11"; then
                    log_success "Підтримувана ОС: Debian $VERSION_ID"
                    return 0
                fi
                ;;
        esac
    fi
    
    log_error "Непідтримувана ОС. Підтримуються: Ubuntu 20.04+, Debian 11+"
    return 1
}

check_ram_requirements() {
    local ram_mb=$(free -m | awk 'NR==2{print $2}')
    
    if [[ $ram_mb -ge $MIN_RAM_MB ]]; then
        log_success "Оперативна пам'ять: ${ram_mb}MB (достатньо)"
        return 0
    else
        log_warn "Оперативна пам'ять: ${ram_mb}MB (мінімум: ${MIN_RAM_MB}MB)"
        return 1
    fi
}

check_disk_space() {
    local available_gb=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
    
    if [[ $available_gb -ge $MIN_DISK_GB ]]; then
        log_success "Дисковий простір: ${available_gb}GB (достатньо)"
        return 0
    else
        log_error "Дисковий простір: ${available_gb}GB (мінімум: ${MIN_DISK_GB}GB)"
        return 1
    fi
}

check_network_connectivity() {
    local test_urls=("google.com" "github.com" "docker.io")
    
    for url in "${test_urls[@]}"; do
        if ping -c 1 -W 5 "$url" &>/dev/null; then
            log_success "Мережеве підключення: OK"
            return 0
        fi
    done
    
    log_error "Відсутнє підключення до інтернету"
    return 1
}

validate_domain() {
    local domain="$1"
    
    # Basic domain format validation
    if [[ $domain =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        # Check if domain resolves
        if nslookup "$domain" &>/dev/null; then
            log_success "Домен $domain валідний та резолвиться"
            return 0
        else
            log_warn "Домен $domain не резолвиться (це нормально для нових доменів)"
            return 0
        fi
    else
        log_error "Невірний формат домену: $domain"
        return 1
    fi
}

validate_email() {
    local email="$1"
    
    if [[ $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        log_success "Email $email валідний"
        return 0
    else
        log_error "Невірний формат email: $email"
        return 1
    fi
}

validate_port() {
    local port="$1"
    
    if [[ $port =~ ^[0-9]+$ ]] && [[ $port -ge 1 ]] && [[ $port -le 65535 ]]; then
        return 0
    else
        return 1
    fi
}

check_port_available() {
    local port="$1"
    
    if netstat -tuln | grep -q ":$port "; then
        log_warn "Порт $port вже використовується"
        return 1
    else
        log_success "Порт $port доступний"
        return 0
    fi
}

version_compare() {
    local version1="$1"
    local version2="$2"
    
    if [[ "$(printf '%s\n' "$version2" "$version1" | sort -V | head -n1)" == "$version2" ]]; then
        return 0
    else
        return 1
    fi
}

validate_directory_writable() {
    local dir="$1"
    
    if [[ -d "$dir" ]]; then
        if [[ -w "$dir" ]]; then
            log_success "Директорія $dir доступна для запису"
            return 0
        else
            log_error "Директорія $dir недоступна для запису"
            return 1
        fi
    else
        # Try to create directory
        if mkdir -p "$dir" 2>/dev/null; then
            log_success "Директорія $dir створена"
            return 0
        else
            log_error "Неможливо створити директорію $dir"
            return 1
        fi
    fi
}

check_command_exists() {
    local cmd="$1"
    
    if command -v "$cmd" &>/dev/null; then
        log_success "Команда $cmd знайдена"
        return 0
    else
        log_error "Команда $cmd не знайдена"
        return 1
    fi
}

validate_required_commands() {
    local missing_commands=()
    
    for cmd in "${REQUIRED_COMMANDS[@]}"; do
        if ! check_command_exists "$cmd"; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_error "Відсутні необхідні команди: ${missing_commands[*]}"
        log_info "Встановіть їх перед продовженням"
        return 1
    fi
    
    log_success "Всі необхідні команди доступні"
    return 0
}

validate_cloudflare_token() {
    local token="$1"
    
    if [[ -z "$token" ]]; then
        log_error "Cloudflare токен порожній"
        return 1
    fi
    
    # Basic token format validation (Cloudflare tokens are typically 40 characters)
    if [[ ${#token} -ge 32 ]]; then
        log_success "Cloudflare токен має правильний формат"
        return 0
    else
        log_error "Cloudflare токен має невірний формат"
        return 1
    fi
}

# Export functions
export -f check_root_privileges validate_system_requirements
export -f validate_domain validate_email validate_port
export -f check_port_available validate_directory_writable
export -f check_command_exists validate_required_commands
export -f validate_cloudflare_token
