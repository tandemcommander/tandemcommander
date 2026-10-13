# Feature 132: the files thumb132_probe.ps1 kept (-KeepDir): does each result still decode to
# the original picture, and does an updated one hold a thumbnail that decodes?
# Usage: python check_outputs.py <keep folder> [result file]
import glob
import io
import os
import sys

from PIL import Image


def pixels(data):
    try:
        im = Image.open(io.BytesIO(data))
        im.load()
        return im.size, im.tobytes()
    except Exception:  # noqa
        return None, None


def thumbnail(data):
    """the first embedded JPEG picture before the main picture's data (Exif or JFXX thumbnail)"""
    soi = bytes([0xFF, 0xD8, 0xFF])
    i = data.find(soi, 2)
    while i > 0:
        try:
            im = Image.open(io.BytesIO(data[i:]))
            im.load()
            return im.size
        except Exception:  # noqa
            i = data.find(soi, i + 1)
    return None


def main():
    keep = sys.argv[1]
    lines = []
    bad = 0
    for after in sorted(glob.glob(os.path.join(keep, '*.after.jpg'))):
        case = os.path.basename(after)[:-len('.after.jpg')]
        new = open(after, 'rb').read()
        orig = open(os.path.join(keep, case + '.orig.jpg'), 'rb').read()
        if new == orig:
            lines.append('%-9s unchanged (%d bytes)' % (case, len(new)))
            continue
        osize, opix = pixels(orig)
        nsize, npix = pixels(new)
        same = opix is not None and opix == npix and osize == nsize
        th = thumbnail(new)
        ok = same and th is not None and th[0] <= 160 and th[1] <= 120 and (th[0] == 160 or th[1] == 120)
        if not ok:
            bad += 1
        lines.append('%-9s updated %d -> %d bytes; decodes to the same pixels: %s; thumbnail inside: %s : %s' % (
            case, len(orig), len(new), same, th, 'ok' if ok else 'BAD'))
    lines.append('')
    lines.append('bad files: %d' % bad)
    text = '\n'.join(lines)
    print(text)
    if len(sys.argv) > 2:
        open(sys.argv[2], 'w', encoding='utf-8', newline='\n').write(text + '\n')
    sys.exit(bad)


if __name__ == '__main__':
    main()
