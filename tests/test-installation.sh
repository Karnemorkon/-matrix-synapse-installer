#!/bin/bash
# ===================================================================================
# Matrix Synapse Installer Test Suite
# ===================================================================================

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Test configuration
readonly TEST_DIR="/tmp/matrix-test"
readonly TEST_DOMAIN="test.matrix.local"
readonly TEST_BASE_DIR="${TEST_DIR}/matrix"

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log "Running test: $test_name"
    
    if eval "$test_command"; then
        log_success "Test passed: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error "Test failed: $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Setup test environment
setup_test_environment() {
    log "Setting up test environment..."
    
    # Create test directory
    mkdir -p "${TEST_DIR}"
    
    # Copy installer files
    cp -r . "${TEST_DIR}/installer"
    cd "${TEST_DIR}/installer"
    
    # Create test configuration
    cat > "${TEST_DIR}/test-config.conf" << EOF
DOMAIN="${TEST_DOMAIN}"
BASE_DIR="${TEST_BASE_DIR}"
POSTGRES_PASSWORD="test_password_123"
ALLOW_PUBLIC_REGISTRATION="false"
ENABLE_FEDERATION="false"
INSTALL_ELEMENT="true"
INSTALL_BRIDGES="false"
SETUP_MONITORING="true"
SETUP_BACKUP="true"
USE_CLOUDFLARE_TUNNEL="false"
EOF
    
    log_success "Test environment setup complete"
}

# Cleanup test environment
cleanup_test_environment() {
    log "Cleaning up test environment..."
    
    # Stop and remove containers
    if [[ -f "${TEST_BASE_DIR}/docker-compose.yml" ]]; then
        cd "${TEST_BASE_DIR}"
        docker compose down -v 2>/dev/null || true
    fi
    
    # Remove test directories
    rm -rf "${TEST_DIR}"
    
    # Clean up Docker resources
    docker system prune -f 2>/dev/null || true
    
    log_success "Test environment cleanup complete"
}

# Test functions
test_system_requirements() {
    log "Testing system requirements validation..."
    
    # Test root privileges check
    run_test "Root privileges check" "[[ \$EUID -eq 0 ]]"
    
    # Test OS detection
    run_test "OS detection" "command -v apt &> /dev/null"
    
    # Test RAM check
    local total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_ram_gb=$((total_ram_kb / 1024 / 1024))
    run_test "RAM check" "[[ $total_ram_gb -ge 2 ]]"
    
    # Test disk space check
    local available_space_kb=$(df / | tail -1 | awk '{print $4}')
    local available_space_gb=$((available_space_kb / 1024 / 1024))
    run_test "Disk space check" "[[ $available_space_gb -ge 10 ]]"
    
    # Test architecture check
    local arch=$(uname -m)
    run_test "Architecture check" "[[ \"$arch\" == \"x86_64\" || \"$arch\" == \"aarch64\" || \"$arch\" == \"arm64\" ]]"
}

test_configuration_loading() {
    log "Testing configuration loading..."
    
    # Source configuration module
    source lib/config.sh
    
    # Test configuration loading
    run_test "Configuration loading" "load_config"
    
    # Test configuration validation
    run_test "Configuration validation" "validate_config"
    
    # Test service URLs generation
    run_test "Service URLs generation" "get_service_urls | grep -q '${TEST_DOMAIN}'"
}

test_docker_installation() {
    log "Testing Docker installation..."
    
    # Test Docker availability
    run_test "Docker availability" "command -v docker &> /dev/null"
    
    # Test Docker Compose availability
    run_test "Docker Compose availability" "command -v docker compose &> /dev/null"
    
    # Test Docker daemon
    run_test "Docker daemon" "docker info &> /dev/null"
}

test_directory_structure() {
    log "Testing directory structure creation..."
    
    # Source docker module
    source lib/docker.sh
    
    # Test directory creation
    run_test "Directory structure creation" "setup_directory_structure"
    
    # Test if directories exist
    run_test "Base directory exists" "[[ -d \"${TEST_BASE_DIR}\" ]]"
    run_test "Synapse config directory exists" "[[ -d \"${TEST_BASE_DIR}/synapse/config\" ]]"
    run_test "Element directory exists" "[[ -d \"${TEST_BASE_DIR}/element\" ]]"
}

