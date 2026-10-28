"""constellation-install --dry-run: the exact commands it would run, for both encryption choices."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

PKG = Path(__file__).resolve().parents[1] / 'pkgs/constellation-installer'


class InstallerDryRun(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        base = Path(self.tmp.name)
        self.share = base / 'share'; self.share.mkdir()
        (self.share / 'packages.txt').write_text((PKG / 'packages.txt').read_text())
        (self.share / 'systemd-packages.txt').write_text('systemd-remove-birthdate\nsystemd-remove-birthdate-libs\n'
                                                       'systemd-remove-birthdate-sysvcompat\n')
        self.pw = base / 'pw'; self.pw.write_text('secret\n')
        self.key = base / 'key'; self.key.write_text('correct horse battery\n')

    def install(self, *extra, env=None):
        r = subprocess.run(['bash', str(PKG / 'constellation-install'), '--dry-run', '--yes', '--disk', '/dev/nvme0n1',
                            '--username', 'stephen', '--fullname', 'Stephen', '--password-file', str(self.pw), *extra],
                           capture_output=True, text=True, input='',
                           env={**os.environ, 'CONSTELLATION_INSTALL_SHARE': str(self.share), **(env or {})})
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        return r.stdout

    def test_unencrypted_layout_and_packages(self):
        out = self.install('--no-encrypt')
        self.assertIn('+ sgdisk -n 1:1m:+1g -t 1:ef00 -c 1:EFI /dev/nvme0n1', out)
        self.assertIn('+ mkfs.fat -F 32 -n CONSTELLATN /dev/nvme0n1p1', out)
        self.assertIn('compatibility=openzfs-2.3-linux', out)
        self.assertNotIn('encryption=', out)
        for ds in ('zroot/ROOT/constellation', 'zroot/home', 'zroot/data/constellation', 'zroot/data/ollama'):
            self.assertIn(ds, out)
        pacstrap = next(l for l in out.splitlines() if l.startswith('+ pacstrap'))
        self.assertNotIn(' -K', pacstrap)                     # the live keyring (with Constellation's key) is copied
        for pkg in ('base', 'linux-lts', 'zfs-dkms', 'constellation-desktop', 'constellation-russian',
                    'systemd-remove-birthdate', 'systemd-remove-birthdate-libs'):
            self.assertIn(f' {pkg}', pacstrap)
        self.assertIn('HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block zfs filesystems)', out)
        self.assertIn('LANG=en_GB.UTF-8', out)
        self.assertIn('KEYMAP=uk', out)
        self.assertIn('useradd -m -G wheel -s /usr/bin/fish -c Stephen stephen', out)
        self.assertIn('zfs set org.zfsbootmenu:commandline=rw quiet loglevel=3 zroot/ROOT', out)
        self.assertIn("efibootmgr -c -d /dev/nvme0n1 -p 1 -L Constellation (ZFSBootMenu)", out)
        self.assertIn('zfs snapshot zroot/ROOT/constellation@installed', out)

    def test_installs_from_the_usb_stick_only(self):
        out = self.install('--no-encrypt')
        pacstrap = next(l for l in out.splitlines() if l.startswith('+ pacstrap'))
        self.assertIn(f'-C {self.share}/pacman-live.conf', pacstrap)
        self.assertIn(' base-devel', pacstrap)                   # for paru
        self.assertIn('no network needed', out)

    def test_content_packs_on_the_stick_are_copied(self):
        content = Path(self.tmp.name) / 'content'
        (content / 'ru-voices').mkdir(parents=True)
        out = self.install('--no-encrypt', env={'CONSTELLATION_INSTALL_CONTENT': str(content)})
        self.assertIn(f'+ cp -a {content}/ru-voices /mnt/constellation/var/lib/constellation/russian/voices', out)
        self.assertIn('constellation-content refresh', out)
        self.assertNotIn('ru-audiobooks', out)
        out = self.install('--no-encrypt', env={'CONSTELLATION_INSTALL_CONTENT': str(content / 'none')})
        self.assertNotIn('constellation-content refresh', out)

    def test_encrypted_install_keeps_the_key_in_the_initramfs_only(self):
        out = self.install('--encrypt-passphrase-file', str(self.key))
        self.assertIn('encryption=aes-256-gcm', out)
        self.assertIn('keylocation=file:///etc/zfs/zroot.key', out)
        self.assertIn('FILES=(/etc/zfs/zroot.key)', out)
        self.assertIn('org.zfsbootmenu:keysource=zroot/ROOT/constellation', out)
        self.assertIn('chmod 600', out)
        self.assertNotIn('correct horse', out)                 # the passphrase is never printed

    def test_live_disk_and_bad_names_refused(self):
        r = subprocess.run(['bash', str(PKG / 'constellation-install'), '--dry-run', '--yes', '--disk', '/dev/sda',
                            '--username', 'root', '--password-file', str(self.pw), '--no-encrypt'],
                           capture_output=True, text=True, input='',
                           env={**os.environ, 'CONSTELLATION_INSTALL_SHARE': str(self.share)})
        self.assertNotEqual(r.returncode, 0)                   # root is not a valid first user


if __name__ == '__main__':
    unittest.main()
