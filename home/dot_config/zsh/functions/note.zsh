#!/bin/zsh
# shellcheck disable=SC1071
# Quick project-scoped notes (also: notes, n alias)
#
# Notes are appended to ~/notes/<project>.md, where <project> is the git repo
# basename when inside a repo, or the current directory basename otherwise.
# Files are append-only via this command — use 'note -e' / 'note --edit' to
# edit in $EDITOR.

# Shared help text, printed by both 'note -h' and 'notes -h'.
_note_help() {
  cat <<'EOF'
note  — append, print, or edit project-scoped notes
notes — list or search across all note files

USAGE
  note [text...]                 Append a note to the current project's file
  note                           Print the current project's notes
  note -e, --edit                Edit the current project's notes in $EDITOR
  note -h, --help, -?            Show this help
  note -- text...                Append text that starts with a dash

  notes                          List all note files
  notes ls                       Same as 'notes'
  notes grep <pattern>           Search across all notes (case-insensitive)
  notes <pattern>                Shorthand for 'notes grep <pattern>'
  notes -h, --help, -?           Show this help

STORAGE
  Notes are stored at ~/notes/<project>.md where <project> is the git repo
  basename (falls back to the cwd basename outside a repo, or '_root' at /).
  Files are Markdown, timestamped per bullet, append-only via this command.
  Use 'note -e' to edit or delete entries in $EDITOR.

ALIASES
  n <text>                       Short alias for 'note'
EOF
}

note() {
  local dir root name file edit_mode=0
  dir="$HOME/notes"

  # Option parsing: standard GNU-style with -h/--help, -e/--edit, and '--'
  # end-of-options separator so notes can start with a dash.
  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help|-\?)
        _note_help
        return 0
        ;;
      -e|--edit)
        edit_mode=1
        shift
        ;;
      --)
        shift
        break
        ;;
      -*)
        echo "note: unknown option: $1" >&2
        echo "Try 'note --help' for usage." >&2
        return 1
        ;;
      *)
        break
        ;;
    esac
  done

  root="$(git rev-parse --show-toplevel 2>/dev/null)" || root="$PWD"
  name="${root##*/}"
  [ -z "$name" ] && name="_root"
  file="$dir/${name}.md"

  # Edit mode: open current project's notes in $EDITOR
  if [ "$edit_mode" -eq 1 ]; then
    mkdir -p "$dir"
    [ ! -f "$file" ] && printf '# %s\n\n' "$name" > "$file"
    ${EDITOR:-vi} "$file"
    return
  fi

  # No remaining args: print the current project's notes
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
  local dir
  dir="$HOME/notes"

  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help|-\?)
        _note_help
        return 0
        ;;
      --)
        shift
        break
        ;;
      -*)
        echo "notes: unknown option: $1" >&2
        echo "Try 'notes --help' for usage." >&2
        return 1
        ;;
      *)
        break
        ;;
    esac
  done

  if [ ! -d "$dir" ]; then
    echo "notes: no notes directory yet at ${dir}" >&2
    return 1
  fi

  case "${1:-list}" in
    list|ls)
      ls -1 "$dir"
      ;;
    grep|g|search)
      shift
      if [ $# -eq 0 ]; then
        echo "notes: grep requires a pattern" >&2
        echo "Usage: notes grep <pattern>" >&2
        return 1
      fi
      grep -rni --color=auto -- "$*" "$dir"
      ;;
    *)
      grep -rni --color=auto -- "$*" "$dir"
      ;;
  esac
}
