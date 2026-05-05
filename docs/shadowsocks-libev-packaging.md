# shadowsocks-libev SIP003U Packaging Notes

These notes summarize the separate `shadowsocks-libev` package build. The LuCI
package can be built independently, but runtime SIP003U support requires a
matching `shadowsocks-libev` package and init script.

## SDK Context

- SDK: `openwrt-sdk-23.05.5-mediatek-mt7622_gcc-12.3.0_musl.Linux-x86_64`
- Target: `aarch64_cortex-a53` / musl
- Source repository: `https://github.com/MichaelSuen-thePointer/shadowsocks-libev`
- Feature branch: `feature/sip003u`
- Feature commit: `9217f6e08b31c5ded469f99f59e0b863bb78c447`
- Local feed path: `local-feed/net/shadowsocks-libev`

## Key Package Changes

- Point `PKG_SOURCE_URL` to the GitHub repository, for example:

```make
PKG_SOURCE_URL:=https://github.com/MichaelSuen-thePointer/shadowsocks-libev.git
PKG_SOURCE_PROTO:=git
PKG_SOURCE_VERSION:=9217f6e08b31c5ded469f99f59e0b863bb78c447
PKG_MIRROR_HASH:=skip
```

- Keep the official OpenWrt `100-Upgrade-PCRE-to-PCRE2.patch` in the local feed
  `patches/` directory.
- Link/install build dependencies such as `pcre2`, `c-ares`, `libev`, `mbedtls`,
  `libsodium`, `firewall4`, `resolveip`, and `iproute2`.
- If `+ip` is unavailable in this SDK target, use `+ip-tiny` for the `ss-rules`
  dependency.
- Include all ucode templates required by `ss-rules`:

```text
files/ss-rules/ss-rules.uc
files/ss-rules/set.uc
files/ss-rules/chain.uc
```

Missing `set.uc` or `chain.uc` causes runtime errors such as:

```text
Include file not found: include("set.uc")
```

## Build

```sh
make package/shadowsocks-libev/compile V=s
```

Expected output path:

```text
bin/packages/aarch64_cortex-a53/local/
```

Verify binaries:

```sh
file bin/packages/aarch64_cortex-a53/local/shadowsocks-libev-ss-*.ipk
```

Verify `shadowsocks-libev-ss-rules` contains:

```text
/usr/share/ss-rules/ss-rules.uc
/usr/share/ss-rules/set.uc
/usr/share/ss-rules/chain.uc
```
