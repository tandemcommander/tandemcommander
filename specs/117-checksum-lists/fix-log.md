# Fix log: feature 117 - checksum lists are read in the encoding they were written in

Branch `117-checksum-lists`, from `116-ftp-passwords` (47ad7fd6). Decisions by the author
(autonomy asked for): `spec.md` *Clarifications*. Measurements and code reading: `research.md`.
Pre-change build: `build\tandemcommander\Debug_x64_pre117` (copy of `Debug_x64` at 47ad7fd6,
`Intermediate` folders removed). Not committed. No GUI run (the installed program was in use; then
another agent ran GUI probes of older features) - the probe is written, its runs are owed
(`quickstart.md`). The registry was not touched.

## T001 - what was measured

- **Writers** (`research.md` A): coreutils 8.32 (Git for Windows) - UTF-8, LF, `*`, `/`, and a
  GNU-escaped line (`\<hash> *sub\\x.txt`) for a name with a backslash; 7-Zip 22.01 `-thash` -
  UTF-8, LF; PowerShell 5.1 - `>` UTF-16 LE with a mark, `Out-File -Encoding utf8` UTF-8 with a
  mark, `Set-Content` the code page **with best fit** (`voila`, `???`, `??`), all CRLF; Total
  Commander (HISTORY.TXT, not run) - code page, or UTF-8 with a mark for Unicode names.
- **The plug-in's reader** (code + primitives): code-page names "missing"; a marked UTF-8 md5/sha
  list and every UTF-16 list refused; `\\?\...\.\x` and `\\?\...\sub\..\x` -> error 123 (every
  `./` line "missing" since 004); `FindFirstFileW` matched `???.txt` to `a b.txt`, `voil?.txt` to
  `voil<U+00E0>.txt` (then an error box at the open); `GetFileAttributesExW` -> 123 for them.
- **The plug-in's writer**: coreutils `sha256sum -c` failed on every line of a 0.1.x list (CRLF),
  7-Zip refused it (comment line); LF without a comment is the only variant both read (research C).
- **Code pages**: strict `MultiByteToWideChar` converts every byte of 1250/1251/1252/852 to one
  character; 932 fails the whole call on a broken pair.

## T003-T006 - changes

| Where | What |
|---|---|
| `src/common/salcsumlist.h` (new, header-only, pure) | `SalCslDetect` (mark / UTF-16 by NUL parity / whole-file WTF-8 / code page; trailing NULs ignored), `SalCslDecode` (exact; `SAL_CSL_BADCHAR` 0xFF for an undecodable byte or unit or a NUL inside a line; NULs at a line's start or end ignored; a mark at a line start dropped; per-character fallback for a broken double-byte sequence), `SalCslNameUsable` (no controls, 0xFF, `* ? < > " \|`, no `:` except after a drive letter), `SalCslUnescapeName` (GNU; an unknown escape makes the name unusable), `SalCslBuildPath` (`/` separator, `.` / `..` / empty components, never above the drive or share; an absolute name only on the list's own drive or share, else `SAL_CSL_PATH_FOREIGN`; trailing dots kept) |
| `src/plugins/checksum/dialogs.cpp` | includes the helper; `SetDispInfoText` converts WTF-8 (`SplU8ToW`) and shows 0xFF as U+FFFD; `LoadFile` decodes with `GetACP()` and returns malloc'd text (callers `free`); `AnalyzeSourceFile` skips a leading `\` for the hash-first / tag checks (not SFV); `LoadSourceFile` builds the path with `SalCslBuildPath`, reports unusable and foreign names missing without a look-up, looks up with `GetFileAttributesExW` (no patterns; a folder is missing); `SaveHashes` opens in binary mode, md5/sha* lines end with LF and have no comment line, SFV keeps CRLF and the `;` header |
| `src/plugins/checksum/wrappers.cpp` | `CGenericHashAlgo::ParseDigest` skips the GNU escape prefix and unescapes the name |
| `src/saltests/saltests.cpp` | `TestChecksumList117` (87 checks) |

No plug-in interface change (107), no new string, no registry or configuration change, no
translation. PRIVACY.md unchanged, after review B1 (below): a list makes the program read files
only under the list's own root - inside its folder, or by an absolute name on the same drive or
the same `\\server\share` the list itself was read from - so **no server is contacted that the
list's own location did not already involve**. (Unchanged since Open Salamander: a directory
link inside the list's folder is followed by the file system wherever it points.) Nothing is
stored or protected differently. The first version of this feature did contact any server a list
named (B1) - fixed before any release.

