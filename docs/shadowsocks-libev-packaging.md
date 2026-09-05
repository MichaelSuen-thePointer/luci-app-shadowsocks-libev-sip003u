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

For the validated x86/64 SDK:

```sh
scripts/build_all_apks.sh \
  /path/to/openwrt-sdk-25.12.5-x86-64_gcc-14.3.0_musl.Linux-x86_64 \
  /path/to/local-feed
```

The source is pinned to the `feature/sip003u` head following its 2026-09-04
force-push:

```make
PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/MichaelSuen-thePointer/shadowsocks-libev.git
PKG_SOURCE_VERSION:=d2ae22a3c85a66944535177425042307db71b5be
PKG_MIRROR_HASH:=skip
```

The force-pushed source has migrated from autotools to CMake and uses PCRE2
natively. The legacy `100-Upgrade-PCRE-to-PCRE2.patch` must not be applied.
Component-specific dependencies remain precise: `ss-local` adds `libpcre2`,
while `ss-server` adds `libcares` and `libpcre2`. Package versions are
`25.12.5_p2-r1` for LuCI and `3.3.6_p2-r1` for the runtime package source.
