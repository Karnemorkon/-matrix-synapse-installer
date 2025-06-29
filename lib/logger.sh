#!/bin/bash
# ===================================================================================
# Модуль Логування - Централізована система логування
# ===================================================================================

# --- Конфігурація ---
# Визначаємо домашню директорію фактичного користувача
if [[ -n "${SUDO_USER}" ]]; then
    # Скрипт запущено з sudo, використовуємо домашню директорію оригінального користувача
    ACTUAL_USER_HOME=$(getent passwd "${SUDO_USER}" | cut -d: -f6)
    LOG_DIR="${ACTUAL_USER_HOME}/.local/share/matrix-installer/logs"
    ACTUAL_USER_ID=$(id -u "${SUDO_USER}")
    ACTUAL_GROUP_ID=$(id -g "${SUDO_USER}")
else
    # Скрипт запущено безпосередньо як root або без sudo
    LOG_DIR="/var/log/matrix-installer"
    ACTUAL_USER_ID=""
    ACTUAL_GROUP_ID=""
fi

readonly LOG_FILE="${LOG_DIR}/install-$(date +%Y%m%d-%H%M%S).log"

# Кольори для виводу
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # Без кольору

# --- Функції ---
init_logger() {
    # Створюємо директорію логів з правильними правами
    mkdir -p "${LOG_DIR}"
    
    # Якщо використовуємо sudo, встановлюємо правильне володіння
    if [[ -n "${SUDO_USER}" && -n "${ACTUAL_USER_ID}" && -n "${ACTUAL_GROUP_ID}" ]]; then
        # Змінюємо володіння всієї структури директорії логів
        chown -R "${ACTUAL_USER_ID}:${ACTUAL_GROUP_ID}" "${LOG_DIR}"
        # Також змінюємо володіння батьківських директорій якщо вони були створені
        local parent_dir="$(dirname "${LOG_DIR}")"
        if [[ -d "${parent_dir}" ]]; then
            chown "${ACTUAL_USER_ID}:${ACTUAL_GROUP_ID}" "${parent_dir}" 2>/dev/null || true
        fi
        local grandparent_dir="$(dirname "${parent_dir}")"
        if [[ -d "${grandparent_dir}" ]]; then
            chown "${ACTUAL_USER_ID}:${ACTUAL_GROUP_ID}" "${grandparent_dir}" 2>/dev/null || true
        fi
    fi
    
    touch "${LOG_FILE}"
    
    # Встановлюємо правильне володіння для файлу логу
    if [[ -n "${SUDO_USER}" && -n "${ACTUAL_USER_ID}" && -n "${ACTUAL_GROUP_ID}" ]]; then
        chown "${ACTUAL_USER_ID}:${ACTUAL_GROUP_ID}" "${LOG_FILE}"
    fi
    
    log_info "Ініціалізація системи логування"
    log_info "Файл логу: ${LOG_FILE}"
    
    # Логуємо інформацію про систему
    log_info "Користувач: ${SUDO_USER:-root}"
    log_info "Робоча директорія: $(pwd)"
    log_info "Версія скрипта: Matrix Synapse Installer 3.0"
}

log_raw() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ${message}" >> "${LOG_FILE}" 2>/dev/null || true
}

log_info() {
    local message="$1"
    echo -e "${BLUE}[INFO]${NC} ${message}"
    log_raw "INFO: ${message}"
}

log_success() {
    local message="$1"
    echo -e "${GREEN}[SUCCESS]${NC} ${message}"
    log_raw "SUCCESS: ${message}"
}

log_warning() {
    local message="$1"
    echo -e "${YELLOW}[WARNING]${NC} ${message}"
    log_raw "WARNING: ${message}"
}

log_error() {
    local message="$1"
    echo -e "${RED}[ERROR]${NC} ${message}" >&2
    log_raw "ERROR: ${message}"
}

log_step() {
    local message="$1"
    echo -e "${PURPLE}[STEP]${NC} ${message}"
    log_raw "STEP: ${message}"
}

log_debug() {
    local message="$1"
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${CYAN}[DEBUG]${NC} ${message}"
    fi
    log_raw "DEBUG: ${message}"
}

log_command() {
    local command="$1"
    log_debug "Виконується: ${command}"
    if eval "${command}" >> "${LOG_FILE}" 2>&1; then
        log_debug "Команда виконана успішно: ${command}"
        return 0
    else
        log_error "Команда завершилася помилкою: ${command}"
        return 1
    fi
}

# Експортуємо функції
export -f init_logger log_raw log_info log_success log_warning log_error log_step log_debug log_command
