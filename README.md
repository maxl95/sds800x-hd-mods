# Siglent SDS800X HD — Reverse Engineering & Modding Notes

Community notes on the **Siglent SDS800X HD** oscilloscope series (firmware **V1.1.6.5**):
how the firmware update container works, how to get a root shell over SSH, what the
hardware/software looks like inside, and how far you can push custom modifications.

Everything here was produced on **privately owned hardware** for interoperability and
educational purposes. No device-specific identifiers are included (see
[DISCLAIMER.md](DISCLAIMER.md)).

> ⚠️ **Read [DISCLAIMER.md](DISCLAIMER.md) first.** Modifying firmware can brick your
> device and voids your warranty. You do this at your own risk.

---

## What's here

| Doc | Topic |
|-----|-------|
| [docs/01-ads-firmware-format.md](docs/01-ads-firmware-format.md) | The `.ADS` firmware container: structure, de-/encode, surgical repack tool |
| [docs/02-enable-ssh.md](docs/02-enable-ssh.md) | Getting a persistent root SSH shell via a custom update |
| [docs/03-system-internals.md](docs/03-system-internals.md) | SoC, partitions, services/ports, the display/video pipeline |
| [docs/04-options-license-system.md](docs/04-options-license-system.md) | How bandwidth / memory-depth / software options are license-gated (observations) |
| [docs/05-wifi.md](docs/05-wifi.md) | Can you add a USB Wi-Fi dongle? Feasibility and realistic paths |
| [docs/06-custom-arm64-binaries.md](docs/06-custom-arm64-binaries.md) | Cross-compiling and running your own ARM64 programs |
| [docs/07-boot-logo.md](docs/07-boot-logo.md) | Replacing the boot splash image |

Plus:
- [scripts/](scripts/) — read-only recon scripts + the SSH-enable script (all run on the scope)
- [tools/ads_repack_tool.py](tools/ads_repack_tool.py) — decode/encode `.ADS`, swap the `update.sh` member
- [sample-output/](sample-output/) — a **redacted** example of what the recon scripts produce

---

## The device in one paragraph

The SDS800X HD runs **Linux 5.10 (Buildroot 2021.02.6)** on a **Xilinx Zynq UltraScale+
MPSoC** (quad Cortex-A53 + FPGA). The GUI is a **Qt app rendering to the Linux framebuffer**
(`/dev/fb0`), pushed to the LCD through the FPGA. The whole product line (SDS800X / EDU / HD,
2- and 4-channel, 70/100/200 MHz) ships the **same binary and hardware**; bandwidth, memory
depth and software options are unlocked by a **license**. SSH (dropbear) and a telnet/SCPI
server are present in the image but SSH is disabled by default.

---

## Quick start (overview — details in the docs)

1. **Get the firmware.** Download the official `.ADS` for your model from Siglent. (Not
   redistributed here — see the disclaimer.)
2. **Build a modified update.** Use [`tools/ads_repack_tool.py`](tools/ads_repack_tool.py)
   to swap in your own `update.sh` (e.g. [`scripts/enable_ssh.sh`](scripts/enable_ssh.sh)).
   Only the `update.sh` member is replaced; the rest of the image stays byte-identical.
3. **Flash it** via the scope's normal **Utility → Upgrade** from USB.
4. **Connect:** `ssh root@<SCOPE-IP>`.

See [docs/02-enable-ssh.md](docs/02-enable-ssh.md) for the full, reversible procedure.

---

## Status of each goal

| Goal | Result |
|------|--------|
| Decode/repack `.ADS` | ✅ Tool with byte-identical round-trip |
| Developer-options menu password | ✅ Recovered from firmware (firmware-wide constant) |
| Persistent root SSH | ✅ Works, reversible |
| Understand display/video path | ✅ Framebuffer → FPGA → LCD; HDMI capable (not on all units) |
| License / options mechanism | ◐ Mapped observationally (no keygen provided) |
| USB Wi-Fi dongle | ◐ Assessed — not plug-and-play, see docs/05 |
| Run custom ARM64 binaries | ✅ Cross-compile + `scp`, runs as root |