## T007 - tests

saltests 14,441 -> **14,528 / 0** (`TestChecksumList117`): every detection outcome (UTF-8 with and
without a mark, UTF-16 LE/BE with and without, code page, empty, a lone surrogate keeps UTF-8, an
overlong sequence makes it code page, one UTF-8 line + one code-page line = the whole file code
page); exact conversion (CJK, a surrogate pair, a lone surrogate from UTF-16; a cut-off unit and
U+0000 -> 0xFF; a broken byte in a marked file; a stray NUL; marks at line starts dropped, inside
kept; `voil<E0>` is a-grave in 1252 and r-acute in 1250 - never `voila`; Cyrillic 1251; OEM 852
when asked; a broken 932 pair is one 0xFF and the next line survives); **every byte 0x80-0xFF of 18
code pages** decodes to exactly Windows' character or 0xFF, never to ASCII; the name rule (17
cases); the GNU escape; 25 path cases (`./`, `.\.\`, `sub/../`, `a//b`, `../`, clamping at the
drive and the share, absolute drive and UNC, trailing dot / space kept, `...`, `.`, buffer exactly
fitting and one byte short).

## T008 - probe and offline model

- `probe/make_lists117.py <dir>`: data files (Czech, Cyrillic, CJK, lone surrogate, the decoys
  `voila.txt` and `abc.txt`, `sub\<r-caron>.txt`), 13 lists in the measured forms, the round-trip
  folder, `expected117.json` (each row's verdict for both builds). Hashes cross-checked with GNU
  `sha256sum -c` (utf8, dotslash, gnu_escape all OK).
- `probe/csumlist_probe.ps1`: hidden desktop only; focuses each list, Ctrl+Shift+V, serves error
  boxes with Skip (never Retry), reads the Verify list view in the target process (LVM_GETITEMW
  with remote memory: icon = OK / CORRUPT / MISSING, status text = SKIPPED, name with lone
  surrogates kept); the round trip through Calculate > Save (.sha256 and .sfv), the saved bytes,
  Verify of both, `sha256sum -c` and `7z t -thash`. `-Expect before` predicts the old behaviour
  row by row. Parses (PowerShell parser), pure ASCII.
- `probe/m117_model.cpp` (+ `build_model.cmd`, `run_model.py`): not the plug-in - the plug-in's
  read path rebuilt on the product's helper (decode, the same line forms, the escape, the path,
  the usable-name rule, `GetFileAttributesExW`, BCrypt / CRC-32 hashes) over the real fixture
  files: **48 rows, 0 mismatches** with `expected117.json` (`after`), the names shown included.

## T009 - gates

Debug x64 and full Release x64 builds exit 0, 0 compiler warnings; saltests 14,528 / 0; strict
guard TOTAL 0; new header UTF-8 BOM + CRLF and clang-formatted; changed `.cpp` files keep BOM +
CRLF and are clang-format clean (dialogs.cpp, wrappers.cpp: 0 differing lines). The saltests block
is not clang-formatted (it would split the concatenated byte literals; the file has ~990
pre-existing differing lines).

## T010 - hostile re-read

- **The substitute byte, first version replaced before any build**: 0x1A (SUB) was the first
  choice. It is <= space, so `LTrimStr` would have stripped it at a line start and an SFV name
  `<undecodable>ame.txt` would have become `ame.txt` - **another file**. 0xFF is never valid UTF-8
  and not white space: the line keeps its shape and the name is refused.
- `IsDBCSLeadByteEx(CP_ACP, ...)` is not documented for CP_ACP -> the plug-in passes `GetACP()`.
- Allocation: per encoding (UTF-8 n, UTF-16 1.5 n, code page 3 n) instead of 3 n for all (a
  500 MB list); a code page yielding more units than bytes (none known) reallocates.
- Behaviour changes, deliberate: `..` above the list's folder is resolved (clamped at the root)
  and absolute names are looked up. **This re-read judged the absolute names "not a boundary"
  (Verify only reads and compares for the same user) - wrong: the code review found that a UNC
  name makes Windows connect to the server and send the user's credentials (B1, T014). Corrected:
  only the list's own drive or share.** A folder is "missing" instead of an error box. The
  md5/sha header comment is gone (CHANGELOG says so).
