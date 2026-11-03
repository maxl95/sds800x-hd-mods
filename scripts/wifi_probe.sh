#!/bin/sh
# SDS800X HD - READ-ONLY Wi-Fi feasibility probe.
# Checks whether WLAN kernel modules + userspace tools exist to bring up a
# USB Wi-Fi dongle. Modifies NOTHING.
TS=$(date +%Y%m%d_%H%M%S 2>/dev/null || echo run)
SHARE=/usr/bin/siglent/usr/mass_storage/local
[ -d "$SHARE" ] || SHARE=/usr/bin/siglent/usr
OUT="$SHARE/wifi_${TS}.txt"
{
  echo "===== WIFI PROBE $TS ====="
  echo "## kernel"; uname -a
  echo "## USB devices (lsusb)"; lsusb 2>/dev/null
  echo "## loaded modules (lsmod)"; lsmod 2>/dev/null
  echo "## /lib/modules contents"
  ls -la /lib/modules 2>/dev/null
  find /lib/modules -type f 2>/dev/null | head -400
  echo "## WLAN-relevant modules on disk"
  find / -xdev \( -name 'rtl8187*.ko*' -o -name 'mac80211.ko*' -o -name 'cfg80211.ko*' \
    -o -name 'eeprom_93cx6*.ko*' -o -name 'lib80211*.ko*' -o -name 'rtl*.ko*' \
    -o -name '*80211*.ko*' \) 2>/dev/null | head -80
  echo "## kernel config (/proc/config.gz)"
  if [ -f /proc/config.gz ]; then
    zcat /proc/config.gz 2>/dev/null | grep -iE 'RTL8187|RTL8XXXU|MAC80211|CFG80211|WLAN|WEXT|CONFIG_USB_NET|EEPROM_93CX6|WIRELESS' | head -60
  else
    echo "no /proc/config.gz"
  fi
  echo "## userspace tools"
  for t in wpa_supplicant wpa_cli wpa_passphrase iw iwconfig iwlist hostapd udhcpc dhcpcd ifconfig ip rfkill; do
    printf '%s: ' "$t"; (command -v "$t" 2>/dev/null || echo MISSING)
  done
  echo "## wpa_supplicant binary locations"
  find / -xdev -name 'wpa_supplicant*' -o -name 'wpa_cli' 2>/dev/null | head
  echo "## /lib/firmware (WLAN blobs?)"
  ls -la /lib/firmware 2>/dev/null | head -40
  find /lib/firmware -iname '*rtl*' -o -iname '*8187*' -o -iname '*8188*' -o -iname '*8812*' 2>/dev/null | head
  echo "## network interfaces now"
  ip link 2>/dev/null || ifconfig -a 2>/dev/null
  echo "## iw dev / phy"
  iw dev 2>/dev/null; iw phy 2>/dev/null | head -20
  echo "## Siglent WLAN config/scripts"
  ls -laR /usr/bin/siglent/usr/wifi 2>/dev/null
  find /usr/bin/siglent -iname '*wifi*' -o -iname '*wlan*' -o -iname 'wpa_supplicant*' 2>/dev/null | head -40
  echo "## dmesg: wlan/rtl/80211/firmware"
  dmesg 2>/dev/null | grep -iE 'rtl|8187|wlan|ieee80211|cfg80211|mac80211|firmware|usbcore.*regist' | tail -60
  echo "===== END (OUT=$OUT) ====="
} > "$OUT" 2>&1
sync
cp "$OUT" /usr/bin/siglent/usr/ 2>/dev/null
sync
echo "Report: $OUT"
exit 0
