#!/bin/sh
# This temporary packaging adapter uses dm.pl's built-in non-root archive
# ownership branch. It does not change host ownership or system IPC resources.
set -eu
case "$1" in
  -c) exit 0 ;;
  -r) shift ;;
  *) echo 'Unexpected Theos packaging adapter argument' >&2; exit 2 ;;
esac
case "$1" in
  dm.pl|/Users/chase/theos/bin/dm.pl) exec "$@" ;;
  *) echo 'Only the inspected dm.pl packer is allowed' >&2; exit 2 ;;
esac
