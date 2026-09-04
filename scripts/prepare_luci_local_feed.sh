#!/bin/sh
set -eu

feed="${1:?usage: prepare_luci_local_feed.sh <local-feed-dir> <sdk-dir>}"
sdk="${2:?usage: prepare_luci_local_feed.sh <local-feed-dir> <sdk-dir>}"
version="${LUCI_PLUGIN_MODE_VERSION:-25.12.5_p1}"

legacy_luci_commit="${LUCI_LEGACY_COMMIT:-63ba3cba5b7bfb803a875d4d8f01248634687fd5}"
raw_luci="https://raw.githubusercontent.com/openwrt/luci/$legacy_luci_commit"
repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

pkg="$feed/applications/luci-app-shadowsocks-libev"

mkdir -p "$pkg/htdocs/luci-static/resources/view/shadowsocks-libev"
mkdir -p "$pkg/htdocs/luci-static/resources"
mkdir -p "$pkg/root/usr/share/luci/menu.d"
mkdir -p "$pkg/root/usr/share/rpcd/acl.d"
mkdir -p "$pkg/root/etc/uci-defaults"

[ -f "$sdk/feeds/luci/luci.mk" ] || {
	echo "missing $sdk/feeds/luci/luci.mk; run scripts/feeds update luci in the SDK first" >&2
	exit 1
}
cp "$sdk/feeds/luci/luci.mk" "$feed/luci.mk"

if [ -d "$sdk/feeds/luci/applications/luci-app-shadowsocks-libev" ]; then
	cp -a "$sdk/feeds/luci/applications/luci-app-shadowsocks-libev/." "$pkg/"
else
	curl -fsSL "$raw_luci/applications/luci-app-shadowsocks-libev/Makefile" -o "$pkg/Makefile"
	curl -fsSL "$raw_luci/applications/luci-app-shadowsocks-libev/htdocs/luci-static/resources/shadowsocks-libev.js" -o "$pkg/htdocs/luci-static/resources/shadowsocks-libev.js"
	curl -fsSL "$raw_luci/applications/luci-app-shadowsocks-libev/htdocs/luci-static/resources/view/shadowsocks-libev/instances.js" -o "$pkg/htdocs/luci-static/resources/view/shadowsocks-libev/instances.js"
	curl -fsSL "$raw_luci/applications/luci-app-shadowsocks-libev/htdocs/luci-static/resources/view/shadowsocks-libev/rules.js" -o "$pkg/htdocs/luci-static/resources/view/shadowsocks-libev/rules.js"
	curl -fsSL "$raw_luci/applications/luci-app-shadowsocks-libev/htdocs/luci-static/resources/view/shadowsocks-libev/servers.js" -o "$pkg/htdocs/luci-static/resources/view/shadowsocks-libev/servers.js"
	curl -fsSL "$raw_luci/applications/luci-app-shadowsocks-libev/root/usr/share/luci/menu.d/luci-app-shadowsocks-libev.json" -o "$pkg/root/usr/share/luci/menu.d/luci-app-shadowsocks-libev.json"
	curl -fsSL "$raw_luci/applications/luci-app-shadowsocks-libev/root/usr/share/rpcd/acl.d/luci-app-shadowsocks-libev.json" -o "$pkg/root/usr/share/rpcd/acl.d/luci-app-shadowsocks-libev.json"
	curl -fsSL "$raw_luci/applications/luci-app-shadowsocks-libev/root/etc/uci-defaults/40_luci-shadowsocks-libev" -o "$pkg/root/etc/uci-defaults/40_luci-shadowsocks-libev"
fi

python3 "$repo_root/scripts/patch_luci_plugin_mode.py" "$pkg/htdocs/luci-static/resources/shadowsocks-libev.js"

if grep -q '^PKG_VERSION:=' "$pkg/Makefile"; then
	sed -i "s/^PKG_VERSION:=.*/PKG_VERSION:=$version/" "$pkg/Makefile"
else
	sed -i "/^include \$(TOPDIR)\/rules.mk/a PKG_VERSION:=$version" "$pkg/Makefile"
fi

grep -n 'PKG_VERSION\|plugin_mode' "$pkg/Makefile" "$pkg/htdocs/luci-static/resources/shadowsocks-libev.js"
