#!/bin/bash
# ===================================================================================
# Validator Module - Input validation and system checks
# ===================================================================================

# --- System Requirements ---
readonly MIN_RAM_GB=2
readonly MIN_DISK_GB=10
readonly REQUIRED_PORTS=(80 443 8008 8448)

# --- Functions ---
check_root_privileges() {
    if [[ ${EUID} -ne 0 ]]; then
        log_error "Цей скрипт потрібно запускати з правами root або через sudo"
        exit 1
    fi
    
    log_success "Права root підтверджено"
}

validate_system_requirements() {
    log_info "Перевірка системних вимог"
    
    local errors=0
    
    # Check RAM
    if ! validate_ram; then
        ((errors++))
    fi
    
    # Check disk space
    if ! validate_disk_space; then
        ((errors++))
    fi
    
    # Check architecture
    if ! validate_architecture; then
        ((errors++))
    fi
    
    # Check OS
    if ! validate_os; then
        ((errors++))
    fi
    
    # Check network
    if ! validate_network; then
        ((errors++))
    fi
    
    if [[ ${errors} -gt 0 ]]; then
        log_error "Знайдено ${errors} проблем з системними вимогами"
        if ! ask_yes_no "Продовжити попри попередження?"; then
            exit 1
        fi
    fi
    
    log_success "Перевірка системних вимог завершена"
}

validate_ram() {
    local total_ram_kb
    total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_ram_gb=$((total_ram_kb / 1024 / 1024))
    
    log_info "Доступна RAM: ${total_ram_gb}GB"
    
    if [[ ${total_ram_gb} -lt ${MIN_RAM_GB} ]]; then
        log_warn "Недостатньо RAM. Рекомендовано: ${MIN_RAM_GB}GB, доступно: ${total_ram_gb}GB"
        return 1
    fi
    
    log_success "RAM: достатньо (${total_ram_gb}GB >= ${MIN_RAM_GB}GB)"
    return 0
}

validate_disk_space() {
    local available_space_kb
    available_space_kb=$(df / | tail -1 | awk '{print $4}')
    local available_space_gb=$((available_space_kb / 1024 / 1024))
    
    log_info "Доступний дисковий простір: ${available_space_gb}GB"
    
    if [[ ${available_space_gb} -lt ${MIN_DISK_GB} ]]; then
        log_error "Недостатньо дискового простору. Потрібно: ${MIN_DISK_GB}GB, доступно: ${available_space_gb}GB"
        return 1
    fi
    
    log_success "Дисковий простір: достатньо (${available_space_gb}GB >= ${MIN_DISK_GB}GB)"
    return 0
}

validate_architecture() {
    local arch
    arch=$(uname -m)
    
    log_info "Архітектура процесора: ${arch}"
    
    case "${arch}" in
        x86_64|aarch64|arm64)
            log_success "Архітектура підтримується: ${arch}"
            return 0
            ;;
        *)
            log_warn "Непідтримувана архітектура: ${arch}"
            return 1
            ;;
    esac
}

validate_os() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "Не вдалося визначити операційну систему"
        return 1
    fi
    
    source /etc/os-release
    
    log_info "Операційна система: ${PRETTY_NAME}"
    
    case "${ID}" in
        ubuntu|debian)
            log_success "Підтримувана ОС: ${PRETTY_NAME}"
            return 0
            ;;
        *)
            log_warn "Непідтримувана ОС: ${PRETTY_NAME}"
            return 1
            ;;
    esac
}

validate_network() {
    log_info "Перевірка мережевого підключення"
    
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        log_error "Немає доступу до інтернету"
        return 1
    fi
    
    if ! ping -c 1 github.com &> /dev/null; then
        log_warn "Немає доступу до GitHub"
        return 1
    fi
    
    log_success "Мережеве підключення: OK"
    return 0
}

validate_config() {
    log_info "Валідація конфігурації"
    
    local errors=0
    
    # Validate domain
    if ! validate_domain "${CONFIG[DOMAIN]}"; then
        log_error "Некоректний домен: ${CONFIG[DOMAIN]}"
        ((errors++))
    fi
    
    # Validate base directory
    if ! validate_directory_path "${CONFIG[BASE_DIR]}"; then
        log_error "Некоректний шлях до базової директорії: ${CONFIG[BASE_DIR]}"
        ((errors++))
    fi
    
    # Validate passwords
    if [[ -z "${CONFIG[POSTGRES_PASSWORD]}" ]]; then
        log_error "Пароль PostgreSQL не може бути порожнім"
        ((errors++))
    fi
    
    # Validate Cloudflare token if needed
    if [[ "${CONFIG[USE_CLOUDFLARE_TUNNEL]}" == "true" ]] && [[ -z "${CONFIG[CLOUDFLARE_TUNNEL_TOKEN]}" ]]; then
        log_error "Токен Cloudflare Tunnel не може бути порожнім"
        ((errors++))
    fi
    
    # Validate email settings
    if [[ "${CONFIG[USE_LETSENCRYPT]}" == "true" ]] && ! validate_email "${CONFIG[LETSENCRYPT_EMAIL]}"; then
        log_error "Некоректний email для Let's Encrypt: ${CONFIG[LETSENCRYPT_EMAIL]}"
        ((errors++))
    fi
    
    if [[ "${CONFIG[SETUP_EMAIL_ALERTS]}" == "true" ]]; then
        if ! validate_email "${CONFIG[ALERT_EMAIL]}"; then
            log_error "Некоректний email для алертів: ${CONFIG[ALERT_EMAIL]}"
            ((errors++))
        fi
        
        if ! validate_email "${CONFIG[SMTP_USER]}"; then
            log_error "Некоректний SMTP користувач: ${CONFIG[SMTP_USER]}"
            ((errors++))
        fi
    fi
    
    if [[ ${errors} -gt 0 ]]; then
        log_error "Знайдено ${errors} помилок у конфігурації"
        exit 1
    fi
    
    log_success "Конфігурація валідна"
}

# --- Validation Functions ---
validate_domain() {
    local domain=$1
    
    # Basic domain format check
    if [[ ! "${domain}" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 1
    fi
    
    # Check for invalid patterns
    if [[ "${domain}" =~ \.\. ]] || [[ "${domain}" =~ ^[-.] ]] || [[ "${domain}" =~ [-.]$ ]]; then
        return 1
    fi
    
    return 0
}

validate_email() {
    local email=$1
    
    if [[ "${email}" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    fi
    
    return 1
}

validate_directory_path() {
    local path=$1
    
    # Check if path is absolute
    if [[ ! "${path}" =~ ^/ ]]; then
        return 1
    fi
    
    # Check if path contains invalid characters
    if [[ "${path}" =~ [[:space:]] ]]; then
        return 1
    fi
    
    return 0
}

validate_not_empty() {
    local value=$1
    
    if [[ -n "${value}" ]]; then
        return 0
    fi
    
    return 1
}

validate_port() {
    local port=$1
    
    if [[ "${port}" =~ ^[0-9]+$ ]] && [[ ${port} -ge 1 ]] && [[ ${port} -le 65535 ]]; then
        return 0
    fi
    
    return 1
}

check_port_availability() {
    local port=$1
    
    if netstat -tuln 2>/dev/null | grep -q ":${port} "; then
        log_warn "Порт ${port} вже використовується"
        return 1
    fi
    
    return 0
}
