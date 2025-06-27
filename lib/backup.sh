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
    log_info "Налаштування системи резервного копіювання..."
    
    # Create backup directory
    mkdir -p "$BACKUP_BASE_DIR"
    
    # Create backup script
    create_backup_script
    
    # Create restore script
    create_restore_script
    
    # Setup cron job
    setup_backup_cron
    
    # Create initial backup
    if ask_yes_no "Створити початкове резервне копіювання?"; then
        run_backup
    fi
    
    log_success "Систему резервного копіювання налаштовано"
}

create_backup_script() {
    local backup_script="$BACKUP_BASE_DIR/backup-matrix.sh"
    
    cat > "$backup_script" << 'EOF'
#!/bin/bash
# Matrix Synapse Backup Script

set -euo pipefail

# Configuration
BACKUP_DIR="/DATA/matrix-backups"
BASE_DIR="/DATA/matrix"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="matrix-backup-$TIMESTAMP"
BACKUP_FILE="$BACKUP_DIR/$BACKUP_NAME.tar.gz"
LOG_FILE="$BACKUP_DIR/backup.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Main backup function
main() {
    log "Starting backup: $BACKUP_NAME"
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT
    
    # Stop services for consistent backup
    log "Stopping Matrix services..."
    cd "$BASE_DIR"
    docker-compose stop synapse element synapse-admin
    
    # Backup database
    log "Backing up PostgreSQL database..."
    docker-compose exec -T postgres pg_dump -U matrix_user matrix_db > "$TEMP_DIR/database.sql"
    
    # Backup configuration and data
    log "Backing up files..."
    cp -r "$BASE_DIR/synapse" "$TEMP_DIR/"
    cp -r "$BASE_DIR/element" "$TEMP_DIR/"
    cp "$BASE_DIR/docker-compose.yml" "$TEMP_DIR/"
    cp "$BASE_DIR/.env" "$TEMP_DIR/"
    
    # Create compressed archive
    log "Creating compressed archive..."
    tar -czf "$BACKUP_FILE" -C "$TEMP_DIR" .
    
    # Restart services
    log "Restarting Matrix services..."
    docker-compose start synapse element synapse-admin
    
    # Cleanup old backups
    cleanup_old_backups
    
    # Verify backup
    if [[ -f "$BACKUP_FILE" ]]; then
        BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
        log "Backup completed successfully: $BACKUP_FILE ($BACKUP_SIZE)"
    else
        log "ERROR: Backup failed - file not created"
        exit 1
    fi
}

# Cleanup old backups
cleanup_old_backups() {
    log "Cleaning up old backups (older than 30 days)..."
    find "$BACKUP_DIR" -name "matrix-backup-*.tar.gz" -mtime +30 -delete
}

# Run main function
main "$@"
EOF

    chmod +x "$backup_script"
    log_success "Скрипт резервного копіювання створено: $backup_script"
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

setup_backup_cron() {
    log_info "Налаштування cron завдання для автоматичного бекапу..."
    
    # Create cron job for daily backup at 2 AM
    local cron_job="0 2 * * * $BACKUP_BASE_DIR/backup-matrix.sh >> $BACKUP_LOG 2>&1"
    
    # Add to root crontab
    (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
    
    log_success "Cron завдання налаштовано (щодня о 2:00)"
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
export -f setup_backup_system run_backup list_backups restore_backup
