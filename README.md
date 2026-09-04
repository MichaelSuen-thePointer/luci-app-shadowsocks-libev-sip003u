# OpenWrt 25.12 shadowsocks-libev SIP003U packages

This branch ports the repository's `plugin_mode` support from OpenWrt 23.05 to
OpenWrt 25.12. The primary validation target is `x86/64`; the scripts are not
architecture-specific and can also be used with a matching `mediatek/mt7622`
SDK.

OpenWrt 25.12 no longer carries `shadowsocks-libev` or
`luci-app-shadowsocks-libev` in its official feeds. This repository therefore
creates a local feed from the last pinned OpenWrt 23.05 package layouts, while
using the `luci.mk` and all dependency feeds pinned by the selected 25.12 SDK.
OpenWrt 25.12 uses `.apk` packages rather than `.ipk` packages.

The legacy package files are vendored below `vendor/openwrt-23.05/`. Local-feed
preparation never downloads those historical files at build time. Network
access is still needed for normal SDK feed updates and the pinned SIP003U
program source.

## Branch status

The OpenWrt 25.12 port is maintained on the `openwrt-25.12-port` branch. It is
separate from `main`, which retains the earlier OpenWrt 23.05 work.

```sh
git switch openwrt-25.12-port
git branch --show-current
```

The second command must print `openwrt-25.12-port` before building or changing
the port.

## Complete patch set

No additional patch is applied to the C source in the SIP003U fork. The
runtime implementation is taken unchanged from the pinned
`MichaelSuen-thePointer/shadowsocks-libev` commit. This repository changes the
OpenWrt package, init, and LuCI layers as follows.

### Historical package inputs

- The OpenWrt 23.05 `shadowsocks-libev` package Makefile, default UCI config,
  README, and three firewall4/ucode `ss-rules` files are stored under
  `vendor/openwrt-23.05/packages/`.
- The OpenWrt 23.05 LuCI Makefile, JavaScript views, menu, ACL, and UCI-defaults
  files are stored under `vendor/openwrt-23.05/luci/`.
- The files are copied from the repository during local-feed preparation. No
  historical file is downloaded from GitHub at build time.
- The 25.12 SDK's own `luci.mk` is used instead of the old vendored copy, so
  LuCI packaging follows the selected SDK release.

### Runtime package adaptation

`scripts/patch_shadowsocks_libev_package.py` transforms the vendored package
Makefile in the generated local feed:

- changes the source from the obsolete release tarball to the SIP003U Git
  repository and pins commit
  `d2ae22a3c85a66944535177425042307db71b5be`;
- sets package version `3.3.6_p1-r1` and source date `2026-09-04`;
- removes `PKG_FIXUP:=autoreconf`, enables `CMAKE_INSTALL`, and includes
  `cmake.mk`;
- replaces Autotools arguments with `WITH_STATIC=OFF`,
  `WITH_EMBEDDED_SRC=ON`, and `BUILD_TESTING=OFF` CMake options;
- changes the removed `ip` dependency to `ip-tiny` for `ss-rules`;
- removes the old `100-Upgrade-PCRE-to-PCRE2.patch`, because the pinned source
  already uses PCRE2 natively.

The original package relationships are retained. In particular, executable
packages depend on `shadowsocks-libev-config`, and `ss-rules` depends on both
the config package and `ss-redir`.

### SIP003U configuration adaptation

`files/shadowsocks-libev.init` adds `plugin_mode` to generated server JSON and
validates the supported `tcp_only`, `udp_only`, and `tcp_and_udp` values. This
file replaces the legacy init script in the generated local feed.

`scripts/patch_luci_plugin_mode.py` adds the same option to the LuCI server
editor. The generated LuCI package version is `25.12.5_p1-r1`, and its direct
package dependency remains only `luci-base`.

The files under `patches/` document the equivalent 23.05 package and LuCI
diffs. The 25.12 build applies the maintained init file and Python transforms
described above, rather than applying those patch files directly.

## Package model

The default build produces these local packages:

- `luci-app-shadowsocks-libev`: web UI; depends only on `luci-base`.
- `shadowsocks-libev-config`: UCI configuration and the SIP003U-aware init
  script.
- `shadowsocks-libev-ss-rules`: firewall4/ucode rules and templates.
- `shadowsocks-libev-ss-local`, `shadowsocks-libev-ss-redir`,
  `shadowsocks-libev-ss-tunnel`, and `shadowsocks-libev-ss-server`: target
  executables built by the matching SDK.

