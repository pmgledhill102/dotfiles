#!/bin/zsh
# shellcheck shell=bash
# Open the Mac shortcut guide in the browser (dotguide md: in the terminal)

dotguide() {
  local dir="$HOME/.config/dotfiles/guide"

  case "${1:-}" in
    "")
      if [ ! -f "$dir/shortcuts.html" ]; then
        echo "dotguide: $dir/shortcuts.html not found; run 'chezmoi apply'." >&2
        return 1
      fi
      open "$dir/shortcuts.html"
      ;;
    md|--md|--markdown)
      if [ ! -f "$dir/shortcuts.md" ]; then
        echo "dotguide: $dir/shortcuts.md not found; run 'chezmoi apply'." >&2
        return 1
      fi
      # mdcp (from mdc.zsh) pages rendered Markdown; fall back to bat, then less.
      if command -v mdcp >/dev/null 2>&1; then
        mdcp "$dir/shortcuts.md"
      elif command -v bat >/dev/null 2>&1; then
        bat --language=markdown "$dir/shortcuts.md"
      else
        less "$dir/shortcuts.md"
      fi
      ;;
    -h|--help)
      echo "Usage: dotguide [md]"
      echo "  dotguide      Open the shortcut guide in the browser"
      echo "  dotguide md   Show the Markdown version in the terminal"
      ;;
    *)
      echo "dotguide: unknown option '$1' (try 'dotguide --help')" >&2
      return 1
      ;;
  esac
}
