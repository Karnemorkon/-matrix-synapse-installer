#!/bin/bash
# ===================================================================================
# Модуль Обробки Помилок - Централізована обробка помилок та відновлення
# ===================================================================================

# --- Константи ---
readonly ERROR_LOG_FILE="/var/log/matrix-installer-errors.log"
readonly MAX_RETRY_ATTEMPTS=3
readonly RETRY_DELAY=5

# --- Глобальні змінні ---
declare -a ERROR_HISTORY=()
declare -i TOTAL_ERRORS=0
declare -i CRITICAL_ERRORS=0

# --- Функції ---

# Ініціалізація обробника помилок
init_error_handler() {
    mkdir -p "$(dirname "$ERROR_LOG_FILE")"
    touch "$ERROR_LOG_FILE"
    
    # Встановлюємо trap для обробки сигналів
    trap 'handle_exit' EXIT
    trap 'handle_signal' SIGINT SIGTERM
    
    log_info "Обробник помилок ініціалізовано"
}

# Обробка критичних помилок
handle_critical_error() {
    local error_message="$1"
    local error_code="${2:-1}"
    local context="${3:-Unknown}"
    
    ((CRITICAL_ERRORS++))
    ((TOTAL_ERRORS++))
    
    # Логуємо помилку
    log_error "КРИТИЧНА ПОМИЛКА [$context]: $error_message"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [CRITICAL] [$context] $error_message" >> "$ERROR_LOG_FILE"
    
    # Додаємо до історії
    ERROR_HISTORY+=("$(date '+%Y-%m-%d %H:%M:%S') - CRITICAL - [$context] $error_message")
    
    # Показуємо користувачу
    echo -e "${RED}❌ КРИТИЧНА ПОМИЛКА:${NC} $error_message"
    echo -e "${YELLOW}Контекст:${NC} $context"
    echo -e "${YELLOW}Код помилки:${NC} $error_code"
    
    # Пропонуємо варіанти вирішення
    suggest_solutions "$context" "$error_message"
    
    return "$error_code"
}

# Обробка звичайних помилок
handle_error() {
    local error_message="$1"
    local context="${2:-Unknown}"
    local retry="${3:-false}"
    
    ((TOTAL_ERRORS++))
    
    # Логуємо помилку
    log_error "ПОМИЛКА [$context]: $error_message"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] [$context] $error_message" >> "$ERROR_LOG_FILE"
    
    # Додаємо до історії
    ERROR_HISTORY+=("$(date '+%Y-%m-%d %H:%M:%S') - ERROR - [$context] $error_message")
    
    # Якщо потрібно повторити
    if [[ "$retry" == "true" ]]; then
        handle_retry "$context" "$error_message"
    fi
}

# Обробка попереджень
handle_warning() {
    local warning_message="$1"
    local context="${2:-Unknown}"
    
    log_warning "ПОПЕРЕДЖЕННЯ [$context]: $warning_message"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARNING] [$context] $warning_message" >> "$ERROR_LOG_FILE"
    
    # Додаємо до історії
    ERROR_HISTORY+=("$(date '+%Y-%m-%d %H:%M:%S') - WARNING - [$context] $warning_message")
}

# Обробка повторних спроб
handle_retry() {
    local context="$1"
    local error_message="$2"
    local attempt=1
    
    while [[ $attempt -le $MAX_RETRY_ATTEMPTS ]]; do
        log_info "Спроба $attempt/$MAX_RETRY_ATTEMPTS для [$context]"
        
        # Чекаємо перед повторною спробою
        if [[ $attempt -gt 1 ]]; then
            sleep $RETRY_DELAY
        fi
        
        # Тут можна додати логіку повторної спроби
        # Наприклад, повторне виконання команди
        
        ((attempt++))
    done
    
    log_error "Всі спроби для [$context] невдалі"
}

# Пропозиції рішень
suggest_solutions() {
    local context="$1"
    local error_message="$2"
    
    echo -e "${CYAN}💡 Можливі рішення:${NC}"
    
    case "$context" in
        "docker")
            echo "  • Перевірте чи Docker запущений: systemctl status docker"
            echo "  • Перезапустіть Docker: systemctl restart docker"
            echo "  • Перевірте права доступу: usermod -aG docker \$USER"
            ;;
        "network")
            echo "  • Перевірте підключення до інтернету: ping 8.8.8.8"
            echo "  • Перевірте DNS: nslookup matrix.org"
            echo "  • Перевірте файрвол: ufw status"
            ;;
        "disk")
            echo "  • Очистіть дисковий простір: df -h"
            echo "  • Видаліть непотрібні файли: apt autoremove"
            echo "  • Розширте дисковий простір"
            ;;
        "permissions")
            echo "  • Перевірте права доступу: ls -la"
            echo "  • Змініть власника: chown -R user:group /path"
            echo "  • Змініть права: chmod -R 755 /path"
            ;;
        "ssl")
            echo "  • Перевірте домен: nslookup $DOMAIN"
            echo "  • Перевірте порти: netstat -tuln | grep :443"
            echo "  • Оновіть сертифікат: certbot renew"
            ;;
        *)
            echo "  • Перевірте логи: tail -f $LOG_FILE"
            echo "  • Перезапустіть сервіси: systemctl restart service"
            echo "  • Зверніться до документації: docs/TROUBLESHOOTING.md"
            ;;
    esac
}

# Обробка виходу
handle_exit() {
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "Скрипт завершився з кодом помилки: $exit_code"
        echo "$(date '+%Y-%m-%d %H:%M:%S') [EXIT] Код: $exit_code" >> "$ERROR_LOG_FILE"
        
        # Показуємо зведення помилок
        show_error_summary
    fi
    
    # Очищаємо trap
    trap - EXIT
    exit $exit_code
}

# Обробка сигналів
handle_signal() {
    local signal=$1
    log_warning "Отримано сигнал: $signal"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SIGNAL] $signal" >> "$ERROR_LOG_FILE"
    
    # Показуємо зведення перед виходом
    show_error_summary
    
    exit 1
}

# Показ зведення помилок
show_error_summary() {
    if [[ ${#ERROR_HISTORY[@]} -gt 0 ]]; then
        echo -e "${YELLOW}📊 Зведення помилок:${NC}"
        echo "  Загальна кількість помилок: $TOTAL_ERRORS"
        echo "  Критичних помилок: $CRITICAL_ERRORS"
        echo "  Попереджень: $((TOTAL_ERRORS - CRITICAL_ERRORS))"
        echo
        echo -e "${YELLOW}📝 Останні помилки:${NC}"
        
        # Показуємо останні 5 помилок
        local count=0
        for ((i=${#ERROR_HISTORY[@]}-1; i>=0 && count<5; i--)); do
            echo "  ${ERROR_HISTORY[$i]}"
            ((count++))
        done
    fi
}

# Перевірка чи є критичні помилки
has_critical_errors() {
    [[ $CRITICAL_ERRORS -gt 0 ]]
}

# Очищення історії помилок
clear_error_history() {
    ERROR_HISTORY=()
    TOTAL_ERRORS=0
    CRITICAL_ERRORS=0
    log_info "Історію помилок очищено"
}

# Експортуємо функції
export -f init_error_handler handle_critical_error handle_error handle_warning
export -f handle_retry suggest_solutions handle_exit handle_signal
export -f show_error_summary has_critical_errors clear_error_history 