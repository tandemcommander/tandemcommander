# Fix log - 403-uniso-dir-length

Backlog item `iso-plug-in-an-iso-9660-folder-length-of-2-gib-or-more-shows` - ISO plug-in: an ISO 9660
folder length of 2 GiB or more shows a stuck memory box.

## Measurement before (main 618dae27)

- Site: `src/plugins/uniso/iso9660.cpp` `CISO9660::ListDirectoryRe` - `int size = root->DataLength;`
  then `char* data = new char[size];`. The only check before was `size == 0`.
- Callers (Grep `ListDirectoryRe`): `CISO9660::ListDirectory` (the fit walk and the listing walk), the
  count walk (`iso9660.cpp` ~669), and itself for every subfolder. Joliet (`Ext == extJoliet`) and the
  ISO 9660 part of a UDF hybrid (`CUDFISO::ListDirectory` -> `ISO->ListDirectory`) use the same function
  - the one site. File extraction (`CISO9660::UnpackFile`) reads a sector at a time
  (`new BYTE[sectorUserSize]`) - no allocation by a file's `DataLength`.
- Reachable from the user: Unpack (Alt+F9) of an image in the panel, or opening it (Enter).
- `.\build.cmd` (up to date), then the new probe on the hidden desktop:

  ```text
  powershell -File tools\run_on_hidden_desktop.ps1 -Log <scratch>\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <scratch>\iso403_probe.ps1 -Exe E:\Projects\tandemcommander\build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -Lib E:\Projects\tandemcommander\specs\098-long-path-overruns\probe\fix_probe_lib.ps1"
  ```

  Result `probe/result_before.txt`: 6 PASS / 6 FAIL. IS-NEG (0xFFFFF800), IS-NEG2 (401 review's
  `isoneg`), IS-MIN (0x80000000): "Insufficient memory to allocate 18446744073709549568 bytes"; the
  probe answers Ignore, the core asks "Do you really want to pass memory allocation error ...", Yes ->
  the allocation throws (MSVC `new` on a NULL from the handler), nothing catches it: "A problem has
  occurred, forcing Tandem Commander to close" + bug report; nothing extracted, the image kept. So the
  item understated it: Ignore also ends the program, not only Abort. Controls PASS: IS-HUGE (0x7FFFF800 -
  a 2 GiB buffer is allocated, the read fails at the image end, one box), IS-PAST, IS-EDGE.
- Registry restored and identical (SHA-256 equal).

## Decisions

- The rule `SalIsoDirLengthReadable` (pure, `src/common/salisowalk.h`, the header of 400 / 401): a length
  1 .. 256 MiB. Above it (also every length >= 2 GiB) the folder is a folder that cannot be read.
- Past the end: for a folder of more than one sector, its last sector is read (1 byte copied) before
  the buffer is allocated; a failed read = the same error path. The last block is computed in 64 bits
  (`SalIsoDirLastBlock`), a block past 0xFFFFFFFF refused.
- The error path is the existing one of a failed `ReadBlock`: the box once per walk (quiet in the fit /
  count walks), ERR_TERMINATE (ERR_CONTINUE for the root), the listing marked by `ListDirectory`.

## speckit-analyze

No CRITICAL / HIGH. LOW, accepted: C1 FR-007 has no own task (no .rc / spl_*.h touched - checked by the
review); C2 the quiet fit / count walks are not driven by the probe (they take the unchanged
SalIsoWalkBoxQuiet path); U1 the 1-byte last-sector read relies on ReadBlock copying `remain` bytes
(confirmed in CISOImage::ReadBlock).

## Implementation

- `src/common/salisowalk.h`: `SAL_ISO_DIR_MAX_LENGTH` (256 MiB), `SalIsoDirLengthReadable(length)`,
  `SalIsoDirLastBlock(block, length, sectorSize, &last)` - 64-bit; first draft computed
  `block + (length - 1) / sectorSize` and compared the sum, which wraps for a small block and a huge
  length (2, 2^64-1, 1 -> 0): changed to compare the sectors after the first with the room left
  (`more > 0xFFFFFFFF - block`), with a check for it.
