"""Feature 111 probe helper: decodes saved images independently of the program (Pillow + the
bytes read by hand) and prints one line of facts per file.

    python pilcheck.py <file> [<file> ...]

Per file: "<name>|mode=..|size=WxH|bits=..|comp=..|t270=<hex>|xmpdesc=<hex of UTF-8>|com=<hex>|
pixels=<sha256 prefix of RGB data>". Missing facts are "-". Pure ASCII output.
"""

import hashlib
import re
import struct
import sys

from PIL import Image


def hx(b):
    return b.hex() if b else "-"


def tiff_facts(data):
    # little-endian classic TIFF only (what the Windows encoder writes)
    if data[:4] != b"II*\x00":
        return {}
    ifd = struct.unpack_from("<I", data, 4)[0]
    n = struct.unpack_from("<H", data, ifd)[0]
    out = {}
    sizes = {1: 1, 2: 1, 3: 2, 4: 4, 5: 8, 7: 1}
    for k in range(n):
        tag, typ, cnt, val = struct.unpack_from("<HHII", data, ifd + 2 + k * 12)
        size = sizes.get(typ, 1) * cnt
        raw = data[ifd + 2 + k * 12 + 8: ifd + 2 + k * 12 + 8 + size] if size <= 4 else data[val: val + size]
        out[tag] = (typ, cnt, raw)
    return out


def jpeg_com(data):
    if data[:2] != b"\xff\xd8":
        return None
    i = 2
    while i + 4 <= len(data) and data[i] == 0xFF:
        m = data[i + 1]
        ln = (data[i + 2] << 8) | data[i + 3]
        if m == 0xFE:
            return data[i + 4: i + 2 + ln]
        if m == 0xDA:
            break
        i += 2 + ln
    return None


def xmp_description(xmp):
    if not xmp:
        return None
    m = re.search(rb"<dc:description>\s*<rdf:Alt[^>]*>\s*<rdf:li[^>]*>(.*?)</rdf:li>", xmp, re.S)
    if not m:
        m = re.search(rb"<dc:description>(.*?)</dc:description>", xmp, re.S)
    return m.group(1) if m else None


def main():
    for path in sys.argv[1:]:
        name = path.replace("\\", "/").split("/")[-1]
        try:
            data = open(path, "rb").read()
            im = Image.open(path)
            im.load()
            facts = {"mode": im.mode, "size": "%dx%d" % im.size, "fmt": im.format}
            t = tiff_facts(data)
            if t:
                facts["comp"] = str(struct.unpack_from("<H", t[259][2])[0]) if 259 in t else "-"
                facts["bits"] = ",".join(str(x) for x in struct.unpack_from("<%dH" % t[258][1], t[258][2])) if 258 in t else "-"
                facts["t270"] = hx(t[270][2]) if 270 in t else "-"
                facts["t270type"] = str(t[270][0]) if 270 in t else "-"
                facts["xmpdesc"] = hx(xmp_description(t[700][2])) if 700 in t else "-"
                # what Pillow itself reports for tag 270 (it decodes ASCII tags as Latin-1)
                pil270 = im.tag_v2.get(270) if hasattr(im, "tag_v2") else None
                facts["pil270"] = pil270.encode("unicode_escape").decode("ascii") if pil270 else "-"
            com = jpeg_com(data)
            if com is not None:
                facts["com"] = hx(com)
            if im.format == "PNG":
                facts["bits"] = str(data[24])
                facts["pngtype"] = str(data[25])
            if im.format == "BMP":
                facts["bits"] = str(struct.unpack_from("<H", data, 28)[0])
            if im.format == "GIF" and "comment" in im.info:
                facts["com"] = hx(im.info["comment"])
            rgb = im.convert("RGB").tobytes()
            facts["pixels"] = hashlib.sha256(rgb).hexdigest()[:16]
            print(name + "|" + "|".join("%s=%s" % (k, v) for k, v in facts.items()))
        except Exception as e:  # noqa: BLE001 - a probe reports, it does not stop
            print(name + "|ERROR=" + str(e).encode("ascii", "replace").decode("ascii"))


if __name__ == "__main__":
    main()
