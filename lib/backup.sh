#!/bin/bash
# ===================================================================================
# Backup Module - Automated backup and restore functionality
# ===================================================================================

# --- Constants ---
readonly BACKUP_BASE_DIR="/DATA/matrix-backups"
readonly BACKUP_RETENTION_DAYS=30
readonly BACKUP_LOG="$BACKUP_BASE_DIR/backup.log"

# --- Functions ---
setup_backup_system() {
    if [[ "${SETUP_BACKUP}" != "true" ]]; then
        return 0
    fi
    
    log_step "Налаштування системи резервного копіювання"
    
    local backup_dir="/DATA/matrix-backups"
    mkdir -p "${backup_dir}"
    
    # Create backup script
    create_backup_script "${backup_dir}"
    
    # Setup cron job
    setup_backup_cron "${backup_dir}"
    
    log_success "Систему резервного копіювання налаштовано"
}

create_backup_script() {
    local backup_dir="$1"
    
    log_info "Створення скрипта резервного копіювання..."
    
    cat > "${backup_dir}/backup-matrix.sh" << EOF
#!/bin/bash
# Matrix Backup Script

BACKUP_DIR="${backup_dir}"
MATRIX_DIR="${BASE_DIR}"
DATE=\$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_NAME="matrix-backup-\$DATE"
BACKUP_PATH="\$BACKUP_DIR/\$BACKUP_NAME"

# Create backup directory
mkdir -p "\$BACKUP_PATH"

# Log start
echo "\$(date): Початок резервного копіювання Matrix" >> "\$BACKUP_DIR/backup.log"

# Stop services for consistent backup
cd "\$MATRIX_DIR"
docker compose stop

# Backup configurations
cp -r "\$MATRIX_DIR/synapse/config" "\$BACKUP_PATH/"
cp -r "\$MATRIX_DIR/synapse/data" "\$BACKUP_PATH/" 2>/dev/null || true

# Backup docker-compose and env files
cp "\$MATRIX_DIR/docker-compose.yml" "\$BACKUP_PATH/" 2>/dev/null || true
cp "\$MATRIX_DIR/.env" "\$BACKUP_PATH/" 2>/dev/null || true

# Backup database
docker compose start postgres
sleep 10
docker compose exec -T postgres pg_dump -U matrix_user matrix_db > "\$BACKUP_PATH/database.sql"

# Restart services
docker compose up -d

# Create archive
cd "\$BACKUP_DIR"
tar -czf "\$BACKUP_NAME.tar.gz" "\$BACKUP_NAME"
rm -rf "\$BACKUP_NAME"

# Clean old backups (keep last 7)
find "\$BACKUP_DIR" -name "matrix-backup-*.tar.gz" -type f -mtime +7 -delete

echo "\$(date): Резервне копіювання завершено: \$BACKUP_NAME.tar.gz" >> "\$BACKUP_DIR/backup.log"
EOF
    
    chmod +x "${backup_dir}/backup-matrix.sh"
}

setup_backup_cron() {
    local backup_dir="$1"
    
    log_info "Налаштування автоматичного резервного копіювання..."
    
    # Add cron job for daily backup at 2 AM
    (crontab -l 2>/dev/null; echo "0 2 * * * ${backup_dir}/backup-matrix.sh") | crontab -
    
    log_success "Автоматичне резервне копіювання налаштовано (щодня о 2:00)"
}

create_restore_script() {
    local restore_script="$BACKUP_BASE_DIR/restore-matrix.sh"
    
    cat > "$restore_script" << 'EOF'
#!/bin/bash
# Matrix Synapse Restore Script

set -euo pipefail

# Configuration
BACKUP_DIR="/DATA/matrix-backups"
BASE_DIR="/DATA/matrix"
LOG_FILE="$BACKUP_DIR/restore.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Usage function
usage() {
    echo "Usage: $0 <backup-file>"
    echo "Example: $0 matrix-backup-20240101_120000.tar.gz"
    exit 1
}

# Main restore function
main() {
    local backup_file="$1"
    
    if [[ ! -f "$BACKUP_DIR/$backup_file" ]]; then
        log "ERROR: Backup file not found: $BACKUP_DIR/$backup_file"
        exit 1
    fi
    
    log "Starting restore from: $backup_file"
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT
    
    # Extract backup
    log "Extracting backup..."
    tar -xzf "$BACKUP_DIR/$backup_file" -C "$TEMP_DIR"
    
    # Stop services
    log "Stopping Matrix services..."
    cd "$BASE_DIR"
    docker-compose down
    
    # Backup current configuration
    log "Backing up current configuration..."
    mv "$BASE_DIR" "$BASE_DIR.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Restore files
    log "Restoring files..."
    mkdir -p "$BASE_DIR"
    cp -r "$TEMP_DIR/synapse" "$BASE_DIR/"
    cp -r "$TEMP_DIR/element" "$BASE_DIR/"
    cp "$TEMP_DIR/docker-compose.yml" "$BASE_DIR/"
    cp "$TEMP_DIR/.env" "$BASE_DIR/"
    
    # Start database
    log "Starting PostgreSQL..."
    cd "$BASE_DIR"
    docker-compose up -d postgres
    sleep 10
    
    # Restore database
    log "Restoring database..."
    docker-compose exec -T postgres psql -U matrix_user -d matrix_db < "$TEMP_DIR/database.sql"
    
    # Start all services
    log "Starting all services..."
    docker-compose up -d
    
    log "Restore completed successfully"
}

# Check arguments
if [[ $# -ne 1 ]]; then
    usage
fi

# Run main function
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

# Export functions
export -f setup_backup_system create_backup_script setup_backup_cron run_backup list_backups restore_backup
