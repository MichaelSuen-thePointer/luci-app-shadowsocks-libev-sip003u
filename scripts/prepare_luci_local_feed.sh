#!/bin/sh
set -eu

feed="${1:?usage: prepare_luci_local_feed.sh <local-feed-dir> <sdk-dir>}"
sdk="${2:?usage: prepare_luci_local_feed.sh <local-feed-dir> <sdk-dir>}"
version="${LUCI_PLUGIN_MODE_VERSION:-25.12.5_p2}"

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
vendor_pkg="$repo_root/vendor/openwrt-23.05/luci/applications/luci-app-shadowsocks-libev"

pkg="$feed/applications/luci-app-shadowsocks-libev"

[ -f "$sdk/feeds/luci/luci.mk" ] || {
	echo "missing $sdk/feeds/luci/luci.mk; run scripts/feeds update luci in the SDK first" >&2
	exit 1
}
mkdir -p "$feed"
cp "$sdk/feeds/luci/luci.mk" "$feed/luci.mk"

[ -f "$vendor_pkg/Makefile" ] || {
	echo "missing vendored LuCI package at $vendor_pkg" >&2
	exit 1
}

mkdir -p "$(dirname -- "$pkg")"
rm -rf "$pkg"
cp -a "$vendor_pkg" "$pkg"

python3 "$repo_root/scripts/patch_luci_plugin_mode.py" "$pkg/htdocs/luci-static/resources/shadowsocks-libev.js"

if grep -q '^PKG_VERSION:=' "$pkg/Makefile"; then
	sed -i "s/^PKG_VERSION:=.*/PKG_VERSION:=$version/" "$pkg/Makefile"
else
	sed -i "/^include \$(TOPDIR)\/rules.mk/a PKG_VERSION:=$version" "$pkg/Makefile"
fi

grep -n 'PKG_VERSION\|plugin_mode' "$pkg/Makefile" "$pkg/htdocs/luci-static/resources/shadowsocks-libev.js"
