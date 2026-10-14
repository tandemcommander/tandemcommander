"""Feature 152 probe fixture (Pillow): python mkfix152.py <folder>; prints ok.

quad.png, 80x60: four quadrants of pure colors - red top left, green top right, blue bottom left,
yellow bottom right - so a capture of the print preview shows where each part of the picture went.
"""
import os
import sys

from PIL import Image

d = sys.argv[1]
W, H = 80, 60
COLORS = {(0, 0): (255, 0, 0), (1, 0): (0, 255, 0), (0, 1): (0, 0, 255), (1, 1): (255, 255, 0)}
im = Image.new('RGB', (W, H))
im.putdata([COLORS[(x * 2 // W, y * 2 // H)] for y in range(H) for x in range(W)])
im.save(os.path.join(d, 'quad.png'))
print('ok')