LuCI itself remains decoupled from all runtime packages and depends only on
`luci-base`. The original runtime chain is retained: `ss-rules` depends on
`ss-redir` and the shared configuration package.

The runtime init script validates `plugin_mode` and copies it into generated
JSON. Supported values are `tcp_only`, `udp_only`, and `tcp_and_udp`.

The force-pushed SIP003U source now uses CMake, Mbed TLS 3, and native PCRE2.
The obsolete OpenWrt 23.05 PCRE-to-PCRE2 patch is intentionally removed.

## Validated SDK

```text
Release:      OpenWrt 25.12.5
Target:       x86/64
Architecture: x86_64
SDK:          openwrt-sdk-25.12.5-x86-64_gcc-14.3.0_musl.Linux-x86_64.tar.zst
SDK SHA256:   0c8df0151a1e88feb7c03d694d61f6a18d51872815b7c811d76e2b77504d5e9c
```

Use the SDK matching the exact release and target installed on the router.
The setup script retains the SDK's pinned base/packages/LuCI commits instead
of following moving release branches.

## Build

### 1. Download and verify the SDK

Use the SDK for the exact OpenWrt release and target installed on the router.
For the validated x86/64 build:

```sh
curl -LO https://downloads.openwrt.org/releases/25.12.5/targets/x86/64/openwrt-sdk-25.12.5-x86-64_gcc-14.3.0_musl.Linux-x86_64.tar.zst
echo '0c8df0151a1e88feb7c03d694d61f6a18d51872815b7c811d76e2b77504d5e9c  openwrt-sdk-25.12.5-x86-64_gcc-14.3.0_musl.Linux-x86_64.tar.zst' | sha256sum -c -
tar --zstd -xf openwrt-sdk-25.12.5-x86-64_gcc-14.3.0_musl.Linux-x86_64.tar.zst
```

### 2. Build all packages

Run the all-package wrapper from the `openwrt-25.12-port` checkout:

```sh
REPO=/path/to/luci-app-shadowsocks-libev-sip003u
SDK=/path/to/openwrt-sdk-25.12.5-x86-64_gcc-14.3.0_musl.Linux-x86_64
FEED=/path/to/local-feed

"$REPO/scripts/build_all_apks.sh" "$SDK" "$FEED"
```

`JOBS` may be set to limit parallelism. The optional third argument overrides
the pinned shadowsocks-libev commit for an explicit test build:

```sh
JOBS=8 "$REPO/scripts/build_all_apks.sh" "$SDK" "$FEED" <full-git-commit>
```

The wrapper performs these steps:

1. verifies that the SDK reports OpenWrt 25.12 and writes a `src-link local`
   entry while preserving the SDK's pinned base, packages, and LuCI feeds;
2. updates those SDK feeds;
3. copies the vendored 23.05 package inputs into the local feed;
4. applies the LuCI `plugin_mode`, init-script, source-pin, CMake, version, and
   dependency adaptations described above;
5. installs the local package definitions and their 25.12 feed dependencies;
6. writes a minimal package selection for LuCI and all six shadowsocks-libev
   subpackages, runs `make defconfig`, and compiles both local packages;
7. prints every generated shadowsocks-libev APK path.

The output directory for x86_64 is:

```text
<sdk>/bin/packages/x86_64/local/
```

Expected output packages are:

```text
luci-app-shadowsocks-libev-25.12.5_p1-r1.apk
shadowsocks-libev-config-3.3.6_p1-r1.apk
shadowsocks-libev-ss-local-3.3.6_p1-r1.apk
shadowsocks-libev-ss-redir-3.3.6_p1-r1.apk
shadowsocks-libev-ss-rules-3.3.6_p1-r1.apk
shadowsocks-libev-ss-server-3.3.6_p1-r1.apk
shadowsocks-libev-ss-tunnel-3.3.6_p1-r1.apk
```

### 3. Optional LuCI-only build

Build only the LuCI APK with:

```sh
"$REPO/scripts/build_luci_apk.sh" "$SDK" "$FEED"
```

### Manual preparation stages

For debugging, the wrapper's preparation stages can be run separately:

