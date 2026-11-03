# 03 — System internals

All of this is read-only observation (see [`scripts/explore.sh`](../scripts/explore.sh)).

## SoC / platform

- **Xilinx Zynq UltraScale+ MPSoC** ("Xilinx ZUP"), quad **Cortex-A53** + FPGA.
- ~480 MB RAM, **eMMC ~3.6 GiB**.
- **Linux 5.10**, Buildroot 2021.02.6, glibc. Toolchain: aarch64 gcc 8.4 / binutils 2.35.
- The FPGA loads a bitstream at boot (the acquisition engine); the analog front-end gain
  stages ("VGA" in the code = *variable gain amplifier*, not a video connector) are driven
  over SPI/I²C.
- Hardware crypto present: ZynqMP AES & RSA, `securefw` → firmware is likely RSA-signed.

## Storage (eMMC partitions)

| Partition | Mount | FS | Notes |
|-----------|-------|----|-------|
| p7 | `/` | ext4 | root (remounted rw) |
| p8 | `/mnt/logo` | vfat | **boot logo** images |
| p9 | `/usr/bin/siglent/firmdata0` | ext4 (ro) | factory / calibration data |
| p10 | `/usr/bin/siglent` | ext4 (ro) | the application |
| p11 | *(unmounted)* | — | ~120 MB, purpose unconfirmed |
| p12 | `/usr/bin/siglent/usr` | ext4 (rw) | user/runtime data |
| boot0/boot1 | — | — | eMMC boot (bootloader/FSBL) |

U-Boot environment is readable with `fw_printenv` after creating `/etc/fw_env.config`.

## Services & open ports

| Port | Service |
|------|---------|
| 22 | SSH (dropbear) — off by default |
| 80 | Web UI (lighttpd + php-cgi) |
| 111 | rpcbind |
| 21 | FTP (vsftpd) |
| 139 / 445 | SMB (Samba) — file share |
| 5900 | VNC (remote screen) |
| 5024 / 5025 | SCPI (telnet / raw) |

The SMB share maps to a folder under the rw `usr` partition — a convenient way to pull files
off the scope without extra tooling.

Rich on-device toolset: `gdb`, `gdbserver`, `strings`, `hexedit`, `devmem`, `i2c*`, `mtd*`,
`flash*`, `fw_printenv/setenv`, `mmc`, `dd`, `mkpasswd`. No compiler on-device.

## Display / video pipeline

- The GUI is **Qt using the `linuxfb` platform plugin**, rendering straight to **`/dev/fb0`**
  (name `siglent`, **1024×600, 32 bpp**). No DRM/KMS, no DirectFB for the app, no GPU.
- Pixels reach the panel through the **FPGA via AXI VDMA**. The FPGA generates the display
  timing itself — there is no separate LCD-controller chip.
- There are **two framebuffers** (`fb0`, `fb1`) and two VDMA engines: `fb0` = internal LCD,
  `fb1` = **HDMI** (class `hdmi_module_t` in the app). Note the HDMI connector is **not
  populated on all models**.
- Touch: **Goodix** capacitive controller via evdev (`/dev/input/event0`), panel 1024×600.
- **VNC** (port 5900, configurable via SCPI) reads `fb0` and serves the screen over the
  network — effectively a wireless "external monitor".

### Drawing your own content on the LCD

- `/dev/fb0` is owned by the Qt app, which repaints constantly. A naive overlay just gets
  overwritten.
- **Full-screen takeover** (stop the GUI, draw to `/dev/fb0`, restart) is reliable.
- A true **overlay while the GUI runs** only works if `fb1` composites onto the LCD as an
  overlay plane — unconfirmed; test on your unit.
