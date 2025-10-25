# Local Testing Environment Setup with UTM

This guide will walk you through setting up a local testing environment for your
dotfiles repository using [UTM](https://mac.getutm.app/), a free and open-source
virtualization software for macOS.

## Why Use UTM?

UTM allows you to create and run virtual machines (VMs) for various operating
systems, including Debian/Ubuntu and other Linux distributions. This is an
excellent way to test your dotfiles in a clean, isolated environment without
affecting your main system.

Key benefits for testing dotfiles:

- **Isolation**: Test your installation script without cluttering your main
  machine.
- **Snapshots**: Take a snapshot of a clean OS installation and revert to it for
  repeated tests.
- **Cross-platform Testing**: Easily test on different operating systems and
  versions.

## 1. Download and Install UTM

You can download UTM from the official website: [mac.getutm.app](https://mac.getutm.app/).

It is available as a direct download from the website or through the Mac App
Store. Alternatively, you can install it using [Homebrew](https://brew.sh/):

```sh
brew install --cask utm
```

## 2. Create a New Virtual Machine

1. **Download an OS Image**: You will need an installation image for the
   operating system you want to test on. For example, you can download the
   latest Ubuntu Desktop image from the
   [Ubuntu website](https://ubuntu.com/download/desktop).

2. **Open UTM and Create a New VM**:

   - Click the "+" button to create a new virtual machine.
   - Select "Virtualize".
   - Select "Linux".
   - Click "Browse" and select the OS image you downloaded.
   - Follow the on-screen instructions to configure the VM. The default
     settings are usually sufficient for testing dotfiles.

## 3. Configure the VM for Testing

Once the VM is created and the OS is installed, it is recommended to perform
the following steps:

1. **Install `git`**: Open a terminal in the VM and install `git` if it is not
   already installed.

   ```sh
   sudo apt update
   sudo apt install git
   ```

2. **Take a Snapshot**: Before you start testing, it is a good idea to take a
   snapshot of the clean OS installation. This will allow you to quickly revert
   to this state for repeated tests.

   - In the UTM main window, select your VM.
   - Click the "Snapshots" button (looks like a clock with a circular arrow).
   - Click the "+" button to create a new snapshot. Give it a descriptive name
     like "Clean Install".

## 4. Test Your Dotfiles

1. **Clone Your Repository**: In the VM's terminal, clone your dotfiles
   repository.

   ```sh
   git clone <your-git-repository-url>
   ```

2. **Run the Installation Script**: Navigate to the repository directory and run
   your installation script.

   ```sh
   cd <your-repository-directory>
   sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply
   ```

3. **Verify the Installation**: Check that your shell is configured correctly,
   your theme is applied, and your secrets are managed as expected.

## 5. Reverting to a Clean State

After you have finished testing, you can easily revert the VM to its clean
state.

1. **Shut down the VM**.
2. **Open the Snapshots**: In the UTM main window, select your VM and open the
   snapshots.
3. **Select the "Clean Install" snapshot** and click the "Restore" button.

Your VM is now back to its original clean state, ready for another round of
testing.
