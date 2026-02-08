Set up Python linting, formatting, type checking, and security scanning for this project. Assumes `/setup-common` has already been run (pre-commit framework is in place).

Use `uv` for all Python package management. Never use `pip install` or `pipx` directly.

## What to install and configure

### 1. ruff (formatting + linting)

Add ruff configuration to `pyproject.toml` (create if needed, merge if exists):

```toml
[tool.ruff]
target-version = "py312"
line-length = 120

[tool.ruff.lint]
select = [
    "E",    # pycodestyle errors
    "W",    # pycodestyle warnings
    "F",    # pyflakes
    "I",    # isort
    "B",    # flake8-bugbear
    "C4",   # flake8-comprehensions
    "UP",   # pyupgrade
    "SIM",  # flake8-simplify
    "S",    # flake8-bandit (security)
    "RUF",  # ruff-specific rules
]

[tool.ruff.lint.per-file-ignores]
"tests/**/*.py" = ["S101"]  # Allow assert in tests
```

Adjust `target-version` to match the project's minimum Python version.

### 2. mypy (type checking)

Add mypy configuration to `pyproject.toml`:

```toml
[tool.mypy]
python_version = "3.12"
strict = true
warn_return_any = true
warn_unused_configs = true
```

Adjust `python_version` to match the project. If `strict = true` is too aggressive for an existing codebase, start with:

```toml
[tool.mypy]
python_version = "3.12"
check_untyped_defs = true
disallow_untyped_defs = false
```

### 3. .gitignore

Append these lines to `.gitignore` if they aren't already present:

```gitignore
# Python
__pycache__/
*.py[cod]
*$py.class
*.egg-info/
dist/
build/
.eggs/
*.egg
.venv/
venv/
.mypy_cache/
.ruff_cache/
.pytest_cache/
htmlcov/
coverage.xml
.coverage
```

### 4. Add pre-commit hooks

Append these repos to the existing `.pre-commit-config.yaml`:

```yaml
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: <latest tag>
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format

  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: <latest tag>
    hooks:
      - id: mypy
        additional_dependencies: []  # Add project deps that have type stubs
```

Look up the latest release tag for each repo and use those for the `rev:` values.

The `additional_dependencies` list in the mypy hook should include any packages that provide type stubs needed by the project (e.g., `types-requests`).

### 5. GitHub Actions workflow

Create or update the CI workflow to include Python linting, type checking, and security scanning jobs that only run when Python files change. Use a separate workflow file (e.g., `.github/workflows/python.yml`) with path filters, or add jobs to an existing workflow.

```yaml
name: Python
on:
  push:
    paths: ['**/*.py', 'pyproject.toml', 'uv.lock']
  pull_request:
    paths: ['**/*.py', 'pyproject.toml', 'uv.lock']

jobs:
  lint:
    name: Ruff
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/ruff-action@v3

  typecheck:
    name: Mypy
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v5
      - run: uv sync
      - run: uv run mypy .

  security:
    name: Bandit
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v5
      - run: uv tool run bandit -r . -c pyproject.toml
```

Don't duplicate if Python lint jobs already exist. Look up latest action versions.

### 6. Bandit configuration

Add bandit configuration to `pyproject.toml`:

```toml
[tool.bandit]
exclude_dirs = ["tests", ".venv", "venv"]
skips = []
```

### 7. Verify

Run `pre-commit run --all-files` to confirm hooks work. Fix any lint or type issues.

## Important

- Do NOT overwrite existing configs. Read first and merge.
- If `.pre-commit-config.yaml` doesn't exist, tell the user to run `/setup-common` first.
- Always use `uv` for Python package management, never `pip` directly.
- If the project uses `pyright` instead of `mypy`, substitute accordingly.
- Note that ruff's `S` rules overlap with bandit. Having both is intentional — ruff catches issues inline during editing, bandit provides deeper analysis in CI.
