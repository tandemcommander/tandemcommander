# Tandem Commander toolbar icon proposal "Fluent 2" - built on Microsoft Fluent UI System Icons (MIT).
# Every button maps to one Fluent icon (16 px regular; a few exist only at 20 px and are scaled) and a colour role.
# Duotone roles draw the matching *_filled glyph underneath as a tint and the *_regular outline on top.
# Writes <out>/<Name>.svg, <out>/dark/<Name>.svg and <out>/LICENSE-fluent.txt (feature 416: the "Fluent 2" icon set,
# src/res/iconsets/fluent). The mapping, palettes and own glyphs are those of the maintainer's design study of
# 2026-11-07; see README.md for fetching the pinned package.
# Usage: python gen_fluent.py <unpacked @fluentui/svg-icons 1.1.344 folder (holds package/ and LICENSE.txt)> [<out>]
import os, re, shutil, sys

if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help"):
    print("usage: python gen_fluent.py <fluent-package-folder> [<out-folder>]\n"
          "  <fluent-package-folder>: the unpacked npm tarball of @fluentui/svg-icons 1.1.344 (package/icons/...)\n"
          "                           and the licence text as LICENSE.txt beside package/\n"
          "  <out-folder>: default src/res/iconsets/fluent of this repository")
    sys.exit(0)
PKG = sys.argv[1]
SRC = os.path.join(PKG, "package", "icons")
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "src", "res", "iconsets", "fluent")

PAL = {
    "light": dict(ink="#242424", blue="#0F6CBD", red="#C50F1F", green="#107C10",
                  folderFill="#FFCF5C", folderStroke="#A86F00", paper="#FFFFFF", archFill="#E3D5FA", archStroke="#7A3FC8",
                  blueFill="#CFE4FA", driveFill="#E2E2E2"),
    "dark": dict(ink="#E8E8E8", blue="#62ABF5", red="#FF7A7A", green="#6CCB5F",
                 folderFill="#E5B443", folderStroke="#FFD97A", paper="#454545", archFill="#4D3F6E", archStroke="#C3A3FF",
                 blueFill="#264A70", driveFill="#4C4C4C"),
}
ROLES = {  # role -> (underlay tint token or None, outline token)
    "ink": (None, "ink"), "blue": (None, "blue"), "red": (None, "red"), "green": (None, "green"),
    "folder": ("folderFill", "folderStroke"), "doc": ("paper", "ink"), "arch": ("archFill", "archStroke"),
    "blueduo": ("blueFill", "blue"), "drive": ("driveFill", "ink"), "drivered": ("driveFill", "red"),
}
# Name (SVGName in ToolBarButtons[] or suggested name) -> (fluent icon, role[, size])
MAP = {
    # navigation
    "Back": ("arrow_left", "blue"), "Forward": ("arrow_right", "blue"), "GoToHotPath": ("bookmark", "blueduo"),
    "ParentDirectory": ("folder_arrow_up", "folder"), "RootDirectory": ("arrow_export_up", "blue"),
    "ChangeDirectory": ("folder_arrow_right", "folder"), "GoToShortcutTarget": ("open", "blue"),
    # drives & network
    "ConnectNetworkDrive": ("plug_connected", "ink"), "Disconnect": ("plug_disconnected", "red"),
    "SharedDirectories": ("share", "ink"), "DriveInformation": ("hard_drive", "drive"),
    # view & sort
    "Views": ("grid", "ink"), "SortByName": ("text_sort_ascending", "ink"), "SortByExtension": ("document_text", "doc"),
    "SortBySize": ("data_bar_vertical_ascending", "ink"), "SortByDate": ("calendar", "ink"),
    "SmartColumnMode": ("table_resize_column", "ink"), "Filter": ("filter", "ink"), "Refresh": ("arrow_clockwise", "blue"),
    "SwapPanels": ("arrow_swap", "blue"),
    # files
    "Copy": ("copy_arrow_right", "ink"), "Move": ("document_arrow_right", "ink"), "Delete": ("delete", "red"),
    "CreateDirectory": ("folder_add", "folder"), "New": ("document_add", "doc"), "EditNewFile": ("compose", "ink"),
    "QuickRename": ("rename", "ink"), "View": ("glasses", "ink"), "Edit": ("edit", "ink"), "Email": ("mail", "ink"),
    "ChangeCase": ("text_case_title", "ink"), "Convert": ("translate", "ink"),
    # attributes
    "ChangeAttributes": ("tag", "ink"), "Security": ("shield_lock", "blueduo"), "Properties": ("info", "blue"),
    "NTFSCompress": ("arrow_minimize", "ink"), "NTFSUncompress": ("arrow_maximize", "ink"),
    # clipboard
    "ClipboardCut": ("cut", "ink"), "ClipboardCopy": ("copy", "ink"), "ClipboardPaste": ("clipboard_paste", "ink"),
    "PasteShortcut": ("clipboard_link", "ink"),
    # archives
    "Pack": ("archive", "arch"), "Unpack": ("archive_arrow_back", "arch"),
    # tools
    "FindFilesAndDirectories": ("search", "ink"), "CompareDirectories": ("item_compare", "ink"),
    "CalculateDirectorySizes": ("autosum", "ink"), "CalculateOccupiedSpace": ("data_pie", "ink"),
    "CommandShell": ("@console", "ink"), "UserMenu": ("star_line_horizontal_3", "ink"),
    "Configuration": ("settings", "ink"), "HelpContents": ("question_circle", "blue"), "WhatIsThis": ("cursor_hover", "ink"),
    # other panel
    "GoToPathFromOtherPanel": ("arrow_export_rtl", "blue"), "OpenNameInOtherPanel": ("arrow_export_ltr", "blue"),
    "FocusNameInOtherPanel": ("panel_left_expand", "blue"),
    # selection
    "Select": ("add_square", "blue"), "Unselect": ("subtract_square", "blue"), "InvertSelection": ("checkbox_checked_sync", "blue"),
    "SelectAll": ("select_all_on", "blue"), "UnselectAll": ("select_all_off", "blue"), "RestoreSelection": ("history", "blue"),
    "SaveSelection": ("save", "ink"), "LoadSelection": ("document_arrow_up", "ink"),
    "SelectFilesWithSameExtension": ("tag_add", "blue"), "UnselectFilesWithSameExtension": ("tag_dismiss", "blue"),
    "SelectFilesWithSameName": ("add_square_multiple", "blue"), "UnselectFilesWithSameName": ("dismiss_square_multiple", "blue"),
    "GoToPreviousSelectedName": ("arrow_up", "blue"), "GoToNextSelectedName": ("arrow_down", "blue"),
    "HideSelectedNames": ("eye_off", "ink"), "HideUnselectedNames": ("eye_tracking_off", "ink"), "ShowHiddenNames": ("eye", "ink"),
    # system folders
    "OpenFolder": ("folder_open", "folder"), "OpenActiveFolder": ("open_folder", "folder"), "OpenDesktop": ("desktop", "ink"),
    "OpenComputer": ("laptop", "ink"), "OpenControlPanel": ("options", "ink"), "OpenPrinters": ("print", "ink"),
    "OpenNetwork": ("@network", "blue"), "OpenRecycleBin": ("delete", "ink"), "OpenFonts": ("text_font", "ink"),
    "OpenDocuments": ("folder_document", "folder"),
    # drives
    "DriveFixed": ("hard_drive", "drive"), "DriveSystem": ("hard_drive", "blueduo"), "DriveRemovable": ("usb", "drive"),
    "DriveCD": ("cd", "drive"), "DriveNetwork": ("server_link", "drive"), "DriveNetworkDisconnected": ("server_link", "drivered"),
    "DriveRam": ("ram", "drive"), "ChangeDrive": ("hard_drive", "blueduo"),
    # panel symbol, EditListBox
    "UpDir": ("@updir", "blue"),
    "New_Insert": ("add", "ink"), "Modify": ("edit", "ink"), "MoveItemUp": ("arrow_up", "blue"), "MoveItemDown": ("arrow_down", "blue"),
}

