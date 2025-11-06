# Local Testing Environment Setup with VMware Fusion

This guide will walk you through setting up a local testing environment for your
dotfiles repository using [VMware Fusion Player](https://www.vmware.com/products/fusion.html),
which is free for personal use.

## Why Use VMware Fusion?

VMware Fusion allows you to create and run virtual machines (VMs) for various
operating systems, including Debian/Ubuntu and other Linux distributions. This
is an excellent way to test your dotfiles in a clean, isolated environment
without affecting your main system.

Key benefits for testing dotfiles:

- **Isolation**: Test your installation script without cluttering your main
  machine.
- **Snapshots**: Take a snapshot of a clean OS installation and revert to it
  for repeated tests.
- **Cross-platform Testing**: Easily test on different operating systems and
  versions.
- **User-Friendly Interface**: VMware Fusion provides a more polished and stable
  user experience compared to some open-source alternatives.

## 1. Download and Install VMware Fusion Player

You can download VMware Fusion Player for free for personal use from the
official VMware website. You will need to create a free account to get a
license key.

1. Go to the [VMware Fusion download page](https://www.vmware.com/go/downloadfusion).
2. Register for a personal use license.
3. Download and install the application.

## 2. Create a New Virtual Machine

1. **Download an OS Image**: You will need an installation image for the
   operating system you want to test on. For example, you can download the
   latest Ubuntu Desktop image from the
   [Ubuntu website](https://ubuntu.com/download/desktop).

2. **Open VMware Fusion and Create a New VM**:
   - Drag and drop the downloaded ISO file into the "Install from disc or
     image" window.
   - Follow the on-screen instructions, using "Easy Install" to automatically
     set up your user account and password.
   - Once the OS is installed, VMware Tools should be installed
     automatically, which provides better integration between the host and
     guest OS.

## 3. Configure the VM for Testing

Once the VM is created and the OS is installed, it is recommended to install
`git` if it is not already installed.

Open a terminal in the VM and run:

```sh
sudo apt update
sudo apt install git
```

## 4. Enable Easy SSH Access (Optional)

For easier access to your VM from your host machine's terminal, you can install
the `avahi-daemon` service on the Ubuntu VM. This advertises the VM on your
local network using mDNS/Bonjour, allowing you to SSH in using a `.local`
hostname instead of an IP address.

1. **Install Avahi on the VM**:

    ```sh
    sudo apt update
    sudo apt install avahi-daemon
    ```

2. **Connect via SSH**:

    You can now SSH into your VM from your Mac's terminal. The default hostname
    is typically `ubuntu.local`. Replace `your-vm-user` with the username you
    created during the VM setup.

    ```sh
    ssh your-vm-user@ubuntu.local
    ```

## 5. Taking and Restoring Snapshots

To repeatedly test your dotfiles on a clean system, you can take a snapshot
of the initial state and revert to it. VMware Fusion has a user-friendly
snapshot manager built into the GUI.

### Managing Snapshots

- **To create a snapshot:**
  1. With the VM running or shut down, go to the `Virtual Machine` >
     `Snapshots` menu.
  2. Select `Take Snapshot...`.
  3. Give it a descriptive name like "Clean Install with Git+Avahi" and click
     `Take`.

- **To revert to a snapshot:**
  1. Go to `Virtual Machine` > `Snapshots`.
  2. Click on the snapshot you want to restore.
  3. Click `Restore`.

- **To delete a snapshot:**
  1. Go to `Virtual Machine` > `Snapshots` > `Snapshot Manager...`.
  2. Select the snapshot you want to delete and click `Delete`.

## 6. Test Your Dotfiles

Now you are ready to test your dotfiles.

1. **Revert to Snapshot**: Before each test run, ensure you revert to your
   "Clean Install with Git+Avahi" snapshot to start from a known-good state.

2. **Run the Installation Script**: Open a terminal in the VM and run the
   one-liner installation command:

   ```sh
   sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply \
     --branch 001-dotfiles-setup \
     https://github.com/pmgledhill102/dotfiles.git
   ```

3. **Enter Passphrase**: When prompted, enter the passphrase for your `age`
   encrypted secrets.

4. **Verify the Installation**: Check that your shell is configured correctly,
   your theme is applied, and your secrets are managed as expected.

After testing, you can shut down the VM and revert to the clean snapshot again
for the next test run.
