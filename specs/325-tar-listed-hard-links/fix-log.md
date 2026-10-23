# Fix log - 325-tar-listed-hard-links

Backlog item `tar-copy-of-listed-files-leaves-hard-links-out` - Copying the files of a tar folder
leaves hard-linked names out silently. Source: review 1 of feature 309.

## Measurement before (main at 0991f43c)

- `.\build.cmd` (Debug x64, incremental) -> BUILD SUCCEEDED.
- New probe `probe/link325_probe.ps1` + fixture writer `probe/mklink325.py` (Python `tarfile`), run on
  the hidden desktop:
  `powershell -File tools\run_on_hidden_desktop.ps1 -Log ... -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <probe> -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -OutFile ..."`
  -> `probe/result_before.txt`: PASS 11, FAIL 7 (registry restored, identical hash).
  - COPY-INSIDE (open `t.tar\sub`, Select All, Copy): 1 of 3 files (`c.txt`), no box - the defect.
  - COPY-INSIDE-GZ, COPY-CHAIN: the same.
  - COPY-MISSING: `c.txt`, no box (the link to a missing member is not even listed).
  - COPY-FOCUSED (End, Copy): `c.txt` copied - the link is not in the panel.
  - COPY-EXIST: no overwrite question for `e.txt` (not listed).
  - VIEW-LINK (End, F3): the viewer shows `c.txt`.
  - COPY-SYM (symbolic link left unlisted) and COPY-ROOT (feature 309's Copy of the root) PASS.
- Caller chain: panel Copy inside an archive folder -> core `UnpackArchive` with the selected names
  -> `CPluginInterfaceForArchiver::UnpackArchive` -> `CArchive::UnpackArchive` -> `DoUnpackArchive`;
  the names come from the panel listing built by `CArchive::ListArchive`, which skips every
  `Ignored` member - `ReadTarHeader` sets `Ignored` for LNKTYPE / SYMTYPE.

## Decisions

- The item's first alternative: list hard links as files (size of the data member they name) and
  extract them from that data; the target's data, when the single pass already passed it unasked,
  is read in a second pass over the archive (reopened stream) - only when such a link exists.
- Symbolic links stay unlisted (never created by the plug-in - a listed one could only fail).
- Feature 309's cases unchanged: target written -> copy; target asked but not written -> report.

## speckit-analyze

No CRITICAL / HIGH. C1 (MEDIUM, accepted): Cancel during the second pass has no probe row - the
second pass uses `WriteOutData(..., doProgress TRUE)` and `ProgressAddSize` like pass 1, checked in
review; a tiny fixture cannot be cancelled at a chosen moment. I1, U1 LOW - no change.

## Implementation

- `src/common/saltarlink.h`: `SAL_TAR_LINK_DEFER`, `SalTarLinkDecideAsked` (309's decision plus
  "target neither written nor asked / itself deferred -> DEFER"; a `..` or empty link name -> report),
  `SalTarResolveHardLink` (chain, bounded by the map size: a cycle is unresolved),
  `SalTarListedLinkSize`. saltests `TestTarLink325`.
- `src/plugins/tar/tar.h` / `untar.cpp`:
  - `CArchive` keeps the archive name (the stream keeps a pointer to this copy), offset and size;
    `ReopenStream()` opens the same (sub)stream again (gzip etc. included).
  - `ListArchive`: hard links (not refused, not a folder) are listed as files with the size of the data
    member their chain ends in (0 if none); the header keeps its own size 0 for the data skip.
  - `DoUnpackArchive`: every hard link recorded; an asked one -> `SalTarLinkDecideAsked`; DEFER stores
    `SDeferredLink`; at the end (both exits, after the cpio empty names) `ExtractDeferredLinks`: groups
    by data name, reopens, second pass with the progress bar reset (Cancel = `ProgressAddSize`), the
    first data member of each name written under the first link's name (the header's name swapped:
    overwrite question and progress name the link), the other links copied from it by 309's
    `WriteOutLinkCopy`, stops once nothing is wanted; unresolved / skipped-first -> 309's report once.
  - `UnpackOneFile` -> `UnpackOneFilePass`: a found hard link whose chain ends in a data member seen
    earlier returns `UNPACK_ONE_LINK`; the caller reopens and extracts that member as `newFileName` or the
    link's file name.
  - `precomp.h`: `<unordered_map>` before the Debug `new` macro (as `<unordered_set>`).
