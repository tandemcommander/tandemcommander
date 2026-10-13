# Fix log: feature 131 - defects found while fixing the plug-in messages

Branch `131-plugin-defect-batch` from `130-plugin-mixed-templates`. Session 2026-10-13, asked
for by the maintainer. The input was the list feature 130 left in `specs/NEXT-WORK.md` and in
the "Other defects seen" sections of its triage files - notes made by reading.

## 1. Method

`agent-brief.md`: per item measure first (real? reachable? - by reading, and by small test
programs outside the repository where reading is not enough), fix minimally, record. Four
work packages in parallel in disjoint directories, without a build; the core and the
translations by the session. One record per plug-in: `items/*.md`.

## 2. Verdicts

| Plug-in | Item | Verdict |
|---|---|---|
| pictview | `thumbs.cpp` path cut at `_MAX_PATH`, no terminator, then used | **fixed** (measured); paths in `CSalMaxPathBuffer`, a name that does not fit refused |
| pictview | code-page path handed to the WIC engine | **fixed** (measured: *Update Thumbnail* could not open any accented name) |
| pictview | `InitEXIF` write through NULL + 1 | **fixed** (measured with code page 932) |
| pictview | image comment through an `A` call | not a defect (the branch never runs) |
| diskmap | `CZStringBuffer::AppendAt` off by one; the directory line's buffer | **fixed** (measured with the debug heap); a long root left the line empty and its menu acted on `\sub` |
| peviewer | narrow `%ls` in the dump | **fixed** (measured: the call fails at the first letter above U+00FF, the rest of the line is lost) |
| sftp | paths cut and then used (`PosixPathAppend` and 18 callers, local joins) | **fixed**: a join that does not fit returns nothing, the caller refuses (`IDS_TOOLONGPATH`), a move deletes nothing |
| sftp | no or stale error reason (10 operations) | **fixed**: the server's status is read (`SetLastErrorFromSftp`) |
| sftp | English literals | one replaced by an existing string; the rest listed (new strings are not allowed here) |
| ftp | `operats6.cpp:1472`, `fs2.cpp:466/623/724`, `operats2.cpp:2465` | **unreachable / not defects**: the core limits a typed user part to 259 bytes; `char` is unsigned in every plug-in (`/J` in `plugin_base.props`, proved from the build log) |
| ftp | a `%` in a host name used as a printf directive | **fixed** - **0.1.9 crashes** (probe) |
| ftp | Logs combo item: unbounded `sprintf` into 300 bytes | **fixed** |
| ftp | Quick Rename with a mask: a long name cut and the file renamed to the cut name | **fixed** (refused) |
| ftp | AS/400 upload name cut | fixed (cannot be probed) |
| filecomp | font description `sprintf` into the 32-byte `lfFaceName` | **fixed** |
| regedt | unbounded `vsprintf` in the error helper | fixed (hardening: no caller of today overruns it) |
| regedt | regular-expression error used as a format, unrelated system text appended | **fixed** |
| regedt | `fs3.cpp` buffer size arguments | fixed (effect unreachable today) |
| zip | favourite names: two encodings | **fixed**: UTF-8 from the dialog to the registry and back |
| zip | 50-byte load buffer | **fixed** - a name of 25 accented letters did not load and **the favourite with its options was deleted at the next save** |
| zip | `.set` file: paths written as UTF-8 for a reader of code page | **fixed**; import accepts both |
| zip | unbounded prefix copies | fixed |
| 7zip | `SetWindowText` (A) of the archive path | not a defect (the control is the core's `CStaticText`, which reads the bytes as UTF-8); the cut of the shown path fixed |
| 7zip | `((int*)&err)[1]` | **fixed** (measured: an unwritten stack value chose the plural form) |
| undelete | virtual folder names as code-page text | **fixed**: one UTF-8 name for listing, path parsing and restore |
| undelete | wrapper of the core's subject text | recorded (needs the core) |
| renamer | stale Windows reason behind logical errors | **fixed** (`FileErrorHasSystemReason`, all 27 callers read) |
| renamer | histories read with 260 bytes for fields of 520 / 4,096 | **fixed** (found on the way: one long item ended the list at every start) |
| renamer | plural text into an `A` call | not a defect |
| core | `CheckAndCreateDirectory`: three templates still code page with a UTF-8 path (`errBuf` for ZIP) | **fixed** |
| core | subject of a plug-in's dialog: name cut at `MAX_PATH` bytes | **fixed** |
| translation | Spanish 7-Zip "es Aceptar" | **fixed**, pinned |
| translation | "SFTP error %d: %s" wrong in seven languages (shown since this feature) | **fixed**, pinned |

## 3. Traps met

- Half of the FTP notes rested on a wrong premise: the triage looked for the `char` signedness
  in the FTP project files; `/J` comes from the shared property sheet.
- `SetWindowTextW` is not always the fix for an `A` call: a control of the core's `CStaticText`
  takes the bytes of `WM_SETTEXT` as UTF-8 - the `A` call delivers them unchanged, the `W` call
  would arrive as code page with `?`.
- The control run on 0.1.9 crashed and left a bug report in `%LOCALAPPDATA%\Tandem Commander` -
  removed again.
- The probe timed out twice in the tool (600 s) when four probes were chained; they finish in
  the background.

## 4. Independent reviews (three, read-only, refute-first) - no blocker

- **ZIP, a small regression - fixed**: favourite names are UTF-8 now but were still compared
  with `StrICmp`, which folds every byte through the code page's table, continuation bytes too:
  `VÍR` and `VÝR` were "the same name" (proved on code page 1250). Now
  `SalNameOrderCompareCI`. (The author's record said `StrICmp` folds ASCII only - wrong.)
- **Core, a missed site - fixed**: the third use of `IDS_NAMEUSEDFORFILE` (the target itself
  is a file - the branch ZIP hits most often) was still code page.
- **SFTP - fixed**: one of the 19 callers of `PosixPathAppend` did not check the result (the
  link target lookup of the listing; harmless, read-only); `LocalPathAppend` with an empty
  directory gave `\name` (the root of the current drive) - refused now; the "SFTP error"
  sentence, unused until now, is wrong in seven of eight languages.
- Sound: every refusal comes before anything is sent or deleted; a move does not delete after
  a refused item; a parent is not removed after a refused child; Undelete uses one name string
  for listing, parsing, sorting and the folder on disk, and never compares a name with
  `LoadStr`; old favourite names load right (the registry holds UTF-16); the claim "deleted at
  the next save" holds; `va_arg` types match both call sites; the FTP escape is correct and no
  other non-literal format exists in the plug-in.
- Notes kept (NEXT-WORK): see section 6.

## 5. Tests

| What | Result | Record |
|---|---|---|
| probe `batch131_probe.ps1`, 0.1.9 | **FAIL: the program crashes** (access violation, bug report) | `probe/batch131_result_before_v019.txt` |
| the same, final build | PASS 2, FAIL 0: `Unable to get IP address of server "tc131-%s-%d-%s.invalid"` | `probe/batch131_result.txt` |
| probe of 130 in Spanish (test rows) | PASS 4, FAIL 0: `... está correcto.` | `probe/plugmix130_result_spanish.txt` |
| regressions on the final build: 130 Czech, 129, 127, 113 | 19 / 0; 19 / 0; 19 / 0 (3 not driven); 37 / 0 | |
| regression 117 (Checksum) | 82 / 0 (before the review fixes, which do not touch it) | |
| SFTP unit harness | 85 passed, 0 failed (23 new) | `src/plugins/sftp/test/` |
| the authors' test programs | results quoted in `items/*.md`; sources in `probe/pictview-diskmap-peviewer/` | |
| saltests | 18,471 checks, 0 failed | |
| `tools/check_encoding.py` | `TOTAL: 0` | |
| Debug (`build.cmd full`) and Release (`build.cmd full release`) | clean | |
| product registry key | identical before and after every run | |

**Not driven in the program** (measured by test programs or read only; owed to a person or a
later probe): everything in SFTP against a server (Docker was not running; rows R1-R5, P1-P5
in `items/sftp.md`), PictView *Update Thumbnail* on an accented path, DiskMap on a deep CJK
folder, the PE Viewer dump of a file with an accented version key, ZIP favourites (a long name
survives a restart; `VÍR` / `VÝR`), the `.set` round trip with `zip2sfx.exe`, Undelete (needs a
volume to scan), Renamer ("Duplicate name." alone), the Registry Editor's Find with `(`, the
File Comparator's font field, FTP Quick Rename and the Logs combo (need a server).

## 6. Left (in `specs/NEXT-WORK.md`)

- PictView: `jpeg_data_save_file` writes whatever part of a malformed JPEG was parsed and
  reports success - *Update Thumbnail* could replace such a file by a truncated one; far more
  files reach that stage now that accented paths open. Nothing checks the output.
- SFTP: a listing ends silently at a name of 2,047 bytes or on a read error (a recursive
  download or move then works on an incomplete listing); `UploadDirRecursive` holds about 30 KB
  per level (a tree about 100 levels deep against a 3 MB stack); the panel is not refreshed
  after a partly failed move; untranslated literals.
- FTP: download autorename shortens a name at a byte offset (`operats5.cpp:1188-1193`,
  `1594-1602`); the core cuts a typed Quick Rename name at 259 bytes (`fileswn5.cpp:2640`).
- DiskMap: `CZFile::GetFullName` skips a path part that does not fit and appends the next (a
  name over 780 bytes; the result goes to the shell menu).
- PE Viewer: letters outside the code page are `?` in the dump (the dump would have to be
  UTF-8 with a BOM, about 50 lines - a decision).
- ZIP: an imported code-page `.set` whose bytes happen to be valid UTF-8 is misread.
- Renamer: two remaining stale reasons (`rendlg.cpp:1344`, `rendlg3.cpp:301`).
