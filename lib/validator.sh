#!/bin/bash
# ===================================================================================
# Модуль Валідації - Системні вимоги та валідація введення
# ===================================================================================

# --- Функції ---
# --- Перевірка root-привілеїв ---
# Завершує роботу, якщо скрипт не під root
check_root_privileges() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Цей скрипт потрібно запускати з правами root або через sudo"
        exit 1
    fi
    log_success "Права root підтверджено"
}

validate_system_requirements() {
    log_step "Перевірка системних вимог"
    
    # Перевіряємо ОС
    if ! command -v apt &> /dev/null; then
        log_error "Підтримуються лише системи на базі Debian/Ubuntu"
        exit 1
    fi
    
    # Перевіряємо версію ядра
    local kernel_version=$(uname -r | cut -d. -f1,2)
    local min_kernel="4.19"
    if [[ "$(printf '%s\n' "$min_kernel" "$kernel_version" | sort -V | head -n1)" != "$min_kernel" ]]; then
        log_warning "Рекомендується ядро версії ${min_kernel}+ (поточна: ${kernel_version})"
    else
        log_success "Версія ядра підтримується (${kernel_version})"
    fi
    
    # Перевіряємо RAM
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
    
    # Перевіряємо дискове місце
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
    
    # Перевіряємо архітектуру
    local arch=$(uname -m)
    log_info "Архітектура процесора: $arch"
    if [[ "$arch" != "x86_64" && "$arch" != "aarch64" && "$arch" != "arm64" ]]; then
        log_warning "Непідтримувана архітектура: $arch"
    else
        log_success "Архітектура процесора підтримується"
    fi
    
    # Перевіряємо наявність Docker
    if command -v docker &> /dev/null; then
        log_success "Docker вже встановлено"
    else
        log_info "Docker буде встановлено під час інсталяції"
    fi
    
    # Перевіряємо мережеве з'єднання
    if ping -c 1 8.8.8.8 &> /dev/null; then
        log_success "Мережеве з'єднання працює"
    else
        log_warning "Проблеми з мережевим з'єднанням"
    fi
    
    log_success "Перевірка системних вимог завершена"
}

# --- Валідація домену ---
# Перевіряє, чи домен відповідає шаблону
validate_domain() {
    local domain="$1"
    if [[ ! "$domain" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 1
    fi
    return 0
}

# --- Валідація email ---
# Перевіряє, чи email відповідає шаблону
validate_email() {
    local email="$1"
    if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 1
    fi
    return 0
}

# --- Перевірка swap ---
# Перевіряє наявність і розмір swap
check_swap() {
    local min_swap_mb=1024
    local swap_total_mb=$(free -m | awk '/Swap:/ {print $2}')
    if [[ -z "$swap_total_mb" || $swap_total_mb -eq 0 ]]; then
        log_warning "Swap не налаштовано. Рекомендується мінімум ${min_swap_mb}MB swap для стабільної роботи."
    elif [[ $swap_total_mb -lt $min_swap_mb ]]; then
        log_warning "Swap занадто малий (${swap_total_mb}MB). Рекомендується мінімум ${min_swap_mb}MB."
    else
        log_success "Swap налаштовано (${swap_total_mb}MB)"
    fi
}

# --- Перевірка версії Docker ---
# Перевіряє, чи встановлено docker і його версію
check_docker_version() {
    local min_version="20.10"
    if ! command -v docker &> /dev/null; then
        log_error "Docker не встановлено!"
        exit 1
    fi
    local version=$(docker --version | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
    if [[ -z "$version" ]]; then
        log_warning "Не вдалося визначити версію Docker."
        return 1
    fi
    if [[ $(printf '%s\n' "$min_version" "$version" | sort -V | head -n1) != "$min_version" ]]; then
        log_warning "Рекомендується Docker >= ${min_version} (зараз: $version)"
    else
        log_success "Docker версія підтримується ($version)"
    fi
}

# --- Перевірка версії Docker Compose ---
# Перевіряє, чи встановлено docker-compose і його версію
check_docker_compose_version() {
    local min_version="1.29"
    local version=""
    if command -v docker-compose &> /dev/null; then
        version=$(docker-compose --version | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
    elif docker compose version &> /dev/null; then
        version=$(docker compose version --short)
    else
        log_error "Docker Compose не встановлено!"
        exit 1
    fi
    if [[ -z "$version" ]]; then
        log_warning "Не вдалося визначити версію Docker Compose."
        return 1
    fi
    if [[ $(printf '%s\n' "$min_version" "$version" | sort -V | head -n1) != "$min_version" ]]; then
        log_warning "Рекомендується Docker Compose >= ${min_version} (зараз: $version)"
    else
        log_success "Docker Compose версія підтримується ($version)"
    fi
}

# Експортуємо функції
export -f check_root_privileges validate_system_requirements validate_domain validate_email check_swap check_docker_version check_docker_compose_version
