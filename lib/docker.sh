#!/bin/bash
# ===================================================================================
# Docker Module - Docker installation and management
# ===================================================================================

# --- Functions ---
install_docker_dependencies() {
    log_info "Встановлення Docker та залежностей"
    
    # Update package lists
    log_command "apt update -y"
    
    # Install basic packages
    log_info "Встановлення базових пакетів"
    log_command "apt install -y curl apt-transport-https ca-certificates gnupg lsb-release net-tools"
    
    # Install Docker if not present
    if ! command -v docker &> /dev/null; then
        install_docker_engine
    else
        log_success "Docker вже встановлено"
    fi
    
    # Install Docker Compose if not present
    if ! docker compose version &> /dev/null; then
        install_docker_compose
    else
        log_success "Docker Compose вже встановлено"
    fi
    
    # Start and enable Docker service
    log_command "systemctl start docker"
    log_command "systemctl enable docker"
    
    # Add current user to docker group if not root
    if [[ ${SUDO_USER:-} ]]; then
        log_command "usermod -aG docker ${SUDO_USER}"
        log_info "Користувача ${SUDO_USER} додано до групи docker"
    fi
    
    log_success "Docker встановлено та налаштовано"
}

install_docker_engine() {
    log_info "Встановлення Docker Engine"
    
    # Add Docker's official GPG key
    log_command "install -m 0755 -d /etc/apt/keyrings"
    
    if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
        log_command "curl -fsSL https://download.docker.com/linux/$(lsb_release -si | tr '[:upper:]' '[:lower:]')/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg"
        log_command "chmod a+r /etc/apt/keyrings/docker.gpg"
    fi
    
    # Add Docker repository
    if [[ ! -f /etc/apt/sources.list.d/docker.list ]]; then
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$(lsb_release -si | tr '[:upper:]' '[:lower:]') $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    fi
    
    # Update package lists and install Docker
    log_command "apt update -y"
    log_command "apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
    
    log_success "Docker Engine встановлено"
}

install_docker_compose() {
    log_info "Встановлення Docker Compose"
    
    # Try to install via package manager first
    if log_command "apt install -y docker-compose-plugin"; then
        log_success "Docker Compose встановлено через пакетний менеджер"
        return 0
    fi
    
    # Fallback to manual installation
    log_warn "Встановлення через пакетний менеджер не вдалося, встановлюю вручну"
    
    local compose_version
    compose_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
    
    log_command "curl -L \"https://github.com/docker/compose/releases/download/${compose_version}/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose"
    log_command "chmod +x /usr/local/bin/docker-compose"
    
    # Create symlink for compatibility
    log_command "ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose"
    
    log_success "Docker Compose встановлено вручну"
}

check_docker_status() {
    log_info "Перевірка статусу Docker"
    
    if ! systemctl is-active --quiet docker; then
        log_error "Docker не запущено"
        return 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker недоступний"
        return 1
    fi
    
    log_success "Docker працює коректно"
    return 0
}

pull_docker_images() {
    local compose_file=$1
    
    log_info "Завантаження Docker образів"
    
    if [[ ! -f "${compose_file}" ]]; then
        log_error "Docker Compose файл не знайдено: ${compose_file}"
        return 1
    fi
    
    cd "$(dirname "${compose_file}")" || return 1
    
    if log_command "docker compose pull"; then
        log_success "Docker образи завантажено"
        return 0
    else
        log_error "Помилка завантаження Docker образів"
        return 1
    fi
}

start_docker_services() {
    local compose_file=$1
    
    log_info "Запуск Docker сервісів"
    
    if [[ ! -f "${compose_file}" ]]; then
        log_error "Docker Compose файл не знайдено: ${compose_file}"
        return 1
    fi
    
    cd "$(dirname "${compose_file}")" || return 1
    
    if log_command "docker compose up -d --remove-orphans"; then
        log_success "Docker сервіси запущено"
        return 0
    else
        log_error "Помилка запуску Docker сервісів"
        return 1
    fi
}

stop_docker_services() {
    local compose_file=$1
    
    log_info "Зупинка Docker сервісів"
    
    if [[ ! -f "${compose_file}" ]]; then
        log_error "Docker Compose файл не знайдено: ${compose_file}"
        return 1
    fi
    
    cd "$(dirname "${compose_file")" || return 1
    
    if log_command "docker compose down"; then
        log_success "Docker сервіси зупинено"
        return 0
    else
        log_error "Помилка зупинки Docker сервісів"
        return 1
    fi
}

get_docker_service_status() {
    local compose_file=$1
    
    if [[ ! -f "${compose_file}" ]]; then
        echo "Docker Compose файл не знайдено"
        return 1
    fi
    
    cd "$(dirname "${compose_file}")" || return 1
    docker compose ps
}

cleanup_docker() {
    log_info "Очищення Docker системи"
    
    # Remove unused containers
    log_command "docker container prune -f"
    
    # Remove unused images
    log_command "docker image prune -f"
    
    # Remove unused volumes
    log_command "docker volume prune -f"
    
    # Remove unused networks
    log_command "docker network prune -f"
    
    log_success "Docker систему очищено"
}
