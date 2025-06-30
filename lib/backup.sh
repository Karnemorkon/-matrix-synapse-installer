#!/bin/bash
# ===================================================================================
# Модуль Резервного Копіювання - Автоматизоване резервне копіювання та відновлення
# ===================================================================================

# --- Константи ---
readonly BACKUP_BASE_DIR="/DATA/matrix-backups"
# readonly BACKUP_RETENTION_DAYS=30
readonly BACKUP_LOG="$BACKUP_BASE_DIR/backup.log"

# --- Функції ---
setup_backup_system() {
    if [[ "${SETUP_BACKUP}" != "true" ]]; then
        return 0
    fi
    
    log_step "Налаштування системи резервного копіювання"
    
    local backup_dir="/DATA/matrix-backups"
    mkdir -p "${backup_dir}"
    
    # Створюємо скрипт резервного копіювання
    create_backup_script "${backup_dir}"
    
    # Налаштовуємо cron завдання
    setup_backup_cron "${backup_dir}"
    
    log_success "Систему резервного копіювання налаштовано"
}

create_backup_script() {
    local backup_dir="$1"
    
    log_info "Створення скрипта резервного копіювання..."
    
    cat > "${backup_dir}/backup-matrix.sh" << EOF
#!/bin/bash
# Скрипт Резервного Копіювання Matrix

BACKUP_DIR="${backup_dir}"
MATRIX_DIR="${BASE_DIR}"
DATE=\$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_NAME="matrix-backup-\$DATE"
BACKUP_PATH="\$BACKUP_DIR/\$BACKUP_NAME"

# Створюємо директорію резервного копіювання
mkdir -p "\$BACKUP_PATH"

# Логуємо початок
echo "\$(date): Початок резервного копіювання Matrix" >> "\$BACKUP_DIR/backup.log"

# Зупиняємо сервіси для узгодженого резервного копіювання
cd "\$MATRIX_DIR"
docker compose stop

# Резервне копіювання конфігурацій
cp -r "\$MATRIX_DIR/synapse/config" "\$BACKUP_PATH/"
cp -r "\$MATRIX_DIR/synapse/data" "\$BACKUP_PATH/" 2>/dev/null || true

# Резервне копіювання docker-compose та env файлів
cp "\$MATRIX_DIR/docker-compose.yml" "\$BACKUP_PATH/" 2>/dev/null || true
cp "\$MATRIX_DIR/.env" "\$BACKUP_PATH/" 2>/dev/null || true

# Резервне копіювання бази даних
docker compose start postgres
sleep 10
docker compose exec -T postgres pg_dump -U matrix_user matrix_db > "\$BACKUP_PATH/database.sql"

# Перезапускаємо сервіси
docker compose up -d

# Створюємо архів
cd "\$BACKUP_DIR"
tar -czf "\$BACKUP_NAME.tar.gz" "\$BACKUP_NAME"
rm -rf "\$BACKUP_NAME"

# Очищаємо старі резервні копії (зберігаємо останні 7)
find "\$BACKUP_DIR" -name "matrix-backup-*.tar.gz" -type f -mtime +7 -delete

echo "\$(date): Резервне копіювання завершено: \$BACKUP_NAME.tar.gz" >> "\$BACKUP_DIR/backup.log"
EOF
    
    chmod +x "${backup_dir}/backup-matrix.sh"
}

setup_backup_cron() {
    local backup_dir="$1"
    
    log_info "Налаштування автоматичного резервного копіювання..."
    
    # Додаємо cron завдання для щоденного резервного копіювання о 2 ранку
    (crontab -l 2>/dev/null; echo "0 2 * * * ${backup_dir}/backup-matrix.sh") | crontab -
    
    log_success "Автоматичне резервне копіювання налаштовано (щодня о 2:00)"
}

