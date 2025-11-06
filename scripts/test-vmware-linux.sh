#!/bin/bash

# This script automates the process of testing the dotfiles in a clean
# VMware Fusion virtual machine. It reverts the VM to a clean snapshot
# and then starts it in headless mode.

# --- Configuration ---
# Path to the vmrun utility
VMRUN="/Applications/VMware Fusion.app/Contents/Public/vmrun"

# Path to the .vmx file of the virtual machine
VMX_PATH="/Users/paul/Virtual Machines.localized/Ubuntu 64-bit Arm.vmwarevm/Ubuntu 64-bit Arm.vmx"

# Name of the snapshot to revert to
SNAPSHOT_NAME="Clean"

# --- Script ---

echo "Reverting to snapshot: '$SNAPSHOT_NAME'..."
"$VMRUN" revertToSnapshot "$VMX_PATH" "$SNAPSHOT_NAME"

if [ $? -ne 0 ]; then
  echo "Error: Failed to revert to snapshot. Please check the VM path and snapshot name."
  exit 1
fi

echo "Starting the virtual machine in headless mode..."
"$VMRUN" start "$VMX_PATH" nogui

if [ $? -ne 0 ]; then
  echo "Error: Failed to start the virtual machine."
  exit 1
fi

echo "VM started successfully."
echo "You can now SSH into the VM using: ssh your-vm-user@ubuntu.local"
echo "Or run the chezmoi installation command directly."
