#!/bin/sh
set -eu

sdk="${1:?usage: build_luci_apk.sh <sdk-dir> <local-feed-dir>}"
feed="${2:?usage: build_luci_apk.sh <sdk-dir> <local-feed-dir>}"
jobs="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '1')}"

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

"$repo_root/scripts/configure_sdk_feeds.sh" "$sdk" "$feed"

cd "$sdk"
./scripts/feeds update base luci

if [ ! -f "$feed/applications/luci-app-shadowsocks-libev/Makefile" ]; then
	"$repo_root/scripts/prepare_luci_local_feed.sh" "$feed" "$sdk"
fi

./scripts/feeds update local
./scripts/feeds install -p local luci-app-shadowsocks-libev

cat > .config <<'EOF'
# CONFIG_ALL is not set
# CONFIG_ALL_NONSHARED is not set
# CONFIG_ALL_KMODS is not set
CONFIG_PACKAGE_luci-app-shadowsocks-libev=m
EOF

make defconfig
make -j"$jobs" package/feeds/local/luci-app-shadowsocks-libev/compile V=s

find bin/packages -type f -name 'luci-app-shadowsocks-libev-*.apk' -print
