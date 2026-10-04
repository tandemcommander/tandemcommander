# Feature 108 probe helper: makes and reads the test archives.
#
#   python arcfix.py make <spec.json>   spec: {"arc": path, "fmt": "zip"|"7z", ["first": tag of member 1,]
#                                               "sevenzip": path-to-7z.exe,
#                                               "members": ["name/in/archive", ...]}
#       member i (1-based) holds the text "content-of-member-<i>\r\n"; ZIP is written
#       by Python's zipfile (DOS host, UTF-8 flag for non-ASCII names), 7z by 7z.exe:
#       the members are staged as m<i>.txt and then renamed inside the archive
#       ("7z rn"), because NTFS cannot hold a case-only pair in one folder
#   python arcfix.py read <spec.json> <marker>
#       prints one line per entry: ENTRY <escaped name> tag=<i or ?> markers=<n> size=<n>
#       and a last line COUNT <n>; names are printed with \uXXXX escapes (ASCII output)
#
# Spec files and names travel as UTF-8 JSON, never on a command line.
import io, json, os, re, shutil, subprocess, sys, tempfile, zipfile


def esc(s):
    return ''.join(c if 32 <= ord(c) < 127 else '\\u%04X' % ord(c) for c in s)


def data_of(i):
    return ('content-of-member-%d\r\n' % i).encode('ascii')


def make(spec):
    arc, fmt, members = spec['arc'], spec['fmt'], spec['members']
    first = spec.get('first', 1) # the tag of the first member (two archives with distinct contents)
    if os.path.exists(arc):
        os.remove(arc)
    if fmt == 'zip':
        with zipfile.ZipFile(arc, 'w', zipfile.ZIP_DEFLATED) as z:
            for i, n in enumerate(members, first):
                zi = zipfile.ZipInfo(n, (2026, 1, 2, 3, 4, 6))
                zi.compress_type = zipfile.ZIP_DEFLATED
                z.writestr(zi, data_of(i))
        return
    sz = spec['sevenzip']
    stage = tempfile.mkdtemp(prefix='tc108stage_', dir=os.path.dirname(arc))
    try:
        staged = []
        for i, n in enumerate(members, first):
            d = os.path.dirname(n.replace('/', os.sep))
            rel = os.path.join(d, 'm%d.txt' % i) if d else 'm%d.txt' % i
            os.makedirs(os.path.join(stage, d), exist_ok=True)
            with open(os.path.join(stage, rel), 'wb') as f:
                f.write(data_of(i))
            staged.append(rel)
        r = subprocess.run([sz, 'a', '-t7z', arc, '*', '-r'], cwd=stage, capture_output=True)
        if r.returncode != 0:
            raise SystemExit('7z a failed: %r' % r.stdout[-400:])
        args = [sz, 'rn', '-ssc', arc]
        for rel, n in zip(staged, members):
            if rel.replace(os.sep, '/') != n:
                args += [rel, n.replace('/', os.sep)]
        if len(args) > 4:
            r = subprocess.run(args, capture_output=True)
            if r.returncode != 0:
                raise SystemExit('7z rn failed: %r' % r.stdout[-400:])
    finally:
        shutil.rmtree(stage, ignore_errors=True)


def describe(name, data, marker):
    m = re.search(rb'content-of-member-(\d+)', data or b'')
    tag = m.group(1).decode() if m else '?'
    n = (data or b'').count(marker.encode('ascii'))
    print('ENTRY %s tag=%s markers=%d size=%d' % (esc(name), tag, n, len(data or b'')))


def read(spec, marker):
    arc, fmt = spec['arc'], spec['fmt']
    if fmt == 'zip':
        with zipfile.ZipFile(arc) as z:
            bad = z.testzip()
            if bad is not None:
                print('TESTZIP-FAILED %s' % esc(bad))
            infos = [i for i in z.infolist() if not i.is_dir()]
            for i in infos:
                describe(i.filename, z.read(i), marker)
            print('COUNT %d' % len(infos))
        return
    sz = spec['sevenzip']
    r = subprocess.run([sz, 'l', '-slt', '-ba', '-sccUTF-8', arc], capture_output=True)
    if r.returncode != 0:
        print('LIST-FAILED rc=%d' % r.returncode)
        return
    out = r.stdout.decode('utf-8', 'replace').replace('\r\n', '\n')
    entries = []
    for block in out.split('\n\n'):
        path = None
        isdir = False
        for line in block.split('\n'):
            if line.startswith('Path = '):
                path = line[7:]
            elif line.startswith('Folder = ') and line[9:].strip() == '+':
                isdir = True
            elif line.startswith('Attributes = ') and line[13:].startswith('D'):
                isdir = True
        if path is not None and not isdir:
            entries.append(path)
    for p in entries:
        r = subprocess.run([sz, 'e', '-so', '-ssc', arc, p], capture_output=True)
        describe(p.replace(os.sep, '/'), r.stdout if r.returncode == 0 else None, marker)
    print('COUNT %d' % len(entries))


if __name__ == '__main__':
    spec = json.load(io.open(sys.argv[2], 'r', encoding='utf-8'))
    if sys.argv[1] == 'make':
        make(spec)
    else:
        read(spec, sys.argv[3])
