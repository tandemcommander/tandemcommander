# Review 2 (feature 123): mechanical checks of the new translation rows.
# - strings 13201, 14103-14111, 14144-14149: %s and \n counts against src/lang/texts.rc2, identical-to-English
# - dialogs 6236, 6251, 270 (About), control 6255 in dialog 300: texts, accelerator collisions per dialog
import io
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', '..'))
LANGS = ['czech', 'german', 'french', 'dutch', 'hungarian', 'romanian', 'slovak', 'spanish']
IDS = [13201] + list(range(14103, 14112)) + list(range(14144, 14150))

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')


def read(path):
    with open(path, 'rb') as f:
        return f.read().decode('utf-8-sig')


def english_strings():
    rh = read(os.path.join(ROOT, 'src', 'texts.rh2'))
    names = {}
    for m in re.finditer(r'#define\s+(IDS_\w+)\s+(\d+)', rh):
        names[m.group(1)] = int(m.group(2))
    rc = read(os.path.join(ROOT, 'src', 'lang', 'texts.rc2'))
    out = {}
    for m in re.finditer(r'^\s*(IDS_\w+),\s*"((?:[^"]|"")*)"', rc, re.M):
        if m.group(1) in names:
            out[names[m.group(1)]] = m.group(2)
    return out


def parse_slt(text):
    dialogs = {}
    strings = {}
    cur = None
    for line in text.splitlines():
        m = re.match(r'^\[DIALOG (\d+)\]', line)
        if m:
            cur = int(m.group(1))
            dialogs[cur] = []
            continue
        if line.startswith('['):
            cur = None
            continue
        if cur is not None:
            m = re.match(r'^(\d+),(-?\d+),(-?\d+),(-?\d+),(-?\d+),(\d+),"(.*)"$', line)
            if m:
                dialogs[cur].append((int(m.group(1)), m.group(7), tuple(int(m.group(i)) for i in range(2, 6))))
                continue
            m = re.match(r'^(-?\d+),(-?\d+),(\d+),"(.*)"$', line)
            if m:
                dialogs[cur].append((None, m.group(4), None))
                continue
            if line.strip() == '':
                cur = None
            continue
        m = re.match(r'^(\d+),(\d+),"(.*)"$', line)
        if m:
            strings[int(m.group(1))] = m.group(3)
    return dialogs, strings


def accel(text):
    t = text.replace('&&', '')
    m = re.search(r'&(.)', t)
    return m.group(1).lower() if m else None


eng = english_strings()
print('English:')
for i in IDS:
    print('  %d %r' % (i, eng.get(i)))

for lang in LANGS:
    dialogs, strings = parse_slt(read(os.path.join(ROOT, 'translations', lang, 'salamand.slt')))
    print('\n== %s' % lang)
    for i in IDS:
        t = strings.get(i)
        e = eng.get(i, '')
        flags = []
        if t is None:
            flags.append('MISSING')
        else:
            if t.count('%s') != e.count('%s') or t.count('%') != e.count('%'):
                flags.append('PLACEHOLDERS')
            if t.count('\\n') != e.count('\\n'):
                flags.append('NEWLINES %d/%d' % (t.count('\\n'), e.count('\\n')))
            if t == e:
                flags.append('SAME-AS-ENGLISH')
            if ('&' in e) != ('&' in t):
                flags.append('ACCEL-PRESENCE')
        print('  %d %s %s' % (i, t, ('   <<< ' + ', '.join(flags)) if flags else ''))
    for d in (6236, 6251, 270, 300):
        rows = dialogs.get(d)
        if rows is None:
            print('  [DIALOG %d] MISSING' % d)
            continue
        seen = {}
        show = d in (6236, 6251, 270)
        if show:
            print('  [DIALOG %d]' % d)
        for cid, text, rect in rows:
            if show and text:
                print('    %s %s %s' % (cid, rect, text))
            if d == 300 and cid == 6255:
                print('  [DIALOG 300] 6255 %s %s' % (rect, text))
            a = accel(text)
            if a and cid is not None:
                seen.setdefault(a, []).append((cid, text))
        for a, lst in seen.items():
            if len(lst) > 1:
                print('    ACCELERATOR COLLISION in dialog %d on "%s": %s' % (d, a, lst))
