# 096 research: an edited file with a non-ASCII name is not packed back into its archive

Measurement only (2026-10-02, branch `095-archive-path-buffers`, HEAD `426c6977`).
No product source was changed, nothing was rebuilt, nothing was committed.

## Verdict

**Confirmed.** When a file whose **name contains any non-ASCII character** is
opened from an archive for editing (F4) or through its association (Enter) and
is changed, the program does not show the *Archive Update* dialog when the
archive is left or the program is closed, the archive keeps the old content,
and the temporary copy holding the edit is deleted at that moment. The edit is
lost without any message.

- Affected: every name with at least one non-ASCII character - inside the code
  page (`článek.txt`, `ř.txt`) and outside it (Cyrillic) alike, at any length
  (6 bytes to 150 bytes measured). ZIP and 7z alike (the defect is in the core).
- Not affected: ASCII names, names with a space, and an ASCII name inside a
  folder with an accented name (the folder is not part of the temporary path).
- Same on the current Debug build and on `Debug_x64_pre094`.

## Cause

`src/salamdr3.cpp:3377`, in `CFileTimeStamps::CheckAndPackAndClear`:

```cpp
char buf[MAX_PATH + 100];
WIN32_FIND_DATA data;                                   // ANSI structure (core has no UNICODE)
...
sprintf(buf, "%s\\%s", item->SourcePath, item->FileName);   // UTF-8 + UTF-8
BOOL kill = TRUE;
HANDLE find = HANDLES_Q(FindFirstFile(buf, &data));     // FindFirstFileA on a UTF-8 path
if (find != INVALID_HANDLE_VALUE) { ... compare time and size ... kill = FALSE when different }
if (kill) List.Delete(i);                               // look-up failed == "unchanged"
```

`FindFirstFileA` reads the UTF-8 bytes through code page 1250 (`ř` = `C5 99`
becomes `Ĺ™`), the file "does not exist", `kill` stays TRUE and the item is
removed from the list as if it had not changed. `List.Count` is then 0, the
dialog (line 3404) is never created, and the callers go on to delete the
temporary files.

## Life of an edited file (file:line, call flavour, encoding)

| Step | Where | File-system call | Path encoding |
|---|---|---|---|
| F4 / Enter in an archive | `CFilesWindow::ExecuteFromArchive`, `src/fileswn6.cpp:3145` | - | - |
| name check | `fileswn6.cpp:3173` `SalIsValidFileNameComponent(f->Name)`: an invalid name is refused with a message, there is **no substitute name** | - | UTF-8 |
| temporary name | `fileswn6.cpp:3246` `DiskCache.GetName(dcFileName, f->Name, ...)` -> `%TEMP%\SALxxx.tmp\<the same name as in the archive>`; the folder inside the archive is not part of it (`src/cache.cpp:1130`, `SalGetTempFileName`, `GetTempPathW`) | wide | UTF-8 |
| unpack | `fileswn6.cpp:3270` `PackUnpackOneFile` | plug-in | UTF-8 |
| stamp at unpack | `fileswn6.cpp:3277` and `:3333` `SalFindFirstFile(name, &data)` (`WIN32_FIND_DATAW`) | **wide helper** | UTF-8 |
| run | `fileswn6.cpp:3318` `EditFile(name)` / `:3326` `ExecuteAssociation(...)` | - | UTF-8 |
| remember | `fileswn6.cpp:3344` `UnpackedAssocFiles.AddFile(archive, zipRoot, tmpDir, name, dosName, lastWrite, fileSize, attr)` -> `CFileTimeStamps::AddFile`, `src/salamdr3.cpp:3088` (stores strings and the stamp, no file-system call); `AssocUsed = TRUE` at `:3352` | none | UTF-8 |
| leave the archive | `CFilesWindow::PrepareCloseCurrentPath`, `src/fileswn2.cpp:1261-1298`: information box, then `:1287` `CheckAndPackAndClear` | - | - |
| operation on the archive | `OfferArchiveUpdateIfNeededAux`, `src/fileswn9.cpp:1205-1232` (`:1217` the same call); callers `fileswn9.cpp:1289`, `mainwnd3.cpp:3663`, `salshlib.cpp:630` | - | - |
| exit | `src/mainwnd3.cpp:7083/7085` -> `PrepareCloseCurrentPath` -> the same call | - | - |
| **changed?** | `salamdr3.cpp:3377` `HANDLES_Q(FindFirstFile(buf, &data))` | **ANSI** | UTF-8 -> **defect** |
| dialog list | `salamdr3.cpp:3193` `SalListBoxAddStringU8` (`AddFilesToListBox`) | - | UTF-8, correct |
| *Copy Selected To* | `salamdr3.cpp:3326` `SHFileOperationW` (fixed in 069, F-P1-20) | wide | correct |
| pack back | `salamdr3.cpp:3447` `SetCurrentDirectory(s1)` | **ANSI** | UTF-8 (twin, see below) |
| | `salamdr3.cpp:3449` `PackCompress(parent, Panel, ZIPFile, r1, FALSE, s1, FileTimeStampsEnum2, &data2)` (`src/pack2.cpp:69`) | plug-in / wide helpers in pack*.cpp | UTF-8 |
| clean up | `fileswn2.cpp:1294-1296` / `fileswn9.cpp:1218-1220`: `SetEvent(ExecuteAssocEvent)`, `DiskCache.WaitForIdle()` -> `CCacheData::CleanFromDisk`, `src/cache.cpp:104-124` `SalGetFileAttributes` / `SalDeleteFile` | **wide helpers** | UTF-8 - the deletion **succeeds** |

