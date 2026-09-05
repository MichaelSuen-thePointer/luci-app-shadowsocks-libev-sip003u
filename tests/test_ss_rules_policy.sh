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

test_config_validation
test_lifecycle
test_table_and_priority_conflicts
test_legacy_cleanup
echo "ss-rules policy tests: OK"
