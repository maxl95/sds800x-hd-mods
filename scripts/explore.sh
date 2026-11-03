#!/bin/sh
# SDS800X HD - READ-ONLY system exploration (run over the SSH shell).
# Collects system, hardware, flash, service and config info into ONE report file.
# Focus: locate serial / model / options / bandwidth / calibration.
# Modifies NOTHING (only a report file is written). Busybox-ash compatible.

TS=$(date +%Y%m%d_%H%M%S 2>/dev/null || echo run)
SHARE=/usr/bin/siglent/usr/mass_storage/local
[ -d "$SHARE" ] || SHARE=/usr/bin/siglent/usr
[ -d "$SHARE" ] || SHARE=/tmp
OUT="$SHARE/explore_${TS}.txt"

sec() { echo; echo "===== $* ====="; }
dump() { echo "--- $1"; cat "$1" 2>&1; }

{
  echo "######## SDS800X HD EXPLORE $TS ########"

  sec "KERNEL / OS"
  uname -a 2>&1
  dump /proc/version
  dump /etc/os-release
  dump /etc/issue
  ls -la /etc/*release* /etc/*version* /usr/bin/siglent/*version* 2>/dev/null
  echo "--- version hints"
  find / -xdev -maxdepth 4 -iname '*version*' 2>/dev/null | head -40

  sec "CPU / MEM"
  dump /proc/cpuinfo
  dump /proc/meminfo
  echo "--- loadavg/uptime"; cat /proc/loadavg 2>&1; uptime 2>&1

  sec "STORAGE: mounts / df / partitions"
  mount 2>&1
  df -h 2>&1
  dump /proc/partitions
  echo "--- block devices"; ls -la /dev/mmcblk* /dev/sd* /dev/mtd* 2>/dev/null
  echo "--- lsblk"; lsblk 2>/dev/null

  sec "FLASH / MTD / U-Boot env"
  dump /proc/mtd
  echo "--- fw_printenv (U-Boot environment)"; fw_printenv 2>&1
  echo "--- uboot/env files"; find / -xdev -iname 'uboot*' -o -iname '*u-boot*' -o -iname 'fw_env*' 2>/dev/null | head

  sec "PROCESSES / SERVICES / PORTS"
  (ps w 2>/dev/null || ps aux 2>/dev/null || ps 2>/dev/null)
  echo "--- listening ports"; (netstat -tlnp 2>/dev/null || netstat -tln 2>/dev/null || ss -tlnp 2>/dev/null)
  echo "--- all init scripts"; ls -la /etc/init.d/ 2>&1

  sec "NETWORK"
  (ip addr 2>/dev/null || ifconfig -a 2>/dev/null)
  echo "--- routes"; (ip route 2>/dev/null || route -n 2>/dev/null)
  dump /etc/resolv.conf
  dump /etc/hosts

  sec "SIGLENT APP DIRECTORY (top level)"
  ls -la /usr/bin/siglent/ 2>&1
  echo "--- usr (rw p12)"; ls -la /usr/bin/siglent/usr/ 2>&1
  echo "--- config directory"; ls -laR /usr/bin/siglent/usr/config/ 2>/dev/null | head -200

  sec "MODEL / SERIAL / OPTIONS / BANDWIDTH (search)"
  echo "## filename matches"
  find / -xdev \( -iname '*licen*' -o -iname '*option*' -o -iname '*.lic' -o -iname '*.key' \
    -o -iname '*cal*' -o -iname '*serial*' -o -iname '*model*' -o -iname '*factory*' \
    -o -iname '*bandwidth*' -o -iname '*.dat' \) 2>/dev/null | grep -v '^/proc\|^/sys' | head -200
  echo
  echo "## contents of small config/XML/INI files under siglent/usr/config"
  for f in $(find /usr/bin/siglent/usr/config -type f \( -name '*.xml' -o -name '*.ini' -o -name '*.conf' -o -name '*.txt' -o -name '*.json' -o -name '*.cfg' \) 2>/dev/null); do
    sz=$(wc -c < "$f" 2>/dev/null)
    if [ -n "$sz" ] && [ "$sz" -lt 20000 ]; then echo "----- $f ($sz B)"; cat "$f" 2>&1; echo; fi
  done
  echo
  echo "## keyword search (model/option/bandwidth/serial) in text files"
  grep -rIlniE 'bandwidth|license|option|serial|SDS8[0-9]+|model' /usr/bin/siglent/usr/config /etc 2>/dev/null | head -60

  sec "FACTORY SETTING (if readable)"
  find / -xdev -iname 'factory_setting*' 2>/dev/null
  echo "--- (large files only listed, not dumped)"

  sec "CALIBRATION"
  find / -xdev -iname '*cal*' -type f 2>/dev/null | grep -viE 'calendar|local|cacl' | head -80
  ls -la /usr/bin/siglent/usr/cal* /usr/bin/siglent/cal* 2>/dev/null

  sec "SCPI / REMOTE CONTROL"
  grep -rIlniE 'scpi' /usr/bin/siglent /etc 2>/dev/null | head -40
  echo "--- lxi/vxi/telnet services"; ls -la /etc/init.d/*telnet* /etc/init.d/*lxi* /etc/init.d/*scpi* 2>/dev/null

  sec "WEB / PHP"
  find / -xdev \( -iname '*.php' -o -name 'index.html' -o -name 'lighttpd*' -o -name '*nginx*' \) 2>/dev/null | head -60
  find / -xdev -iname '*.conf' 2>/dev/null | grep -iE 'lighttpd|nginx|httpd|php' | head

  sec "DMESG (boot log)"
  dmesg 2>&1 | tail -200

  sec "INSTALLED TOOLS (busybox applets etc.)"
  busybox 2>&1 | sed -n '/Currently defined functions/,$p' | head -40
  echo "--- /usr/bin, /usr/sbin (excerpt)"; ls /usr/bin /usr/sbin 2>/dev/null | sort | head -200

  echo
  echo "######## END (OUT=$OUT) ########"
} > "$OUT" 2>&1

sync
cp "$OUT" /usr/bin/siglent/usr/mass_storage/ 2>/dev/null
cp "$OUT" /usr/bin/siglent/usr/ 2>/dev/null
sync
exit 0
