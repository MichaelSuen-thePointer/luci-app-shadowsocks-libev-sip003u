# OpenWrt 23.05 shadowsocks-libev SIP003U Packages

This repository records a repeatable OpenWrt 23.05 build flow for two related
SIP003U tasks:

- Add the `plugin_mode` UCI option to `luci-app-shadowsocks-libev`.
- Build matching `shadowsocks-libev` runtime packages from a SIP003U-capable
  source branch.

The LuCI package only edits `/etc/config/shadowsocks-libev`. Runtime support is
provided by the `shadowsocks-libev` package's init script, which must read the
same UCI option and write it to the generated JSON config. Install both sides
when testing `plugin_mode`.

## Background And Rationale

This section explains the target, repository files, and package changes. The
actual command sequence starts at [Procedure](#procedure).

### Target

- OpenWrt release: `23.05.5`
- SDK example: `openwrt-sdk-23.05.5-mediatek-mt7622_gcc-12.3.0_musl.Linux-x86_64.tar.xz`
- Target package architecture: `aarch64_cortex-a53`
- LuCI package version override: `git-25.222.75657-7ce34fe+sip003u`
- Runtime package version override: `3.3.6+sip003u-1`
- Runtime source repository:
  `https://github.com/MichaelSuen-thePointer/shadowsocks-libev`
- Runtime source branch/commit example:
  `feature/sip003u` / `9217f6e08b31c5ded469f99f59e0b863bb78c447`

Use the SDK that exactly matches the router release and target/subtarget.

### Files

- `patches/luci-plugin-mode.patch`: minimal LuCI patch.
- `patches/packages-plugin-mode.patch`: init script source patch for `openwrt/packages`.
- `files/shadowsocks-libev.init`: patched `/etc/init.d/shadowsocks-libev` source file.
- `scripts/prepare_luci_local_feed.sh`: create a local feed for the LuCI app.
- `scripts/build_luci_ipk.sh`: configure the SDK and build the LuCI `.ipk`.
- `scripts/patch_shadowsocks_libev_package.py`: patch the copied OpenWrt
  runtime package Makefile.
- `scripts/prepare_shadowsocks_libev_local_feed.sh`: copy OpenWrt's
  `shadowsocks-libev` package into the local feed, point it at the SIP003U
  GitHub repository, and keep the required PCRE2 / `ss-rules` packaging pieces.
- `scripts/build_all_ipks.sh`: prepare the local feed and build both LuCI and
  runtime `.ipk` files.
- `docs/shadowsocks-libev-packaging.md`: notes for the full `shadowsocks-libev` SIP003U package build.

### LuCI Change

Patch OpenWrt's `openwrt/luci` package, not the standalone `shadowsocks/luci-app-shadowsocks-libev` repository.

The relevant file is:

```text
applications/luci-app-shadowsocks-libev/htdocs/luci-static/resources/shadowsocks-libev.js
```

Required changes:

- Add `plugin_mode` to `names_options_server`.
- Add a `plugin_mode` `ListValue` in `options_server()`.
- Valid values: `tcp_only`, `udp_only`, `tcp_and_udp`.
- Leave it empty by default with `rmempty = true`.

The explicit `PKG_VERSION` matters. A generated version such as `260505.31683`
is older than an already installed `git-25.222.75657-7ce34fe` package and opkg
will treat it as a downgrade. Use the installed LuCI package version plus a
suffix, for example:

```make
PKG_VERSION:=git-25.222.75657-7ce34fe+sip003u
```

Then install normally:

```sh
opkg install ./luci-app-shadowsocks-libev_git-25.222.75657-7ce34fe+sip003u_all.ipk
```

Avoid `--force-downgrade`; downgrade paths can trigger obsolete-file cleanup
errors against files such as `/etc/uci-defaults/40_luci-shadowsocks-libev`.

### Runtime Package Change

Patch the init script source in `openwrt/packages`:

```text
net/shadowsocks-libev/files/shadowsocks-libev.init
```

Required changes:

- Add `plugin_mode` to `validate_common_server_options_()`.
- Add `plugin_mode` to `ss_mkjson_server_conf_()` so the runtime JSON under
  `/var/etc/shadowsocks-libev/*.json` includes it when configured.

The patched installable init script is available at:

```text
files/shadowsocks-libev.init
```

The runtime package build also needs the OpenWrt package itself to come from the
SIP003U source branch. In the local feed package Makefile, replace the release
tarball source with a local git source:

```make
PKG_VERSION:=3.3.6+sip003u
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/MichaelSuen-thePointer/shadowsocks-libev.git
PKG_SOURCE_VERSION:=9217f6e08b31c5ded469f99f59e0b863bb78c447
PKG_MIRROR_HASH:=skip
```

Keep the official OpenWrt `100-Upgrade-PCRE-to-PCRE2.patch`. Without it, the
SIP003U source tree still checks for old PCRE and configure can fail with:

```text
Cannot find pcre library. Configure --with-pcre=DIR
```

For this SDK, the `ss-rules` package should depend on `+ip-tiny`, not `+ip`.
Also make sure all three ucode templates are installed:

```text
files/ss-rules/ss-rules.uc
files/ss-rules/set.uc
files/ss-rules/chain.uc
```

If `set.uc` or `chain.uc` is missing from the package, routers can fail at
runtime with:

```text
Runtime error: Include file not found
include("set.uc");
```

## Procedure

Start here when you want to prepare the SDK local feed and build packages.

### Build Both Package Sets

On a Linux host:

```sh
mkdir -p ~/work/openwrt-plugin-mode
cd ~/work/openwrt-plugin-mode
tar -xf ~/openwrt-sdk-23.05.5-mediatek-mt7622_gcc-12.3.0_musl.Linux-x86_64.tar.xz
```

One-command path:

```sh
REPO=/path/to/this/repo
SDK=~/work/openwrt-plugin-mode/openwrt-sdk-23.05.5-mediatek-mt7622_gcc-12.3.0_musl.Linux-x86_64
FEED=~/work/openwrt-plugin-mode/local-feed

"$REPO/scripts/build_all_ipks.sh" "$SDK" "$FEED"
```

Manual path:

```sh
REPO=/path/to/this/repo
SDK=~/work/openwrt-plugin-mode/openwrt-sdk-23.05.5-mediatek-mt7622_gcc-12.3.0_musl.Linux-x86_64
FEED=~/work/openwrt-plugin-mode/local-feed
SS_COMMIT=9217f6e08b31c5ded469f99f59e0b863bb78c447

cd "$SDK"
./scripts/feeds update base packages luci
"$REPO/scripts/prepare_luci_local_feed.sh" "$FEED" "$SDK"
"$REPO/scripts/prepare_shadowsocks_libev_local_feed.sh" "$SDK" "$FEED" "$SS_COMMIT"
./scripts/feeds update local
./scripts/feeds install -p local luci-app-shadowsocks-libev shadowsocks-libev
./scripts/feeds install pcre2 c-ares libev mbedtls libsodium iproute2 firewall4 resolveip ucode ucode-mod-fs
make defconfig
make package/feeds/local/luci-app-shadowsocks-libev/compile V=s
make package/feeds/local/shadowsocks-libev/compile V=s
```

When an SDK path is provided, `prepare_luci_local_feed.sh` copies
`luci-app-shadowsocks-libev` from the SDK's pinned `feeds/luci` checkout.
Without an SDK path, it falls back to downloading the same files from the
`openwrt-23.05` branch on GitHub.

The output is under:

```text
<sdk>/bin/packages/aarch64_cortex-a53/local/
```

Expected package names include:

```text
luci-app-shadowsocks-libev_git-25.222.75657-7ce34fe+sip003u_all.ipk
shadowsocks-libev-config_3.3.6+sip003u-1_aarch64_cortex-a53.ipk
shadowsocks-libev-ss-local_3.3.6+sip003u-1_aarch64_cortex-a53.ipk
shadowsocks-libev-ss-redir_3.3.6+sip003u-1_aarch64_cortex-a53.ipk
shadowsocks-libev-ss-rules_3.3.6+sip003u-1_aarch64_cortex-a53.ipk
shadowsocks-libev-ss-server_3.3.6+sip003u-1_aarch64_cortex-a53.ipk
shadowsocks-libev-ss-tunnel_3.3.6+sip003u-1_aarch64_cortex-a53.ipk
```

Verify the runtime binaries are for the target:

```sh
file "$SDK"/build_dir/target-aarch64_cortex-a53_musl/shadowsocks-libev-3.3.6+sip003u/.pkgdir/shadowsocks-libev-ss-local/usr/bin/ss-local
```

Verify `ss-rules` contains the include files:

```sh
tar -xOf "$SDK"/bin/packages/aarch64_cortex-a53/local/shadowsocks-libev-ss-rules_3.3.6+sip003u-1_aarch64_cortex-a53.ipk ./data.tar.gz \
  | tar -tzf - \
  | grep /usr/share/ss-rules/
```

### Runtime Verification

Install or upgrade the LuCI package plus the matching runtime packages you need.
For a redir setup with rules, that usually means at least:

```sh
opkg install \
  ./luci-app-shadowsocks-libev_git-25.222.75657-7ce34fe+sip003u_all.ipk \
  ./shadowsocks-libev-config_3.3.6+sip003u-1_aarch64_cortex-a53.ipk \
  ./shadowsocks-libev-ss-redir_3.3.6+sip003u-1_aarch64_cortex-a53.ipk \
  ./shadowsocks-libev-ss-rules_3.3.6+sip003u-1_aarch64_cortex-a53.ipk
```

Then configure a server section with `plugin_mode`.

Example UCI fragment:

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

Restart and inspect the generated JSON:

```sh
/etc/init.d/shadowsocks-libev restart
grep plugin_mode /var/etc/shadowsocks-libev/*.json
```
