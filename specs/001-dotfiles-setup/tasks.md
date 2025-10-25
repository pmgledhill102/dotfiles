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
- [x] T007 [P] Add base package installation for macOS to `run_once_install-packages.sh.tmpl`
- [x] T008 [P] Add base package installation for Debian/Ubuntu to `run_once_install-packages.sh.tmpl`
- [x] T009 [P] Add base package installation for WSL to `run_once_install-packages.sh.tmpl`

---

## Phase 3: User Story 1 - Easy Installation (Priority: P1) 🎯 MVP

**Goal**: A developer can set up their dotfiles on a new machine with a single command.

**Independent Test**: A new, clean machine can be fully configured by running one command.

- [x] T010 [US1] Document the single command installation in `home/README.md`

---

## Phase 4: User Story 2 - Consistent Shell Experience (Priority: P1)

**Goal**: Provide a consistent Zsh shell experience across all platforms.

**Independent Test**: The shell prompt, theme, and aliases are identical on all platforms.

- [x] T011 [US2] Add `.zshrc` to `chezmoi` in `home/dot_zshrc`
- [x] T012 [US2] Add OhMyZsh installation to `run_once_install-packages.sh.tmpl`
- [x] T013 [US2] Add Powerlevel10k installation to `run_once_install-packages.sh.tmpl`
- [x] T014 [US2] Add Powerlevel10k configuration file (`.p10k.zsh`) to `chezmoi` in `home/dot_p10k.zsh`

---

## Phase 5: User Story 3 - Secure Secret Management (Priority: P2)

**Goal**: Manage secrets securely without storing them in the Git repository.

**Independent Test**: A scan of the repository does not find any plaintext secrets.

- [x] T015 [US3] Add Bitwarden CLI installation to `run_once_install-packages.sh.tmpl`
- [x] T016 [US3] Create a template for a secret file (e.g., `home/.secrets.tmpl`) that will be populated by `chezmoi` from Bitwarden.
- [x] T017 [US3] Document the secret management workflow in `home/README.md`

---

## Phase 6: Polish & Cross-Cutting Concerns

- [ ] T018 [P] Add ShellCheck linting to the CI pipeline.
- [ ] T019 Test the installation on a clean macOS machine.
- [ ] T020 Test the installation on a clean Debian/Ubuntu machine.
- [ ] T021 Test the installation on a clean WSL instance.
- [x] T022 Refine and update the `README.md`.
