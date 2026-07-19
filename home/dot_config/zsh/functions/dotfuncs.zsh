#!/bin/zsh
# shellcheck disable=SC1071
# List the custom shell functions installed by these dotfiles

dotfuncs() {
  local dir
  dir="$HOME/.config/zsh/functions"

  if [ ! -d "$dir" ]; then
    echo "dotfuncs: no functions directory at ${dir}" >&2
    return 1
  fi

  echo "Update commands:"
  _dotfuncs_list "$dir" up
  echo "\nOther commands:"
  _dotfuncs_list "$dir" other
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
