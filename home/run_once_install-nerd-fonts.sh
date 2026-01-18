#!/bin/sh

# Install JetBrains Mono Nerd Font
# This script runs once to install the font on Linux systems

set -e

case "$(uname -s)" in
  Linux*)
    echo "Installing JetBrains Mono Nerd Font on Linux..."
    
    FONT_DIR="$HOME/.local/share/fonts"
    FONT_NAME="JetBrainsMono"
    FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/JetBrainsMono.zip"
    
    # Create font directory if it doesn't exist
    mkdir -p "$FONT_DIR"
    
    # Check if font is already installed
    if fc-list | grep -qi "JetBrainsMono"; then
      echo "JetBrains Mono Nerd Font already installed, skipping..."
      exit 0
    fi
    
    echo "Downloading JetBrains Mono Nerd Font..."
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR" || exit 1
    
    curl -fLo "${FONT_NAME}.zip" "$FONT_URL"
    
    echo "Extracting fonts..."
    unzip -q "${FONT_NAME}.zip" -d "$FONT_NAME"
    
    echo "Installing fonts..."
    find "$FONT_NAME" -name "*.ttf" -exec cp {} "$FONT_DIR" \;
    
    echo "Updating font cache..."
    fc-cache -fv "$FONT_DIR"
    
    # Cleanup
    cd - > /dev/null || exit 1
    rm -rf "$TEMP_DIR"
    
    echo "JetBrains Mono Nerd Font installed successfully!"
    ;;
  Darwin*)
    echo "macOS detected - font should be installed via Brewfile"
    if ! brew list --cask font-jetbrains-mono-nerd-font >/dev/null 2>&1; then
      echo "Installing JetBrains Mono Nerd Font via Homebrew..."
      brew install --cask font-jetbrains-mono-nerd-font || echo "Warning: Font installation failed"
    else
      echo "JetBrains Mono Nerd Font already installed"
    fi
    ;;
  *)
    echo "Unsupported OS for automatic font installation"
    ;;
esac
