#!/bin/bash
# Post-installation validation script for dotfiles
# Validates that the installation is working correctly

echo "================================"
echo "Post-Installation Validation"
echo "================================"
echo ""

# Ensure Homebrew is in PATH for macOS
if [[ "$(uname -s)" == "Darwin" ]]; then
    if [ -d "/opt/homebrew/bin" ]; then
        export PATH="/opt/homebrew/bin:$PATH"
    elif [ -d "/usr/local/bin" ]; then
        export PATH="/usr/local/bin:$PATH"
    fi
fi

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

FAILED_TESTS=0
PASSED_TESTS=0
WARNED_TESTS=0

validate_test() {
    local description=$1
    local test_command=$2
    local output
    
    # Run the test command and capture both stdout and stderr
    # We use eval to execute the command string properly
    output=$(eval "$test_command" 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $description"
        ((PASSED_TESTS++))
        return 0
    else
        echo -e "${RED}✗${NC} $description"
        # Only print output if there is any, to avoid empty lines
        if [ -n "$output" ]; then
             echo -e "${RED}  Error details: $output${NC}"
        fi
        ((FAILED_TESTS++))
        return 1
    fi
}

echo "Validating shell configuration..."
echo "-----------------------------------"
# Check using getent/dscl if possible, fallback to ENV check but warn it might be stale
if command -v getent >/dev/null 2>&1; then
    USER_SHELL=$(getent passwd "$USER" | cut -d: -f7)
    echo "Detected shell via getent: $USER_SHELL"
    validate_test "Zsh is the configured shell (getent)" "[ \"$USER_SHELL\" = \"$(command -v zsh)\" ] || [ \"$USER_SHELL\" = \"/bin/zsh\" ] || [ \"$USER_SHELL\" = \"/usr/bin/zsh\" ] || [ \"$USER_SHELL\" = \"/usr/local/bin/zsh\" ] || [ \"$USER_SHELL\" = \"/opt/homebrew/bin/zsh\" ]"
elif command -v dscl >/dev/null 2>&1; then
    USER_SHELL=$(dscl . -read /Users/"$USER" UserShell | awk '{print $2}')
    echo "Detected shell via dscl: $USER_SHELL"
    validate_test "Zsh is the configured shell (dscl)" "[ \"$USER_SHELL\" = \"$(command -v zsh)\" ] || [ \"$USER_SHELL\" = \"/bin/zsh\" ] || [ \"$USER_SHELL\" = \"/usr/bin/zsh\" ] || [ \"$USER_SHELL\" = \"/usr/local/bin/zsh\" ] || [ \"$USER_SHELL\" = \"/opt/homebrew/bin/zsh\" ]"
else
    validate_test "Zsh is the default shell (\$SHELL)" "[ \"\$SHELL\" = \"/bin/zsh\" ] || [ \"\$SHELL\" = \"/usr/bin/zsh\" ] || [ \"\$SHELL\" = \"$(command -v zsh)\" ] || [ \"\$SHELL\" = \"/usr/local/bin/zsh\" ] || [ \"\$SHELL\" = \"/opt/homebrew/bin/zsh\" ]"
fi

validate_test "Oh My Zsh is loaded" "[ -n \"\$ZSH\" ] || [ -d \"\$HOME/.oh-my-zsh\" ]"
# Note: $ZSH env var is loaded effectively when .zshrc is sourced. 
# validation script runs in bash, so $ZSH won't be set from the current shell environment
# unless we source .zshrc (which we can't easily do from bash).
# So checking directory existence is a safer static check for installation.

echo ""
echo "Validating Starship prompt..."
echo "-----------------------------------"
validate_test "Starship is in PATH" "command -v starship"
validate_test "Starship config exists" "[ -f \"\$HOME/.config/starship.toml\" ]"
validate_test "Starship version can be queried" "starship --version"

if [[ "$(uname -s)" == "Darwin" ]]; then
    # Check for the macOS symbol () which is specific to our custom config
    validate_test "Starship prompt uses custom config" "starship prompt | grep -q ''"
elif [[ "$(uname -s)" == "Linux" ]]; then
    # Check for Ubuntu () or generic Linux () symbol
    validate_test "Starship prompt uses custom config" "starship prompt | grep -q -E '|'"
fi

# Verify Starship is actually loaded in the Zsh prompt
PROMPT_CHECK_FILE="/tmp/zsh_prompt_check_$(date +%s)"
if [[ "$(uname -s)" == "Darwin" ]]; then
    # macOS syntax: script [file] [command]
    # We clear VSCODE_COPILOT_CHAT_TERMINAL to ensure starship loads even if running from VS Code
    script -q "$PROMPT_CHECK_FILE" env VSCODE_COPILOT_CHAT_TERMINAL="" zsh -ic "echo \"PROMPT=\$PROMPT\"" >/dev/null 2>&1
elif [[ "$(uname -s)" == "Linux" ]]; then
    # Linux syntax: script -c [command] [file]
    script -q -c "env VSCODE_COPILOT_CHAT_TERMINAL='' zsh -ic 'echo \"PROMPT=\$PROMPT\"'" "$PROMPT_CHECK_FILE" >/dev/null 2>&1
fi

validate_test "Starship is hooked into Zsh PROMPT" "grep -F 'starship prompt' \"$PROMPT_CHECK_FILE\""
rm -f "$PROMPT_CHECK_FILE"

# Additional prompt functionality tests (T024)
echo ""
echo "Validating prompt theme functionality..."
echo "-----------------------------------"

# Test that starship config contains expected customizations
validate_test "Starship config has directory customization" "grep -q 'directory' \$HOME/.config/starship.toml"
validate_test "Starship config has git_branch customization" "grep -q 'git_branch' \$HOME/.config/starship.toml"
validate_test "Starship config has character customization" "grep -q 'character' \$HOME/.config/starship.toml"

# Test prompt rendering with common scenarios
PROMPT_TEST_DIR="/tmp/starship_test_$(date +%s)"
mkdir -p "$PROMPT_TEST_DIR"
cd "$PROMPT_TEST_DIR" || exit 1

# Test basic directory prompt
validate_test "Prompt renders in non-git directory" "starship prompt --terminal-width=80 2>/dev/null | grep -q '.'"

# Test git directory prompt
if command -v git >/dev/null 2>&1; then
    git init >/dev/null 2>&1
    validate_test "Prompt renders in git repository" "starship prompt --terminal-width=80 2>/dev/null | grep -q '.'"
fi

cd - >/dev/null 2>&1 || exit 1
rm -rf "$PROMPT_TEST_DIR"

echo ""
echo "Validating Terminal capabilities..."
echo "-----------------------------------"
# Check if xterm-ghostty terminfo is available (important for SSH from Ghostty)
# We test this even if NOT currently running in Ghostty, as it's a system requirement 
# for seamless SSH access into this machine.
validate_test "xterm-ghostty terminfo is installed" "infocmp xterm-ghostty >/dev/null 2>&1"

if command -v pwsh >/dev/null 2>&1; then
    echo ""
    echo "Validating PowerShell configuration..."
    echo "-----------------------------------"
    PWSH_PROFILE="$HOME/.config/powershell/Microsoft.PowerShell_profile.ps1"
    validate_test "PowerShell profile exists" "[ -f \"$PWSH_PROFILE\" ]"
    if [ -f "$PWSH_PROFILE" ]; then
        validate_test "PowerShell profile uses Starship" "grep -q 'starship init powershell' \"$PWSH_PROFILE\""
    fi
    
    # Verify Starship loads in PowerShell by capturing the prompt output
    PWSH_CHECK_FILE="/tmp/pwsh_check_$(date +%s)"
    if [[ "$(uname -s)" == "Darwin" ]]; then
        script -q "$PWSH_CHECK_FILE" env VSCODE_COPILOT_CHAT_TERMINAL="" pwsh -Command "prompt" >/dev/null 2>&1
    elif [[ "$(uname -s)" == "Linux" ]]; then
        script -q -c "env VSCODE_COPILOT_CHAT_TERMINAL='' pwsh -Command 'prompt'" "$PWSH_CHECK_FILE" >/dev/null 2>&1
    fi
    
    if [[ "$(uname -s)" == "Darwin" ]]; then
         validate_test "PowerShell prompt renders Starship symbol" "grep -q '' \"$PWSH_CHECK_FILE\""
    elif [[ "$(uname -s)" == "Linux" ]]; then
         validate_test "PowerShell prompt renders Starship symbol" "grep -q -E '|' \"$PWSH_CHECK_FILE\""
    fi
    rm -f "$PWSH_CHECK_FILE"
fi



echo ""
echo "Validating tools..."
echo "-----------------------------------"
validate_test "Git is installed" "command -v git"
validate_test "Age is installed" "command -v age"

# Phase 9 tools
validate_test "Git config exists" "[ -f \"\$HOME/.gitconfig\" ]"
validate_test "Global gitignore exists" "[ -f \"\$HOME/.gitignore_global\" ]"
validate_test "Tmux config exists" "[ -f \"\$HOME/.tmux.conf\" ]"

# Check for tools that should be installed via Brewfile or apt packages
if command -v delta >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} git-delta is installed"
    ((PASSED_TESTS++))
    validate_test "Git is configured to use delta" "git config --get core.pager | grep -q delta"
