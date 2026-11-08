"""Feature 420: the program pins the signers of the installers it downloads and runs.

The list SalUpdSignerThumbprints in src/common/salupdinstall.h must contain the
'thumbprint' of tools/codesign/codesign.cfg - the certificate the releases are
signed with. A certificate that is not in the list would make every automatic
update refuse the new installer (the program then offers the browser download),
so build.cmd runs this check on every build. Around a certificate renewal the
list holds the old and the new thumbprint (architecture/12-project-reference.md,
"Automatic update").

Usage: python tools/check_update_pin.py [--help]
Exit code 0 when the signing thumbprint is pinned, 1 when it is not or cannot be read.
"""

import os
import re
import sys


def main(argv):
    if len(argv) > 1 and argv[1] in ("--help", "-h", "/?"):
        print(__doc__.strip())
        return 0
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    cfg = os.path.join(root, "tools", "codesign", "codesign.cfg")
    header = os.path.join(root, "src", "common", "salupdinstall.h")
    thumb = None
    with open(cfg, encoding="utf-8-sig") as f:
        for line in f:
            m = re.match(r"^\s*thumbprint\s*=\s*([0-9A-Fa-f]{40})\s*$", line)
            if m:
                thumb = m.group(1).lower()
    pins = []
    with open(header, encoding="utf-8-sig") as f:
        m = re.search(r"SalUpdSignerThumbprints\[\]\s*=\s*\{(.*?)\};", f.read(), re.S)
        if m:
            pins = [p.lower() for p in re.findall(r'"([0-9A-Fa-f]{40})"', m.group(1))]
    if thumb is None or not pins:
        print("check_update_pin: FAILED - could not read the thumbprint (%s) or the pins (%s)" % (cfg, header))
        return 1
    if thumb not in pins:
        print("check_update_pin: FAILED - codesign.cfg thumbprint %s is not in SalUpdSignerThumbprints %s" % (thumb, pins))
        print("Add it to the list in src/common/salupdinstall.h (feature 420).")
        return 1
    print("check_update_pin: OK (%s of %d pinned)" % (thumb, len(pins)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
