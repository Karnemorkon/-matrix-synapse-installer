#!/bin/bash
# ===================================================================================
# Matrix Control Script - System management utility
# ===================================================================================

set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly CONFIG_FILE="${PROJECT_ROOT}/config/matrix.conf"
readonly LOG_FILE="/var/log/matrix-control.log"

# Default values
readonly DEFAULT_BASE_DIR="/DATA/matrix"
readonly DEFAULT_DOMAIN="matrix.example.com"

# Load configuration
source "${PROJECT_ROOT}/lib/config.sh" 2>/dev/null || {
    echo -e "${RED}Error: Cannot load configuration module${NC}"
    exit 1
}

# Load all modules
for module in logger validator docker matrix bridges monitoring backup security; do
    source "${PROJECT_ROOT}/lib/${module}.sh" 2>/dev/null || {
        echo -e "${YELLOW}Warning: Cannot load module ${module}${NC}"
    }
done

# ===================================================================================
# Utility Functions
# ===================================================================================

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" >> "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $1" >> "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARNING] $1" >> "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >> "$LOG_FILE"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [STEP] $1" >> "$LOG_FILE"
}

# ===================================================================================
# Configuration Management
# ===================================================================================

create_default_config() {
    log_step "Створення конфігураційних файлів"
    
    # Create config directory
    mkdir -p "${PROJECT_ROOT}/config"
    
    # Create main configuration file
    cat > "${CONFIG_FILE}" << EOF
# Matrix Synapse Installer Configuration
# Generated on $(date)

# Basic Settings
DOMAIN="${DEFAULT_DOMAIN}"
BASE_DIR="${DEFAULT_BASE_DIR}"
POSTGRES_PASSWORD="$(openssl rand -base64 32)"

# Features
ALLOW_PUBLIC_REGISTRATION="false"
ENABLE_FEDERATION="false"
INSTALL_ELEMENT="true"
INSTALL_BRIDGES="false"
SETUP_MONITORING="true"
SETUP_BACKUP="true"
USE_CLOUDFLARE_TUNNEL="false"

# Bridge Configuration
INSTALL_SIGNAL_BRIDGE="false"
INSTALL_WHATSAPP_BRIDGE="false"
INSTALL_DISCORD_BRIDGE="false"

# Security Settings
SSL_ENABLED="true"
FIREWALL_ENABLED="true"
RATE_LIMITING="true"

# Monitoring Settings
GRAFANA_PASSWORD="$(openssl rand -base64 16)"
PROMETHEUS_ENABLED="true"

# Backup Settings
BACKUP_RETENTION_DAYS="30"
BACKUP_SCHEDULE="0 2 * * *"

# Cloudflare Settings
CLOUDFLARE_TUNNEL_TOKEN=""
EOF

    log_success "Конфігураційний файл створено: ${CONFIG_FILE}"
}

load_or_create_config() {
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        log_warning "Конфігураційний файл не знайдено"
        create_default_config
    fi
    
    # Load configuration
    source "${CONFIG_FILE}"
    
    # Validate required variables
    local required_vars=("DOMAIN" "BASE_DIR" "POSTGRES_PASSWORD")
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Відсутня обов'язкова змінна: ${var}"
            exit 1
        fi
    done
    
    log_success "Конфігурація завантажена"
}

# ===================================================================================
# System Validation
# ===================================================================================

validate_system() {
    log_step "Перевірка системних вимог"
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_error "Скрипт повинен запускатися з правами root"
        exit 1
    fi
    
    # Check OS
    if [[ ! -f /etc/os-release ]]; then
        log_error "Непідтримувана операційна система"
        exit 1
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker не встановлений"
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose не встановлений"
        exit 1
    fi
    
    # Check available disk space
    local available_space=$(df / | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 10485760 ]]; then # 10GB in KB
        log_warning "Мало вільного місця на диску (потрібно мінімум 10GB)"
    fi
    
    # Check memory
    local total_mem=$(free -m | awk 'NR==2{print $2}')
    if [[ $total_mem -lt 2048 ]]; then # 2GB
        log_warning "Мало оперативної пам'яті (рекомендується мінімум 2GB)"
    fi
    
    log_success "Системні вимоги перевірені"
}

