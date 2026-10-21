# Fix log: 275 - F3 / F4 of archive members whose path inside the archive has 520+ bytes

Backlog item `f3-f4-refuse-archive-members-whose-path-inside-the-archive` (source leftover:260).

## Measured at HEAD (66245537, on `main`, before the feature)

- `.\build.cmd` (Debug x64, up to date), then on the hidden desktop
  `specs/260-archive-cache-long-names/probe/cache260_probe.ps1` -> 16 PASS / 0 FAIL
  (`%TEMP%\tc275scratch\result_260_at_head.txt`). Row ARCCAP: a ZIP member of 200 CJK letters +
  `.txt` (604 bytes / 204 units) - F3: "Unable to unpack file from archive to temporary directory
  because resulting filename is too long." although the temporary path (about 249 units) fits
  feature 260's rule. The defect is present.
- Sites (Grep `2 \* MAX_PATH` / `IDS_UNPACKTOOLONGNAME`): `src/fileswn5.cpp` `ViewFile` (F3)
  `strlen(dcFileName + dcKeyLen + 1) >= 2 * MAX_PATH`; `src/fileswn6.cpp` `ExecuteFromArchive`
  (F4 / Enter) `strlen(nameInArchive) >= 2 * MAX_PATH`. These are the only two callers of
  `PackUnpackOneFile` (`src/pack1.cpp`).
- Bound of the input: `CSalamanderDirectory::AddFile` / `AddDir` (`src/zip.cpp`) refuse a path part
  over `MAX_PATH - 5` bytes and a name over 255 UTF-16 units -> a path inside the archive has at
  most about 251 + 1 + 765 bytes.
- Plug-in interface: every loaded plug-in is built for >= 104 (<= 103 refused at load); 104's
  promise is name components of 3 * 255 bytes and long paths; F5 hands such names to archivers
  since 222. Lifting the core test changes no interface.

## Consumers enumerated (fix protocol)

`PackUnpackOneFile` -> plug-in route `CPluginData::UnpackOneFile` (`plugins1.cpp`, no limit; only
the archive-name check of 097) -> `CPluginInterfaceForArchiver::UnpackOneFile` of the plug-in; or
the external-archiver route (`pack1.cpp`): `PackExpandCmdLine` into `cmdLine[PACK_CMDLINE_MAXLEN]`
(1040 bytes) - `ExpandVarString` refuses with "Expanded string is too large." + IDS_PACKERR_CMDLNERR;
the move target is on the heap. No cut.

Audit of the archivers' `UnpackOneFile` (independent agent, by reading):

| plug-in | 700 bytes | site |
|---|---|---|
| ZIP | works (stored name compared in a 64 KiB heap buffer; target on the heap) | - |
| 7-Zip | works (member by index; `nameInArchive` unused; heap target, refusing append) | - |
| tar / deb / rpm / cpio / streams | works (`strcmp` against heap names; GNU long names up to 10000 bytes) | - |
| uniso | works (heap `CU8PathBuf`, refusing `SalPathAppend` + message) | - |
| uncab | works (at most 765 bytes reach it) | `rootDir[U8_MAX_CAB_NAME]` + `lstrcpyn` = a silent cut at 769+ (hardening, FR-003) |
| unrar (off) | overflows already at 260+ | Inbox item exists (`unrar-plug-in-a-member-name-over-259-bytes-overflows-a-stack`) |
| unchm (off) | overflows already at 260+; a refused join reports success | -> new Inbox item |
| unole / unmime / demoplug (off) | no length issue reachable | - |

Found on the way (not this item): the tar plug-in ignores PAX `x` / `g` headers in the listing
(`untar.cpp`) - a long PAX path is listed under the ustar fallback name -> to verify, Inbox item.
The uniso listing builds paths in `char path[4 * MAX_PATH + 2]` with unbounded `strcat` - only
reachable if the core's listing ever accepted folder parts over 255 bytes (noted in the contract).

## Analyze

