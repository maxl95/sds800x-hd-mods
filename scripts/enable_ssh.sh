#!/bin/sh
# SDS800X HD - enable SSH (dropbear) with root password login.
# - Sets the root password (hash below). REVERSIBLE: backs up /etc/shadow first.
# - Adds a persistent autostart /etc/init.d/S60sshon (base rootfs, survives updates).
# - No new user, no HOME change, no writes to the read-only partition (p10).
# Runs as root from the firmware update. Busybox-ash compatible.
#
# >>> SET YOUR OWN PASSWORD HASH BELOW. Do not ship a shared default. <<<
# Generate one on any Linux box or on the scope:   mkpasswd -m sha-256 'your-password'
# Then paste the resulting $5$... string into NEWHASH.
NEWHASH='$5$REPLACE_WITH_YOUR_OWN_SHA256CRYPT_HASH'
KD=/usr/bin/siglent/usr/dropbear

TS=$(date +%Y%m%d_%H%M%S 2>/dev/null || echo run)
SHARE=/usr/bin/siglent/usr/mass_storage/local
[ -d "$SHARE" ] || SHARE=/usr/bin/siglent/usr
LOG="$SHARE/ssh_enable_${TS}.log"
BK=/usr/bin/siglent/usr/ssh_backup
mkdir -p "$BK" 2>/dev/null

{
  echo "== SDS800X HD: enable SSH (password) $TS =="

  # Safety guard: refuse to run with the placeholder hash still in place.
  case "$NEWHASH" in
    *REPLACE_WITH_YOUR_OWN*)
      echo "ABORT: NEWHASH is still the placeholder. Set your own hash first."
      echo "       mkpasswd -m sha-256 'your-password'  ->  paste into NEWHASH"
      exit 1 ;;
  esac

  # 0) Back up /etc/shadow (to restore the original root hash)
  if cp -a /etc/shadow "$BK/shadow.$TS" 2>/dev/null; then
    echo "backup -> $BK/shadow.$TS"
  else
    echo "WARN: shadow backup failed"
  fi

  # 1) Set root password hash (only field 2 of the root: line, rest unchanged)
  if [ -w /etc/shadow ]; then
    if awk -F: -v OFS=: -v NH="$NEWHASH" '$1=="root"{$2=NH} {print}' /etc/shadow > /tmp/shadow.new 2>/dev/null; then
      if grep -q '^root:' /tmp/shadow.new; then
        cat /tmp/shadow.new > /etc/shadow && echo "root password hash set"
      else
        echo "ERROR: new shadow has no root line, not applied"
      fi
      rm -f /tmp/shadow.new
    else
      echo "ERROR: awk rewrite failed"
    fi
  else
    echo "ERROR: /etc/shadow not writable"
  fi
  echo "-- root line now:"; grep '^root:' /etc/shadow

  # 2) Persistent dropbear autostart (additive, base rootfs). Runs at every boot via rcS.
  cat > /etc/init.d/S60sshon <<'EOS'
#!/bin/sh
# custom: dropbear SSH (password login) with persistent host keys, additive
KD=/usr/bin/siglent/usr/dropbear
start() {
  mkdir -p "$KD" 2>/dev/null
  [ -f "$KD/ed25519" ] || /usr/bin/dropbearkey -t ed25519 -f "$KD/ed25519" >/dev/null 2>&1
  [ -f "$KD/rsa" ]     || /usr/bin/dropbearkey -t rsa -s 2048 -f "$KD/rsa"   >/dev/null 2>&1
  /usr/sbin/dropbear -r "$KD/ed25519" -r "$KD/rsa" -p 22 -P /var/run/dropbear.pid >/dev/null 2>&1
}
case "$1" in
  stop) kill "$(cat /var/run/dropbear.pid 2>/dev/null)" 2>/dev/null ;;
  *)    start ;;
esac
exit 0
EOS
  chmod 755 /etc/init.d/S60sshon
  echo "wrote /etc/init.d/S60sshon"

  # 3) Generate host keys now (so the first login after reboot works immediately)
  mkdir -p "$KD" 2>/dev/null
  [ -f "$KD/ed25519" ] || /usr/bin/dropbearkey -t ed25519 -f "$KD/ed25519" >/dev/null 2>&1
  [ -f "$KD/rsa" ]     || /usr/bin/dropbearkey -t rsa -s 2048 -f "$KD/rsa"   >/dev/null 2>&1
  echo "-- host keys:"; ls -l "$KD"

  # 4) Start dropbear now (without waiting for the reboot)
  if /usr/sbin/dropbear -r "$KD/ed25519" -r "$KD/rsa" -p 22 -P /var/run/dropbear.pid >/dev/null 2>&1; then
    echo "dropbear started now (pid $(cat /var/run/dropbear.pid 2>/dev/null))"
  else
    echo "immediate dropbear start failed - will come up after reboot via S60sshon"
  fi

  echo "== done. Login:  ssh root@<SCOPE-IP>   (password you set in NEWHASH) =="
  echo "   Restore original root hash:  cp $BK/shadow.$TS /etc/shadow"
} > "$LOG" 2>&1

sync
cp "$LOG" /usr/bin/siglent/usr/mass_storage/ 2>/dev/null
cp "$LOG" /usr/bin/siglent/usr/ 2>/dev/null
sync
exit 0
