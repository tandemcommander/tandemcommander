"""Regenerate the shipped Tandem Commander brand assets from hand-swappable sources.

Feature 035: every graphic is replaceable by swapping a file here and
re-running this script — no source-code or project-file edits.

Inputs (all in tools/brand/):

    icon-master.png   REQUIRED  square PNG, edge >= 256 px (1024 recommended);
                                every icon size is derived from it (Lanczos)
    icon-<N>.png      OPTIONAL  N in {16, 24, 32, 48, 64, 128, 256}; must be
                                exactly NxN; overrides the master-derived
                                rendering for that one size
    about.png         REQUIRED  artwork drawn in the About dialog and on the
                                splash screen (copied verbatim to
                                src/res/logo.png; alpha supported; scaled to
                                fit at draw time, aspect preserved)
    hotpath-master.png REQUIRED square PNG, edge >= 256 px; grayscale bookmark
                                motif (white fill, dark outline, alpha) for the
                                hot path icon gallery (feature 047); the RGB
                                channels are multiplied by each gallery color,
                                so keep the fill white/light for clean tinting

Usage (from anywhere; paths are resolved relative to this file):

    python tools/brand/gen_icons.py            # regenerate all shipped assets
    python tools/brand/gen_icons.py --verify   # structural check, no writes

Feature 428: src/res/salamand_portable.ico, the program icon of the portable edition, is the same
icon with a badge drawn on every size by portable_badge() below (no extra source file): a disk in
the lower-right corner - blue, ringed dark and then light so it reads on light and dark
taskbars - with a white USB-stick glyph. Each size is drawn at 4x and scaled down.

ICO packing convention (kept from feature 032): 32-bpp; BMP-encoded entries
for sizes <= 64 px, PNG-encoded entries for sizes >= 128 px.
"""

import io
import struct
import sys
from pathlib import Path

from PIL import Image, ImageDraw

BRAND_DIR = Path(__file__).resolve().parent
REPO_ROOT = BRAND_DIR.parent.parent

MASTER = BRAND_DIR / "icon-master.png"
ABOUT = BRAND_DIR / "about.png"
HOTPATH_MASTER = BRAND_DIR / "hotpath-master.png"

ICON_SIZES = (16, 24, 32, 48, 64, 128, 256)
MASTER_MIN_EDGE = 256

# Shipped ICO outputs (repo-relative); all pack the full size set.
ICO_TARGETS = (
    "src/res/salamand.ico",
    "src/setup/res/setup.ico",
    "src/setup/remove/icon1.ico",
)

LOGO_PNG = "src/res/logo.png"

# Feature 047: hot path icon gallery color variants. The tuple order is
# APPEND-ONLY - hotpath<N>.ico is gallery index N and the index is persisted
# in the user's configuration (gallery index 0 is the system default icon and
# is not generated here). Sizes cover the 16 px base at 100-200 % DPI.
HOTPATH_SIZES = (16, 20, 24, 32)
HOTPATH_TINTS = (
    ("red", (229, 72, 77)),
    ("orange", (247, 107, 21)),
    ("yellow", (245, 176, 0)),
    ("green", (70, 167, 88)),
    ("teal", (18, 165, 148)),
    ("blue", (62, 99, 221)),
    ("purple", (142, 78, 198)),
    ("pink", (214, 64, 159)),
    ("gray", (141, 141, 141)),
)
HOTPATH_TARGETS = tuple(
    f"src/res/hotpath{i}.ico" for i in range(1, len(HOTPATH_TINTS) + 1))

# Feature 428: the portable edition's program icon (salamand.rc2 under TC_PORTABLE)
PORTABLE_ICO = "src/res/salamand_portable.ico"
BADGE_FILL = (37, 99, 235, 255)    # blue - stands apart from the orange folder
BADGE_DARK = (30, 41, 59, 255)     # slate - the ring that reads on light backgrounds
BADGE_LIGHT = (255, 255, 255, 255) # the outer ring that reads on dark backgrounds
BADGE_GLYPH = (255, 255, 255, 255)

PNG_MAGIC = b"\x89PNG\r\n\x1a\n"


