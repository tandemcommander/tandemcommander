"""Feature 086 probe: list the AES salts and ZIP 2.0 encryption headers of the
encrypted entries in one or more ZIP archives, and report any that repeat.

    python zip_salts.py a1.zip a2.zip ...     list + "repeats: N" (exit 1 if N > 0)
    python zip_salts.py --selftest            prove the parser on archives made by
                                              7-Zip (AES-256 and ZipCrypto)

What is read (APPNOTE 4.3.6 / WinZip AE-1/AE-2):
  * an entry is encrypted when bit 0 of its general-purpose flag is set;
  * AES (compression method 99, extra field 0x9901 with strength 1/2/3): the
    first 8/12/16 bytes of the file data are the salt;
  * otherwise (ZIP 2.0 "ZipCrypto"): the first 12 bytes are the encryption
    header (stored encrypted; two equal headers mean equal random input under
    the same password).
The local header is read at the offset the central directory gives, because a
data descriptor may hide the sizes in the local header.
"""

import os
import shutil
import struct
import subprocess
import sys
import tempfile
import zipfile

SEVEN_ZIP = r"C:\Program Files\7-Zip\7z.exe"


def entries(path):
    """yield (archive, name, kind, hex) for every encrypted entry"""
    with zipfile.ZipFile(path) as z, open(path, "rb") as f:
        for info in z.infolist():
            if not info.flag_bits & 1:
                continue
            f.seek(info.header_offset)
            hdr = f.read(30)
            if hdr[:4] != b"PK\x03\x04":
                raise ValueError("%s: bad local header for %s" % (path, info.filename))
            method = struct.unpack("<H", hdr[8:10])[0]
            name_len, extra_len = struct.unpack("<HH", hdr[26:30])
            f.seek(name_len, 1)
            extra = f.read(extra_len)
            data_start = info.header_offset + 30 + name_len + extra_len
            kind, size = "zipcrypto", 12
            if method == 99:
                strength = None
                i = 0
                while i + 4 <= len(extra):
                    hid, hlen = struct.unpack("<HH", extra[i:i + 4])
                    if hid == 0x9901 and hlen >= 7 and i + 4 + 7 <= len(extra):
                        strength = extra[i + 4 + 4]
                    i += 4 + hlen
                if strength not in (1, 2, 3):
                    raise ValueError("%s: AES entry %s without a valid 0x9901 field" % (path, info.filename))
                kind, size = "aes%d" % (64 + 64 * strength), 4 + 4 * strength
            f.seek(data_start)
            yield path, info.filename, kind, f.read(size).hex()


def report(paths):
    seen = {}
    repeats = 0
    for p in paths:
        for arch, name, kind, value in entries(p):
            # a ZipCrypto header byte depends only on the password and the bytes
            # before it, and the last 1-2 bytes are the time check: compare the
            # 10-byte random prefix (same password assumed, quickstart step 3)
            key = (kind, value[:20] if kind == "zipcrypto" else value)
            dup = key in seen
            repeats += dup
            print("%-10s %s  %s :: %s%s" % (kind, value, os.path.basename(arch), name,
                                            "   <-- REPEAT of " + seen[key] if dup else ""))
            seen.setdefault(key, "%s :: %s" % (os.path.basename(arch), name))
    print("entries: %d, repeats: %d" % (len(seen) + repeats, repeats))
    return repeats


def selftest():
    if not os.path.exists(SEVEN_ZIP):
        print("selftest: SKIP (7-Zip not found at %s)" % SEVEN_ZIP)
        return 0
    tmp = tempfile.mkdtemp(prefix="zip086_")
    try:
        src = os.path.join(tmp, "data.txt")
        with open(src, "wb") as f:
            f.write(b"feature 086 probe\r\n" * 100)
        made = []
        for name, args in [("aes1.zip", ["-mem=AES256"]), ("aes2.zip", ["-mem=AES256"]),
                           ("aes128.zip", ["-mem=AES128"]), ("zc1.zip", ["-mem=ZipCrypto"]),
                           ("zc2.zip", ["-mem=ZipCrypto"])]:
            out = os.path.join(tmp, name)
            subprocess.run([SEVEN_ZIP, "a", "-tzip", "-pZz086test"] + args + [out, src],
                           check=True, capture_output=True)
            made.append(out)
        rows = [e for p in made for e in entries(p)]
        kinds = sorted(r[2] for r in rows)
        ok = kinds == ["aes128", "aes256", "aes256", "zipcrypto", "zipcrypto"]
        ok = ok and all(len(r[3]) == {"aes128": 16, "aes256": 32, "zipcrypto": 24}[r[2]] for r in rows)
        ok = ok and report(made) == 0  # 7-Zip's salts must not repeat either
        # a repeat must be detected: the same archive twice
        dup = os.path.join(tmp, "aes1_copy.zip")
        shutil.copy(made[0], dup)
        ok = ok and report([made[0], dup]) == 1
        print("selftest: %s" % ("PASS" if ok else "FAIL"))
        return 0 if ok else 1
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main():
    if len(sys.argv) == 2 and sys.argv[1] == "--selftest":
        return selftest()
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    return 1 if report(sys.argv[1:]) else 0


if __name__ == "__main__":
    sys.exit(main())
