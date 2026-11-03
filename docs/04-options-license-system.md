# 04 — Options & license system (observations)

> This chapter is **descriptive only**. It documents how the device appears to gate features,
> for understanding the platform. It contains **no keys, no key generator, and no instructions
> to forge licenses.** Unlocking options you have not purchased may be unlawful where you live.

## The whole series is one binary

The application references the model strings `SDS800X`, `SDS800XEDU`, `SDS800XHD`. A single
application binary and a single hardware platform span the entire line — the differences
between models (channels, bandwidth, memory depth) are **licensed**, not separate hardware.

## What a license controls

Strings and symbols in the application show a full licensing subsystem
(`license_module_t`, `drv_license_t`, `installOption()`, `autoInstallUdiskLicense()`,
SCPI `LCISL` / `LICENSE_KEY` / `LICENSE_ID?`). A license encodes, among other things:

- **Bandwidth** (e.g. 70 / 100 / 200 MHz) — the code literally logs
  *"Input license match bandwidth"*.
- **Memory depth** — tiers of 10 / 20 / 50 / 100 / 200 / 500 Mpts ("…match mem_depth").
- **Software options** (serial-bus decoders, analysis packages, Wi-Fi, …), some apparently
  **time-limited/trial** (there are per-option "times" counters).

## How licenses are applied

- **From USB** (`autoInstallUdiskLicense()`), or
- **Over SCPI** (`LICENSE_KEY`, `LICENSE_ID?`).

The presence of an `MD5_SRLN?` SCPI query (MD5 of the serial number) indicates the license is
**tied to the unit's serial number** — i.e. a license for one scope will not work on another.

## Practical implications (legitimate)

- **If you bought an option** and need to re-apply it after a reset/repair, the install paths
  above are how the UI does it.
- **Bandwidth is per-serial**; there is no generic file you can copy between units.
- For understanding/limits testing on your **own** unit, you can read the current license
  state over SCPI and observe the UI behavior — without changing anything.

That is the extent of what is documented here.
