"""The login screen's wrapper: hands over to greetd after a login, falls back to tuigreet otherwise."""
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
GREETER = ROOT / 'pkgs/constellation-desktop'


class GreeterWrapper(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        base = Path(self.tmp.name)
        self.bin = base / 'bin'; self.bin.mkdir()
        self.run_dir = base / 'run'; self.run_dir.mkdir()
        self.log = base / 'log'
        (self.bin / 'mango').write_text('#!/bin/sh\necho "mango $*" >> "$STUB_LOG"\n'
                                       '[ "$STUB_LOGIN" = 1 ] && touch "$XDG_RUNTIME_DIR/constellation-greeter-done"\nexit 0\n')
        (self.bin / 'tuigreet').write_text('#!/bin/sh\necho "tuigreet $*" >> "$STUB_LOG"\n')
        for f in self.bin.iterdir():
            f.chmod(0o755)

    def wrapper(self, login):
        env = {**os.environ, 'PATH': f'{self.bin}:{os.environ["PATH"]}', 'XDG_RUNTIME_DIR': str(self.run_dir),
               'STUB_LOG': str(self.log), 'STUB_LOGIN': '1' if login else '0'}
        r = subprocess.run(['sh', str(GREETER / 'constellation-greeter')], env=env, capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        return self.log.read_text()

    def test_after_a_login_greetd_takes_over(self):
        log = self.wrapper(login=True)
        self.assertIn('mango -c /usr/share/constellation/greeter/mango.conf', log)
        self.assertNotIn('tuigreet', log)
        self.assertFalse((self.run_dir / 'constellation-greeter-done').exists())   # cleaned up for next time

    def test_without_a_login_the_text_screen_takes_over(self):
        log = self.wrapper(login=False)
        self.assertIn('tuigreet --time --remember --asterisks', log)
        self.assertIn('--cmd mango', log)


class Branding(unittest.TestCase):
    def test_the_packaged_mark_is_the_branding_mark(self):
        self.assertEqual((ROOT / 'branding/constellation-logo.png').read_bytes(),
                         (ROOT / 'pkgs/constellation-desktop/constellation-logo.png').read_bytes())

    def test_fastfetch_logo_uses_fastfetch_colour_codes(self):
        art = (ROOT / 'pkgs/constellation-desktop/fastfetch-logo.txt').read_text()
        self.assertNotIn('${c', art)
        self.assertNotRegex(art, r'(?<!\$)\$(?![1-6$])')   # every other $ is escaped as $$
        import json, re
        cfg = json.loads(re.sub(r'^//.*$', '', (ROOT / 'pkgs/constellation-desktop/fastfetch.jsonc').read_text(), flags=re.M))
        self.assertEqual(sorted(cfg['logo']['color']), ['1', '2', '3', '4', '5', '6'])


class GreeterFiles(unittest.TestCase):
    def test_mango_runs_the_greeter_and_quits_with_it(self):
        conf = (GREETER / 'greeter-mango.conf').read_text()
        self.assertIn('exec_once=qs -p /usr/share/constellation/greeter/shell.qml; mmsg dispatch quit', conf)
        self.assertNotRegex(conf, r'(?m)^bind')                # nothing to escape to

    def test_greetd_runs_the_wrapper(self):
        toml = (ROOT / 'pkgs/constellation-desktop/greetd.toml').read_text()
        self.assertIn('command = "/usr/lib/constellation/greeter"', toml)

    def test_qml_braces_balance_and_marker_matches(self):
        for path in (GREETER / 'shell.qml', GREETER / 'Greeter.qml', GREETER / 'Sky.qml', ROOT / 'pkgs/caelestia-mango/Hypr.qml', ROOT / 'pkgs/caelestia-mango/CustomShortcut.qml'):
            name = path.name; text = path.read_text()
            code = re.sub(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|//[^\n]*', '', text)
            for a, b in ('{}', '()', '[]'):
                self.assertEqual(code.count(a), code.count(b), f'{name}: {a}{b}')
        self.assertIn('constellation-greeter-done', (GREETER / 'shell.qml').read_text())
        self.assertIn('constellation-greeter-done', (GREETER / 'constellation-greeter').read_text())


if __name__ == '__main__':
    unittest.main()
