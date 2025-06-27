#!/bin/bash
# ===================================================================================
# Logger Module - Centralized logging system
# ===================================================================================

# --- Color Codes ---
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# --- Log Levels ---
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3
readonly LOG_LEVEL_SUCCESS=4

# --- Configuration ---
LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}
LOG_FILE=""
LOG_TO_FILE=${LOG_TO_FILE:-false}

# --- Functions ---
init_logger() {
    local log_dir="/var/log/matrix-installer"
    
    if [[ "$EUID" -eq 0 ]]; then
        mkdir -p "$log_dir"
        LOG_FILE="$log_dir/install-$(date +%Y%m%d_%H%M%S).log"
        LOG_TO_FILE=true
        
        # Create symlink to latest log
        ln -sf "$LOG_FILE" "$log_dir/latest.log"
    else
        LOG_FILE="./matrix-install-$(date +%Y%m%d_%H%M%S).log"
        LOG_TO_FILE=true
    fi
    
    log_info "Логування ініціалізовано: $LOG_FILE"
}

log_message() {
    local level="$1"
    local color="$2"
    local message="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Console output with colors
    echo -e "${color}[${timestamp}] [${level}] ${message}${NC}"
    
    # File output without colors
    if [[ "$LOG_TO_FILE" == "true" && -n "$LOG_FILE" ]]; then
        echo "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE"
    fi
}

log_debug() {
    [[ $LOG_LEVEL -le $LOG_LEVEL_DEBUG ]] && log_message "DEBUG" "$CYAN" "$1"
}

log_info() {
    [[ $LOG_LEVEL -le $LOG_LEVEL_INFO ]] && log_message "INFO" "$BLUE" "$1"
}

log_warn() {
    [[ $LOG_LEVEL -le $LOG_LEVEL_WARN ]] && log_message "WARN" "$YELLOW" "$1"
}

log_error() {
    [[ $LOG_LEVEL -le $LOG_LEVEL_ERROR ]] && log_message "ERROR" "$RED" "$1" >&2
}

log_success() {
    [[ $LOG_LEVEL -le $LOG_LEVEL_SUCCESS ]] && log_message "SUCCESS" "$GREEN" "$1"
}

log_step() {
    echo
    log_message "STEP" "$PURPLE" "=== $1 ==="
    echo
}

# Progress bar function
show_progress() {
    local current=$1
    local total=$2
    local message=${3:-"Processing"}
    local width=50
    
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r${BLUE}${message}: ["
    printf "%${filled}s" | tr ' ' '='
    printf "%${empty}s" | tr ' ' '-'
    printf "] %d%% (%d/%d)${NC}" "$percentage" "$current" "$total"
    
    if [[ $current -eq $total ]]; then
        echo
    fi
}

# Spinner function for long operations
show_spinner() {
    local pid=$1
    local message=${2:-"Processing"}
    local delay=0.1
    local spinstr='|/-\'
    
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf "\r${BLUE}${message}... %c${NC}" "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\r${GREEN}${message}... Done!${NC}\n"
}

# Error handling
handle_error() {
    local exit_code=$?
    local line_number=$1
    
    log_error "Помилка в рядку $line_number (код виходу: $exit_code)"
    log_error "Команда: ${BASH_COMMAND}"
    
    if [[ -n "$LOG_FILE" ]]; then
        log_error "Детальні логи: $LOG_FILE"
    fi
    
    exit $exit_code
}

# Set error trap
trap 'handle_error $LINENO' ERR

# Export functions
export -f log_debug log_info log_warn log_error log_success log_step
export -f show_progress show_spinner handle_error
