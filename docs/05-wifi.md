# 05 — Adding Wi-Fi (USB dongle feasibility)

**Short answer:** not plug-and-play. The 802.11 *stack* is in the kernel, but **no USB Wi-Fi
device driver is compiled in**, and the Wi-Fi userspace tools are absent. Getting any dongle
working is a real project, not a quick win.

## What the probe shows

Run [`scripts/wifi_probe.sh`](../scripts/wifi_probe.sh). On firmware V1.1.6.5 it reports:

- `CONFIG_CFG80211=y`, `CONFIG_MAC80211=y` — the wireless **stack** is built in. ✅
- **No in-tree USB Wi-Fi driver** enabled (no `RTL8187`, `RTL8XXXU`, `ath9k_htc`, …), and
  dependencies like `EEPROM_93CX6` are **off**.
- **`/lib/modules` is empty** — the kernel is monolithic; you can't just `insmod` a stock
  driver. (Module loading itself works — Siglent's own modules are loaded at boot from the
  app directory.)
- **`wpa_supplicant`, `iw`, `iwconfig`, `hostapd` are all missing.** Only `udhcpc`,
  `ifconfig`, `ip` exist.
- Wi-Fi is also a **licensed option** in the UI (`bu_cfg_if_wifi_get_license_type`), and the
  driver + `wpa_supplicant` appear to ship only with Siglent's official Wi-Fi package. The app
  itself drives a `wlan0` and expects `wpa_supplicant`/scan tooling.

## Why a random dongle (e.g. RTL8187) won't "just work"

Every USB Wi-Fi chip needs its driver **cross-compiled against this exact kernel** (matching
`vermagic`: `5.10.0+ #38 SMP`, gcc 8.4), *plus* cross-compiled `wpa_supplicant` + `iw` for
WPA networks. The RTL8187 additionally needs `eeprom_93cx6`, which is disabled. Lots of effort,
uncertain payoff, and you'd get 2.4 GHz 802.11g at best.

## Realistic paths

### Path A — no device modification (recommended, reliable)
The kernel has **USB-Ethernet drivers built in** (ASIX AX88772/AX88179, CDC-Ether/NCM). So:

1. Plug a cheap **USB-to-Ethernet adapter (ASIX chipset)** into the scope → it appears as a
   network interface with no extra work.
2. Feed that from a small **travel router / Wi-Fi bridge in client mode**.

Result: the scope is on Wi-Fi, **zero firmware risk**, a few euros. This is the sane way to get
a "wireless scope".

### Path B — build the driver (the real hack)
With the kernel `.config` (readable from `/proc/config.gz`) you can cross-build a Wi-Fi driver
module + `wpa_supplicant` + `iw` against the device kernel. Medium success odds (vermagic),
several evenings. If you attempt it, pick a chipset with a clean in-tree driver that needs **no
firmware blob**, not an ancient RTL8187.

> Note: bringing up `wlan0` at the Linux level gives you network connectivity regardless of the
> UI's Wi-Fi option — the application does not need to be involved for SSH/SCPI/VNC access.
