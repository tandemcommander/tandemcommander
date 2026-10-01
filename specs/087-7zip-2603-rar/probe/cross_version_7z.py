"""cross_version_7z.py - feature 087, T021 / SC-002: 7z archives CREATED by an
older engine (16.04, e.g. the 7za.dll of an installed 0.1.8) are read by the
new one: every variant extracts identical to the source.

    python cross_version_7z.py <old 7za.dll> <new 7za.dll>
"""
import filecmp
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
if len(sys.argv) != 3:
    print("usage: cross_version_7z.py <old 7za.dll (16.04)> <new 7za.dll (26.03)>")
    sys.exit(2)
OLD, NEW = sys.argv[1], sys.argv[2]
DRIVE = os.path.join(HERE, "obj", "7zdrive.exe")


def same(a, b):
    c = filecmp.dircmp(a, b)
    if c.left_only or c.right_only or c.diff_files or c.funny_files:
        return False
    return all(same(os.path.join(a, d), os.path.join(b, d)) for d in c.common_dirs)


work = tempfile.mkdtemp(prefix='t021_')
src = os.path.join(work, 'src')
os.makedirs(os.path.join(src, 'sub dir'))
open(os.path.join(src, 'a.txt'), 'wb').write(b'feature 087\r\n' * 5000)
open(os.path.join(src, 'sub dir', '\u010d\u00e1st \u4e2d\u6587.bin'), 'wb').write(os.urandom(200000))
open(os.path.join(src, 'empty.txt'), 'wb').close()
failed = 0
for name, args in (('plain', []), ('store', ['-mx=0']), ('nonsolid', ['-ms=off']),
                   ('encrypted', ['-pZz087pw']), ('encrypted_headers', ['-pZz087pw', '-mhe'])):
    arc = os.path.join(work, name + '.7z')
    rc1 = subprocess.run([DRIVE, 'create', OLD, arc, src] + args, capture_output=True).returncode
    out = os.path.join(work, 'out_' + name)
    pw = [a for a in args if a.startswith('-p')]
    rc2 = subprocess.run([DRIVE, 'extract', NEW, arc, out] + pw, capture_output=True).returncode
    ok = rc1 == 0 and rc2 == 0 and same(src, out)
    failed += 0 if ok else 1
    print('%s %s: created by 16.04 (rc %d), extracted by 26.03 (rc %d)' % ('PASS' if ok else 'FAIL', name, rc1, rc2))
print('failed: %d' % failed)
sys.exit(1 if failed else 0)
