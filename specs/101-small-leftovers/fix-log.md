# Fix log: feature 101 - small leftovers

Branch `101-small-leftovers`, from `100-cjk-focus-name`.
Decisions by the author (maintainer away): `spec.md` *Clarifications*.

## T002 - S1 code

### Tray tip (`src/mainwnd1.cpp`)

- `AddTrayIcon`, `RemoveTrayIcon`, `SetTrayIconText` - every notification-area call of the
  program - use `NOTIFYICONDATAW` (zero-initialised) and `Shell_NotifyIconW`; there is no
  balloon (`NIF_INFO`) anywhere. The tip is converted by the new
  `SalU8ToWTruncate` (`src/common/salunicode.{h,cpp}`): UTF-8 (WTF-8) -> UTF-16, legacy
  code-page text (the "not valid UTF-8" branch of `SetWindowTitle`) read in the system code
  page, cut at a whole character within the 128 units of `szTip` (a surrogate pair is left out
  whole, never split; a lone surrogate counts as one character). Before: the UTF-8 bytes were
  `lstrcpyn`-ed into the ANSI `szTip` (every non-ASCII name garbled, cut at 127 BYTES, possibly
  inside a character).
- `src/tserver/window.cpp` (the trace server, a separate developer tool, constant ASCII tip) is
  not the product and was left as it is.
- Pre-existing, unchanged: `AddTrayIcon(TRUE)` from `SetWindowIcon` resets the tip to the
  product name until the next title change.
- Verified by unit test (saltests `TestLeftovers101`: exact Czech/Cyrillic/CJK/emoji, the cut at
  128 units with a pair at the boundary, 200 x U+0159 -> 127 whole characters, every buffer
  size, lone surrogates, legacy text, arguments) and by reading. Not driven: the hidden desktop
  has no notification area (`Shell_NotifyIconW` finds no tray there) and the user's real tray was
  deliberately not touched.

### Clipboard path paste (`src/fileswn9.cpp` `ClipboardPastePath`)

- The buffer is `CSalMaxPathBuffer` (SAL_MAX_PATH_UTF8, the size Change Directory and
  `PostProcessPathFromUser` use) instead of `char[2 * MAX_PATH]`; only a text that does not fit
  even that (no such path can exist) still gets "too long". The trim and conversion moved to a
  helper `ClipboardPathToU8` shared by both formats.
- `CF_UNICODETEXT` first, as before. The `CF_TEXT` branch (reached only when no Unicode text
  can be had) now converts the code-page text to UTF-8 too - it copied code-page bytes into a
  buffer whose contract is UTF-8. A path that does not exist goes to `ChangeDir` and gets its
  usual error.
- Verified by reading only: `OpenClipboard` fails for this session's processes on both desktops
  again (probe rows p600/p5000/pnx/pcjk NOT DRIVEN, as in 098).

### Find window "copy UNC name" (`src/fileswn9.cpp` `CopyUNCPathToClipboard`)

- The body is `CopyUNCPathToClipboardAux` with a `tooLong` flag; the public function keeps its
  signature. On the top level a refusal for length now shows the existing IDS_TOOLONGPATH
  ("The path specified is too long.", title "Error", owner = the caller's window: the Find
  window for the Find route):
  - the early check (location + name over the 520-byte buffers) - it returned FALSE in silence,
    so the old clipboard content stayed and could be pasted by mistake;
  - a share, a mapped drive (`WNetGetConnectionW` ERROR_MORE_DATA, or the UNC form over the
    buffer) or a SUBST target (target + rest over the buffer) that holds the path but gives a
    UNC name that does not fit - these ended in "cannot be converted to UNC", which was wrong
    (the name can be converted, it is too long). `CShares::GetUNCPath` reports that through a
    new optional `BOOL* tooLong`.
- The other caller, the panel's `CopyFocusedNameToClipboard(cfnmUNC)` (Ctrl+Shift+C / menu /
  the command line's shortcut), refused a long location in silence (097 guard); it now hands the
  whole location (heap, SAL_TAB_LOCATION_MAX) to the function, which shows the message.
- Not changed: a clipboard that cannot be opened makes every copy command fail in silence
  (`CopyTextToClipboardW`), here as for Copy Full Name - not a length refusal.
- Driven (probe rows unc1-unc5 on a SUBST drive, both builds, see the table below).

### Share matching (`src/shares.cpp`)

- `CShares::GetUNCPath` compares the WHOLE path through the new
  `SalPathIsWithinOrdinalCI(path, dir, &bytes)` (`salunicode`): the identity of
  `SalPathHasPrefixOrdinalCI` plus the component boundary. It cut the path to 259 bytes and
  appended a backslash before a bare prefix test.