# ===================================================================================
# Docker Management
# ===================================================================================

check_docker_compose() {
    if [[ ! -f "${BASE_DIR}/docker-compose.yml" ]]; then
        log_error "Docker Compose файл не знайдено в ${BASE_DIR}"
        log_info "Спочатку запустіть встановлення: sudo ./install.sh"
        exit 1
    fi
    
    cd "${BASE_DIR}"
}

# ===================================================================================
# Service Management
# ===================================================================================

start_services() {
    log_step "Запуск сервісів Matrix"
    check_docker_compose
    
    docker compose up -d
    log_success "Сервіси запущені"
    
    # Wait for services to be ready
    log_info "Очікування готовності сервісів..."
    sleep 30
    
    # Check service health
    check_service_health
}

stop_services() {
    log_step "Зупинка сервісів Matrix"
    check_docker_compose
    
    docker compose down
    log_success "Сервіси зупинені"
}

restart_services() {
    log_step "Перезапуск сервісів Matrix"
    check_docker_compose
    
    docker compose restart
    log_success "Сервіси перезапущені"
}

check_service_health() {
    log_step "Перевірка здоров'я сервісів"
    
    local services=("synapse" "postgres" "redis")
    local healthy=true
    
    for service in "${services[@]}"; do
        if docker compose ps | grep -q "${service}.*Up"; then
            log_success "Сервіс ${service} працює"
        else
            log_error "Сервіс ${service} не працює"
            healthy=false
        fi
    done
    
    if [[ "$healthy" == "true" ]]; then
        log_success "Всі сервіси працюють нормально"
    else
        log_warning "Деякі сервіси мають проблеми"
        return 1
    fi
}

# ===================================================================================
# User Management
# ===================================================================================

create_user() {
    local username="$1"
    local password="$2"
    
    log_step "Створення користувача: ${username}"
    
    # Generate registration shared secret
    local registration_shared_secret=$(openssl rand -base64 32)
    
    # Create user via Synapse admin API
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"${username}\",\"password\":\"${password}\",\"admin\":false}" \
        "http://localhost:8008/_synapse/admin/v2/users/@${username}:${DOMAIN}" \
        2>/dev/null || echo "error")
    
    if [[ "$response" == "error" ]]; then
        log_error "Помилка створення користувача"
        return 1
    else
        log_success "Користувач ${username} створений"
    fi
}

list_users() {
    log_step "Список користувачів"
    
    local response=$(curl -s -X GET \
        "http://localhost:8008/_synapse/admin/v2/users" \
        2>/dev/null || echo "error")
    
    if [[ "$response" == "error" ]]; then
        log_error "Помилка отримання списку користувачів"
        return 1
    else
        echo "$response" | jq -r '.users[] | "\(.name) (\(.displayname // "No display name"))"' 2>/dev/null || echo "$response"
    fi
}

delete_user() {
    local username="$1"
    
    log_step "Видалення користувача: ${username}"
    
    local response=$(curl -s -X DELETE \
        "http://localhost:8008/_synapse/admin/v2/users/@${username}:${DOMAIN}" \
        2>/dev/null || echo "error")
    
    if [[ "$response" == "error" ]]; then
        log_error "Помилка видалення користувача"
        return 1
    else
        log_success "Користувач ${username} видалений"
    fi
}

# ===================================================================================
# Bridge Management
# ===================================================================================

