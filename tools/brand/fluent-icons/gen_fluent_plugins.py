# Tandem Commander plug-in icons of the "Fluent 2" icon set (feature 417) - built on Microsoft Fluent UI System
# Icons (MIT), in the language of the toolbar set made by gen_fluent.py: a 16 px regular glyph, a colour role by
# meaning, a paper underlay or a halo, a hand-made dark variant. Badges are composed the way Fluent composes them:
# a cut-out plate in the bottom-right corner with a small glyph (the technique of the toolbar's Network icon).
# Two own drawings: the 7-Zip "7" tile and the RegEdit block of cubes. The mapping, palettes and drawings are
# those of the maintainer's design study of 2026-11-07 (the RegEdit icon approved after three rounds).
# Writes <out>/plugins/<id>.svg and <out>/plugins/dark/<id>.svg for the 31 plug-in ids of
# src/common/saliconset.h (SalIconSetPluginId) and the defaults _plugin (a plug-in without an icon) and
# _pluginfs (a file system without an icon). Contract: specs/417-fluent-plugin-icons/contracts/plugin-icon-files.md.
# Usage: python gen_fluent_plugins.py <unpacked @fluentui/svg-icons 1.1.344 folder (holds package/)> [<out>]
import os, re, sys

if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help"):
    print("usage: python gen_fluent_plugins.py <fluent-package-folder> [<out-folder>]\n"
          "  <fluent-package-folder>: the unpacked npm tarball of @fluentui/svg-icons 1.1.344 (package/icons/...),\n"
          "                           the same package as gen_fluent.py (see README.md)\n"
          "  <out-folder>: default src/res/iconsets/fluent of this repository (the files go to plugins\\ and plugins\\dark\\)")
    sys.exit(0)
PKG = sys.argv[1]
SRC = os.path.join(PKG, "package", "icons")
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "src", "res", "iconsets", "fluent")

PAL = {  # = gen_fluent.py, plus greenFill (the "recover / verified" tint) and onAccent (a glyph cut into a badge)
    "light": dict(ink="#242424", blue="#0F6CBD", red="#C50F1F", green="#107C10",
                  folderFill="#FFCF5C", folderStroke="#A86F00", paper="#FFFFFF", archFill="#E3D5FA", archStroke="#7A3FC8",
                  blueFill="#CFE4FA", driveFill="#E2E2E2", greenFill="#DFF6DD", onAccent="#FFFFFF"),
    "dark": dict(ink="#E8E8E8", blue="#62ABF5", red="#FF7A7A", green="#6CCB5F",
                 folderFill="#E5B443", folderStroke="#FFD97A", paper="#454545", archFill="#4D3F6E", archStroke="#C3A3FF",
                 blueFill="#264A70", driveFill="#4C4C4C", greenFill="#28452A", onAccent="#1E1E1E"),
}
ROLES = {  # = gen_fluent.py + greenduo; role -> (underlay tint token or None, outline token)
    "ink": (None, "ink"), "blue": (None, "blue"), "red": (None, "red"), "green": (None, "green"),
    "folder": ("folderFill", "folderStroke"), "doc": ("paper", "ink"), "arch": ("archFill", "archStroke"),
    "blueduo": ("blueFill", "blue"), "drive": ("driveFill", "ink"), "drivered": ("driveFill", "red"),
    "greenduo": ("greenFill", "green"),
}
NO_PAPER = {"markdown", "music_note_2", "arrow_sync_circle"}  # a filled underlay would change the meaning: a halo
HALO = {"light": "#FFFFFF", "dark": "#1E1E1E"}
PLATE = {"light": "#FFFFFF", "dark": "#262626"}  # = the Network composite in gen_fluent.py

