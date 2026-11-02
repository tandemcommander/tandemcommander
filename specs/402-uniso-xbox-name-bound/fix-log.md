# Fix log - 402-uniso-xbox-name-bound

Backlog item `iso-plug-in-an-xbox-entry-name-can-be-read-past-the-end-of` (source review:400, NOTE 3).

## Measurement before (main 76e8f098)

- Site: `src/plugins/uniso/xdvdfs.cpp` `CXDVDFS::ScanDir` - the loop `while ((offset + 0x0E) <= size ...)`,
  `BYTE len = GET_BYTE(data, offset + 0x000D)`, `strncpy_s(fileName, (char*)data + offset + 0x000E, len)`:
  `offset + 0x0E + len` never compared with `size` (the buffer is `new BYTE[size]`).
- Reachable: Unpack / open of any Xbox image - `CISOImage::ListImage` -> `CXDVDFS::ListDirectory` ->
  `ScanDir` for the root and every folder (default configuration, uniso is on).
- `.\build.cmd` (incremental, nothing to rebuild), then the new probe on the hidden desktop:
  `powershell -File tools\run_on_hidden_desktop.ps1 -Log <scratch>\result_before.txt -CommandLine "powershell
  -NoProfile -ExecutionPolicy Bypass -File <scratch>\iso402_probe.ps1 -Exe build\...\tandemcommander.exe
  -Lib specs\098-long-path-overruns\probe\fix_probe_lib.ps1 -Label before -OutFile ..."` (the probe was
  written in the session's scratchpad before the branch existed; copied to `probe/` unchanged;
  `probe/result_before.txt`). Images by `probe/img402.py` (written from scratch, no WSL).
