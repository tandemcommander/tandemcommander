# Closing report - 393-cpio-long-name
Backlog item: a-cpio-or-rpm-archive-with-a-member-name-the-panel-cannot - A cpio or rpm archive with a member name the panel cannot hold fails as a whole
Outcome: closed

## What changed

`src/plugins/tar/untar.cpp` (TAR plug-in, which opens cpio and rpm):

- `CArchive::ReadArchiveHeader`: the per-member refusal of PAX paths / GNU long names (features 306 /
  308 / 321, `SalPaxNameUsableU8`) applies to every cpio name too (newc, crc, odc, binary,
  byte-swapped binary - and so the rpm payload). While the panel listing is built a name it cannot hold
  is left out and the system's "(206)" text with the whole path is shown once; an extraction refuses
  only a component over 255 UTF-16 units and fails (archive kept) when asked for such a member. A cpio
  folder is recognised by its mode for this check (cpio writes folders without a trailing slash).
- `CArchive::IsCpioGroupMember` / `DoUnpackArchive`: a refused name stays in its hard-link group as
  "not asked", so the file's other names get its data instead of an empty file (data-last layout).

No UI strings, resources, plug-in interface or settings changed.

## Measurements (before / after, commands)

- Before (af18dc21): `tar321_probe.ps1 -Only CPIO-TOOLONG` -> "Internal error: file data structure
  corrupted.", the archive does not open. `cpio393_probe.ps1` (label `before`, `probe/result_before.txt`)
  PASS 14 / FAIL 8: every over-long / too-deep row fails to open; both TOOLONG unpacks extract nothing.
- After: `cpio393_probe.ps1` (`probe/result_after.txt`, label `after-review1`) PASS 28 / FAIL 0
  (14 RUN rows: newc, odc, rpm TOOLONG; deep tree copy and whole unpack; boundary 255; top-level
  folder of 100 CJK; nested 300-byte folder; hard link data-last and data-first; symlink).
- Negative control (`probe/result_negctl.txt`): mode check and group change reverted -> 19 / 3, the
  predicted rows (nested folder: the archive fails whole again; data-last hard link: `a.txt` empty).
  The reviewer's own control (only the group guard reverted) failed UNP-HARD-REFUSED-DEL.

Command: `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\393-cpio-long-name\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\393-cpio-long-name\probe\cpio393_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label <label>"`

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> `BUILD SUCCEEDED` (no `full` needed: no strings, resources or plug-in lists).
- `saltests.exe` -> `saltests: 30798 checks, 0 failed`.
- Regression probes unchanged: 306 30 / 0, 308 12 / 0, 309 16 / 0, 310 52 / 0, 321 `tar321` 20 / 0
  and `unp321` 12 / 0 (`probe/regress_*.txt`).

## Reviews (findings and what was done)

Review 1 (independent, refute-first): no MUST.
- SHOULD-1 (FR-006 promised the data for the other names in every layout; data-first reports them):
  spec narrowed to feature 310's rule, probe rows COPY-HARD-FIRST / UNP-HARD-FIRST-DEL added, the
  improvement -> Inbox.
- NOTE-1 (a cpio symlink with a refused name is now named at opening): recorded, row COPY-SYMLINK-LONG.
- NOTE-2 (321's probe header described the old behaviour): comment updated.
- NOTE-3 (binary formats / F3 of a refused carrier not probed): accepted, shared code.
- NOTE-4 (pre-existing: an empty-normalized data name drops the data): Inbox.

## Owed to a person (with the new person-step items)

- Add the CHANGELOG entry below: `CHANGELOG.md` has no `## [Unreleased]` section (versions are the
  maintainer's), so the run did not create one.

```text
- **A cpio archive or rpm package with a member name that is too long for the panel could not be opened at all** (feature 393).
  - **Before:** a cpio archive or rpm package holding a member whose name no file system takes (for example 300 Chinese characters), whose folders are nested deeper than the panel can show, or with a folder named by more than 255 bytes inside another folder, refused to open with "Internal error: file data structure corrupted." - none of its other files could be reached.
  - **Now:** such a member is left out of the listing and named once by the system's "file name too long" message with its whole path, as a TAR member has been since 0.2.0; every other member lists and extracts. Unpack (Alt+F9) extracts everything a file system takes, also the deep members, and keeps the archive when it was asked for a member it cannot write.
  - **Limitation:** when the too-long name is the one that carries a hard-linked file's data and it comes first, the file's other names are reported instead of extracted (the archive is kept).
```

No person-step item: nothing in this change needs a real keyboard, clipboard or another machine.

## New Inbox items (slug - title)

- `a-cpio-name-stored-after-its-data-on-a-refused-name-is` - A cpio name stored after its data on a refused name is reported, not extracted
- `a-cpio-hard-link-whose-data-name-normalizes-to-empty-is` - A cpio hard link whose data name normalizes to empty is written as an empty file