Consequences of the failed look-up:

- The item is dropped from the list (treated as unchanged), `*someFilesChanged`
  stays FALSE, so `fileswn2.cpp:1292` runs the clean-up even during a critical
  shutdown (the rule "never delete edited files at a critical shutdown" is
  bypassed for these names).
- The clean-up uses the wide helpers, finds the file and deletes it. The edit
  is gone for good; nothing is left in `%TEMP%` (measured).

Neighbours:

- **Viewer (F3)**: no pack-back by design; `UnpackedAssocFiles.AddFile` has one
  caller only (`fileswn6.cpp:3344`), the view path does not use this class.
- **Edit New** (`CFilesWindow::EditNewFile`, `src/fileswn5.cpp:1497`): does not
  use this class (`AddFile` has the single caller above).
- **Enter (association)**: the same `ExecuteFromArchive`, `edit == FALSE`; the
  same loss (measured, row `er`).
- **Unattended close (080)**: `fileswn2.cpp:1254` declines while `AssocUsed`,
  before the look-up; not affected.
- **Critical shutdown**: see above - for an affected name the edited copy is
  deleted although the comment at `fileswn2.cpp:1288-1291` promises it is kept.

## Since when

`git log -S"HANDLES_Q(FindFirstFile(buf, &data));" -- src/salamdr3.cpp` gives one
commit, `3945ecf7` *Open Salamander initial commit*: the line was never touched.
In Open Salamander the producer side was ANSI too
(`3945ecf7:src/fileswn6.cpp:3173`, `:3230`), so the two agreed. Feature 004,
commit `cfb8213d` (2026-07-14), moved the names and the producer
(`fileswn6.cpp`) to UTF-8 and `SalFindFirstFile` and left this consumer on the
ANSI call. That commit is an ancestor of `v0.1.0`; the line is identical in
`v0.1.0` (3277), `v0.1.5`, `v0.1.7`, `v0.1.8` (3377). **Every released
version, 0.1.0 to 0.1.8, has the defect.** Feature 069 fixed the neighbouring
`CopyFilesTo` in the same class and did not reach this line.

## Experiment

Probe `probe/archedit_probe.ps1` (helper block and registry discipline of the
095 probe), run only through `tools\run_on_hidden_desktop.ps1`. One instance
per row; the archive holds one file; F4 editor =
`cmd.exe /c echo edited096>>"$(FullName)"`; the Enter rows use a `.cmd` file
that appends a line to itself. "edit ran" = the temporary copy was read by the
probe before the leave and contained the appended line.

Results are identical on `Debug_x64` (current) and `Debug_x64_pre094`
(`probe/archedit_result_Debug_x64.txt`, `probe/archedit_result_Debug_x64_pre094.txt`):

| Case | Archive | Name in the archive | Action | Edit ran | Information box | Archive Update shown | Archive after | Temp copy after leave / exit |
|---|---|---|---|---|---|---|---|---|
| ascii | zip | `a.txt` | F4, leave | yes | yes | yes | updated | deleted |
| clanek | zip | `článek.txt` | F4, leave | yes | yes | **no** | **unchanged** | **deleted** |
| r | zip | `ř.txt` | F4, leave | yes | yes | **no** | **unchanged** | **deleted** |
| cyr | zip | `Кирил.txt` (outside the code page) | F4, leave | yes | yes | **no** | **unchanged** | **deleted** |
| space | zip | `a b.txt` | F4, leave | yes | yes | yes | updated | deleted |
| subasc | zip | `složka/a.txt` | F4, leave | yes | yes | yes | updated | deleted |
| subacc | zip | `složka/ř.txt` | F4, leave | yes | yes | **no** | **unchanged** | **deleted** |
| L60 | zip | 56 x `ř` + `.txt` (116 bytes) | F4, leave | yes | yes | **no** | **unchanged** | **deleted** |
| L67 | zip | 63 x `ř` + `.txt` (130 bytes) | F4, leave | yes | yes | **no** | **unchanged** | **deleted** |
| L77 | zip | 73 x `ř` + `.txt` (150 bytes) | F4, leave | yes | yes | **no** | **unchanged** | **deleted** |
| xascii | zip | `a.txt` | F4, close the program | yes | yes | yes | updated | deleted |
| xr | zip | `ř.txt` | F4, close the program | yes | yes | **no** | **unchanged** | **deleted** |
| eascii | zip | `a.cmd` | Enter, leave | yes | yes | yes | updated | deleted |
| er | zip | `ř.cmd` | Enter, leave | yes | yes | **no** | **unchanged** | **deleted** |
| 7ascii | 7z | `a.txt` | F4, leave | yes | yes | yes | updated | deleted |
| 7r | 7z | `ř.txt` | F4, leave | yes | yes | **no** | **unchanged** | **deleted** |

