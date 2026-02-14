Set up Node.js linting, formatting, and dependency auditing for this project. Assumes `/setup-common` has already been run (pre-commit framework is in place).

## What to install and configure

### 1. Prettier (formatting)

Create `.prettierrc` in the project root (if it doesn't already exist). If one exists, review and suggest additions.

```json
{
  "semi": true,
  "singleQuote": true,
  "trailingComma": "all",
  "printWidth": 100,
  "tabWidth": 2
}
```

Create `.prettierignore` if it doesn't exist:

```text
node_modules/
dist/
build/
coverage/
```

### 2. ESLint

Create `eslint.config.js` (flat config) in the project root (if it doesn't already exist). If one exists, review and suggest additions.

```js
import js from '@eslint/js';

export default [
  js.configs.recommended,
  {
    rules: {
      'no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
      'no-console': 'warn',
      'prefer-const': 'error',
      'no-var': 'error',
    },
  },
  {
    ignores: ['node_modules/', 'dist/', 'build/', 'coverage/'],
  },
];
```

If the project uses CommonJS (no `"type": "module"` in `package.json`), use `eslint.config.cjs` with `require()` instead.

### 3. .gitignore

Append these lines to `.gitignore` if they aren't already present:

```gitignore
# Node.js
node_modules/
dist/
build/
coverage/
*.tgz
.npm
.eslintcache
```

### 4. Add pre-commit hooks

Append these repos to the existing `.pre-commit-config.yaml`:

```yaml
  - repo: https://github.com/pre-commit/mirrors-prettier
    rev: <latest tag>
    hooks:
      - id: prettier

  - repo: https://github.com/pre-commit/mirrors-eslint
    rev: <latest tag>
    hooks:
      - id: eslint
        types: [javascript]
        additional_dependencies:
          - eslint
          - '@eslint/js'
```

Look up the latest release tag for each repo and use those for the `rev:` values.

### 5. GitHub Actions workflow

Create or update the CI workflow to include Node.js linting and dependency auditing jobs that only run when JS files change. Use a separate workflow file (e.g., `.github/workflows/node.yml`) with path filters, or add jobs to an existing workflow.

```yaml
name: Node.js
on:
  push:
    paths: ['**/*.js', '**/*.mjs', '**/*.cjs', 'package.json', 'package-lock.json']
  pull_request:
    paths: ['**/*.js', '**/*.mjs', '**/*.cjs', 'package.json', 'package-lock.json']

jobs:
  lint:
    name: Lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version-file: '.node-version'
          cache: 'npm'
      - run: npm ci
      - run: npx prettier --check .
      - run: npx eslint .

  audit:
    name: npm Audit
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version-file: '.node-version'
      - run: npm audit --audit-level=high
```

If the project doesn't have `.node-version`, use a fixed `node-version: '22'` (or whatever the project uses). Don't duplicate if Node.js lint jobs already exist. Look up latest action versions.

### 6. Dependabot ecosystem

Read `.github/dependabot.yml` and add the `npm` ecosystem entry if it isn't already present. Don't duplicate entries.

```yaml
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
    commit-message:
      prefix: "deps"
      include: "scope"
    labels:
      - "dependencies"
      - "javascript"
    open-pull-requests-limit: 5
```

### 7. Verify

Run `npx prettier --check .` and `npx eslint .` to confirm. Fix formatting issues with `npx prettier --write .`.

## Important

- Do NOT overwrite existing configs. Read first and merge.
- If `.pre-commit-config.yaml` doesn't exist, tell the user to run `/setup-common` first.
- Use ESLint flat config format (eslint.config.js) for new projects. If the project has an existing `.eslintrc.*`, don't migrate unless asked.
- If the project uses yarn or pnpm instead of npm, adjust commands and CI accordingly.
