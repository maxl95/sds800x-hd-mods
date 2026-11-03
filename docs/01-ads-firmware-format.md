# 01 — The `.ADS` firmware container

Siglent ships SDS800X HD firmware as a single `.ADS` file. It is an obfuscated, partially
encrypted wrapper around an ordinary **ZIP archive**.

## Layout

```
+--------------------------------------------------+
| 112-byte header (check word, length, meta)       |
+--------------------------------------------------+
| payload (obfuscated)                             |
|   - two regions additionally covered by a        |
|     non-standard 2-key 3DES (ECB) pass           |
|   - whole-payload byte reordering + XOR masking  |
|   => after decode: a ZIP starting at offset 0x34 |
+--------------------------------------------------+
```

The decoded payload is a ZIP whose members are the actual firmware parts:

| Member | What it is |
|--------|------------|
| `bsp/Image` | Linux kernel (ARM64) |
| `bsp/system.dtb` | Device tree |
| `firmdata0/factory_setting.xml` | factory/metadata |
| `siglent.ext4` | root application filesystem (ext4 image, ~200 MB) |
| `update.sh` | **runs as root during the update** |
| `update_config` | small config blob |

The header stores a **check word** = two's-complement negation of the byte sum of the
payload, so any change to the payload must be followed by recomputing it, or the scope
rejects the file.

## Why `update.sh` matters

During a firmware update the scope mounts the image and executes `update.sh` **as root**.
That makes it the clean, intended hook for running your own code once, with full privileges —
no exploit required. This is the basis for the SSH-enable procedure (doc 02).

## The repack tool

[`tools/ads_repack_tool.py`](../tools/ads_repack_tool.py) implements the decode/encode and a
**surgical** replacement of the `update.sh` member. Because `update.sh` is the last member in
the ZIP, swapping it only shifts the central directory + EOCD — **every other member
(kernel, `siglent.ext4`, dtb, …) stays byte-identical**. That keeps brick risk minimal and
lets you verify the result.

### Usage

```bash
# Point the tool at your model's official .ADS (download it yourself):
export SDS_ADS=/path/to/your_model_firmware.ADS

# Self-test: decodes and re-encodes unchanged -> must print FULL==orig: True
python tools/ads_repack_tool.py

# Build a modified image with your own update.sh:
python tools/ads_repack_tool.py build scripts/enable_ssh.sh out.ADS
```

The `build` step prints a verification: it decodes the result, confirms `update.sh` matches
your input, and checks that all other members are unchanged (`VERIFY: PASS`).

> The tool contains no firmware. It needs the official `.ADS` for your model, supplied via
> the `SDS_ADS` environment variable (or placed one directory above the tool).

## Flashing

Copy the produced `out.ADS` to a USB stick and use the scope's normal
**Utility → Upgrade**. The scope validates, reboots (typically twice), runs your `update.sh`
as root, and boots normally.
