"""Feature 120: fixtures + Pillow reference for pixharness.exe (PictView's engine and pipette /
histogram reader, compiled from the plug-in's sources).

pixref.py <out dir> <new pixharness.exe> [<old pixharness.exe>]

Makes the fixtures with Pillow in <out dir>\\fix, runs each program on all of them and compares:
  PIX   every pixel the pipette reads (GetRGBAtCursor) with Pillow's pixel composited over white
        (the engine's default background; the alpha fixtures use alpha 0 or 255 only, so the
        composite is exact whatever the converter's rounding)
  HIST  the five histogram channels (CalculateHistogram) with the same counts made from Pillow's
        pixels: red, green, blue, luminosity (299 R + 587 G + 114 B) // 1000, "RGB" (every channel
        value once, // 3 per level)
  TURN  the engine's rows after a 90 degree clockwise turn and a new background color (black):
        the size and a hash of the rows' B, G, R bytes against Pillow's image composited over black
        and turned clockwise; TURN3 the same after two more turns and white again (= one
        counter-clockwise turn over white)
Prints one line per fixture and program; exit code = the number of mismatching checks of the NEW
program (the old one is expected to fail - it is the control).
"""
import os
import subprocess
import sys

from PIL import Image

OUT, NEW = sys.argv[1], sys.argv[2]
OLD = sys.argv[3] if len(sys.argv) > 3 else None
FIX = os.path.join(OUT, 'fix')
os.makedirs(FIX, exist_ok=True)

W, H = 37, 5  # a width that is not a multiple of 4: the old reader read 3/4 of each row


def px(x, y):
    return ((x * 53 + y * 17) % 256, (x * 29 + y * 71 + 40) % 256, (x * 11 + y * 113 + 90) % 256)


def make():
    fx = {}
    im = Image.new('RGB', (W, H))
    im.putdata([px(x, y) for y in range(H) for x in range(W)])
    im.save(os.path.join(FIX, 'rgb24.png'))
    fx['rgb24.png'] = im.convert('RGBA')
    a = Image.new('RGBA', (W, H))
    a.putdata([px(x, y) + (255,) for y in range(H) for x in range(W)])
    a.save(os.path.join(FIX, 'rgba_opaque.png'))
    fx['rgba_opaque.png'] = a
    t = Image.new('RGBA', (W, H))
    t.putdata([px(x, y) + (0 if (x + y) % 3 == 0 else 255,) for y in range(H) for x in range(W)])
    t.save(os.path.join(FIX, 'rgba_alpha.png'))
    fx['rgba_alpha.png'] = t
    p = Image.new('P', (W, H))
    pal = []
    for i in range(256):
        pal += [i, (i * 7) % 256, 255 - i]
    p.putpalette(pal)
    p.putdata([(x * 7 + y * 31) % 256 for y in range(H) for x in range(W)])
    p.save(os.path.join(FIX, 'pal8.gif'))
    fx['pal8.gif'] = Image.open(os.path.join(FIX, 'pal8.gif')).convert('RGBA')
    p4 = Image.new('P', (W, H))
    p4.putpalette([v for i in range(16) for v in (i * 16, 255 - i * 16, (i * 40) % 256)])
    p4.putdata([(x + y) % 16 for y in range(H) for x in range(W)])
    p4.save(os.path.join(FIX, 'pal16.png'), bits=4)
    fx['pal16.png'] = Image.open(os.path.join(FIX, 'pal16.png')).convert('RGBA')
    b = Image.new('1', (W, H))
    b.putdata([255 if (x * y + x) % 3 else 0 for y in range(H) for x in range(W)])
    b.save(os.path.join(FIX, 'bilevel.png'))
    fx['bilevel.png'] = b.convert('RGBA')
    g = Image.new('L', (W, H))
    g.putdata([(x * 7 + y * 50) % 256 for y in range(H) for x in range(W)])
    g.save(os.path.join(FIX, 'gray.png'))
    fx['gray.png'] = g.convert('RGBA')
    one = Image.new('RGB', (40, 30), (200, 100, 50))
    one.save(os.path.join(FIX, 'one_color.png'))
    fx['one_color.png'] = one.convert('RGBA')
    name = 'P' + chr(0x0159) + chr(0x00ED) + 'klad ' + chr(0x65E5) + '.png'  # a UTF-8 name through the engine
    im.save(os.path.join(FIX, name))
    fx[name] = im.convert('RGBA')
    return fx


def over(img, bg):
    base = Image.new('RGBA', img.size, bg + (255,))
    return Image.alpha_composite(base, img).convert('RGB')


