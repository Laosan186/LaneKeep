# Third-party components

LaneKeep's own code is GPL-3.0-only. The following separately licensed components retain their original terms and attribution.

| Files | Upstream | License and changes |
|---|---|---|
| `tools/preview/public/luci-runtime.js` | [OpenWrt LuCI](https://github.com/openwrt/luci/tree/openwrt-25.12) | Apache-2.0; a bundled/minified LuCI runtime with a local preview environment adapter. See `licenses/Apache-2.0.txt` and `licenses/LuCI-NOTICE.txt`. |
| `tools/preview/public/luci-static/argon/` | [luci-theme-argon](https://github.com/jerrykuku/luci-theme-argon) | Apache-2.0; preview-only CSS and SVG assets. Font loading was removed and replaced by system fonts. Original CSS attribution is retained. No upstream fonts are redistributed. |
| `root/usr/share/v2ray/lanekeep-services.dat` | [Loyalsoldier/v2ray-rules-dat, release 202611152204](https://github.com/Loyalsoldier/v2ray-rules-dat/releases/tag/202611152204) | GPL-3.0; filtered to public IPv4 prefixes for GOOGLE and NETFLIX. No country GeoLite2 entries are included. Source and output digests are in `docs/audit/geodata.json`; reproduce with `tools/build/subset-geodata.py`. |

The installed package uses OpenWrt-distributed Xray, nftables, ucode, LuCI and geodata packages as dependencies. Their source, licensing and updates remain with their respective upstream projects and OpenWrt feeds; those binaries are not vendored into this repository.

Screenshots and preview fixtures are synthetic. Example addresses and names are demonstrations, not redistributed user configurations.
