#!/usr/bin/env python3
"""Contact sheets of the feature 123 captures (tester's aid for looking at them).

    python make_sheets.py            builds shots/_sheets/<dir>_a.png and <dir>_b.png for every
                                     sub-directory of shots/ (one per language / theme)

Sheet a: the two notifications and the About dialog in its three states.
Sheet b: the wait dialog, the answers of the manual check and the part of the General
configuration page that holds the option. Nothing is scaled.
"""
import os
import sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SHOTS = os.path.join(HERE, 'shots')
OUT = os.path.join(SHOTS, '_sheets')


def load(d, name, crop=None):
    f = os.path.join(SHOTS, d, name)
    if not os.path.exists(f):
        return None
    im = Image.open(f).convert('RGB')
    if crop:
        im = im.crop((crop[0], crop[1], min(crop[2], im.width), min(crop[3], im.height)))
    return im


def sheet(images, columns, file):
    images = [i for i in images if i is not None]
    if not images:
        return
    rows = [images[i:i + columns] for i in range(0, len(images), columns)]
    w = max(sum(i.width for i in r) + 8 * (len(r) + 1) for r in rows)
    h = sum(max(i.height for i in r) for r in rows) + 8 * (len(rows) + 1)
    out = Image.new('RGB', (w, h), (255, 0, 255))
    y = 8
    for r in rows:
        x = 8
        for i in r:
            out.paste(i, (x, y))
            x += i.width + 8
        y += max(i.height for i in r) + 8
    out.save(file)


def main():
    os.makedirs(OUT, exist_ok=True)
    for d in sorted(os.listdir(SHOTS)):
        if d.startswith('_') or not os.path.isdir(os.path.join(SHOTS, d)):
            continue
        a = [load(d, n) for n in ('notice_startup.png', 'notice_manual.png', 'about_notchecked.png', 'about_newer.png', 'about_latest.png')]
        sheet(a, 3, os.path.join(OUT, d + '_a.png'))
        b = [load(d, n) for n in ('wait.png', 'msg_uptodate.png', 'msg_refused.png', 'msg_unexpected.png', 'msg_unreachable.png')]
        b.append(load(d, 'config_general.png', (0, 30, 5000, 380)))
        sheet(b[:5], 2, os.path.join(OUT, d + '_b.png'))
        sheet(b[5:], 1, os.path.join(OUT, d + '_c.png'))
        print(d)
    return 0


if __name__ == '__main__':
    sys.exit(main())
