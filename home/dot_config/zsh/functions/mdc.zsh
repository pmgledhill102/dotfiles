#!/bin/zsh
# shellcheck shell=bash
# Render markdown in the terminal with mdcat (also: mdcp for paged output)
#
# bat is a syntax highlighter, not a renderer — it prints markdown bytes as
# they arrive, so a table piped from a CLI tool stays ragged. mdcat computes
# column widths at render time and aligns regardless of the source formatting.
#
# Primary use is `mytool | mdc`. mdcat reads stdin when given no filenames, so
# no explicit '-' is needed, and `mdc README.md` works from the same function.
#
# Static preferences (margin, theme, image protocol, full width) live in
# ~/.config/mdcat/config.toml so they apply however mdcat is invoked. Only
# --columns is set here, because it is the one setting that depends on whether
# a terminal is attached.
#
# 'mdc' rather than 'md': oh-my-zsh's core lib/directories.zsh always defines
# md='mkdir -p', and being core rather than a plugin it cannot be dropped by
# editing the plugins list in .zshrc.

if command -v mdcat >/dev/null 2>&1; then

  # Render markdown to the terminal.
  mdc() {
    if [[ -t 1 ]]; then
      # A terminal is attached: fill the window. config.toml's full_width does
      # this too, but passing $COLUMNS keeps the width correct when detection
      # is unreliable, such as inside a multiplexer.
      mdcat --columns "$COLUMNS" "$@"
    else
      # Redirected or piped onward: disable wrapping entirely, so the current
      # window width is not baked into a file. Without this mdcat falls back to
      # its 80-column default, full_width notwithstanding.
      mdcat --columns 0 "$@"
    fi
  }

  # Same, through a pager. Pagers do not pass graphics escape codes through, so
  # inline images degrade to plain ANSI here — that is why mdc, not mdcp, is
  # the default. --columns is explicit because stdout is the pager's pipe.
  mdcp() {
    mdcat --columns "$COLUMNS" --paginate "$@"
  }

fi
