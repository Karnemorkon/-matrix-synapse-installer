#!/bin/bash
# ===================================================================================
# Matrix Synapse Control Script
# Версія: 4.0 - З підтримкою Docker Compose та офіційних образів
# ===================================================================================

# --- Конфігурація ---
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BASE_DIR="$(dirname "${SCRIPT_DIR}")"
readonly CONFIG_FILE="${BASE_DIR}/config.conf"
readonly LOG_FILE="${BASE_DIR}/matrix-control.log"

# --- Імпорт модулів ---
source "${BASE_DIR}/lib/common.sh"
source "${BASE_DIR}/lib/logger.sh"
source "${BASE_DIR}/lib/error-handler.sh"
source "${BASE_DIR}/lib/env-config.sh"

# --- Змінні середовища ---
# Завантажуємо конфігурацію
load_env_config

# --- Функції ---
show_help() {
    cat << 'EOF'
🚀 Matrix Synapse Control Script v4.0

Використання:
  ./matrix-control.sh [команда] [опції]

Команди:
  start                    Запустити всі сервіси
  stop                     Зупинити всі сервіси
  restart                  Перезапустити всі сервіси
  status                   Показати статус сервісів
  logs [сервіс]           Показати логи сервісу
  update                   Оновити образи контейнерів
  backup                   Створити резервну копію
  restore [файл]          Відновити з резервної копії
  config                   Показати конфігурацію
  shell [сервіс]          Відкрити shell в контейнері
  portainer               Запустити Portainer
  monitoring              Запустити моніторинг
  bridges                  Запустити мости
  element                  Запустити Element Web
  cloudflare              Запустити Cloudflare Tunnel

Сервіси:
  postgres                 PostgreSQL база даних
  redis                    Redis кеш
  synapse                  Matrix Synapse
  nginx                    Nginx веб-сервер
  element                  Element Web клієнт
  cloudflared              Cloudflare Tunnel
  prometheus               Prometheus метрики
  grafana                  Grafana дашборди
  node-exporter            Node Exporter
  loki                     Loki логи
  promtail                 Promtail збір логів
  signal-bridge            Signal Bridge
  whatsapp-bridge          WhatsApp Bridge
  discord-bridge           Discord Bridge
  portainer                Portainer управління

Приклади:
  ./matrix-control.sh start
  ./matrix-control.sh logs synapse
  ./matrix-control.sh shell postgres
  ./matrix-control.sh backup
  ./matrix-control.sh monitoring
  ./matrix-control.sh bridges

Змінні середовища:
  MATRIX_DOMAIN                    Домен для Matrix сервера
  MATRIX_BASE_DIR                  Базова директорія
  MATRIX_POSTGRES_PASSWORD         Пароль PostgreSQL
  MATRIX_USE_CLOUDFLARE_TUNNEL     Використовувати Cloudflare Tunnel
  MATRIX_CLOUDFLARE_TUNNEL_TOKEN   Токен Cloudflare Tunnel
  MATRIX_SETUP_MONITORING          Увімкнути моніторинг
  MATRIX_INSTALL_BRIDGES           Увімкнути мости
EOF
}

# Запуск сервісів
start_services() {
    log_step "Запуск Matrix сервісів"
    
    cd "${BASE_DIR}"
    
    # Перевіряємо чи існує docker-compose.yml
    if [[ ! -f "docker-compose.yml" ]]; then
        log_error "Файл docker-compose.yml не знайдено"
        log_info "Спочатку запустіть встановлення: ./install.sh"
        return 1
    fi
    
    # Запускаємо основні сервіси
    log_info "Запуск основних сервісів..."
    if ! docker compose up -d postgres redis synapse nginx; then
        log_error "Помилка запуску основних сервісів"
        return 1
    fi
    
    # Запускаємо додаткові сервіси залежно від конфігурації
    if [[ "${USE_CLOUDFLARE_TUNNEL}" == "true" ]]; then
        log_info "Запуск Cloudflare Tunnel..."
        docker compose --profile cloudflare up -d cloudflared
    fi
    
    if [[ "${SETUP_MONITORING}" == "true" ]]; then
        log_info "Запуск моніторингу..."
        docker compose --profile monitoring up -d prometheus grafana node-exporter loki promtail
    fi
    
    if [[ "${INSTALL_BRIDGES}" == "true" ]]; then
        log_info "Запуск мостів..."
        docker compose --profile bridges up -d
    fi
    
    if [[ "${INSTALL_ELEMENT}" == "true" ]]; then
        log_info "Запуск Element Web..."
        docker compose --profile element up -d element
    fi
    
    log_success "Всі сервіси запущено"
    show_status
}

