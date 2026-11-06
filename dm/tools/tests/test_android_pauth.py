"""The Android rewriter lowers guest pointer-auth instructions for Armv8 phones."""
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_cheat_anchor import nso
TOOLS = Path(__file__).resolve().parents[1]

class AndroidPauth(unittest.TestCase):
    def rewrite(self, words, target):
        with tempfile.TemporaryDirectory() as tmp:
            src = Path(tmp) / 'input.nso'
            nso(src, {0x100: words})
            r = subprocess.run([sys.executable, str(TOOLS/'patch_nso.py'), str(src), tmp, 'unit', '--target', target],
                               env=os.environ | {'DM_GAME':'010015100B514000', 'DM_REWRITE_J':'1'}, capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stdout+r.stderr)
            return (Path(tmp)/'unit.patched.bin').read_bytes(), (Path(tmp)/'unit.gates.tsv').read_text()

    def test_android_returns_and_context_mac(self):
        words = [0xd503237f, 0xdac107fe, 0xdac117fe, 0xdac10130, 0xdac143fa, 0x9ac233c2, 0xd65f0fff]
        data, gates = self.rewrite(words, 'android')
        got = struct.unpack_from('<7I', data, 0x100)
        self.assertEqual(got[:5], (0xd503201f,)*5)
        self.assertEqual(got[-1], 0xd65f03c0)
        self.assertEqual(got[5] & 0xfc000000, 0x14000000)  # branch to a saved-register host gate
        self.assertIn('\tpacga\t', gates)

    def test_apple_keeps_hardware_authentication(self):
        words = [0xd503237f, 0x9ac233c2, 0xd65f0fff]
        data, gates = self.rewrite(words, 'apple')
        self.assertEqual(struct.unpack_from('<3I', data, 0x100), tuple(words))
        self.assertNotIn('\tpacga\t', gates)
