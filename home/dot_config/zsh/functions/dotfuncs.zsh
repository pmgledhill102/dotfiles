#!/bin/zsh
# shellcheck shell=bash
# List the custom shell functions and scripts installed by these dotfiles

dotfuncs() {
  local dir
  dir="$HOME/.config/zsh/functions"

  if [ ! -d "$dir" ]; then
    echo "dotfuncs: no functions directory at ${dir}" >&2
    return 1
  fi

  echo "Update commands:"
  _dotfuncs_list "$dir" up
  printf "\nOther commands:\n"
  _dotfuncs_list "$dir" other
  _dotfuncs_scripts "$HOME/.local/bin"
}

# Helper: print one group of functions. Mode 'up' selects the *up commands
# (the "bring something current" family); 'other' selects everything else.
_dotfuncs_list() {
  local dir="$1" mode="$2" file name desc

  for file in "$dir"/*.zsh; do
    [ -f "$file" ] || continue
    name="${file##*/}"
    name="${name%.zsh}"

    case "$name" in
      *up) [ "$mode" = "up" ]   || continue ;;
      *)   [ "$mode" = "other" ] || continue ;;
    esac

    # First comment line after the shebang and shellcheck pragma.
    desc=$(awk '
      /^#!/          { next }
      /^# shellcheck/ { next }
      /^#[[:space:]]/ {
        sub(/^#[[:space:]]*/, "")
        print
        exit
      }
    ' "$file")
    printf "  %-11s %s\n" "$name" "$desc"
  done
}

# Helper: print the standalone scripts these dotfiles install onto PATH. They
# aren't shell functions, so the loop above never sees them — but from the
# prompt they're the same thing: a command you can type.
_dotfuncs_scripts() {
  local dir="$1" file name desc found=0

  [ -d "$dir" ] || return 0

  for file in "$dir"/*; do
    # ~/.local/bin also holds the chezmoi binary and personal symlinks into
    # project checkouts. Requiring a regular file with a shebang keeps the list
    # to scripts this repo actually installs.
    [ -f "$file" ] && [ ! -L "$file" ] || continue
    head -n 1 "$file" | grep -q '^#!' || continue

    name="${file##*/}"

    # Same first-comment-line convention as the functions above, except these
    # open with "name — description", so the name is stripped to avoid
    # printing it twice.
    desc=$(awk -v n="$name" '
      /^#!/           { next }
      /^# shellcheck/ { next }
      /^#[[:space:]]/ {
        sub(/^#[[:space:]]*/, "")
        sub("^" n "[[:space:]]*[-—][[:space:]]*", "")
        # Match the sentence style of the function descriptions above.
        sub(/\.$/, "")
        print toupper(substr($0, 1, 1)) substr($0, 2)
        exit
      }
    ' "$file")
    [ -n "$desc" ] || continue

    [ "$found" -eq 1 ] || printf "\nScripts:\n"
    found=1
    printf "  %-21s %s\n" "$name" "$desc"
  done
}