- Unchanged on purpose: an SFV line starting with `\` is still relative (no GNU escape in SFV);
  trailing dots/spaces are literal (102); case follows the volume (092 - the file system decides).
- Residual risks recorded: a code-page list that is valid UTF-8 by accident is read as UTF-8; an
  OEM list's accented names are "missing" (or, if the code-page reading names an existing file,
  that file is checked and almost surely CORRUPT); a UTF-32 list is not read.
- Process note: once `sed -i` was used on the probe's `build_model.cmd` (one redirect); the file
  was checked (ASCII) and re-saved with CRLF.

## T014 - code-only review: REJECT (1 BLOCKER, 1 SHOULD-FIX), fixed

The reviewer confirmed: no best fit, the 0xFF marker safe, an ASan fuzz of decode / paths clean,
the existence check without patterns, the saving.

- **B1 (privacy / security, measured by the reviewer)**: `IsAbsoluteName` took every name that
  starts with two separators (`\\host\share\...`, `//host/share/...`, `/\host\...`) as an
  absolute UNC path and `GetFileAttributesExW` was called on it: a hostile list made Windows
  connect to any SMB / WebDAV server with the user's credentials (NTLM hash), opened
  `\\localhost\C$\Windows\win.ini`, tried WebDAV at `\\127.0.0.1@80\x\y`, and an unreachable
  `\\server\share\x` blocked the dialog thread about 10 s per line. Before 117 `SalPathAppend`
  dropped one `\` and everything stayed under the list's folder. **Fix**: `SalCslBuildPath`
  returns `SAL_CSL_PATH_FOREIGN` for an absolute name whose root (the drive, or `\\server\share`)
  is not the list's own root, compared by `CompareStringOrdinal(..., TRUE)` (feature 092's rule);
  every two-separator spelling counts (`\\?\UNC\...`, `\\?\C:\...`, `\\.\pipe\...`,
  `\\\srv`, mixed slashes) - the plug-in reports the name missing **without any file-system call**
  (no look-up, no open, no link-size query, and the Focus button acts only on existing files).
  Stricter than asked: a drive-absolute name on **another** drive is foreign too (a mapped drive
  letter is a network share - the list's own drive involves no new server). saltests: 16 foreign
  spellings, same-share and same-drive acceptance (case-insensitive), `..` clamping at the share.
- **S1 (measured)**: one trailing NUL refused the whole list (0.1.8 verified it - its text ended
  at the NUL): the NUL became a 0xFF "line"; a NUL ending the last line appended 0xFF to that name;
  an 80-byte UTF-8 list + 11 / 13 / 21 NULs of padding was detected as UTF-16. **Fix**: trailing
  NULs do not take part in the detection; BOM-less UTF-16 needs one parity to dominate (the other
  parity at most 1/8 of it) and at least 1 NUL in 16 bytes; in every encoding a run of NULs at a
  line's start or end is ignored. **Deviation from the review's suggestion** ("treat a NUL as a
  line end"): a NUL **inside** a line stays one 0xFF and the line is not cut there - cutting
  `voil<NUL>a.txt` would name `voil`, another file. saltests: padding of 1 / 11 / 13 / 21 / 64
  NULs (UTF-8 and code page), NULs at line starts and ends, inside a line, UTF-16 with NUL units
  and a padding byte, parity dominance both ways.
- **N1**: a `:` anywhere but right after the drive letter of `X:\` / `X:/` makes the name unusable
  (`file.txt:secret` - a stream, `C:name` - another drive's current folder): missing, no open.
- **N2**: the header documents that device safety rests on the `?` rule plus the two-separator
  rule (`\\?\...`, `\\.\pipe\...`) and the plug-in's `\\?\` prefixing; never relax either
  without a device guard (a named pipe would hang the worker).
- **N3**: an unknown GNU escape or a lone trailing backslash puts 0xFF in the name (missing), as
  coreutils rejects such a line.
- **N4 (recorded)**: with the system code page set to UTF-8 (65001, "Beta: use Unicode UTF-8"), a
  list that is not valid UTF-8 goes the code-page way, whose strict conversion fails for every
  non-UTF-8 byte: each becomes 0xFF and those names are missing - correct (there is no other
  code page to try; OEM is not guessed).
- **N5 (recorded, in the header)**: peak memory of a Verify is about 6x the list's size for a
  code-page list (raw bytes 1x + UTF-16 2x + output up to 3x), about 3x for UTF-8 / UTF-16; with
  the plug-in's 500 MB limit up to about 3 GB on x64. Not reduced (no measured need).
- Probe: two lists added (`absolute.sha256`: own drive OK, another drive / `//127.0.0.1/...` /
  `\\?\UNC\...` / a stream MISSING; `nul_tail1.sha256`, `nul_tail11.sha256`: OK on both builds).
  The probe cannot observe a network connection; the refusal is proven by saltests and by the
  model (no look-up for a foreign name). Model 58 rows, 0 mismatches.
