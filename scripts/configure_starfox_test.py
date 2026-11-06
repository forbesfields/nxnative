#!/usr/bin/env python3
"""Update an existing Star Fox 120 Hz Test.app with a shared-data mode selector.

Build the host and rewrite main with this checkout first. Only the executables
and rewritten main are replaced; RomFS, shaders, saves and the icon stay in place.
Quit the test app before running this command. Backups contain changed files only.
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

def copy_asset(src, dst):
    # APFS shares the unchanged module pages; replace atomically without copying game data again.
    dst.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=dst.parent) as temp:
        staged = Path(temp)/dst.name
        if subprocess.run(['cp', '-c', str(src), str(staged)], capture_output=True).returncode:
            shutil.copy2(src, staged)
        staged.replace(dst)

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('app', type=Path)
    ap.add_argument('--patched', required=True, type=Path)
    ap.add_argument('--backup', required=True, type=Path)
    ap.add_argument('--host', type=Path, default=REPO/'dm/host/dmhost')
    a = ap.parse_args()
    app, backup = a.app.resolve(), a.backup.resolve()
    info = plistlib.loads((app/'Contents/Info.plist').read_bytes())
    if info.get('CFBundleIdentifier') != 'org.nxnative.starfox.120hz-test':
        ap.error('this installer only updates Star Fox 120 Hz Test.app')
    if backup.exists() or backup.is_relative_to(app):
        ap.error('backup must be a new folder outside the app')
    if subprocess.run(['pgrep', '-f', re.escape(str(app/'Contents/MacOS'))], capture_output=True).returncode == 0:
        ap.error('quit the test app before updating it')
    fixups = (a.patched/'main.fixups.tsv').read_text()
    if '# BUILD_ID\ta7730d0f74d168d90422354c8317f76f\n' not in fixups:
        ap.error('unsupported Star Fox build')
    if 'DM_STARFOX_RENDER_HZ' not in (a.patched/'main.cuts.tsv').read_text():
        ap.error('rewrite main with this checkout first; output-timing stubs are missing')
    if not a.host.is_file() or a.patched.resolve().is_relative_to(app):
        ap.error('use a built host and rewritten modules outside the app')
    mac, dm = app/'Contents/MacOS', app/'Contents/Resources/dm'
    files = [p for p in a.patched.iterdir() if p.name.startswith('main.') and p.suffix in ('.bin', '.tsv') and p.name != 'main.sites.tsv']
    with tempfile.TemporaryDirectory() as temp:
        selector = Path(temp)/'nxnative'
        run('clang', '-O2', '-fobjc-arc', '-Wall', '-Wextra', '-mmacosx-version-min=14.0',
            REPO/'dm/games/0400E88025B1A000/mac_test_launcher.m', '-framework', 'Cocoa', '-o', selector)
        core_existed = (mac/'nxnative-core').exists()
        targets = [mac/'nxnative', mac/'dmhost', app/'Contents/Info.plist', app/'Contents/_CodeSignature/CodeResources'] + [dm/p.name for p in files]
        if core_existed: targets.append(mac/'nxnative-core')
        for src in targets:
            dst = backup/src.relative_to(app); dst.parent.mkdir(parents=True, exist_ok=True)
            copy_asset(src, dst)
        try:
            if not core_existed: copy_asset(mac/'nxnative', mac/'nxnative-core')
            copy_asset(selector, mac/'nxnative'); copy_asset(a.host, mac/'dmhost')
            for src in files: copy_asset(src, dm/src.name)
            head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=REPO, text=True).strip()
            dirty = subprocess.check_output(['git', 'status', '--porcelain'], cwd=REPO, text=True).strip()
            info['DMCommit'] = head + ('+dirty' if dirty else '')
            (app/'Contents/Info.plist').write_bytes(plistlib.dumps(info, sort_keys=False))
            for target in (mac/'nxnative-core', mac/'dmhost', app): run('codesign', '--force', '--sign', '-', target)
            run('codesign', '--verify', '--deep', '--strict', '--verbose=2', app)
        except BaseException:
            for dst in targets: copy_asset(backup/dst.relative_to(app), dst)
            if not core_existed: (mac/'nxnative-core').unlink(missing_ok=True)
            raise
    print(f'Updated {app}; modes share one RomFS, shader set and save folder.')

if __name__ == '__main__':
    main()
