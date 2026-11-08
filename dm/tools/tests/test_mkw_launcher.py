"""Run the real Mario Kart selector against a recording core, without game data or UI."""
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[3]
CORE = r'''#include <stdio.h>
#include <stdlib.h>
int main(int argc, char **argv) {
    const char *keys[] = {"DM_PRESENT_HZ", "DM_PRESENT_LINK", "DM_PRESENT_VSYNC",
        "DM_PRESENT_INTERVAL", "DM_VI_BUFFER_MAX", "DM_OPMODE", "DM_LAUNCHER",
        "DM_SAVED_CHOICES", "DM_METAL_HUD", "MTL_HUD_ENABLED", "MTL_HUD_ELEMENTS"};
    for (unsigned i = 0; i < sizeof(keys) / sizeof(keys[0]); i++) {
        const char *value = getenv(keys[i]);
        printf("%s=%s\n", keys[i], value ? value : "<unset>");
    }
    printf("argc=%d\nargument=%s\n", argc, argc > 1 ? argv[1] : "");
    return 7;
}
'''


@unittest.skipUnless(sys.platform == 'darwin' and shutil.which('clang'), 'Mac selector needs Cocoa and clang')
class MarioKartLauncher(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix='mkw-launcher-')
        root = Path(cls.temp.name)
        contents = root / 'Selector Test.app/Contents'
        mac = contents / 'MacOS'
        mac.mkdir(parents=True)
        (contents / 'Info.plist').write_bytes(plistlib.dumps({
            'CFBundleExecutable': 'nxnative', 'CFBundleIdentifier': 'org.nxnative.test.mkw-selector',
            'CFBundlePackageType': 'APPL',
        }))
        cls.launcher = mac / 'nxnative'
        subprocess.run(['clang', '-O2', '-fobjc-arc', '-Wall', '-Wextra', '-Werror',
                        REPO / 'dm/games/0400C3F00006E000/mac_test_launcher.m',
                        '-framework', 'Cocoa', '-o', cls.launcher], check=True, capture_output=True)
        source = root / 'core.c'
        source.write_text(CORE)
        subprocess.run(['clang', '-Wall', '-Wextra', '-Werror', source, '-o', mac / 'nxnative-core'],
                       check=True, capture_output=True)

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def test_all_eighteen_handoffs_override_inherited_pacing_and_hud(self):
        env = dict(os.environ, DM_PRESENT_HZ='30', DM_PRESENT_LINK='1', DM_PRESENT_VSYNC='1',
                   DM_METAL_HUD='1', MTL_HUD_ENABLED='1', MTL_HUD_ELEMENTS='wrong')
        for resolution, vi, opmode in (('1080p', '1', '0'), ('4k', '3', '1')):
            for rate, hz, vsync in (('60', '60', '1'), ('120', '120', '0'), ('uncapped', '0', '0')):
                for display, enabled in (('off', '0'), ('fps', '1'), ('full', '1')):
                    with self.subTest(resolution=resolution, rate=rate, display=display):
                        result = subprocess.run([self.launcher, '--mode', f'{resolution}-{rate}',
                                                 '--debug-display', display], env=env, capture_output=True, text=True)
                        self.assertEqual(result.returncode, 7, result.stderr)
                        values = dict(line.split('=', 1) for line in result.stdout.splitlines())
                        self.assertEqual({k: values[k] for k in (
                            'DM_PRESENT_HZ', 'DM_PRESENT_LINK', 'DM_PRESENT_VSYNC', 'DM_PRESENT_INTERVAL',
                            'DM_VI_BUFFER_MAX', 'DM_OPMODE', 'DM_LAUNCHER', 'DM_SAVED_CHOICES',
                            'DM_METAL_HUD', 'MTL_HUD_ENABLED', 'argc', 'argument')}, {
                            'DM_PRESENT_HZ': hz, 'DM_PRESENT_LINK': '0', 'DM_PRESENT_VSYNC': vsync,
                            'DM_PRESENT_INTERVAL': 'game', 'DM_VI_BUFFER_MAX': vi, 'DM_OPMODE': opmode,
                            'DM_LAUNCHER': '0', 'DM_SAVED_CHOICES': '0', 'DM_METAL_HUD': enabled,
                            'MTL_HUD_ENABLED': enabled, 'argc': '2', 'argument': '--no-launcher',
                        })
                        if display == 'fps':
                            self.assertEqual(values['MTL_HUD_ELEMENTS'], 'fps')
                        elif display == 'full':
                            self.assertIn('gputime', values['MTL_HUD_ELEMENTS'].split(','))
                            self.assertIn('frameintervalgraph', values['MTL_HUD_ELEMENTS'].split(','))

    def test_invalid_options_do_not_start_core(self):
        for args in (('--mode', '4k-240'), ('--mode', '4k'), ('--mode',),
                     ('--debug-display', 'invalid'), ('--debug-display',), ('--unknown',)):
            with self.subTest(args=args):
                result = subprocess.run([self.launcher, *args], capture_output=True, text=True)
                self.assertEqual(result.returncode, 2)
                self.assertEqual(result.stdout, '')


if __name__ == '__main__':
    unittest.main()
