"""Feature 153 probe helper: the test archive, members with explicit tags.

    python arcfix153.py make <arc.zip|arc.7z> <name=tag[:timetag]> [...]
        every member holds "content-of-member-<tag>\\r\\n" (one length for tags 0-9), with the time
        2026-01-02 03:04:(6 + 2 * timetag); timetag defaults to tag, so a member written again with
        its tag is the same member (size, time, content), and "x.txt=9:1" is another content with
        the size and time of tag 1; the archive file itself always gets a new time. ZIP by Python's
        zipfile, 7z by 7z.exe (the 7-Zip folder of Program Files) from staged files
    python arcfix153.py corrupt <arc>
        the archive replaced by bytes no archiver lists (its name and size stay plausible)
    python arcfix153.py read <arc> <marker>
        one line per member: ENTRY <name> tag=<tag or ?> markers=<n>; a 7z or an unreadable archive
        prints UNREADABLE when it cannot be read
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import zipfile

SEVENZIP = os.path.join(os.environ.get('ProgramFiles', r'C:\Program Files'), '7-Zip', '7z.exe')


def members(pairs):
    for p in pairs:
        name, tag = p.split('=')
        timetag = tag
        if ':' in tag:
            tag, timetag = tag.split(':')
        yield name, tag, (2026, 1, 2, 3, 4, 6 + 2 * int(timetag))


def make(arc, pairs):
    if arc.lower().endswith('.7z'):
        stage = tempfile.mkdtemp(prefix='tc153stage_', dir=os.path.dirname(arc))
        try:
            names = []
            for name, tag, t in members(pairs):
                f = os.path.join(stage, name)
                with open(f, 'wb') as h:
                    h.write(('content-of-member-%s\r\n' % tag).encode('ascii'))
                stamp = time.mktime(t + (0, 0, -1))
                os.utime(f, (stamp, stamp))
                names.append(name)
            tmp = arc + '.new.7z'
            if os.path.exists(tmp):
                os.remove(tmp)
            r = subprocess.run([SEVENZIP, 'a', '-t7z', tmp] + names, cwd=stage, capture_output=True)
            if r.returncode != 0:
                raise SystemExit('7z a failed: %r' % r.stdout[-400:])
            os.replace(tmp, arc)
        finally:
            shutil.rmtree(stage, ignore_errors=True)
        return
    with zipfile.ZipFile(arc, 'w', zipfile.ZIP_DEFLATED) as z:
        for name, tag, t in members(pairs):
            zi = zipfile.ZipInfo(name, t)
            zi.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(zi, ('content-of-member-%s\r\n' % tag).encode('ascii'))


def corrupt(arc):
    size = max(os.path.getsize(arc), 64)
    with open(arc, 'wb') as h:
        h.write(b'not an archive - feature 153 probe\r\n' * (size // 36 + 1))


def read(arc, marker):
    if arc.lower().endswith('.7z'):
        out = tempfile.mkdtemp(prefix='tc153read_', dir=os.path.dirname(arc))
        try:
            r = subprocess.run([SEVENZIP, 'x', '-y', '-o' + out, arc], capture_output=True)
            if r.returncode != 0:
                print('UNREADABLE')
                return
            for name in sorted(os.listdir(out)):
                t = open(os.path.join(out, name), 'rb').read().decode('latin-1')
                m = re.search(r'content-of-member-(\d+)', t)
                print('ENTRY %s tag=%s markers=%d' % (name, m.group(1) if m else '?', t.count(marker)))
        finally:
            shutil.rmtree(out, ignore_errors=True)
        return
    try:
        with zipfile.ZipFile(arc) as z:
            for i in z.infolist():
                t = z.read(i).decode('latin-1')
                m = re.search(r'content-of-member-(\d+)', t)
                print('ENTRY %s tag=%s markers=%d' % (i.filename, m.group(1) if m else '?', t.count(marker)))
    except zipfile.BadZipFile:
        print('UNREADABLE')


if sys.argv[1] == 'make':
    make(sys.argv[2], sys.argv[3:])
elif sys.argv[1] == 'corrupt':
    corrupt(sys.argv[2])
else:
    read(sys.argv[2], sys.argv[3])
