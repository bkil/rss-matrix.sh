#!/bin/sh
set +u
if [ -z "$_INCLUDED_MATRIX_INC_SH" ]; then
  _INCLUDED_MATRIX_INC_SH=1
  . "$(dirname "$(readlink -f "$0")")"/matrix-pure.inc.sh || exit 1
fi
set -u

matrix_init() {
  local MAINFUN TOKENFILE MATRIXHS MATRIXTOKEN
  readonly MAINFUN=$1
  shift 1

  TOKENFILE="$HOME/.rss-matrix.secret.cfg"

  if ! [ -f "$TOKENFILE" ]; then
    echo "error: Please fill in $TOKENFILE" >&2

    printf "%s" \
'MATRIXHS="matrix-client.matrix.org"
MATRIXTOKEN="" # copy from User menu -> All settings -> Help & About -> Advanced -> Access Token
' |
    tee "$TOKENFILE"

    return 1
  fi
  if ! . "$TOKENFILE"; then
    echo "error processing $TOKENFILE" >&2
    return 1
  fi
  if ! [ -n "$MATRIXTOKEN" ]; then
    echo "error: missing MATRIXTOKEN from $TOKENFILE" >&2
    return 1
  fi

  if ! [ -n "$MATRIXHS" ]; then
    echo "error: missing MATRIXHS from $TOKENFILE" >&2
    return 1
  fi

  # TODO: determine $MATRIXHS from naked $DOMAIN/.well-known/matrix/client

  unset TOKENFILE
  $MAINFUN "$@"
}

matrix_send_json() {
  local ROOM JSON
  readonly ROOM="$1"
  readonly JSON="$2"

  matrix_api_post \
    "r0/rooms/$ROOM/send/m.room.message" \
    -d "$JSON" >&2
}

matrix_redact() {
  local ROOM ID TX
  readonly ROOM="$1"
  readonly ID="$2"
  readonly TX="`date +%s.%N`"

  matrix_api_put \
    "v3/rooms/$ROOM/redact/$ID/$TX" \
    -d "{\"reason\":\"unimportant\"}"
}

matrix_api_put() {
  matrix_api \
    "$@" \
    -XPUT
}

matrix_api_post() {
  matrix_api \
    "$@" \
    -XPOST
}

matrix_api() {
  local MXOP
  readonly MXOP="$1"
  shift 1

  curl \
    -A- \
    --globoff \
    "$@" \
    "https://$MATRIXHS/_matrix/client/$MXOP?access_token=$MATRIXTOKEN"
}
