"""Static checks on the PKGBUILDs and the AUR lock: sources exist, checksums line up, names agree."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
PKGS = ROOT / 'pkgs'


def array(text, name):
    m = re.search(rf'^{name}=\((.*?)\)', text, re.S | re.M)
    if not m:
        return []
    body = re.sub(r'(^|\s)#[^\n]*', ' ', m.group(1), flags=re.M)   # comments, not URL fragments
    return [a or b for a, b in re.findall(r"'([^']*)'|\"([^\"]*)\"", body)]


class PackageTests(unittest.TestCase):
    def test_build_scripts_have_no_early_exit_pipelines(self):
        # Under set -o pipefail, 'producer | grep -q/-m1' or '| head' fails the whole pipeline
        # when the reader stops early (the producer gets SIGPIPE), even on a match.
        import re
        for script in (ROOT / 'build').glob('*.sh'):
            for n, line in enumerate(script.read_text().splitlines(), 1):
                code = line.split('#', 1)[0] if not line.lstrip().startswith('#') else ''
                self.assertIsNone(re.search(r'\|\s*(grep\s+-[a-zA-Z]*[qm]|head\b)', code),
                                  f'{script.name}:{n}: {line.strip()}')

    def test_build_scripts_are_executable(self):
        import os
        for script in (ROOT / 'build').glob('*.sh'):
            self.assertTrue(os.access(script, os.X_OK), f'{script.name} is not executable')

    def test_sources_exist_and_sums_line_up(self):
        for pkgbuild in PKGS.glob('*/PKGBUILD'):
            text = pkgbuild.read_text()
            sources, sums = array(text, 'source'), array(text, 'sha256sums')
            self.assertEqual(len(sources), len(sums), pkgbuild)
            for s in sources:
                if '://' in s or '::' in s or s.startswith('git+'):
                    continue
                # makepkg looks for local sources by file name in the PKGBUILD's own folder.
                self.assertNotIn('/', s, f'{pkgbuild.parent.name}: {s} must be in the package folder itself')
                self.assertTrue((pkgbuild.parent / s).is_file(), f'{pkgbuild.parent.name}: {s}')
            pkgname = re.search(r'^pkgname=(\S+)', text, re.M).group(1)
            self.assertEqual(pkgname, pkgbuild.parent.name)
            self.assertRegex(text, r"license=\(")

    def test_downloads_are_pinned(self):
        for pkgbuild in PKGS.glob('*/PKGBUILD'):
            text = pkgbuild.read_text()
            for s, h in zip(array(text, 'source'), array(text, 'sha256sums')):
                if 'git+' in s:
                    self.assertIn('#commit=', s, pkgbuild)            # a commit, never a branch
                elif '://' in s and 'LICENSE' not in s:
                    self.assertRegex(h, r'^[0-9a-f]{64}$', f'{pkgbuild.parent.name}: {s}')

    def test_build_order_covers_every_package(self):
        build = (ROOT / 'build/build-repo.sh').read_text()
        own = re.search(r'^OWN=\((.*?)\)', build, re.M).group(1).split()
        own += re.search(r'^FIRST=\((.*?)\)', build, re.M).group(1).split()
        self.assertEqual(sorted(own), sorted(p.parent.name for p in PKGS.glob('*/PKGBUILD')))

    def test_dependencies_come_from_the_lock_or_constellation(self):
        aur = [l.split()[0] for l in (PKGS / 'aur.lock').read_text().splitlines() if l.strip() and not l.startswith('#')]
        self.assertIn('systemd-remove-birthdate', aur)
        own = {p.parent.name for p in PKGS.glob('*/PKGBUILD')}
        base = (PKGS / 'constellation-base/PKGBUILD').read_text()
        self.assertIn("'systemd-remove-birthdate'", base)
        shell = (PKGS / 'niri-caelestia-shell/PKGBUILD').read_text()
        for dep in ('quickshell-git', 'caelestia-cli', 'libcava', 'app2unit'):
            self.assertIn(f"'{dep}'", shell)
            self.assertIn(dep, aur, dep)
        self.assertTrue(own >= {'zfsbootmenu-efi', 'niri-caelestia-shell', 'ttf-material-symbols-rounded'})
        self.assertIn("'ttf-material-symbols-rounded'", shell)

    def test_reviewed_pins_are_full_commits(self):
        for line in (PKGS / 'aur.lock').read_text().splitlines():
            if line.strip() and not line.startswith('#'):
                name, commit, *src = line.split()
                self.assertRegex(commit, r'^([0-9a-f]{40}|UNPINNED)$', name)
                if name.endswith('-git'):
                    self.assertRegex(src[0], r'^src=([0-9a-f]{40}|UNPINNED)$', name)

    def test_installer_lists_the_desktop_and_russian(self):
        listed = [l.strip() for l in (PKGS / 'constellation-installer/packages.txt').read_text().splitlines()
                  if l.strip() and not l.startswith('#')]
        for p in ('base', 'linux', 'zfs-dkms', 'constellation-base', 'constellation-desktop', 'constellation-russian'):
            self.assertIn(p, listed)
        self.assertNotIn('systemd', listed)


if __name__ == '__main__':
    unittest.main()