- Gates after the fixes: Debug + full Release builds exit 0, 0 warnings; saltests 14,528 ->
  **14,576 / 0**; strict guard 0; header clang-formatted, BOM + CRLF.

## T015 - code-only re-review: ACCEPT (pending GUI)

The reviewer's harnesses on the fixed code: one gate before anything touches the disk; foreign names
keep no path (worker skips them, Focus refused); the own-share comparison is text-only and was not
spoofable (`\\server\share.evil`, trailing space/dot, `@SSL`, `@80`, `server.`, `..` in the server
part); `..` never climbs above the share; a list on `Z:\` rejects `\\server\share\x` even if `Z:` maps
there (cautious); 2,000,000 random names - every accepted path stays under the list's own root.
Trailing NULs: 5-21 zero bytes after a UTF-8 list read as UTF-8; real BOM-less UTF-16 still detected;
decode fuzz under ASan clean. NIT recorded: a NUL at the START of a line is dropped, so an SFV line
`<NUL>abc.txt 1234abcd` checks `abc.txt` - acceptable (a NUL cannot be part of a Windows name; the
usual cause is a string terminator after the previous line; the checksum is still compared against
that file's contents). Still in place (recorded): a symbolic link inside the list's own folder is
followed for size and hashing (unchanged since Open Salamander).

Committed after this check with the GUI runs still owed; the build is preserved as
`build\tandemcommander\Debug_x64_117` (checksum.spl 23:48). Results follow in a separate commit.

## Found by 117, not fixed (NEXT-WORK)

- A list line whose resolved path does not fit 780 bytes (`FILEINFO::fileName`, 3 x MAX_PATH)
  aborts the whole Verify with "name too long" (pre-existing).
- OEM lists (decision, research E2).

## T012 - GUI results (2026-10-06, hidden desktop)

Runs on the preserved trees, one at a time, registry export SHA-256 `1AB614304771DBE0...` before
and after every run (the maintainer's baseline that morning; the probe's own restore also reported
identical every time); no network mapping touched; nothing built.

| Build | Expect | Rows | Result file |
|---|---|---|---|
| `Debug_x64_117` | fixed | **82 PASS / 0 FAIL / 0 NOT DRIVEN** | `probe/csumlist_result.txt` |
| `Debug_x64_pre117` | before | **60 PASS / 0 FAIL / 0 NOT DRIVEN** | `probe/csumlist_result_pre117.txt` |

- **This build**: all 16 lists as expected with no box at all - the control, UTF-8 with a mark,
  UTF-16 LE/BE with and without a mark, the GNU escape, concatenated lists, `./` / `..` / `//`,
  the code-page lists (c-caron and r-caron OK, `voila.txt` CORRUPT - the writer's best fit, never
  matched back to voila-grave - `???.txt` MISSING, not `abc.txt`), the broken byte (`voil<U+FFFD>`
  MISSING), wildcards and a folder MISSING, absolute names (own drive OK; another drive,
  `//127.0.0.1/...`, `\\?\UNC\...` and a stream MISSING), trailing NULs OK; lone-surrogate names
  shown exactly (`lone<U+D800>.txt`). Round trip: the saved `.sha256` has no mark, no CR, no
  comment, 7 lines; the `.sfv` CRLF with the `;` header; Verify of both 7 x OK; Git for Windows
  `sha256sum -c` exit 0 with 7 OK; `7z t -thash` "Everything is Ok". END rows: exit 0, no stray
  window, no crash report.
