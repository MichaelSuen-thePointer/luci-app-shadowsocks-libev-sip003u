#!/bin/sh
set -eu

echo "OpenWrt 25.12 uses APK; forwarding to build_luci_apk.sh" >&2
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
exec "$script_dir/build_luci_apk.sh" "$@"
