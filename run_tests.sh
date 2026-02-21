#!/bin/bash

# Test Runner Script for Facett App
# This script runs different types of tests based on the environment and available hardware

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="GoProConfigurator"
SCHEME_NAME="GPControl"
SIMULATOR_NAME="iPhone 16"
DEVICE_ID="00008130-000578862861401C" # Kevin's iPhone

# Test types
TEST_TYPES=("unit" "ui" "integration" "device" "all")

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if device is connected
check_device_connected() {
    if xcrun devicectl list devices | grep -q "$DEVICE_ID"; then
        return 0
    else
        return 1
    fi
}

# Function to check if simulator is available
check_simulator_available() {
    if xcrun simctl list devices | grep -q "$SIMULATOR_NAME"; then
        return 0
    else
        return 1
    fi
}

# Function to run unit tests (no hardware required)
run_unit_tests() {
    print_status "Running unit tests..."

    # Build and run unit tests
    xcodebuild test \
        -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
        -only-testing:GoProConfiguratorTests/ParserTests \
        -only-testing:GoProConfiguratorTests/SettingsTests \
        | xcpretty

    if [ $? -eq 0 ]; then
        print_success "Unit tests passed!"
    else
        print_error "Unit tests failed!"
        exit 1
    fi
}

# Function to run UI tests (simulator)
run_ui_tests() {
    print_status "Running UI tests..."

    # Build and run UI tests
    xcodebuild test \
        -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
        -only-testing:GoProConfiguratorUITests/UIWorkflowTests \
        | xcpretty

    if [ $? -eq 0 ]; then
        print_success "UI tests passed!"
    else
        print_error "UI tests failed!"
        exit 1
    fi
}

# Function to run integration tests (simulator with mocked BLE)
run_integration_tests() {
    print_status "Running integration tests..."

    # Build and run integration tests
    xcodebuild test \
        -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
        -only-testing:GoProConfiguratorTests/BLETestStrategy \
        | xcpretty

    if [ $? -eq 0 ]; then
        print_success "Integration tests passed!"
    else
        print_error "Integration tests failed!"
        exit 1
    fi
}

# Function to run device tests (real device with BLE)
run_device_tests() {
    print_status "Running device tests..."

    if ! check_device_connected; then
        print_warning "Device not connected. Skipping device tests."
        return 0
    fi

    # Build and run device tests
    xcodebuild test \
        -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -destination "platform=iOS,id=$DEVICE_ID" \
        -only-testing:GoProConfiguratorTests/ManualTest \
        | xcpretty

    if [ $? -eq 0 ]; then
        print_success "Device tests passed!"
    else
        print_error "Device tests failed!"
        exit 1
    fi
}

# Function to run all tests
run_all_tests() {
    print_status "Running all tests..."

    # Run unit tests first
    run_unit_tests

    # Run UI tests
    run_ui_tests

    # Run integration tests
    run_integration_tests

    # Run device tests if device is available
    if check_device_connected; then
        run_device_tests
    else
        print_warning "Device not connected. Skipping device tests."
    fi

    print_success "All tests completed!"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [test_type]"
    echo ""
    echo "Test types:"
    echo "  unit        - Run unit tests (no hardware required)"
    echo "  ui          - Run UI tests (simulator required)"
    echo "  integration - Run integration tests (simulator with mocked BLE)"
    echo "  device      - Run device tests (real device with BLE)"
    echo "  all         - Run all tests"
    echo ""
    echo "Examples:"
    echo "  $0 unit"
    echo "  $0 ui"
    echo "  $0 device"
    echo "  $0 all"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."

    # Check if Xcode is installed
    if ! command -v xcodebuild &> /dev/null; then
        print_error "Xcode is not installed or not in PATH"
        exit 1
    fi

    # Check if project exists
    if [ ! -d "$PROJECT_NAME.xcodeproj" ]; then
        print_error "Project $PROJECT_NAME.xcodeproj not found"
        exit 1
    fi

    # Check if xcpretty is installed (optional)
    if ! command -v xcpretty &> /dev/null; then
        print_warning "xcpretty not found. Install with: gem install xcpretty"
        print_warning "Continuing without xcpretty..."
    fi

    print_success "Prerequisites check passed!"
}

# Function to setup test environment
setup_test_environment() {
    print_status "Setting up test environment..."

    # Clean build folder
    xcodebuild clean \
        -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -quiet

    # Boot simulator if needed
    if check_simulator_available; then
        xcrun simctl boot "$SIMULATOR_NAME" 2>/dev/null || true
    fi

    print_success "Test environment setup complete!"
}

# Main script logic
main() {
    local test_type="${1:-all}"

    # Validate test type
    if [[ ! " ${TEST_TYPES[@]} " =~ " ${test_type} " ]]; then
        print_error "Invalid test type: $test_type"
        show_usage
        exit 1
    fi

    print_status "Starting Facett app testing..."
    print_status "Test type: $test_type"

    # Check prerequisites
    check_prerequisites

    # Setup test environment
    setup_test_environment

    # Run tests based on type
    case $test_type in
        "unit")
            run_unit_tests
            ;;
        "ui")
            run_ui_tests
            ;;
        "integration")
            run_integration_tests
            ;;
        "device")
            run_device_tests
            ;;
        "all")
            run_all_tests
            ;;
    esac

    print_success "Testing completed successfully!"
}

# Handle command line arguments
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_usage
    exit 0
fi

# Run main function
main "$@"
