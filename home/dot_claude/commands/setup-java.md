Set up Java linting, formatting, and dependency auditing for this project. Assumes `/setup-common` has already been run (pre-commit framework is in place).

## What to install and configure

### 1. google-java-format / spotless

If the project uses **Gradle**, add the Spotless plugin to `build.gradle` or `build.gradle.kts`:

```kotlin
plugins {
    id("com.diffplug.spotless") version "<latest>"
}

spotless {
    java {
        googleJavaFormat()
        removeUnusedImports()
        trimTrailingWhitespace()
        endWithNewline()
    }
}
```

If the project uses **Maven**, add the Spotless plugin to `pom.xml`:

```xml
<plugin>
    <groupId>com.diffplug.spotless</groupId>
    <artifactId>spotless-maven-plugin</artifactId>
    <version>LATEST</version>
    <configuration>
        <java>
            <googleJavaFormat/>
            <removeUnusedImports/>
            <trimTrailingWhitespace/>
            <endWithNewline/>
        </java>
    </configuration>
</plugin>
```

Look up the latest stable version of the Spotless plugin.

### 2. Checkstyle

Create `checkstyle.xml` in the project root (if it doesn't already exist) or use Google's published config:

```xml
<!DOCTYPE module PUBLIC
    "-//Checkstyle//DTD Checkstyle Configuration 1.3//EN"
    "https://checkstyle.org/dtds/configuration_1_3.dtd">
<module name="Checker">
    <module name="TreeWalker">
        <module name="GoogleStyle"/>
    </module>
</module>
```

For most projects, using the Google style checkstyle config via Spotless is sufficient. Only add standalone checkstyle if the project has custom rules.

### 3. SpotBugs / PMD

If the project uses Gradle, add:

```kotlin
plugins {
    id("com.github.spotbugs") version "<latest>"
    id("pmd")
}

pmd {
    isConsoleOutput = true
    ruleSetFiles = files("pmd-ruleset.xml")
}
```

If these are too noisy for an existing codebase, start with Spotless formatting only and add linters incrementally.

### 4. .gitignore

Append these lines to `.gitignore` if they aren't already present:

```gitignore
# Java
*.class
*.jar
*.war
*.ear
target/
build/
.gradle/
out/
*.iml
.idea/
```

### 5. Add pre-commit hooks

Append this repo to the existing `.pre-commit-config.yaml`:

```yaml
  - repo: local
    hooks:
      - id: spotless-check
        name: spotless check
        entry: ./gradlew spotlessCheck
        language: system
        types: [java]
        pass_filenames: false
```

For Maven projects, use `mvn spotless:check` as the entry instead.

### 6. GitHub Actions workflow

Create or update the CI workflow to include Java linting and dependency auditing jobs that only run when Java files change. Use a separate workflow file (e.g., `.github/workflows/java.yml`) with path filters, or add jobs to an existing workflow.

```yaml
name: Java
on:
  push:
    paths: ['**/*.java', 'build.gradle*', 'pom.xml', 'settings.gradle*']
  pull_request:
    paths: ['**/*.java', 'build.gradle*', 'pom.xml', 'settings.gradle*']

jobs:
  lint:
    name: Spotless & Lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '21'
      - run: ./gradlew spotlessCheck
      - run: ./gradlew check

  dependency-check:
    name: OWASP Dependency Check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '21'
      - uses: dependency-check/Dependency-Check_Action@main
        with:
          project: '${{ github.repository }}'
          path: '.'
          format: 'HTML'
```

Adjust for Maven if the project uses `pom.xml` instead of Gradle. Don't duplicate if Java lint jobs already exist. Look up latest action versions.

### 7. Dependabot ecosystem

Read `.github/dependabot.yml` and add the `maven` ecosystem entry if it isn't already present. Don't duplicate entries.

```yaml
  - package-ecosystem: "maven"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
    commit-message:
      prefix: "deps"
      include: "scope"
    labels:
      - "dependencies"
      - "java"
    open-pull-requests-limit: 5
```

If the project uses Gradle instead of Maven, use `gradle` as the `package-ecosystem` value.

### 8. Verify

Run `./gradlew spotlessCheck` (or `mvn spotless:check`) to confirm formatting. Fix any issues with `./gradlew spotlessApply`.

## Important

- Do NOT overwrite existing configs. Read first and merge.
- If `.pre-commit-config.yaml` doesn't exist, tell the user to run `/setup-common` first.
- Ask the user whether the project uses Gradle or Maven before configuring.
- Adjust the Java version in CI to match the project's target.
