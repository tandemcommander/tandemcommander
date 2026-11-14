r"""Feature 428: every project writes into the output tree of its edition.

The portable edition (build.cmd ... portable, MSBuild /p:TcEdition=portable) builds the whole
solution into ...\tandemcommander\<Configuration>_<Platform>_portable\ next to the normal tree.
That works only while every project file and property sheet under src\ that spells the output
root - "tandemcommander\$(Configuration)_$(ShortPlatform)" - follows it with $(TcOutSuffix)
(defined in src\Directory.Build.props). A root spelled without the suffix would let a portable
build overwrite the normal tree that the installer packages; nothing else would report it, so
build.cmd runs this check on every build.

Usage: python tools/check_outdir_suffix.py [--help]
Exit code 0 when every spelling carries the suffix, 1 when one does not (each is listed).
"""

import os
import re
import sys

ROOT_SPELLING = re.compile(r"tandemcommander\\\$\(Configuration\)_(?:\$\(ShortPlatform\)|x64|x86|Win32)(?!\$\(TcOutSuffix\))")
# projects that are not in salamand.sln (never built by build.cmd); each needs a reason
NOT_BUILT = {
    os.path.join("src", "plugins", "pictview", "vcxproj", "salpvenv_base.props"):
        "not in salamand.sln (see the KEEP IN SYNC note in src\\Directory.Build.targets)",
}


def main(argv):
    if len(argv) > 1 and argv[1] in ("--help", "-h", "/?"):
        print(__doc__.strip())
        return 0
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    src = os.path.join(root, "src")
    bad = []
    checked = 0
    for dirpath, dirnames, filenames in os.walk(src):
        for name in filenames:
            if not (name.endswith(".props") or name.endswith(".vcxproj") or name.endswith(".targets")):
                continue
            path = os.path.join(dirpath, name)
            rel = os.path.relpath(path, root)
            checked += 1
            with open(path, encoding="utf-8-sig", errors="replace") as f:
                for lineno, line in enumerate(f, 1):
                    if ROOT_SPELLING.search(line) and rel not in NOT_BUILT:
                        bad.append("%s:%d: %s" % (rel, lineno, line.strip()))
    if bad:
        print("check_outdir_suffix: FAILED - output root spelled without $(TcOutSuffix):")
        for b in bad:
            print("  " + b)
        return 1
    print("check_outdir_suffix: OK (%d project files checked)" % checked)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
