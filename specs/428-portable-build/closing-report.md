# Closing report - 428-portable-build
Outcome: implemented, verified on this machine; nothing committed or pushed (the maintainer's step)

## What changed

- **A portable edition** of Tandem Commander, fixed at build time (`TC_PORTABLE`, MSBuild
  `TcEdition=portable`, output `<Config>_x64_portable`, every output root and `Intermediate` under
  the suffix `_portable`, guarded by `tools/check_outdir_suffix.py`):
  - **No registry of its own**: the configuration lives in a private registry hive
    (`RegLoadAppKeyW`) in `%TEMP%\TandemCommander-portable-<scope>\session.dat`, seeded at start from
    `settings\tandemcommander.reg` next to the program and written back (2 s after a change, after
    SaveConfig, at exit) through a temporary file + `SalReplaceWithTempW`, the previous file kept as
    `.bak`; paths inside the program folder stored as `$(PortableDir)`. reglib maps
    `HKEY_CURRENT_USER` to the hive (`SalCfgBaseKey()`); 33 registry sites classified
    (`tools/check_portable_regsites.py`). Several processes of one copy share the session;
    copies in different folders and the installed program never see each other (scoped kernel
    objects, FR-011a).
  - Files the program keeps go into `settings\` (bug reports, import backups, the export folder,
    PictView's wallpaper picture and its previous-wallpaper backup); WebView2 data in the session
    folder, removed at exit (and after a crash at the next start).
  - **Identity**: `[portable]` in the title, a badge icon, About shows "Portable edition" and the
    settings folder as a link (Enter / click opens it in the active panel).
  - **Update check**: offers only a release carrying the portable ZIP, opens the release page,
    never downloads; the level list is hidden (General page and the notification).
  - **Import / export**: *Import Configuration* checks the file at once and applies it at the next
    lone start (`settings\import.reg`), a `$(PortableDir)` of another copy expands to this one;
    exports contain absolute paths.
  - Password note (once, "do not show again"), the Explorer-integration message (FR-006a).
  - Plug-in interface **109**: `IsPortableEdition`, `GetUserDataFolderW`, `GetInstanceScopeSuffix`.
- **The package**: `build.cmd full release portable` makes
  `tandemcommander-<ver>-x64-portable.zip` (`tools/portable/make_portable_zip.py`: one top folder,
  sorted, commit-time stamps, `.part` + rename, refuses a normal-edition exe, the GPL / LGPL / 7-Zip /
  third-party notices and `README-portable.txt`); a released version's ZIP goes to the build folder,
  never over a published file.
- **`build.cmd dist`**: the complete signed release in one command (installer + portable ZIP),
  refusing before any work a released version, a missing certificate or another build folder;
  `tools/release/release.py artifacts <ver>` checks both files (layout, edition, every executable file
  validly signed). RELEASE.md and `/tandem-release` updated.
- Docs: PRIVACY.md (*Portable edition*), README, help, CHANGELOG `[Unreleased]`, architecture 06 /
  11 (binding WebView2 rule) / 12, CLAUDE.md (interface 109, the commands, the configuration rule).

## Measurements (final run, 2026-11-14 15:07, `probe/results/run_all-20261114-150721.txt`)

| Check | Result |
|---|---|
| Builds `full portable`, `full`, `full release`, `full release portable` | green |
| saltests | 287,558 checks, 0 failed |
| `check_encoding.py --strict` | TOTAL 0 |
| unit tests (`test_dist_summary.py` 11, `test_release.py` 51) | OK |
| zip_check (626 entries) Z1-Z7; Z8 two builds of one commit | PASS; same files apart from build stamps (215 differ by stamps only; negative control: a real change is found) |
| gate (real configuration + synthetic values, round trip) | 0 differences, the token check PASS |
| notrace (portable) / negative control (normal edition) | PASS / FAILs on exactly its two named rows |
| scenarios: move (non-ASCII path, subst), unwritable, damaged, both damaged, 20 kills (13 cut a write in the middle), two processes of a copy, side by side | PASS |
| import I1-I6 (incl. cross-edition) | PASS |
| identity (8 languages, About, link, icons, FR-006a) | PASS |
| update (with / without the ZIP, not uploaded, General page, nothing downloaded) | PASS |
| password note | PASS |
| SC-009 (Release, the same configuration, a real save at exit) | start-up +6.5 %, exit +7.7 % (limit 10 %) |
| SC-010 normal tree | 615 -> 615 files, none added or removed; a portable build leaves the normal tree byte-identical |
| PictView wallpaper (probe 111 `-PortableSettings`) | 7 PASS, the profile's file untouched |
| installed edition's registry key | SHA-256 19c222e0... before and after every probe and at the end |

## Reviews

Three independent refute-first reviews (core, release tooling and claims, test adequacy), then two
re-reviews of the fixes and a third check of the store - every finding verified against the code,
fixed or decided; details in `fix-log.md` (sections of 2026-11-14). The most serious ones fixed: a
start joining while the last process closes could write defaults over the file (sev 8); a joiner of a
read-only session became writable (7); dumps without the configuration lock (7); PRIVACY wording that
would have broken `/tandem-release` (7); the closing pass overwriting a published ZIP (6).

## Not driven here (person checks, appended to *Manual checks owed before the next release*)

Real FAT32 / exFAT sticks on two PCs; the browser download (Mark of the Web, SmartScreen); the badge
on a real taskbar; real drag and drop to Explorer; elevated title; High Contrast About; the password
note through a real FTP / SFTP bookmark; `build.cmd dist` on the release day.

## New Inbox items

`the-installer-ships-7-zip-without-the-lgpl-text-the-notices` (6), `builds-not-bit-reproducible` (4),
`portable-regsites-check-skips-plugins` (4), `update-level-offered-in-unpacked-copy` (3).

## Owed to the maintainer

Review and commit the branch (nothing is committed); the first release with the portable edition
runs `/tandem-release`, then `build.cmd dist`, and attaches both files.
