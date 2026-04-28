#!/bin/zsh
# shellcheck disable=SC1071
# Deprecated alias — 'dotbrew' was renamed to 'brewup'. Remove after one release cycle

dotbrew() {
  echo "==> 'dotbrew' has been renamed to 'brewup' — running brewup; update your muscle memory." >&2
  brewup "$@"
}
