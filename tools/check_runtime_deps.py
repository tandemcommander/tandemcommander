#!/usr/bin/env python3
"""Verify that the Visual C++ runtime a release tree needs is shipped in it.

Feature 077 (specs/077-fix-antivirus-findings/contracts/runtime-deployment.md
section 2).  Walks a build output tree, parses the import and delay-load
import directories of every PE file (*.exe, *.dll, *.spl, *.slg; paths under
an "Intermediate" directory are skipped) and reports every imported DLL whose
name matches the runtime-name pattern but is not present in the ROOT of the
tree, where the loader looks first for an application-local runtime.

Usage:
    python tools\\check_runtime_deps.py <tree> [--pattern <regex>] [--list]

Exit codes:
    0  closure holds (every runtime import resolves inside the tree root)
    1  at least one runtime import is not shipped (one line per violation)
    2  bad arguments, tree missing, or no PE file found

Standard library only.  Output is ASCII.
"""

import argparse
import os
import re
import struct
import sys

# Keep in sync with data-model.md section 1 and tools/codesign/sign_release.ps1
# ($RuntimeNamePattern): the file classes that make up the Visual C++ runtime.
DEFAULT_PATTERN = (
    r"^(vcruntime140|vcruntime140_1|vcruntime140_threads|msvcp140(_[a-z0-9_]+)?|"
    r"concrt140|vccorlib140|vcamp140|vcomp140|mfc140[a-z]*|mfcm140[a-z]*)\.dll$"
)
PE_EXTENSIONS = (".exe", ".dll", ".spl", ".slg")

IMAGE_DIRECTORY_ENTRY_IMPORT = 1
IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT = 13


class NotPE(Exception):
    pass


def _read_cstring(data, offset, limit=260):
    end = data.find(b"\0", offset, offset + limit)
    if end < 0:
        end = min(len(data), offset + limit)
    return data[offset:end].decode("ascii", "replace")


def pe_imports(path):
    """Return the set of DLL names (lower-case) imported by a PE file,
    from both the import directory and the delay-load directory."""
    with open(path, "rb") as f:
        data = f.read()
    if len(data) < 64 or data[:2] != b"MZ":
        raise NotPE("no MZ header")
    pe_off = struct.unpack_from("<I", data, 60)[0]
    if pe_off + 24 > len(data) or data[pe_off:pe_off + 4] != b"PE\0\0":
        raise NotPE("no PE signature")
    num_sections = struct.unpack_from("<H", data, pe_off + 6)[0]
    opt_size = struct.unpack_from("<H", data, pe_off + 20)[0]
    opt_off = pe_off + 24
    magic = struct.unpack_from("<H", data, opt_off)[0]
    if magic == 0x10B:      # PE32
        dd_off = opt_off + 96
    elif magic == 0x20B:    # PE32+
        dd_off = opt_off + 112
    else:
        raise NotPE("unknown optional header magic 0x%X" % magic)
    num_dd = struct.unpack_from("<I", data, opt_off + (92 if magic == 0x10B else 108))[0]

    sections = []
    sec_off = opt_off + opt_size
    for i in range(num_sections):
        s = sec_off + i * 40
        vsize, vaddr, rsize, rptr = struct.unpack_from("<IIII", data, s + 8)
        sections.append((vaddr, max(vsize, rsize), rptr))

    def rva_to_off(rva):
        for vaddr, size, rptr in sections:
            if vaddr <= rva < vaddr + size:
                return rptr + (rva - vaddr)
        return None

    names = set()

    def directory(index):
        if index >= num_dd:
            return 0, 0
        return struct.unpack_from("<II", data, dd_off + index * 8)

    # import directory: array of IMAGE_IMPORT_DESCRIPTOR (20 bytes), Name at +12
    rva, size = directory(IMAGE_DIRECTORY_ENTRY_IMPORT)
    if rva and size:
        off = rva_to_off(rva)
        while off is not None and off + 20 <= len(data):
            chars, tds, fwd, name_rva, first_thunk = struct.unpack_from("<IIIII", data, off)
            if chars == 0 and name_rva == 0 and first_thunk == 0:
                break
            name_off = rva_to_off(name_rva)
            if name_off is not None:
                names.add(_read_cstring(data, name_off).lower())
            off += 20

    # delay-load directory: array of IMAGE_DELAYLOAD_DESCRIPTOR (32 bytes), DllNameRVA at +4
    rva, size = directory(IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT)
    if rva and size:
        off = rva_to_off(rva)
        while off is not None and off + 32 <= len(data):
            attrs, name_rva = struct.unpack_from("<II", data, off)
            if name_rva == 0:
                break
            name_off = rva_to_off(name_rva)
            if name_off is not None:
                names.add(_read_cstring(data, name_off).lower())
            off += 32

    return names


def main(argv=None):
    ap = argparse.ArgumentParser(description="Visual C++ runtime import closure check")
    ap.add_argument("tree", help="build output tree (root of the shipped layout)")
    ap.add_argument("--pattern", default=DEFAULT_PATTERN, help="runtime-name regex (case-insensitive)")
    ap.add_argument("--list", action="store_true", help="print every module with its runtime imports")
    args = ap.parse_args(argv)

    tree = os.path.abspath(args.tree)
    if not os.path.isdir(tree):
        print("ERROR: tree not found: %s" % tree)
        return 2
    try:
        pattern = re.compile(args.pattern, re.IGNORECASE)
    except re.error as e:
        print("ERROR: bad --pattern: %s" % e)
        return 2

    shipped = {n.lower() for n in os.listdir(tree) if os.path.isfile(os.path.join(tree, n))}
    scanned = 0
    runtime_imports = 0
    violations = []
    used_names = set()
    modules = []
    for dirpath, dirnames, filenames in os.walk(tree):
        if os.sep + "Intermediate" + os.sep in (dirpath + os.sep):
            continue
        for fn in sorted(filenames):
            if not fn.lower().endswith(PE_EXTENSIONS):
                continue
            full = os.path.join(dirpath, fn)
            rel = os.path.relpath(full, tree)
            try:
                imports = pe_imports(full)
            except NotPE as e:
                print("note: skipped (not a PE file): %s (%s)" % (rel, e))
                continue
            except OSError as e:
                print("ERROR: cannot read %s: %s" % (rel, e))
                return 2
            scanned += 1
            rt = sorted(n for n in imports if pattern.match(n))
            modules.append((rel, rt))
            for n in rt:
                runtime_imports += 1
                used_names.add(n)
                if n not in shipped:
                    violations.append((rel, n))

    if scanned == 0:
        print("ERROR: no PE file found under %s" % tree)
        return 2

    if args.list:
        for rel, rt in modules:
            print("  %-40s %s" % (rel, ", ".join(rt) if rt else "-"))

    if violations:
        for rel, n in violations:
            print("%s needs %s (not shipped)" % (rel, n))
        print("runtime closure FAILED: %d unsatisfied import(s) in %d module(s) scanned" % (len(violations), scanned))
        return 1

    print("runtime closure OK: %d module(s) scanned, %d runtime import(s), shipped: %s"
          % (scanned, runtime_imports, ", ".join(sorted(used_names)) if used_names else "(none needed)"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