NO_PAPER = {"arrow_left", "arrow_right", "arrow_up", "arrow_down", "arrow_up_left", "arrow_export_up", "arrow_export_ltr", "arrow_export_rtl",
            "arrow_clockwise", "arrow_swap", "arrow_minimize", "arrow_maximize", "text_sort_ascending", "data_bar_vertical_ascending",
            "autosum", "translate", "text_case_title", "text_font", "table_resize_column", "star_line_horizontal_3", "options", "add",
            "filter", "plug_connected", "plug_disconnected", "history", "cut", "share", "item_compare"}

def paths_of(fn):
    with open(os.path.join(SRC, fn), encoding="utf-8") as f:
        t = f.read()
    m = re.search(r"<svg[^>]*>(.*)</svg>", t, re.S)
    body = m.group(1)
    assert not re.search(r"<(linearGradient|radialGradient|mask|clipPath|filter|use|image|text)\b", body), fn
    return re.sub(r'\sfill="[^"]*"', "", body)

# the only own drawing: Fluent has no 16 px console glyph; drawn on the Fluent grid (1 px stroke, 2 px corner radius)
CUSTOM = {"console": '<path d="M3.5 2A2.5 2.5 0 0 0 1 4.5v7A2.5 2.5 0 0 0 3.5 14h9a2.5 2.5 0 0 0 2.5-2.5v-7A2.5 2.5 0 0 0 12.5 2zM2 4.5C2 3.67 2.67 3 3.5 3h9c.83 0 1.5.67 1.5 1.5v7c0 .83-.67 1.5-1.5 1.5h-9A1.5 1.5 0 0 1 2 11.5z"/>'
           '<path d="M4.15 6.15a.5.5 0 0 1 .7 0l1.5 1.5a.5.5 0 0 1 0 .7l-1.5 1.5a.5.5 0 0 1-.7-.7L5.29 8 4.15 6.85a.5.5 0 0 1 0-.7M7.5 10h4a.5.5 0 0 1 0 1h-4a.5.5 0 0 1 0-1"/>',
          # ".." of the file list: the shape and idea of today's updir.ico (angular up arrow whose stem turns right,
          # followed by two square dots), redrawn flat on the 16 px pixel grid: every straight edge on a whole pixel,
          # the head's flanks at 45 degrees, no stroke and no rounded corners (a 0.5 px stroke and .7 corners put every
          # edge on a quarter pixel and blurred the icon)
          "updir": '<path d="M3 3h1l3 3v1H5v4h3v3H2V7H0V6z"/><rect x="9" y="11" width="3" height="3"/><rect x="13" y="11" width="3" height="3"/>'}