In every row the temporary name equals the name in the archive, no other
message appeared, the exit code was 0 and no crash report was written. The
information box "archive is about to close ... update will be offered in case
of changes" is shown in the failing rows too, which makes the loss more
misleading.

Row `tmpacc` (ASCII name with an accented `%TEMP%`) is **not a valid
measurement**: the instance ignored the `TEMP`/`TMP` given in its environment
(two launch methods: `Start-Process` and `ProcessStartInfo.EnvironmentVariables`;
the reason was not determined) and unpacked into the real `%TEMP%`
(`probe/archedit_result_Debug_x64_tmpacc.txt`).

## What the user loses

The edit. The temporary copy is deleted when the archive is left, when another
operation on the archive triggers the update offer, or when the program exits.
No message. The only way to keep the work is to save it elsewhere from the
editor before leaving the archive.

## Smallest safe fix

`src/salamdr3.cpp`, `CFileTimeStamps::CheckAndPackAndClear`:

```cpp
WIN32_FIND_DATAW data;                         // was WIN32_FIND_DATA
...
HANDLE find = SalFindFirstFile(buf, &data);    // was HANDLES_Q(FindFirstFile(buf, &data)); registers with HANDLES itself
```

The fields used afterwards (`ftLastWriteTime`, `nFileSizeLow/High`,
`dwFileAttributes`) are the same in the wide structure; `HANDLES(FindClose(find))`
stays. This is exactly what the producer does at `fileswn6.cpp:3277`.

Twin sites in the same class:

1. `salamdr3.cpp:3447` `SetCurrentDirectory(s1)` - ANSI on the UTF-8 temporary
   folder. Harmless while `%TEMP%` is ASCII; move to the house pattern of
   `salamdr3.cpp:1031-1035` (`SalU8ToW` + `SetCurrentDirectoryW`, ANSI fallback).
2. By code reading, a **non-ASCII `%TEMP%`** (an accented user profile name)
   makes line 3377 fail for *every* name, ASCII included, because `SourcePath`
   is UTF-8. The one-line fix covers it.
3. `CFileTimeStamps::AddFile` (3088): no file-system call, nothing to fix.
   `AddFilesToListBox` (3185) and `CopyFilesTo` (3243): already correct.
   Deletion of the temporary files (`cache.cpp:104-124`): already wide.
4. Optional hardening, not part of the smallest fix: a look-up that fails with
   an error other than "not found" could keep the item instead of dropping it,
   so that a failure can never again turn into a silent deletion.

## Not verified

- **The fixed behaviour.** With the look-up repaired, the pack-back of a
  non-ASCII name (`PackCompress` -> plug-in with the UTF-8 enumerator, the
  *Confirm File Overwrite* dialog, the 7z update matching of 089) runs for the
  first time since 0.1.0. It is the same contract as packing from a panel, but
  it was not measured - re-run this probe after the fix; every row must read
  `yes / updated`.
- A non-ASCII `%TEMP%` (see `tmpacc`): code reading only.
- The critical-shutdown path and the "operation on the archive" callers
  (`fileswn9.cpp:1289`, `mainwnd3.cpp:3663`, `salshlib.cpp:630`): code reading
  only; they call the same function.
- Release build and the installed 0.1.8: not run (the line is identical in the
  `v0.1.8` source).
- External archivers (7-Zip console / RAR, feature 084): not measured.

## Housekeeping

Registry `HKCU\Software\Tandem Commander`: SHA-256 of the export before and
after every run `1AB614304771DBE00A71EAB448FDF988EA7BCC409DE1D48407F2BB6CE63BF769`
(identical). No test process left; `%TEMP%\tc096_accent` and
`%TEMP%\tc096_accent_reg` removed by the probe; no `SAL*.tmp` folder left.
