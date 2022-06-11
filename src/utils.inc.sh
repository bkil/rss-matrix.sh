#!/bin/sh
set -u

get_lock_path() {
  local LOCKP VARP BASE
  readonly VARP="$1"
  readonly BASE="$2"

  for LOCKP in \
    "/run/user/`id -u`" \
    "/run/lock" \
    "/run/shm" \
    "/dev/shm" \
    "$VARP" \
    "."
  do
    if
      [ -w "$LOCKP" ]
    then
      echo "$LOCKP/$BASE"
      return
    fi
  done
}

get_file_time() {
  ls --no-group --time-style=+%s -l "$@" 2>/dev/null |
  cut -d ' ' -f 5
}
