# Fix log: feature 107 - a folder is never copied or moved onto another path of itself

Branch `107-folder-alias-move`, from `106-zip-overwrite-source` (30513653). Decisions by the author
(the maintainer asked for autonomy): `spec.md` *Clarifications*. Research and the measurements behind
every decision: `research.md`. Pre-change build: `build\tandemcommander\Debug_x64_pre107` (copied
before the first build of this feature, without `Intermediate`; no other build tree was created).
Not committed: the maintainer commits after an independent review.

## T002/T003 - measured first

`research.md` sections 0-3 and `probe/folderalias_result_pre107.txt`. In short: on the build before
this feature a folder moved "into the same place" lost its **empty subfolders** through eight aliases
(`\\localhost\C$`, `\\127.0.0.1\C$`, a mapped drive, SUBST, a second WebDAV server name, and on the
same drive a junction, the 8.3 spelling of a folder above it, the NFC spelling of an NFD-stored WebDAV
folder); a folder moved **into itself or into its own subfolder** through an other-root alias had its
whole content moved one level down and the originals deleted. No file content was lost anywhere (103
refuses the files); copies lose nothing (a copy into itself is a snapshot, by name and through every
alias; a copy onto itself is refused per file). The hard link through an alias: "Confirm File
Overwrite" with two identical lines, then "Error Deleting File (32)" (six aliases).

## T005 - S1: the rules (`src/common/salsamefile.h`, header-only; `salfileio.{h,cpp}`)

