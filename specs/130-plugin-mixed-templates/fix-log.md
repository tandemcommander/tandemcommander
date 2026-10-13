# Fix log: feature 130 - plug-in messages with names and error texts

Branch `130-plugin-mixed-templates` from `129-regedt-wide-inserts`. Session 2026-10-13, asked
for by the maintainer ("mixed templates in the plug-ins ... split by plug-in"). The follow-up of
GitHub issue #7 that feature 127 left to the plug-ins.

## 1. Inventory and split

`scan_mixed.py --plugins`: 400 compositions with a `LoadStr()` template in the 20 enabled
plug-ins, 131 with a name or error-text argument (FTP 86, SFTP 17, ZIP 15). The scanner sees
only printf calls with an inline `LoadStr`, so every use of `LoadStr(` was read instead, per
plug-in, by four agents working in parallel in disjoint directories (no build, no GUI), each
writing a record `triage/<plugin>.md`: every composition, its pieces and sink, the verdict.
A fifth agent read FTP and changed nothing.

## 2. Measure first

`probe/plugmix_probe.ps1` on 0.1.9 (`Debug_x64_v019`), hidden desktop:

| Row | 0.1.9, Czech |
|---|---|
| CSUM - Checksum, Save over an existing file | `Soubor '...\PĹ™Ă­liĹˇ ĹľluĹĄouÄŤkĂ˝ kĹŻĹ.sha256' již existuje.` - the question names garbage |
| DBV - Database Viewer title | `...\PĹ™Ă­liĹˇ ... .dbf - Prohlížeč databází` |
| PVW - PictView title | the same, `... - Prohlížeč PictView` |
| PEV - PE Viewer caption | the same, `... - Prohlížeč spustitelných souborů` |
| ZIPTEST / 7ZTEST - Test Archive | **pass in Czech** - `Archiv '%s' je OK.` has no accented letter; **fail in Slovak** (`Archív '...' je OK.`) |

So the premise holds, and it also shows why it was not noticed everywhere: a sentence without
an accented letter works by accident, language by language. English: the same texts on both
builds.

First idea for the archivers that did not work: holding the archive open without sharing and
entering it - the **core** reports that (its own dialog), the plug-in is not reached. A file
that is no archive gives a plug-in message without any name; those three rows stay as controls
of the changed error helpers.

## 3. The change

Shared: `src/plugins/shared/splloadstru8.h` (new, header-only) - `SplLoadStrU8` (per-module
cache, converted once, pointer valid until unload, any thread), `SplLegacyToU8Alloc`,
`SplLegacyToU8`. Each changed plug-in has `const char* LoadStrU8(int resID)` next to its
`LoadStr`.

| Plug-in | Fixed | What |
|---|---|---|
| 7zip | 9 sites | `Error` / `SysError` helpers (`SysError` was mixed at all 11 calls), the three Test Archive texts, extraction errors |
| checksum | 2 | the overwrite question; `Error()` (its `FormatMessage` A text converted) |
| tar | 13 | every "text + Windows reason" sentence (`LoadErr`, 19 callers), progress lines, RPM viewer caption |
| uncab | 3 | progress line, two progress titles |
| uniso | 16 | both `Error` helpers and their callers, viewer caption |
| zip | 15 | `ProcessError` (43 callers; three unbounded `sprintf` gone), seven progress titles, progress line prefixes, Test result, comment dialog title (it was **not set at all** with an accented template), self-extractor messages |
| sftp | 30 + 13 | `LastErrorText` is UTF-8 at every writer; all sentences with host, user, key file, path, remote name; the log (one text - a single code-page line garbled every path in it) stores UTF-8 lines; remote names (the server's bytes) through `CSFTPMsgText` |
| renamer | 1 helper | `FileError` (28 callers): template + `GetErrorText` |
| dbviewer | 1 | window title |
| pictview | 6 | window title, open error, proposed Save As name (**empty** for a captured image in Czech), rename subject, print error (an overflow of `errBuff[164]` gone), thumbnail error |
| peviewer | 5 | viewer caption, four open errors |
| diskmap | 1 | window title composed wide (Spanish: the path was dropped) |
| portables | 1 | change-path error |
| filecomp, regedt, codeview, mdview, folders, undelete | 0 | right as they are / recorded |

Core, `src/zip.cpp`: the progress dialog a plug-in opens set its title with `SetWindowText` (A) -
an archive name was wrong there in **every** language, English too, for every plug-in. Now
UTF-8-or-code-page -> wide -> `SalSetWindowTitleW`. A progress line cut at 299 bytes ends at a
whole character (only when the rest is UTF-8).

## 4. Traps met

- The helper used a slim lock; some plug-ins compile for a Windows version whose headers do
  not declare it - a critical section instead.
- A variable named `small` in saltests: the Windows headers define it as `char`.
- A project built alone with MSBuild puts its output under `src/vcxproj/...` (no
  `OPENSAL_BUILD_DIR`) - removed again.
- A Python here-document in Bash lost the backslashes of a probe edit once more (the assertion
  caught it before anything was written); edits go through script files.
- ZIP's first version set the progress title twice from the plug-in (once for the core's A
  call, once wide). Fixing the core's dialog is one place for all plug-ins.

