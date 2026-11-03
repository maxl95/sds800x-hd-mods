#!/bin/sh
# SDS800X HD - READ-ONLY video/display probe. Shows framebuffers, DRM/KMS,
# HDMI/DisplayPort status, VDMA and VNC. Modifies NOTHING.
TS=$(date +%Y%m%d_%H%M%S 2>/dev/null || echo run)
SHARE=/usr/bin/siglent/usr/mass_storage/local
[ -d "$SHARE" ] || SHARE=/usr/bin/siglent/usr
OUT="$SHARE/video_${TS}.txt"
{
  echo "===== VIDEO/DISPLAY PROBE $TS ====="
  echo "## framebuffer devices"; ls -la /dev/fb* 2>/dev/null
  echo "## fbset -i"; fbset -i 2>&1
  echo "## /sys/class/graphics/fb0"
  for f in name virtual_size bits_per_pixel stride modes; do
    printf '%s = ' "$f"; cat /sys/class/graphics/fb0/$f 2>/dev/null; echo
  done
  echo "## DRM/KMS"; ls -la /dev/dri 2>/dev/null
  echo "## /sys/class/drm connector status"
  for c in /sys/class/drm/*/status; do [ -f "$c" ] && { printf '%s: ' "$c"; cat "$c"; }; done 2>/dev/null
  echo "## modetest (if present)"; (command -v modetest >/dev/null && modetest -c 2>&1 | head -40) || echo "no modetest"
  echo "## dmesg: fb/drm/dp/hdmi/vdma/panel/display"
  dmesg 2>/dev/null | grep -iE 'fb|drm| dp|hdmi|vdma|panel|display|goodix|vout|mixer' | head -60
  echo "## VNC process + port"; ps w 2>/dev/null | grep -i vnc | grep -v grep
  netstat -tlnp 2>/dev/null | grep -E ':5900|:59[0-9][0-9]'
  echo "## Qt platform / app environment"
  cat /usr/bin/siglent/product_environment.sh 2>/dev/null
  tr '\0' '\n' < /proc/$(pidof main.app 2>/dev/null | awk '{print $1}')/environ 2>/dev/null | grep -iE 'QT_|QPA|FB|DIRECTFB|DISPLAY'
  echo "## HDMI/EDID via i2c (bus list only, no dump)"; ls /dev/i2c* 2>/dev/null
  echo "===== END (OUT=$OUT) ====="
} > "$OUT" 2>&1
sync
cp "$OUT" /usr/bin/siglent/usr/ 2>/dev/null
sync
echo "Report: $OUT"
exit 0