# id -> (Fluent glyph or @own drawing, size of the glyph, role, badge). badge: (kind, colour token, glyph):
#   "glyph": a 12 px Fluent glyph (filled tint + regular outline) on the plate, as the Network globe
#   "disc":  a filled accent disc with a 12 px Fluent glyph cut in the on-accent colour (Fluent status badge)
#   "tile7": a rounded accent tile with a "7" (Fluent's file-type badges are letter tiles)
PLUGINS = {
    # archivers: the archive purple of Pack / Unpack
    "zip": ("folder_zip", 16, "arch", None),                                  # the Explorer compressed folder
    "7zip": ("archive", 16, "arch", ("tile7", "archStroke", None)),            # archive + "7" tile
    "tar": ("archive_multiple", 16, "arch", None),                            # many archives: TAR, GZ, BZ2, XZ
    "uncab": ("box", 16, "arch", None),                                       # a cabinet
    "uniso": ("cd", 16, "arch", None),                                        # a disc image (not the grey CD drive)
    "unrar": ("library", 16, "arch", None),                                   # book spines (without the RAR logo)
    "unchm": ("book_question_mark", 20, "arch", None),                        # compiled help
    "unmime": ("mail_attach", 16, "arch", None),                              # mail attachments
    "unole": ("document_folder", 16, "arch", None),                           # a document holding folders
    # F3 viewers: documents
    "codeview": ("document_code", 16, "doc", None),
    "mdview": ("markdown", 16, "ink", None),
    "dbviewer": ("document_table", 16, "doc", None),
    "peviewer": ("document_bullet_list_cube", 16, "doc", None),               # a listing with a module cube
    "pictview": ("image", 16, "blueduo", None),
    "mmviewer": ("music_note_2", 16, "blue", None),
    # file systems: coloured by the place
    "ftp": ("folder_globe", 16, "folder", None),                              # remote folders
    "sftp": ("folder_globe", 16, "folder", ("glyph", "ink", "lock_closed")),  # the same + a lock
    "folders": ("folder_multiple", 16, "folder", None),                       # the shell's folders
    "regedt": ("@regedit", 16, "blueduo", None),                              # own drawing, see regedit()
    "undelete": ("delete", 16, "doc", ("disc", "green", "arrow_counterclockwise")),  # the bin + a green "back"
    "portables": ("phone", 16, "drive", None),                                # a device, grey like the drives
    "nethood": ("@network", 16, "blueduo", None),                             # = Network of the toolbar
    # tools
    "checksum": ("document", 16, "doc", ("disc", "green", "checkmark")),      # a verified document
    "filecomp": ("document_landscape_split", 20, "doc", None),                # one document split in two halves
    "diskmap": ("data_treemap", 20, "blueduo", None),                         # what the plug-in draws
    "renamer": ("text_edit_style", 16, "ink", None),                          # a letter with a pencil
    "automation": ("script", 16, "ink", None),
    "checkver": ("arrow_sync_circle", 16, "green", None),
    # samples for plug-in authors: a puzzle piece (= a plug-in) + a badge
    "demoplug": ("puzzle_piece", 16, "blueduo", ("glyph", "ink", "server")),
    "demoview": ("puzzle_piece", 16, "blueduo", ("glyph", "ink", "eye")),
    "demomenu": ("puzzle_piece", 16, "blueduo", None),
    # the program's defaults
    "_plugin": ("puzzle_piece", 16, "ink", None),
    "_pluginfs": ("puzzle_piece", 16, "ink", ("glyph", "ink", "server")),
}


def body_of(fn):
    with open(os.path.join(SRC, fn), encoding="utf-8") as f:
        t = f.read()
    body = re.search(r"<svg[^>]*>(.*)</svg>", t, re.S).group(1)
    assert not re.search(r"<(linearGradient|radialGradient|mask|clipPath|filter|use|image|text)\b", body), fn
    return re.sub(r'\sfill="[^"]*"', "", body)


def has(fn):
    return os.path.exists(os.path.join(SRC, fn))


def base_glyph(icon, size, role, theme):
    """The rules of gen_fluent.build for a plain glyph."""
    P = PAL[theme]
    tint, stroke = ROLES[role]
    if tint is None and role in ("ink", "blue", "red") and icon not in NO_PAPER and has(f"{icon}_{size}_filled.svg"):
        tint = "paper"
    reg = body_of(f"{icon}_{size}_regular.svg")
    inner = ""
    if tint:
        inner += f'<g fill="{P[tint]}">{body_of(f"{icon}_{size}_filled.svg")}</g>'
    else:
        inner += f'<g fill="{HALO[theme]}" stroke="{HALO[theme]}" stroke-width="1.5" stroke-linejoin="round">{reg}</g>'
    inner += f'<g fill="{P[stroke]}">{reg}</g>'
    if size != 16:
        inner = f'<g transform="scale({16 / size:.4f})">{inner}</g>'
    return inner


def network(theme):  # = gen_fluent.py "@network"
    P = PAL[theme]
    B, F = P["blue"], P["blueFill"]
    return (f'<g fill="{F}">{body_of("desktop_16_filled.svg")}</g><g fill="{B}">{body_of("desktop_16_regular.svg")}</g>'
            f'<circle cx="12" cy="12" r="4.6" fill="{PLATE[theme]}"/>'
            f'<g transform="translate(8 8) scale(0.6667)"><g fill="{F}">{body_of("globe_12_filled.svg")}</g><g fill="{B}">{body_of("globe_12_regular.svg")}</g></g>')


