Set up PHP linting, formatting, and dependency auditing for this project. Assumes `/setup-common` has already been run (pre-commit framework is in place).

## What to install and configure

### 1. PHP-CS-Fixer (formatting)

Create `.php-cs-fixer.dist.php` in the project root (if it doesn't already exist). If one exists, review and suggest additions.

```php
<?php

$finder = PhpCsFixer\Finder::create()
    ->in(__DIR__)
    ->exclude('vendor');

return (new PhpCsFixer\Config())
    ->setRules([
        '@PSR12' => true,
        'array_syntax' => ['syntax' => 'short'],
        'ordered_imports' => ['sort_algorithm' => 'alpha'],
        'no_unused_imports' => true,
        'trailing_comma_in_multiline' => true,
        'single_quote' => true,
    ])
    ->setFinder($finder);
```

### 2. PHPStan (static analysis)

Create `phpstan.neon` in the project root (if it doesn't already exist). If one exists, review and suggest additions.

```neon
parameters:
    level: 6
    paths:
        - src
    excludePaths:
        - vendor
```

Adjust `paths` and `level` to match the project. Level 6 is a good starting point; level 9 is maximum strictness. For existing codebases, start lower and increase incrementally.

### 3. .gitignore

Append these lines to `.gitignore` if they aren't already present:

```gitignore
# PHP
vendor/
composer.lock
.phpunit.result.cache
.php-cs-fixer.cache
phpstan-baseline.neon
```

Note: `composer.lock` should be committed for applications but may be ignored for libraries. Ask the user which type this project is and adjust accordingly.

### 4. Add pre-commit hooks

Append these repos to the existing `.pre-commit-config.yaml`:

```yaml
  - repo: local
    hooks:
      - id: php-cs-fixer
        name: php-cs-fixer
        entry: vendor/bin/php-cs-fixer fix --dry-run --diff
        language: system
        types: [php]
        pass_filenames: false
      - id: phpstan
        name: phpstan
        entry: vendor/bin/phpstan analyse
        language: system
        types: [php]
        pass_filenames: false
```

### 5. GitHub Actions workflow

Create or update the CI workflow to include PHP linting and dependency auditing jobs that only run when PHP files change. Use a separate workflow file (e.g., `.github/workflows/php.yml`) with path filters, or add jobs to an existing workflow.

```yaml
name: PHP
on:
  push:
    paths: ['**/*.php', 'composer.json', 'composer.lock', 'phpstan.neon']
  pull_request:
    paths: ['**/*.php', 'composer.json', 'composer.lock', 'phpstan.neon']

jobs:
  lint:
    name: PHP-CS-Fixer
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: shivammathur/setup-php@v2
        with:
          php-version: '8.3'
      - run: composer install --no-progress
      - run: vendor/bin/php-cs-fixer fix --dry-run --diff

  phpstan:
    name: PHPStan
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: shivammathur/setup-php@v2
        with:
          php-version: '8.3'
      - run: composer install --no-progress
      - run: vendor/bin/phpstan analyse

  audit:
    name: Composer Audit
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: shivammathur/setup-php@v2
        with:
          php-version: '8.3'
      - run: composer audit
```

Adjust `php-version` to match the project. Don't duplicate if PHP lint jobs already exist. Look up latest action versions.

### 6. Dependabot ecosystem

Read `.github/dependabot.yml` and add the `composer` ecosystem entry if it isn't already present. Don't duplicate entries.

```yaml
  - package-ecosystem: "composer"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
    commit-message:
      prefix: "deps"
      include: "scope"
    labels:
      - "dependencies"
      - "php"
    open-pull-requests-limit: 5
```

### 7. Verify

Run `vendor/bin/php-cs-fixer fix --dry-run --diff` and `vendor/bin/phpstan analyse` to confirm. Fix any issues.

## Important

- Do NOT overwrite existing configs. Read first and merge.
- If `.pre-commit-config.yaml` doesn't exist, tell the user to run `/setup-common` first.
- If the project uses Psalm instead of PHPStan, substitute accordingly.
- Adjust the PHP version in CI to match the project's minimum supported version.
