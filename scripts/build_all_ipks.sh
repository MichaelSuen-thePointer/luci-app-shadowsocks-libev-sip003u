#!/bin/sh
set -eu

sdk="${1:?usage: build_all_ipks.sh <sdk-dir> <local-feed-dir> [shadowsocks-libev-commit]}"
feed="${2:?usage: build_all_ipks.sh <sdk-dir> <local-feed-dir> [shadowsocks-libev-commit]}"
source_version="${3:-}"

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

cd "$sdk"

cat > feeds.conf.default <<EOF
src-link local $feed
src-git-full base https://git.openwrt.org/openwrt/openwrt.git;openwrt-23.05
src-git packages https://git.openwrt.org/feed/packages.git^b5ed85f6e94aa08de1433272dc007550f4a28201
src-git luci https://git.openwrt.org/project/luci.git^63ba3cba5b7bfb803a875d4d8f01248634687fd5
EOF

./scripts/feeds update base packages luci

"$repo_root/scripts/prepare_luci_local_feed.sh" "$feed" "$sdk"
"$repo_root/scripts/prepare_shadowsocks_libev_local_feed.sh" "$sdk" "$feed" "$source_version"

./scripts/feeds update local
./scripts/feeds install -p local luci-app-shadowsocks-libev shadowsocks-libev
./scripts/feeds install pcre2 c-ares libev mbedtls libsodium iproute2 firewall4 resolveip ucode ucode-mod-fs

cat > .config <<'EOF'
CONFIG_PACKAGE_luci-app-shadowsocks-libev=m
CONFIG_PACKAGE_shadowsocks-libev-config=m
CONFIG_PACKAGE_shadowsocks-libev-ss-local=m
CONFIG_PACKAGE_shadowsocks-libev-ss-redir=m
CONFIG_PACKAGE_shadowsocks-libev-ss-rules=m
CONFIG_PACKAGE_shadowsocks-libev-ss-server=m
CONFIG_PACKAGE_shadowsocks-libev-ss-tunnel=m
EOF

make defconfig
make package/feeds/local/luci-app-shadowsocks-libev/compile V=s
make package/feeds/local/shadowsocks-libev/compile V=s

find bin/packages -path '*/local/*shadowsocks-libev*.ipk' -o -path '*/local/luci-app-shadowsocks-libev*.ipk' | sort
