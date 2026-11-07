#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Pavel Stupka
# SPDX-License-Identifier: GPL-2.0-or-later
"""Feature 416: checks the Fluent 2 icon set (src/res/iconsets/fluent) against the program.

- every name the program asks the set for exists, light and dark: the SVGName column of
  ToolBarButtons[] in src/toolbar4.cpp with the Fluent overrides of src/common/saliconset.h,
  the drive / ".." / Documents / Network names of saliconset.h, the configuration-list toolbar
  names of src/gui.cpp;
- every light file has a dark variant and the other way round; nothing else in the folders;
- no colour the image lists treat as transparent (#FF00FF, #F0F0F0, #2D2D2D);
- the paths parse with the vendored nanosvg (an emulation of its tokenizer: it reads arc flags
  as ordinary numbers, so merged flags such as "011" would be misread);
- the palette of gen_fluent.py: every outline colour >= 3:1 against the toolbar face of its
  theme, and on the menu highlight the outline or the underlay / halo colour >= 3:1;
- the licence text is there.

Usage: python tools/brand/fluent-icons/check_iconset.py [--help]
Exit code: number of problems (0 = all good).
"""
import glob
import importlib.util
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
SET = os.path.join(ROOT, "src", "res", "iconsets", "fluent")


def tokens(d):
    i, n = 0, len(d)
    while i < n:
        c = d[i]
        if c.isspace() or c == ",":
            i += 1
            continue
        if c in "+-." or c.isdigit():
            j = i
            if d[j] in "+-":
                j += 1
            while j < n and d[j].isdigit():
                j += 1
            if j < n and d[j] == ".":
                j += 1
                while j < n and d[j].isdigit():
                    j += 1
            if j < n and d[j] in "eE":
                j += 1
                if j < n and d[j] in "+-":
                    j += 1
                while j < n and d[j].isdigit():
                    j += 1
            yield ("n", d[i:j])
            i = j
        else:
            yield ("c", c)
            i += 1


ARGS = dict(m=2, l=2, h=1, v=1, c=6, s=4, q=4, t=2, a=7, z=0)


def path_problems(d):
    out = []
    cmd, args = None, []
    for kind, v in tokens(d):
        if kind == "c":
            if args:
                out.append("leftover arguments %s before %r" % (args, v))
            if v.lower() not in ARGS:
                out.append("unknown path command %r" % v)
            cmd, args = v, []
            continue
        if cmd is None:
            out.append("number before a command")
            continue
        args.append(v)
        if len(args) == ARGS[cmd.lower()]:
            if cmd.lower() == "a" and (float(args[3]) not in (0, 1) or float(args[4]) not in (0, 1)):
                out.append("arc flags read as %s %s" % (args[3], args[4]))
            args = []
    if args:
        out.append("leftover arguments %s" % args)
    return out


def lum(hexcol):
    v = []
    for k in (0, 2, 4):
        s = int(hexcol[1 + k:3 + k], 16) / 255.0
        v.append(s / 12.92 if s <= 0.03928 else ((s + 0.055) / 1.055) ** 2.4)
    return 0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2]


def contrast(a, b):
    la, lb = lum(a) + 0.05, lum(b) + 0.05
    return la / lb if la > lb else lb / la


