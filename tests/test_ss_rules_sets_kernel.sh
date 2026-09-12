#!/bin/sh
# Run ONLY in an empty disposable network namespace:
# unshare -Urn sh tests/test_ss_rules_sets_kernel.sh
set -eu
repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
asset="$repo_root/vendor/openwrt-23.05/packages/net/shadowsocks-libev/files/ss-rules-sets.nft"
[ -z "$(nft list tables)" ] || { echo 'Refusing non-empty namespace' >&2; exit 1; }
tmp="$(mktemp -d)"
trap 'nft delete table inet fw4; rm -rf "$tmp"' EXIT
nft add table inet fw4
nft 'add set inet fw4 unrelated { type ipv4_addr; elements = { 192.0.2.9 }; }'
{
 cat "$asset"
 echo 'add element inet fw4 ss_rules_dst_bypass { 104.16.0.0/13, 104.24.0.0/14, 172.64.0.0/13 }'
 echo 'add element inet fw4 ss_rules6_dst_bypass { 2606:4700::/32 }'
} | nft -f -
# Exactly fw4 ordering: table flush, ruleset-pre asset, ordinary declarations.
{
 echo 'flush table inet fw4'
 cat "$asset"
 echo 'table inet fw4 {'
 echo 'set ss_rules_dst_bypass { type ipv4_addr; flags interval; auto-merge; elements = { 172.64.229.91 }; }'
 echo 'set ss_rules6_dst_bypass { type ipv6_addr; flags interval; auto-merge; elements = { 2606:4700::1234 }; }'
 echo '}'
} > "$tmp/normal.nft"
for iteration in 1 2; do
 nft -f "$tmp/normal.nft"
 nft 'get element inet fw4 ss_rules_dst_bypass { 172.64.229.91 }' >/dev/null
 nft 'get element inet fw4 ss_rules6_dst_bypass { 2606:4700::1234 }' >/dev/null
 if nft 'get element inet fw4 ss_rules_dst_bypass { 104.18.32.47 }' >/dev/null 2>&1; then exit 1; fi
 if nft 'get element inet fw4 ss_rules6_dst_bypass { 2606:4700::5678 }' >/dev/null 2>&1; then exit 1; fi
 nft 'get element inet fw4 unrelated { 192.0.2.9 }' >/dev/null
 done
# A failed transaction must leave the previous working sets intact.
{
 cat "$asset"
 echo 'add rule inet fw4 missing_chain accept'
} > "$tmp/failure.nft"
if nft -f "$tmp/failure.nft" 2>"$tmp/expected-error"; then exit 1; fi
nft 'get element inet fw4 ss_rules_dst_bypass { 172.64.229.91 }' >/dev/null
nft 'get element inet fw4 ss_rules6_dst_bypass { 2606:4700::1234 }' >/dev/null
# Stop/disable/failure cleanup: include removed, ruleset-pre retained.
for iteration in 1 2; do
 { echo 'flush table inet fw4'; cat "$asset"; } | nft -f -
 for prefix in ss_rules ss_rules6; do
  for suffix in src_bypass src_forward src_checkdst dst_bypass dst_bypass_ dst_forward dst_forward_rrst_; do
   if nft list set inet fw4 "${prefix}_${suffix}" | grep -q 'elements ='; then exit 1; fi
  done
 done
 nft 'get element inet fw4 unrelated { 192.0.2.9 }' >/dev/null
 done
echo 'ss-rules real nft tests: OK (shrink IPv4/IPv6, repeat, rollback, empty, unrelated preservation)'
