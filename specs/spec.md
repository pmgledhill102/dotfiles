# Feature Specification: Cross-Platform Dotfiles Setup

**Feature Branch**: `001-dotfiles-setup`
**Created**: 2025-10-25
**Status**: Draft
**Input**: User description: "Create a new dotfiles repository for a software
developer working across macOS, Ubuntu, and Windows (via WSL). The system must
provide a consistent Zsh shell experience, powered by OhMyZsh and the
Starship prompt. It must be easily installable on a new machine with a
single command. All sensitive data, such as API keys, must be managed securely
and kept out of the public Git repository."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Easy Installation (Priority: P1)

As a developer, I want to be able to set up my dotfiles on a new machine
(macOS, Ubuntu, or WSL) by running a single command, so that I can quickly get
to a familiar and productive environment.

**Why this priority**: This is the core functionality of the dotfiles
repository.

**Independent Test**: A new, clean machine (macOS, Ubuntu, or WSL) can be fully
configured by cloning the repository and running one command.

**Acceptance Scenarios**:

1. **Given** a new macOS machine, **When** the user clones the repository and
   runs the installation command, **Then** the dotfiles are installed and the
   shell is configured correctly.
2. **Given** a new Ubuntu machine, **When** the user clones the repository and
   runs the installation command, **Then** the dotfiles are installed and the
   shell is configured correctly.
3. **Given** a new WSL instance, **When** the user clones the repository and
   runs the installation command, **Then** the dotfiles are installed and the
   shell is configured correctly.

---

### User Story 2 - Consistent Shell Experience (Priority: P1)

As a developer, I want a consistent Zsh shell experience across all my
machines, using Ghostty as the terminal emulator, complete with OhMyZsh,
useful productivity plugins, and the Starship prompt, so that I can work
efficiently without needing to adjust to different shell environments.

**Why this priority**: This provides a consistent and productive user
experience.

**Independent Test**: The shell prompt, theme, plugins, and aliases are identical on
macOS, Ubuntu, and WSL.

**Acceptance Scenarios**:

1. **Given** an installed system, **When** the user opens a new terminal,
   **Then** the Zsh shell is the default shell.
2. **Given** the Zsh shell is open, **When** the user views the prompt, **Then**
   the Starship prompt is displayed correctly.
3. **Given** an installed system, **When** the user opens a terminal, **Then**
   Ghostty is available and configured (on macOS/Windows only).
4. **Given** an installed system, **When** the user types commands, **Then**
   Oh My Zsh plugins provide autosuggestions, syntax highlighting, and enhanced
   functionality.

---

### User Story 3 - Secure Secret Management (Priority: P2)

As a developer, I want to manage my development-related secrets (API keys,
tokens, etc.) securely using age encryption with a passphrase, so that I can
safely share my dotfiles publicly without exposing sensitive information. My
highly sensitive, day-to-day secrets will remain in Bitwarden, managed
manually.

**Why this priority**: This is a critical security requirement.

**Independent Test**: A scan of the repository does not find any plaintext
secrets.

**Acceptance Scenarios**:

1. **Given** the dotfiles are being installed on a new machine, **When**
   `chezmoi apply` is run, **Then** the user is prompted for the age passphrase
   to decrypt the secrets.
2. **Given** the repository is public, **When** a security scan is performed,
   **Then** no plaintext secrets are found in the repository.
3. **Given** a user needs to add a new development secret, **Then** there is a
   clear and documented process for encrypting it with age.

---

### User Story 4 - Automated Testing & Validation (Priority: P2)

As a developer maintaining this dotfiles repository, I want automated testing
that validates the installation process across different platforms, so that I
can confidently make changes without breaking existing functionality.

**Why this priority**: This ensures reliability and prevents regressions during
development.

**Independent Test**: The installation process succeeds automatically on fresh
macOS and Ubuntu environments through CI/CD (GitHub Actions) workflows.

