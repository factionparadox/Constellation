# Building Constellation

Everything is built on an Arch Linux machine: Arch itself, or Arch on WSL2 with systemd enabled (`[boot] systemd=true` in `/etc/wsl.conf`; devtools' build chroots use systemd-nspawn). About 30 GB free.

    sudo pacman -S --needed base-devel devtools archiso grub git github-cli

## 1. A signing key (once)

Installed systems only accept Constellation's packages signed by this key.

    gpg --quick-generate-key 'Constellation packages <you@example.org>' ed25519 sign never
    gpg --list-secret-keys --keyid-format long          # note the key's ID
    gpg --armor --export KEYID > keys/constellation.asc
    git add keys/constellation.asc                        # the public key only
    export CONSTELLATION_GPGKEY=KEYID                     # add to ~/.bashrc or fish config

Keep the secret key safe (and backed up): anyone with it can push packages to every Constellation machine. `build/build-repo.sh --unsigned` builds without it, for a local test ISO only.

## 2. Review and pin the AUR packages

    build/aur-pin.sh                  # each package: pinned, behind, or unpinned
    build/aur-pin.sh NAME             # read its files (or the diff since the last pin), then pin it

`pkgs/aur.lock` lists the AUR packages Constellation builds, in build order, each pinned to an AUR git commit you have read. `build/aur-pin.sh --deps NAME` lists a package's own AUR dependencies, which need adding above it. The first time, `systemd-remove-birthdate` deserves the most care: it becomes PID 1 on every Constellation machine.

## 3. Build the repository

    build/build-repo.sh               # everything (already-built versions are skipped)
    build/build-repo.sh --only NAME   # one package

AUR packages and anything that compiles are built in a clean chroot (`work/chroot`), never on this machine's own system, so building the birthDate-free systemd does not touch your systemd. Packages built earlier in a run are available to later ones. The result is `out/repo`: signed packages, the `constellation` database, and `systemd-packages.txt` (the systemd family the installer and ISO use).

## 4. Build the ISO

    sudo build/build-iso.sh

Starts from archiso's own `releng` profile and adds the LTS kernel with OpenZFS, the birthDate-free systemd, the repository (copied onto the ISO), the installer, the signing key (trusted by the live system's keyring at boot) and the GRUB theme. Output: `out/constellation-YYYY.MM.DD-x86_64.iso` and its `.sha256`.

## 5. Publish the repository

    build/publish-repo.sh

Uploads `out/repo` as the assets of the `repo` release on GitHub, which is where installed systems' pacman finds Constellation's packages. Do this before installing, and after every rebuild.

## Keeping up

`build/check-updates.sh` (run daily by GitHub Actions) reports AUR packages with new commits to review and fails when Arch's systemd is ahead of Constellation's. Updating a package is: `build/aur-pin.sh NAME`, `build/build-repo.sh --only NAME`, `build/publish-repo.sh`, then `sudo constellation-be upgrade` on the laptop.

Constellation's own packages: bump `pkgver` or `pkgrel` in `pkgs/NAME/PKGBUILD` when you change them, so installed systems see the update. The Caelestia shell is pinned to a commit of its niri port: update `_commit` and `pkgver` together after reading what changed.

## Tests

    python3 -m unittest discover -s tests

They run the scripts against stubs: boot environments (`constellation-be` with a fake pool), the installer (`--dry-run`), the Russian tools, the downloaders and the content mirror. They do not replace a real build and install.
