#!/bin/sh
# SDS800X HD - READ-ONLY recon. Writes a report into the SMB mass-storage share.
# Does NOT modify the system (only a report file is created).
# Runs as root from the firmware update. Busybox-ash compatible.

TS=$(date +%Y%m%d_%H%M%S 2>/dev/null || echo run)
NAME="recon_${TS}.txt"

# Candidate directories for the SMB-visible folder (best first)
OUT=""
for D in \
  /usr/bin/siglent/usr/mass_storage/local \
  /usr/bin/siglent/usr/mass_storage \
  /usr/bin/siglent/usr/mass_storage/U-disk0 \
  /usr/bin/siglent/usr ; do
  if [ -d "$D" ]; then OUT="$D/$NAME"; break; fi
done
[ -z "$OUT" ] && OUT="/tmp/$NAME"

{
  echo "===== SDS800X HD RECON $TS ====="
  echo "## id"; id 2>&1
  echo "## uname"; uname -a 2>&1
  echo "## partitions"; cat /proc/partitions 2>&1
  echo "## mounts"; mount 2>&1
  echo "## df"; df -h 2>&1
  echo "## /etc/init.d"; ls -la /etc/init.d/ 2>&1
  echo "## dropbear/telnet binaries"
  for b in dropbear dropbearkey dropbearconvert telnetd sshd; do
    printf '%s: ' "$b"; (command -v "$b" 2>/dev/null || which "$b" 2>/dev/null || echo NOTFOUND)
  done
  echo "## find dropbear/ssh"; find / -xdev \( -iname 'dropbear*' -o -iname 'sshd' \) 2>/dev/null
  echo "## /etc/dropbear"; ls -la /etc/dropbear 2>/dev/null
  echo "## S50dropbear"; cat /etc/init.d/S50dropbear 2>/dev/null
  echo "## S50telnet";   cat /etc/init.d/S50telnet 2>/dev/null
  echo "## S91smb";      cat /etc/init.d/S91smb 2>/dev/null
  echo "## product_rcs_begin.sh (path+perms)"; ls -la /usr/bin/siglent/product_rcs_begin.sh 2>/dev/null
  echo "## IGNORE_LIST consumer"; grep -rn IGNORE_LIST /etc 2>/dev/null
  echo "## rcS"; cat /etc/init.d/rcS 2>/dev/null
  echo "## smb.conf locations"; find / -xdev -name 'smb.conf' 2>/dev/null
  echo "## smb.conf contents"
  for f in $(find / -xdev -name 'smb.conf' 2>/dev/null); do echo "--- $f"; cat "$f" 2>/dev/null; done
  echo "## samba_storage_info.xml"; cat /usr/bin/siglent/usr/config/samba_storage_info.xml 2>/dev/null
  echo "## mass_storage listing"
  ls -la /usr/bin/siglent/usr/mass_storage/ 2>/dev/null
  ls -la /usr/bin/siglent/usr/mass_storage/local/ 2>/dev/null
  echo "## /etc/passwd"; cat /etc/passwd 2>/dev/null
  echo "## /etc/shadow (existence only)"; ls -la /etc/shadow 2>/dev/null
  echo "## ps"; (ps w 2>/dev/null || ps aux 2>/dev/null || ps 2>/dev/null)
  echo "## listening ports"; (netstat -tlnp 2>/dev/null || netstat -tln 2>/dev/null)
  echo "## which smbd nmbd"; (command -v smbd nmbd 2>/dev/null; ls -la /usr/local/samba/bin 2>/dev/null)
  echo "===== END (OUT=$OUT) ====="
} > "$OUT" 2>&1

sync
# Safety copies into the mass_storage root, in case the share points elsewhere
cp "$OUT" /usr/bin/siglent/usr/mass_storage/ 2>/dev/null
cp "$OUT" /usr/bin/siglent/usr/ 2>/dev/null
sync
exit 0
