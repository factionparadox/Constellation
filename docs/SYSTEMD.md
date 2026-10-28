# systemd without birthDate

systemd 261 (June 2026) added an optional `birthDate` field to its JSON user records, for operating-system age checks that laws such as California's Digital Age Assurance Act ask for. systemd itself does nothing with it, but Constellation does not want the field on the machine at all.

## How

* Constellation's systemd is the AUR package `systemd-remove-birthdate` (with its split packages), pinned to a reviewed AUR commit in `pkgs/aur.lock` and built into Constellation's own signed repository by `build/build-repo.sh`.
* It `provides` and `conflicts` with Arch's systemd under a different name, so `pacman -Syu` never swaps Arch's back in.
* The installer installs it in the same `pacstrap` step as `base`, and the live ISO is built with it, so Arch's systemd is never on a Constellation machine at any point.

## Keeping it current

Arch updates systemd every few weeks, often with security fixes. `build/check-updates.sh` runs daily in GitHub Actions (`.github/workflows/check-updates.yml`) and **fails**, so GitHub emails you, when Arch's systemd is newer than Constellation's. Then:

    build/aur-pin.sh systemd-remove-birthdate          # read the diff, pin it
    build/build-repo.sh --only systemd-remove-birthdate
    build/publish-repo.sh
    sudo constellation-be upgrade                       # on the laptop

If the AUR package stops being maintained, its PKGBUILD can be copied into `pkgs/` and kept up to date here instead: it is Arch's systemd PKGBUILD plus a patch that reverts upstream PR #40954.

## Checking a machine

    pacman -Qo /usr/lib/systemd/libsystemd-shared-*.so    # owned by systemd-remove-birthdate
    grep -c birthDate /usr/lib/systemd/libsystemd-shared-*.so /usr/bin/userdbctl /usr/bin/homectl   # all 0
