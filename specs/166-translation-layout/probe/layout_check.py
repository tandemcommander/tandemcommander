"""Feature 166 check: clipped labels and controls across a group box frame in the translations.

    python layout_check.py <translations dir> [--list]

For every language folder and module .slt: each single-line control (height <= 12 DLU) with text
is measured in the dialog font (MS Shell Dlg 2, 8 pt, 96 DPI; dialog units from the font's base
units as Windows computes them). CLIPPED: the text is wider than the control (minus 16 px for a
check box / radio button - the module's lang.rc says which, as tools/translate/layout.py reads
it). CROSSING: a control reaches past the right edge of a row that frames it (holds its left edge
and its whole height - a group box). Prints the totals per module and in all.
"""
import ctypes
import sys
from ctypes import wintypes
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / 'tools'))
from translate.config import load_enabled_modules  # noqa: E402
from translate.layout import load_control_classes  # noqa: E402
from translate.slt import load  # noqa: E402

gdi32 = ctypes.WinDLL('gdi32')
user32 = ctypes.WinDLL('user32')


class SIZE(ctypes.Structure):
    _fields_ = [('cx', ctypes.c_long), ('cy', ctypes.c_long)]


class TEXTMETRICW(ctypes.Structure):
    _fields_ = [(n, ctypes.c_long) for n in ('tmHeight', 'tmAscent', 'tmDescent', 'tmInternalLeading',
                                             'tmExternalLeading', 'tmAveCharWidth', 'tmMaxCharWidth',
                                             'tmWeight', 'tmOverhang', 'tmDigitizedAspectX',
                                             'tmDigitizedAspectY')] + \
               [(n, ctypes.c_wchar) for n in ('tmFirstChar', 'tmLastChar', 'tmDefaultChar', 'tmBreakChar')] + \
               [(n, ctypes.c_byte) for n in ('tmItalic', 'tmUnderlined', 'tmStruckOut', 'tmPitchAndFamily',
                                            'tmCharSet')]


gdi32.CreateFontW.restype = wintypes.HANDLE
gdi32.CreateCompatibleDC.restype = wintypes.HANDLE
gdi32.SelectObject.argtypes = [wintypes.HANDLE, wintypes.HANDLE]
gdi32.GetTextExtentPoint32W.argtypes = [wintypes.HANDLE, wintypes.LPCWSTR, ctypes.c_int, ctypes.POINTER(SIZE)]
dc = gdi32.CreateCompatibleDC(None)
FACE = next((a.split('=', 1)[1] for a in sys.argv if a.startswith('--face=')), 'MS Shell Dlg')
font = gdi32.CreateFontW(-11, 0, 0, 0, 400, 0, 0, 0, 1, 0, 0, 0, 0, FACE)
gdi32.SelectObject(dc, font)


def width(s):
    sz = SIZE()
    gdi32.GetTextExtentPoint32W(dc, s, len(s), ctypes.byref(sz))
    return sz.cx


BASE_X = (width('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz') / 26.0 + 1) / 2.0


def px(dlu):
    return int(dlu * BASE_X / 4)


def label(text):
    return text.replace('&&', '\x01').replace('&', '').replace('\x01', '&').split('\\t')[0]


def check(root, listing):
    mods = {m.name: m for m in load_enabled_modules()}
    total_clip = total_cross = 0
    per = {}
    for lang in sorted(p for p in Path(root).iterdir() if p.is_dir()):
        for slt in sorted(lang.glob('*.slt')):
            m = mods.get(slt.stem)
            if m is None:
                continue
            classes = load_control_classes(m.rh_path.with_name('lang.rc'), m.rh_path)
            f = load(slt)
            clip = cross = 0
            for sec in f.sections:
                if sec.kind != 'DIALOG' or not sec.rows:
                    continue
                checkable = classes.checkable.get(sec.number, frozenset())
                rows = [r for r in sec.rows[1:] if len(r.numbers) == 6]
                for r in rows:
                    cid, x, y, cx, cy = r.numbers[:5]
                    if not r.text.strip():
                        continue
                    if cy <= 12:
                        need = width(label(r.text)) + (16 if cid in checkable else 0)
                        if need > px(cx):
                            clip += 1
                            if listing:
                                print('CLIP %s/%s D%d #%d %d>%d %s' % (lang.name, slt.stem, sec.number, cid, need, px(cx), label(r.text)))
                    for g in rows:
                        if g is r:
                            continue
                        gx, gy, gcx, gcy = g.numbers[1:5]
                        if gx < x < gx + gcx and gy < y and y + cy <= gy + gcy and x + cx > gx + gcx:
                            cross += 1
                            if listing:
                                print('CROSS %s/%s D%d #%d %d>%d %s' % (lang.name, slt.stem, sec.number, cid, x + cx, gx + gcx, label(r.text)))
            key = slt.stem
            c = per.setdefault(key, [0, 0])
            c[0] += clip
            c[1] += cross
            total_clip += clip
            total_cross += cross
    for k in sorted(per):
        if per[k] != [0, 0]:
            print('%-12s clipped %4d   crossing %4d' % (k, per[k][0], per[k][1]))
    print('TOTAL clipped %d crossing %d' % (total_clip, total_cross))


check(sys.argv[1], '--list' in sys.argv)
