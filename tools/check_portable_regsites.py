r"""Feature 428: every use of HKEY_CURRENT_USER in the core is classified.

The portable edition keeps its configuration in a private session hive; code reaches it through
SalCfgBaseKey() (src\consts.h). A configuration site that still names HKEY_CURRENT_USER would
read and write the user's registry in the portable edition - the one thing it promises never to
do - and nothing else would notice until a registry snapshot shows it. So build.cmd runs this
check on every build: each HKEY_CURRENT_USER in the code (comments and string literals do not
count) of the core's sources must carry, on the same line, a marker

    // portable: <why this is not the configuration> (system read, reglib name, ...)

or the site is reported. A new configuration site is written with SalCfgBaseKey() instead.
(HKEY_LOCAL_MACHINE / HKEY_CLASSES_ROOT are not listed here: the core only reads them, and the
registry snapshot probe of the portable edition - specs\428-portable-build\probe - checks writes.)

Usage: python tools/check_portable_regsites.py [--help]
Exit code 0 when every site is classified, 1 when one is not (each is listed).
"""

import os
import re
import sys

SCAN = [
    ("src", (".cpp", ".h")),
    (os.path.join("src", "common"), (".cpp",)),
    (os.path.join("src", "reglib", "src"), (".cpp",)),
]
TOKEN = re.compile(r"\bHKEY_CURRENT_USER\b")


def strip_code(line, in_block):
    """The line without comments and string / character literals; the block-comment state."""
    out = []
    i = 0
    n = len(line)
    while i < n:
        if in_block:
            j = line.find("*/", i)
            if j < 0:
                return "".join(out), True
            i = j + 2
            in_block = False
            continue
        c = line[i]
        if line.startswith("//", i):
            break
        if line.startswith("/*", i):
            in_block = True
            i += 2
            continue
        if c in "\"'":
            q = c
            i += 1
            while i < n and line[i] != q:
                i += 2 if line[i] == "\\" else 1
            i += 1
            out.append(" ")
            continue
        out.append(c)
        i += 1
    return "".join(out), in_block


def main(argv):
    if len(argv) > 1 and argv[1] in ("--help", "-h", "/?"):
        print(__doc__.strip())
        return 0
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    bad = []
    sites = 0
    for folder, exts in SCAN:
        d = os.path.join(root, folder)
        for name in sorted(os.listdir(d)):
            if not name.endswith(exts):
                continue
            path = os.path.join(d, name)
            if not os.path.isfile(path):
                continue
            in_block = False
            with open(path, encoding="utf-8-sig", errors="replace") as f:
                for lineno, line in enumerate(f, 1):
                    code, in_block = strip_code(line.rstrip("\r\n"), in_block)
                    if TOKEN.search(code):
                        sites += 1
                        if "portable:" not in line:
                            bad.append("%s:%d: %s" % (os.path.relpath(path, root), lineno, line.strip()))
    if bad:
        print("check_portable_regsites: FAILED - HKEY_CURRENT_USER without SalCfgBaseKey() or a 'portable:' marker:")
        for b in bad:
            print("  " + b)
        return 1
    print("check_portable_regsites: OK (%d classified sites)" % sites)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
