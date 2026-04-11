#!/bin/zsh
# shellcheck disable=SC1071
# List the custom shell functions installed by these dotfiles

dotfuncs() {
  local dir file name desc
  dir="$HOME/.config/zsh/functions"

  if [ ! -d "$dir" ]; then
    echo "dotfuncs: no functions directory at ${dir}" >&2
    return 1
  fi

  echo "Custom shell functions available:"
  for file in "$dir"/*.zsh; do
    [ -f "$file" ] || continue
    name="${file##*/}"
    name="${name%.zsh}"
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
