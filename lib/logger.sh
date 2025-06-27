#!/bin/bash
# ===================================================================================
# Logger Module - Centralized logging functionality
# ===================================================================================

# --- Configuration ---
readonly LOG_DIR="${LOG_DIR:-/var/log/matrix-installer}"
readonly LOG_FILE="${LOG_DIR}/install-$(date +%Y-%m-%d_%H-%M-%S).log"
readonly LOG_LEVEL="${LOG_LEVEL:-INFO}"

# --- Colors ---
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# --- Log Levels ---
readonly LOG_LEVEL_ERROR=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_INFO=3
readonly LOG_LEVEL_DEBUG=4

# --- Functions ---
init_logger() {
    mkdir -p "${LOG_DIR}"
    touch "${LOG_FILE}"
    
    # Set permissions
    chmod 755 "${LOG_DIR}"
    chmod 644 "${LOG_FILE}"
    
    log_info "Logger initialized. Log file: ${LOG_FILE}"
}

get_log_level_num() {
    case "${LOG_LEVEL}" in
        ERROR) echo ${LOG_LEVEL_ERROR} ;;
        WARN)  echo ${LOG_LEVEL_WARN} ;;
        INFO)  echo ${LOG_LEVEL_INFO} ;;
        DEBUG) echo ${LOG_LEVEL_DEBUG} ;;
        *) echo ${LOG_LEVEL_INFO} ;;
    esac
}

should_log() {
    local level_num=$1
    local current_level_num
    current_level_num=$(get_log_level_num)
    
    [[ ${level_num} -le ${current_level_num} ]]
}

log_message() {
    local level=$1
    local level_num=$2
    local color=$3
    local message=$4
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log to file
    echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}"
    
    # Log to console if level is appropriate
    if should_log "${level_num}"; then
        echo -e "${color}[${level}]${NC} ${message}"
    fi
}

log_error() {
    log_message "ERROR" ${LOG_LEVEL_ERROR} "${RED}" "$1"
}

log_warn() {
    log_message "WARN" ${LOG_LEVEL_WARN} "${YELLOW}" "$1"
}

log_info() {
    log_message "INFO" ${LOG_LEVEL_INFO} "${BLUE}" "$1"
}

log_success() {
    log_message "SUCCESS" ${LOG_LEVEL_INFO} "${GREEN}" "$1"
}

log_debug() {
    log_message "DEBUG" ${LOG_LEVEL_DEBUG} "${PURPLE}" "$1"
}

log_step() {
    echo
    log_message "STEP" ${LOG_LEVEL_INFO} "${CYAN}" "=== $1 ==="
}

log_command() {
    local cmd=$1
    log_debug "Executing: ${cmd}"
    
    if eval "${cmd}" >> "${LOG_FILE}" 2>&1; then
        log_debug "Command succeeded: ${cmd}"
        return 0
    else
        local exit_code=$?
        log_error "Command failed (exit code: ${exit_code}): ${cmd}"
        return ${exit_code}
    fi
}

# Progress indicator
show_progress() {
    local current=$1
    local total=$2
    local message=$3
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    printf "\r${BLUE}[${GREEN}"
    printf "%${filled}s" | tr ' ' '='
    printf "${NC}${BLUE}"
    printf "%${empty}s" | tr ' ' '-'
    printf "] ${percent}%% ${message}${NC}"
    
    if [[ ${current} -eq ${total} ]]; then
        echo
    fi
}
