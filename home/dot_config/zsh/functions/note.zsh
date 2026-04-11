#!/bin/zsh
# shellcheck disable=SC1071
# Quick project-scoped notes
#
# Notes are appended to ~/notes/<project>.md, where <project> is the git repo
# basename when inside a repo, or the current directory basename otherwise.
# Files are append-only via this command — use 'note -e' to edit in $EDITOR.
#
# Usage:
#   note "popd/pushd to navigate to/from a folder"   # append a note
#   note                                              # print current project's notes
#   note -e                                           # edit current project's notes in $EDITOR
#   n "..."                                           # short alias for note
#   notes                                             # list all note files
#   notes grep "pushd"                                # search across all notes

note() {
  local dir root name file
  dir="$HOME/notes"
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || root="$PWD"
  name="${root##*/}"
  [ -z "$name" ] && name="_root"
  file="$dir/${name}.md"

  # Edit mode: open current project's notes in $EDITOR
  if [ "$1" = "-e" ]; then
    mkdir -p "$dir"
    [ ! -f "$file" ] && printf '# %s\n\n' "$name" > "$file"
    ${EDITOR:-vi} "$file"
    return
  fi

  # No args: print the current project's notes
  if [ $# -eq 0 ]; then
    if [ -f "$file" ]; then
      cat "$file"
    else
      echo "No notes yet for ${name}. Add one with: note \"text\""
    fi
    return
  fi

  # Append mode: timestamped bullet
  mkdir -p "$dir"
  [ ! -f "$file" ] && printf '# %s\n\n' "$name" > "$file"
  printf -- '- %s — %s\n' "$(date '+%Y-%m-%d %H:%M')" "$*" >> "$file"
}

# Short alias for note
alias n='note'

# List or search across all note files
notes() {
  local dir="$HOME/notes"
  if [ ! -d "$dir" ]; then
    echo "No notes directory yet at ${dir}"
    return
  fi

  case "${1:-list}" in
    list|ls)
      ls -1 "$dir"
      ;;
    grep|g|search)
      shift
      if [ $# -eq 0 ]; then
        echo "Usage: notes grep <pattern>"
        return 1
      fi
      grep -rni --color=auto -- "$*" "$dir"
      ;;
    *)
      grep -rni --color=auto -- "$*" "$dir"
      ;;
  esac
}