else
    echo -e "${RED}✗${NC} git-delta is installed"
    ((FAILED_TESTS++))
fi

if command -v lazygit >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} lazygit is installed"
    ((PASSED_TESTS++))
    validate_test "Lazygit config exists" "[ -f \"\$HOME/.config/lazygit/config.yml\" ]"
else
    echo -e "${RED}✗${NC} lazygit is installed"
    ((FAILED_TESTS++))
fi

if command -v tmux >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} tmux is installed"
    ((PASSED_TESTS++))
else
    echo -e "${RED}✗${NC} tmux is installed"
    ((FAILED_TESTS++))
fi

if [[ "$(uname -s)" == "Darwin" ]]; then
   # Ghostty is only installed on macOS/Windows in this setup
   if command -v ghostty >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Ghostty is installed"
        ((PASSED_TESTS++))
   else
        # Ghostty might be a cask or app, command -v might not find it if not in path
        # But for this test, let's assume valid if strictly found or if strictly required.
        # Given it is installed via brew, it might be available.
        # However, checking for the app bundle might be safer if command missing.
        if [ -d "/Applications/Ghostty.app" ] || [ -d "$HOME/Applications/Ghostty.app" ]; then
             echo -e "${GREEN}✓${NC} Ghostty.app found"
             ((PASSED_TESTS++))
        else
             echo -e "${RED}✗${NC} Ghostty is installed"
             ((FAILED_TESTS++))
        fi
   fi
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
validate_test "Chezmoi source directory exists" "chezmoi source-path >/dev/null"
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
    validate_test "Brewfile exists" "[ -f \"\$HOME/Brewfile\" ]"
    
    # Check for Nerd Font installation (macOS only via Brewfile)
    # Font cask installs are flaky on GitHub Actions runners (headless, no GUI),
    # so downgrade to a warning in CI to avoid blocking the entire pipeline.
    if fc-list | grep -qi "JetBrainsMono Nerd"; then
        echo -e "${GREEN}✓${NC} JetBrains Mono Nerd Font is installed"
        ((PASSED_TESTS++))
    elif [ "${CI:-}" = "true" ]; then
        echo -e "${YELLOW}⚠${NC} JetBrains Mono Nerd Font not found (skipped in CI — font casks are unreliable on headless runners)"
        ((WARNED_TESTS++))
    else
        echo -e "${RED}✗${NC} JetBrains Mono Nerd Font is installed"
        ((FAILED_TESTS++))
    fi
