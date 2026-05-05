#!/bin/sh
set -eu

sdk="${1:?usage: prepare_shadowsocks_libev_local_feed.sh <sdk-dir> <local-feed-dir> [commit]}"
feed="${2:?usage: prepare_shadowsocks_libev_local_feed.sh <sdk-dir> <local-feed-dir> [commit]}"
source_version="${3:-}"

pkg_version="${SHADOWSOCKS_LIBEV_VERSION:-3.3.6+sip003u}"
pkg_release="${SHADOWSOCKS_LIBEV_RELEASE:-1}"
source_url="${SHADOWSOCKS_LIBEV_SOURCE_URL:-https://github.com/MichaelSuen-thePointer/shadowsocks-libev.git}"
ss_rules_ip_dep="${SS_RULES_IP_DEP:-ip-tiny}"
repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

src_pkg="$sdk/feeds/packages/net/shadowsocks-libev"
pkg="$feed/net/shadowsocks-libev"

[ -d "$src_pkg" ] || {
	echo "missing $src_pkg; run scripts/feeds update packages in the SDK first" >&2
	exit 1
}

if [ -z "$source_version" ]; then
	source_version="9217f6e08b31c5ded469f99f59e0b863bb78c447"
fi

mkdir -p "$feed/net"
rm -rf "$pkg"
cp -a "$src_pkg" "$pkg"

python3 "$repo_root/scripts/patch_shadowsocks_libev_package.py" \
	"$pkg/Makefile" \
	--pkg-version "$pkg_version" \
	--pkg-release "$pkg_release" \
	--source-url "$source_url" \
	--source-version "$source_version" \
	--ss-rules-ip-dep "$ss_rules_ip_dep"

for required in \
	"$pkg/patches/100-Upgrade-PCRE-to-PCRE2.patch" \
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
find "$pkg/files/ss-rules" -maxdepth 1 -type f -print | sort
