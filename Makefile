include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-lanekeep
PKG_VERSION:=0.1.0
PKG_RELEASE:=1
PKG_LICENSE:=GPL-3.0-only
PKG_MAINTAINER:=LaneKeep contributors
PKGARCH:=all
PKG_BUILD_DEPENDS:=python3/host

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-lanekeep
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LaneKeep per-device routing
  DEPENDS:=+luci-base +rpcd +rpcd-mod-ucode +uhttpd-mod-ubus +xray-core +v2ray-geoip +v2ray-geosite +firewall4 +nftables-json +kmod-nft-tproxy +kmod-nft-socket +ip-full +ucode +ucode-mod-fs +ucode-mod-uci +ucode-mod-ubus +ucode-mod-math +ucode-mod-socket +ucode-mod-struct +ucode-mod-digest +ca-bundle +curl +flock +coreutils-timeout
endef

define Package/luci-app-lanekeep/description
  Four per-device routing modes, protected DNS, a fail-closed proxy gate,
  transactional configuration and monitoring. Disabled on first installation.
endef

define Build/Prepare
  mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Compile
  $(STAGING_DIR_HOST)/bin/python3 $(CURDIR)/tools/build/materialize.py --output $(PKG_BUILD_DIR)/root --version $(PKG_VERSION) --release $(PKG_RELEASE)
endef

define Package/luci-app-lanekeep/install
  $(CP) $(PKG_BUILD_DIR)/root/. $(1)/
endef

define Package/luci-app-lanekeep/conffiles
/etc/config/lanekeep
/etc/config/lanekeep_runtime
/etc/lanekeep-proxy/nodes.json
endef

define Package/luci-app-lanekeep/preinst
#!/bin/sh
if [ -z "$$IPKG_INSTROOT" ] && [ "$$PKG_UPGRADE" = 1 ]; then
  /usr/libexec/lanekeep-panel/lifecycle stop
fi
endef

define Package/luci-app-lanekeep/postinst
#!/bin/sh
[ -n "$$IPKG_INSTROOT" ] || /usr/libexec/lanekeep-panel/package-install
endef

define Package/luci-app-lanekeep/prerm
#!/bin/sh
[ -n "$$IPKG_INSTROOT" ] || /usr/libexec/lanekeep-panel/lifecycle disable
endef

$(eval $(call BuildPackage,luci-app-lanekeep))
