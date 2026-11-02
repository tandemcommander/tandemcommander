# Probe fixture of the backlog item tar-member-name-with-dotdot-extracted-into-wrong-folder:
# writes one tar per probe row with Python's tarfile (member names with a ".." component).
# Usage: python -I mkdotdot.py <ROW> <out>. Pure ASCII.
import io
import sys
import tarfile


def add(tf, name, data):
    ti = tarfile.TarInfo(name)
    ti.size = len(data)
    ti.mtime = 1000000000
    ti.mode = 0o644
    tf.addfile(ti, io.BytesIO(data))


def link(tf, name, target):
    ti = tarfile.TarInfo(name)
    ti.type = tarfile.LNKTYPE
    ti.linkname = target
    ti.mtime = 1000000000
    ti.mode = 0o644
    tf.addfile(ti)


def main():
    row, out = sys.argv[1], sys.argv[2]
    fmt = tarfile.USTAR_FORMAT
    if row.startswith('UNP-GNU'):
        fmt = tarfile.GNU_FORMAT
    elif row.startswith('UNP-PAX'):
        fmt = tarfile.PAX_FORMAT

    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode='w', format=fmt) as tf:
        if row.startswith('UNP-ROOT') or row.startswith('COPY-ROOT'):
            add(tf, 'sub/c.txt', b'C')
            add(tf, 'sub/../a.txt', b'A')            # legacy rule: s\a.txt
            add(tf, 'x/y/../b.txt', b'B')            # legacy rule already right: x\b.txt
            add(tf, '../../e.txt', b'E')             # the AIX case: never above the root
            add(tf, 'q/../../f.txt', b'F')           # climbs above the root: f.txt
        elif row.startswith('UNP-OVER'):
            add(tf, 's/a.txt', b'S')                 # an unrelated member where the legacy rule points
            add(tf, 'sub/../a.txt', b'A')            # legacy rule: s\a.txt (the overwrite question)
        elif row.startswith('UNP-GNU') or row.startswith('UNP-PAX'):
            add(tf, 'sub/../' + 'g' * 120 + '.txt', b'G')   # a long name (GNU 'L' / PAX path)
        elif row.startswith('UNP-LINK'):
            add(tf, 'a.txt', b'A')
            add(tf, 's/a.txt', b'S')
            link(tf, 'b.txt', 'sub/../a.txt')        # feature 309: a link name with ".." stays reported
        else:
            raise SystemExit('unknown row ' + row)
    with open(out, 'wb') as f:
        f.write(buf.getvalue())


main()
