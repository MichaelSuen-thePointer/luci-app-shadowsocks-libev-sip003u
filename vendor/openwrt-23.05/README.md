# Vendored OpenWrt 23.05 package files

These files are local snapshots of the historical package layouts used to
construct the OpenWrt 25.12 local feed. They are deliberately kept unmodified;
the preparation scripts copy them and then apply this repository's 25.12 and
SIP003U changes to the generated feed.

Sources:

- `packages/`: `openwrt/packages` commit
  `b5ed85f6e94aa08de1433272dc007550f4a28201`, directory
  `net/shadowsocks-libev`
- `luci/`: `openwrt/luci` commit
  `63ba3cba5b7bfb803a875d4d8f01248634687fd5`, directory
  `applications/luci-app-shadowsocks-libev`

Only the files previously fetched by the preparation scripts are included.
The SIP003U runtime source is not vendored and remains pinned separately in
`scripts/prepare_shadowsocks_libev_local_feed.sh`.
