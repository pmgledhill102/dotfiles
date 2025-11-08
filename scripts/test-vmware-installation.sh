#!/bin/bash
# Test script for dotfiles installation in VMware Fusion VMs
# This script should be run inside the VM after installation

set -e

echo "================================"
echo "Dotfiles Installation Test"
echo "================================"
echo ""

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

FAILED_TESTS=0
PASSED_TESTS=0

test_command() {
    local cmd=$1
    local description=$2
    
    if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $description: $cmd is installed"
        ((PASSED_TESTS++))
    else
        echo -e "${RED}✗${NC} $description: $cmd is NOT installed"
        ((FAILED_TESTS++))
    fi
}

test_file() {
    local file=$1
    local description=$2
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $description: $file exists"
        ((PASSED_TESTS++))
    else
        echo -e "${RED}✗${NC} $description: $file does NOT exist"
        ((FAILED_TESTS++))
    fi
}

test_directory() {
    local dir=$1
    local description=$2
    
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓${NC} $description: $dir exists"
        ((PASSED_TESTS++))
    else
        echo -e "${RED}✗${NC} $description: $dir does NOT exist"
        ((FAILED_TESTS++))
    fi
}

echo "Testing installed tools..."
echo "----------------------------"
test_command "zsh" "Zsh shell"
test_command "chezmoi" "Chezmoi"
test_command "starship" "Starship prompt"
test_command "age" "Age encryption"

# Test for Ghostty only on macOS
if [[ "$(uname -s)" == "Darwin" ]]; then
    test_command "ghostty" "Ghostty terminal"
fi

echo ""
echo "Testing Oh My Zsh..."
echo "----------------------------"
test_directory "$HOME/.oh-my-zsh" "Oh My Zsh directory"

echo ""
echo "Testing configuration files..."
echo "----------------------------"
test_file "$HOME/.zshrc" ".zshrc configuration"
test_file "$HOME/.config/starship.toml" "Starship configuration"

# Test Ghostty config only on macOS
if [[ "$(uname -s)" == "Darwin" ]]; then
    test_file "$HOME/.config/ghostty/config" "Ghostty configuration"
fi

echo ""
echo "Testing Starship prompt..."
echo "----------------------------"
if grep -q "starship init zsh" "$HOME/.zshrc" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Starship initialization found in .zshrc"
    ((PASSED_TESTS++))
else
    echo -e "${RED}✗${NC} Starship initialization NOT found in .zshrc"
    ((FAILED_TESTS++))
fi

echo ""
echo "================================"
echo "Test Summary"
echo "================================"
echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
echo -e "${RED}Failed: $FAILED_TESTS${NC}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. Please review the output above.${NC}"
    exit 1
fi
