# 02 — Enabling a persistent root SSH shell

The image already contains **dropbear** (SSH server), it is just not started. The scope also
runs as **root**, mounts `/` read-write, and runs `update.sh` as root during an update — so we
can enable SSH cleanly, persistently and reversibly, without any exploit.

## How it works

The boot process runs `/etc/init.d/S??*` scripts. We add our own
`/etc/init.d/S60sshon` that starts dropbear with persistent host keys. Because it lives on the
base root filesystem, it survives reboots (and even normal firmware updates).

dropbear's public-key login for `root` is blocked on this platform (root's home directory is
owned by a non-root UID on a read-only partition, which fails dropbear's ownership check).
Changing the home directory or that partition is invasive, so the simplest robust option is
**password login**, using a password you set yourself. `/etc/shadow` is on the already-rw root
filesystem, so this is a light, fully reversible change.

## The script

See [`scripts/enable_ssh.sh`](../scripts/enable_ssh.sh). It:

1. **Backs up** `/etc/shadow` to `…/usr/ssh_backup/shadow.<timestamp>` (for rollback).
2. **Sets the root password** by replacing only the hash field of the `root:` line with a
   precomputed SHA-256-crypt (`$5$`) hash. **Generate your own** (see below) — do not ship a
   shared default.
3. Writes **`/etc/init.d/S60sshon`** (persistent dropbear autostart, host keys on the rw
   `usr` partition).
4. Generates host keys and starts dropbear immediately.
5. Logs everything to the SMB share for inspection.

### Set your own password hash

On any Linux box (or the scope itself, which has `mkpasswd`):

```bash
mkpasswd -m sha-256 'your-password'
# -> $5$....  paste this into NEWHASH= in scripts/enable_ssh.sh
```

## Build & flash

```bash
export SDS_ADS=/path/to/your_model_firmware.ADS
python tools/ads_repack_tool.py build scripts/enable_ssh.sh out.ADS
# copy out.ADS to USB -> Utility -> Upgrade
```

## Connect

```bash
ssh root@<SCOPE-IP>
```

If your client refuses the key exchange or host-key type, dropbear offers an ed25519 host key;
accept the fingerprint on first connect.

## Rollback

Over SSH:

```bash
# restore original root hash
cp /usr/bin/siglent/usr/ssh_backup/shadow.<timestamp> /etc/shadow
# fully disable SSH again
rm /etc/init.d/S60sshon
```

Or re-flash the **original, unmodified** `.ADS` for your model.

## Security note

A root shell on an open port is fine on an **isolated lab network** only. On any reachable
network, use a strong password (or solve key-auth properly) and consider firewalling.
