# 06 — Running your own ARM64 programs

The scope is a normal aarch64 Linux (glibc) box, so your own cross-compiled binaries run
directly. There is **no compiler on the device** — build on your PC and copy over.

## Target profile

| Property | Value |
|----------|-------|
| Architecture | aarch64 / ARMv8-A (Cortex-A53) |
| Kernel | Linux 5.10 |
| libc | glibc 2.32 (Buildroot 2021.02.6) |
| Reference toolchain | aarch64 gcc 8.4, binutils 2.35 |

## Build

On a Linux box (or WSL):

```bash
sudo apt install gcc-aarch64-linux-gnu      # Debian/Ubuntu
```

```c
// hello.c
#include <stdio.h>
int main(void){ printf("Hello from the scope!\n"); return 0; }
```

```bash
aarch64-linux-gnu-gcc -static -O2 hello.c -o hello
```

`-static` makes the binary **dependency-free**, so it runs regardless of on-device library
versions. Dynamic linking also works (on-device glibc is 2.32).

## Deploy & run

```bash
scp hello root@<SCOPE-IP>:/usr/bin/siglent/usr/hello   # rw partition, survives reboot
ssh root@<SCOPE-IP> '/usr/bin/siglent/usr/hello'
```

Use `/tmp` instead if you want it gone on reboot.

## Ideas

- CLI tools / daemons: data loggers, SCPI bridges, automation.
- Framebuffer programs (see doc 03) — e.g. a full-screen custom display.
- Hardware poking via `/dev/i2c-0`, `devmem` (FPGA registers), the u-dma-buf raw-data buffers.
- **Live-debug the application**: run `gdbserver` on the scope, attach `gdb` from your PC.

## Caveats

- Don't fight the Qt GUI on `/dev/fb0` (see doc 03).
- If you use glibc features newer than 2.32, build `-static`.
