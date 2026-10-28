"""constellation-be against stub zfs, zpool, mount and arch-chroot that keep a fake pool's state."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

TOOL = Path(__file__).resolve().parents[1] / 'pkgs/constellation-base/constellation-be'

STUB = r'''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
state_file = Path(os.environ['STUB_STATE'])
st = json.loads(state_file.read_text())
name, args = Path(sys.argv[0]).name, sys.argv[1:]
log = Path(os.environ['STUB_LOG']); log.open('a').write(name + ' ' + ' '.join(args) + '\n')
def save(): state_file.write_text(json.dumps(st))
if name == 'id':
    print(0)
elif name == 'findmnt':
    print('zfs' if 'FSTYPE' in args else st['running'])
elif name == 'zpool':
    if args[0] == 'get': print(st['bootfs'])
    elif args[0] == 'set': st['bootfs'] = args[1].split('=', 1)[1]; save()
elif name == 'zfs':
    cmd = args[0]
    if cmd == 'list':
        target = args[-1]
        if '-t' in args and 'snapshot' in args:
            for s in st['snapshots']:
                if s.startswith(target + '@'): print(f'{s}\t1M\tnow')
        elif '-d' in args:
            print(f'{target}\t-\tnow')
            for d in st['datasets']: print(f'{d}\t1G\tnow')
        else:
            sys.exit(0 if target in st['datasets'] or target in st['snapshots'] else 1)
    elif cmd == 'snapshot':
        st['snapshots'].append(args[-1]); save()
    elif cmd == 'clone':
        st['datasets'].append(args[-1]); st.setdefault('origins', {})[args[-1]] = args[-2]; save()
    elif cmd == 'destroy':
        st['datasets'].remove(args[-1]); save()
elif name == 'mount':
    if '-t' in args and 'zfs' in args:          # mount -t zfs -o zfsutil DATASET DIR: a fake system
        root = Path(args[-1])
        (root / 'boot').mkdir(parents=True, exist_ok=True)
        (root / 'boot/vmlinuz-linux-lts').write_text('k')
        if os.environ.get('STUB_NO_INITRAMFS') != '1':
            (root / 'boot/initramfs-linux-lts.img').write_text('i')
        mods = root / 'usr/lib/modules/6.18.9-1-lts'
        mods.mkdir(parents=True, exist_ok=True)
        (mods / 'pkgbase').write_text('linux-lts\n')
        if os.environ.get('STUB_NO_ZFS_MODULE') != '1':
            (mods / 'updates/dkms').mkdir(parents=True, exist_ok=True)
            (mods / 'updates/dkms/zfs.ko.zst').write_text('m')
elif name == 'arch-chroot':
    sys.exit(int(os.environ.get('STUB_PARU_RC', '0')))
'''


class BootEnvironmentTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        base = Path(self.tmp.name)
        self.bin = base / 'bin'; self.bin.mkdir()
        for name in ('id', 'findmnt', 'zpool', 'zfs', 'mount', 'umount', 'arch-chroot'):
            (self.bin / name).write_text(STUB if name != 'umount' else '#!/bin/sh\nexit 0\n')
            (self.bin / name).chmod(0o755)
        self.state = base / 'state.json'
        self.state.write_text(json.dumps({'running': 'zroot/ROOT/constellation', 'bootfs': 'zroot/ROOT/constellation',
                                          'datasets': ['zroot/ROOT/constellation'],
                                          'snapshots': ['zroot/ROOT/constellation@installed']}))
        self.log = base / 'log'
        self.env = {**os.environ, 'PATH': f'{self.bin}:{os.environ["PATH"]}', 'STUB_STATE': str(self.state),
                    'STUB_LOG': str(self.log), 'SUDO_USER': 'stephen', 'CONSTELLATION_BE_WORK': str(base / 'work')}

    def be(self, *args, **env):
        return subprocess.run(['bash', str(TOOL), *args], capture_output=True, text=True,
                              env={**self.env, **env})

    def st(self):
        return json.loads(self.state.read_text())

    def test_upgrade_updates_a_clone_and_activates_it(self):
        r = self.be('upgrade')
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        st = self.st()
        new = [d for d in st['datasets'] if '/upgrade-' in d]
        self.assertEqual(len(new), 1)
        self.assertEqual(st['bootfs'], new[0])
        self.assertTrue(st['origins'][new[0]].startswith('zroot/ROOT/constellation@before-upgrade-'))
        log = self.log.read_text()
        self.assertIn('arch-chroot', log)
        self.assertIn('runuser -u stephen -- paru -Syu', log)
        self.assertIn('kernel, initramfs and ZFS module present', r.stdout)
        self.assertIn('choose constellation in the ZFSBootMenu menu', r.stdout)

    def test_failed_update_leaves_the_running_system_default(self):
        r = self.be('upgrade', STUB_PARU_RC='1')
        self.assertEqual(r.returncode, 1)
        self.assertEqual(self.st()['bootfs'], 'zroot/ROOT/constellation')
        self.assertIn('Nothing changed in your running system', r.stdout)

    def test_kernel_without_zfs_module_is_not_activated(self):
        r = self.be('upgrade', STUB_NO_ZFS_MODULE='1')
        self.assertEqual(r.returncode, 1)
        self.assertEqual(self.st()['bootfs'], 'zroot/ROOT/constellation')
        self.assertIn('no ZFS module for the linux-lts kernel', r.stdout)
        r = self.be('upgrade', STUB_NO_INITRAMFS='1')
        self.assertIn('missing initramfs for linux-lts', r.stdout)

    def test_upgrade_needs_a_real_user(self):
        r = self.be('upgrade', SUDO_USER='')
        self.assertNotEqual(r.returncode, 0)
        self.assertIn('paru must not run as root', r.stderr)

    def test_no_activate_keeps_the_default(self):
        r = self.be('upgrade', '--no-activate')
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(self.st()['bootfs'], 'zroot/ROOT/constellation')
        self.assertIn('Try it once from the ZFSBootMenu menu', r.stdout)

    def test_rollback_makes_a_new_environment(self):
        r = self.be('rollback', 'installed')
        self.assertEqual(r.returncode, 0, r.stderr)
        st = self.st()
        self.assertTrue(st['bootfs'].startswith('zroot/ROOT/rollback-'))
        self.assertIn('zroot/ROOT/constellation', st['datasets'])          # the old one stays

    def test_destroy_refuses_running_and_default(self):
        self.assertIn('the running system', self.be('destroy', 'constellation').stderr)
        self.be('create', 'test')
        self.be('activate', 'test')
        self.assertIn('is the default', self.be('destroy', 'test').stderr)
        self.be('activate', 'constellation')
        self.assertEqual(self.be('destroy', 'test').returncode, 0)
        self.assertNotIn('zroot/ROOT/test', self.st()['datasets'])

    def test_list_marks_running_and_default(self):
        out = self.be('list').stdout
        self.assertRegex(out, r'constellation .*\[running default\]')
        self.assertIn('installed', out)


if __name__ == '__main__':
    unittest.main()
