"""Feature 111 probe fixtures (Pillow): python mkfix111.py <folder>; prints ok."""
import os
import sys

from PIL import Image
d = sys.argv[1]
W, H = 40, 30
def grad(mode='RGB'):
    im = Image.new('RGB', (W, H))
    for y in range(H):
        for x in range(W):
            im.putpixel((x, y), ((x*6) % 256, (y*8) % 256, ((x+y)*3) % 256))
    return im
rgb = grad()
rgb.save(os.path.join(d, 'rgb.png'))
rgb.transpose(Image.FLIP_LEFT_RIGHT).save(os.path.join(d, 'rgb_fliph.png'))
rgb.transpose(Image.ROTATE_270).transpose(Image.FLIP_LEFT_RIGHT).save(os.path.join(d, 'rgb_rot90_fliph.png'))
rgba = rgb.convert('RGBA'); rgba.save(os.path.join(d, 'rgba_opaque.png'))
ra = rgb.convert('RGBA')
for y in range(H):
    for x in range(W // 2):
        p = ra.getpixel((x, y)); ra.putpixel((x, y), p[:3] + (x * 10,))
ra.save(os.path.join(d, 'rgba_alpha.png'))
bl = Image.new('1', (W, H))
for y in range(H):
    for x in range(W):
        bl.putpixel((x, y), 1 if (x // 4 + y // 4) % 2 else 0)
bl.save(os.path.join(d, 'bilevel.png'))
bl.save(os.path.join(d, 'bilevel_g4.tif'), compression='group4')
bl.save(os.path.join(d, 'bilevel.bmp'))
bl.save(os.path.join(d, 'bilevel.gif'))
g = rgb.convert('L'); g.save(os.path.join(d, 'gray.png')); g.save(os.path.join(d, 'gray.jpg')); g.save(os.path.join(d, 'gray.tif'))
p16 = rgb.quantize(16); p16.save(os.path.join(d, 'pal16.png'), bits=4)
p256 = rgb.quantize(256); p256.save(os.path.join(d, 'pal256.png')); p256.save(os.path.join(d, 'pal256.gif'))
pt = rgb.quantize(16); pt.save(os.path.join(d, 'pal_trns.png'), transparency=0)
rgba.save(os.path.join(d, 'rgba_opaque.tif'))
ra.save(os.path.join(d, 'rgba_alpha.tif'))
rgb.save(os.path.join(d, 'rgb.tif'))
rgb.save(os.path.join(d, 'rgb.jpg'))
rgb.save(os.path.join(d, 'rgb.bmp'))
rgba.save(os.path.join(d, 'rgba_opaque.bmp'))
rgba.resize((32, 32)).save(os.path.join(d, 'icon_opaque.ico'), sizes=[(32, 32)])
ra.resize((32, 32)).save(os.path.join(d, 'icon_alpha.ico'), sizes=[(32, 32)])
# feature 111 review rows: a two-page TIFF (24-bit, then bilevel), a CMYK JPEG, a large noisy BMP
rgb.copy().save(os.path.join(d, 'multi.tif'), save_all=True, append_images=[bl.copy()])  # copies: no encoder settings of earlier saves
rgb.convert('CMYK').save(os.path.join(d, 'cmyk.jpg'))
big = Image.effect_noise((6000, 4000), 90).convert('RGB')
big = Image.merge('RGB', (big.getchannel(0), Image.effect_noise((6000, 4000), 70), Image.effect_noise((6000, 4000), 50)))
big.save(os.path.join(d, 'big.bmp'))
print('ok')