# thin halo behind outline-only glyphs (light set): they stay visible on the dark blue menu highlight and on a blue panel cursor
HALO = {"light": "#FFFFFF", "dark": "#1E1E1E"}

def build(name, spec, theme):
    icon, role = spec[0], spec[1]
    if icon.startswith("@"):
        P = PAL[theme]
        g = CUSTOM.get(icon[1:], "")
        if icon == "@network":
            # Network: Fluent "desktop" + Fluent "globe" (12 px) as a corner badge on a cut-out plate, the way Fluent composes badges
            B, F = P["blue"], P["blueFill"]
            plate = {"light": "#FFFFFF", "dark": "#262626"}[theme]
            body = (f'<g fill="{F}">{paths_of("desktop_16_filled.svg")}</g><g fill="{B}">{paths_of("desktop_16_regular.svg")}</g>'
                    f'<circle cx="12" cy="12" r="4.6" fill="{plate}"/>'
                    f'<g transform="translate(8 8) scale(0.6667)"><g fill="{F}">{paths_of("globe_12_filled.svg")}</g><g fill="{B}">{paths_of("globe_12_regular.svg")}</g></g>')
            return f'<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">{body}</svg>'
        if icon == "@updir":
            halo = {"light": "#FFFFFF", "dark": "#1E1E1E"}[theme]
            # a 1 px halo (a 2 px stroke, half of it outside) with mitred joins keeps the halo on whole pixels too
            body = f'<g fill="{halo}" stroke="{halo}" stroke-width="2">{g}</g>' + f'<g fill="{P[ROLES[role][1]]}">{g}</g>'
        else:
            body = f'<rect x="1.5" y="2.5" width="13" height="11" rx="2" fill="{P["paper"]}"/>' + f'<g fill="{P[ROLES[role][1]]}">{g}</g>'
        return f'<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">{body}</svg>'
    size = spec[2] if len(spec) > 2 else 16
    tint, stroke = ROLES[role]
    P = PAL[theme]
    # paper underlay for outline-only icons: keeps them legible on any background, also on the dark blue
    # menu highlight (COLOR_HIGHLIGHT); skipped where a filled shape would change the meaning (arrows, letters, lines)
    if tint is None and role in ("ink", "blue", "red") and icon not in NO_PAPER and os.path.exists(os.path.join(SRC, f"{icon}_{size}_filled.svg")):
        tint = "paper"
    reg = paths_of(f"{icon}_{size}_regular.svg")
    inner = ""
    if tint:
        fil = paths_of(f"{icon}_{size}_filled.svg")
        inner += f'<g fill="{P[tint]}">{fil}</g>'
    elif HALO[theme]:
        inner += f'<g fill="{HALO[theme]}" stroke="{HALO[theme]}" stroke-width="1.5" stroke-linejoin="round">{reg}</g>'
    inner += f'<g fill="{P[stroke]}">{reg}</g>'
    if size != 16:
        inner = f'<g transform="scale({16 / size:.4f})">{inner}</g>'
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">{inner}</svg>'

os.makedirs(os.path.join(OUT, "dark"), exist_ok=True)
for name, spec in MAP.items():
    for theme in ("light", "dark"):
        s = build(name, spec, theme)
        # the image lists treat magenta and the toolbar background (light / dark) as transparent
        assert "#F0F0F0" not in s.upper() and "#2D2D2D" not in s.upper() and "#FF00FF" not in s.upper(), name
        with open(os.path.join(OUT, *([] if theme == "light" else ["dark"]), name + ".svg"), "w", encoding="utf-8", newline="") as f:
            f.write(s)
shutil.copy(os.path.join(PKG, "LICENSE.txt"), os.path.join(OUT, "LICENSE-fluent.txt"))
print(len(MAP), "icons")