- Result: PASS 6 / FAIL 4 (5 END rows pass, XD-EDGE pass):
  - XD-NAME `files 3: top.txt, zlast/z.txt, zzýýýý`, no window, image deleted;
  - XD-OVER1 `zzý`; XD-MAX `zzýýýýÝÝ`; XD-SUB `a/zzýýýý`;
    each no window, image deleted - the name took the Debug heap's no-man's-land bytes (0xFD) and freed
    fill (0xDD) after the directory buffer, through `EnsureU8Name`'s byte fallback as `ý` / `Ý`.
  - XD-EDGE (the name `zz` ends exactly at the end of the root's 60 bytes): top.txt, zlast/z.txt, zz;
    no window; image deleted - PASS (the control for the bound's off-by-one).
- The Debug heap reported nothing (no assertion, no bug report): a read is not checked.

## Decisions

- Root: a damaged record ends the walk of its directory with ERR_CONTINUE (entries before it listed, the
  listing marked incomplete via `ListDirectory`'s `walked != ERR_OK`), also in the root - the image opens
  (the Xbox root's read failure already returns ERR_CONTINUE). A sub-folder's CONTINUE / TERMINATE are the
  same to its parent (`SalIsoWalkAfterChild`).
- Box: `IDS_ERROR_LISTING_IMAGE` with the directory's sector, `SalIsoWalkBoxQuiet(Walk, false)` (once per
  walk) - no new string, no translation work.

## Analyze

- speckit-analyze: 0 CRITICAL, 0 HIGH; LOW C1 accepted - no probe row with two damaged Xbox directories
  (the one box per walk is 400's shared `SalIsoWalkBoxQuiet`, proven by 400's XD-TWO / XD-MANY rows).

## Implementation

- `src/common/salisoxboxentry.h` (new, header-only): `SalIsoXboxEntryHeadFits(size, offset)` and
  `SalIsoXboxEntryFits(size, offset, nameLen, next)` - 64-bit, no wrap; `next` = the name's end rounded up
  to 4.
- `src/plugins/uniso/xdvdfs.cpp` `CXDVDFS::ScanDir`: the loop and the padding check by
  `SalIsoXboxEntryHeadFits` (the same values, no wrap); before the name is copied `SalIsoXboxEntryFits` -
  false: `Error(IDS_ERROR_LISTING_IMAGE, SalIsoWalkBoxQuiet(Walk, false), sector)`,
  `ret = SalIsoWalkAfterChild(ret, ERR_TERMINATE)` (= ERR_CONTINUE), `break`; the next offset from the rule
  (past the data ends the walk; the old 32-bit `((offset + 3) / 4) * 4` could wrap to 0 for a directory
  near 4 GiB).
- First build: `C1083 salisoxboxentry.h` - uniso includes common headers by `../../common/` (as
  `salisowalk.h`); fixed. Warning C4267 at xdvdfs.cpp line 119 is upstream's (`fd.NameLen = strlen`), untouched.
- `src/saltests/saltests.cpp` `TestIsoXboxEntry402`: the bounds (exact fit, one over, 255, empty name,
  offset past size, near 2^32) and a model walk of ScanDir over the probe's directories, a two-sector
  directory and a cut second sector - `outside == 0` for the walk with the rule; the walk without it reads
  `len - 2` bytes outside (the defect, asserted).

## Measurement after

- `.\build.cmd` -> BUILD SUCCEEDED; saltests `282,383 checks, 0 failed` (main: 282,328 + 55 new).
- `iso402_probe` after: PASS 10 / FAIL 0 (`probe/result_after.txt`): XD-NAME, XD-OVER1, XD-MAX
  `files 2: top.txt, zlast/z.txt`, one box "Error reading directory structure at sector #00000021",
  image kept; XD-SUB `a/side.txt, top.txt, zlast/z.txt`, one box (sector #00000022), kept; XD-EDGE
  unchanged (zz listed, no window, image deleted). Registry restored, identical hash.
- Negative control (the name bound of `SalIsoXboxEntryFits` replaced by `if (false)` in the tree,
  rebuilt, then restored from a saved copy and rebuilt): saltests 17 failed; `iso402_probe` 6 / 4
  (`probe/result_negctl.txt`, the before picture: `zzý...`, no box, image deleted) - the probe
  proves the plug-in's use of the rule.
- Regressions on the final build: `iso401_probe` 10 / 0 (`probe/regress_401.txt`), `iso400_probe`
  48 / 0 (`probe/regress_400.txt`, WSL seeds made, no NOT DRIVEN).
- Encoding guard `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- No UI string, menu or dialog changed: no `.slt` refresh (stop-rules §2.13 not triggered).

## Review

- Refute-first review 1 (independent agent, 2026-11-02): **no MUST, no SHOULD.** It re-ran saltests
  (282,383 / 0) and `iso402_probe` on the run's build (10 / 0, registry identical); its own negative
  control in a detached worktree with its own build folder - only `ret = SalIsoWalkAfterChild(ret,
  ERR_TERMINATE);` removed (the box still shown, the listing not marked) - 6 / 4, the four damaged rows
  fail on "image kept: False" (the probe catches the data-loss path, not only the box). Callers
  enumerated: `ScanDir` <- `CXDVDFS::ListDirectory` <- `CISOImage::ListDirectory` / `ListImage`.
  - NOTE 1: `XboxWalk402` in saltests is a model of `ScanDir` (proves the rule; the probe proves the
    plug-in's use); no probe row for a damaged entry in a second sector after 0xFF padding (the model
    covers it). Recorded, accepted.
  - NOTE 2 (upstream): a name with a NUL inside is listed cut at the NUL (`strncpy_s`) -> Inbox
    `iso-plug-in-an-xbox-entry-name-with-a-nul-byte-inside-is` (review:402).
  - NOTE 3 (upstream): `new BYTE[size]` with a claimed size up to 4 GiB before the read fails; plain `new`
    throws, so the NULL check may never fire -> Inbox `iso-plug-in-an-xbox-folder-entry-claiming-a-huge-size`
    (review:402).
  - NOTE 4: closing records owed (done at closing). NOTE 5: old review worktrees of earlier features
    registered in `git worktree list` - not this feature's, left alone.
- `git status --short` after the review: only this run's two new backlog items - the tree as the run left it.
- Trap: a Bash here-document collapsed `\0` in a Python string into `\0` - the item text got three NUL
  bytes; repaired with a script written by the editor (CLAUDE.md rule 123).
