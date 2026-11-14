r"""Feature 428: the release files of `build.cmd dist` - summary and clean-up after a failure.

Usage:
  python tools/portable/dist_summary.py --start
      record the start of a dist run (build\dist-start.txt, UTC seconds); exit 1 when the version
      is already released (its tag exists) - dist must not overwrite the published files
  python tools/portable/dist_summary.py
      print "DIST OK" with the installer and the portable ZIP of the version in setup\output\
      (size and SHA-256); exit 1 when one of them is missing
  python tools/portable/dist_summary.py --remove-partial setup|portable
      after a failed step: delete that step's release file of this version (and a .part) - but
      ONLY when it was written during this dist run (setup\output\ also keeps the published
      installers; an older file of the same name is never touched)
  python tools/portable/dist_summary.py --built-before-failure
      list the release files of this version written during this dist run
  python tools/portable/dist_summary.py --help

The version is VERSINFO_SALAMANDER_MAJOR.MINORA.MINORB of src\plugins\shared\spl_vers.h, the
build number VERSINFO_BUILDNUMBER - the sources the installer's and the ZIP's names come from.
"""

import hashlib
import os
import re
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUTPUT = os.path.join(ROOT, "setup", "output")
SPL_VERS = os.path.join(ROOT, "src", "plugins", "shared", "spl_vers.h")


def rel(path):
    """The path relative to the repository for messages; the absolute path on another drive."""
    try:
        return os.path.relpath(path, ROOT)
    except ValueError:
        return path


def build_dir():
    d = os.environ.get("OPENSAL_BUILD_DIR") or os.path.join(ROOT, "build") + os.sep
    return d


def start_file():
    return os.path.join(build_dir(), "dist-start.txt")


def read_version():
    with open(SPL_VERS, encoding="utf-8-sig", errors="replace") as f:
        text = f.read()

    def macro(name):
        m = re.search(r"^\s*#define\s+" + name + r"\s+(\d+)\s*$", text, re.M)
        if not m:
            raise SystemExit("dist_summary: %s not found in %s" % (name, SPL_VERS))
        return int(m.group(1))

    ver = "%d.%d.%d" % (macro("VERSINFO_SALAMANDER_MAJOR"), macro("VERSINFO_SALAMANDER_MINORA"),
                        macro("VERSINFO_SALAMANDER_MINORB"))
    return ver, macro("VERSINFO_BUILDNUMBER")


def release_files(ver):
    return {
        "setup": os.path.join(OUTPUT, "tandemcommander-%s-x64-setup.exe" % ver),
        "portable": os.path.join(OUTPUT, "tandemcommander-%s-x64-portable.zip" % ver),
    }


def released(ver):
    """TRUE when the tag v<ver> exists (the version is published and setup\\output keeps its files),
    FALSE when it does not, None when git cannot tell - the caller then refuses (fail closed)."""
    import subprocess
    try:
        r = subprocess.run(["git", "-C", ROOT, "tag", "--list", "v" + ver], capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.SubprocessError):
        return None
    if r.returncode != 0:
        return None
    return r.stdout.strip() == "v" + ver


def build_dir_is_default():
    """TRUE when the build folder is <repository>\build - the tree the installer script packs."""
    own = os.path.normcase(os.path.abspath(os.path.join(ROOT, "build")))
    return os.path.normcase(os.path.abspath(build_dir())) == own


def certificate_present():
    """TRUE when the certificate named in tools\\codesign\\codesign.cfg is in the user's or the
    machine's certificate store (the same stores sign_release.ps1 searches)."""
    import subprocess
    cfg = os.path.join(ROOT, "tools", "codesign", "codesign.cfg")
    thumb = None
    try:
        for line in open(cfg, encoding="utf-8-sig", errors="replace"):
            m = re.match(r"\s*thumbprint\s*=\s*([0-9A-Fa-f]{40})\s*$", line)
            if m:
                thumb = m.group(1).upper()
    except OSError:
        return False
    if thumb is None:
        return False
    ps = ("$t='%s'; $hit=@(); foreach ($s in 'Cert:\\CurrentUser\\My','Cert:\\LocalMachine\\My') "
          "{ try { $hit += @(Get-ChildItem -Path $s -ErrorAction Stop | Where-Object { $_.Thumbprint -eq $t }) } catch {} }; "
          "if ($hit.Count) { exit 0 } else { exit 1 }" % thumb)
    try:
        return subprocess.run(["powershell", "-NoProfile", "-NonInteractive", "-Command", ps],
                              capture_output=True, timeout=120).returncode == 0
    except (OSError, subprocess.SubprocessError):
        return False


