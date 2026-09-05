#!/bin/sh
set -eu

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$repo_root/files/shadowsocks-libev.init"

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

test_config_validation() (
	logger() { :; }

	ss_rules_policy_config 0x01000000 0xff000000 1000 100 \
		|| fail "valid policy configuration was rejected"
	[ "$ssrules_policy_mark" = 0x01000000 ] || fail "mark was not normalized"
	[ "$ssrules_policy_keep_mask" = 0x00ffffff ] || fail "keep mask is incorrect"

	! ss_rules_policy_config 0x01000001 0xff000000 1000 100 \
		|| fail "mark bits outside the mask were accepted"
	! ss_rules_policy_config 0x01000000 0xff000000 254 100 \
		|| fail "reserved routing table was accepted"
	! ss_rules_policy_config 0x01000000 0xff000000 1000 0 \
		|| fail "zero rule priority was accepted"
)

test_lifecycle() (
	test_dir="$(mktemp -d /tmp/ssrules-policy-test.XXXXXX)" || exit 1
	ssrules_policy_state="$test_dir/state"
	commands=""
	logger() { :; }
	ip() {
		family="$1"
		shift
		case "$*" in
			"-n route show table 1000")
				[ -f "$ssrules_policy_state" ] && echo "local default dev lo scope host"
				return 0
				;;
			"-n rule show")
				echo "0: from all lookup local"
				[ -f "$ssrules_policy_state" ] \
					&& echo "100: from all fwmark 0x1000000/0xff000000 lookup 1000"
				echo "32766: from all lookup main"
				return 0
				;;
			*)
				commands="$commands|$family $*"
				return 0
				;;
		esac
	}

	ss_rules_policy_config 0x01000000 0xff000000 1000 100 \
		|| fail "could not prepare lifecycle test"
	ss_rules_policy_setup || fail "initial policy setup failed"
	[ -f "$ssrules_policy_state" ] || fail "policy state was not recorded"
	[ "$(cat "$ssrules_policy_state")" = "1000 100" ] \
		|| fail "policy state contains more than table and priority"
	ss_rules_policy_setup || fail "repeated policy setup failed"
	ss_rules_policy_reset || fail "policy reset failed"
	[ ! -f "$ssrules_policy_state" ] || fail "policy state was not removed"

	for expected in \
		"-4 route add local default dev lo table 1000" \
		"-6 route add local default dev lo table 1000" \
		"-4 rule add priority 100 fwmark 0x01000000/0xff000000 lookup 1000" \
		"-6 rule add priority 100 fwmark 0x01000000/0xff000000 lookup 1000" \
		"-4 rule del priority 100" \
		"-6 rule del priority 100" \
		"-4 route flush table 1000" \
		"-6 route flush table 1000"
	do
		case "$commands" in
			*"$expected"*) ;;
			*) fail "missing lifecycle command: $expected" ;;
		esac
	done

	rmdir "$test_dir" || fail "test directory is not empty"
)

test_table_and_priority_conflicts() (
	test_dir="$(mktemp -d /tmp/ssrules-policy-test.XXXXXX)" || exit 1
	ssrules_policy_state="$test_dir/state"
	mode=table
	logger() { :; }
	ip() {
		family="$1"
		shift
		case "$*:$mode" in
			"-n route show table 1000:table")
				echo "default via 192.0.2.1 dev eth0"
				return 0
				;;
			"-n route show table 1000:"*) return 0 ;;
			"-n rule show:priority")
				echo "100: from all lookup 2000"
				return 0
				;;
			"-n rule show:mark")
				echo "5000: from all fwmark 0x1000000/0xff000000 lookup 5000"
				return 0
				;;
			"-n rule show:"*) return 0 ;;
			*) return 0 ;;
		esac
	}

	ss_rules_policy_config 0x01000000 0xff000000 1000 100 \
		|| fail "could not prepare resource conflict test"
	! ss_rules_policy_conflict_check || fail "occupied routing table was accepted"
	mode=priority
	! ss_rules_policy_conflict_check || fail "occupied rule priority was accepted"
	mode=mark
	ss_rules_policy_conflict_check || fail "mark-only conflict was unexpectedly rejected"
	rmdir "$test_dir" || fail "test directory is not empty"
)

