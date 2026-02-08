Set up TypeScript linting, formatting, type checking, and dependency auditing for this project. Assumes `/setup-common` has already been run (pre-commit framework is in place).

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

Append these repos to the existing `.pre-commit-config.yaml`:

```yaml
  - repo: https://github.com/pre-commit/mirrors-prettier
    rev: <latest tag>
    hooks:
      - id: prettier
        types_or: [typescript, tsx, javascript, jsx, json, css, markdown]

  - repo: https://github.com/pre-commit/mirrors-eslint
    rev: <latest tag>
    hooks:
      - id: eslint
        types_or: [typescript, tsx]
        additional_dependencies:
          - eslint
          - typescript
          - typescript-eslint
          - '@eslint/js'
```

Look up the latest release tag for each repo and use those for the `rev:` values.

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
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
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
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version-file: '.node-version'
          cache: 'npm'
      - run: npm ci
      - run: npx tsc --noEmit

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

If the project doesn't have `.node-version`, use a fixed `node-version: '22'` (or whatever the project uses). Don't duplicate if TypeScript lint jobs already exist. Look up latest action versions.

### 7. Verify

Run `npx tsc --noEmit`, `npx prettier --check .`, and `npx eslint .` to confirm. Fix any issues.

## Important

- Do NOT overwrite existing configs. Read first and merge.
- If `.pre-commit-config.yaml` doesn't exist, tell the user to run `/setup-common` first.
- Use ESLint flat config format. If the project has an existing `.eslintrc.*`, don't migrate unless asked.
- If the project uses yarn or pnpm instead of npm, adjust commands and CI accordingly.
- If the project is a monorepo, adjust `tsconfig.json` paths and ESLint config accordingly.