list_bridges() {
    log_step "Список встановлених мостів"
    
    local bridges_dir="${BASE_DIR}/bridges"
    if [[ ! -d "$bridges_dir" ]]; then
        log_info "Мости не встановлені"
        return 0
    fi
    
    local found=false
    for bridge in "$bridges_dir"/*; do
        if [[ -d "$bridge" ]]; then
            local bridge_name=$(basename "$bridge")
            local status="❌ Зупинений"
            
            if docker compose ps | grep -q "${bridge_name}-bridge"; then
                status="✅ Запущений"
            fi
            
            echo "  📱 $bridge_name: $status"
            found=true
        fi
    done
    
    if [[ "$found" == "false" ]]; then
        log_info "Мости не встановлені"
    fi
}

bridge_status() {
    local bridge_name="$1"
    
    log_step "Статус моста: ${bridge_name}"
    
    if docker compose ps | grep -q "${bridge_name}-bridge"; then
        docker compose ps "${bridge_name}-bridge"
        log_info "Логи моста: $0 bridge logs $bridge_name"
    else
        log_warning "Міст ${bridge_name} не запущений"
        log_info "Запустіть міст: docker compose up -d ${bridge_name}-bridge"
    fi
}

bridge_logs() {
    local bridge_name="$1"
    
    log_step "Логи моста: ${bridge_name}"
    docker compose logs -f "${bridge_name}-bridge"
}

bridge_restart() {
    local bridge_name="$1"
    
    log_step "Перезапуск моста: ${bridge_name}"
    docker compose restart "${bridge_name}-bridge"
    log_success "Міст ${bridge_name} перезапущений"
}

bridge_setup() {
    local bridge_name="$1"
    
    log_step "Налаштування моста: ${bridge_name}"
    
    local bridge_dir="${BASE_DIR}/bridges/${bridge_name}"
    local config_file="${bridge_dir}/config/config.yaml"
    
    if [[ ! -d "$bridge_dir" ]]; then
        log_error "Міст ${bridge_name} не встановлений"
        log_info "Спочатку встановіть міст через інсталятор"
        return 1
    fi
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Файл конфігурації не знайдено: $config_file"
        return 1
    fi
    
    log_info "Редагування конфігурації моста ${bridge_name}..."
    log_info "Файл конфігурації: $config_file"
    log_info "Після редагування перезапустіть міст: $0 bridge restart $bridge_name"
    
    # Show current configuration
    echo
    log_info "Поточна конфігурація:"
    cat "$config_file"
    echo
    log_info "Для редагування використовуйте: nano $config_file"
}

# ===================================================================================
# SSL Management
# ===================================================================================

check_ssl() {
    log_step "Перевірка SSL сертифікатів"
    
    if [[ "${SSL_ENABLED}" != "true" ]]; then
        log_info "SSL не увімкнено"
        return 0
    fi
    
    local cert_file="/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
    if [[ -f "$cert_file" ]]; then
        local expiry_date=$(openssl x509 -enddate -noout -in "$cert_file" | cut -d= -f2)
        log_success "SSL сертифікат дійсний до: $expiry_date"
    else
        log_warning "SSL сертифікат не знайдено"
    fi
}

renew_ssl() {
    log_step "Оновлення SSL сертифікатів"
    
    if command -v certbot &> /dev/null; then
        certbot renew --quiet
        log_success "SSL сертифікати оновлені"
        
        # Reload nginx if running
        if systemctl is-active --quiet nginx; then
            systemctl reload nginx
            log_info "Nginx перезавантажено"
        fi
    else
        log_error "Certbot не встановлений"
    fi
}

# ===================================================================================
# Backup Management
# ===================================================================================

create_backup() {
    log_step "Створення резервної копії"
    
    local backup_dir="${BASE_DIR}/backups"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${backup_dir}/matrix-backup-${timestamp}.tar.gz"
    
    mkdir -p "$backup_dir"
    
    # Stop services for consistent backup
    docker compose stop
    
    # Create backup
    tar -czf "$backup_file" \
        --exclude="${BASE_DIR}/backups" \
        --exclude="${BASE_DIR}/logs" \
        -C "$(dirname "$BASE_DIR")" "$(basename "$BASE_DIR")"
    
    # Start services
    docker compose start
    
    log_success "Резервну копію створено: $backup_file"
}

restore_backup() {
    local backup_file="$1"
    
    if [[ ! -f "$backup_file" ]]; then
        log_error "Файл резервної копії не знайдено: $backup_file"
        return 1
    fi
    
    log_step "Відновлення з резервної копії"
    
    # Stop services
    docker compose down
    
    # Backup current installation
    local current_backup="${BASE_DIR}/backups/pre-restore-$(date +%Y%m%d_%H%M%S).tar.gz"
    tar -czf "$current_backup" \
        --exclude="${BASE_DIR}/backups" \
        -C "$(dirname "$BASE_DIR")" "$(basename "$BASE_DIR")"
    
    # Extract backup
    tar -xzf "$backup_file" -C "$(dirname "$BASE_DIR")"
    
    # Start services
    docker compose up -d
    
    log_success "Відновлення завершено"
    log_info "Попередня версія збережена в: $current_backup"
}

# ===================================================================================
# System Maintenance
# ===================================================================================

update_system() {
    log_step "Оновлення системи"
    
    # Update Docker images
    docker compose pull
    
    # Restart services with new images
    docker compose up -d
    
    log_success "Система оновлена"
}

cleanup_system() {
    log_step "Очищення системи"
    
    # Remove unused Docker resources
    docker system prune -f
    
    # Remove old logs
    find "${BASE_DIR}/logs" -name "*.log" -mtime +7 -delete 2>/dev/null || true
    
    # Remove old backups
    find "${BASE_DIR}/backups" -name "*.tar.gz" -mtime +${BACKUP_RETENTION_DAYS} -delete 2>/dev/null || true
    
    log_success "Очищення завершено"
}

# ===================================================================================
# Main Functions
# ===================================================================================

show_status() {
    log_step "Статус системи Matrix"
    
    echo "📊 Загальна інформація:"
    echo "  Домен: ${DOMAIN}"
    echo "  Базова директорія: ${BASE_DIR}"
    echo "  Версія скрипта: 3.1"
    echo
    
    echo "🔧 Сервіси:"
    check_docker_compose
    docker compose ps
    echo
    
    echo "🌉 Мости:"
    list_bridges
    echo
    
    echo "💾 Дисковий простір:"
    df -h "${BASE_DIR}"
    echo
    
    echo "🧠 Пам'ять:"
    free -h
}

show_usage() {
    cat << EOF
Matrix Synapse Control Script v3.1

Використання: $0 <команда> [параметри]

Команди:
  start                    Запустити всі сервіси
  stop                     Зупинити всі сервіси
  restart                  Перезапустити всі сервіси
  status                   Показати статус сервісів
  logs [service]           Показати логи (всіх сервісів або конкретного)
  update                   Оновити Docker образи
  health                   Перевірити здоров'я системи
  backup                   Створити резервну копію
  restore <backup-file>    Відновити з резервної копії
  user create <username>   Створити нового користувача
  user list               Показати список користувачів
  user delete <username>   Видалити користувача
  bridge list              Показати список мостів
  bridge status <name>     Показати статус моста
  bridge logs <name>       Показати логи моста
  bridge restart <name>    Перезапустити міст
  bridge setup <name>      Налаштувати міст
  ssl check                Перевірити SSL сертифікати
  ssl renew                Оновити SSL сертифікати
  cleanup                  Очистити невикористані Docker ресурси
  config create            Створити конфігураційні файли
  config validate          Перевірити конфігурацію

Приклади:
  $0 start
  $0 logs synapse
  $0 user create admin
  $0 backup
  $0 restore matrix-backup-20240101_120000.tar.gz
  $0 bridge list
  $0 bridge status signal
  $0 bridge setup whatsapp
  $0 config create
EOF
}

# ===================================================================================
# Main Script Logic
# ===================================================================================

main() {
    # Initialize logging
    mkdir -p "$(dirname "$LOG_FILE")"
    
    log_step "Matrix Control Script v3.1"
    
    # Load or create configuration
    load_or_create_config
    
    # Validate system if not config command
    if [[ "${1:-}" != "config" ]]; then
        validate_system
    fi
    
    case "${1:-}" in
        start)
            start_services
            ;;
        stop)
            stop_services
            ;;
        restart)
            restart_services
            ;;
        status)
            show_status
            ;;
        logs)
            check_docker_compose
            if [[ -n "${2:-}" ]]; then
                docker compose logs -f "$2"
            else
                docker compose logs -f
            fi
            ;;
        update)
            update_system
            ;;
        health)
            check_service_health
            ;;
        backup)
            create_backup
            ;;
        restore)
            if [[ -z "${2:-}" ]]; then
                log_error "Вкажіть файл резервної копії"
                echo "Використання: $0 restore <backup-file>"
                exit 1
            fi
            restore_backup "$2"
            ;;
        user)
            case "${2:-}" in
                create)
                    if [[ -z "${3:-}" ]]; then
                        log_error "Вкажіть ім'я користувача"
                        echo "Використання: $0 user create <username>"
                        exit 1
                    fi
                    local password=$(openssl rand -base64 16)
                    create_user "$3" "$password"
                    log_info "Пароль: $password"
                    ;;
                list)
                    list_users
                    ;;
                delete)
                    if [[ -z "${3:-}" ]]; then
                        log_error "Вкажіть ім'я користувача"
                        echo "Використання: $0 user delete <username>"
                        exit 1
                    fi
                    delete_user "$3"
                    ;;
                *)
                    log_error "Невідома команда користувача: ${2:-}"
                    echo "Доступні команди: create, list, delete"
                    exit 1
                    ;;
            esac
            ;;
        bridge)
            case "${2:-}" in
                list)
                    list_bridges
                    ;;
                status)
                    if [[ -z "${3:-}" ]]; then
                        log_error "Вкажіть ім'я моста"
                        echo "Використання: $0 bridge status <name>"
                        echo "Доступні мости: signal, whatsapp, discord"
                        exit 1
                    fi
                    bridge_status "$3"
                    ;;
                logs)
                    if [[ -z "${3:-}" ]]; then
                        log_error "Вкажіть ім'я моста"
                        echo "Використання: $0 bridge logs <name>"
                        echo "Доступні мости: signal, whatsapp, discord"
                        exit 1
                    fi
                    bridge_logs "$3"
                    ;;
                restart)
                    if [[ -z "${3:-}" ]]; then
                        log_error "Вкажіть ім'я моста"
                        echo "Використання: $0 bridge restart <name>"
                        echo "Доступні мости: signal, whatsapp, discord"
                        exit 1
                    fi
                    bridge_restart "$3"
                    ;;
                setup)
                    if [[ -z "${3:-}" ]]; then
                        log_error "Вкажіть ім'я моста"
                        echo "Використання: $0 bridge setup <name>"
                        echo "Доступні мости: signal, whatsapp, discord"
                        exit 1
                    fi
                    bridge_setup "$3"
                    ;;
                *)
                    log_error "Невідома команда моста: ${2:-}"
                    echo "Доступні команди: list, status, logs, restart, setup"
                    exit 1
                    ;;
            esac
            ;;
        ssl)
            case "${2:-}" in
                check)
                    check_ssl
                    ;;
                renew)
                    renew_ssl
                    ;;
                *)
                    log_error "Невідома команда SSL: ${2:-}"
                    echo "Доступні команди: check, renew"
                    exit 1
                    ;;
            esac
            ;;
        cleanup)
            cleanup_system
            ;;
        config)
            case "${2:-}" in
                create)
                    create_default_config
                    ;;
                validate)
                    load_or_create_config
                    log_success "Конфігурація валідна"
                    ;;
                *)
                    log_error "Невідома команда конфігурації: ${2:-}"
                    echo "Доступні команди: create, validate"
                    exit 1
                    ;;
            esac
            ;;
        *)
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
