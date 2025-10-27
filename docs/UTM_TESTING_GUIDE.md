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

Once the VM is created and the OS is installed, it is recommended to install `git` if it is not already installed.

Open a terminal in the VM and run:

```sh
sudo apt update
sudo apt install git
```

## 4. Taking and Restoring Snapshots with `qemu-img`

To repeatedly test your dotfiles on a clean system, you can take a snapshot of the initial state and revert to it. You can manage snapshots using the `qemu-img` command-line tool.

### Finding the Disk Image

1.  **Shut down your VM.** It's crucial to not have the VM running when you manipulate snapshots from the command line.
2.  In UTM, right-click your VM and select "Show in Finder".
3.  Right-click the `.utm` file and choose "Show Package Contents".
4.  Navigate into the `Images/` directory. You'll find the main disk image, usually named `data.qcow2`. This is the file you'll be working with.

### Installing `qemu-img`

If you don't have `qemu-img` available in your terminal, you can install it via Homebrew:

```sh
brew install qemu
```

### Managing Snapshots

Here are the essential `qemu-img` commands for snapshot management. You'll need to provide the full path to the `data.qcow2` file you located earlier.

-   **To create a snapshot:**

    Before you start testing, create a snapshot of the clean OS installation. Give it a descriptive name like "Clean Install".

    ```sh
    qemu-img snapshot -c <snapshot_name> /path/to/your/vm.utm/Images/data.qcow2
    ```
    *Example:*
    ```sh
    qemu-img snapshot -c clean-install "/Users/paul/Library/Containers/com.utmapp.UTM/Data/Documents/Debian.utm/Images/data.qcow2"
    ```

-   **To list all snapshots:**

    ```sh
    qemu-img snapshot -l /path/to/your/vm.utm/Images/data.qcow2
    ```

-   **To revert to a snapshot:**

    After you have finished testing, you can revert the VM to its clean state.

    ```sh
    qemu-img snapshot -a <snapshot_name> /path/to/your/vm.utm/Images/data.qcow2
    ```

-   **To delete a snapshot:**

    ```sh
    qemu-img snapshot -d <snapshot_name> /path/to/your/vm.utm/Images/data.qcow2
    ```

Using `qemu-img` provides a powerful way to manage your testing environments, especially when you want to script the process of reverting to a clean state.

## 5. Test Your Dotfiles

Now you are ready to test your dotfiles.

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

After testing, you can revert to the clean snapshot using the `qemu-img` command shown above and run your tests again.
