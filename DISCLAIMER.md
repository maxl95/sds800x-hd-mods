# Disclaimer & Scope

## Risk
Modifying oscilloscope firmware can **permanently damage (brick) the device** and **voids
your warranty**. Everything in this repository is provided **as-is, without any warranty**.
You are solely responsible for anything you do to your own hardware.

## Purpose
These notes document **interoperability and educational** reverse-engineering of a device
the authors **own**. The goal is understanding the platform (a standard Linux/Qt system),
enabling standard Linux services (SSH) on your own unit, and running your own software on it.

## What is NOT included, and why
- **No Siglent firmware** (`.ADS`) or any file extracted from it (kernel, root filesystem,
  the main application binary, boot logos, fonts). Those are Siglent's copyrighted property —
  download them yourself from the official source for your model.
- **No license keys, key generators, or instructions to forge licenses.** The license system
  is described **observationally only**. Unlocking paid options you have not purchased may be
  unlawful in your jurisdiction and is not the aim of this document.
- **No device identifiers.** All serial numbers, MAC addresses, IP addresses, hostnames,
  build IDs and locale data have been removed or replaced with placeholders
  (`<SCOPE-IP>`, `SDSxxxxxxxxx`, `XX:XX:XX:XX:XX:XX`). Sample outputs are redacted.

## Placeholders used throughout
| Placeholder | Meaning |
|-------------|---------|
| `<SCOPE-IP>` | Your oscilloscope's IP address |
| `SDSxxxxxxxxx` | Your unit's serial number |
| `XX:XX:XX:XX:XX:XX` | A MAC address |
| `<password>` | A password you choose yourself |

## Reversibility
The SSH-enable procedure backs up the file it changes and can be fully reverted, and the
repack tool only swaps the `update.sh` member (the rest of the image is untouched). Still:
keep the **original, unmodified** `.ADS` for your model as your ultimate rollback.