- **The build before** (each row shows the old defect): the 7 marked UTF-8 / UTF-16 / escaped /
  concatenated / broken lists refused ("The selected file is not a valid SFV, MD5, SHA-1, SHA-256,
  nor SHA-512 file"); code-page c-caron and r-caron MISSING; `???.txt` and `voil?.txt` found by
  wildcard, then an error box (Retry / Skip / Skip All) and SKIPPED; the folder `sub` SKIPPED after
  an error box; `dotslash` 5 x MISSING; the own-drive absolute name MISSING; trailing NULs OK (as
  the review said); its saved `.sha256` CRLF + `;` header: `sha256sum -c` exit 1 ("2 lines are
  improperly formatted", "7 listed files could not be read"), 7-Zip "Cannot open the file as
  [Hash] archive"; its own Verify of both lists 7 x OK.

**Probe-only fixes during the runs** (no product change; run 1 of this build was 74 / 4):
1. Expected names travel also as UTF-16 code units (`name_units`): Windows PowerShell 5.1's
   `ConvertFrom-Json` turned the escaped lone surrogate into U+FFFD, the product showed
   `lone<U+D800>.txt` correctly (2 rows).
2. The save dialog is the common item dialog: no type combo id 1136 and no field id 1148 (the
   field is an edit id 1001 in an unnamed combo); it builds its file-name area late on the hidden
   desktop - the probe waits for the window, then the field, and finds the type combo by its items.
3. `WM_SETTEXT` changed the field's text but not the name the dialog used (it saved "rt" - the
   plug-in's default name - and asked about "C:\Program Files\Notepad++\rt"); the probe now types
   (`WM_CHAR`), navigating to the folder first, then the bare name; questions after OK are answered
   (task-dialog buttons have id 0 - by their text; text read by UI Automation for the record).
4. Git's `sha256sum.exe` fails without valid standard handles on the hidden desktop ("failed to
   set file descriptor text/binary mode"): both tools run through `cmd /c` with redirections.

**Found during the runs, not fixed (product, pre-existing - both builds)**: the Calculate dialog's
Save dialog does not open in the panel's folder: it opened in the folder last used by another
program's common dialog (`C:\Program Files\Notepad++`) although the plug-in passes the panel folder
as `lpstrInitialDir` - Windows ignores that member when it has a remembered folder for the
dialog and `lpstrFile` holds a bare name (the plug-in's default "rt"). Saving with the proposed
name writes the list into that other folder (a non-writable one there: Windows asked to save into
the user folder instead). Fix direction: put the panel folder into `lpstrFile` (full default
path). For NEXT-WORK (not edited here: outside this folder).

## Proposed CLAUDE.md entry (Recent Changes)

- 117-checksum-lists: **checksum lists are read in the encoding they were written in** (NEXT-WORK
  plug-in leftovers item 4, from 104). Measured first (`research.md`): coreutils and 7-Zip write
  UTF-8, PowerShell 5.1 writes UTF-16 LE with a mark (`>`), UTF-8 with a mark (`Out-File -Encoding
  utf8`) or the code page with best fit (`Set-Content`: `voila`, `???`), Open Salamander and Total
  Commander the code page (TC: UTF-8 with a mark for Unicode names). The plug-in read only plain
  UTF-8: code-page names "missing", marked UTF-8 and UTF-16 md5/sha lists refused; every `./x` /
  `dir/../x` line "missing" since 004 (`\\?\` keeps `.` and `..`); the existence check was
  `FindFirstFileW` - `???.txt` matched `abc.txt`; its own md5/sha lists were unreadable by
  coreutils (CRLF) and 7-Zip (comment line).
  - **Rules** (`src/common/salcsumlist.h`, header-only): the encoding is decided **once per file**
    (mark; UTF-16 by NUL parity with strong dominance; UTF-8 if the whole file is WTF-8; else
    `GetACP()`; trailing NULs ignored), never per line; OEM never guessed; exact conversion, an
    undecodable byte -> 0xFF (`SAL_CSL_BADCHAR` - not 0x1A: white space is trimmed at a line start
    and would name another file) and the name is "missing" (shown U+FFFD); a NUL inside a line is
    0xFF, never a line end (a cut name is another file's); names with controls, `* ? < > " |` or a
    `:` (streams) are "missing" without a look-up; `GetFileAttributesExW` (no patterns, a folder
    is missing); `.` / `..` / `//` resolved, never above the drive or share; **an absolute name is
    used only on the list's own drive or share - any other, every UNC / `\\?\` / `\\.\` spelling
    included, is "missing" without any file-system call** (review B1: a UNC look-up connected to
    any server a list named and sent the user's NTLM hash); GNU-escaped lines unescaped.
  - **Writing**: md5/sha* lists UTF-8, LF, no comment line (coreutils and 7-Zip read them); SFV
    unchanged.
  - saltests 14,441 -> 14,576 (all single bytes of 18 code pages: never ASCII). Offline model
    `probe/m117_model.cpp` 58 / 0. Code-only review: REJECT (B1 above; S1: one trailing NUL
    refused a list 0.1.8 read), fixed. Probe `probe/csumlist_probe.ps1` written, runs owed. Found,
    not fixed: a path over 780 bytes aborts the Verify. Interface stays 107. Records:
    `specs/117-checksum-lists/fix-log.md`.
