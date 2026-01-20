# Testing Procedures

This document describes the testing procedures and automation for the dotfiles repository.

## Overview

The dotfiles repository includes comprehensive automated testing to ensure reliable installation and configuration across all supported platforms:

- **macOS** (latest)
- **Linux** (Ubuntu/Debian)
- **Windows** (latest)
- **WSL** (Windows Subsystem for Linux)

## Automated Testing (CI/CD)

### GitHub Actions Workflow

All changes are automatically tested via GitHub Actions. The workflow includes:

1. **Linting and Static Analysis**
   - ShellCheck for shell scripts
   - Markdown linting for documentation
   - GitHub Actions workflow validation

2. **Multi-Platform Installation Testing**
   - Tests run on Ubuntu, macOS, and Windows
   - Complete installation from scratch
   - Post-installation validation
   - Performance benchmarking

3. **Validation**
   - Tool availability checks
   - Configuration file validation
   - Shell and prompt functionality tests
   - Font installation verification
   - Platform-specific settings validation

### Viewing Test Results

1. Navigate to the [Actions tab](https://github.com/pmgledhill102/dotfiles/actions) in the repository
2. Click on a workflow run to see details
3. Review the job summary for quick metrics:
   - Installation status
   - Tests passed/failed
   - Disk space overhead
   - Installation time

## Local Testing

### Running Validation Scripts

#### Unix (macOS/Linux)

```bash
# Run the validation script
chmod +x scripts/validate-installation.sh
./scripts/validate-installation.sh
```

The script validates:

- Shell configuration (Zsh, Oh My Zsh)
- Starship prompt installation and configuration
- Theme and prompt functionality
- Tool availability (git, age, chezmoi, etc.)
- Configuration files (.gitconfig, .tmux.conf, etc.)
- Platform-specific tools (Homebrew on macOS, apt on Linux)
- VS Code configuration
- Font installation

#### Windows

```powershell
# Run the Windows validation script
& scripts/validate-installation-windows.ps1

# For verbose output
& scripts/validate-installation-windows.ps1 -Verbose
```

The script validates:

- PowerShell profile and configuration
- Starship prompt installation and configuration
- Windows Terminal settings
- Tool availability (git, age, chezmoi, pwsh, etc.)
- Registry settings (Long Paths, Developer Mode)
- Environment variables
- Font installation
- Configuration files

### Manual Testing Procedures

#### Test on a Clean System

The most reliable way to test is on a fresh system:

1. **Using Virtual Machines**
   - Create a VM with your target OS
   - Run the installation command
   - Verify all features work as expected

2. **Using Containers** (Linux only)

   ```bash
   docker run -it --rm ubuntu:latest bash
   # Run installation commands
   ```

3. **Using GitHub Codespaces**
   - Create a Codespace from the repository
   - Run `chezmoi init --apply --source .`
   - Test the configuration

#### Test Specific Features

1. **Shell Configuration**

   ```bash
   # Start a new shell session
   zsh  # or pwsh on Windows
   
   # Verify prompt appears correctly
   # Try tab completion
   # Test aliases (gs, ga, etc.)
   ```

2. **Git Configuration**

   ```bash
   # Check git config
   git config --list
   
   # Test delta (if installed)
   git diff
   ```

3. **Starship Prompt**

   ```bash
   # Check version
   starship --version
   
   # Test in different contexts
   cd ~/  # Should show home directory icon
   mkdir test-repo && cd test-repo
   git init  # Should show git branch
   ```

4. **Chezmoi Operations**

   ```bash
   # Check status
   chezmoi status
   
   # List managed files
   chezmoi managed
   
   # Test update workflow
   # Make a change to a file
   chezmoi add ~/.zshrc  # Add changes
   chezmoi diff  # Review changes
   chezmoi apply  # Apply changes
   ```

## Testing New Changes

### Before Submitting a PR

1. **Run Local Validation**

   ```bash
   # Unix
   ./scripts/validate-installation.sh
   
   # Windows
   pwsh -File scripts/validate-installation-windows.ps1
   ```

2. **Check Linting**

   ```bash
   # Install shellcheck (if not already installed)
   # macOS: brew install shellcheck
   # Ubuntu: sudo apt-get install shellcheck
   # Windows: winget install koalaman.shellcheck
   
   # Run shellcheck on modified scripts
   shellcheck scripts/*.sh home/*.sh.tmpl
   ```

3. **Test on Target Platform**

   - If modifying macOS-specific code, test on macOS
   - If modifying Linux-specific code, test on Ubuntu/Debian
   - If modifying Windows-specific code, test on Windows

### PR Testing

When you open a PR:

1. GitHub Actions automatically runs the full test suite
2. Review the workflow results in the PR checks
3. Fix any failures before merging

## Test Coverage

### Current Test Coverage

- ✅ Shell configuration (Zsh, PowerShell)
- ✅ Prompt configuration (Starship)
- ✅ Theme and prompt functionality
- ✅ Tool installation verification
- ✅ Configuration file presence
- ✅ Platform-specific settings
- ✅ Git configuration
- ✅ VS Code settings
- ✅ Font installation
- ✅ Environment variables
- ✅ Registry settings (Windows)

### Known Limitations

- Terminal emulator testing is limited (Ghostty on macOS, Windows Terminal on Windows)
- Interactive features (e.g., zsh-autosuggestions behavior) are not fully tested
- SSH and remote terminal scenarios require manual testing
- WSL-specific features require manual testing on Windows with WSL installed

## Performance Benchmarks

The CI pipeline tracks:

- **Installation Time**: Total time for `chezmoi init --apply`
- **Disk Space Overhead**: Additional disk space used by dotfiles and tools

Typical performance metrics:

- **macOS**: ~5-10 minutes (includes Homebrew package installation)
- **Linux**: ~3-5 minutes (includes apt packages)
- **Windows**: ~10-15 minutes (includes winget package installation)

## Troubleshooting Test Failures

### Common Issues

1. **Network Timeouts**
   - CI runners may experience transient network issues
   - Re-run failed jobs

2. **Package Installation Failures**
   - Some packages may be temporarily unavailable
   - Check if the package is still available in the repository

3. **Font Installation Failures**
   - Font installation is optional and may fail on some systems
   - This should not block the installation

4. **Permission Issues**
   - Some operations require sudo/admin privileges
   - Ensure scripts handle privilege escalation correctly

### Debugging Failed Tests

1. **Review Logs**
   - Click on the failed job in GitHub Actions
   - Expand the failing step
   - Review the detailed output

2. **Reproduce Locally**
   - Try to reproduce the issue on a similar system
   - Use the same OS version as the CI runner

3. **Add Debugging Output**
   - Add `set -x` to shell scripts for verbose output
   - Add `$VerbosePreference = "Continue"` to PowerShell scripts
   - Set `RUNNER_DEBUG=1` environment variable in CI

## Adding New Tests

### Adding Validation Tests

1. **For Unix (scripts/validate-installation.sh)**

   ```bash
   # Add a new validation test
   validate_test "Description of test" "test_command"
   ```

2. **For Windows (scripts/validate-installation-windows.ps1)**

   ```powershell
   # Add a new validation test
   Test-Validation "Description of test" {
       # Test logic here
       Test-Path $somePath
   }
   ```

### Adding CI Tests

Edit `.github/workflows/ci.yml` to add new test steps:

```yaml
- name: My New Test
  run: |
    # Test commands here
```

## Best Practices

1. **Test on Clean Systems**: Always test major changes on a fresh installation
2. **Test All Platforms**: Test changes on all affected platforms
3. **Use Validation Scripts**: Run validation scripts after installation
4. **Check CI Results**: Always review CI results before merging
5. **Document Changes**: Update documentation when adding new features
6. **Keep Tests Fast**: Optimize tests to run quickly without sacrificing coverage

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [ShellCheck](https://www.shellcheck.net/)
- [Chezmoi Testing Guide](https://www.chezmoi.io/user-guide/test-your-dotfiles-with-github-actions/)
- [PowerShell Testing Best Practices](https://learn.microsoft.com/en-us/powershell/scripting/dev-cross-plat/performance/script-authoring-considerations)

## Support

If you encounter testing issues:

1. Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
2. Review [GitHub Issues](https://github.com/pmgledhill102/dotfiles/issues)
3. Open a new issue with test logs and details
