#!/bin/sh

# macOS System Defaults Configuration
# This script applies macOS system settings for improved developer experience
# Run once on initial setup

set -e

case "$(uname -s)" in
  Darwin*)
    echo "Applying macOS system defaults..."
    
    # Show hidden files in Finder
    defaults write com.apple.finder AppleShowAllFiles -bool true
    
    # Show all file extensions
    defaults write NSGlobalDomain AppleShowAllExtensions -bool true
    
    # Disable the "Are you sure you want to open this application?" dialog
    defaults write com.apple.LaunchServices LSQuarantine -bool false
    
    # Enable fast key repeat
    defaults write NSGlobalDomain KeyRepeat -int 2
    defaults write NSGlobalDomain InitialKeyRepeat -int 15
    
    # Expand save panel by default
    defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
    defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
    
    # Expand print panel by default
    defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
    defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true
    
    # Save to disk (not to iCloud) by default
    defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
    
    # Disable automatic period substitution
    defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
    
    # Disable smart quotes
    defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
    
    # Disable smart dashes
    defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
    
    # Show path bar in Finder
    defaults write com.apple.finder ShowPathbar -bool true
    
    # Show status bar in Finder
    defaults write com.apple.finder ShowStatusBar -bool true
    
    # Use list view by default in Finder
    defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
    
    # Avoid creating .DS_Store files on network or USB volumes
    defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
    defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
    
    # Show the ~/Library folder
    chflags nohidden ~/Library
    
    # Disable the sound effects on boot
    sudo nvram SystemAudioVolume=" "
    
    # Enable full keyboard access for all controls (e.g. enable Tab in modal dialogs)
    defaults write NSGlobalDomain AppleKeyboardUIMode -int 3
    
    # Restart affected applications
    echo "Restarting Finder to apply changes..."
    killall Finder || true
    
    echo "macOS defaults applied successfully!"
    echo "Note: Some changes may require a logout/restart to take full effect."
    ;;
  *)
    echo "Not macOS - skipping macOS defaults"
    ;;
esac
