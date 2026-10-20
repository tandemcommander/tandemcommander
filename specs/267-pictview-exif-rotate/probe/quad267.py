"""Feature 267 probe helper: the quadrant colours of a picture.

    python quad267.py shown <file>          what the file holds, as it is stored
    python quad267.py want <file>           what a viewer that honours the Exif orientation shows
                                            (Pillow's ImageOps.exif_transpose)

Prints "<W>x<H> <TL><TR><BL><BR>" with each quadrant's centre pixel named R, G, B, Y (nearest of
the four fixture colours) or ? when it is near none of them. Pure ASCII output.
"""
import sys

from PIL import Image, ImageOps

NAMES = {'R': (255, 0, 0), 'G': (0, 255, 0), 'B': (0, 0, 255), 'Y': (255, 255, 0)}


def name(px):
    best, dist = '?', 1 << 30
    for n, c in NAMES.items():
        dd = sum((a - b) ** 2 for a, b in zip(px[:3], c))
        if dd < dist:
            best, dist = n, dd
    return best if dist < 3 * 60 * 60 else '?'


def main():
    mode, path = sys.argv[1], sys.argv[2]
    try:
        im = Image.open(path)
        im.load()
        if mode == 'want':
            im = ImageOps.exif_transpose(im)
        im = im.convert('RGB')
        w, h = im.size
        pts = [(w // 4, h // 4), (3 * w // 4, h // 4), (w // 4, 3 * h // 4), (3 * w // 4, 3 * h // 4)]
        print('%dx%d %s' % (w, h, ''.join(name(im.getpixel(p)) for p in pts)))
    except Exception as e:  # noqa: BLE001 - a probe reports, it does not stop
        print('ERROR ' + str(e).encode('ascii', 'replace').decode('ascii'))


if __name__ == '__main__':
    main()