**Acceptance Scenarios**:

1. **Given** a new pull request is opened, **When** the GitHub Actions workflow
   runs, **Then** the dotfiles are installed successfully on a macOS runner.
2. **Given** a new pull request is opened, **When** the GitHub Actions workflow
   runs, **Then** the dotfiles are installed successfully on an Ubuntu runner.
3. **Given** the installation completes in CI, **When** validation scripts run,
   **Then** all expected tools (zsh, oh-my-zsh, powerlevel10k) are properly
   configured and functional.

### Edge Cases

- What happens if the installation script is run on an unsupported operating
  system?
- How does the system handle a failed installation?
- What happens if a required dependency (like Git) is not installed?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide a single command to install the dotfiles
  on a new machine.
- **FR-002**: The installation script MUST detect the operating system (macOS,
  Debian/Ubuntu, WSL) and install the appropriate dependencies.
- **FR-003**: The system MUST install and configure Zsh as the default shell.
- **FR-004**: The system MUST install and configure OhMyZsh.
- **FR-004a**: The system MUST install and configure Oh My Zsh plugins including:
  zsh-autosuggestions, zsh-syntax-highlighting, colored-man-pages,
  command-not-found, history, copypath, and copyfile.
- **FR-005**: The system MUST install and configure the Starship prompt.
- **FR-005a**: The system MUST configure PowerShell to use the Starship prompt.
- **FR-006**: The system MUST provide a mechanism for managing development
  secrets using age encryption with a passphrase. Highly sensitive secrets
  will be managed manually in Bitwarden.
- **FR-007**: The configuration for tools (Zsh, Git, etc.) MUST be organized
  into logical, self-contained modules.
- **FR-008**: The system MUST include automated testing capabilities for
  validating installations on macOS and Ubuntu platforms.
- **FR-009**: The system MUST include validation scripts that verify the correct
  installation and configuration of all components.
- **FR-010**: The repository MUST include GitHub Actions workflows for
  continuous integration testing.
- **FR-011**: The system MUST install and configure Ghostty as the terminal
  emulator on macOS and Windows (not required for Linux).
- **FR-012**: Installation scripts MUST be idempotent, allowing safe re-execution
  without errors or duplicate installations. Re-running the installation script
  after configuration changes MUST apply those changes correctly.
- **FR-013**: The system MUST include pre-commit hooks to enforce markdown linting
  standards on all documentation files.

## Non-Functional Requirements

### Testing Requirements

- **NFR-TEST-001**: Automated testing MUST be implemented using GitHub Actions
  for pull request validation on every commit.
- **NFR-TEST-002**: Test environments MUST be clean, isolated runners
  that simulate fresh OS installations.
- **NFR-TEST-003**: All tests MUST include validation of the complete user
  experience, from installation to functional shell usage.
- **NFR-TEST-004**: Test execution time MUST not exceed 10 minutes per platform
   in the CI environment.
- **NFR-TEST-005**: The CI pipeline MUST include static analysis steps for both
  shell scripts (ShellCheck) and documentation (Markdown linting).

### Performance Requirements

- **NFR-PERF-001**: Shell startup time MUST not exceed 1 second on modern
  hardware after all plugins and configurations are loaded.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A new machine (macOS, Ubuntu, or WSL) can be fully set up with the
  dotfiles by running a single command in under 5 minutes.
- **SC-002**: After installation, the Zsh shell with the Starship prompt and
  Oh My Zsh plugins is the default shell and is visually and functionally
  identical across macOS, Ubuntu, and WSL.
- **SC-003**: No plaintext development secrets are stored within the
  version-controlled repository. Encrypted secrets are decrypted at runtime
  using a passphrase.
- **SC-004**: Automated tests successfully validate the installation process on
  both macOS and Ubuntu environments with a 100% success rate.
- **SC-005**: Pull requests trigger automated CI tests that complete within 10
  minutes and provide clear pass/fail feedback.
