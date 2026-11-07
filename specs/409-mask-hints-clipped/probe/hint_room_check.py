"""Feature 409 check: the mask-hints link (control 102, IDC_FILEMASK_HINT) in the English layout.

    python -I -X utf8 hint_room_check.py [--base <commit>] [--template <salamand.slt>]

For every dialog of module salamand that holds control 102 it compares the exported English
template (default build/tandemcommander/translator/templates/salamand.slt - export it from the
current src/lang/lang.rc first) with the RTEXT rows of src/lang/lang.rc at <base> (default the
merge base with main) and checks:

  EDGE   the right edge x + cx is the one of <base> (right-aligned: it must not move);
  ROOM   the rectangle stays inside the dialog and overlaps no control it did not overlap at
         <base> (a drop-down combo box counts with its closed height, as tools/translate/layout.py);
  EST    cx >= translate.layout.estimate_width of every enabled language's committed text, so the
         merge's widening pass leaves the row alone (it would grow it to the right).

Prints one row per dialog and check and `TOTAL: <n> failed`; exit 1 when anything failed.
"""
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / 'tools'))
from translate.config import load_languages  # noqa: E402
from translate.layout import CLOSED_DROPDOWN_CY, estimate_width, load_control_classes  # noqa: E402
from translate.slt import load  # noqa: E402

HINT = 102


def arg(name, default):
    if name in sys.argv:
        return sys.argv[sys.argv.index(name) + 1]
    return default


def git(*a):
    return subprocess.run(['git', '-C', str(REPO)] + list(a), capture_output=True, check=True,
                          encoding='utf-8').stdout


base = arg('--base', None) or git('merge-base', 'main', 'HEAD').strip()
template = Path(arg('--template', str(REPO / 'build/tandemcommander/translator/templates/salamand.slt')))

# the base's hint rows, in file order, by dialog symbol -> id
rh = (REPO / 'src/lang/lang.rh').read_text(encoding='utf-8-sig')
defines = {m.group(1): int(m.group(2)) for m in re.finditer(r'#define\s+(\w+)\s+(\d+)', rh)}
base_rc = git('show', base + ':src/lang/lang.rc')
base_rows = {}
dialog = None
for line in base_rc.splitlines():
    m = re.match(r'^(\w+)\s+DIALOG(?:EX)?\b', line)
    if m:
        dialog = defines.get(m.group(1))
        continue
    m = re.match(r'^\s*RTEXT\s+"(?:[^"]|"")*"\s*,\s*IDC_FILEMASK_HINT\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)', line)
    if m and dialog is not None:
        base_rows[dialog] = tuple(int(g) for g in m.groups())

classes = load_control_classes(REPO / 'src/lang/lang.rc', REPO / 'src/lang/lang.rh')
langs = load_languages()
lang_files = {lang.folder: load(REPO / 'translations' / lang.folder / 'salamand.slt') for lang in langs}


def rect(n, dropdown):
    cid, x, y, cx, cy = n[:5]
    if cid in dropdown and cy > CLOSED_DROPDOWN_CY:
        cy = CLOSED_DROPDOWN_CY
    return x, y, x + cx, y + cy


def overlap(a, b):
    return a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]


def contains(outer, inner):
    return outer[0] <= inner[0] and outer[1] <= inner[1] and inner[2] <= outer[2] and inner[3] <= outer[3]


failed = 0
seen = 0


def row(check, dlg, ok, text):
    global failed
    failed += 0 if ok else 1
    print('%-4s D%-5d %-4s %s' % (check, dlg, 'PASS' if ok else 'FAIL', text))


for sec in load(template).sections:
    if sec.kind != 'DIALOG':
        continue
    rows = [r for r in sec.rows[1:] if len(r.numbers) == 6]
    hint = next((r for r in rows if r.numbers[0] == HINT), None)
    if hint is None:
        continue
    seen += 1
    d = sec.number
    dropdown = classes.dropdown.get(d, frozenset())
    _, x, y, cx, cy = hint.numbers[:5]
    old = base_rows.get(d)
    if old is None:
        row('EDGE', d, False, 'no IDC_FILEMASK_HINT row of this dialog at %s' % base)
        continue
    ox, oy, ocx, ocy = old
    row('EDGE', d, x + cx == ox + ocx and y == oy and cy == ocy,
        'x %d->%d cx %d->%d right %d->%d' % (ox, x, ocx, cx, ox + ocx, x + cx))
    new_r = (x, y, x + cx, y + cy)
    old_r = (ox, oy, ox + ocx, oy + ocy)
    dlg_cx, dlg_cy = sec.rows[0].numbers[0], sec.rows[0].numbers[1]
    bad = []
    if x < 0 or x + cx > dlg_cx:
        bad.append('outside the dialog (%d wide)' % dlg_cx)
    for o in rows:
        if o is hint:
            continue
        r = rect(o.numbers, dropdown)
        # a frame that holds the link (group box, the dialog-wide list) is not an overlap
        if contains(r, old_r):
            continue
        if overlap(new_r, r) and not overlap(old_r, r):
            bad.append('new overlap with #%d %r' % (o.numbers[0], o.text[:24]))
    row('ROOM', d, not bad, '; '.join(bad) if bad else 'x %d..%d free in y %d..%d' % (x, x + cx, y, y + cy))
    worst = []
    for folder, f in lang_files.items():
        s = next((s for s in f.sections if s.key == sec.key), None)
        lr = None if s is None else next((r for r in s.rows[1:] if len(r.numbers) == 6 and r.numbers[0] == HINT), None)
        if lr is None:
            worst.append('%s: no row' % folder)
            continue
        e = estimate_width(lr.text)
        if e > cx:
            worst.append('%s %r est %d > %d' % (folder, lr.text, e, cx))
    row('EST', d, not worst, '; '.join(worst) if worst else 'every enabled language estimate <= %d' % cx)

if seen == 0:
    print('no dialog with control %d in %s' % (HINT, template))
    failed += 1
print('dialogs: %d (base %s)' % (seen, base[:8]))
print('TOTAL: %d failed' % failed)
sys.exit(1 if failed else 0)
