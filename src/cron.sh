#!/bin/sh

. "$(dirname "$(readlink -f "$0")")"/main.inc.sh || exit 1

main "$@"
