#!/bin/sh
set -eu

sdk="${1:?usage: build_all_apks.sh <sdk-dir> <local-feed-dir> [shadowsocks-libev-commit]}"
feed="${2:?usage: build_all_apks.sh <sdk-dir> <local-feed-dir> [shadowsocks-libev-commit]}"
source_version="${3:-}"
jobs="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '1')}"

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

"$repo_root/scripts/configure_sdk_feeds.sh" "$sdk" "$feed"

cd "$sdk"
./scripts/feeds update base packages luci

"$repo_root/scripts/prepare_luci_local_feed.sh" "$feed" "$sdk"
"$repo_root/scripts/prepare_shadowsocks_libev_local_feed.sh" "$sdk" "$feed" "$source_version"

./scripts/feeds update local
./scripts/feeds install -p local luci-app-shadowsocks-libev shadowsocks-libev
./scripts/feeds install pcre2 c-ares libev mbedtls libsodium iproute2 firewall4 resolveip ucode ucode-mod-fs

cat > .config <<'EOF'
# CONFIG_ALL is not set
# CONFIG_ALL_NONSHARED is not set
# CONFIG_ALL_KMODS is not set
CONFIG_PACKAGE_luci-app-shadowsocks-libev=m
CONFIG_PACKAGE_shadowsocks-libev-config=m
CONFIG_PACKAGE_shadowsocks-libev-ss-rules=m
CONFIG_PACKAGE_shadowsocks-libev-ss-local=m
CONFIG_PACKAGE_shadowsocks-libev-ss-redir=m
CONFIG_PACKAGE_shadowsocks-libev-ss-server=m
CONFIG_PACKAGE_shadowsocks-libev-ss-tunnel=m
EOF

make defconfig
make -j"$jobs" package/feeds/local/luci-app-shadowsocks-libev/compile V=s
make -j"$jobs" package/feeds/local/shadowsocks-libev/compile V=s

find bin/packages -type f \( \
	-name 'luci-app-shadowsocks-libev-*.apk' -o \
	-name 'shadowsocks-libev-*.apk' \
\) -print | sort