- Trap 123 again: a Python here-document turned `'\0'` into NUL bytes in `untar.cpp` - found by a
  byte count, fixed with a script written by the editor. `sed -i` turned the CRLF file into LF - restored.

## Checks after

- `.\build.cmd` -> BUILD SUCCEEDED; saltests -> `saltests: 27877 checks, 0 failed`.
- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- Probe first run after: 17 PASS / 1 FAIL - COPY-EXIST got the COPY-INSIDE fixture (probe bug in
  `mklink325.py`: no `e.txt` in it); fixed the fixture selection. COPY-INSIDE, -GZ, -CHAIN, -MISSING
  (one box "(2) ... sub\b.txt -> missing.txt"), -FOCUSED, VIEW-LINK (viewer shows the disk-cache copy
  `d.txt` holding "A") PASS.
- The re-run was refused (exit 99): the maintainer started the installed Tandem Commander at 12:45 -
  probes share the registry key; waited for it to close (never touched).
- After the maintainer's instance closed: `probe/result_after.txt` first run 17 / 1 - COPY-EXIST
  wrote e.txt correctly and showed the overwrite question with the new size 131 072, but the probe
  looked for "e.txt" in the box text; the Confirm File Overwrite dialog shows the names in controls the
  driver does not read (not Static). Check changed to: exactly one box, titled Confirm File Overwrite,
  showing 131 072. Then `probe/result_after.txt` PASS 18 / FAIL 0 (registry restored, identical).
  (`result_before.txt` was taken with the earlier check texts; both checks only became stricter.)
