#!/usr/bin/env python3
"""Install Mario Kart World's optional Mac settings selector into a packed app.

First build with scripts/build_ipa_from_nsp.py --platform mac-app. This changes
only the launcher and signature; game data, shaders, host and saves stay intact.
The resulting app uses ad-hoc signing, as the default Mac packer does.
"""
import argparse
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile

REPO = Path(__file__).resolve().parent.parent


def run(*cmd):
    subprocess.run([str(x) for x in cmd], check=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('app', type=Path)
    ap.add_argument('--backup', required=True, type=Path)
    a = ap.parse_args()
    app, backup = a.app.resolve(), a.backup.resolve()
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    if info.get('CFBundleIdentifier') != 'org.nxnative.0400c3f00006e000':
        ap.error('this installer only updates Mario Kart World.app')
    if backup.exists() or backup.is_relative_to(app):
        ap.error('backup must be a new folder outside the app')
    if subprocess.run(['pgrep', '-f', re.escape(str(app / 'Contents/MacOS'))], capture_output=True).returncode == 0:
        ap.error('quit the app before updating it')
    mac = app / 'Contents/MacOS'
    core = mac / 'nxnative-core'
    had_core = core.exists()
    targets = [mac / 'nxnative', app / 'Contents/_CodeSignature/CodeResources']
    if had_core:
        targets.append(core)
    with tempfile.TemporaryDirectory() as temp:
        selector = Path(temp) / 'nxnative'
        run('clang', '-O2', '-fobjc-arc', '-Wall', '-Wextra', '-mmacosx-version-min=14.0',
            REPO / 'dm/games/0400C3F00006E000/mac_test_launcher.m', '-framework', 'Cocoa', '-o', selector)
        for src in targets:
            dst = backup / src.relative_to(app)
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
        try:
            if not had_core:
                shutil.copy2(mac / 'nxnative', core)
            shutil.copy2(selector, mac / 'nxnative')
            run('codesign', '--force', '--sign', '-', core)
            run('codesign', '--force', '--sign', '-', app)
            run('codesign', '--verify', '--deep', '--strict', '--verbose=2', app)
        except BaseException:
            for dst in targets:
                shutil.copy2(backup / dst.relative_to(app), dst)
            if not had_core:
                core.unlink(missing_ok=True)
            raise
    print(f'Updated {app}; modes share one RomFS, shader set and save folder.')


if __name__ == '__main__':
    main()
