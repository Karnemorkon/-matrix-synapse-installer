#!/bin/bash
# ===================================================================================
# Logger Module - Centralized logging system
# ===================================================================================

# --- Configuration ---
readonly LOG_DIR="${HOME}/.local/share/matrix-installer/logs"
readonly LOG_FILE="${LOG_DIR}/install-$(date +%Y%m%d-%H%M%S).log"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# --- Functions ---
init_logger() {
    mkdir -p "${LOG_DIR}"
    touch "${LOG_FILE}"
    log_info "Ініціалізація системи логування"
    log_info "Файл логу: ${LOG_FILE}"
}

log_raw() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ${message}" >> "${LOG_FILE}"
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

# Export functions
export -f init_logger log_raw log_info log_success log_warning log_error log_step log_debug