def portable_badge(frame):
    """The frame with the portable badge in its lower-right corner (feature 428)."""
    size = frame.size[0]
    k = 4
    big = size * k
    layer = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    r = 0.25 * big                    # the disk
    ring = max(0.035 * big, 1.5 * k)  # each ring at least 1.5 px wide in the final size
    cx = cy = big - r - 2 * ring
    for radius, color in ((r + 2 * ring, BADGE_LIGHT), (r + ring, BADGE_DARK), (r, BADGE_FILL)):
        d.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=color)
    # the USB stick: a body with a connector on top, upright in the disk
    bw, bh = 0.62 * r, 0.82 * r
    bx0, by0 = cx - bw / 2, cy - bh / 2 + 0.18 * r
    d.rounded_rectangle((bx0, by0, bx0 + bw, by0 + bh), radius=0.14 * r, fill=BADGE_GLYPH)
    cw, ch = 0.38 * r, 0.42 * r
    cx0, cy0 = cx - cw / 2, by0 - ch + 0.04 * r
    d.rectangle((cx0, cy0, cx0 + cw, cy0 + ch), fill=BADGE_GLYPH)
    if size >= 32:  # the connector's two contacts, where there are pixels for them
        hw = 0.09 * r
        for hx in (cx - 0.11 * r - hw / 2, cx + 0.11 * r - hw / 2):
            d.rectangle((hx, cy0 + 0.1 * r, hx + hw, cy0 + 0.22 * r), fill=BADGE_FILL)
    badge = layer.resize((size, size), Image.LANCZOS)
    out = frame.copy()
    out.alpha_composite(badge)
    return out


def fail(msg):
    sys.exit(f"error: {msg}")


def load_png(path):
    """Open a PNG as RGBA or fail with a message naming the file."""
    try:
        img = Image.open(path)
        if img.format != "PNG":
            fail(f"{path} is {img.format}, expected PNG")
        return img.convert("RGBA")
    except FileNotFoundError:
        fail(f"{path} is missing")
    except Image.UnidentifiedImageError:
        fail(f"{path} cannot be decoded as PNG")


def load_sources():
    """Validate ALL inputs up front; nothing is written if any input is bad."""
    master = load_png(MASTER)
    w, h = master.size
    if w != h:
        fail(f"{MASTER} is {w}x{h}, expected a square image")
    if w < MASTER_MIN_EDGE:
        fail(f"{MASTER} is {w}x{h}, expected edge >= {MASTER_MIN_EDGE} px")

    overrides = {}
    for size in ICON_SIZES:
        path = BRAND_DIR / f"icon-{size}.png"
        if not path.exists():
            continue
        img = load_png(path)
        if img.size != (size, size):
            fail(f"{path} is {img.size[0]}x{img.size[1]}, expected exactly {size}x{size}")
        overrides[size] = img

    if not ABOUT.exists():
        fail(f"{ABOUT} is missing")
    load_png(ABOUT)  # decodability check only; the file is copied verbatim

    hotpath = load_png(HOTPATH_MASTER)
    w, h = hotpath.size
    if w != h:
        fail(f"{HOTPATH_MASTER} is {w}x{h}, expected a square image")
    if w < MASTER_MIN_EDGE:
        fail(f"{HOTPATH_MASTER} is {w}x{h}, expected edge >= {MASTER_MIN_EDGE} px")

    return master, overrides, hotpath


def frame_for(size, master, overrides):
    if size in overrides:
        return overrides[size]
    return master.resize((size, size), Image.LANCZOS)


