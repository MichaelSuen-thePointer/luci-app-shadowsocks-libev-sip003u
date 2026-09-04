#!/bin/sh
set -eu

sdk="${1:?usage: configure_sdk_feeds.sh <sdk-dir> <local-feed-dir>}"
feed="${2:?usage: configure_sdk_feeds.sh <sdk-dir> <local-feed-dir>}"

[ -f "$sdk/feeds.conf.default" ] || {
	echo "missing $sdk/feeds.conf.default" >&2
	exit 1
}

grep -Eq 'VERSION_NUMBER\),25\.12([.][0-9]+)?\)' "$sdk/include/version.mk" || {
	echo "the SDK at $sdk is not an OpenWrt 25.12 SDK" >&2
	exit 1
}

feeds_tmp="$sdk/feeds.conf.sip003u.$$"
trap 'rm -f "$feeds_tmp"' EXIT HUP INT TERM

{
	printf 'src-link local %s\n' "$feed"
	grep -v '^src-link local ' "$sdk/feeds.conf.default"
} > "$feeds_tmp"

mv "$feeds_tmp" "$sdk/feeds.conf"
trap - EXIT HUP INT TERM