def hist(pixels):
    h = {k: [0] * 256 for k in ('lum', 'red', 'green', 'blue', 'rgb')}
    for r, g, b in pixels:
        h['red'][r] += 1
        h['green'][g] += 1
        h['blue'][b] += 1
        h['lum'][(299 * r + 587 * g + 114 * b) // 1000] += 1
        h['rgb'][r] += 1
        h['rgb'][g] += 1
        h['rgb'][b] += 1
    h['rgb'] = [v // 3 for v in h['rgb']]
    return h


def fnv(img):
    v = 2166136261
    raw = img.tobytes()  # R, G, B
    for i in range(0, len(raw), 3):
        for byte in (raw[i + 2], raw[i + 1], raw[i]):
            v = ((v ^ byte) * 16777619) & 0xFFFFFFFF
    return '%08x' % v


def run(exe, fx):
    files = [os.path.join(FIX, n) for n in fx]
    out = subprocess.run([exe] + files, capture_output=True)
    text = out.stdout.decode('utf-8', 'replace')
    recs, cur = {}, None
    for line in text.splitlines():
        f = line.split('|')
        if f[0] == 'FILE':
            cur = os.path.basename(f[1])
            recs[cur] = {'info': f[2:], 'pix': {}, 'hist': {}, 'turn': None, 'turn3': None}
        elif f[0] == 'PIX' and cur:
            recs[cur]['pix'][(int(f[1]), int(f[2]))] = (int(f[3]), int(f[4]), int(f[5]), int(f[6]))
        elif f[0] == 'HIST' and cur:
            recs[cur]['hist'][f[1]] = [int(v) for v in f[2].split(',')]
        elif f[0] in ('TURN', 'TURN3') and cur:
            recs[cur][f[0].lower()] = (int(f[1]), int(f[2]), f[3])
    return recs, out.returncode


def check(label, exe, fx):
    recs, rc = run(exe, fx)
    bad_total = 0
    for name, img in fx.items():
        r = recs.get(name)
        if r is None or not r['pix']:
            print('%s %-22s NO OUTPUT (exit %d) %s' % (label, ascii(name), rc, r['info'] if r else ''))
            bad_total += 1
            continue
        ref = over(img, (255, 255, 255))
        w, h = ref.size
        badpix, first = 0, None
        for y in range(h):
            for x in range(w):
                got = r['pix'].get((x, y))
                want = ref.getpixel((x, y))
                if got is None or got[3] != 1 or got[:3] != want:
                    badpix += 1
                    if first is None:
                        first = '(%d,%d) got %s want %s' % (x, y, got[:3] if got else None, want)
        raw = ref.tobytes()
        refh = hist([(raw[i], raw[i + 1], raw[i + 2]) for i in range(0, len(raw), 3)])
        badh = [c for c in ('lum', 'red', 'green', 'blue', 'rgb') if r['hist'].get(c) != refh[c]]
        tref = over(img, (0, 0, 0)).transpose(Image.Transpose.ROTATE_270)
        want_turn = (tref.size[0], tref.size[1], fnv(tref))
        turn_ok = r['turn'] == want_turn
        t3 = over(img, (255, 255, 255)).transpose(Image.Transpose.ROTATE_90)
        want_t3 = (t3.size[0], t3.size[1], fnv(t3))
        t3_ok = r['turn3'] == want_t3
        bad = badpix + len(badh) + (0 if turn_ok else 1) + (0 if t3_ok else 1)
        bad_total += bad
        print('%s %-22s %s  pipette %d/%d pixels wrong%s; histogram channels wrong: %s; turn + new background: %s (want %dx%d %s); three turns + white: %s (want %dx%d %s)' % (
            label, ascii(name), 'OK  ' if bad == 0 else 'FAIL', badpix, w * h, (' - first ' + first) if first else '',
            ','.join(badh) or 'none', ('%dx%d %s' % r['turn']) if r['turn'] else 'none', want_turn[0], want_turn[1], want_turn[2],
            ('%dx%d %s' % r['turn3']) if r['turn3'] else 'none', want_t3[0], want_t3[1], want_t3[2]))
    return bad_total


fx = make()
print('fixtures: %d images %dx%d (one 40x30) by Pillow %s in %s' % (len(fx), W, H, Image.__version__, FIX))
nbad = check('NEW', NEW, fx)
if OLD:
    obad = check('OLD', OLD, fx)
    print('OLD (control): %d mismatching checks - the defect shows when > 0' % obad)
print('NEW: %d mismatching checks' % nbad)
sys.exit(min(nbad, 255))
