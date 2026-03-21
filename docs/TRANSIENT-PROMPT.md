# Transient Prompt

This document explains the transient prompt feature used in the zsh shell
configuration, which collapses previous prompts to a minimal symbol after
each command runs.

## What It Does

The full Starship prompt shows OS icon, username, directory, git info, and
more. A transient prompt replaces **previous** prompt lines with just the
prompt character (`󰄾`), keeping only the active prompt fully detailed. This
reduces visual noise in scrollback while preserving context where you need
it — on the current line.

**Before (without transient prompt):**

```text
 paul ~/dev/dotfiles  main ⇡1
󰄾 git status
 paul ~/dev/dotfiles  main
󰄾 echo hello
 paul ~/dev/dotfiles  main
󰄾 █
```

**After (with transient prompt):**

```text
󰄾 git status
󰄾 echo hello
 paul ~/dev/dotfiles  main
󰄾 █
```

## How It Works

Starship declares a `[transient_prompt]` config section, but as of v1.24.2
its `starship init zsh` does not wire up the ZLE hooks needed to activate it.
A custom ZLE (Zsh Line Editor) widget in `.zshrc` bridges the gap.

### The mechanism

After `starship init zsh` sets `$PROMPT` and `$RPROMPT`, the following code
saves those values and overrides the `accept-line` widget (the function zsh
calls when you press Enter):

```zsh
__starship_full_prompt=$PROMPT
__starship_full_rprompt=$RPROMPT

__starship_transient_accept_line() {
    PROMPT='$(starship module character)'
    RPROMPT=''
    zle reset-prompt          # redraws the CURRENT line with the minimal prompt
    PROMPT=$__starship_full_prompt
    RPROMPT=$__starship_full_rprompt
    zle .accept-line          # executes the command as normal
}
zle -N accept-line __starship_transient_accept_line
```

Step by step:

1. **Save** the full prompt strings that `starship init` created.
2. **Override `accept-line`** — this ZLE widget fires every time you press
   Enter.
3. When Enter is pressed:
   - Set `PROMPT` to just the Starship `character` module (`󰄾`).
   - Clear `RPROMPT` (removes duration, time, etc. from old lines).
   - Call `zle reset-prompt` — zsh redraws the **current** prompt line with
     the minimal version. The line is now committed to scrollback as minimal.
   - Restore the full `PROMPT` and `RPROMPT` so the **next** prompt line
     renders with all details.
   - Call `zle .accept-line` (note the `.` prefix — this calls the original
     built-in widget, not our override) to actually execute the command.

### Why `starship module character`?

Using `starship module character` renders the character symbol with its full
style (bold green on success, bold red on error). This keeps the collapsed
prompt visually consistent with the `[character]` section in
`starship.toml`, and means the transient prompt matches the
`[transient_prompt]` format defined there.

### Ordering matters

The `starship init zsh` call must happen **before** the transient prompt
code so that `$PROMPT` and `$RPROMPT` are already set when they are
captured. Both must happen **after** `source "$ZSH/oh-my-zsh.sh"` to avoid
Oh My Zsh overwriting the prompt.

### VS Code Copilot Chat terminal

The entire Starship + transient prompt block is wrapped in a guard:

```zsh
if [ -z "$VSCODE_COPILOT_CHAT_TERMINAL" ] || [ "$VSCODE_COPILOT_CHAT_TERMINAL" != "1" ]; then
```

This prevents prompt issues in VS Code's Copilot Chat terminal, which
manages its own prompt rendering.

## Configuration

### `starship.toml`

The `[transient_prompt]` and `[character]` sections define the appearance:

```toml
[character]
success_symbol = "[󰄾](bold green)"
error_symbol = "[󰄾](bold red)"
vicmd_symbol = "[❮](bold green)"

[transient_prompt]
format = "[󰄾](bold green) "
```

### `.zshrc`

The ZLE override described above must be present after `starship init zsh`.

## Future

If a future Starship release wires up `[transient_prompt]` natively in its
`starship init zsh` output, the custom ZLE code can be removed — the
`[transient_prompt]` config in `starship.toml` is already in place.
