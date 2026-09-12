#!/bin/sh
set -eu
repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$repo_root/files/shadowsocks-libev.init"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
logger() { :; }
ssrules_nft="$tmp/include.nft"
ssrules_uc="$tmp/template.uc"
touch "$ssrules_uc"
reloads=0
fw4() {
 case "$1" in
 print) printf '%s\n' "${printed:-include \"/usr/share/nftables.d/ruleset-pre/90-ss-rules-sets.nft\"}" ;;
 reload) reloads=$((reloads + 1)); return "${reload_rc:-0}" ;;
 *) return 1 ;;
 esac
}
ss_rules_nft_reset
[ "$reloads" = 1 ]
echo '# generated' > "$ssrules_nft"
ss_rules_nft_reset
[ ! -e "$ssrules_nft" ]
[ "$reloads" = 2 ]
reload_rc=1
if ss_rules_nft_reset; then echo 'FAIL: swallowed reload failure'; exit 1; fi
reload_rc=0
printed='# auto includes disabled'
if ss_rules_fw4_reload; then echo 'FAIL: missing replacement accepted'; exit 1; fi
[ "$reloads" = 3 ]
rm "$ssrules_uc"
ss_rules_nft_reset
[ "$reloads" = 3 ]
echo 'ss-rules set lifecycle shell tests: OK'
