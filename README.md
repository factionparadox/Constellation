# Созвездие / Constellation

**An Arch Linux desktop for the Framework Laptop 13 Pro: MangoWM and the Caelestia shell on an OpenZFS root with boot environments, a systemd without the `birthDate` field, and a Russian course from the alphabet to B2.**

The name comes from Fabergé's Constellation Egg of 1917, the last of the Imperial eggs: a globe of deep blue glass set with the stars of Leo, Tsarevich Alexei's sign. It was left unfinished when the revolution came. The boot menu wears its colours.

**Status: first version, not yet built or installed.** Every script is tested here with stubs (`tests/`), but Constellation has not yet been built with `mkarchiso` or installed on hardware. See [What's not done yet](#whats-not-done-yet).

## What it is

| | |
| --- | --- |
| Base | Arch Linux, rolling: the newest kernel graphics, Mesa and firmware for new hardware, from Arch's own repositories |
| Desktop | [MangoWM](https://github.com/mangowm/mango), a scrolling, Hyprland-style compositor, with the [Caelestia](https://github.com/caelestia-dots/shell) shell, ported to Mango by Constellation; greetd login; kitty, fish, Dolphin, Firefox ([Desktop](docs/DESKTOP.md)) |
| Storage | OpenZFS root (optionally encrypted), separate `/home`, ZFSBootMenu, a snapshot before every pacman change ([Updates](docs/UPDATES.md)) |
| Updates | `sudo constellation-be upgrade` runs `paru -Syu` in a **copy** of the system, checks it can boot, and makes it the default. The system you are using is never changed; the previous one stays one key press away in the boot menu |
| systemd | A rebuilt systemd with the `birthDate` user-record field removed, in place of Arch's, from the first install step; a daily check flags when Arch's systemd moves ahead ([systemd](docs/SYSTEMD.md)) |
| AUR | Packages Constellation needs from the AUR are pinned to reviewed commits and built into Constellation's own signed repository; nothing from the AUR is installed unreviewed ([Building](docs/BUILDING.md)) |
| Russian | The *Между нами* textbook, FSI, DLI and Peace Corps courses, a 10,000-word spaced-repetition drill, 29 audiobooks, Russian Wikisource, Wikipedia and Wiktionary, Piper voices and a local AI tutor ([Russian](docs/RUSSIAN.md)) |
| Everyday | sudo remembers your password for two hours in every terminal; zram instead of swap; the AUR ready to use through paru (which shows you every PKGBUILD before building) |

## Installing

1. Write the ISO to a USB stick and boot it in UEFI mode.
2. The live system offers to start the installer. It asks for your user name, a password and whether to encrypt (and which disk, if there is more than one), then erases that disk and installs. No internet connection is needed: every package, and the Russian voices, course books and audiobooks, are on the stick.

Rehearse first with `constellation-install --dry-run`, which shows every step and changes nothing.

See [Installing](docs/INSTALL.md) for what the installer does.

## Day to day

~~~sh
sudo constellation-be upgrade        # update in a new boot environment (paru -Syu inside it)
constellation-be list                # boot environments and snapshots
sudo constellation-be rollback pacman-20261028-091500   # boot a snapshot from before a change
constellation-russian path           # the study route from A1 to B2
constellation-russian words          # today's Russian words
sudo constellation-content           # download the tutor, voices, courses, audiobooks, dictionaries
~~~

## Building

On an Arch Linux machine (WSL2 works, with systemd enabled):

~~~sh
build/aur-pin.sh                      # review and pin the AUR packages (first time, and when they change)
build/build-repo.sh                   # build every package in a clean chroot, signed
sudo build/build-iso.sh               # build the ISO with mkarchiso (packages and content packs on it)
build/publish-repo.sh                 # publish the repository that installed systems update from
~~~

Details, including the signing key: [Building](docs/BUILDING.md).

## Layout

| Path | What |
| --- | --- |
| `pkgs/` | Constellation's packages (`PKGBUILD`s) and `aur.lock`, the reviewed AUR pins |
| `build/` | The repository, ISO, pinning, update-check and mirror scripts |
| `iso/` | Files added to the live system |
| `branding/` | Boot menu theme, fonts (Inter, OFL) and the Constellation mark |
| `tests/` | `python3 -m unittest discover -s tests` |

## What's not done yet

| | |
| --- | --- |
| First real build and install | The scripts are tested with stubs only |
| Signing key | Create one and export it to `keys/constellation.asc` ([Building](docs/BUILDING.md)) |
| ZFSBootMenu theming | ZFSBootMenu draws a text menu and cannot be themed like GRUB; the themed menu is the live USB's |
| Constellation's own content mirror | Downloads use the copies published with Kirin (`content-v1` on factionparadox/Kirin); `build/publish-content.sh` republishes them here |

## Licence

MIT, see [LICENSE](LICENSE). Packaged software keeps its own licences; the Russian word list is CC BY-SA 4.0 (`pkgs/constellation-russian/VOCAB-SOURCES.md`), Inter is OFL 1.1, and the wallpaper's rights remain with its artist.
