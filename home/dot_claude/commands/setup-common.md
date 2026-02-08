Set up the common development tooling foundation for this project. This is the base layer that language-specific setup commands build on.

## What to install and configure

### 1. EditorConfig

Create `.editorconfig` in the project root (if it doesn't already exist). If one exists, review it and suggest additions for any missing settings.

```ini
root = true

[*]
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
charset = utf-8
indent_style = space
indent_size = 2

[*.{go,py}]
indent_size = 4

[Makefile]
indent_style = tab
```

### 2. pre-commit framework

Create `.pre-commit-config.yaml` in the project root (if it doesn't already exist). If one exists, review it and suggest adding any missing hooks from below.

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: <latest tag>
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
      - id: check-merge-conflict

  - repo: https://github.com/gitleaks/gitleaks
    rev: <latest tag>
    hooks:
      - id: gitleaks
```

Look up the latest release tag for each repo and use those for the `rev:` values.

After creating/updating the config, run:

```sh
pre-commit install
```

If `pre-commit` is not installed, tell the user to install it (`brew install pre-commit`) and stop.

### 3. Verify

Run `pre-commit run --all-files` to confirm everything works. Fix any issues that come up.

## Important

- Do NOT blindly overwrite existing config files. Read them first and merge.
- If a `.gitignore` doesn't exist, create one appropriate for the project.
