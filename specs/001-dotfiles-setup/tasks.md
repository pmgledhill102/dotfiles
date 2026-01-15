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
- [x] T012a [US2] Configure Oh My Zsh plugins (autosuggestions, syntax-highlighting, etc.)
- [x] T013 [US2] Add Starship installation to
  `run_once_install-packages.sh.tmpl`
- [x] T014 [US2] Add Starship configuration file (`starship.toml`) to `chezmoi`
- [x] T015 [US2] Add Ghostty installation to `run_once_install-packages.sh.tmpl`
- [x] T016 [US2] Add Ghostty configuration file to `chezmoi`

---

## Phase 5: User Story 3 - Secure Secret Management (Priority: P2)

**Goal**: Manage development secrets securely using age encryption.

**Independent Test**: A scan of the repository does not find any plaintext
secrets.

- [x] T017 [US3] Add `age` installation to `run_once_install-packages.sh.tmpl`
- [x] T018 [US3] Create a template for a secret file (e.g.,
  `home/.secrets.tmpl`) that will be encrypted with `age`.
- [x] T019 [US3] Document the age encryption workflow (key generation,
  encryption, decryption) in `home/README.md`.
- [x] T020 [US3] Document that highly sensitive secrets are managed manually in
  Bitwarden.

---

## Phase 6: User Story 4 - Automated Testing & Validation (Priority: P2)

**Goal**: Implement comprehensive testing strategy using VMware Fusion and GitHub
Actions.

**Independent Test**: Installation process succeeds automatically on fresh macOS
and Ubuntu environments.

### Local Testing Infrastructure (VMware Fusion)

- [x] T021 [US4] Document manual VMware Fusion VM setup for macOS testing in
  `docs/VMWARE_TESTING_GUIDE.md`
- [x] T022 [US4] Document manual VMware Fusion VM setup for Ubuntu testing in
  `docs/VMWARE_TESTING_GUIDE.md`
- [x] T023 [US4] Create test script to run inside the VMware Fusion VM
- [x] T024 [US4] Create post-installation validation scripts

### CI/CD Pipeline (GitHub Actions)

- [ ] T025 [US4] Create GitHub Actions workflow for macOS testing
- [ ] T026 [US4] Create GitHub Actions workflow for Ubuntu testing
- [ ] T027 [US4] Add matrix testing for multiple OS versions
- [ ] T028 [US4] Configure artifact collection for test results

### Validation & Quality Assurance

- [ ] T029 [US4] Create shell configuration validation scripts
- [ ] T030 [US4] Add theme and prompt functionality tests
- [ ] T031 [US4] Implement tool availability verification
- [ ] T032 [US4] Add performance benchmarking for installation time

---

## Phase 7: Quality Assurance & Documentation

- [ ] T030 [P] Add ShellCheck linting to the CI pipeline
- [ ] T031 Test the installation on a clean macOS machine (UTM)
- [ ] T032 Test the installation on a clean Ubuntu machine (UTM)
- [ ] T033 Test the installation on a clean WSL instance
- [ ] T034 [P] Update documentation with testing procedures
- [x] T035 Refine and update the `README.md`

---

## Phase 8: Final Integration & Maintenance Setup

**Goal**: Complete the project setup with maintenance tooling, final documentation, and production readiness checks.

**Independent Test**: The repository is fully documented, includes maintenance procedures, and is ready for daily use.

- [x] T036 [P8] Create CONTRIBUTING.md with guidelines for maintaining the dotfiles
- [x] T037 [P8] Add maintenance documentation (updating dependencies, adding new tools)
- [x] T038 [P8] Create backup and recovery procedures documentation
- [ ] T039 [P8] Set up repository maintenance workflows (dependency updates, etc.)
- [x] T040 [P8] Create troubleshooting guide for common issues
- [ ] T041 [P8] Final validation: Run complete installation test on all platforms
- [ ] T042 [P8] Update all documentation to reflect final state
- [x] T043 [P8] Create migration guide for users switching from other dotfiles
- [ ] T044 [P8] Mark Phase 8 as complete
