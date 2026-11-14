# Contract: how the portable edition presents itself (FR-006a, FR-014 – FR-016, FR-015a)

## Main window title (FR-014)

`[<prefix> - ][<path> - ]Tandem Commander <version> [portable][ (Administrator)]` — the literal
` [portable]` (not a string resource, the same in every language) is inserted in
`CMainWindow::SetWindowTitle` right after the version. Taskbar button, Alt+Tab and the tray tooltip
reuse the title. Normal edition: unchanged.

## About box (FR-015)

Created at run time in `CAboutDialog` (portable only), directly below the version line, in the
dialog's font; the dialog grows by their height, other controls move down:

1. a static: `IDS_ABOUT_PORTABLE_EDITION` ("Portable edition");
2. a link (the `CUpdateLink` behaviour: Tab stop, Enter / Space / click, focus rectangle, the
   theme's link colour in Light / Dark / High Contrast) showing the full path of `settings\`; if it
   does not fit the width it is shortened in the middle at whole characters and the tooltip shows
   the whole path. Activating it closes the box and opens `settings\` in the active panel (created
   first if missing). Splash screen: unchanged.

## Icon (FR-016)

- `IDI_SALAMANDER` = `res\salamand_portable.ico` under `TC_PORTABLE` (rc define), every size of
  `res\salamand.ico`; badge (a small USB-stick mark, lower-right) with a contrasting outline so it
  reads on light and dark taskbars; generated from the brand sources by the existing
  `tools/brand/gen_icons.py` (a `--portable` variant, so both icons come from one generator) and
  checked in; `tools/brand/README.md` describes it.
- Taskbar group: no AppUserModelID set (Windows groups by executable path — verified by probe).
- Version resource: `FileDescription` = "Tandem Commander (portable)" under `TC_PORTABLE`.

## Explorer integration not available (FR-006a)

Where the normal edition needs the shell extension (`shellsup.cpp`: drag to Explorer and copy to
the clipboard from an archive or a plug-in file system), the portable edition shows
`IDS_PORTABLE_NOSHELLEXT` (information box): "Dragging or copying files out of an archive or a
plug-in file system to other programs needs the Explorer integration, which the portable edition
does not install. Copy or unpack the files to a disk folder first." Once per action, not once per
file.

## Password note (FR-015a)

At the first save of a password into the program's password store while no master password is set
(portable only, not after "Do not show this again"): `IDS_PORTABLE_PWDNOTE` with buttons *Set Master
Password…* / *Continue* and the check box *Do not show this again* (stored as `Portable Password Note
Shown`). The password is saved in both cases.

## Strings and translations

New strings: `IDS_ABOUT_PORTABLE_EDITION`, `IDS_PORTABLE_NOSHELLEXT`, `IDS_PORTABLE_PWDNOTE` (+ its
check box and button texts), `IDS_UPDATE_HINT_PORTABLE_EDITION`, and the four store messages of
[settings-store.md](settings-store.md). Free slots of existing bundles; the two-stage `.slt` refresh
(`translate.merge --templates`) runs in this feature; register pins in `ui-overrides.json` for
de / fr / nl / es (formal register) and "Portable edition" (not "transportable").
