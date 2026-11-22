---
name: setup-typescript
description: Set up TypeScript formatting, linting, type checking and dependency auditing for a project — prettier, eslint with typescript-eslint, tsc --noEmit and npm audit, wired into pre-commit and CI.
---

# Set up TypeScript tooling

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

### 2. ESLint with typescript-eslint

Create `eslint.config.ts` in the project root (if it doesn't already exist). If one exists, review and suggest additions.

```ts
import eslint from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  eslint.configs.recommended,
  ...tseslint.configs.recommendedTypeChecked,
  {
    languageOptions: {
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
      '@typescript-eslint/no-explicit-any': 'warn',
      '@typescript-eslint/explicit-function-return-type': 'off',
      'no-console': 'warn',
    },
  },
  {
    ignores: ['node_modules/', 'dist/', 'build/', 'coverage/'],
  },
);
```

If type-checked rules are too slow or noisy for the project, use `tseslint.configs.recommended` instead of `recommendedTypeChecked`.

### 3. TypeScript strict mode

Review `tsconfig.json` and suggest enabling strict mode if not already set:

```json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "forceConsistentCasingInFileNames": true
  }
}
```

Do not overwrite existing `tsconfig.json`. Only suggest additions for missing strict options.

### 4. .gitignore

Append these lines to `.gitignore` if they aren't already present:

```gitignore
# Node.js / TypeScript
node_modules/
dist/
build/
coverage/
*.tgz
.npm
.eslintcache
*.tsbuildinfo
```

### 5. Add pre-commit hooks

Append this repo to the existing `.pre-commit-config.yaml`. Use `repo: local` hooks running the project's own binaries — not the `pre-commit/mirrors-*` repos: `mirrors-prettier` is archived and no longer receives releases, and both mirrors pin their own copy of the tool, so the hook and `package.json` can silently run different versions.

```yaml
  - repo: local
    hooks:
      - id: prettier
        name: prettier
        entry: npx --no-install prettier --write
        language: system
        types_or: [ts, tsx, javascript, jsx, json, css, markdown]
      - id: eslint
        name: eslint
        entry: npx --no-install eslint
        language: system
        types_or: [ts, tsx]
```

`--no-install` matters: without it, a missing `node_modules` makes npx silently download some other version instead of failing. Both tools must be devDependencies — `npm install -D prettier eslint typescript typescript-eslint @eslint/js` if they aren't already.

### 6. GitHub Actions workflow

Create or update the CI workflow to include TypeScript linting, type checking, and dependency auditing jobs that only run when TS files change. Use a separate workflow file (e.g., `.github/workflows/typescript.yml`) with path filters, or add jobs to an existing workflow.

```yaml
name: TypeScript
on:
  push:
    paths: ['**/*.ts', '**/*.tsx', 'package.json', 'package-lock.json', 'tsconfig.json']
  pull_request:
    paths: ['**/*.ts', '**/*.tsx', 'package.json', 'package-lock.json', 'tsconfig.json']

jobs:
  lint:
    name: Lint & Format
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<full-sha> # <version>
      - uses: actions/setup-node@<full-sha> # <version>
        with:
          node-version-file: '.node-version'
          cache: 'npm'
      - run: npm ci
      - run: npx prettier --check .
      - run: npx eslint .

  typecheck:
    name: Type Check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<full-sha> # <version>
      - uses: actions/setup-node@<full-sha> # <version>
        with:
          node-version-file: '.node-version'
          cache: 'npm'
      - run: npm ci
      - run: npx tsc --noEmit

  audit:
    name: npm Audit
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<full-sha> # <version>
      - uses: actions/setup-node@<full-sha> # <version>
        with:
          node-version-file: '.node-version'
      - run: npm audit --audit-level=high
```

If the project doesn't have `.node-version`, use a fixed `node-version: '22'` (or whatever the project uses). Don't duplicate if TypeScript lint jobs already exist. Look up latest action versions.

### 7. Dependabot ecosystem

If the `npm` ecosystem is already configured in `.github/dependabot.yml` (e.g. from `setup-node`), skip this step. Otherwise, read `.github/dependabot.yml` and add the `npm` ecosystem entry:

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
    cooldown:
      default-days: 7
```

### 8. Verify

Run `npx tsc --noEmit`, `npx prettier --check .`, and `npx eslint .` to confirm. Fix any issues.

## Important

- Do NOT overwrite existing configs. Read first and merge.
- If `.pre-commit-config.yaml` doesn't exist, tell the user to run `setup-common` first.
- Use ESLint flat config format. If the project has an existing `.eslintrc.*`, don't migrate unless asked.
- If the project uses yarn or pnpm instead of npm, adjust commands and CI accordingly.
- If the project is a monorepo, adjust `tsconfig.json` paths and ESLint config accordingly.
