# Fix log - 383-arc-typed-target-case

Backlog item `copying-into-an-archive-folder-typed-in-another-case-packs`: Copy (F5) / Move (F6) from
disk into an archive folder typed in another case packs into a new folder beside it.

## Measurement before (at e3dfe127, main)

- Site: `src/fileswn8.cpp`, `CFilesWindow::FilesAction`, the `PATH_TYPE_ARCHIVE` branch:
  `PackCompress(HWindow, this, path, hasPath ? secondPart + 1 : "", ...)` - the typed text after
  the archive name, unchanged. Reached from F5 / F6 in a disk panel with a typed target
  `<archive>\<path>\` (a trailing backslash; without it the dialog answers "operation masks not
  supported", unchanged).
- Other `PackCompress` callers (enumerated): `src/fileswna.cpp` drag & drop / paste into an archive
  panel - the root is the panel's `ZIPPath` (spelled as listed since 273) or a folder name of its
  listing; `src/salamdr3.cpp` the archive update of edited members - the root recorded from the
  listing. Neither is this defect.
- Probe `probe/arctarget383_probe.ps1` (written for this run, built on 382's and 099's probes), run
  on the hidden desktop:
  `powershell -File tools\run_on_hidden_desktop.ps1 -Log ...\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File ...\arctarget_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Lib specs\098-long-path-overruns\probe\fix_probe_lib.ps1 -Label before"`
  (scratch copy named `arctarget_probe.ps1`, fixture `tcarctgt`; renamed to `arctarget383_probe.ps1` /
  `tc383` when committed - same rows and checks).
  Result **22 PASS / 10 FAIL** (`probe/result_before.txt`), the same for 7z and ZIP:
  TYPED `\DOCS\` -> `DOCS\n.txt` beside `Docs`; DEEP `\dOCS\sUB\` -> `dOCS\sUB\n.txt`; NEWTAIL
  `\DOCS\New\` -> `DOCS\New\n.txt`; MOVE -> `DOCS\n.txt`; TWINS (twins `X\a.txt` / `X\A.txt`) ->
  `DOCS\n.txt`. Controls PASS: EXACT, TWINEX (`DOCS\n.txt`), AMBIG (`docs\n.txt`). Registry restored,
  identical hash.
- ZIP behaves like 7z (the item suspected ZIP's own case rules might differ - they do not).

## Decisions

- The rule is 382's `CSalamanderDirectory::ResolvePathCase` (`SalArcPathResolveCase`): exact first,
  else the listing's comparison (fold in a case-insensitive listing), in a case-sensitive listing the
  ONE folder equal ignoring case and no file of that name; the unresolved tail kept as typed. This is
  what the panel does for the same typed path (273 / 382), so the packing root equals the folder the
  panel would open. `SalArcPathRespell` (273) alone would refuse the whole path when the tail is
  missing (NEWTAIL) - not used.
- Listing: a panel showing the same archive whose recorded date and size equal the file's now (the
  stored-listing check of `salshlib.cpp`), else `PackList` (as `salshlib.cpp` paste and the 153
  edited-member check in `salamdr3.cpp`), plug-in data released as there.

## Analyze

- Round 1: HIGH C1 (the panel-listing branch had no probe row) -> row PANEL added to T008 / SC-002;
  MEDIUM I1 (the "can the format list" check missing from plan / T004) -> added; MEDIUM I2 (row
  counts) -> SC-002 / quickstart count RUN and END rows (PASS 36).
- Round 2: no CRITICAL / HIGH. Accepted LOW: U1 the Copy dialog history keeps the typed text - by
  reading (the dialog stores the history before FilesAction acts; the re-spelled root is a copy);
  U2 a stale panel listing (archive changed since listed) is re-listed - by reading, not probed.

## Implementation

- `src/common/salarcpathspell.h`: `SalArcPathApplyResolved(typed, resolved)` - lays the resolved
  names over the typed root between its optional leading / trailing `\`, only when the lengths are
  equal; writes only inside `typed`; true when a byte changed.
- `src/fileswn8.cpp`: `ArchiveCanBeListed383` (the conditions `PackList` checks before it lists:
  a plug-in with `SupportPanelView`, or an external archiver with list command and parser - else no
  listing and no message) and `RespellTypedArchiveRoot383` (a panel's `ArchiveDir` of the same
  archive - `SalPathEqualOrdinalCI` - when the file's date / size equal the panel's and the name does
  not lead elsewhere (145); else `PackList` into an own `CSalamanderDirectory` with the wait window;
  `ResolvePathCase` + `SalArcPathApplyResolved`; the own listing's plug-in data released as in
  `salamdr3.cpp`, only after a successful listing). Called in the archive branch of `FilesAction`
  after the zero-size test, only with a typed path and a non-zero-size archive, on the copy
  `packRoot[MAX_PATH]`; `PackCompress` gets `packRoot`; `path` / `secondPart` stay as typed.
  `zip.h` included for `CSalamanderDirectory` (first build: C2027 incomplete type).
- `src/saltests/saltests.cpp`: `TestArcPathApplyResolved383` - 32 checks (separators kept, length
  mismatch / empty / NULL untouched, unchanged = false, and composed with `SalArcPathResolveCase`
  over the probe's archives incl. TOOLONG at size 8 keeping the typed root).
- No UI string, dialog or resource changed (the wait window uses the existing `IDS_LISTINGARCHIVE`)
  -> no `.slt` refresh needed.
- Trap met: a Bash here-document collapsed `\\` in a Python replacement of the probe header (123's
  trap) - the replacement simply did not match; fixed with the editor, control characters checked
  (none).

## Measurements after

| Check | Command | Result |
|---|---|---|
| build | `.\build.cmd` | BUILD SUCCEEDED |
| saltests | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | `30466 checks, 0 failed` |
| encoding guard | `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)` |
| probe | `arctarget383_probe.ps1 -Label after` (hidden desktop) | **36 / 0** (`probe/result_after.txt`; before 22 / 10) |
| negative control | the call disabled (`if (FALSE && !nullFile)`) in the tree, rebuilt, probe, restored, rebuilt | **24 / 12** (`probe/result_negative.txt`: the 10 rows of before + both PANEL rows) |
| recheck | restored build, `-Only 7Z-TYPED,ZIP-PANEL` | 4 / 0 |
| 273 probe | `arccase273_probe.ps1` | 12 / 0 (`probe/regress_273_after.txt`) |
| 382 probe | `arctwins382_probe.ps1` | 24 / 0 (`probe/regress_382_after.txt`) |

Every probe run: registry restored, identical SHA-256; fixture removed; nothing left running.

## Review

### Review 1 (independent agent, refute-first) - 1 MUST, 1 SHOULD, 2 NOTE

- **MUST M1 - another letter taken as the same name, a member overwritten.** The listing's comparison
  in a case-insensitive listing (`SalDirStrCmpEx` = `StrICmpEx`, the code page's `CharLowerA` on UTF-8
  bytes) folds 0x8C to 0x9C under cp1250 / cp1252: `Č` (C4 8C) == `Ĝ` (C4 9C). Archive folder `Ĝ`,
  typed `x.7z\Č\` -> 383 packed into `Ĝ\n.txt`; with `Ĝ\n.txt` present an overwrite question came and
  (answered Yes) the member `OLDCONTENT` was replaced. New with 383 (before, the typed text went
  through unchanged). **Fixed**: `SalArcPathApplyResolved` takes a same-name callback and lays a
  resolved component over the typed one only when the file system's rule (`SalNameEqualOrdinalCI` in
  the core, `SalNameOrderCompareCI` in saltests) takes it as the same name; from the first component
  that is not, the rest stays as typed (deeper names were resolved inside the wrong folder); the
  resolution's shape (separators at the same places) is required. saltests +11 (C caron / G
  circumflex direct and composed, a real case pair C caron / c caron taken, shape mismatch, a rule
  that takes nothing). Probe rows FOLD / FOLDOW added (from the reviewer's `fold_probe.ps1`): typed
  `\Č\` into an archive with `Ĝ` -> `Č\n.txt`; FOLDOW: `Ĝ\n.txt` keeps `OLDCONTENT`, no overwrite
  question. Archive paths now listed with `-sccUTF-8`.
- **SHOULD S1 - the PANEL rows did not prove the panel branch** (the committed negative control
  disabled both branches). **Done**: branch control with only the own listing disabled
  (`if (FALSE && listing == NULL && ...)`) -> **34 / 10** (`probe/result_negative_ownlisting.txt`):
  PANEL passes on the panel's listing alone, the 10 rows without a panel fail.
- NOTE N1 - non-ASCII case pairs (`Č` typed, archive `č`) are not equal by the listing's fold and are
  still packed beside it (before and after) -> limit, spec *Assumptions*; Inbox
  `typed-archive-target-non-ascii-case-makes-a-twin` (review:383).
- NOTE N2 - an extra listing before a typed Copy / Move into an archive no panel shows (time for a
  large archive; a header-encrypted 7z may ask for its password; a listing error may come before the
  packer's error) -> accepted, the item's *Notes* name the read; limit in the closing report.
- The reviewer's last remark: the panel route opens `Ĝ` for typed `Č` (273 / 382, older) -> Inbox
  `archive-path-typed-opens-another-letter-equal-by-byte-fold` (review:383).

After the fixes:

| Check | Result |
|---|---|
| build | BUILD SUCCEEDED |
| saltests | `30477 checks, 0 failed` |
| saltests negative control (the same-name test disabled in the header) | 6 failed (the C caron / G circumflex checks and the rule that takes nothing) |
| probe negative control (same binary), `-Only 7Z-FOLD,ZIP-FOLD` (matches FOLDOW too) | 4 / 4 (`probe/result_negative_samename.txt`: `Ĝ\n.txt`; FOLDOW: overwrite question) |
| probe after | **44 / 0** (`probe/result_after.txt`) |
| branch control (own listing off) | 34 / 10 |
| restored build recheck `-Only 7Z-TYPED,ZIP-FOLD` | 6 / 0 |
| encoding guard | TOTAL: 0 |

Trap met: a Python replacement run from a Bash here-document wrote the C escapes of the new saltests
lines as real bytes and turned the file's line ends into LF (`git checkout HEAD -- src/saltests/saltests.cpp`,
redone with the editor).

### Review 2 (independent agent, refute-first) - no MUST, no SHOULD, 3 NOTE

Re-ran saltests (30477 / 0) and a scratch copy of the probe with own rows: 52 / 0 at HEAD. Data
safety of the new collision (typed `\DOCS\` now lands in an existing `Docs` holding `n.txt`): Copy
shows "Confirm File Overwrite" first (OWQ); Move answered Cancel / Skip there keeps the member's
OLDCONTENT and the source `n.txt` (OWCANCEL / OWSKIP / OWSKIPEX 12 / 0). Callers enumerated (three
`PackCompress` sites); the own listing is built as the other `PackList` callers do; `packRoot` fits.
- NOTE N1 - a plain F5 into an archive panel (the default target is the panel's own path) also runs
  the re-spelling; it reuses the panel's listing, a second listing only when the archive changed
  since it was listed - widens the accepted extra-listing limit. Accepted (closing report).
- NOTE N2 - the comment of `ArchiveCanBeListed383` said "without a message", but `PackList` can still
  report (an archive name too long for an external lister or an older plug-in) - comment corrected.
- NOTE N3 - a cancelled listing (password prompt) packs with the typed spelling - by design (FR-005).

No MUST -> no third review.
