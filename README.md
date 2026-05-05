# OpenWrt 23.05 luci-app-shadowsocks-libev SIP003U plugin_mode

This repository records the minimal repeatable process for adding the
`plugin_mode` UCI option to OpenWrt 23.05 `luci-app-shadowsocks-libev`, and for
building a LuCI `.ipk` with an upgrade-safe custom version.

The LuCI package only edits `/etc/config/shadowsocks-libev`. Runtime support is
provided by the `shadowsocks-libev` package's init script, which must read the
same UCI option and write it to the generated JSON config.

## Target

- OpenWrt release: `23.05.5`
- SDK example: `openwrt-sdk-23.05.5-mediatek-mt7622_gcc-12.3.0_musl.Linux-x86_64.tar.xz`
- Target package architecture: `aarch64_cortex-a53`
- LuCI package version override: `git-25.222.75657-7ce34fe+sip003u`

Use the SDK that exactly matches the router release and target/subtarget.

## Files

- `patches/luci-plugin-mode.patch`: minimal LuCI patch.
- `patches/packages-plugin-mode.patch`: init script source patch for `openwrt/packages`.
- `files/shadowsocks-libev.init`: patched `/etc/init.d/shadowsocks-libev` source file.
- `scripts/prepare_luci_local_feed.sh`: create a local feed for the LuCI app.
- `scripts/build_luci_ipk.sh`: configure the SDK and build the LuCI `.ipk`.
- `docs/shadowsocks-libev-packaging.md`: notes for the full `shadowsocks-libev` SIP003U package build.

## LuCI Change

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

## Init Script Change

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

## Build LuCI IPK

On a Linux host:

```sh
mkdir -p ~/work/openwrt-plugin-mode
cd ~/work/openwrt-plugin-mode
tar -xf ~/openwrt-sdk-23.05.5-mediatek-mt7622_gcc-12.3.0_musl.Linux-x86_64.tar.xz
```

Prepare the local feed:

```sh
REPO=/path/to/this/repo
SDK=~/work/openwrt-plugin-mode/openwrt-sdk-23.05.5-mediatek-mt7622_gcc-12.3.0_musl.Linux-x86_64
FEED=~/work/openwrt-plugin-mode/local-feed

"$REPO/scripts/prepare_luci_local_feed.sh" "$FEED"
```

Build:

```sh
"$REPO/scripts/build_luci_ipk.sh" "$SDK" "$FEED"
```

The output is under:

```text
<sdk>/bin/packages/aarch64_cortex-a53/local/
```

Expected package name:

```text
luci-app-shadowsocks-libev_git-25.222.75657-7ce34fe+sip003u_all.ipk
```

## Runtime Verification

After installing both the LuCI package and a matching `shadowsocks-libev` package
with init-script support, configure a server section with `plugin_mode`.

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
