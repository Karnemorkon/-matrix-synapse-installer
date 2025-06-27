#!/bin/bash
# ===================================================================================
# Validator Module - System requirements and input validation
# ===================================================================================

# --- Functions ---
check_root_privileges() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Цей скрипт потрібно запускати з правами root або через sudo"
        exit 1
    fi
    log_success "Права root підтверджено"
}

validate_system_requirements() {
    log_step "Перевірка системних вимог"
    
    # Check OS
    if ! command -v apt &> /dev/null; then
        log_error "Підтримуються лише системи на базі Debian/Ubuntu"
        exit 1
    fi
    
    # Check RAM
    local total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_ram_gb=$((total_ram_kb / 1024 / 1024))
    local min_ram_gb=2
    
    log_info "Доступна RAM: ${total_ram_gb}GB"
    if [[ $total_ram_gb -lt $min_ram_gb ]]; then
        log_warning "Рекомендується мінімум ${min_ram_gb}GB RAM"
        if ! ask_yes_no "Продовжити встановлення?" "false"; then
            log_error "Встановлення скасовано через недостатню кількість RAM"
            exit 1
        fi
    else
        log_success "RAM: достатньо (${total_ram_gb}GB >= ${min_ram_gb}GB)"
    fi
    
    # Check disk space
    local available_space_kb=$(df / | tail -1 | awk '{print $4}')
    local available_space_gb=$((available_space_kb / 1024 / 1024))
    local min_space_gb=10
    
    log_info "Доступний дисковий простір: ${available_space_gb}GB"
    if [[ $available_space_gb -lt $min_space_gb ]]; then
        log_error "Недостатньо дискового простору. Потрібно мінімум ${min_space_gb}GB"
        exit 1
    else
        log_success "Дисковий простір: достатньо (${available_space_gb}GB >= ${min_space_gb}GB)"
    fi
    
    # Check architecture
    local arch=$(uname -m)
    log_info "Архітектура процесора: $arch"
    if [[ "$arch" != "x86_64" && "$arch" != "aarch64" && "$arch" != "arm64" ]]; then
        log_warning "Непідтримувана архітектура: $arch"
    else
        log_success "Архітектура процесора підтримується"
    fi
    
    log_success "Перевірка системних вимог завершена"
}

validate_domain() {
    local domain="$1"
    if [[ ! "$domain" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 1
    fi
    return 0
}

validate_email() {
    local email="$1"
    if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 1
    fi
    return 0
}

# Export functions
export -f check_root_privileges validate_system_requirements validate_domain validate_email
