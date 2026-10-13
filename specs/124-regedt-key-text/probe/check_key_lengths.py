#!/usr/bin/env python3
"""Feature 124: every translation of the Registry Editor's "KEY" (id 1007 in
translations/<lang>/regedt.slt) fits whole into the plug-in's buffers.

KeyTextW holds 32 UTF-16 units (31 + terminator), KeyText 100 bytes of UTF-8.
A text that does not fit is replaced by the English word, never cut - this
check makes sure no existing translation is replaced.

Prints a table (pure ASCII, non-ASCII letters escaped); exit code = violations.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[3]
MAX_W = 31
MAX_U8 = 99
OLD_BYTES = 9  # char KeyText[10] before the feature

bad = 0
rows = []
for slt in sorted((ROOT / "translations").glob("*/regedt.slt")):
    text = slt.read_text(encoding="utf-8-sig")
    m = re.search(r'^1007,\d+,"(.*)"\s*$', text, re.M)
    if not m:
        rows.append((slt.parent.name, "<id 1007 missing>", 0, 0, "FAIL"))
        bad += 1
        continue
    word = m.group(1)
    w = len(word.encode("utf-16-le")) // 2
    u8 = len(word.encode("utf-8"))
    ok = 0 < w <= MAX_W and u8 <= MAX_U8
    if not ok:
        bad += 1
    note = "ok" if ok else "FAIL"
    if u8 > OLD_BYTES:
        note += " (was cut by the old 10-byte buffer in UTF-8)"
    rows.append((slt.parent.name, word.encode("ascii", "backslashreplace").decode(), w, u8, note))

print("%-20s %-45s %5s %5s  %s" % ("language", "id 1007", "UTF16", "UTF8", "verdict"))
for r in rows:
    print("%-20s %-45s %5d %5d  %s" % r)
print("languages: %d, violations: %d (limits: %d UTF-16 units, %d UTF-8 bytes)" % (len(rows), bad, MAX_W, MAX_U8))
sys.exit(bad)
