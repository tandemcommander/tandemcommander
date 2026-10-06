"""Feature 120 probe fixtures (Pillow): python mkfix120.py <folder>; prints ok."""
import os
import sys

from PIL import Image

d = sys.argv[1]
W, H = 40, 30


def grad():
    im = Image.new('RGB', (W, H))
    im.putdata([((x * 6) % 256, (y * 8) % 256, ((x + y) * 3) % 256) for y in range(H) for x in range(W)])
    return im


rgb = grad()
rgb.save(os.path.join(d, 'rgb.png'))
rgb.transpose(Image.Transpose.ROTATE_270).save(os.path.join(d, 'rgb_rot90.png'))  # 90 degrees clockwise
rgb.convert('L').save(os.path.join(d, 'gray.png'))
# the histogram rows: one color (one level per channel), the same as an 8-bit GIF, and with alpha
one = Image.new('RGB', (W, H), (200, 100, 50))
one.save(os.path.join(d, 'one_color.png'))
one.quantize(2).save(os.path.join(d, 'one_color.gif'))
oa = Image.new('RGBA', (W, H))
oa.putdata([(200, 100, 50, 255 if x < W // 2 else 0) for y in range(H) for x in range(W)])
oa.save(os.path.join(d, 'one_alpha.png'))
# the pipette rows: every pixel of its own color
PW, PH = 120, 90
pip = Image.new('RGB', (PW, PH))
pip.putdata([((x * 2) % 256, (y * 2 + 7) % 256, (x * 3 + y * 5) % 256) for y in range(PH) for x in range(PW)])
pip.save(os.path.join(d, 'pipette.png'))
print('ok')