`speckit-analyze` (one run): 0 CRITICAL, 0 HIGH, 0 MEDIUM, 3 LOW - accepted: C1 case-twin members
(F3's `:0x<pointer>` key suffix) have no probe row - the heap copy of the path is kept, the code is
unchanged; C2 Enter (open by association) goes through the same `ExecuteFromArchive` as F4, the
probe drives F4 only; U1 the CAB refusal is verified by reading (no real cabinet holds such a path).

## Probe before (T002)

`probe/arcmember275_probe.ps1` on the build without the source change -> `probe/result_before.txt`:
**9 PASS / 5 FAIL** - VIEWCAP, VIEWDEEP, EDITCAP, 7Z, TAR refused with "Unable to unpack file from
archive to temporary directory because resulting filename is too long."; OVERLIMIT (the cache's
refusal) and CTL pass (controls).
- First run of EDITCAP (both builds): F4 never ran - focusing a member this long shows the
  information line's "Expanded string is too large." (pre-existing, Inbox
  `focusing-an-archive-member-with-a-very-long-name-shows`), and the F4 posted while that box was
  open was lost (after: 13 / 1). The probe now answers that box first and reports it; the
  before-run was repeated on a build of the unchanged sources (`git stash` of the three source
  files, `.\build.cmd`, probe, `git stash pop`, `.\build.cmd`): EDITCAP now shows the real refusal.

## Work

- `src/fileswn5.cpp` `ViewFile` (F3) and `src/fileswn6.cpp` `ExecuteFromArchive` (F4 / Enter): the
  095 test (`>= 2 * MAX_PATH` -> IDS_UNPACKTOOLONGNAME) removed; F3 keeps the heap copy of the path
  (the key may get the `:0x<pointer>` case-twin suffix). The cache's refusal (feature 260) is the
  only length refusal left before extraction.
- `src/plugins/uncab/uncab.cpp` `UnpackOneFile`: a path inside the cabinet of `U8_MAX_CAB_NAME`
  (769) bytes or more -> `Error(IDS_TOOLONGNAME)` ("Can't finish operation because of too long path
  name.") before the copy; `strcpy` instead of the cutting `lstrcpyn`. Unreachable with a real
  cabinet (at most 765 bytes) - by reading.
- `specs/260-archive-cache-long-names/probe/cache260_probe.ps1` ARCCAP expects the viewer;
  `specs/260-.../contracts/cache-tmp-path.md` points to `contracts/arc-member-path.md`.

## Checks

- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s).
- `.\build.cmd` -> BUILD SUCCEEDED (tandemcommander.exe, uncab.spl rebuilt).
- saltests -> `saltests: 24859 checks, 0 failed` (no rule changed).

## Probe after (T010, T011)

- `probe/result_after.txt`: **14 PASS / 0 FAIL** - VIEWCAP (604 bytes), VIEWDEEP (557 bytes: a
  folder of 84 CJK letters + 100 letters), 7Z (7z.exe archive), TAR (GNU long name) open the viewer
  on `%TEMP%\SALxxx.tmp\<whole name>`; EDITCAP: Notepad started, the copy (649 bytes / 249 units)
  rewritten, leaving the archive asked the ZIP plug-in's "Confirm File Overwrite" (Yes) - the archive
  holds ONE member, 604 bytes of name, "EDITED-CONTENT". This also drives feature 260's
  `CheckAndPackAndClear` fix for the first time (a copy path over the old 620-byte cut - review S1 of
  260 said it needed a long %TEMP%; a long member name reaches it with the system %TEMP%).
  OVERLIMIT refused as before; CTL passes.
- Regressions: feature 260's probe -> `probe/regress_260.txt` **16 / 0** (ARCCAP: the viewer opens;
  the same row failed at HEAD, `%TEMP%\tc275scratch\result_260_at_head.txt` with the old expectation
  showing the refusal); feature 222's probe -> `probe/regress_222.txt` **10 / 0**.
- Registry: every run restored, identical (SHA-256 BA9B23CF...).

## New Inbox items (measure:275)

- `unchm-plug-in-a-member-path-over-259-bytes-overflows-a-stack` - the disabled CHM plug-in's
  `lstrcpy(srcPath[MAX_PATH], nameInArchive)` and its false success.
