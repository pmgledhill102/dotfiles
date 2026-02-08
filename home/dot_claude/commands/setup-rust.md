Set up Rust linting, formatting, and dependency auditing for this project. Assumes `/setup-common` has already been run (pre-commit framework is in place).

## What to install and configure

### 1. rustfmt

Create `rustfmt.toml` in the project root (if it doesn't already exist). If one exists, review and suggest additions.

```toml
edition = "2021"
max_width = 100
use_field_init_shorthand = true
use_try_shorthand = true
```

Adjust `edition` to match `Cargo.toml`.

### 2. clippy

Create `clippy.toml` in the project root (if it doesn't already exist). If one exists, review and suggest additions.

```toml
too-many-arguments-threshold = 7
```

Add clippy configuration to `Cargo.toml` or `.cargo/config.toml`:

```toml
[lints.clippy]
pedantic = { level = "warn", priority = -1 }
nursery = { level = "warn", priority = -1 }
unwrap_used = "warn"
expect_used = "warn"
```

If `pedantic` is too aggressive for an existing codebase, start with the default clippy lints and add selectively.

### 3. deny.toml (cargo-deny)

Create `deny.toml` in the project root (if it doesn't already exist):

```toml
[advisories]
vulnerability = "deny"
unmaintained = "warn"
yanked = "warn"

[licenses]
unlicensed = "deny"
allow = [
    "MIT",
    "Apache-2.0",
    "BSD-2-Clause",
    "BSD-3-Clause",
    "ISC",
    "Unicode-DFS-2016",
]

[bans]
multiple-versions = "warn"
wildcards = "deny"

[sources]
unknown-registry = "warn"
unknown-git = "warn"
```

### 4. .gitignore

Append these lines to `.gitignore` if they aren't already present:

```gitignore
# Rust
target/
Cargo.lock
```

Note: `Cargo.lock` should be committed for binary crates but ignored for library crates. Ask the user which type this project is and adjust accordingly.

### 5. Add pre-commit hooks

Append this repo to the existing `.pre-commit-config.yaml`:

```yaml
  - repo: local
    hooks:
      - id: cargo-fmt
        name: cargo fmt
        entry: cargo fmt --all --
        language: system
        types: [rust]
      - id: cargo-clippy
        name: cargo clippy
        entry: cargo clippy --all-targets --all-features -- -D warnings
        language: system
        types: [rust]
        pass_filenames: false
```

### 6. GitHub Actions workflow

Create or update the CI workflow to include Rust linting, formatting, and security scanning jobs that only run when Rust files change. Use a separate workflow file (e.g., `.github/workflows/rust.yml`) with path filters, or add jobs to an existing workflow.

```yaml
name: Rust
on:
  push:
    paths: ['**/*.rs', 'Cargo.toml', 'Cargo.lock']
  pull_request:
    paths: ['**/*.rs', 'Cargo.toml', 'Cargo.lock']

jobs:
  fmt:
    name: Rustfmt
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          components: rustfmt
      - run: cargo fmt --all --check

  clippy:
    name: Clippy
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          components: clippy
      - run: cargo clippy --all-targets --all-features -- -D warnings

  audit:
    name: Security Audit
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: rustsec/audit-check@v2
        with:
          token: ${{ secrets.GITHUB_TOKEN }}

  deny:
    name: Cargo Deny
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: EmbarkStudios/cargo-deny-action@v2
```

Don't duplicate if Rust lint jobs already exist. Look up latest action versions.

### 7. Verify

Run `cargo fmt --all --check` and `cargo clippy --all-targets --all-features -- -D warnings` to confirm. Fix any issues.

## Important

- Do NOT overwrite existing configs. Read first and merge.
- If `.pre-commit-config.yaml` doesn't exist, tell the user to run `/setup-common` first.
- If the project is a workspace, ensure clippy and fmt run across all workspace members.