def run_start():
    try:
        with open(start_file(), encoding="ascii") as f:
            return float(f.read().strip())
    except (OSError, ValueError):
        return None


def written_this_run(path, start):
    return start is not None and os.path.isfile(path) and os.path.getmtime(path) >= start - 2


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main(argv):
    if len(argv) > 1 and argv[1] in ("--help", "-h", "/?"):
        print(__doc__.strip())
        return 0
    if len(argv) > 1 and argv[1] == "--start":
        ver, _ = read_version()
        state = released(ver)
        if state is None:
            print("ERROR: git cannot tell whether version %s is released (its tag) - 'dist' does not guess." % ver)
            return 1
        if state:
            # the published installer and ZIP of that version are archived in setup\output (winget
            # pins the installer's hash): a dist of an unbumped tree would overwrite them
            print("ERROR: version %s is already released (tag v%s) - run /tandem-release <x.y.z> first;" % (ver, ver))
            print("       'dist' would overwrite the published files in setup\\output.")
            return 1
        # the installer packs ..\\build\\tandemcommander\\Release_x64 whatever OPENSAL_BUILD_DIR says
        # (setup\\tandemcommander.iss): another build folder would sign one tree and pack another
        own = os.path.join(ROOT, "build")
        if not build_dir_is_default():
            print("ERROR: 'dist' needs the default build folder %s (the installer packs that tree);" % own)
            print("       OPENSAL_BUILD_DIR is %s." % build_dir())
            return 1
        if not certificate_present():
            print("ERROR: the certificate of tools\\codesign\\codesign.cfg is not in Cert:\\CurrentUser\\My or")
            print("       Cert:\\LocalMachine\\My (connect the signing token first) - nothing was built.")
            return 1
        # earlier, unreleased files of this version (an earlier dist of the same day) are set aside:
        # a failed run must not leave a complete-looking file of another build behind
        stamp = time.strftime("%Y%m%d-%H%M%S")
        for p in release_files(ver).values():
            for q in (p, p + ".part"):
                if os.path.isfile(q):
                    aside = q + ".before-dist-" + stamp
                    os.replace(q, aside)
                    print("  set aside an earlier build: %s" % os.path.basename(aside))
        os.makedirs(build_dir(), exist_ok=True)
        with open(start_file(), "w", encoding="ascii") as f:
            f.write("%.3f\n" % time.time())
        return 0
    ver, build = read_version()
    files = release_files(ver)
    start = run_start()
    if len(argv) > 2 and argv[1] == "--remove-partial":
        step = argv[2]
        if step not in files:
            print("dist_summary: unknown step '%s'" % step)
            return 2
        for p in (files[step], files[step] + ".part"):
            if written_this_run(p, start):
                os.remove(p)
                print("  removed the unfinished %s" % rel(p))
        return 0
    if len(argv) > 1 and argv[1] == "--built-before-failure":
        for step in ("setup", "portable"):
            p = files[step]
            if written_this_run(p, start):
                print("  built before the failure: %s  %d bytes  SHA-256 %s"
                      % (os.path.basename(p), os.path.getsize(p), sha256(p)))
        return 0
    missing = [p for p in files.values() if not os.path.isfile(p)]
    stale = [p for p in files.values() if os.path.isfile(p) and start is not None and not written_this_run(p, start)]
    if missing or stale:
        for p in missing:
            print("DIST FAILED: missing %s" % rel(p))
        for p in stale:
            print("DIST FAILED: %s was not written by this run" % rel(p))
        return 1
    print("")
    print("============================================================")
    print("DIST OK  Tandem Commander %s (build %d)" % (ver, build))
    for step in ("setup", "portable"):
        p = files[step]
        print("  %-40s %10d bytes  SHA-256 %s" % (os.path.basename(p), os.path.getsize(p), sha256(p)))
    print("============================================================")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
