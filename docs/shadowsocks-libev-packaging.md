# shadowsocks-libev SIP003U packaging notes for OpenWrt 25.12

## Local-feed composition

OpenWrt 25.12 has removed both upstream packages used here. Their files from
the fixed legacy OpenWrt commits are checked into `vendor/openwrt-23.05/`.
The preparation scripts copy these local files and combine them with the
current SDK's `luci.mk`; they do not download historical package files.

The default selection includes:

```text
luci-app-shadowsocks-libev
shadowsocks-libev-config
shadowsocks-libev-ss-rules
shadowsocks-libev-ss-local
shadowsocks-libev-ss-redir
shadowsocks-libev-ss-server
shadowsocks-libev-ss-tunnel
```

LuCI has only `+luci-base` in `LUCI_DEPENDS`. The rules package retains its
dependency on `shadowsocks-libev-ss-redir` and also depends on firewall4,
ip-tiny, resolveip, ucode, ucode-mod-fs, the configuration package, and
kmod-nft-tproxy.

## SIP003U changes

The LuCI server editor exposes `plugin_mode` with these values:

```text
tcp_only
udp_only
tcp_and_udp
```

The init script validates the same option and writes it to each generated
server JSON configuration. The repository copy at
`files/shadowsocks-libev.init` is always installed into the generated feed.

The rules package includes:

```text
files/ss-rules/ss-rules.uc
files/ss-rules/set.uc
files/ss-rules/chain.uc
```

It uses `ip-tiny` rather than the removed legacy `ip` dependency.

## Build details

### 3.3.6_p2-r2 policy-query correction

The init script now requests numeric routing identifiers with `ip -N`, not
`ip -n` (which selects a network namespace). It dumps `route show table all`
and checks exact `table` fields rather than querying the target table directly:
ip-tiny 6.18 returns an error when a fresh policy table does not exist yet.
Actual route/rule dump errors still fail closed. Both IPv4 and IPv6 conflict
checks remain present; defaults for mark, mask, table and priority are unchanged.

That release was a packaging/init fix, not a change to the then-pinned SIP003U C source.
Local-feed preparation copies `files/shadowsocks-libev.init` into the config
package and now defaults to release 2. LuCI remains unchanged. Regenerate the
local feed before rebuilding APKs; do not reuse the old generated init file.
The current `3.3.6_p3-r1` source update supersedes that release.

Run `sh tests/test_ss_rules_policy.sh` before rebuilding. The mock ip rejects
wrong query syntax and covers fresh tables, occupied tables/priorities,
similar numeric IDs, IPv6 conflicts, query failures, and setup/reset lifecycle.
These tests are not a substitute for an isolated-VM ip-tiny/nftables smoke test.

For the validated x86/64 SDK:

```sh
scripts/build_all_apks.sh \
  /path/to/openwrt-sdk-25.12.5-x86-64_gcc-14.3.0_musl.Linux-x86_64 \
  /path/to/local-feed
```

The source is pinned to the remote `feature/sip003u` head verified on
2026-09-23:

```make
PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/MichaelSuen-thePointer/shadowsocks-c.git
PKG_SOURCE_DATE:=2026-09-23
PKG_SOURCE_VERSION:=49d2bf68b509f4b5a1c28992828212e5633bd390
PKG_MIRROR_HASH:=skip
```

The source uses CMake, libuv, and native PCRE2. The legacy
`100-Upgrade-PCRE-to-PCRE2.patch` must not be applied. Build with
`SS_DEPENDENCY_MODE=system` and `WITH_STATIC=OFF`; disable the unneeded
embedding libraries and `ss-manager`. All executables need `libuv` (the SDK
emits `libuv1`); `ss-local` and `ss-server` additionally need `libcares` and
`libpcre2`. Package
versions are `25.12.5_p2-r1` for LuCI and `3.3.6_p3-r1` for the runtime
package source. Installed package, UCI, and service names remain unchanged.