# Зупинка сервісів
stop_services() {
    log_step "Зупинка Matrix сервісів"
    
    cd "${BASE_DIR}"
    
    if [[ ! -f "docker-compose.yml" ]]; then
        log_error "Файл docker-compose.yml не знайдено"
        return 1
    fi
    
    # Зупиняємо всі сервіси
    if docker compose down; then
        log_success "Всі сервіси зупинено"
    else
        log_error "Помилка зупинки сервісів"
        return 1
    fi
}

# Перезапуск сервісів
restart_services() {
    log_step "Перезапуск Matrix сервісів"
    
    stop_services
    sleep 2
    start_services
}

# Показ статусу
show_status() {
    log_step "Статус Matrix сервісів"
    
    cd "${BASE_DIR}"
    
    if [[ ! -f "docker-compose.yml" ]]; then
        log_error "Файл docker-compose.yml не знайдено"
        return 1
    fi
    
    echo
    echo "📊 Статус контейнерів:"
    docker compose ps
    
    echo
    echo "🌐 Доступні сервіси:"
    echo "   Matrix Synapse: http://${DOMAIN}:8008"
    echo "   Element Web: https://${DOMAIN}"
    echo "   Nginx: http://${DOMAIN}"
    
    if [[ "${SETUP_MONITORING}" == "true" ]]; then
        echo "   Grafana: http://localhost:3000"
        echo "   Prometheus: http://localhost:9090"
        echo "   Loki: http://localhost:3100"
    fi
    
    if [[ "${USE_CLOUDFLARE_TUNNEL}" == "true" ]]; then
        echo "   Cloudflare Tunnel: активний"
    fi
    
    echo
    echo "💾 Використання диску:"
    docker system df
    
    echo
    echo "📈 Використання ресурсів:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
}

# Показ логів
show_logs() {
    local service="${1:-}"
    
    cd "${BASE_DIR}"
    
    if [[ ! -f "docker-compose.yml" ]]; then
        log_error "Файл docker-compose.yml не знайдено"
        return 1
    fi
    
    if [[ -z "${service}" ]]; then
        log_info "Показ логів всіх сервісів..."
        docker compose logs -f
    else
        log_info "Показ логів сервісу: ${service}"
        docker compose logs -f "${service}"
    fi
}

# Оновлення образів
update_images() {
    log_step "Оновлення Docker образів"
    
    cd "${BASE_DIR}"
    
    if [[ ! -f "docker-compose.yml" ]]; then
        log_error "Файл docker-compose.yml не знайдено"
        return 1
    fi
    
    # Зупиняємо сервіси
    log_info "Зупинка сервісів для оновлення..."
    docker compose down
    
    # Оновлюємо образи
    log_info "Завантаження нових образів..."
    if ! docker compose pull; then
        log_error "Помилка завантаження образів"
        return 1
    fi
    
    # Запускаємо сервіси з новими образами
    log_info "Запуск сервісів з новими образами..."
    start_services
    
    # Очищаємо старі образи
    log_info "Очищення старих образів..."
    docker image prune -f
    
    log_success "Оновлення завершено"
}

