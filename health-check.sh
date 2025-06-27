#!/bin/bash
# Скрипт перевірки здоров'я Matrix системи

MATRIX_DIR="/DATA/matrix"
LOG_FILE="/var/log/matrix-health.log"

# Функція логування
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Перевірка доступності Synapse
check_synapse() {
    if curl -sf http://localhost:8008/_matrix/client/versions > /dev/null; then
        log_message "✅ Synapse: OK"
        return 0
    else
        log_message "❌ Synapse: НЕДОСТУПНИЙ"
        return 1
    fi
}

# Перевірка бази даних
check_database() {
    cd "$MATRIX_DIR"
    if docker compose exec -T postgres pg_isready -U matrix_user > /dev/null 2>&1; then
        log_message "✅ PostgreSQL: OK"
        return 0
    else
        log_message "❌ PostgreSQL: НЕДОСТУПНИЙ"
        return 1
    fi
}

# Перевірка дискового простору
check_disk_space() {
    USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$USAGE" -lt 80 ]; then
        log_message "✅ Дисковий простір: OK ($USAGE%)"
        return 0
    else
        log_message "⚠️ Дисковий простір: УВАГА ($USAGE%)"
        return 1
    fi
}

# Перевірка пам'яті
check_memory() {
    USAGE=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
    if [ "$USAGE" -lt 90 ]; then
        log_message "✅ Пам'ять: OK ($USAGE%)"
        return 0
    else
        log_message "⚠️ Пам'ять: УВАГА ($USAGE%)"
        return 1
    fi
}

# Основна перевірка
main() {
    log_message "=== Початок перевірки здоров'я Matrix ==="
    
    ERRORS=0
    
    check_synapse || ((ERRORS++))
    check_database || ((ERRORS++))
    check_disk_space || ((ERRORS++))
    check_memory || ((ERRORS++))
    
    if [ $ERRORS -eq 0 ]; then
        log_message "✅ Всі перевірки пройшли успішно"
    else
        log_message "❌ Знайдено $ERRORS проблем"
    fi
    
    log_message "=== Кінець перевірки здоров'я Matrix ==="
}

main "$@"
