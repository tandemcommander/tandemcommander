#!/usr/bin/env python3
"""Writes the reproducing inputs of the findings to findings/ and shows what the header and a
strict parser (Python json after a strict UTF-8 decode) say about each.

    python findings.py [bin\\adv_o2_J.exe]
"""
import json
import os
import struct
import subprocess
import sys

import adv

HERE = os.path.dirname(os.path.abspath(__file__))
V = (0, 1, 9)
N, U, F = adv.notes_url(V), adv.inst_url(V), adv.inst_name(V)


def rec(tag="v0.1.9", assets=None, tail=b""):
    if assets is None:
        assets = '[{"name":"%s","state":"uploaded","browser_download_url":"%s"}]' % (F, U)
    return ('{"tag_name":"%s","draft":false,"prerelease":false,"published_at":"2026-10-14T08:00:00Z","html_url":"%s","assets":%s' %
            (tag, N, assets)).encode() + tail + b"}"


CASES = [
    ("F1a-invalid-utf8-ff-in-body.json", rec(tail=b',"body":"\xff"'),
     "C4: a lone 0xFF byte in an ignored string - not UTF-8, RFC 8259 8.1; a strict parser refuses the text"),
    ("F1b-overlong-utf8-in-member-name.json", rec(tail=b',"x\xc0\xaf":1'),
     "C4: an overlong encoding (C0 AF) in a member name"),
    ("F1c-cesu-surrogate-in-body.json", rec(tail=b',"body":"\xed\xa0\x80"'),
     "C4: a UTF-8-encoded surrogate (ED A0 80)"),
    ("F1d-truncated-utf8-before-quote.json", rec(tail=b',"body":"\xe2\x82"'),
     "C4: a truncated multi-byte sequence right before the closing quote"),
    ("F2-leading-zeros-in-tag.json", rec(tag="v00.01.009"),
     "C2/C3 (letter of the contract kept): tag v00.01.009 with the addresses of v0.1.9 is accepted as 0.1.9"),
    ("F3-asset-name-twice-same-value.json", rec(assets='[{"name":"%s","name":"%s","state":"uploaded","browser_download_url":"%s"}]' % (F, F, U)),
     "C4 other direction: valid JSON, any last-wins/first-wins parser sees a correct installer; refused (NoInstaller)"),
    ("control-good.json", rec(), "control: the same record without any trick"),
]


def strict(data):
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as e:
        return "REFUSED (not UTF-8: %s)" % e.reason
    try:
        d = json.loads(text)
    except ValueError as e:
        return "REFUSED (%s)" % e
    return "parsed, tag_name=%r" % d.get("tag_name")


def main():
    exe = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "bin", "adv_o2_J.exe")
    d = os.path.join(HERE, "findings")
    os.makedirs(d, exist_ok=True)
    cases_file = os.path.join(d, "_cases.bin")
    with open(cases_file, "wb") as f:
        for name, data, _ in CASES:
            open(os.path.join(d, name), "wb").write(data)
            f.write(b"R" + struct.pack("<I", len(data)) + data)
    out = os.path.join(d, "_verdicts.txt")
    subprocess.run([exe, "batch", cases_file, out], check=True)
    lines = open(out).read().split("\n")
    for (name, data, what), line in zip(CASES, lines):
        f = line.split(" ")
        got = "ACCEPTED as %s.%s.%s" % (f[4], f[5], f[6]) if f[2] == "1" else "refused (%s)" % adv.ERR[int(f[3])]
        print("%s\n    %s\n    salupdcheck.h : %s (grammar %s)\n    strict parser : %s\n" %
              (name, what, got, "ok" if f[1] == "1" else "fails", strict(data)))
    os.remove(cases_file)
    os.remove(out)


if __name__ == "__main__":
    main()
