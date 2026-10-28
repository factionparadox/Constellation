"""constellation-content against a fake installed system, a stub Ollama and a local web server."""
import functools
import hashlib
import http.server
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading
import unittest

PKG = Path(__file__).resolve().parents[1] / 'pkgs/constellation-russian'
TOOL = PKG / 'constellation-content'


def stage(root: Path) -> None:
    """Lay the package out as its PKGBUILD's package() does."""
    lib, share = root / 'usr/lib/constellation/content', root / 'usr/share/constellation/russian'
    lib.mkdir(parents=True); share.mkdir(parents=True)
    for f in PKG.glob('fetch-*.py'):
        shutil.copy(f, lib)
    shutil.copy(PKG / 'mirror.json', lib)
    for f in ('vocab.tsv', 'library.tsv', 'audiobooks.tsv', 'voices.tsv'):
        shutil.copy(PKG / f, share)
    (root / 'var/lib/constellation/russian').mkdir(parents=True)


class ContentTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        base = Path(self.temp.name)
        self.root = base / 'root'
        stage(self.root)
        self.data = self.root / 'var/lib/constellation/russian'
        (self.data / 'russian.json').write_text(json.dumps({'model': 'tutor'}))
        self.site = base / 'site'; self.site.mkdir()
        handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(self.site))
        handler.log_message = lambda *a: None
        httpd = http.server.ThreadingHTTPServer(('127.0.0.1', 0), handler)
        threading.Thread(target=httpd.serve_forever, daemon=True).start()
        self.addCleanup(httpd.server_close); self.addCleanup(httpd.shutdown)
        self.url = f'http://127.0.0.1:{httpd.server_port}'
        # Stub Ollama: remembers pulled tags in a file.
        self.ollama = base / 'ollama'
        self.ollama.write_text('#!/bin/sh\nS="$(dirname "$0")/pulled"\ncase "$1" in\n'
                               '  list) echo "NAME ID SIZE"; [ -f "$S" ] && sed "s/$/ x 1GB/" "$S" ;;\n'
                               '  pull) echo "$2" >> "$S" ;;\n  rm) grep -vx "$2" "$S" > "$S.n"; mv "$S.n" "$S" ;;\nesac\n')
        self.ollama.chmod(0o755)

    def publish_zim(self, directory, name, data=b'zim'):
        d = self.site / 'zim' / directory; d.mkdir(parents=True, exist_ok=True)
        (d / name).write_bytes(data)
        (d / f'{name}.sha256').write_text(f'{hashlib.sha256(data).hexdigest()}  {name}\n')
        listing = d / 'index.html'
        listing.write_text((listing.read_text() if listing.exists() else '') + f'<a href="{name}">{name}</a>\n')

    def run_tool(self, *args, input=''):
        env = {**os.environ, 'CONSTELLATION_CONTENT_ROOT': str(self.root),
               'CONSTELLATION_CONTENT_OLLAMA': str(self.ollama),
               'CONSTELLATION_CONTENT_KIWIX': self.url + '/zim', 'CONSTELLATION_CONTENT_ARCHIVE': self.url + '/archive/',
               'CONSTELLATION_CONTENT_MEZHDUNAMI': self.url + '/mn/index.shtml',
               'CONSTELLATION_CONTENT_YTDLP': 'no-such-ytdlp',
               'CONSTELLATION_CONTENT_MIRROR': self.url + '/no-mirror/'}
        return subprocess.run([sys_python(), str(TOOL), *args], capture_output=True, text=True, env=env, input=input)

    def config(self):
        return json.loads((self.data / 'russian.json').read_text())

    def test_tutor_model_goes_through_ollama(self):
        r = self.run_tool('install', 'ai-tutor')
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn('qwen3:30b-a3b-instruct-2507-q4_K_M', (self.ollama.parent / 'pulled').read_text())
        self.assertRegex(self.run_tool('list').stdout, r'ai-tutor\s+installed')
        self.run_tool('remove', 'ai-tutor')
        self.assertNotIn('qwen3', (self.ollama.parent / 'pulled').read_text())

    def test_dictionaries_are_verified_and_configured(self):
        self.publish_zim('wiktionary', 'wiktionary_en_all_nopic_2026-09.zim')
        self.publish_zim('wiktionary', 'wiktionary_ru_all_nopic_2026-08.zim')
        r = self.run_tool('install', 'ru-dictionaries')
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        cfg = self.config()
        self.assertEqual(cfg['kiwix']['wiktionary'],
                         '/var/lib/constellation/russian/dictionary/wiktionary_en_all_nopic_2026-09.zim')
        self.assertEqual(cfg['kiwix']['wiktionary-ru'],
                         '/var/lib/constellation/russian/dictionary/wiktionary_ru_all_nopic_2026-08.zim')
        self.assertEqual(cfg['model'], 'tutor')                        # existing settings kept
        self.assertRegex(self.run_tool('list').stdout, r'ru-dictionaries\s+installed')
        self.run_tool('remove', 'ru-dictionaries')
        self.assertEqual(self.config()['kiwix'], {})

    def test_tampered_zim_refused(self):
        self.publish_zim('wikisource', 'wikisource_ru_all_nopic_2019-08.zim')
        self.publish_zim('wikipedia', 'wikipedia_ru_all_mini_2026-10.zim')
        (self.site / 'zim/wikipedia/wikipedia_ru_all_mini_2026-10.zim').write_bytes(b'tampered')
        r = self.run_tool('install', 'ru-reading')
        self.assertEqual(r.returncode, 1)
        self.assertIn('FAILED', r.stdout)
        self.assertNotIn('wikipedia', self.config()['kiwix'])
        self.assertIn('wikisource', self.config()['kiwix'])

    def test_interactive_choice_and_unknown_pack(self):
        r = self.run_tool(input='2\n')
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn('qwen3', (self.ollama.parent / 'pulled').read_text())
        self.assertEqual(self.run_tool('install', 'nonsense').returncode, 2)

    def test_packaged_files_exist(self):
        pkgbuild = (PKG / 'PKGBUILD').read_text()
        for name in ('fetch-files.py', 'fetch-kiwix.py', 'fetch-archive.py', 'fetch-mezhdunami.py', 'fetch-mirror.py',
                     'library.tsv', 'audiobooks.tsv', 'voices.tsv', 'vocab.tsv', 'mirror.json'):
            self.assertTrue((PKG / name).is_file(), name)
            self.assertIn(f"'{name}'", pkgbuild, name)


def sys_python():
    import sys
    return sys.executable


if __name__ == '__main__':
    unittest.main()