- `src/plugins/uniso/isoimage.h`: `CISOImage::GetSectorUserSize()` (the bytes ReadBlock takes a sector).
- `src/plugins/uniso/iso9660.cpp` `CISO9660::ListDirectoryRe`: the record's length is a `DWORD length`
  (the 0 check and the visit key use it - same key value as 401); after the visited check and before
  the allocation: `SalIsoDirLengthReadable`, and for a folder longer than one sector its last sector
  read (1 byte, `ReadBlock`); either fails -> the failed-read path (box once per walk, ERR_TERMINATE /
  ERR_CONTINUE for the root). Only then `int size = (int)length` for the rest - keeping `size` a
  `DWORD` throughout was rejected: the record loop's `offset < size - 0x21` would underflow for a
  folder shorter than 0x21 bytes and read past the buffer (as `int` the loop is not entered).
- `src/saltests/saltests.cpp`: `TestIsoDirLength403` (32 checks).

## Checks after

- `.\build.cmd` -> BUILD SUCCEEDED, exit 0.
- saltests: 282,383 (402) -> `saltests: 282415 checks, 0 failed`.
- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- clang-format: no difference on the changed lines of iso9660.cpp, isoimage.h, salisowalk.h; in
  saltests.cpp only trailing-comment alignment, as the rest of the file.