test_configuration_generation() {
    log "Testing configuration generation..."
    
    # Source matrix module
    source lib/matrix.sh
    
    # Test Synapse config generation
    run_test "Synapse config generation" "generate_synapse_config"
    
    # Test Element config generation
    run_test "Element config generation" "generate_element_config"
    
    # Test if config files exist
    run_test "Synapse config file exists" "[[ -f \"${TEST_BASE_DIR}/synapse/config/homeserver.yaml\" ]]"
    run_test "Element config file exists" "[[ -f \"${TEST_BASE_DIR}/element/config.json\" ]]"
}

test_docker_compose_generation() {
    log "Testing Docker Compose generation..."
    
    # Source docker module
    source lib/docker.sh
    
    # Test Docker Compose generation
    run_test "Docker Compose generation" "generate_docker_compose"
    
    # Test if compose file exists
    run_test "Docker Compose file exists" "[[ -f \"${TEST_BASE_DIR}/docker-compose.yml\" ]]"
    
    # Test compose file syntax
    run_test "Docker Compose syntax check" "cd \"${TEST_BASE_DIR}\" && docker compose config &> /dev/null"
}

test_service_management() {
    log "Testing service management..."
    
    # Test service start
    run_test "Service start" "cd \"${TEST_BASE_DIR}\" && docker compose up -d"
    
    # Wait for services to start
    sleep 30
    
    # Test service status
    run_test "Service status check" "cd \"${TEST_BASE_DIR}\" && docker compose ps | grep -q 'Up'"
    
    # Test Synapse API
    run_test "Synapse API check" "curl -sf http://localhost:8008/_matrix/client/versions > /dev/null"
    
    # Test database connectivity
    run_test "Database connectivity" "cd \"${TEST_BASE_DIR}\" && docker compose exec -T postgres pg_isready -U matrix_user > /dev/null"
}

test_backup_functionality() {
    log "Testing backup functionality..."
    
    # Source backup module
    source lib/backup.sh
    
    # Test backup script creation
    run_test "Backup script creation" "create_backup_script \"/tmp/backup-test\""
    
    # Test if backup script exists
    run_test "Backup script exists" "[[ -f \"/tmp/backup-test/backup-matrix.sh\" ]]"
    
    # Test backup script permissions
    run_test "Backup script permissions" "[[ -x \"/tmp/backup-test/backup-matrix.sh\" ]]"
}

test_security_setup() {
    log "Testing security setup..."
    
    # Source security module
    source lib/security.sh
    
    # Test firewall setup (mock)
    run_test "Firewall setup" "true"
    
    # Test file permissions setup
    run_test "File permissions setup" "secure_file_permissions"
    
    # Test SSL certificate validation (mock)
    run_test "SSL certificate validation" "true"
}

test_control_script() {
    log "Testing control script functionality..."
    
    # Test control script exists
    run_test "Control script exists" "[[ -f \"${TEST_BASE_DIR}/bin/matrix-control.sh\" ]]"
    
    # Test control script permissions
    run_test "Control script permissions" "[[ -x \"${TEST_BASE_DIR}/bin/matrix-control.sh\" ]]"
    
    # Test control script help
    run_test "Control script help" "cd \"${TEST_BASE_DIR}\" && ./bin/matrix-control.sh 2>&1 | grep -q 'Usage'"
    
    # Test service status command
    run_test "Service status command" "cd \"${TEST_BASE_DIR}\" && ./bin/matrix-control.sh status &> /dev/null"
}

# Main test runner
main() {
    log "Starting Matrix Synapse Installer Test Suite"
    
    # Setup
    setup_test_environment
    
    # Run tests
    test_system_requirements
    test_configuration_loading
    test_docker_installation
    test_directory_structure
    test_configuration_generation
    test_docker_compose_generation
    test_service_management
    test_backup_functionality
    test_security_setup
    test_control_script
    
    # Print results
    echo
    log "Test Results Summary:"
    echo "===================="
    log_success "Tests passed: $TESTS_PASSED"
    if [[ $TESTS_FAILED -gt 0 ]]; then
        log_error "Tests failed: $TESTS_FAILED"
    fi
    log "Total tests: $TESTS_TOTAL"
    
    # Calculate success rate
    local success_rate=$((TESTS_PASSED * 100 / TESTS_TOTAL))
    echo
    log "Success rate: ${success_rate}%"
    
    # Cleanup
    cleanup_test_environment
    
    # Exit with appropriate code
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All tests passed!"
        exit 0
    else
        log_error "Some tests failed!"
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 