- Regression (`probe/run_regress.ps1`, hidden desktop, `probe/regress_*.txt`): pax306 30 / 0, unp308
  12 / 0, link309 16 / 0, cpio310 52 / 0, tar321 20 / 0, unp321 12 / 0 - no row needed a change (none
  of them copies a folder's files without the link target).
- Negative control (DEFER reported instead of deferred, and UnpackOneFile's link re-read off; build of
  the working tree, then `git checkout HEAD -- src/plugins/tar/untar.cpp` and a rebuild):
  `probe/result_negctl.txt` PASS 12 / FAIL 6 - COPY-INSIDE / -GZ / -CHAIN 1 of 3 files plus a box,
  COPY-FOCUSED 0 files + box, COPY-EXIST e.txt not replaced, VIEW-LINK the "(2) sub\d.txt -> a.txt"
  box; COPY-MISSING / -SYM / -ROOT pass in both (they do not depend on the second pass). Restored
  build: `probe/result_after_restored.txt` PASS 18 / FAIL 0.
- Build warnings C4267 in untar.cpp (lines `NameLen = strlen(...)`) are pre-existing (0991f43c).

## Review

### Review 1 (independent agent, refute-first) - one MUST, three SHOULD

The first reviewer launched stopped making progress at 13:17 (a probe run of its own left without
rows; its registry backup was restored by the second reviewer, hash identical). A fresh review was
launched with its partial results (`%TEMP%\rev325`): branch 18 / 0, main 11 / 7 on the feature probe.

- MUST M1 (fixed): a deferred link took the FIRST data member of the name it refers to; tar (GNU tar
  1.35, bsdtar, Python - measured by the reviewer on a real `tar -u` archive: `a.dat` OLD,
  `sub/b.txt -> a.dat`, `a.dat` NEWER, `sub/b.txt -> a.dat`) extracts the LATEST earlier member. Unpack
  with mask `*.txt` + "Delete archive after unpacking": branch wrote b.txt = OLD, no message, archive
  DELETED (main reported and kept it). Copy of the folder's files gave OLD too. Fix:
  `CSalTarLinkResolver` (saltarlink.h) - every member fed in archive order, a link resolved when read
  against the latest definition of its target name (data member name + ordinal; a link redefines its
  own name, other members clear it); the further pass extracts that occurrence; a later asked member
  of a deferred link's own name supersedes it (tar keeps the last); listing sizes and UnpackOneFile
  use the same resolver (ordinal-exact second pass).
- SHOULD S1 (fixed): chains were walked again per link (N^2/2; 40,000 links 23.5 s Release). The
  resolver stores each link's resolution - O(1) per link.
- SHOULD S2 (fixed): Skip at the first name of a group reported the other names "(2) not found";
  now the group waits for another pass and its data goes under the next name.
- SHOULD S3 (fixed): probe rows added - UNP-UPD-DEL (Unpack with a mask + Delete archive on the
  `tar -u` shape), COPY-UPD (Copy of that folder), COPY-SKIP (Skip inside a group).
- NOTE (accepted): the listing / view record every member name of the pass (memory proportional to
  the member count - the listing itself holds them all anyway).

After the fixes: build BUILD SUCCEEDED; saltests 27882 / 0 (TestTarLink325 rewritten for the resolver:
`tar -u` order, redefinition by a link / by a folder, ordinals, unresolved links); encoding guard 0;
`probe/result_after_review1.txt` PASS 24 / FAIL 0. Negative control: the pre-review code (stash of the
fix, build of commit b2afe914) with `-Only UNP-UPD-DEL,COPY-UPD,COPY-SKIP` ->
`probe/result_negctl_review1.txt` PASS 3 / FAIL 3 (UNP-UPD-DEL: sub/b.txt wrong content and the archive
deleted - M1 reproduced; COPY-UPD wrong content; COPY-SKIP d.txt missing + a "(2)" box); fixed build
rebuilt, the full probe again 24 / 0.
- Trap 123 twice more: a Bash here-document collapsed `\` in a probe edit script (Python then made
  tabs of `\t`) - the probe restored from git and edited with the editor tool.
- Regression on the fixed build (`probe/regress_*.txt` overwritten): pax306 30 / 0, unp308 12 / 0, link309
  16 / 0, cpio310 52 / 0, tar321 20 / 0, unp321 12 / 0.

### Review 2 (independent agent, refute-first) - stopped without a report; its partial results acted on

Launched 14:06 after 496e8ac3 with review 1's findings. Its own probe (`%TEMP%\rev325c`, real GNU
`tar -u` fixtures) ran on the branch and on main (14:07-14:10) - every review-1 row now matches tar
(R-TARU / R-UPD / U-TARU-MASK-DEL: NEWER; R-SKIP: d.txt written; R-DUP NEW; R-RELINK A) - then a run on
a patched build was interrupted at 14:13 and no further activity followed (two wake-ups, 14:25 and
14:34, without progress -> treated as stopped). Its probe left the registry changed: restored at
14:26 from `%TEMP%\tcrev325c_backup.reg` (`reg delete` + `reg import`, export hash
D36F5B06... identical to the backup and to every probe's pre-run hash today).

Its rows X-RELINK2 and X-CASE showed two defects (branch vs main, mask + "Delete archive after
unpacking"), both fixed here:
- X-RELINK2 (MUST-level: wrong content, archive deleted): `a.txt` 'A' written, then redefined as a
  link to `z.txt`, then `sub/b.txt -> a.txt`; mask `a.txt;*b.txt`. The branch COPIED the on-disk a.txt
  ('A') into b.txt - tar gives 'Z' - and deleted the archive (main reported and kept it). Fix:
  `SalTarLinkDecideAsked` checks "target is a deferred link" before "target written" (the latest
  definition wins); b.txt is deferred with the resolver's target (z.txt #1) and copied from a.txt
  after a.txt gets Z. saltests +2.
- X-CASE (MUST-level): a deferred `sub/b.txt -> a.txt`, then a data member `SUB/B.TXT` 'NEW' (the same
  file on Windows); mask `*b.txt`. The later member did not supersede the deferred link (byte
  compare); the further pass wrote 'A' over NEW (after an overwrite question) and the archive was
  deleted; tar's result is NEW. Fix: the deferred index is a `std::map` ordered by
  `SalNameOrderCompareCI` (`salnameorder.h`, the file system's name rule, rule 092).

Probe rows added: UNP-RELINK-DEL (one overwrite question: a.txt is written twice by the operation, as
on main), UNP-CASE-DEL. `probe/result_after_review2.txt` PASS 28 / FAIL 0. Negative control (the fix
stashed, the 496e8ac3 code built): `probe/result_negctl_review2.txt` - UNP-RELINK-DEL sub/b.txt wrong
content + archive deleted, UNP-CASE-DEL wrong content + archive deleted (PASS 2 / FAIL 2 with the END
rows); fix rebuilt. saltests 27884 / 0.
- Regression on the review-2 build: pax306 30 / 0, unp308 12 / 0, link309 16 / 0, cpio310 52 / 0, tar321
  20 / 0, unp321 12 / 0; encoding guard TOTAL 0.

### Review 2, second launch - stopped without a report

Launched after 786c1d34. Its probe (`%TEMP%\rev325d`) on the branch, 14:58: every earlier row now
matches tar (R-TARU / U-TARU-MASK-DEL NEWER, R-SKIP d.txt = A, R-DUP NEW, X-RELINK2 a.txt = b.txt = Z,
X-CASE NEW), N-OVERALL (40 links to a 24 MiB member + 1 file) 4.3 s, N-SKIPALL (Skip All at the
overwrite question) 4.3 s - one further pass per skipped name, not a hang - N-DEB (a .deb's data tar)
b.txt = A, N-DOT and N-DEV (below); registry restored identical. A gzip run (`log_gz.txt`, 15:01) was
interrupted at row N-SKIPALL-GZ (N-OVERALL-GZ: 41 files, 5.1 s) and the agent showed no activity at
the 15:14 and 15:24 checks -> treated as stopped. Its probe had left the registry changed (export hash
3DF1D4E2...): restored at 15:15 from `%TEMP%\tcrev325d_backup.reg`, hash D36F5B06... identical.
- N-DOT (link `sub/b.txt`, later `sub/b.txt.` NEW): two files `b.txt` = A and `b.txt.` = NEW - the
  plug-in writes a trailing-dot name as its own file through the `\?\` form (pre-existing name
  handling, not this feature).
- N-DEV (link `sub/b.txt`, later a FIFO `sub/b.txt`): nothing written, archive deleted, no message -
  the FIFO supersedes the link (tar's result is the FIFO); the plug-in skips FIFO / device members
  silently in every version (pre-existing) -> Inbox item.

### Review 2, third launch - stopped without a report

Launched 15:27 with the advice to run probes in the background. Its probe (`%TEMP%\rev325e`, 15:32):
E-BADSIG (an unknown member type 'A' between the data and the link) b.txt = A - the plug-in's
"Unknown block signature - skipping" box at opening; E-CANCEL1 / E-CANCEL2 (Cancel at the overwrite
question in the further pass) archive KEPT. Then it ran this feature's probe (15:33) and stopped at
row COPY-EXIST; no activity at 15:35 / 15:46, and none of the three review-2 agents was alive any more
(ListAgents, 15:47). The interrupted feature probe had left the registry changed (0FB44762...):
restored at 15:47 from `%TEMP%\tc325_backup.reg`, hash D36F5B06... identical; its fixture removed.
Next attempt, a different method: a review without GUI probes (the GUI evidence is recorded), from
the code, saltests and a console harness of the header rules.
