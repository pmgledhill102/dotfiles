Set up Ruby linting, formatting, and security scanning for this project. Assumes `/setup-common` has already been run (pre-commit framework is in place).

## What to install and configure

### 1. RuboCop (formatting + linting)

Create `.rubocop.yml` in the project root (if it doesn't already exist). If one exists, review and suggest additions.

```yaml
require:
  - rubocop-performance
  - rubocop-rake

AllCops:
  TargetRubyVersion: 3.3
  NewCops: enable
  SuggestExtensions: false
  Exclude:
    - 'vendor/**/*'
    - 'db/schema.rb'

Style/Documentation:
  Enabled: false

Metrics/MethodLength:
  Max: 20

Layout/LineLength:
  Max: 120
```

Adjust `TargetRubyVersion` to match the project. If the project uses Rails, add `rubocop-rails` to the require list.

### 2. .gitignore

Append these lines to `.gitignore` if they aren't already present:

```gitignore
# Ruby
*.gem
*.rbc
.bundle/
vendor/bundle/
coverage/
tmp/
log/
.byebug_history
```

### 3. Add pre-commit hooks

Append this repo to the existing `.pre-commit-config.yaml`:

```yaml
  - repo: https://github.com/rubocop/rubocop
    rev: <latest tag>
    hooks:
      - id: rubocop
        args: ['--auto-correct']
```

Look up the latest release tag and use it for the `rev:` value.

### 4. GitHub Actions workflow

Create or update the CI workflow to include Ruby linting and security scanning jobs that only run when Ruby files change. Use a separate workflow file (e.g., `.github/workflows/ruby.yml`) with path filters, or add jobs to an existing workflow.

```yaml
name: Ruby
on:
  push:
    paths: ['**/*.rb', 'Gemfile', 'Gemfile.lock', '.rubocop.yml']
  pull_request:
    paths: ['**/*.rb', 'Gemfile', 'Gemfile.lock', '.rubocop.yml']

jobs:
  rubocop:
    name: RuboCop
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - run: bundle exec rubocop

  brakeman:
    name: Brakeman
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - run: gem install brakeman
      - run: brakeman --no-pager

  bundler-audit:
    name: Bundler Audit
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - run: gem install bundler-audit
      - run: bundle-audit check --update
```

Don't duplicate if Ruby lint jobs already exist. Look up latest action versions.

Brakeman is only relevant for Rails applications. If the project is not a Rails app, skip the brakeman job.

### 5. Verify

Run `bundle exec rubocop` to confirm. Fix any issues with `bundle exec rubocop --auto-correct`.

## Important

- Do NOT overwrite existing configs. Read first and merge.
- If `.pre-commit-config.yaml` doesn't exist, tell the user to run `/setup-common` first.
- If the project uses Rails, add `rubocop-rails` to the RuboCop config and Gemfile.
- Only include brakeman for Rails applications.
