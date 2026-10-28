# Installing Constellation

**No network needed.** Every package comes from the USB stick, and so do the content packs the ISO was built with; they are copied to `/var/lib/constellation/russian`. The installer asks for the disk (only if there is more than one), your user name, a password and whether to encrypt; the host name (`constellation`), time zone (`Europe/London`) and keyboard (`uk`) have defaults you can change with `--hostname`, `--timezone` and `--keymap`.

`constellation-install` (from the live USB) erases one whole disk and installs Constellation on it. It follows ZFSBootMenu's Arch Linux UEFI guide. Rehearse it first: `constellation-install --dry-run` prints every command without running any.

It asks for the disk (the USB stick itself is never offered), your user name, a password, and whether to encrypt the disk. Options: `--disk`, `--username`, `--fullname`, `--password-file`, `--encrypt-passphrase-file` or `--no-encrypt`, `--hostname` (default `constellation`), `--timezone` (default `Europe/London`), `--keymap` (default `uk`), `--yes`.

## What it creates

| | |
| --- | --- |
| `p1` | 1 GB EFI system partition with ZFSBootMenu (and a backup copy, and the fallback `BOOTX64.EFI`) |
| `p2` | the ZFS pool `zroot`, `compatibility=openzfs-2.3-linux` so ZFSBootMenu's own OpenZFS can always read it; zstd compression; optional aes-256-gcm encryption with a passphrase |
| `zroot/ROOT/constellation` | the system: a boot environment, with `/boot` (kernels live on ZFS, so every boot environment has its own) |
| `zroot/home` | your files, shared by every boot environment |
| `zroot/data/constellation`, `zroot/data/ollama` | the Russian downloads and the AI model, shared by every boot environment, so a rollback never "loses" a download and snapshots stay small |

No swap partition: Constellation swaps to compressed RAM (zram).

## What it installs

`pacstrap` installs `base`, `linux-lts` with OpenZFS (`zfs-dkms`), `constellation-base`, `constellation-desktop` and `constellation-russian`, and the birthDate-free systemd family **in the same step as `base`**, so Arch's systemd is never installed. Constellation's own packages come from the copy of the repository on the USB stick (exactly what was built), Arch's from its mirrors. The live system's keyring, which trusts Constellation's signing key, is copied to the new system.

Then: hostname, `en_GB.UTF-8` (and `ru_RU.UTF-8`), keyboard, time zone, the mkinitcpio `zfs` hook (and the key file, if encrypted, in a root-only initramfs), the ZFS services, NetworkManager, greetd, your account (in `wheel`, with fish), a locked root account, ZFSBootMenu on the EFI partition with two firmware boot entries, and a snapshot called `installed`.

## First start

ZFSBootMenu starts first (asks for the disk passphrase if you chose encryption) and boots the default boot environment after a short countdown; press Escape during it to choose another boot environment or a snapshot. Log in at the greetd screen; niri and the Caelestia shell start. Super+Shift+/ shows every key binding.

Then, when you like: `sudo constellation-content` for the Russian material.
