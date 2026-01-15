#!/bin/bash
# Post-installation validation script for dotfiles
# Validates that the installation is working correctly

set -e

echo "================================"
echo "Post-Installation Validation"
echo "================================"
echo ""

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

FAILED_TESTS=0
PASSED_TESTS=0

validate_test() {
    local description=$1
    local test_command=$2
    
    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $description"
        ((PASSED_TESTS++))
        return 0
    else
        echo -e "${RED}✗${NC} $description"
        ((FAILED_TESTS++))
        return 1
    fi
}

echo "Validating shell configuration..."
echo "-----------------------------------"
validate_test "Zsh is the default shell" "[ \"\$SHELL\" = \"/bin/zsh\" ] || [ \"\$SHELL\" = \"/usr/bin/zsh\" ]"
validate_test "Oh My Zsh is loaded" "[ -n \"\$ZSH\" ]"

echo ""
echo "Validating Starship prompt..."
echo "-----------------------------------"
validate_test "Starship is in PATH" "command -v starship"
validate_test "Starship config exists" "[ -f \"\$HOME/.config/starship.toml\" ]"
validate_test "Starship version can be queried" "starship --version"

echo ""
echo "Validating tools..."
echo "-----------------------------------"
validate_test "Git is installed" "command -v git"
validate_test "Age is installed" "command -v age"

if [[ "$(uname -s)" == "Darwin" ]]; then
   # Ghostty is only installed on macOS/Windows in this setup
    validate_test "Ghostty is installed" "command -v ghostty"
fi

echo ""
echo "Validating Zsh plugins..."
echo "-----------------------------------"
# Check custom plugins
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
validate_test "zsh-autosuggestions installed" "[ -d \"$ZSH_CUSTOM/plugins/zsh-autosuggestions\" ]"
validate_test "zsh-syntax-highlighting installed" "[ -d \"$ZSH_CUSTOM/plugins/zsh-syntax-highlighting\" ]"

echo ""
echo "Validating chezmoi..."
echo "-----------------------------------"
validate_test "Chezmoi is in PATH" "command -v chezmoi"
validate_test "Chezmoi source directory exists" "[ -d \"\$HOME/.local/share/chezmoi\" ]"
validate_test "Chezmoi can list managed files" "chezmoi managed"

echo ""
echo "Validating age encryption..."
echo "-----------------------------------"
validate_test "Age is in PATH" "command -v age"
validate_test "Age keygen is in PATH" "command -v age-keygen"

# macOS-specific validations
if [[ "$(uname -s)" == "Darwin" ]]; then
    echo ""
    echo "Validating macOS-specific tools..."
    echo "-----------------------------------"
    validate_test "Homebrew is in PATH" "command -v brew"
    validate_test "Ghostty is installed" "[ -d \"/Applications/Ghostty.app\" ] || command -v ghostty"
fi

# Linux-specific validations
if [[ "$(uname -s)" == "Linux" ]]; then
    echo ""
    echo "Validating Linux-specific tools..."
    echo "-----------------------------------"
    validate_test "apt is available" "command -v apt-get"
fi

echo ""
echo "================================"
echo "Validation Summary"
echo "================================"
echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
echo -e "${RED}Failed: $FAILED_TESTS${NC}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}All validations passed! Your dotfiles are properly installed.${NC}"
    exit 0
else
    echo -e "${RED}Some validations failed. Please review the output above.${NC}"
    exit 1
fi