```sh
"$REPO/scripts/configure_sdk_feeds.sh" "$SDK" "$FEED"
cd "$SDK"
./scripts/feeds update base packages luci
"$REPO/scripts/prepare_luci_local_feed.sh" "$FEED" "$SDK"
"$REPO/scripts/prepare_shadowsocks_libev_local_feed.sh" "$SDK" "$FEED"
./scripts/feeds update local
./scripts/feeds install -p local luci-app-shadowsocks-libev shadowsocks-libev
```

Environment overrides supported by local-feed preparation are
`LUCI_PLUGIN_MODE_VERSION`, `SHADOWSOCKS_LIBEV_VERSION`,
`SHADOWSOCKS_LIBEV_RELEASE`, `SHADOWSOCKS_LIBEV_SOURCE_URL`, and
`SS_RULES_IP_DEP`. Normal reproducible builds should use the defaults.

## Install and verify

Copy the locally built APKs to the router and install them together with their
official-feed dependencies:

```sh
apk add --allow-untrusted \
  ./luci-app-shadowsocks-libev-25.12.5_p1-r1.apk \
  ./shadowsocks-libev-config-3.3.6_p1-r1.apk \
  ./shadowsocks-libev-ss-redir-3.3.6_p1-r1.apk \
  ./shadowsocks-libev-ss-rules-3.3.6_p1-r1.apk
```

Example server configuration:

```uci
config server 'example'
        option server 'example.com'
        option server_port '443'
        option method 'chacha20-ietf-poly1305'
        option password 'secret'
        option plugin 'v2ray-plugin'
        option plugin_opts 'udpMode=quic'
        option plugin_mode 'tcp_and_udp'
```

Restart and inspect the generated runtime configuration:

```sh
/etc/init.d/shadowsocks-libev restart
grep plugin_mode /var/etc/shadowsocks-libev/*.json
```

The rules APK must contain all three ucode templates:

```text
/usr/share/ss-rules/ss-rules.uc
/usr/share/ss-rules/set.uc
/usr/share/ss-rules/chain.uc
```

## OpenWrt 25.12 dependency audit

All direct dependencies emitted by the x86_64 APKs are available from the
25.12.5 SDK's pinned base, packages, and LuCI feeds:

```text
libc, luci-base, libcares, libev, libmbedtls21, libpcre2, libpthread,
libsodium, firewall4, ip-tiny, kmod-nft-tproxy, resolveip, ucode,
ucode-mod-fs
```

`libmbedtls21` is the ABI-versioned APK generated by the feed's logical
`libmbedtls` package. No direct dependency is missing from the pinned feeds.

The emitted package relationships are:

| Package | Direct runtime dependencies beyond `libc` |
| --- | --- |
| `luci-app-shadowsocks-libev` | `luci-base` |
| `shadowsocks-libev-config` | none |
| `shadowsocks-libev-ss-local` | `libev`, `libmbedtls21`, `libpcre2`, `libpthread`, `libsodium`, config |
| `shadowsocks-libev-ss-redir` | `libev`, `libmbedtls21`, `libpthread`, `libsodium`, config |
| `shadowsocks-libev-ss-rules` | `firewall4`, `ip-tiny`, `kmod-nft-tproxy`, `resolveip`, `ss-redir`, config, `ucode`, `ucode-mod-fs` |
| `shadowsocks-libev-ss-server` | `libcares`, `libev`, `libmbedtls21`, `libpcre2`, `libpthread`, `libsodium`, config |
| `shadowsocks-libev-ss-tunnel` | `libev`, `libmbedtls21`, `libpthread`, `libsodium`, config |

Here `config` denotes `shadowsocks-libev-config`.

## Source pins

- Legacy OpenWrt packages layout:
  `b5ed85f6e94aa08de1433272dc007550f4a28201`
- Legacy OpenWrt LuCI app layout:
  `63ba3cba5b7bfb803a875d4d8f01248634687fd5`
- SIP003U runtime source:
  `https://github.com/MichaelSuen-thePointer/shadowsocks-libev.git`
- SIP003U source commit:
  `d2ae22a3c85a66944535177425042307db71b5be`

The source commit is the `feature/sip003u` head after its 2026-09-04
force-push. The build pins the commit rather than the moving branch name for
repeatability.

The files taken from the two legacy commits are stored under
`vendor/openwrt-23.05/`; see its `README.md` for provenance.

The custom versions use `_p1`, which is valid in OpenWrt 25.12's APK version
syntax. The old `+sip003u` suffix is not accepted by its APK tooling.

See [docs/shadowsocks-libev-packaging.md](docs/shadowsocks-libev-packaging.md)
for package-level details.
