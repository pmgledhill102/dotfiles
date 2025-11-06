#!/bin/bash

# This script automates the testing of the dotfiles repository on a Linux VM.

# --- Configuration ---
VM_NAME="Linux"
SNAPSHOT_NAME="clean-linux"
GIT_REPO_URL="https://github.com/pmgledhill102/dotfiles.git"
VM_PATH="$HOME/Library/Containers/com.utmapp.UTM/Data/Documents/${VM_NAME}.utm"
DISK_IMAGE_PATH="${VM_PATH}/Data/90137F59-D73B-4655-9F64-F0DE48B2F808.qcow2"

# --- Functions ---

# Function to log messages
log() {
  echo "[INFO] $1"
}

# Function to log errors
error() {
  echo "[ERROR] $1" >&2
  exit 1
}

# --- Main Script ---

# 0. Check for prerequisites
if ! command -v utmctl >/dev/null 2>&1; then
  error "utmctl is not installed. Please run 'brew install utmctl'."
fi

if [ "$GIT_REPO_URL" = "YOUR_GIT_REPOSITORY_URL" ]; then
  error "Please edit the script and replace 'YOUR_GIT_REPOSITORY_URL' with your actual Git repository URL."
fi

# 1. Revert to the clean snapshot
log "Reverting to snapshot: ${SNAPSHOT_NAME}..."
qemu-img snapshot -a "${SNAPSHOT_NAME}" "${DISK_IMAGE_PATH}" || error "Failed to revert to snapshot."

# 2. Start the VM
log "Starting VM: ${VM_NAME}..."
utmctl start "${VM_NAME}" || error "Failed to start VM."

log "VM started. Waiting for it to boot and network to be ready..."
# Wait for the VM to boot. This is a simple sleep, but it's often sufficient.
# A more robust solution might poll for network or SSH access.
sleep 30

# 3. Run the installation script inside the VM
# sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --branch 001-dotfiles-setup https://github.com/pmgledhill102/dotfiles.git
log "Running dotfiles installation script inside the VM..."
INSTALL_COMMAND="sh -c \"\$(curl -fsLS get.chezmoi.io)\" -- init --apply --branch 001-dotfiles-setup ${GIT_REPO_URL}"

log "Running one-liner chezmoi installation..."
if ! utmctl exec "${VM_NAME}" --cmd /bin/sh -c "${INSTALL_COMMAND}"
then
  error "Installation script failed. Check the output above for details."
fi

log "Test complete. You can now connect to the VM to verify the setup or stop it with 'utmctl stop ${VM_NAME}'."

exit 0