def tint(img, rgb):
    """Multiply the RGB channels by a color; alpha is preserved."""
    r, g, b, a = img.split()
    r = r.point(lambda v: v * rgb[0] // 255)
    g = g.point(lambda v: v * rgb[1] // 255)
    b = b.point(lambda v: v * rgb[2] // 255)
    return Image.merge("RGBA", (r, g, b, a))


def write_ico(path, frames):
    """Manual ICO writer: BMP entries for sizes <= 64, PNG for larger."""
    entries = []
    for img in frames:
        w, h = img.size
        if w >= 128:
            buf = io.BytesIO()
            img.save(buf, "PNG")
            data = buf.getvalue()
        else:
            bgra = img.tobytes("raw", "BGRA")
            # rows bottom-up
            stride = w * 4
            pix = b"".join(bgra[(h - 1 - r) * stride:(h - r) * stride] for r in range(h))
            and_stride = ((w + 31) // 32) * 4
            and_mask = b"\x00" * (and_stride * h)
            header = struct.pack("<IiiHHIIiiII", 40, w, h * 2, 1, 32, 0,
                                 len(pix) + len(and_mask), 0, 0, 0, 0)
            data = header + pix + and_mask
        entries.append((w, h, data))

    out = struct.pack("<HHH", 0, 1, len(entries))
    offset = 6 + 16 * len(entries)
    dir_entries = b""
    blobs = b""
    for w, h, data in entries:
        dir_entries += struct.pack("<BBBBHHII", w % 256, h % 256, 0, 0, 1, 32,
                                   len(data), offset)
        blobs += data
        offset += len(data)
    Path(path).write_bytes(out + dir_entries + blobs)


def generate():
    master, overrides, hotpath = load_sources()
    frames = [frame_for(s, master, overrides) for s in ICON_SIZES]
    for rel in ICO_TARGETS:
        out = REPO_ROOT / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        write_ico(out, frames)
        print(f"OK: wrote {rel} ({', '.join(str(s) for s in ICON_SIZES)} px)")
    write_ico(REPO_ROOT / PORTABLE_ICO, [portable_badge(f.convert("RGBA")) for f in frames])
    print(f"OK: wrote {PORTABLE_ICO} (the portable badge on {', '.join(str(s) for s in ICON_SIZES)} px)")
    logo = REPO_ROOT / LOGO_PNG
    logo.write_bytes(ABOUT.read_bytes())
    print(f"OK: wrote {LOGO_PNG} (copy of {ABOUT.name})")
    for (name, rgb), rel in zip(HOTPATH_TINTS, HOTPATH_TARGETS):
        colored = tint(hotpath, rgb)
        frames = [colored.resize((s, s), Image.LANCZOS) for s in HOTPATH_SIZES]
        write_ico(REPO_ROOT / rel, frames)
        print(f"OK: wrote {rel} ({name}; "
              f"{', '.join(str(s) for s in HOTPATH_SIZES)} px)")


def check_ico(rel, sizes):
    """Structural check of one shipped ICO; returns a list of problems."""
    path = REPO_ROOT / rel
    problems = []
    try:
        data = path.read_bytes()
        count = struct.unpack("<H", data[4:6])[0]
        if count != len(sizes):
            problems.append(f"{count} entries, expected {len(sizes)}")
        for i, size in enumerate(sizes[:count]):
            off = 6 + 16 * i
            w, h, _cc, _res, _planes, bpp, length, imgoff = struct.unpack(
                "<BBBBHHII", data[off:off + 16])
            w, h = w or 256, h or 256
            if (w, h) != (size, size):
                problems.append(f"entry {i}: {w}x{h}, expected {size}x{size}")
            if bpp != 32:
                problems.append(f"entry {i}: {bpp} bpp, expected 32")
            payload = data[imgoff:imgoff + length]
            if size >= 128:
                if payload[:8] != PNG_MAGIC:
                    problems.append(f"entry {i}: expected PNG encoding")
            else:
                bi_size, bi_w, bi_h, _p, bi_bpp = struct.unpack(
                    "<IiiHH", payload[:16])
                if (bi_size, bi_w, bi_h, bi_bpp) != (40, size, size * 2, 32):
                    problems.append(f"entry {i}: bad BITMAPINFOHEADER")
    except FileNotFoundError:
        problems.append("missing file")
    except (struct.error, IndexError):
        problems.append("truncated/corrupt ICO")
    return problems


def verify():
    """Structural check of every shipped asset, no writes."""
    failures = 0
    for rel in ICO_TARGETS:
        problems = check_ico(rel, ICON_SIZES)
        status = "OK" if not problems else "FAIL: " + "; ".join(problems)
        print(f"{rel}: {status}")
        failures += bool(problems)

    problems = check_ico(PORTABLE_ICO, ICON_SIZES)
    print(f"{PORTABLE_ICO}: {'OK' if not problems else 'FAIL: ' + '; '.join(problems)}")
    failures += bool(problems)

    for rel in HOTPATH_TARGETS:
        problems = check_ico(rel, HOTPATH_SIZES)
        status = "OK" if not problems else "FAIL: " + "; ".join(problems)
        print(f"{rel}: {status}")
        failures += bool(problems)

    logo = REPO_ROOT / LOGO_PNG
    if not logo.exists():
        print(f"{LOGO_PNG}: FAIL: missing file")
        failures += 1
    elif logo.read_bytes()[:8] != PNG_MAGIC:
        print(f"{LOGO_PNG}: FAIL: not a PNG")
        failures += 1
    else:
        print(f"{LOGO_PNG}: OK")
    return failures == 0


if __name__ == "__main__":
    if "--verify" in sys.argv[1:]:
        sys.exit(0 if verify() else 1)
    generate()
