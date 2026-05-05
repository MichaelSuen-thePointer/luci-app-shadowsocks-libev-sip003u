#!/bin/sh
set -eu

sdk="${1:?usage: build_luci_ipk.sh <sdk-dir> <local-feed-dir>}"
feed="${2:?usage: build_luci_ipk.sh <sdk-dir> <local-feed-dir>}"

cd "$sdk"

cat > feeds.conf.default <<EOF
src-link local $feed
src-git-full base https://git.openwrt.org/openwrt/openwrt.git;openwrt-23.05
src-git packages https://git.openwrt.org/feed/packages.git^b5ed85f6e94aa08de1433272dc007550f4a28201
src-git luci https://git.openwrt.org/project/luci.git^63ba3cba5b7bfb803a875d4d8f01248634687fd5
EOF

./scripts/feeds update local base packages luci
./scripts/feeds install -p local luci-app-shadowsocks-libev

cat > .config <<'EOF'
CONFIG_PACKAGE_luci-app-shadowsocks-libev=m
EOF

make defconfig
make package/feeds/local/luci-app-shadowsocks-libev/compile V=s

find bin/packages -name 'luci-app-shadowsocks-libev_*.ipk' -print
