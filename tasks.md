# luci-app-shadowsocks-libev plugin_mode Tasks

Current workspace:

`C:\Users\crazy\Documents\Codex\2026-05-05\openwrt-luci-23-05-luci-app`

## 0. Checkout Source Repositories

- [ ] 0.1 Confirm target OpenWrt release and device target/subtarget, for example `23.05.x` plus `x86/64`, `mediatek/filogic`, etc.
- [ ] 0.2 Checkout `openwrt/luci` branch `openwrt-23.05`.
- [ ] 0.3 Checkout `openwrt/packages` branch `openwrt-23.05`.
- [ ] 0.4 Confirm the target LuCI app path is `openwrt/luci/applications/luci-app-shadowsocks-libev`, not the standalone `shadowsocks/luci-app-shadowsocks-libev` repository.
- [ ] 0.5 Confirm the init script source path is `openwrt/packages/net/shadowsocks-libev/files/shadowsocks-libev.init`.

## 1. Modify LuCI App

- [ ] 1.1 Edit `applications/luci-app-shadowsocks-libev/htdocs/luci-static/resources/shadowsocks-libev.js`.
- [ ] 1.2 Add `plugin_mode` to the server overview field list near `plugin` and `plugin_opts`.
- [ ] 1.3 Add a `plugin_mode` form option in `options_server()`, preferably near `plugin_opts`.
- [ ] 1.4 Use valid shadowsocks-libev mode values: `tcp_only`, `udp_only`, `tcp_and_udp`.
- [ ] 1.5 Keep the option empty by default and removable, so existing configs are not changed during upgrade.
- [ ] 1.6 Decide whether SIP002 import should parse an extra `plugin_mode` query parameter.
- [ ] 1.7 Re-check that the field appears only where server-side options are edited: remote `server` entries and local `ss_server` instances.

## 2. Modify Init Script

- [ ] 2.1 Edit `net/shadowsocks-libev/files/shadowsocks-libev.init` in the `openwrt/packages` checkout.
- [ ] 2.2 Add `plugin_mode` to `validate_common_server_options_()` with allowed values `tcp_only`, `udp_only`, `tcp_and_udp`.
- [ ] 2.3 Add JSON output in `ss_mkjson_server_conf_()` so `plugin_mode` is written to `/var/etc/shadowsocks-libev/*.json`.
- [ ] 2.4 Confirm `plugin_mode` follows the same server-side flow as `plugin` and `plugin_opts`.
- [ ] 2.5 Confirm no changes are needed in `ss_rules`, firewall rules, LuCI ACL, or menu files.

## 3. Download SDK, Configure, and Compile

- [ ] 3.1 Download the OpenWrt SDK that exactly matches the router release and target/subtarget.
- [ ] 3.2 Use a Linux build host or WSL2; avoid spaces in the SDK path.
- [ ] 3.3 Create a local feed that contains the modified `luci-app-shadowsocks-libev` package and modified `shadowsocks-libev` package.
- [ ] 3.4 Add the local feed at the top of `feeds.conf.default` so it overrides official feed packages.
- [ ] 3.5 Run `./scripts/feeds update -a`.
- [ ] 3.6 Install the local packages with `./scripts/feeds install -p local luci-app-shadowsocks-libev` and `./scripts/feeds install -p local shadowsocks-libev`.
- [ ] 3.7 Configure package selection with `make menuconfig` or `.config` plus `make defconfig`.
- [ ] 3.8 Build `luci-app-shadowsocks-libev`.
- [ ] 3.9 Build `shadowsocks-libev`; collect the `shadowsocks-libev-config` subpackage output.
- [ ] 3.10 Locate generated `.ipk` files under `bin/packages/<arch>/local/`.
- [ ] 3.11 Optionally run `make package/index` if using the output directory as an opkg feed.

## 4. Local Review and Sanity Checks

- [ ] 4.1 Review the final diff and ensure only the intended files changed.
- [ ] 4.2 Confirm LuCI package metadata still depends on `luci-base` as before.
- [ ] 4.3 Confirm `shadowsocks-libev-config` package installs the modified init script.
- [ ] 4.4 Confirm generated runtime JSON includes `plugin_mode` only when the UCI option is set.
- [ ] 4.5 Confirm configs without `plugin_mode` still behave exactly as before.

## 5. Router Install and Runtime Test

- [ ] 5.1 Copy `luci-app-shadowsocks-libev_*.ipk` and `shadowsocks-libev-config_*.ipk` to the router.
- [ ] 5.2 Install or upgrade both packages with `opkg install`.
- [ ] 5.3 Set a test server section with `plugin`, `plugin_opts`, and `plugin_mode`.
- [ ] 5.4 Restart the service with `/etc/init.d/shadowsocks-libev restart`.
- [ ] 5.5 Inspect `/var/etc/shadowsocks-libev/*.json` and confirm `plugin_mode` is present.
- [ ] 5.6 Confirm the expected ss-local, ss-redir, or ss-server instance starts under procd.
- [ ] 5.7 Test the SIP003U traffic path, especially UDP behavior when `plugin_mode` is `tcp_and_udp`.

## 6. Packaging Notes

- [ ] 6.1 Record the exact SDK filename, OpenWrt release, target, subtarget, and architecture.
- [ ] 6.2 Record the generated package filenames and versions.
- [ ] 6.3 If distributing the packages, document that both LuCI and `shadowsocks-libev-config` packages are required for full `plugin_mode` support.