## 5. Independent review (two reviewers, read-only, refute-first)

- **SFTP, one real regression - fixed**: `operats.cpp` download error. The template became
  UTF-8, the local path was passed raw - and on download it ends with the remote name, the
  server's bytes. A Latin-1 name made the text invalid UTF-8, so the whole box, the UTF-8
  template included, went through the code page: a sentence that was readable before would
  have been garbled. Now through `CSFTPMsgText`, like its neighbours. (The triage row called
  that path UTF-8; it is for upload only.)
- Fixed: the log's tail trim ran on every line; `SplU8TrimTornTail` drops a final letter
  >= 0xC0 of code-page text - now only when the line was cut. The same for the core's progress
  line.
- Fixed: `triage/zip.md`, `uncab.md`, `checksum.md` described the progress title before the core
  change - a correction note on top.
- Sound (read by the reviewers): every UTF-8 composition ends in a sink that shows valid UTF-8;
  no UTF-8 template reaches an A-only sink, a file, a byte-wise compare or a later format
  string; every caller of the changed helpers; every `_snprintf_s(buf, _TRUNCATE, ...)` on a
  real array, none used as a path afterwards. The helper: 8 threads, 1.6 million calls, 3,000
  ids, a rotating source buffer - no wrong text (the reviewer's own program).
- Notes kept: a text is cached from the core's rotating `LoadStrW` buffer after the core's lock
  is released (about 10,000 characters of other threads' texts in between would be needed);
  code-page text that happens to be valid UTF-8 is taken as UTF-8 (inherent to the rule); with
  no memory a piece converted by `SplLegacyToU8` is empty; `tar` compositions of "prefix +
  Windows text" have no tail trim (1,000 bytes); three old unbounded prefix copies in ZIP.

## 6. Tests

| What | Result | Record |
|---|---|---|
| probe, 0.1.9, Czech | PASS 15, **FAIL 4** (CSUM, DBV, PVW, PEV) | `probe/plugmix_result_before_v019_czech.txt` |
| probe, 0.1.9, Slovak (test rows) | PASS 2, **FAIL 2** (ZIPTEST, 7ZTEST) | `probe/plugmix_result_before_v019_slovak.txt` |
| probe, final build, Czech | **PASS 19, FAIL 0** | `probe/plugmix_result_czech.txt` |
| probe, final build, Slovak | **PASS 4, FAIL 0** | `probe/plugmix_result_slovak.txt` |
| probe, English, both builds | PASS 19, FAIL 0; the texts identical | `probe/plugmix_result_english.txt`, `..._before_v019_english.txt` |
| regression: 127 (core messages, Czech) | PASS 19, FAIL 0, 3 not driven (clipboard) | |
| regression: 117 (Checksum lists) | PASS 82, FAIL 0 | |
| regression: 113 (ZIP read errors) | 37 PASS, 0 FAIL | |
| saltests | 18,471 checks, 0 failed (18,447 before; `TestPluginLoadStr130` = 24) | |
| `tools/check_encoding.py` | `TOTAL: 0` (it does not read the plug-ins) | |
| Debug and Release (`build.cmd full release`) | clean | |
| product registry key | identical before and after every run (SHA-256 `2865657F...`) | |

Driven by the probe: Checksum, 7-Zip, ZIP, Database Viewer, PictView, PE Viewer (names), and
7-Zip, UnISO, TAR (control messages of the changed helpers).

**Not driven** - read by the authors and the reviewers only, owed to a person or a later probe:
SFTP (needs the test server `tandem-sftp`), Renamer (a file held by another program), DiskMap
(German / Spanish title), Portables, UnCAB (French line), TAR's skip line and RPM caption, UnISO
with a name, the ZIP comment dialog title, PictView's Save As name / rename / print error, and
**the progress dialog's title** (the core change; it is on screen only while an operation runs).

## 7. Left

- **FTP** (`triage/ftp.md`): about 104 sites in eight steps; needs a local FTP server whose
  replies and listing bytes can be chosen, and the maintainer's decision about the log (its
  bytes in a saved file change from mixed to UTF-8). The next feature.
- `GetCommonFSOperSourceDescr` (core) still hands FTP and Undelete a mixed text.
- Defects seen on the way, not fixed (each `triage/*.md`, section "other defects"; the serious
  ones copied to `specs/NEXT-WORK.md`).
