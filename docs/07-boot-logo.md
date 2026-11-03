# 07 — Custom boot logo

The power-on splash and the "updating" screen are plain bitmap files on a FAT partition, so
you can replace them live over SSH — no re-flash needed.

## Where / what

- Partition **p8**, mounted at **`/mnt/logo`** (vfat, read-write).
- `logo.bmp` — power-on splash.
- `update_logo.bmp` — shown during a firmware update.
- Format of both: **1024×600, 24-bit uncompressed BMP** (54-byte header), bottom-up row order
  (standard Windows BMP).

> The stock images are Siglent artwork and are **not** included here. Make your own.

## Make a compatible image

Any 1024×600 image, exported as 24-bit BMP. For example with ImageMagick:

```bash
magick input.png -resize 1024x600! -type TrueColor BMP3:logo.bmp
```

(`BMP3` = classic 24-bit BMP; `!` forces exact size.)

## Install (live, over SSH)

```bash
# back up the originals first!
ssh root@<SCOPE-IP> 'cp /mnt/logo/logo.bmp /usr/bin/siglent/usr/logo.bmp.bak'
scp logo.bmp root@<SCOPE-IP>:/mnt/logo/logo.bmp
ssh root@<SCOPE-IP> 'sync'
```

Reboot to see it. If something looks wrong, copy the backup back.

## Risk

Very low: worst case is a wrong/garbled splash, fixed by restoring the backup. It does not
touch the application or the read-only system partitions.