| Piece | What it does |
|---|---|
| `SalHasUsableFileId` | an id that is neither all zeros nor all ones (128-bit or 64-bit) |
| `SalDirIsSame(src, tgt, failClosed, pathsMatch)` | one side unreadable -> `failClosed`; snapshot tags differ -> not; equal ids -> same (FAT/FAT32/exFAT: only with equal times); different ids -> not; one side with a usable id, the other without (local/SMB vs WebDAV) -> not (two file systems); no ids on both -> equal kind + times (whole seconds) **and** `pathsMatch` (after the review; first version: the folder's name) |
| `SalDirChainHolds(src, chain, n, pathsMatch[])` | the index of the chain entry (T, its parent, ... the root) that is the source, or -1 |
| `SalSnapshotTagFromPath`, `SalFsNameHasWeakIds`, `SalFileIdentityVolumeTraits`, `SalGetFileIdentityW(..., volumeTraits)` (review SF1) | `CSalFileIdentity::SnapshotTag` (FNV hash of a `HarddiskVolumeShadowCopyN` component of the handle's final NT path or of an `@GMT-YYYY.MM.DD-HH.MM.SS` component of the opened path; 0 = live) and `WeakIds` (file system name FAT*/exFAT), read only when asked - the folder checks ask, 103's/106's file rules do not |
| `SalPathsBelowServerLooselyEqualU8`, `SalCanonicalBelowServerU8Alloc` (`salfileio`, review SF2 + re-check) | both paths resolved (`SalGetFinalPathU8Alloc`), then below the server name with a `DavWWWRoot` component dropped, trailing backslash ignored, one path up to case and NFC; unresolvable -> the folder names |
| `CSalSameEntry`, `SalSameDirEntry(srcDir, tgtDir, srcName, tgtName)` | one directory entry or two: two holding folders known different -> no; known equal -> the stored names decide (`wcscmp`); anything unreadable -> unknown |
| `SalDecideExistingTargetEx(copy, err, src, tgt, sameEntry)` | 103's rule, except a copy with equal ids and more than one link: `sseNo` -> the old handling, `sseYes` / `sseUnknown` -> refuse. `SalDecideExistingTarget` = `Ex(..., sseNo)` (the plug-ins: unchanged) |
| `SalDecideNeedsSameEntry` | only that rare case pays for the look-ups |
| `SalSameDirEntryU8(src, tgt)` (`salfileio`) | the holding folders' identities (through links; `C:` / `\\server\share` get their backslash) + `FindFirstFileW`'s `cFileName` of each path (the stored long name, whatever spelling the path used) |
| `SalGetFinalPathU8Alloc` (`salfileio`) | `GetFinalPathNameByHandleW(FILE_NAME_NORMALIZED | VOLUME_NAME_DOS)` of an attribute-only open, `\\?\` stripped, `\\?\UNC\` -> `\\` |
| `SalNamesLooselyEqualU8` (`salfileio`) | one name up to case and NFC (`SalNameEqualOrdinalCI`, else NFC + `CompareStringOrdinal(TRUE)`) |

## T006 - S2: at script build (`fileswn6.cpp`)

`BuildScriptDir`, the top-level folder of a copy or move (`firstLevelDir`), only when the target path
differs from the source path by name (`SalNameEqualOrdinalCI`; the same path by name keeps every old
branch - the `strcmp` refusal, 092's case-only rename, `BuildScriptFile`'s refusals), right before the
move branch: `DirTargetIsSource107(type, source, attr, T, T\name, exists)`:
1. `T\name` exists and `SalDirIsSame(source, T\name, failClosed = move)` -> refuse. A link as the source
   is compared as the link itself (moving it "onto itself" copied its content onto itself and then
   removed the link).
2. A move of a real folder: `T` or a folder above it is the source -> refuse. `CDirTargetChain107` reads
   the identities and names along the path as written and along `SalGetFinalPathU8Alloc`'s path (a
   junction in the middle); it lives in a `CDirChainScope107` that `BuildScriptMain`,
   `BuildScriptMain2` (paste, drag & drop) and `MoveFiles` (the plug-ins' unpack-and-move) declare, so
   it is read once per operation and freed with it; without a scope it is read per folder. Low memory
   -> a move refuses.

Refusal: `SalMessageBox(LoadStrU8(IDS_CANNOTMOVEDIRTOITSELF | IDS_CANNOTCOPYFILETOITSELF),
LoadStrU8(IDS_ERRORTITLE))`, the build returns FALSE - the operation ends before anything is touched,
as the by-name check does.

## T007/T008 - S3: in the worker (`worker.cpp`)

`DoCreateDir`, "directory overwrite" (the target folder exists), **before** "Confirm Directory
Overwrite": the source folder against the existing one (`SalDirIsSame`, fail-closed for a move,
`pathsMatch` from the two full paths, identities with the snapshot tag) -> the worker's error dialog ("Copy Error"/"Move Error",
the folder, "Cannot copy a file to itself."/"Cannot move a directory to itself.") with Retry / Skip /
Skip All (`SkipAllSameFile`, shared with 103's file refusal - one class) / Cancel; Skip leaves the
whole subtree out, its deletions included. This is the second line for a junction BELOW the top level
pointing back into the source (probe rows `deep-junc-*`).

`DoCopyFile` (103's refusal): when `SalDecideNeedsSameEntry`, `sameEntry = SalSameDirEntryU8(source,
target)` and `SalDecideExistingTargetEx` decides.

## T009 - S4: saltests `TestFolderAlias107`

13,588 -> **13,756** checks, 0 failed (13,717 before the review, 13,747 before the re-check). Pure: `SalDirIsSame` (ids, WebDAV maybe, paths, mixed ids, snapshot tags, FAT,
unreadable both ways), `SalDirChainHolds` (into itself, into a subfolder, a sibling, the parent as the
target, names), `SalSameDirEntry` (one entry, another link, case-sensitive pair, another folder,
unknown), `SalDecideExistingTargetEx` / `SalDecideNeedsSameEntry`, and `SalDecideExistingTarget` ==
`Ex(sseNo)` over a 5 x 5 x 2 table. Real NTFS (`%TEMP%`): one folder through another case, the 8.3
spelling of a folder above, `\\localhost\C$`; two folders created in one second told apart; the chain
of `F\sub`; the final path of an 8.3 / another-case path; hard links in the same folder, another folder,
another case, the 8.3 folder, the link's own 8.3 name, `\\localhost\C$`, a missing name.

## T010 - the probe (`probe/folderalias_probe.ps1`)

Hidden desktop (`tools\run_on_hidden_desktop.ps1`), fixtures under `%TEMP%\tc107\fa`; the probe makes
and removes a SUBST letter (first free of T, U, V, Q, R - T was used), a `net use` drive (first free of
W, Y, X - W was used) mapped to `\\localhost\C$`, junctions, hard links, and starts 103's `davnorm.py`
on port 18107 (`\\localhost@18107\dav` and `\\127.0.0.1@18107\dav`). 103 cases x (RUN + END) since the
re-check (91 after the review, 89 before it):
- 3 shapes (a: into itself, b: the same place, c: into its subfolder) x 10 aliases (plain, UNC, IP,
  SUBST, junction, 8.3, case, mapped drive, WebDAV second name, WebDAV NFD/NFC, a drive letter mapped
  to the WebDAV share, the WebDAV `DavWWWRoot` form) x F5 / F6 = 72 rows;
- paste (Copy / Cut + Paste) for plain, UNC, SUBST, junction, WebDAV: 32 rows NOT DRIVEN (the clipboard
  cannot be opened on the hidden desktop);
- Quick Rename of the folder to its own 8.3 name and to another case;
- hard links: the same entry through UNC, IP, SUBST, junction, 8.3, mapped drive (F5, F6) and another
  link (`b.txt`, by name and through UNC);
- `deep-junc-mov` / `deep-junc-unc-mov` (a junction below the target back into the source),
  `jlink-unc-mov` (a junction moved onto itself), `dav-merge-mov` / `dav-twin-merge` (a merge into
  another folder through the second server name, times different / equal), `dav-bak-cpy` /
  `dav-bak-mov` (review SF2: a backup update `a\F` -> `b\` on one server, equal folder times);
- controls: ASCII and Cyrillic copies/moves between two folders, between two roots, merges.

| Run | Result |
|---|---|
| this build after the re-check, `-Expect107` (`probe/folderalias_result.txt`) | **PASS 206, FAIL 0, NOT DRIVEN 32**; all 103 END rows clean |
| this build after the review, before the re-check (91 cases) | PASS 182, FAIL 0, NOT DRIVEN 32 (the `davy` / `davw` rows did not exist - the re-check found them failing open) |
| this build before the review (89 cases) | PASS 178, FAIL 0, NOT DRIVEN 32 (`dav-twin-merge` then refused - the SF2 false refusal) |
| `Debug_x64_pre107` (`probe/folderalias_result_pre107.txt`, 89 cases, run before the `dav-bak-*` rows existed) | PASS 157, **FAIL 21**, NOT DRIVEN 32; all END rows clean |
| `Debug_x64_pre107`, the `davy` / `davw` rows (`probe/folderalias_result_pre107_davyw.txt`) | PASS 18, **FAIL 6** (every move changes the source tree) |

The 21 rows that fail on the build before and pass now: F6 a / b / c through UNC, IP, SUBST, mapped drive
and the second WebDAV name (15); F6 b through a junction, the 8.3 spelling and the WebDAV NFD/NFC
spelling (3); `deep-junc-mov`, `deep-junc-unc-mov` (an empty folder deleted below a junction);
`jlink-unc-mov` (the junction deleted). On this build every one of them shows "Cannot move a directory
to itself." (the deep rows: the worker's "Move Error" for `sub`, the rest moved as asked) and leaves the
source tree identical. Rows that behave as before by design: every F5 a / c (a snapshot copy), F6 b by
name ("Cannot move a directory to itself.", by name), F6 b to another case (092's case-only rename, a
no-op), Quick Rename rows, `hl-*-other` ("Confirm File Overwrite", `b.txt` an independent copy), the
controls, `dav-merge-mov`, `dav-twin-merge` and `dav-bak-*` (merged, as before). Changed without a loss on the build before: F5 b through an alias showed
"Cannot copy a file to itself." once per file (103) - now once, before anything; F6 a / c by name and
through one-drive aliases showed "Error Moving Directory (87 / 5 / 58)" - now "Cannot move a directory
to itself."; the hard link through an alias: "Confirm File Overwrite" + "Error Deleting File (32)" - now
"Cannot copy/move a file to itself.".

## T011/T012 - gates

| What | Result | Baseline (106) |
|---|---|---|
| Debug build (`build.cmd`) | exit 0; no warning in a changed file | - |
| `build.cmd full release` | exit 0, no error lines; 20 plug-ins in `plugins.ver`, 189 language modules, runtime closure OK - repeated after the review's fixes on the final code | - |
| saltests | **13,756 checks, 0 failed** | 13,588 |
| `check_encoding.py --strict` | TOTAL: 0 | 0 |
| 103 `samefile_probe -Expect103` (`regress_samefile103_107.txt`) | PASS 62, FAIL 0 | 62 / 0 |
| 099 `linkmove_probe` (`regress_linkmove099_107.txt`) | PASS 24, FAIL 0 | 24 / 0 |
| 098 `fix_probe` (`regress_fixprobe098_107.txt`) | PASS 107, FAIL 0, NOT DRIVEN 3, INFO 1 | the same |
| 106 `packself_probe` (`regress_packself106_107.txt`) | PASS 70, FAIL 0, NOT DRIVEN 4 | the same |

Every hidden-desktop run: no `tandemcommander.exe` running before; `HKCU\Software\Tandem Commander`
exported before and compared after - SHA-256 `1AB614304771DBE0...` before and after every run (no
restore was needed); nothing left running; the SUBST letter, the `net use` drive and the fixtures under
`%TEMP%\tc107\fa` removed (also checked from outside the probe after every run).

## Decisions recorded (spec.md)

- **A copy of a folder into itself or into its subfolder stays a snapshot copy** (by name and through
  an alias alike, as before): nothing is lost, the script is built before anything is written.
- **No new string**: a refused folder copy says "Cannot copy a file to itself." (the text the by-name
  route has always shown for a folder), a move into a subfolder "Cannot move a directory to itself.".
  Clearer texts ("Cannot copy a directory to itself.", "...into one of its own subfolders") need the
  translation pipeline - queued in NEXT-WORK.
- **Hard links**: the same entry through an alias -> refused; another link (another name or folder) ->
  the old handling - "Confirm File Overwrite", then `b.txt` an independent copy, `a.txt` intact: that
  is what was asked and nothing is lost (NTFS removes the other link while the source is open,
  measured by 103); unreadable -> refused.
- **Two file systems**: a folder with an id is never "the same" as one without (local/SMB vs WebDAV).
  The price: a local folder and a WebDAV alias of the SAME local folder (a WebDAV server on this
  machine serving its own disk) are not recognised - the old behaviour there.
- **WebDAV (no ids)**: two folders count as one only with equal times AND the same path below the
  server name (after the review; see below). Left: two DIFFERENT WebDAV servers mirroring one path
  with kept folder times are taken for one (a refused merge, nothing lost).

## Independent review (ACCEPT) and its fixes

Verdict ACCEPT, no data-safety blocker; the reviewer reproduced the probe (178 / 0 / 32) and ran 54
own cases (two-item selections, an `F` -> `F2` prefix sibling, paths over 300 bytes, SUBST / junction on
`F\sub`, a case-only rename, two NTFS folders with forced equal times, a WebDAV sibling with equal
times, a 120-level target); the build before fails its negative controls as expected. Two SHOULD-FIX
false refusals - both fixed:

- **SF1 - equal ids alone.** A folder restored from a **shadow copy / Previous Versions**
  (`\\localhost\C$\@GMT-...\x`, `\\?\GLOBALROOT\Device\HarddiskVolumeShadowCopyN\x`) or a mounted
  clone keeps the volume serial and the ids of the live folder, so the merge was refused ("Cannot copy
  a file to itself.", also every merged subfolder); on **FAT** the id follows the directory entry. Now
  the folder identities are read with `volumeTraits`: a snapshot tag (from the handle's final NT path,
  or an `@GMT-` component of the path - the SMB client may not report the token back) makes a snapshot
  never equal to the live folder or to another snapshot; on FAT/FAT32/exFAT an equal id counts only
  with equal times. No blanket time check on NTFS/SMB (stale SMB folder times would hide aliases).
  The hard-link entry check reads the holding folders with the tag too (a link restored from a
  snapshot = another entry). 103's file rule: an UNCHANGED file restored from a snapshot is refused
  "to itself" (equal id and metadata: nothing to restore - harmless, recorded); a changed one has other
  metadata and is overwritten as before; not changed. **Not driven**: creating a shadow copy needs an
  administrator, no FAT volume exists here - rule tests only (saltests: device and `@GMT` forms, case,
  another snapshot, a look-alike folder name, the live NTFS volume read on disk = tag 0, not weak).
- **SF2 - folder times alone on WebDAV.** In a merge the target folder has the source's name, so the
  name never discriminated: a backup update `\\dav\a\F` -> `\\dav\b\` whose `b\F` had equal folder
  times (kept times, one archive unpacked twice) was refused, Skip All left changed files uncopied.
  Now, without ids, the whole path below the server name must agree (case + NFC): the two server
  names and the NFC/NFD spelling keep it, a backup in another folder does not. The worker's
  per-subfolder check uses the same rule, so it never decides a WebDAV merge by times alone. Probe
  rows `dav-bak-cpy` / `dav-bak-mov` (same server, `a\F` -> `b\`, equal folder times) and
  `dav-twin-merge` (two server names, equal times) must merge; the alias rows still refuse.

Recorded (review NITs): NIT 3 - a NAS that gives each share its own volume serial: a folder reachable
through two shares is not recognised (the old behaviour); NIT 4 - cost about 1 ms per merged folder
over SMB (1,500 folders through UNC 8.5 -> 10 s), accepted; NIT 5 - the move-into-itself check is
skipped when the source folder cannot be read at all (the move then fails by itself).

After the SF1/SF2 fixes (before the re-check): Debug build exit 0; saltests **13,747 / 0** (rule tests for snapshot
tags, FAT, the path rule, the live volume on disk); strict guard 0; `folderalias_probe -Expect107`
**182 / 0 / 32** (91 cases; `dav-twin-merge`, `dav-bak-cpy`, `dav-bak-mov` merge, every alias row
still refuses); 103 samefile `-Expect103` 62 / 0 and 106 packself 70 / 0 / 4 (`regress_*_107.txt`,
overwritten by these runs; 099 24 / 0 and 098 107 / 0 are from the round before the fixes); full
Release build exit 0. Registry hash `1AB614304771DBE0` before and after every run, nothing left
running, SUBST / `net use` / fixtures removed.

## Targeted re-check of SF1/SF2 (REJECT, one blocker) and its fix

The reviewer re-ran the probe (182 / 0 / 32) and found the SF1 snapshot side fine (also `@GMT-`-named
LIVE folders: refused, no leak), but a **blocker made by the SF2 change**: the path rule compared the
TYPED paths, so the same WebDAV folder under another form of its path counted as another folder and
the move failed OPEN. Driven by the reviewer (source `\\localhost@18107\dav\...\parentlong`, F6 of F):
a drive letter mapped to the share (`Y:\...\parentlong\`, shape b) and the redirector's root form
(`\\localhost@18107\DavWWWRoot\dav\...`, shapes a/b/c) deleted the empty folders or moved the content
one level down - all of which the first (name) version had refused. Fixed:

- `SalPathsBelowServerLooselyEqualU8` now resolves **both** sides first (`SalGetFinalPathU8Alloc`:
  measured on the WebDAV server - a mapped letter `Y:\x\F` resolves to `\\?\UNC\localhost@port\dav\x\F`,
  the `DavWWWRoot` form stays as typed, both NT forms are `\Device\Mup\...`), then canonicalises with
  the pure `SalCanonicalBelowServerU8Alloc` (drop the server component - any name, IP, `@SSL`, `@port`
  - and a following `DavWWWRoot` component; drop a trailing backslash) and compares folded (case +
  NFC). A side that cannot be resolved falls back to the folder names (a "maybe" - fail closed). The
  same function serves check 1, the chain and the worker's merge check.
- Snapshot test (NITs): the final NT path is read with a buffer of its own length (was a fixed 1,024
  characters); when it cannot be read and the typed path shows no token, `SnapshotUnknown` is set and
  the snapshot test never makes two folders "different" (the ids decide - fail closed).
- The test server (`specs/103-.../probe/davnorm.py`) answers `PROPFIND /` (the root collection holding
  `dav`), which the redirector needs for the `DavWWWRoot` form (before: "The path ... is invalid").
- Probe rows `{a,b,c}-davy-{cpy,mov}` (a drive letter mapped with `net use` to the WebDAV share, Y)
  and `{a,b,c}-davw-{cpy,mov}` (the `DavWWWRoot` form). On `Debug_x64_pre107`
  (`probe/folderalias_result_pre107_davyw.txt`): **PASS 18, FAIL 6** - every move (a/b/c, both forms)
  changes the source tree (empty folders deleted / content moved one level down), copies as before.

Recorded (re-check NITs): the `@GMT` tag is any `@GMT-` + 19 characters as a whole component (not the
exact format) - harmless, both sides of a live folder carry it; two differently named `@GMT` folders
joined by a junction could give the two sides different tags (a missed alias - not reproducible
without snapshots); on FAT, two views reporting different times would miss an alias (reasoned).

After the re-check fix (final tree): Debug build exit 0; saltests **13,756 / 0** (canonical forms:
two server names, `DavWWWRoot` in any case, `@SSL@443`, a look-alike component, roots, unresolved
input; the resolved rule on disk: one folder by two spellings, two folders, unresolvable paths ->
names; `SnapshotUnknown` lets the ids decide); strict guard 0; `folderalias_probe -Expect107` **206 / 0 /
32** (103 cases: every `davy` / `davw` move refused "Cannot move a directory to itself.", the copy onto
itself refused, copies into itself as before; `dav-bak-cpy` / `dav-bak-mov` / `dav-twin-merge` /
`dav-merge-mov` merge); regressions on this tree: 103 samefile `-Expect103` 62 / 0, 106 packself
70 / 0 / 4, 099 linkmove 24 / 0, 098 fix_probe 107 / 0 / 3 / 1 INFO (`regress_*_107.txt`); full Release
build exit 0 (20 plug-ins, 189 language modules, runtime closure OK). Registry hash
`1AB614304771DBE0` before and after every run; nothing left running; SUBST, both `net use` drives and
the fixtures removed. (A deviceless connection `\\localhost@18107\DavWWWRoot` listed by `net use`
existed before this round's first `DavWWWRoot` row and was not created by these probes - left alone.)

## Not driven

- **Paste** (Ctrl+C / Ctrl+X, Ctrl+V; 32 probe rows): the clipboard cannot be opened from the hidden
  desktop (098 and 101 met the same). **Drag & drop**: needs a real mouse. Both build their script in
  `DropCopyMove` -> `BuildScriptMain2` -> `BuildScriptDir`, where the check sits; quickstart step 5 is
  the manual pass.
- A real macOS / Samba share (103's open item) - the WebDAV server reproduces the folding.
- The Release build's GUI behaviour (the probes drive the Debug build).

## Recorded, not changed

- The Renamer plug-in never copies a folder between roots (`isDir` -> "Error in the script") and
  refuses to overwrite a directory, so it has no folder-level case.
- The plug-ins' "move files from a temporary folder" service ends in `CFilesWindow::MoveFiles`, which
  builds through `BuildScriptDir` - covered (not driven: its source is a plug-in's temporary folder).

## CLAUDE.md entry

Added to CLAUDE.md by the coordinating session. Final re-check after the SF2 fix: ACCEPT (the
reviewer's five failing cases and further spellings - second mapped letter, IP name, SUBST into the
mapped drive, upper case, trailing dot - refused; backup updates merge; author's WebDAV rows 32/0).

- 107-folder-alias-move: **a folder is never copied or moved onto another path of itself** (103's
  leftovers NIT 4 and NIT 5, measured first). On the build before, F6 of a folder "into the same
  place" through `\\localhost\C$`, `\\127.0.0.1\C$`, a mapped drive, SUBST, a second WebDAV server
  name - and on the same drive through a junction, the 8.3 spelling of a folder above it or a WebDAV
  NFC/NFD spelling - deleted its empty subfolders; F6 into itself or into its own subfolder through
  an other-root alias moved the whole content one level down and deleted the originals; a junction
  below the target pointing back into the source lost an empty folder of the source; a junction moved
  onto itself through UNC was deleted. No file content was lost (103 refuses files), copies lose
  nothing (a copy into itself stays a snapshot copy - decision). Fix: `DirTargetIsSource107` in
  `BuildScriptDir` (top-level folder of every copy/move route: F5/F6, paste and drag & drop via
  `BuildScriptMain2`, the plug-ins' `MoveFiles`), only when the target differs from the source by name:
  `T\name` exists and is the source -> refuse; a move whose target `T` or a folder above it is the
  source -> refuse ("Cannot move a directory to itself.", a copy "Cannot copy a file to itself." - no
  new string). `T`'s chain is read once per operation (`CDirChainScope107`) along the written path and
  the final path (a junction in the middle). Worker: `DoCreateDir` refuses a merge into the source
  folder itself before "Confirm Directory Overwrite" (Skip leaves the subtree and its deletions out; a
  move fails closed). Rules in `src/common/salsamefile.h`: `SalDirIsSame` (ids; without ids equal times
  AND the same path below the server name up to case/NFC; one side with an id and one without = two file systems, so WebDAV
  uploads are not refused), `SalDirChainHolds`, and for hard links `SalSameDirEntry` +
  `SalDecideExistingTargetEx`: the same directory entry through an alias (holding folders' identities +
  `FindFirstFile`'s stored names) is refused as "to itself", another link keeps the old handling; facade
  `SalSameDirEntryU8`, `SalGetFinalPathU8Alloc`, `SalPathsBelowServerLooselyEqualU8` in `salfileio`.
  Independent review ACCEPT with two false refusals fixed: a folder in a snapshot (shadow-copy device
  or `@GMT-` path; `SnapshotTag`, read only by the folder checks via `volumeTraits`) is never the live
  one, so restoring from Previous Versions merges; FAT ids count only with equal times; on WebDAV (no
  ids) the whole path below the server name must agree - both sides resolved first (a mapped drive ->
  UNC, `DavWWWRoot` dropped; the targeted re-check REJECTED a typed-text version that let a mapped
  drive and the `DavWWWRoot` form fail open) - so backup updates with equal folder times merge. Interface stays 107, no registry change. Probe
  `specs/107-folder-alias-move/probe/folderalias_probe.ps1` 206/0 (pre-107 157/21 + 18/6: every FAIL
  a source-tree change); paste and drag & drop NOT DRIVEN (hidden desktop) - a person's pass owed
  (`quickstart.md` step 5); snapshots and FAT rule-tested only; 103's `davnorm.py` now answers
  `PROPFIND /` (the `DavWWWRoot` form). saltests 13,588 -> 13,756. Records:
  `specs/107-folder-alias-move/fix-log.md`.
