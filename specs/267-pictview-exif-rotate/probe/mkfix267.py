"""Feature 267 probe fixtures (Pillow): python mkfix267.py <folder>; prints ok.

JPEG files of four solid quadrants (red top-left, green top-right, blue bottom-left, yellow
bottom-right; 64 x 48, quality 95, no chroma subsampling) - so a turned or mirrored picture is
told apart by the colours of its quadrants, independently of the decoder's rounding:

    o1.jpg .. o8.jpg   an Exif block with Orientation 1..8 and PixelXDimension / PixelYDimension
                       64 x 48 (what a camera writes)
    o6-nodims.jpg      Orientation 6, no PixelX/YDimension
    o6-moddims.jpg     Orientation 6, PixelX/YDimension 640 x 480 (the picture was changed after
                       the camera wrote the block - PictView's rule: not turned)
    noexif.jpg         no Exif block
    xmp.jpg            an XMP block (APP1, not Exif) only
    o6.tif             a TIFF with Orientation 6 (not a JPEG)
"""
import os
import sys

from PIL import Image

d = sys.argv[1]
W, H = 64, 48
COLORS = [(255, 0, 0), (0, 255, 0), (0, 0, 255), (255, 255, 0)]  # TL, TR, BL, BR


def quad():
    im = Image.new('RGB', (W, H))
    im.putdata([COLORS[(0 if y < H // 2 else 2) + (0 if x < W // 2 else 1)] for y in range(H) for x in range(W)])
    return im


def exif(orient, dims):
    ex = Image.Exif()
    if orient:
        ex[0x0112] = orient
    if dims:
        sub = ex.get_ifd(0x8769)
        sub[0xA002] = dims[0]
        sub[0xA003] = dims[1]
    return ex.tobytes()


def save(name, **kw):
    quad().save(os.path.join(d, name), 'JPEG', quality=95, subsampling=0, **kw)


for o in range(1, 9):
    save('o%d.jpg' % o, exif=exif(o, (W, H)))
save('o6-nodims.jpg', exif=exif(6, None))
save('o6-moddims.jpg', exif=exif(6, (640, 480)))
save('noexif.jpg')
xmp = (b'<?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?><x:xmpmeta xmlns:x="adobe:ns:meta/">'
       b'<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"/></x:xmpmeta><?xpacket end="w"?>')
save('xmp.jpg', xmp=xmp)
# not a JPEG: a TIFF with Orientation 6 in its own IFD (the feature leaves other formats alone)
quad().save(os.path.join(d, 'o6.tif'), 'TIFF', tiffinfo={274: 6})

# self-check: the blocks are what the rows rely on
for o in range(1, 9):
    ex = Image.open(os.path.join(d, 'o%d.jpg' % o)).getexif()
    sub = ex.get_ifd(0x8769)
    assert ex.get(0x0112) == o and sub.get(0xA002) == W and sub.get(0xA003) == H, o
assert not Image.open(os.path.join(d, 'noexif.jpg')).getexif()
with open(os.path.join(d, 'xmp.jpg'), 'rb') as f:
    data = f.read()
assert b'http://ns.adobe.com/xap/1.0/' in data and b'Exif\0\0' not in data
print('ok')