# Резервне копіювання
create_backup() {
    log_step "Створення резервної копії"
    
    cd "${BASE_DIR}"
    
    local backup_dir="${BASE_DIR}/backups"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="${backup_dir}/matrix_backup_${timestamp}.tar.gz"
    
    mkdir -p "${backup_dir}"
    
    # Зупиняємо сервіси для консистентності
    log_info "Зупинка сервісів для резервного копіювання..."
    docker compose stop
    
    # Створюємо резервну копію
    log_info "Створення архіву..."
    tar -czf "${backup_file}" \
        --exclude='backups' \
        --exclude='*.log' \
        --exclude='.git' \
        .
    
    # Запускаємо сервіси
    log_info "Запуск сервісів..."
    docker compose start
    
    if [[ -f "${backup_file}" ]]; then
        local size=$(du -h "${backup_file}" | cut -f1)
        log_success "Резервну копію створено: ${backup_file} (${size})"
    else
        log_error "Помилка створення резервної копії"
        return 1
    fi
}

# Відновлення з резервної копії
restore_backup() {
    local backup_file="${1:-}"
    
    if [[ -z "${backup_file}" ]]; then
        log_error "Вкажіть файл резервної копії"
        log_info "Використання: ./matrix-control.sh restore <файл>"
        return 1
    fi
    
    if [[ ! -f "${backup_file}" ]]; then
        log_error "Файл резервної копії не знайдено: ${backup_file}"
        return 1
    fi
    
    log_step "Відновлення з резервної копії"
    
    cd "${BASE_DIR}"
    
    # Зупиняємо сервіси
    log_info "Зупинка сервісів..."
    docker compose down
    
    # Створюємо резервну копію поточної конфігурації
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    mv . .backup_${timestamp}
    
    # Відновлюємо з архіву
    log_info "Відновлення з архіву..."
    tar -xzf "${backup_file}" -C .
    
    # Запускаємо сервіси
    log_info "Запуск сервісів..."
    start_services
    
    log_success "Відновлення завершено"
}

# Показ конфігурації
show_config() {
    log_step "Конфігурація Matrix Synapse"
    
    echo "🌐 Домен: ${DOMAIN}"
    echo "📁 Базова директорія: ${BASE_DIR}"
    echo "🔐 Публічна реєстрація: ${ALLOW_PUBLIC_REGISTRATION}"
    echo "🌍 Федерація: ${ENABLE_FEDERATION}"
    echo "📱 Element Web: ${INSTALL_ELEMENT}"
    echo "🌉 Мости: ${INSTALL_BRIDGES}"
    echo "📊 Моніторинг: ${SETUP_MONITORING}"
    echo "☁️ Cloudflare Tunnel: ${USE_CLOUDFLARE_TUNNEL}"
    echo "💾 Резервне копіювання: ${SETUP_BACKUP}"
    
    if [[ "${INSTALL_BRIDGES}" == "true" ]]; then
        echo
        echo "🌉 Встановлені мости:"
        [[ "${INSTALL_SIGNAL_BRIDGE:-false}" == "true" ]] && echo "  📱 Signal Bridge"
        [[ "${INSTALL_WHATSAPP_BRIDGE:-false}" == "true" ]] && echo "  💬 WhatsApp Bridge"
        [[ "${INSTALL_DISCORD_BRIDGE:-false}" == "true" ]] && echo "  🎮 Discord Bridge"
    fi
}

# Відкриття shell в контейнері
open_shell() {
    local service="${1:-}"
    
    if [[ -z "${service}" ]]; then
        log_error "Вкажіть сервіс для відкриття shell"
        log_info "Доступні сервіси: postgres, redis, synapse, nginx, element"
        return 1
    fi
    
    cd "${BASE_DIR}"
    
    if [[ ! -f "docker-compose.yml" ]]; then
        log_error "Файл docker-compose.yml не знайдено"
        return 1
    fi
    
    log_info "Відкриття shell в контейнері: ${service}"
    docker compose exec "${service}" /bin/bash
}

