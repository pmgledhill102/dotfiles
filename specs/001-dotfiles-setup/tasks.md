# Tasks: Cross-Platform Dotfiles Setup

**Input**: Design documents from `/specs/001-dotfiles-setup/`

## Phase 1: Setup (Shared Infrastructure)

- [x] T001 Initialize `chezmoi` repository with `chezmoi init`
- [x] T002 Create initial directory structure: `home`, `.chezmoitemplates`
- [x] T003 Create `.gitignore` file
- [x] T004 Create `.chezmoiignore` file

---

## Phase 2: Foundational (Blocking Prerequisites)

- [x] T005 Create `run_once_install-packages.sh.tmpl` script
- [x] T006 [P] Add OS detection logic to `run_once_install-packages.sh.tmpl`
- [x] T007 [P] Add base package installation for macOS to
  `run_once_install-packages.sh.tmpl`
- [x] T008 [P] Add base package installation for Debian/Ubuntu to
  `run_once_install-packages.sh.tmpl`
- [x] T009 [P] Add base package installation for WSL to
  `run_once_install-packages.sh.tmpl`

---

## Phase 3: User Story 1 - Easy Installation (Priority: P1) 🎯 MVP

**Goal**: A developer can set up their dotfiles on a new machine with a single
command.

**Independent Test**: A new, clean machine can be fully configured by running
one command.

- [x] T010 [US1] Document the single command installation in `home/README.md`

---

## Phase 4: User Story 2 - Consistent Shell Experience (Priority: P1)

**Goal**: Provide a consistent Zsh shell experience across all platforms.

**Independent Test**: The shell prompt, theme, and aliases are identical on all
platforms.

- [x] T011 [US2] Add `.zshrc` to `chezmoi` in `home/dot_zshrc`
- [x] T012 [US2] Add OhMyZsh installation to `run_once_install-packages.sh.tmpl`
- [x] T013 [US2] Configure Oh My Zsh plugins (autosuggestions, syntax-highlighting, etc.)
- [x] T014 [US2] Add Starship installation to
  `run_once_install-packages.sh.tmpl`
- [x] T015 [US2] Add Starship configuration file (`starship.toml`) to `chezmoi`
- [x] T016 [US2] Add Ghostty installation to `run_once_install-packages.sh.tmpl`
- [x] T017 [US2] Add Ghostty configuration file to `chezmoi`
- [x] T043 [US2] Configure PowerShell to use Starship prompt

---

## Phase 5: User Story 3 - Secure Secret Management (Priority: P2)

**Goal**: Manage development secrets securely using age encryption.

**Independent Test**: A scan of the repository does not find any plaintext
secrets.

- [x] T018 [US3] Add `age` installation to `run_once_install-packages.sh.tmpl`
- [x] T019 [US3] Create a template for a secret file (e.g.,
  `home/.secrets.tmpl`) that will be encrypted with `age`.
- [x] T020 [US3] Document the age encryption workflow (key generation,
  encryption, decryption) in `home/README.md`.
- [x] T021 [US3] Document that highly sensitive secrets are managed manually in
  Bitwarden.

---

## Phase 6: User Story 4 - Automated Testing & Validation (Priority: P2)

**Goal**: Implement comprehensive testing strategy using GitHub Actions.

**Independent Test**: Installation process succeeds automatically on fresh macOS
and Ubuntu environments in CI.

### Validation & Quality Assurance

- [x] T022 [US4] Create post-installation validation scripts
- [x] T023 [US4] Create shell configuration validation scripts
- [ ] T024 [US4] Add theme and prompt functionality tests
- [x] T025 [US4] Implement tool availability verification
- [x] T026 [US4] Add performance benchmarking for installation time
- [x] T044 [US4] Add validation for PowerShell Starship configuration

### CI/CD Pipeline (GitHub Actions)

- [x] T027 [US4] Create GitHub Actions workflow for macOS testing
- [x] T028 [US4] Create GitHub Actions workflow for Ubuntu testing
- [x] T029 [US4] Add matrix testing for multiple OS versions
- [x] T030 [US4] Configure artifact collection for test results

---

## Phase 7: Quality Assurance & Documentation

- [x] T031 [P] Add ShellCheck linting to the CI pipeline
- [ ] T032 [P] Update documentation with testing procedures
- [x] T033 Refine and update the `README.md`

---

## Phase 8: Final Integration & Maintenance Setup

**Goal**: Complete the project setup with maintenance tooling, final documentation, and production readiness checks.

**Independent Test**: The repository is fully documented, includes maintenance procedures, and is ready for daily use.