- Probe `iso403_probe` after (`probe/result_after.txt`): **12 PASS / 0 FAIL** (before 6 / 6). IS-NEG,
  IS-NEG2, IS-MIN, IS-HUGE, IS-PAST: one box "Error reading directory structure at sector #00000015
  (#00000018 for IS-PAST). Incomplete content of ISO image.", the other files extracted, image kept,
  no memory box, no report; IS-EDGE: everything, no window, image deleted. Registry identical.
- Regression probes (hidden desktop, `probe/regress_<NNN>.txt`, registry identical each): 328 **20 / 0**,
  400 **48 / 0**, 401 **10 / 0**, 402 **10 / 0** - as at their closing.
- Negative controls: (1) the probe before (main 618dae27, `probe/result_before.txt`) 6 / 6 - IS-NEG,
  IS-NEG2, IS-MIN fail with the memory box and a program end; (2) mutants of the rules
  (`SalIsoDirLengthReadable` without the limit, `SalIsoDirLastBlock` without the room check): build
  succeeded, `saltests: 282415 checks, 15 failed` (8 length checks, 4 wrap / past-0xFFFFFFFF checks,
  3 more cascade through the shared `last`); header restored (no `MUTANT` left), rebuilt,
  `saltests: 282415 checks, 0 failed`. A probe run of the length mutant alone would still pass IS-NEG
  (the last-sector read refuses those lengths too - past the 25-sector image), so the probe's negative
  control is main.

## Review

### Review 1 (refute-first, independent agent)

- MUST: none. Re-ran saltests (282,415 / 0) and `iso403_probe` (12 / 0, registry identical); callers
  enumerated (fit walk, listing walk, count walk, itself); the last-sector arithmetic matches ReadBlock;
  the plug-in ABI untouched.
- SHOULD 1 - nested readable folders: a folder's buffer is held while the walk descends its subfolders,
  so a chain of folders of 256 MiB each (all readable) took 256 MiB more per level - measured by the
  reviewer (`deep403.py`): peak private bytes depth 0 305 MiB, depth 1 547 MiB, depth 6 1,829 MiB; ~125
  levels fit the listing's path -> the memory box again on a machine with less memory. Not a regression
  (before, 2 GiB a level). **Fixed** (inside the item: "no way to end the program from a damaged image"):
  `SalIsoDirTake` / `SalIsoDirGive` (salisowalk.h) - the bytes of the buffers the walk holds at once,
  `CISO9660::DirBytesHeld` (a member, not in `Walk`: a count walk swaps `Walk` while the listing walk
  still holds its buffers), taken after the last-sector read and before the allocation, given back by an
  RAII guard on every way out; past 256 MiB together = a folder that cannot be read. saltests
  282,415 -> 282,430 / 0 (15 checks, the chain of 125 levels and a real deep tree of 100 x 64 KiB).
- NOTE 1 - the probe proved only the 2 GiB part (IS-HUGE / IS-PAST pass on main). **Done**: rows
  IS-OVER (a readable folder of 256 MiB + 2048 inside a 256 MiB image - refused only by the limit) and
  IS-DEEP (D of 128 MiB holding A0..A2 of 128 MiB each, nested). The past-the-end check before the
  allocation is still proven by saltests only (telling it apart needs a peak-memory measurement) -
  accepted.
- NOTE 2 - NRG: `GetSectorOffset(int)` makes a block >= 0x80000000 negative; with NRG's DataOffset a last
  block in 0xFFFFFF6A..0xFFFFFFFF can land on a valid offset, so up to 256 MiB is allocated before the real
  read fails with the same box - bounded by the limit; accepted (pre-existing int parameter).
- NOTE 3 - Joliet / UDF-hybrid not probed: the same function; accepted.
- NOTE 4 - xdvdfs.cpp / nrg.cpp unchecked allocations: already Inbox items
  (`iso-plug-in-an-xbox-folder-entry-claiming-a-huge-size`, `iso-plug-in-an-nrg-etnf-chunk-claiming-a-huge-size`).

After the fix: `.\build.cmd` BUILD SUCCEEDED; saltests 282,430 / 0; encoding guard TOTAL: 0; probe
`result_after_review1.txt` **16 PASS / 0 FAIL** (IS-DEEP: one box at sector #00000017 - A0, D read;
IS-OVER: one box at #00000016). Negative control (budget off: `SalIsoDirTake` without the held check):
saltests 6 failed; probe `-Only IS-DEEP,IS-OVER` (`result_negctl_budget.txt`) IS-DEEP FAIL (no box, the
image deleted - every level read), IS-OVER PASS (the length rule); restored, rebuilt, 0 failed.
Regression probes after the review fix (`probe/regress_<NNN>_review1.txt`): 328 20 / 0, 400 48 / 0,
401 10 / 0, 402 10 / 0; registry identical each.

### Review 2 (refute-first, independent agent; the review-1 fix)

- MUST: none. Rebuilt (17:19 - the header's newer time stamp came from `unix2dos` before the commit
  restoring CRLF, the content was the one built and probed), saltests 282,430 / 0, `iso403_probe` 16 / 0 +
  its own row; callers enumerated again (fit, listing, CountUnder, recursion, CUDFISO's own CISO9660 -
  DirBytesHeld starts at 0); the count walk keeps DirBytesHeld (right: the listing walk holds its
  ancestors' buffers); the RAII guard gives back on every exit; fail closed throughout.
- SHOULD 1 - a readable subfolder of exactly 256 MiB under a 2048-byte root is refused (its IS-EXACT row:
  d/d1.txt missing, one box, image kept), against the spec's edge case and FR-006 ("1 byte to the
  limit"). **Done** (conservative - the budget is the review-1 fix and keeps the bound): FR-006 and the
  edge case reworded (a folder below the root gets the limit less its ancestors' buffers); saltests
  checks for it (held 2048: the whole limit refused, the limit - 2048 taken). No real image comes near.
- NOTE 1 - the recorded probes ran before that rebuild: 403 re-run on the final binaries
  (`probe/result_final.txt`, uniso.spl 17:19): **16 PASS / 0 FAIL**, registry identical; the uniso code
  of the regression runs is the same content.
- NOTE 2 - a folder refused deep in a chain and met again higher up is listed empty without a box (the
  visited key is added before the refusal) - the listing is already marked, the image kept; crafted only;
  accepted (328's "met again" rule).
- NOTE 3 - time is not bounded: many sibling folders under 256 MiB with distinct lengths are each read
  (fit walk and listing walk) - pre-existing (worse at 2 GiB), no memory box; the listing budget is Inbox
  `iso-plug-in-a-crafted-image-of-folders-naming-one-directory`; accepted.
- NOTE 4 - the last-sector read costs two seeks per multi-sector folder per walk; negligible on a file,
  noticeable on an optical drive; accepted (only folders longer than one sector).
- NOTE 5 / 6 - confirm the accepted past-the-end limit and the budget negative control.

After: `.\build.cmd` BUILD SUCCEEDED; saltests **282,433 / 0**; encoding guard TOTAL: 0.