- **Found while doing it (older than 097, from Open Salamander):** the prefix test had no
  component boundary at all - the share of `C:\foo` matched `C:\foobar\x` and produced
  `\\computer\<share>\bar\x`. Fixed by the same helper; a root share `C:\` still holds `C:`
  (the old appended backslash), and the longest share still wins.
- Twin in the same file: `CShares::PrepareSearch` (the shared-folder marker of the panel) cut
  the panel path to 259 bytes before an equality test - a longer path whose first 259 bytes equal
  a share's parent folder would have been marked; now a heap copy of the whole path.
- Verified by unit test (whole path vs the 259-byte cut, boundary, root, `C:`, accented, 4,299-
  and 2,005-byte paths) and by reading; no share can be created here (`net share` needs an
  administrator).

### Directory-line drag image (`src/stswnd.cpp` `CreateDragImage`)

- The image is at most as wide as the window's monitor (`GetMonitorInfo`; 2,048 px when that
  fails, never over 4,096 px); a longer text is drawn with `DT_PATH_ELLIPSIS` (keeps the start
  and the last component - the one dragged). Before: about 280,000 px for a component of a
  7,500-character path, and the shared `ItemBitmap` stayed that large for the session.
- GDI failures: an `ItemBitmap.Enlarge` failure or a NULL `ImageList_Create` now returns NULL
  with a 0 x 0 size (it drew past a too-small bitmap / passed NULL on); the caller begins and
  ends the image drag only with an image, the drag itself works without one.
- Verified by reading (no drag on a hidden desktop).

## T003 - S2 messages

### Strings (English, `src/lang/texts.rc2`, ids in `src/texts.rh2`)

Free slots 14182-14184 of the bundle of IDS_DELFILESAFTERPACKINGNOLINKS (14181; bundle
14176-14191, section 156 of the `.slt`): no bundle changes its ordinal, so no re-key was needed
(the template differs from the committed `.slt` only by the three rows in section 156 - checked
by script for every language).

| id | symbol | text |
|----|--------|------|
| 14182 | IDS_DELFILESAFTERPACKINGUNREADABLE | You are trying to move selected files and directories to archive. This is not possible because a directory in the selection cannot be read, so it cannot be checked for links to directories. Files will not be deleted from disk. Please continue without deleting files from disk after packing to archive.\n\nDirectory: %s |
| 14183 | IDS_DELFILESAFTERPACKINGTOODEEP | ... because a directory in the selection is nested too deeply (more than %d levels), so it cannot be checked for links to directories. Files will not be deleted from disk. Please continue ...\n\nDirectory: %s |
| 14184 | IDS_DIRNESTEDTOODEEP | Directory "%s" is nested too deeply (more than %d levels) to be processed. |

Three strings, not two: the scan before a move needs the "too deep" cause with the move
framing ("files will not be deleted"), the packing walk needs it without (OK = skip, Cancel =
stop). The tone and the framing follow the neighbouring link text (14181), which stays for real
links.

### Code (`src/fileswn7.cpp`, `src/fileswnd.h` comment)

- `_ReadDirectoryTree` / `ReadDirectoryTree` carry a new `int* uncheckedWhy`;
  `NoteUncheckedFolder` records why with the first unchecked folder: UNCHECKED_UNREADABLE (the
  folder cannot be listed - both "cannot read" branches; also a path that cannot be built and low
  memory) or UNCHECKED_TOODEEP (depth > READDIRTREE_MAX_DEPTH).
- `ScanMoveSelectionForDirLinks` (the Pack dialog's "delete files after packing", F6 into an
  archive, drag & drop / cut + paste with Move - 098/099): a link -> 14181 as before; a folder
  not checked -> 14182, or 14183 with the limit 1000; a scan that recorded no folder (low memory,
  an early exit) -> 14182 naming the panel folder.
- `ReportReadDirTreeTooLong`: at depth 1,001 the walk shows 14184 with the folder's full path
  (it said the NAME was too long); a path that cannot be built keeps IDS_NAMEISTOOLONG.

### Translations

- `build.cmd` -> `src\vcxproj\build_langs.cmd --export-templates --module salamand` ->
  `python -m translate.merge --dry-run --module salamand`: **3 unique gaps per language, ~738
  characters each**, validation failures 0 - exactly the new rows.
- Merge (`SSL_CERT_FILE` = certifi): **6,488 DeepL characters** (quota remaining 487,712).
- Review of the DeepL output: informal register in de/fr/nl/es (du, tu, je, tu/continúa);
  Slovak wrote the Czech word "vnořený"; Hungarian used "könyvtár" where its corpus says
  "mappa" (113 : 8); Czech used other words than its neighbouring link message
  ("Snažíte se", "vybrané", "po zabalení"). **17 pins** under `salamand` in
  `translations/ui-overrides.json`, note `_feature_101`: cs 14182/14183, sk all three, de
  14182/14183, fr all three, nl 14182/14183, hu all three, es 14182/14183 - formal
  Sie/vous/u/usted, the words of 14181 and of the Pack dialog's check box 512 ("vom
  Datenträger", "ficheros", "označení ... po přidání do archivu"), straight French apostrophe.
  Romanian kept as DeepL wrote it (formal, diacritics - as the 071/084 pins).
- Second merge: 0 gaps, 0 characters. Provenance: pinned rows "human", the others "machine" in
  each `.origin`. Diff against HEAD: +3 rows in each `salamand.slt` and +3 keys in each
  `salamand.origin`, nothing else; `python -m translate.slt --verify`: 298 files byte-exact.
- `build.cmd full` (Debug): 189 language modules, version check OK. Checked by loading every
  `lang\*.slg` with `LoadLibraryEx(LOAD_LIBRARY_AS_DATAFILE)` and `LoadStringW(14181..14184)`:
  all 9 modules (English + 8) hold the three new strings in their language (script in the
  session scratchpad; output identical to the `.slt` rows).

Czech (pinned 14182/14183, DeepL 14184):
- 14182 "Pokoušíte se přesunout označené soubory a adresáře do archivu. Není to možné, protože
  adresář v označení nelze přečíst, a proto nelze ověřit, zda neobsahuje odkaz na adresář.
  Soubory nebudou z disku odstraněny. Pokračujte prosím bez odstranění souborů z disku po přidání
  do archivu.\n\nAdresář: %s"
- 14183 the same with "adresář v označení je vnořen příliš hluboko (více než %d úrovní), a proto
  nelze ověřit ..."
- 14184 "Adresář „%s“ je vnořen příliš hluboko (více než %d úrovní), než aby mohl být zpracován."

German (pinned 14182/14183, DeepL 14184):
- 14182 "Sie versuchen, die ausgewählten Dateien und Verzeichnisse ins Archiv zu verschieben. Das
  ist nicht möglich, da ein Verzeichnis in der Auswahl nicht gelesen werden kann und daher nicht
  auf Verknüpfungen zu Verzeichnissen geprüft werden kann. Die Dateien werden nicht vom
  Datenträger gelöscht. Fahren Sie fort, ohne die Dateien nach dem Packen vom Datenträger zu
  löschen.\n\nVerzeichnis: %s"
- 14183 the same with "zu tief verschachtelt ist (mehr als %d Ebenen) und daher ..."
- 14184 "Das Verzeichnis „%s“ ist zu tief verschachtelt (mehr als %d Ebenen), um verarbeitet zu
  werden."

## T004 - S3 the 096 probe

Cause of the flake, from the code: CM_EDIT (743) acts only when `EnablerFileOnDiskOrArchive` is
set, and the enablers are refreshed in the main loop's idle pass (`salamdr1.cpp` ->
`CMainWindow::OnEnterIdle`). The probe moved the caret from ".." to the file with Home/Down and
posted WM_COMMAND at once; when that message reached the queue before the idle pass, the enabler
still described ".." and the command was dropped without a trace ("temporary copy: none").
`archedit_probe.ps1` now focuses the file, lets the instance go idle (`Settle`: WM_NULL round
trip, 500 ms, round trip), posts F4, waits for the edited temporary copy, and - only when no
temporary copy and no window appeared at all - focuses again, settles 1.5 s and posts once more,
recording "F4 RETRY" in the row and a retry count in the summary. The focused item cannot be read
from outside (custom list box); the existing "tmp name equals archive name" check proves the
right file was edited. Three runs in a row on this build: **17 of 17 UPDATED each, 0 retries**
(`probe/regress_archedit_101_run{1,2,3}.txt`) - the retry path was not needed, so it is
verified by reading only.

## Probe (`probe/leftovers_probe.ps1`)

Dot-sources 098's `fix_probe_lib.ps1`; own Serve variant recording the raw text and the owner of
each window. Hidden desktop; registry SHA-256 identical after each run
(`1AB61430...F769`); SUBST drive removed; fixtures removed; nothing left running.
Results: `probe/leftovers_result.txt` (`-Expect fixed`), `probe/leftovers_result_pre101.txt`
(`Debug_x64_pre101`, `-Expect before`).

| Row | This build | Before 101 |
|-----|-----------|------------|
| p600 / p5000 / pnx / pcjk clipboard paste | NOT DRIVEN (OpenClipboard fails here) | NOT DRIVEN |
| unc1 panel, SUBST X: (target 240 bytes) + 302-byte location: target + rest > 520 | "The path specified is too long." | "cannot be converted to UNC" |
| unc2 panel, 602-byte location | "too long" | no window (silent) |
| unc3 Find window (found under X:\u2), 602-byte folder | "too long", owner = the Find window | no window (silent) |
| unc4 / unc5 control, short X: path (panel / Find window) | "cannot be converted to UNC" | the same |
| unr Alt+F5 + delete, B\U unreadable | 14182 (cannot be read); then "Cannot read directory" from the walk; files kept | link text 14181; files kept |
| deep Alt+F5 + delete, 1,005 levels | 14183 (scan) + 14184 (walk at level 1,001) + the enumerator's "too long" relative name; files kept - after the review: 14183 with the folder shortened by "..." + the enumerator's "too long" only (2 message boxes) | link text + 2 x "with full path is too long" (3 boxes) |
| link control, junction | link text | link text |
| unrcs / deepcs (Czech UI) | Czech 14182 / 14183 + 14184 | Czech link text |
| END rows | exit 0, no stray window, no report | the same |

Totals: this build **20 PASS / 0 FAIL / 4 NOT DRIVEN**; before 101 **20 PASS / 0 FAIL / 4 NOT
DRIVEN** (verdicts per `-Expect`).

Observed, not changed (upstream message box): when a message holds a long unbreakable path,
`msgbox.cpp DuplicateStrAndInsertEOLs` inserts hard line breaks at character positions into the
WHOLE text, also into the prose ("Files wil" / "l not be deleted"); the probe removes line breaks
before matching. Same on the build before (any message with a very long path).

## Gates (T002-T004, Debug)

- Debug x64 build exit 0; the only warnings are the pre-existing C4018 `salamdr2.cpp`
  1036/1044 and C4244 `zip.cpp` 5913 (recompiled because `salamand.h` changed).
- `build.cmd full` (Debug) exit 0, 189 language modules.
- saltests **13,170 checks, 0 failed** (13,119 + 51 in `TestLeftovers101`).
- `tools/check_encoding.py --strict` TOTAL 0; draft 131 (as HEAD; the four new candidates -
  `CF_TEXT` read through CP_ACP and the two standalone IDS_TOOLONGPATH messages - carry
  `encoding-check: allow` markers with the reason).
- Touched files keep BOM / no BOM and CRLF as at HEAD (checked per file).
- No plug-in interface change (no `src/plugins/` file touched).

## Regression (this build, results in `probe/regress_*_101*.txt`)

Run one after another through `tools/run_on_hidden_desktop.ps1`; registry SHA-256 identical after
every run (`1AB61430...F769`), nothing left running, fixtures removed.

| Probe | Result | Baseline |
|-------|--------|----------|
| 093 `dialogs_probe` | 139 PASS / 0 LOSSY / 0 FAIL / 1 not driven | same (100) |
| 093 `cmdline_probe` | 63 PASS / 0 FAIL / 1 INFO | same |
| 095 `longarc_probe` | 60 PASS / 0 FAIL, Debug handle notes 4 | same |
| 096 `archedit_probe` (new wait) | 17 of 17 UPDATED, three runs in a row, 0 retries | 17 of 17 only after re-runs (099, 100) |
| 097 `arcpath_probe -Stage S2` | 55 PASS / 0 FAIL | same |
| 097 `arcwork_probe` (run: the packing walk changed) | 390 PASS / 0 FAIL / 21 n/a | same |
| 098 `fix_probe` | 107 PASS / 0 FAIL / 3 not driven / 1 INFO | same |
| 099 `linkmove_probe` | first run 22 / 2: the two `unread` rows looked for the link text, which an unreadable folder no longer shows (intended - same refusal: "Move Error", nothing packed, B kept). The probe now also accepts the cannot-read text for `unread` (the link text still passes on older builds); re-run **24 PASS / 0 FAIL** | 24 / 0 |
| 100 `cjk_focus_probe -Expect fixed` | 77 PASS / 0 FAIL | same |

Not done in T002-T004 (later tasks): the independent review (T005), the full Release build (T006),
the commit (T007).

## Independent review - ACCEPT, two nits applied (T005)

The reviewer verified the format specifiers of all 8 languages, the pins byte for byte, drove the
Czech box text and the UNC refusals (one message each, the right owner). Applied:

### NIT 1 - the folder in 14181-14183 was cut with no sign

The scan keeps the folder name in a MAX_PATH buffer and cut it with `_snprintf_s` (the user saw
"...\d\d\d" ending nowhere). New `SalU8EllipsizeMiddle` (`salunicode`): the whole text when it
fits, else its start (a third) + "..." + its end (the last folders), cut only at whole characters;
`fileswn7.cpp SetScanFolderName` builds the full name on the heap and shortens it - used by
`NoteUncheckedFolder` (14182/14183), both link sites (14181, the same cut) and the panel-folder
fallback. Unit tests in `TestLeftovers101` (fits, exactly fits, the 1,005-level path keeps start
and end, every size 8-40 over 2- and 3-byte characters stays valid UTF-8, size < 8, arguments).
Driven: the deep rows' 14183 text now reads `...\S\A\d\d...\d...d\d\d...` (probe column
"14183 name shortened with '...'").

### NIT 2 - three boxes in the deep case

Measured first where the third box comes from: `_PanelSalEnumSelection` (the enumeration that
hands the walked tree to a plug-in packer) keeps names relative to the packed folder in
`char[MAX_PATH]` (`EnumLastPath`, `EnumTmpFileName`, `EnumLastDosPath` - the plug-in interface).
At about level 129 of the `\d` chain the relative path reaches 259 bytes: it refuses that folder
with IDS_NAMEISTOOLONG ("Name "d" with full path is too long. Path: A\d\d...") and skips its
whole subtree (levels 129-1,005 are not packed). **That box is a real length failure, not the
depth case, so it stays.** The walk's 14184 box (level 1,001) describes a folder inside that
already-refused subtree: 1,001 levels are at least 2,001 relative bytes, so for every too-deep
folder the enumeration has a box of its own. Not repeating a message for the same skipped part:
`ReportReadDirTreeTooLong` now gets the folder's relative path length (`_ReadDirectoryTree`
carries `relBase`, the work path's length) and skips a too-deep folder whose relative path is
MAX_PATH or more without a box (SALENUM_ERROR as before - nothing is skipped in silence, the
enumeration's box covers it). 14184 stays for a too-deep folder the enumeration would deliver (none
today; it becomes reachable if the enumeration ever takes longer names). The deep case now shows
14183 + the length box: **2 message boxes, both accurate** (before 101: the link text + 2 x "too
long": 3). The probe's deep rows count the message boxes (windows without an edit / combo box
child) and check the texts: fixed = scan 14183 once, shortened name, no 14184, "too long" once,
2 boxes; before = link text, "too long" twice, 3 boxes; `unr` = 2 boxes on both builds.

### Recorded only

- NIT 3: a scan that recorded no folder (low memory, an early exit) says "cannot be read" and names
  the panel folder - the nearest true statement without a new string.
- NIT 4: French "Répertoire : %s" (French typography) beside the neighbouring "Lien: %s";
  Romanian formal with diacritics beside its informal neighbour 14181 - consistent with the
  071/084 pins.

## Gates after the review (T006)

- Debug x64 build exit 0, only the known warnings (C4018 `salamdr2.cpp` 1036/1044, C4244 `zip.cpp`
  5913); saltests **13,278 checks, 0 failed** (13,119 + 159 in `TestLeftovers101`); strict guard
  TOTAL 0, draft 131 (as HEAD). BOM / CRLF kept per file (re-checked; a Git Bash `sed -i` had
  turned `saltests.cpp` to LF and was reverted to CRLF before the build).
- `leftovers_probe` (this build, `probe/leftovers_result.txt`): **20 PASS / 0 FAIL / 4 NOT DRIVEN**;
  `Debug_x64_pre101` result unchanged (`leftovers_result_pre101.txt`, run before the review with
  the box-count-free verdicts).
- Regression for the changed walk: 099 `linkmove_probe` 24 PASS / 0 FAIL; 098 `fix_probe` 107 PASS
  / 0 FAIL / 3 not driven / 1 INFO. Registry identical after each, nothing left running.
- Full Release build (`build.cmd full release`): exit 0, BUILD SUCCEEDED, no error lines; 20
  plug-ins registered, 189 language modules (version check OK), runtime closure OK; warnings only
  the three known ones (C4018 `salamdr2.cpp` 1036/1044, C4244 `zip.cpp` 5913).

Not done: the commit (T007) - left to the coordinator.
