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
- There are **two framebuffers** (`fb0`, `fb1`). `fb0` is the internal LCD; `fb1` appears to
  be a secondary/off-screen buffer (e.g. for VNC), **not** a physical monitor output.
- **There is no HDMI video output.** The HDMI-shaped socket on the front panel is **not** a
  display output — it is the **MSO / logic-analyzer connector** (see below). The app's
  `hdmi_module_t` / `acq_cfg_hdmi_reset` belong to the **acquisition** subsystem, not display.
- Touch: **Goodix** capacitive controller via evdev (`/dev/input/event0`), panel 1024×600.
- **VNC** (port 5900, configurable via SCPI) reads `fb0` and serves the screen over the
  network — this is the real "external monitor", over LAN.

## Digital / MSO (logic analyzer) & external instruments

- The **HDMI-shaped front connector carries LVDS**, not HDMI video. The **SLA1016** 16-channel
  logic pod plugs in here. Data flows pod → LVDS → the **`sbus`** acquisition engine
  (`sbus_drv`) → DDR3 buffer → digital waveform + protocol decode (I²C/SPI/UART/CAN/LIN).
  Relevant strings: `MSO LVDS`, `acq_cfg_hdmi_reset`, `acq_drv_func_digital_sla1016_t`.
- **MSO is a licensed option** (`bu_cfg_if_mso_get_license_type`): using the pod needs both the
  SLA1016 **and** the MSO license.
- The **Wave-Gen** menu, by contrast, controls an **external Siglent SDG over USB** (USB-TMC
  host, `*IDN?` detection; supported: SDG1000X/2000X/6000X/6000X-E). It is **not** a built-in
  generator on this model — "device not recognized" means no supported SDG is attached.
- There is also an **active analog probe** auto-ID system (`CProbeBase`, `ProbeMcu::ProbeType`)
  that reads a probe's EEPROM/MCU over the BNC for gain/atten/degauss.

### Drawing your own content on the LCD

- `/dev/fb0` is owned by the Qt app, which repaints constantly. A naive overlay just gets
  overwritten.
- **Full-screen takeover** (stop the GUI, draw to `/dev/fb0`, restart) is reliable.
- A true **overlay while the GUI runs** only works if `fb1` composites onto the LCD as an
  overlay plane — unconfirmed; test on your unit.
