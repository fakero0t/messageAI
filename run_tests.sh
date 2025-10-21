#!/bin/bash

# run_tests.sh
# Helper script to run swift_demo unit tests

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCHEME="swift_demo"
DESTINATION="platform=iOS Simulator,name=iPhone 15"
PROJECT="swift_demo.xcodeproj"

echo -e "${YELLOW}🧪 swift_demo Test Runner${NC}\n"

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}❌ xcodebuild not found. Please install Xcode.${NC}"
    exit 1
fi

# Parse arguments
TEST_FILTER=""
COVERAGE=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--coverage)
            COVERAGE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -t|--test)
            TEST_FILTER="-only-testing:swift_demoTests/$2"
            shift
            shift
            ;;
        -h|--help)
            echo "Usage: ./run_tests.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -c, --coverage          Enable code coverage"
            echo "  -v, --verbose          Show detailed output"
            echo "  -t, --test CLASS       Run specific test class"
            echo "  -h, --help             Show this help message"
            echo ""
            echo "Examples:"
            echo "  ./run_tests.sh                           # Run all tests"
            echo "  ./run_tests.sh -c                        # Run with coverage"
            echo "  ./run_tests.sh -t RetryPolicyTests       # Run specific test class"
            echo "  ./run_tests.sh -t RetryPolicyTests/testDefaultRetryPolicyConfiguration  # Run specific test"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Build command
CMD="xcodebuild test -scheme $SCHEME -destination '$DESTINATION' -project $PROJECT"

if [ "$COVERAGE" = true ]; then
    CMD="$CMD -enableCodeCoverage YES"
fi

if [ -n "$TEST_FILTER" ]; then
    CMD="$CMD $TEST_FILTER"
fi

# Add quiet flag if not verbose
if [ "$VERBOSE" = false ]; then
    CMD="$CMD -quiet"
fi

echo -e "${YELLOW}📱 Simulator:${NC} iPhone 15"
if [ -n "$TEST_FILTER" ]; then
    echo -e "${YELLOW}🎯 Filter:${NC} $TEST_FILTER"
fi
if [ "$COVERAGE" = true ]; then
    echo -e "${YELLOW}📊 Coverage:${NC} Enabled"
fi
echo ""

# Run tests
echo -e "${YELLOW}▶️  Running tests...${NC}\n"

if eval $CMD; then
    echo -e "\n${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}❌ Tests failed!${NC}"
    exit 1
fi

