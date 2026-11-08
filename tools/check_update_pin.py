"""Feature 420: the program pins the signer of the installers it downloads and runs.

The pin SALUPD_SIGNER_THUMBPRINT in src/common/salupdinstall.h must equal the
'thumbprint' of tools/codesign/codesign.cfg - the certificate the releases are
signed with. A rotated certificate without a moved pin would make every
automatic update refuse the new installer (the program then offers the browser
download), so build.cmd runs this check on every build.

Usage: python tools/check_update_pin.py [--help]
Exit code 0 when they are equal, 1 when they differ or cannot be read.
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
    pin = None
    with open(header, encoding="utf-8-sig") as f:
        m = re.search(r'#define\s+SALUPD_SIGNER_THUMBPRINT\s+"([0-9A-Fa-f]{40})"', f.read())
        if m:
            pin = m.group(1).lower()
    if thumb is None or pin is None:
        print("check_update_pin: FAILED - could not read the thumbprint (%s) or the pin (%s)" % (cfg, header))
        return 1
    if thumb != pin:
        print("check_update_pin: FAILED - SALUPD_SIGNER_THUMBPRINT %s != codesign.cfg thumbprint %s" % (pin, thumb))
        print("Move the pin in src/common/salupdinstall.h together with the certificate (feature 420).")
        return 1
    print("check_update_pin: OK (%s)" % pin)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