create_restore_script() {
    local restore_script="$BACKUP_BASE_DIR/restore-matrix.sh"
    
    cat > "$restore_script" << 'EOF'
#!/bin/bash
# Скрипт Відновлення Matrix Synapse

set -euo pipefail

# Конфігурація
BACKUP_DIR="/DATA/matrix-backups"
BASE_DIR="/DATA/matrix"
LOG_FILE="$BACKUP_DIR/restore.log"

# Функція логування
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Функція використання
usage() {
    echo "Використання: $0 <backup-file>"
    echo "Приклад: $0 matrix-backup-20240101_120000.tar.gz"
    exit 1
}

# Основна функція відновлення
main() {
    local backup_file="$1"
    
    if [[ ! -f "$BACKUP_DIR/$backup_file" ]]; then
        log "ПОМИЛКА: Файл резервної копії не знайдено: $BACKUP_DIR/$backup_file"
        exit 1
    fi
    
    log "Початок відновлення з: $backup_file"
    
    # Створюємо тимчасову директорію
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT
    
    # Розпаковуємо резервну копію
    log "Розпаковуємо резервну копію..."
    tar -xzf "$BACKUP_DIR/$backup_file" -C "$TEMP_DIR"
    
    # Зупиняємо сервіси
    log "Зупиняємо сервіси Matrix..."
    cd "$BASE_DIR"
    docker-compose down
    
    # Резервне копіювання поточної конфігурації
    log "Резервне копіювання поточної конфігурації..."
    mv "$BASE_DIR" "$BASE_DIR.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Відновлюємо файли
    log "Відновлюємо файли..."
    mkdir -p "$BASE_DIR"
    cp -r "$TEMP_DIR/synapse" "$BASE_DIR/"
    cp -r "$TEMP_DIR/element" "$BASE_DIR/"
    cp "$TEMP_DIR/docker-compose.yml" "$BASE_DIR/"
    cp "$TEMP_DIR/.env" "$BASE_DIR/"
    
    # Запускаємо базу даних
    log "Запускаємо PostgreSQL..."
    cd "$BASE_DIR"
    docker-compose up -d postgres
    sleep 10
    
    # Відновлюємо базу даних
    log "Відновлюємо базу даних..."
    docker-compose exec -T postgres psql -U matrix_user -d matrix_db < "$TEMP_DIR/database.sql"
    
    # Запускаємо всі сервіси
    log "Запускаємо всі сервіси..."
    docker-compose up -d
    
    log "Відновлення завершено успішно"
}

# Перевіряємо аргументи
if [[ $# -ne 1 ]]; then
    usage
fi

# Запускаємо основну функцію
main "$1"
EOF

    chmod +x "$restore_script"
    log_success "Скрипт відновлення створено: $restore_script"
}

run_backup() {
    log_info "Запуск резервного копіювання..."
    
    if [[ -f "$BACKUP_BASE_DIR/backup-matrix.sh" ]]; then
        "$BACKUP_BASE_DIR/backup-matrix.sh"
    else
        log_error "Скрипт резервного копіювання не знайдено"
        return 1
    fi
}

list_backups() {
    log_info "Доступні резервні копії:"
    
    if [[ -d "$BACKUP_BASE_DIR" ]]; then
        ls -la "$BACKUP_BASE_DIR"/*.tar.gz 2>/dev/null || log_info "Резервні копії не знайдено"
    else
        log_info "Директорія бекапів не існує"
    fi
}

restore_backup() {
    local backup_file="$1"
    
    if [[ -z "$backup_file" ]]; then
        log_error "Не вказано файл резервної копії"
        list_backups
        return 1
    fi
    
    log_info "Відновлення з резервної копії: $backup_file"
    
    if [[ -f "$BACKUP_BASE_DIR/restore-matrix.sh" ]]; then
        "$BACKUP_BASE_DIR/restore-matrix.sh" "$backup_file"
    else
        log_error "Скрипт відновлення не знайдено"
        return 1
    fi
}

# Експортуємо функції
export -f setup_backup_system create_backup_script setup_backup_cron run_backup list_backups restore_backup
