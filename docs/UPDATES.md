# Updates and boot environments

Arch rolls, and a rolling system occasionally breaks on an update. Constellation is built so that an update can never break the system you are using.

## Updating

    sudo constellation-be upgrade

1. Snapshots the running system and clones the snapshot into a new boot environment, `upgrade-YYYYMMDD-HHMM`.
2. Runs `paru -Syu` inside it (with `arch-chroot`, as you, so paru builds AUR packages normally). Kernels, DKMS modules and initramfs images are built there, not in your running system.
3. Checks the new environment can boot: every kernel has its initramfs and a ZFS module. (A new kernel that OpenZFS does not support yet is the usual way an Arch + ZFS system fails to boot; it is caught here.)
4. Makes it the default. Restart to use it. Your previous system is still in the ZFSBootMenu menu: press Escape at the countdown and pick it, or `sudo constellation-be activate NAME`.

If the update fails or the check fails, nothing changes: your running system stays the default, and the half-updated copy is left for you to inspect or remove (`sudo constellation-be destroy NAME`). `--no-activate` updates the copy without making it the default, so you can try it once from the menu first.

Plain `sudo pacman -Syu` and `paru -Syu` still work: a pacman hook snapshots the root before every transaction (`@pacman-…`, the newest 20 are kept), so even those can be undone.

## Other commands

| Command | What it does |
| --- | --- |
| `constellation-be list` | boot environments (running, default) and snapshots |
| `sudo constellation-be snapshot [NAME]` | snapshot now |
| `sudo constellation-be create NAME [SNAPSHOT]` | a new boot environment from a snapshot |
| `sudo constellation-be activate NAME` | boot NAME by default |
| `sudo constellation-be rollback SNAPSHOT` | a new boot environment from SNAPSHOT, made the default; nothing is rolled back in place |
| `sudo constellation-be destroy NAME` | delete one (never the running or default one) |

ZFSBootMenu can also boot any snapshot directly from its menu (it clones it first).

## Kernel choice

Constellation uses `linux-lts`: OpenZFS supports each LTS kernel reliably, and the Framework 13 Pro's Core Ultra Series 3 is supported from Linux 6.17. To try Arch's newest kernel, install `linux linux-headers` with `constellation-be upgrade`: if OpenZFS does not build for it, the check in step 3 refuses to activate that environment.