def program_names():
    names = set()
    tb = open(os.path.join(ROOT, "src", "toolbar4.cpp"), encoding="utf-8-sig").read()
    table = tb[tb.index("CButtonData ToolBarButtons[TBBE_TERMINATOR]"):tb.index("DWORD TopToolBarButtons[]")]
    rows = re.findall(r"/\*(TBBE_\w+)\*/\s*\{(.*)\},", table)
    classic = {}
    for i, (tbbe, body) in enumerate(rows):
        m = re.search(r',\s*(NULL|"[^"]*")\s*$', body)
        classic[i] = None if m is None or m.group(1) == "NULL" else m.group(1).strip('"')
    hdr = open(os.path.join(ROOT, "src", "common", "saliconset.h"), encoding="utf-8-sig").read()

    def func_body(func):
        s = hdr.index(func)
        return hdr[s:hdr.index("\n}\n", s)]

    buttons = func_body("inline const char* SalIconSetFluentButtonName(")
    overrides = {}
    for num, val in re.findall(r"case (\d+):\s*return ([^;]+);", buttons):
        overrides[int(num)] = None if val.strip() == "0" else val.strip().strip('"')
    # the Change Drive pair shares one return
    for num in re.findall(r"case (\d+): // TBBE_CHANGE_DRIVE_[LR]", buttons):
        overrides[int(num)] = "ChangeDrive"
    shell = {}
    for i, (tbbe, body) in enumerate(rows):
        cols = [c.strip() for c in body.split(",")]
        try:
            shell[i] = int(cols[1])
        except ValueError:
            shell[i] = 0
    with_image = 0
    for i in range(len(rows)):
        name = overrides.get(i, classic[i]) if i in overrides else classic[i]
        image_index = rows[i][1].split(",")[0]
        if "0xFFFF" in image_index:
            continue
        with_image += 1
        if name is None:
            yield ("toolbar button %s has no Fluent 2 name" % rows[i][0], None)
            continue
        names.add(name)
    for n in re.findall(r'"(Drive\w+)"', func_body("inline const char* SalIconSetFluentDriveName(")):
        names.add(n)
    for n in re.findall(r'#define SAL_ICONSET_NAME_(?!PLUGIN)\w+ "(\w+)"', hdr):  # the plug-in defaults live in plugins\
        names.add(n)
    gui = open(os.path.join(ROOT, "src", "gui.cpp"), encoding="utf-8-sig").read()
    block = gui[gui.index("CSVGIcon svgIcons[TLBHDR_COUNT]"):]
    block = block[:block.index("};")]
    names.update(re.findall(r'\{\d+, "(\w+)"\}', block))
    yield ("buttons with an image: %d" % with_image, with_image)
    for n in sorted(names):
        yield (None, n)


def main():
    if len(sys.argv) > 1 and sys.argv[1] in ("-h", "--help"):
        print(__doc__)
        return 0
    problems = []
    light = {os.path.basename(f) for f in glob.glob(os.path.join(SET, "*.svg"))}
    dark = {os.path.basename(f) for f in glob.glob(os.path.join(SET, "dark", "*.svg"))}
    for f in sorted(light ^ dark):
        problems.append("only in one folder: %s" % f)
    used = set()
    count = None
    for msg, val in program_names():
        if msg is None:
            used.add(val + ".svg")
        elif val is None:
            problems.append(msg)
        else:
            count = val
    if count != 85:
        problems.append("toolbar buttons with an image: %s, expected 85" % count)
    for f in sorted(used - light):
        problems.append("the program uses %s, the set has no such file" % f)
    for f in sorted(light - used):
        problems.append("unused file %s" % f)
    for f in sorted(glob.glob(os.path.join(SET, "*.svg")) + glob.glob(os.path.join(SET, "dark", "*.svg"))):
        t = open(f, encoding="utf-8").read()
        rel = os.path.relpath(f, SET)
        for bad in ("#FF00FF", "#F0F0F0", "#2D2D2D"):
            if bad in t.upper():
                problems.append("%s uses %s (transparent in the image lists)" % (rel, bad))
        if re.search(r"<(linearGradient|radialGradient|mask|clipPath|filter|use|image|text|script)\b", t):
            problems.append("%s uses an element nanosvg does not draw" % rel)
        for d in re.findall(r'\sd="([^"]*)"', t):
            for p in path_problems(d):
                problems.append("%s: %s" % (rel, p))
    if not os.path.isfile(os.path.join(SET, "LICENSE-fluent.txt")):
        problems.append("LICENSE-fluent.txt is missing")
    # the palette of the generator
    spec = importlib.util.spec_from_file_location("gen_fluent_palette", os.path.join(os.path.dirname(__file__), "gen_fluent.py"))
    src = open(spec.origin, encoding="utf-8").read()
    pal = eval(src[src.index("PAL = ") + 6:src.index("ROLES = ")], {})
    roles = eval(src[src.index("ROLES = ") + 8:src.index("# Name (SVGName")], {})
    halo = eval(src[src.index("HALO = ") + 7:src.index("\n", src.index("HALO = "))], {})
    face = {"light": "#F0F0F0", "dark": "#2D2D2D"}
    highlight = {"light": "#0078D7", "dark": "#264F78"}
    for theme in ("light", "dark"):
        P = pal[theme]
        for role, (tint, outline) in roles.items():
            c = contrast(P[outline], face[theme])
            if c < 3.0:
                problems.append("%s %s outline %s: %.2f:1 on the toolbar" % (theme, role, P[outline], c))
            under = [P[tint]] if tint else [P["paper"], halo[theme]]
            best = max([contrast(P[outline], highlight[theme])] + [contrast(u, highlight[theme]) for u in under])
            if best < 3.0:
                problems.append("%s %s: neither outline nor underlay / halo reaches 3:1 on the menu highlight (%.2f)" % (theme, role, best))
    nplug = plugin_problems(problems, face, highlight)
    for p in problems:
        print("PROBLEM:", p)
    print("check_iconset: %d light + %d dark files, %d names used by the program, %d plug-in icons, %d problem(s)" %
          (len(light), len(dark), len(used), nplug, len(problems)))
    return len(problems)


