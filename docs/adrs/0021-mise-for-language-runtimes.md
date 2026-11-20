# ADR-0021: mise for language runtimes (Node, Java)

- **Status**: Accepted
- **Scope**: Repo. This record binds `dotfiles` only: it decides how this
  repo installs and switches Node and Java versions.
- **Date**: 2026-11-20
- **Tags**: packages, languages, shell
- **Refs**: [#518](https://github.com/pmgledhill102/dotfiles/issues/518),
  [#511](https://github.com/pmgledhill102/dotfiles/issues/511)

## Context

Node and Java versions were managed by two tools, one per language:

- **nvm**, installed by Homebrew on macOS and by its own installer on Linux.
  `.zshrc` sources `nvm.sh` on every shell start, which is its best-known cost.
  The npm-globals script also relied on nvm to install global CLIs.
- **jenv**, installed by Homebrew, which runs `jenv init` on every shell start.
  Only one JDK (Homebrew's `openjdk`) was installed, so there was nothing for
  it to switch between.

The first [ADR-0020](0020-tool-selection-criteria.md) review (#511) found both
failing **1 Lightweight** and **5 No duplicates**. Homebrew also installs a
second Node as a dependency of the linters, so nvm duplicated that too.

Java and Node are used lightly here. What's needed is a sensible default
version of each, plus a per-project version when a repo pins one.

Single-language managers are giving way to one tool for all runtimes. Volta's
README now says it is unmaintained and recommends mise. In Homebrew's figures
for the last 365 days, mise had about 850,000 installs, against roughly
510,000 for nvm, 94,000 for asdf, 71,000 for fnm and 36,000 for jenv.

## Decision

**mise manages Node, Java and npm CLIs on macOS, personal Linux and work
Linux.** It replaces nvm and jenv, and Homebrew's explicit `openjdk` line.

- **Global config:** `~/.config/mise/config.toml` (source
  `home/dot_config/mise/config.toml.tmpl`) is owned by chezmoi. It sets:
  - `node = "lts"` and `java = "temurin-25"`, the current LTS of each;
  - the CLIs from `[data.packages.npm]`, as `npm:` tools, so they survive a
    Node upgrade;
  - `idiomatic_version_file_enable_tools = ["node", "java"]`, so existing
    `.nvmrc`, `.node-version`, `.java-version` and `.sdkmanrc` files are read.
- **Project versions:** live in each project's `mise.toml`, written by
  `mise use`. Global versions change in the chezmoi source, never with
  `mise use -g`, which edits the target copy that the next apply overwrites.
- **Install:**
  - macOS and personal Linux get mise from the Brewfile.
  - Work Linux gets it from the official `mise.run` installer, pinned with
    `MISE_VERSION`, into `~/.local/bin`.
  - Minimal machines and Windows get none of it.
- **Tools:** `run_onchange_after_install-mise-tools.sh` runs `mise install`
  whenever the config or the npm list changes.
- **Shell:** `.zshrc` runs `eval "$(mise activate zsh)"`, a hook that adjusts
  `PATH` per directory, with no shims.

### Scope: runtimes, not packages

[ADR-0004](0004-native-package-managers-per-platform.md) and
[ADR-0017](0017-homebrew-on-personal-linux.md) rejected mise as a
**whole-machine package manager**, and that still holds. Here mise only
switches language runtimes, the job nvm and jenv did. Homebrew, apt and
winget still install everything else.

Other languages stay as they are:

- **Python:** uv.
- **Go and .NET:** Homebrew.
- **Terraform:** tenv.

Moving any of these to mise is a separate decision.

## Consequences

- **Faster shell start:** one activation hook replaces sourcing `nvm.sh` and
  running `jenv init`.
- **One tool:** a single tool and config file for both runtimes, which
  passes all seven ADR-0020 criteria.
- **Global CLIs survive upgrades:** `clasp` and any later npm CLI no longer
  vanish when Node's LTS moves on, which was a quiet failure of
  `npm install -g` under nvm.
- **Java default:** Temurin 25 from mise, instead of Homebrew's `openjdk`.
  gradle and maven still pull `openjdk` in as a Homebrew dependency for their
  own use.
- **Larger first apply:** it downloads a JDK and a Node release, a few
  hundred MB.
- **Manual clean-up on existing machines:** chezmoi doesn't remove what
  earlier applies installed, so `~/.nvm`, `~/.jenv` and the Homebrew `nvm`
  and `jenv` formulae stay until removed by hand.

## Alternatives considered

- **Keep nvm and jenv.** Rejected: they fail ADR-0020 on startup cost and
  duplication, for little use.
- **fnm for Node and SDKMAN for Java.** Both are fast and well regarded, but
  that is still two tools for one job, and SDKMAN is a bash script sourced
  at startup.
- **Homebrew's `node` and `openjdk` only, with no version manager.**
  Lightest of all, but it can't follow a project's `.nvmrc`. A project that
  pins a version would bring the problem back.
- **asdf.** It works the same way through plugins, but is slower, less used,
  and doesn't read `.nvmrc` without a plugin setting.
- **Volta.** Unmaintained, by its own README.
