#!/bin/sh
set -eu

sdk="${1:?usage: prepare_shadowsocks_libev_local_feed.sh <sdk-dir> <local-feed-dir> [commit]}"
feed="${2:?usage: prepare_shadowsocks_libev_local_feed.sh <sdk-dir> <local-feed-dir> [commit]}"
source_version="${3:-}"

pkg_version="${SHADOWSOCKS_LIBEV_VERSION:-3.3.6_p1}"
pkg_release="${SHADOWSOCKS_LIBEV_RELEASE:-1}"
source_url="${SHADOWSOCKS_LIBEV_SOURCE_URL:-https://github.com/MichaelSuen-thePointer/shadowsocks-libev.git}"
ss_rules_ip_dep="${SS_RULES_IP_DEP:-ip-tiny}"
repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
vendor_pkg="$repo_root/vendor/openwrt-23.05/packages/net/shadowsocks-libev"

pkg="$feed/net/shadowsocks-libev"

if [ -z "$source_version" ]; then
	# Head of feature/sip003u after its 2026-09-04 force-push, pinned for repeatability.
	source_version="d2ae22a3c85a66944535177425042307db71b5be"
fi

mkdir -p "$feed/net"
rm -rf "$pkg"
[ -f "$vendor_pkg/Makefile" ] || {
	echo "missing vendored shadowsocks-libev package at $vendor_pkg" >&2
	exit 1
}
cp -a "$vendor_pkg" "$pkg"

# The force-pushed SIP003U branch is CMake based and already uses PCRE2.
rm -f "$pkg/patches/100-Upgrade-PCRE-to-PCRE2.patch"

# The package disappeared before OpenWrt 25.12. Keep the last official package
# layout, but always install this repository's SIP003U-aware init script.
cp "$repo_root/files/shadowsocks-libev.init" "$pkg/files/shadowsocks-libev.init"
chmod 0755 "$pkg/files/shadowsocks-libev.init"

python3 "$repo_root/scripts/patch_shadowsocks_libev_package.py" \
	"$pkg/Makefile" \
	--pkg-version "$pkg_version" \
	--pkg-release "$pkg_release" \
	--source-url "$source_url" \
	--source-version "$source_version" \
	--ss-rules-ip-dep "$ss_rules_ip_dep"

for required in \
	"$pkg/files/ss-rules/ss-rules.uc" \
	"$pkg/files/ss-rules/set.uc" \
	"$pkg/files/ss-rules/chain.uc"
do
	[ -f "$required" ] || {
		echo "missing required packaging file: $required" >&2
		exit 1
	}
done

grep -n 'PKG_VERSION\|PKG_RELEASE\|PKG_SOURCE_PROTO\|PKG_SOURCE_URL\|PKG_SOURCE_VERSION\|PKG_MIRROR_HASH\|+ip' "$pkg/Makefile"
grep -q '+shadowsocks-libev-ss-redir' "$pkg/Makefile" || {
	echo "ss-rules is missing its ss-redir dependency" >&2
	exit 1
}
find "$pkg/files/ss-rules" -maxdepth 1 -type f -print | sort