- `tar-plug-in-ignores-pax-extended-headers` - PAX `x` / `g` headers ignored by the listing.

## Review

### Review 1 (refute-first, independent agent) - 1 MUST, 2 SHOULD, 4 NOTE

Re-ran the probe (14 / 0) and a scratch probe of its own (`%TEMP%\tc275rev\deep_probe.ps1`).
- **M1** the Archive Update dialog (`CFileTimeStamps::AddFilesToListBox`, `src/salamdr3.cpp`) built
  each line in `char buf[3 * MAX_PATH]` with `SalPathAppend`'s result ignored: an edited member whose
  path inside the archive has 780+ bytes (folder 84 CJK + name 200 CJK = 857 bytes) was listed as
  its folder only - newly reachable through 275 (F4 refused 520+ before). Update All packed it
  correctly. **Fixed**: the line on the heap (`CSalHeapString`); on low memory the bare name keeps
  the line (the buttons use the list's indexes). Probe rows EDITDEEP / EDITDEEP-LIST added:
  on the build without the M1 fix `probe/result_review1_before_fix.txt` 16 / 1 (EDITDEEP-LIST: the
  item 252 bytes = the folder only; the first try of the row did not catch the dialog - a box before
  it was not answered; the reviewer's loop branch taken over), with the fix
  `probe/result_after.txt` **17 / 0** (the item 857 bytes, whole).
- **S1** CHANGELOG still stated the 520-byte limit (the 260 entry) - **fixed**: the 260 entry's
  *Now* / *Limitation* say the limit was lifted by 275; a 275 entry added.
- **S2** the probe's view rows passed on any viewer window and no edit row reached 780 bytes -
  **fixed**: view rows also require the copy's whole name in the viewer's title; EDITDEEP added.
- N1 *Copy Selected To...* refuses deep long members ("too long name", the shell call's 259-unit
  limit) - a refusal, not a cut -> Inbox `archive-update-copy-selected-to-refuses-long-targets`
  (review:275).
- N2 the ~1,021-byte bound holds for listings with a path; `AddFile` with a NULL path checks no
  length - the cache's rule refuses such names first, except F3 of an invalid name (its prefix goes
  to the cache); shipped: only tar's single-file streams (255 units, 260). Contract wording adjusted.
- N3 the uncab change is correct by reading. N4 the external route refuses, never cuts; its
  `onlyName` keeps the backslash (a doubled backslash in the move target - harmless, pre-existing).

After the fixes: `.\build.cmd` BUILD SUCCEEDED; saltests 24859 / 0; encoding guard 0; probe 17 / 0;
`probe/regress_260.txt` 16 / 0; `probe/regress_222.txt` 10 / 0 (rerun on the final build).

### Review 2 (fresh agent, with review 1's findings) - no MUST, 1 SHOULD, 4 NOTE

Re-ran the probe (17 / 0, `%TEMP%\tc275rev2\result.txt`); confirmed M1 / S1 / S2; read the packing
back (`CheckAndPackAndClear`, `PackCompress`, ZIP `PackToArchive` and its "Confirm File Overwrite"
text, 7-Zip `CFileItem`), the disk cache, history / Find, the viewer / editor launch - heap or
refusing. Drove 7-Zip edit-back itself (`%TEMP%\tc275rev2\edit7z.ps1`): a 604-byte member at the top
and an 857-byte member in a folder go back under the whole path with the new content.
- **S1** the CHANGELOG generalised editing to every archive type - **fixed**: "Editing was tried
  with ZIP and 7-Zip archives; ISO images and CAB archives were checked by reading only."
- N1 the information line's "Expanded string is too large." also shows after the viewer closes -
  the CHANGELOG limitation says so now; the Inbox item exists.
- N2 on low memory the Archive Update line shows the bare name (display only; packing uses the
  item's fields) - accepted.
- N3 uncab's `Error()` may append a stale system text to the refusal - as the function's other
  refusals; unreachable - accepted.
- N4 deep members of 7z / tar under F3, uniso, CAB and the maximum ~1,021-byte path are by reading -
  every buffer on those routes is heap or refusing.
