# AUR overlays

Files an AUR package needs but its AUR repository is missing. `build/build-repo.sh` copies
`NAME/` over the pinned AUR checkout before building, and the PKGBUILD's own checksums
still check every file, so a wrong file stops the build.

- `systemd-remove-birthdate/systemd-hook`: listed in the PKGBUILD's `source` but not in
  the AUR repository. It is Arch's own file, from
  https://gitlab.archlinux.org/archlinux/packaging/packages/systemd (sha512 entry 9 of
  `sha512sums`: `f2f9c8de…b232b7a7`, which this copy matches). Unchanged from Arch's
  packaging at commit 3c84384 (July 2026).
