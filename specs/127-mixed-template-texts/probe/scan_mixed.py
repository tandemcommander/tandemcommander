#!/usr/bin/env python3
"""Feature 127 (GitHub issue #7): an INVENTORY of every place where a code-page
template (LoadStr) is composed with an argument that may be UTF-8 - wider than
the rule `mixed-composition` of tools/check_encoding.py, which only reports a
composition whose sink (a message box, the Find log) is within 14 lines.

Every printf-family call whose text contains `LoadStr(` (not LoadStrU8/LoadStrW)
is listed with the classes of its other arguments:

    NAME   an identifier that looks like a file / path / name / mask / archive
    ERR    GetErrorText(...)      (UTF-8 since feature 010)
    -      neither (numbers, other LoadStr texts, ...)

    scan_mixed.py                 the core (as check_encoding.py scopes it)
    scan_mixed.py --plugins       src/plugins of the plug-ins enabled in plugins.cfg
    scan_mixed.py --all           both

The list is for a person (or an agent) to triage: the sink decides whether a
row is a defect. Exit code 0; the count is printed.
"""
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parents[3]
SRC = REPO / "src"
EXCLUDED = ("plugins/", "saltests/", "tserver/", "shellext/", "setup/", "salopen/", "translator/", "reglib/", "common/dep/")
PRINTF = re.compile(r'\b(?:v?sprintf|sprintf_s|_snprintf|_snprintf_s|_vsnprintf_s|wsprintf|SalPrintf|Printf)\s*\(')
LOADSTR = re.compile(r'(?<![A-Za-z0-9_])LoadStr\s*\(')
NAME = re.compile(r'[A-Za-z_]*(?:[Nn]ame|[Pp]ath|[Ff]ile|[Dd]ir|[Mm]ask|[Aa]rchive)[A-Za-z_]*')
ERR = re.compile(r'\bGetErrorText\s*\(')


def enabled_plugins():
    out = []
    for line in (REPO / "plugins.cfg").read_text(encoding="utf-8").splitlines():
        line = line.split("#")[0].strip()
        if "=" in line:
            k, v = line.split("=", 1)
            if v.strip().lower() == "on":
                out.append(k.strip().lower())
    return out


def statement(lines, i):
    """the text of the call starting on line i, up to the closing parenthesis"""
    text = ""
    depth = 0
    started = False
    for j in range(i, min(i + 12, len(lines))):
        for ch in lines[j]:
            if ch == "(":
                depth += 1
                started = True
            elif ch == ")":
                depth -= 1
            text += ch
            if started and depth == 0:
                return text
        text += " "
    return text


def strip_strings(s):
    return re.sub(r'"(?:[^"\\]|\\.)*"', '""', s)


def scan(files, relroot):
    rows = []
    for path in files:
        try:
            lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            continue
        for i, ln in enumerate(lines):
            if ln.lstrip().startswith("//") or not PRINTF.search(ln):
                continue
            st = statement(lines, i)
            if not LOADSTR.search(st):
                continue
            bare = strip_strings(st)
            # arguments after the (first) LoadStr(...) call
            m = LOADSTR.search(bare)
            rest = bare[m.end():]
            rest = rest[rest.find(")") + 1:] if ")" in rest else ""
            rest = re.sub(r'LoadStr(?:U8|W)?\s*\([^)]*\)', '', rest)
            kinds = []
            if ERR.search(rest):
                kinds.append("ERR")
            if NAME.search(ERR.sub("", rest)):
                kinds.append("NAME")
            rows.append((str(path.relative_to(relroot)).replace("\\", "/"), i + 1, "+".join(kinds) or "-", " ".join(st.split())[:150]))
    return rows


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "--core"
    files = []
    if mode in ("--core", "--all"):
        for p in sorted(SRC.rglob("*.cpp")):
            rel = str(p.relative_to(SRC)).replace("\\", "/")
            if not rel.startswith(EXCLUDED):
                files.append(p)
    if mode in ("--plugins", "--all"):
        for name in enabled_plugins():
            d = SRC / "plugins" / name
            files += [p for p in sorted(d.rglob("*.cpp")) if "/7za/" not in str(p).replace("\\", "/")]
        files += sorted((SRC / "plugins" / "shared").glob("*.cpp"))
    rows = scan(files, SRC)
    for r in rows:
        if r[2] != "-":
            print("%-34s %5d  %-8s %s" % r)
    n = len([r for r in rows if r[2] != "-"])
    print("compositions with a LoadStr() template: %d; with a NAME or ERR argument: %d" % (len(rows), n))
    return 0


if __name__ == "__main__":
    sys.exit(main())