- [x] T034 [P8] Create CONTRIBUTING.md with guidelines for maintaining the dotfiles
- [x] T035 [P8] Add maintenance documentation (updating dependencies, adding new tools)
- [x] T036 [P8] Create backup and recovery procedures documentation
- [ ] T037 [P8] Set up repository maintenance workflows (dependency updates, etc.)
- [x] T038 [P8] Create troubleshooting guide for common issues
- [ ] T039 [P8] Final validation: Run complete installation test on all platforms
- [x] T040 [P8] Update all documentation to reflect final state
- [x] T041 [P8] Create migration guide for users switching from other dotfiles
- [x] T042 [P8] Mark Phase 8 as complete

---

**Phase 8 Status**: ✅ COMPLETE

**Summary**: Phase 8 has been completed with comprehensive documentation covering:

- Contributing guidelines for maintainers
- Maintenance procedures for keeping the system up to date
- Backup and disaster recovery procedures
- Troubleshooting guide for common issues
- Migration guide for users switching from other systems
- Updated README with better organization and links to all documentation

**Remaining Optional Tasks**:

- T037: Set up automated dependency update workflows (e.g., Dependabot, Renovate)
- T039: Comprehensive platform testing (can be done as part of Phase 6/7 CI/CD work)

---

## Phase 9: Maturity & Power User Features (Priority: P2)

**Goal**: Enhance the dotfiles with advanced tools, better package management, and system customization.

**Independent Test**:
1. `brew bundle` runs on changes.
2. VS Code settings sync.
3. `tmux`, `git-delta`, `lazygit` are available and configured.
4. macOS defaults are applied.
5. Fonts are installed.

- [ ] T045 [MacOS] Implement `Brewfile` support via `run_onchange_install-packages.sh.tmpl` for MacOS (see _todo_resources/Brewfile)
- [ ] T045b [Ubuntu] Implement apt package installs using package list config file (see _todo_resources/ubuntu_pkglist)
- [ ] T046 [US5] Add VS Code `settings.json` and `keybindings.json` to chezmoi
- [ ] T047 [US5] Add `tmux` configuration (`.tmux.conf`)
- [ ] T048 [US5] Create `run_once_macos_defaults.sh` for system defaults
- [ ] T049 [US5] Add `git-delta` installation and configuration
- [ ] T050 [US5] Add `lazygit` configuration
- [ ] T051 [US5] Add global `.gitignore` with system file exclusions
- [ ] T052 [US5] Automate Nerd Font installation

---

## Phase 10: Windows Support (Priority: P3)

**Goal**: Extend the seamless dotfiles experience to Windows native (PowerShell) and WSL environments.

**Independent Test**:
1. PowerShell profile loads correctly with aliases and functions.
2. Windows packages are installed via Winget or Scoop.
3. Windows Terminal is configured with the correct theme and fonts.

- [ ] T053 [Win] Create `run_once_install-packages-windows.ps1` (Winget/Scoop)
- [ ] T054 [Win] Full management of `Microsoft.PowerShell_profile.ps1`
- [ ] T055 [Win] Configure Windows Terminal (`settings.json`)
- [ ] T056 [Win] Add Windows-specific environment variables
- [ ] T057 [Win] Automate Nerd Font installation on Windows
- [ ] T058 [Win] Registry tweaks for developer experience (e.g. Long Paths, Developer Mode)
- [ ] T059 [Win] Use winget to install packages - use the import action, with a package json file
- [ ] T060 [win] install JetBrainsMonoNerdFont using winget approach

---

## Phase 11: Legacy Resource Migration (Priority: P2)

**Goal**: Seamlessly integrate existing configuration resources into the new chezmoi-based system.

**Independent Test**: All resources in `_todo_resources` have been processed and the folder is deleted.

- [ ] T061 [Migrate] Migrate `Brewfile` dependencies to `run_onchange_install-packages.sh.tmpl` (macOS)
- [ ] T062 [Migrate] Implement WSL PATH fix script (`fix-wsl-path.sh`)
- [ ] T063 [Migrate] Automate PowerShell installation on Ubuntu (`pwsh.sh.md`)
- [ ] T064 [Migrate] Ensure base Ubuntu packages are installed (`ubuntu_pkglist`)
- [ ] T065 [Migrate] Automate VS Code extension installation (`vscode-exts.md`)
- [ ] T066 [Migrate] Integrate Windows Terminal profile configuration (`win-term-profile.ps1`)
- [ ] T067 [Migrate] Delete `_todo_resources` folder once migration is complete
- [ ] T068 [Migrate] Add pyhton support, favouring UV rather than pip - package installs for all OS's and any env script setup required