test_legacy_cleanup() (
	test_dir="$(mktemp -d /tmp/ssrules-policy-test.XXXXXX)" || exit 1
	ssrules_nft="$test_dir/legacy.nft"
	commands=""
	logger() { :; }
	ip() {
		commands="$commands|$*"
		return 0
	}
	echo 'meta l4proto udp meta mark set 1 tproxy to :1100;' >"$ssrules_nft"

	ss_rules_policy_legacy_reset || fail "legacy cleanup failed"
	for expected in \
		"-4 rule del fwmark 1 lookup 100" \
		"-6 rule del fwmark 1 lookup 100" \
		"-4 route del local default dev lo table 100" \
		"-6 route del local default dev lo table 100"
	do
		case "$commands" in
			*"$expected"*) ;;
			*) fail "missing legacy cleanup command: $expected" ;;
		esac
	done
	case "$commands" in
		*flush*) fail "legacy cleanup flushed a route table" ;;
	esac
	rm "$ssrules_nft"
	rmdir "$test_dir" || fail "test directory is not empty"
)

test_redir_semantics() (
	redir_type=ss_redir
	redir_disabled=0
	redir_mode=tcp_and_udp
	redir_port=12345
	ss_rules_redir_tcp_sections=" redir-main"
	ss_rules_redir_udp_sections=" redir-main"
	logger() { :; }
	config_get() {
		case "$3" in
			TYPE) eval "$1=\$redir_type" ;;
			mode) eval "$1=\$redir_mode" ;;
			local_port) eval "$1=\$redir_port" ;;
		esac
	}
	config_get_bool() {
		eval "$1=\$redir_disabled"
	}
	validate_ss_redir_section() {
		[ "$redir_port" -ge 1 ] 2>/dev/null \
			&& [ "$redir_port" -le 65535 ] 2>/dev/null
	}

	ss_rules_redir_port redir-main tcp || fail "valid TCP redir was rejected"
	[ "$ssrules_redir_port" = 12345 ] || fail "TCP redir port was not returned"
	ss_rules_redir_port redir-main udp || fail "valid UDP redir was rejected"

	redir_mode=tcp_only
	! ss_rules_redir_port redir-main udp || fail "UDP accepted a TCP-only redir"
	redir_mode=tcp_and_udp
	redir_disabled=1
	! ss_rules_redir_port redir-main tcp || fail "disabled redir was accepted"
	redir_disabled=0
	redir_port=70000
	! ss_rules_redir_port redir-main tcp || fail "invalid redir port was accepted"
	redir_port=12345
	ss_rules_redir_tcp_sections=
	! ss_rules_redir_port redir-main tcp || fail "unprepared redir was accepted"
)

test_apply_failure_disables_rules() (
	test_dir="$(mktemp -d /tmp/ssrules-failure-test.XXXXXX)" || exit 1
	ssrules_nft="$test_dir/active.nft"
	reset_nft=0
	reset_policy=0
	logger() { :; }
	ss_rules_nft_gen() {
		return 1
	}
	ss_rules_nft_reset() { reset_nft=1; }
	ss_rules_policy_reset() { reset_policy=1; }
	echo old >"$ssrules_nft"

	set +e
	ss_rules
	rc=$?
	set -e
	[ "$rc" = 1 ] || fail "apply failure was not propagated"
	[ "$reset_nft" = 1 ] || fail "apply failure did not remove nftables rules"
	[ "$reset_policy" = 1 ] || fail "apply failure did not remove policy routing"

	rm "$ssrules_nft"
	rmdir "$test_dir"
)

test_rule_failure_keeps_redir() (
	registered=""
	rules_rc=1
	ssrules_uc=/dev/null
	procd_lock() { :; }
	mkdir() { :; }
	config_load() { :; }
	config_foreach() {
		callback="$1"
		cfgtype="$2"
		"$callback" "${cfgtype#ss_}-main" "$cfgtype"
	}
	ss_xxx() {
		registered="$registered $2.$1"
	}
	ss_rules() { return "$rules_rc"; }

	set +e
	start_service
	rc=$?
	set -e
	[ "$rc" = 1 ] || fail "failed rule application was not propagated"
	case "$registered" in
		*" ss_redir.redir-main"*) ;;
		*) fail "redir was stopped by a rule failure" ;;
	esac
	for expected in ss_local.local-main ss_server.server-main ss_tunnel.tunnel-main; do
		case "$registered" in
			*" $expected"*) ;;
			*) fail "$expected was stopped by a rule failure" ;;
		esac
	done
)

test_config_validation
test_lifecycle
test_table_and_priority_conflicts
test_legacy_cleanup
test_redir_semantics
test_apply_failure_disables_rules
test_rule_failure_keeps_redir
echo "ss-rules policy tests: OK"
