#!/bin/sh
set -eu

feed="${1:?usage: prepare_luci_local_feed.sh <local-feed-dir>}"
version="${LUCI_PLUGIN_MODE_VERSION:-git-25.222.75657-7ce34fe+sip003u}"

raw_luci="https://raw.githubusercontent.com/openwrt/luci/openwrt-23.05"
repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

pkg="$feed/applications/luci-app-shadowsocks-libev"

mkdir -p "$pkg/htdocs/luci-static/resources/view/shadowsocks-libev"
mkdir -p "$pkg/htdocs/luci-static/resources"
mkdir -p "$pkg/root/usr/share/luci/menu.d"
mkdir -p "$pkg/root/usr/share/rpcd/acl.d"

curl -fsSL "$raw_luci/luci.mk" -o "$feed/luci.mk"
curl -fsSL "$raw_luci/applications/luci-app-shadowsocks-libev/Makefile" -o "$pkg/Makefile"
curl -fsSL "$raw_luci/applications/luci-app-shadowsocks-libev/htdocs/luci-static/resources/shadowsocks-libev.js" -o "$pkg/htdocs/luci-static/resources/shadowsocks-libev.js"
curl -fsSL "$raw_luci/applications/luci-app-shadowsocks-libev/htdocs/luci-static/resources/view/shadowsocks-libev/instances.js" -o "$pkg/htdocs/luci-static/resources/view/shadowsocks-libev/instances.js"
curl -fsSL "$raw_luci/applications/luci-app-shadowsocks-libev/htdocs/luci-static/resources/view/shadowsocks-libev/rules.js" -o "$pkg/htdocs/luci-static/resources/view/shadowsocks-libev/rules.js"
curl -fsSL "$raw_luci/applications/luci-app-shadowsocks-libev/htdocs/luci-static/resources/view/shadowsocks-libev/servers.js" -o "$pkg/htdocs/luci-static/resources/view/shadowsocks-libev/servers.js"
curl -fsSL "$raw_luci/applications/luci-app-shadowsocks-libev/root/usr/share/luci/menu.d/luci-app-shadowsocks-libev.json" -o "$pkg/root/usr/share/luci/menu.d/luci-app-shadowsocks-libev.json"
curl -fsSL "$raw_luci/applications/luci-app-shadowsocks-libev/root/usr/share/rpcd/acl.d/luci-app-shadowsocks-libev.json" -o "$pkg/root/usr/share/rpcd/acl.d/luci-app-shadowsocks-libev.json"

python3 "$repo_root/scripts/patch_luci_plugin_mode.py" "$pkg/htdocs/luci-static/resources/shadowsocks-libev.js"

if grep -q '^PKG_VERSION:=' "$pkg/Makefile"; then
	sed -i "s/^PKG_VERSION:=.*/PKG_VERSION:=$version/" "$pkg/Makefile"
else
	sed -i "/^include \$(TOPDIR)\/rules.mk/a PKG_VERSION:=$version" "$pkg/Makefile"
fi

grep -n 'PKG_VERSION\|plugin_mode' "$pkg/Makefile" "$pkg/htdocs/luci-static/resources/shadowsocks-libev.js"