def plugin_problems(problems, face, highlight):
    """Feature 417: iconsets\\fluent\\plugins\\ and \\dark\\ hold exactly the ids of SalIconSetPluginIdAt and the two
    defaults, with the file rules above, and the plug-in generator's palette passes the same contrast rule."""
    hdr = open(os.path.join(ROOT, "src", "common", "saliconset.h"), encoding="utf-8-sig").read()
    s = hdr.index("inline const char* SalIconSetPluginIdAt(")
    table = hdr[s:hdr.index("};", s)]
    ids = re.findall(r'"(\w+)"', table)
    count = int(re.search(r"#define SAL_ICONSET_PLUGIN_ID_COUNT (\d+)", hdr).group(1))
    if len(ids) != count:
        problems.append("SalIconSetPluginIdAt lists %d ids, SAL_ICONSET_PLUGIN_ID_COUNT is %d" % (len(ids), count))
    expected = set(i + ".svg" for i in ids)
    expected.update(n + ".svg" for n in re.findall(r'#define SAL_ICONSET_NAME_PLUGIN\w* "(\w+)"', hdr))
    if len(expected) != count + 2:
        problems.append("expected %d plug-in names, found %d" % (count + 2, len(expected)))
    folder = os.path.join(SET, "plugins")
    for sub in ("", "dark"):
        have = {os.path.basename(f) for f in glob.glob(os.path.join(folder, sub, "*.svg"))}
        rel = "plugins\\" + (sub + "\\" if sub else "")
        for f in sorted(expected - have):
            problems.append("%s%s is missing" % (rel, f))
        for f in sorted(have - expected):
            problems.append("%s%s is not a plug-in id of saliconset.h" % (rel, f))
        others = [os.path.basename(f) for f in glob.glob(os.path.join(folder, sub, "*")) if not f.endswith(".svg") and os.path.isfile(f)]
        for f in others:
            problems.append("%s%s: not an icon" % (rel, f))
        for f in sorted(have):
            t = open(os.path.join(folder, sub, f), encoding="utf-8").read()
            for bad in ("#FF00FF", "#F0F0F0", "#2D2D2D"):
                if bad in t.upper():
                    problems.append("%s%s uses %s (transparent in the image lists)" % (rel, f, bad))
            if re.search(r"<(linearGradient|radialGradient|mask|clipPath|filter|use|image|text|script)\b", t):
                problems.append("%s%s uses an element nanosvg does not draw" % (rel, f))
            for d in re.findall(r'\sd="([^"]*)"', t):
                for p in path_problems(d):
                    problems.append("%s%s: %s" % (rel, f, p))
    src = open(os.path.join(os.path.dirname(__file__), "gen_fluent_plugins.py"), encoding="utf-8").read()
    pal = eval(src[src.index("PAL = {") + 6:src.index("ROLES = ")], {})
    roles = eval(src[src.index("ROLES = {") + 8:src.index("NO_PAPER = ")], {})
    halo = eval(src[src.index("HALO = ") + 7:src.index("\n", src.index("HALO = "))], {})
    for theme in ("light", "dark"):
        P = pal[theme]
        for role, (tint, outline) in roles.items():
            c = contrast(P[outline], face[theme])
            if c < 3.0:
                problems.append("plug-ins: %s %s outline %s: %.2f:1 on the toolbar" % (theme, role, P[outline], c))
            under = [P[tint]] if tint else [P["paper"], halo[theme]]
            best = max([contrast(P[outline], highlight[theme])] + [contrast(u, highlight[theme]) for u in under])
            if best < 3.0:
                problems.append("plug-ins: %s %s: neither outline nor underlay / halo reaches 3:1 on the menu highlight (%.2f)" % (theme, role, best))
    return len(expected)


if __name__ == "__main__":
    sys.exit(main())
