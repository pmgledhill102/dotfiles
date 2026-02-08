Set up .NET / C# linting, formatting, and security scanning for this project. Assumes `/setup-common` has already been run (pre-commit framework is in place).

## What to install and configure

### 1. EditorConfig for C#

Append C#-specific settings to `.editorconfig` (merge with existing):

```ini
[*.cs]
indent_size = 4
csharp_new_line_before_open_brace = all
csharp_new_line_before_else = true
csharp_new_line_before_catch = true
csharp_new_line_before_finally = true
csharp_indent_case_contents = true
csharp_indent_switch_labels = true
csharp_space_after_cast = false
csharp_space_after_keywords_in_control_flow_statements = true
dotnet_sort_system_directives_first = true

# Naming conventions
dotnet_naming_style.pascal_case.capitalization = pascal_case
dotnet_naming_style.camel_case.capitalization = camel_case
dotnet_naming_style.underscore_prefix.capitalization = camel_case
dotnet_naming_style.underscore_prefix.required_prefix = _
```

### 2. Directory.Build.props (Roslyn analyzers + SecurityCodeScan)

Create or update `Directory.Build.props` in the solution root:

```xml
<Project>
  <PropertyGroup>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
    <EnforceCodeStyleInBuild>true</EnforceCodeStyleInBuild>
    <AnalysisLevel>latest-recommended</AnalysisLevel>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="SecurityCodeScan.VS2019" Version="*">
      <PrivateAssets>all</PrivateAssets>
      <IncludeAssets>runtime; build; native; contentfiles; analyzers</IncludeAssets>
    </PackageReference>
  </ItemGroup>
</Project>
```

Look up the latest stable version of `SecurityCodeScan.VS2019` (or `SecurityCodeScan.VS2022` for .NET 8+) and pin it instead of `*`.

### 3. .gitignore

Append these lines to `.gitignore` if they aren't already present:

```gitignore
# .NET
bin/
obj/
*.user
*.suo
*.userosscache
*.sln.docstates
packages/
*.nupkg
project.lock.json
```

### 4. Add pre-commit hooks

Append this repo to the existing `.pre-commit-config.yaml`:

```yaml
  - repo: https://github.com/dotnet/format
    rev: <latest tag>
    hooks:
      - id: dotnet-format
        args: ['--verbosity', 'minimal']
```

If no pre-commit hook is available for `dotnet format`, use a local hook instead:

```yaml
  - repo: local
    hooks:
      - id: dotnet-format
        name: dotnet format
        entry: dotnet format --verbosity minimal
        language: system
        types: [c#]
```

### 5. GitHub Actions workflow

Create or update the CI workflow to include .NET build, lint, and security scanning jobs that only run when C# files change. Use a separate workflow file (e.g., `.github/workflows/dotnet.yml`) with path filters, or add jobs to an existing workflow.

```yaml
name: .NET
on:
  push:
    paths: ['**/*.cs', '**/*.csproj', '**/*.sln', 'Directory.Build.props']
  pull_request:
    paths: ['**/*.cs', '**/*.csproj', '**/*.sln', 'Directory.Build.props']

jobs:
  build-and-lint:
    name: Build & Lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'
      - run: dotnet restore
      - run: dotnet build --no-restore /p:TreatWarningsAsErrors=true
      - run: dotnet format --verify-no-changes --verbosity minimal

  outdated:
    name: Dependency Audit
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'
      - run: dotnet tool install --global dotnet-outdated-tool
      - run: dotnet outdated
```

Adjust `dotnet-version` to match the project. Don't duplicate if .NET build jobs already exist. Look up latest action versions.

### 6. Verify

Run `dotnet build` to confirm analyzers are active and no warnings are emitted. Run `dotnet format --verify-no-changes` to confirm formatting.

## Important

- Do NOT overwrite existing configs. Read first and merge.
- If `.pre-commit-config.yaml` doesn't exist, tell the user to run `/setup-common` first.
- If the project uses a `.sln` file, ensure `dotnet format` targets the solution.
- Adjust the .NET SDK version in CI to match the project's target framework.