def regedit(theme):
    """Own drawing after the Windows Registry Editor icon, facing the viewer as the original does (oblique view):
    a block assembled from cubes (2x2x2; cube 4 px, depth 2 px up-right), the front top-right cube missing, and two
    tilted cubes flying in from the top right. Front faces and grooves lie on whole pixels (edges at .5 with a 1 px
    groove), so the front of the block stays sharp at 16 px. Colours from the Fluent 2 brand ramp: top 150, front
    120 (dark 110), side 90, groove 80 (dark 70). The flying cubes carry the set's halo."""
    C = {"light": dict(top="#CFE4FA", front="#77B7F7", right="#2886DE", groove="#0F6CBD"),
         "dark": dict(top="#CFE4FA", front="#62ABF5", right="#2886DE", groove="#0F548C")}[theme]
    f = lambda v: f"{v:g}"

    def cube(x, y, s, d, halo=False, rot=0):
        front = f"M{f(x)} {f(y)}h{f(s)}v{f(s)}h{f(-s)}z"
        top = f"M{f(x)} {f(y)}l{f(d)} {f(-d)}h{f(s)}l{f(-d)} {f(d)}z"
        right = f"M{f(x + s)} {f(y)}l{f(d)} {f(-d)}v{f(s)}l{f(-d)} {f(d)}z"
        out = f"M{f(x)} {f(y)}l{f(d)} {f(-d)}h{f(s)}v{f(s)}l{f(-d)} {f(d)}h{f(-s)}z"
        g = ""
        if halo:
            g += f'<path d="{out}" fill="{HALO[theme]}" stroke="{HALO[theme]}" stroke-width="1.2" stroke-linejoin="round"/>'
        g += f'<path d="{front}" fill="{C["front"]}"/><path d="{top}" fill="{C["top"]}"/><path d="{right}" fill="{C["right"]}"/>'
        g += (f'<path d="{out} M{f(x + s)} {f(y)}l{f(d)} {f(-d)} M{f(x)} {f(y)}h{f(s)}v{f(s)}" fill="none" '
              f'stroke="{C["groove"]}" stroke-width="1" stroke-linejoin="round"/>')
        if rot:
            g = f'<g transform="rotate({rot} {f(x + s / 2)} {f(y + s / 2)})">{g}</g>'
        return g

    s, d, x0, ybot = 4, 2, 0.5, 15.5
    # cells (column, row from the bottom, depth from the front); painter's order: back to front, bottom to top, left to right
    cells = [(c, r, z) for z in (1, 0) for r in (0, 1) for c in (0, 1) if (c, r, z) != (1, 1, 0)]
    g = "".join(cube(x0 + c * s + z * d, ybot - (r + 1) * s - z * d, s, d) for c, r, z in cells)
    return g + cube(10.5, 2.5, 3, 1.5, True, -14) + cube(12.5, 8.5, 2.5, 1.2, True, 12)


def badge(spec, theme):
    kind, tok, icon = spec
    P = PAL[theme]
    if kind == "glyph":
        tint = {"ink": "paper", "blue": "blueFill", "green": "greenFill"}[tok]
        return (f'<circle cx="12" cy="12" r="4.6" fill="{PLATE[theme]}"/>'
                f'<g transform="translate(8 8) scale(0.6667)"><g fill="{P[tint]}">{body_of(icon + "_12_filled.svg")}</g>'
                f'<g fill="{P[tok]}">{body_of(icon + "_12_regular.svg")}</g></g>')
    if kind == "disc":
        # the 12 px glyph scaled to 7 px, centred on the disc (12,12); the filled glyph for a solid mark on the accent
        s = 7 / 12
        return (f'<circle cx="12" cy="12" r="4.6" fill="{PLATE[theme]}"/><circle cx="12" cy="12" r="3.75" fill="{P[tok]}"/>'
                f'<g transform="translate({12 - 6 * s:.3f} {12 - 6 * s:.3f}) scale({s:.4f})" fill="{P["onAccent"]}">{body_of(icon + "_12_filled.svg")}</g>')
    if kind == "tile7":
        # an accent tile 8x8 at (8,8) on a 1 px plate; the "7": a 1.25 px stroke on the Fluent 1 px grid
        return (f'<rect x="7" y="7" width="9" height="9" rx="2.2" fill="{PLATE[theme]}"/>'
                f'<rect x="8" y="8" width="8" height="8" rx="1.6" fill="{P[tok]}"/>'
                f'<path d="M10.1 10.1h3.8l-2.3 4.3" fill="none" stroke="{P["onAccent"]}" stroke-width="1.25" stroke-linejoin="round"/>')
    raise ValueError(kind)


def build(spec, theme):
    icon, size, role, bdg = spec
    inner = network(theme) if icon == "@network" else regedit(theme) if icon == "@regedit" else base_glyph(icon, size, role, theme)
    if bdg:
        inner += badge(bdg, theme)
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">{inner}</svg>'


base = os.path.join(OUT, "plugins")
os.makedirs(os.path.join(base, "dark"), exist_ok=True)
for pid, spec in PLUGINS.items():
    for theme in ("light", "dark"):
        s = build(spec, theme)
        # the image lists treat magenta and the toolbar background (light / dark) as transparent
        assert "#F0F0F0" not in s.upper() and "#2D2D2D" not in s.upper() and "#FF00FF" not in s.upper(), pid
        with open(os.path.join(base, *([] if theme == "light" else ["dark"]), pid + ".svg"), "w", encoding="utf-8", newline="") as f:
            f.write(s)
print(len(PLUGINS), "plug-in icons")