# Запуск Portainer
start_portainer() {
    log_step "Запуск Portainer"
    
    cd "${BASE_DIR}"
    
    if [[ ! -f "docker-compose.yml" ]]; then
        log_error "Файл docker-compose.yml не знайдено"
        return 1
    fi
    
    log_info "Запуск Portainer..."
    docker compose --profile portainer up -d portainer
    
    log_success "Portainer запущено"
    echo "🌐 Portainer доступний за адресою: http://localhost:9000"
}

# Запуск моніторингу
start_monitoring() {
    log_step "Запуск моніторингу"
    
    cd "${BASE_DIR}"
    
    if [[ ! -f "docker-compose.yml" ]]; then
        log_error "Файл docker-compose.yml не знайдено"
        return 1
    fi
    
    log_info "Запуск сервісів моніторингу..."
    docker compose --profile monitoring up -d prometheus grafana node-exporter loki promtail
    
    log_success "Моніторинг запущено"
    echo "📊 Grafana: http://localhost:3000"
    echo "📈 Prometheus: http://localhost:9090"
    echo "📋 Loki: http://localhost:3100"
}

# Запуск мостів
start_bridges() {
    log_step "Запуск мостів"
    
    cd "${BASE_DIR}"
    
    if [[ ! -f "docker-compose.yml" ]]; then
        log_error "Файл docker-compose.yml не знайдено"
        return 1
    fi
    
    log_info "Запуск мостів..."
    docker compose --profile bridges up -d
    
    log_success "Мости запущено"
    echo "🌉 Доступні мости:"
    [[ "${INSTALL_SIGNAL_BRIDGE:-false}" == "true" ]] && echo "  📱 Signal Bridge: http://localhost:29328"
    [[ "${INSTALL_WHATSAPP_BRIDGE:-false}" == "true" ]] && echo "  💬 WhatsApp Bridge: http://localhost:29318"
    [[ "${INSTALL_DISCORD_BRIDGE:-false}" == "true" ]] && echo "  🎮 Discord Bridge: http://localhost:29334"
}

# Запуск Element Web
start_element() {
    log_step "Запуск Element Web"
    
    cd "${BASE_DIR}"
    
    if [[ ! -f "docker-compose.yml" ]]; then
        log_error "Файл docker-compose.yml не знайдено"
        return 1
    fi
    
    log_info "Запуск Element Web..."
    docker compose --profile element up -d element
    
    log_success "Element Web запущено"
    echo "🌐 Element Web доступний за адресою: https://${DOMAIN}"
}

# Запуск Cloudflare Tunnel
start_cloudflare() {
    log_step "Запуск Cloudflare Tunnel"
    
    cd "${BASE_DIR}"
    
    if [[ ! -f "docker-compose.yml" ]]; then
        log_error "Файл docker-compose.yml не знайдено"
        return 1
    fi
    
    if [[ "${USE_CLOUDFLARE_TUNNEL}" != "true" ]]; then
        log_error "Cloudflare Tunnel не налаштовано"
        return 1
    fi
    
    log_info "Запуск Cloudflare Tunnel..."
    docker compose --profile cloudflare up -d cloudflared
    
    log_success "Cloudflare Tunnel запущено"
    echo "☁️ Cloudflare Tunnel активний"
}

# --- Головна логіка ---
main() {
    local command="${1:-}"
    
    # Перевіряємо чи запущений Docker
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker не запущений або недоступний"
        exit 1
    fi
    
    case "${command}" in
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
            show_logs "${2:-}"
            ;;
        update)
            update_images
            ;;
        backup)
            create_backup
            ;;
        restore)
            restore_backup "${2:-}"
            ;;
        config)
            show_config
            ;;
        shell)
            open_shell "${2:-}"
            ;;
        portainer)
            start_portainer
            ;;
        monitoring)
            start_monitoring
            ;;
        bridges)
            start_bridges
            ;;
        element)
            start_element
            ;;
        cloudflare)
            start_cloudflare
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Невідома команда: ${command}"
            echo
            show_help
            exit 1
            ;;
    esac
}

# Запуск скрипта
main "$@"
