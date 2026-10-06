"""Feature 120 probe reference (Pillow), independent of the program.

python ref120.py hist <image> <background RRGGBB>
    the histogram levels the viewer must show, per channel, for the image composited over the
    background: "lum=124|red=200|green=100|blue=50|rgb=50,100,200" (levels with a count > 0)
python ref120.py pix <image> <x,y> [<x,y> ...]
    the color of each pixel: "x,y=R,G,B" one per line
"""
import sys

from PIL import Image


def composite(path, bg):
    im = Image.open(path).convert('RGBA')
    base = Image.new('RGBA', im.size, bg + (255,))
    return Image.alpha_composite(base, im).convert('RGB')


if sys.argv[1] == 'hist':
    bg = tuple(int(sys.argv[3][i:i + 2], 16) for i in (0, 2, 4))
    raw = composite(sys.argv[2], bg).tobytes()
    s = {k: set() for k in ('lum', 'red', 'green', 'blue', 'rgb')}
    for i in range(0, len(raw), 3):
        r, g, b = raw[i], raw[i + 1], raw[i + 2]
        s['red'].add(r)
        s['green'].add(g)
        s['blue'].add(b)
        s['lum'].add((299 * r + 587 * g + 114 * b) // 1000)
        s['rgb'].update((r, g, b))
    print('|'.join('%s=%s' % (k, ','.join(str(v) for v in sorted(s[k]))) for k in ('lum', 'red', 'green', 'blue', 'rgb')))
else:
    im = Image.open(sys.argv[2]).convert('RGB')
    for a in sys.argv[3:]:
        x, y = (int(v) for v in a.split(','))
        print('%d,%d=%d,%d,%d' % ((x, y) + im.getpixel((x, y))))