fi

# Linux-specific validations
if [[ "$(uname -s)" == "Linux" ]]; then
    echo ""
    echo "Validating Linux-specific tools..."
    echo "-----------------------------------"
    validate_test "apt is available" "command -v apt-get"
    validate_test "Ubuntu package list exists" "[ -f \"\$HOME/.config/ubuntu_pkglist\" ]"
fi

# VS Code configuration validation (cross-platform)
echo ""
echo "Validating VS Code configuration..."
echo "-----------------------------------"
validate_test "VS Code settings exist" "[ -f \"\$HOME/.config/Code/User/settings.json\" ]"
validate_test "VS Code keybindings exist" "[ -f \"\$HOME/.config/Code/User/keybindings.json\" ]"

echo ""
echo "================================"
echo "Validation Summary"
echo "================================"
echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
if [ "$WARNED_TESTS" -gt 0 ]; then
    echo -e "${YELLOW}Warned: $WARNED_TESTS${NC}"
fi
echo -e "${RED}Failed: $FAILED_TESTS${NC}"
echo ""

# Save counts for CI summary if running in CI environment
echo "PASSED_TESTS=$PASSED_TESTS" > /tmp/validation_counts.txt
echo "FAILED_TESTS=$FAILED_TESTS" >> /tmp/validation_counts.txt
echo "WARNED_TESTS=$WARNED_TESTS" >> /tmp/validation_counts.txt
TOTAL_TESTS=$((PASSED_TESTS + FAILED_TESTS + WARNED_TESTS))
echo "TOTAL_TESTS=$TOTAL_TESTS" >> /tmp/validation_counts.txt

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}All validations passed! Your dotfiles are properly installed.${NC}"
    exit 0
else
    echo -e "${RED}Some validations failed. Please review the output above.${NC}"
    exit 1
fi
