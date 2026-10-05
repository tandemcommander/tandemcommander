# Fix log: feature 110 - the ZIP plug-in replaces only the member that has the added file's name

Branch `110-zip-plugin-name-matching` (from `109-disk-cache-archive-key`, HEAD c34af19e). Pre-change
build preserved as `build\tandemcommander\Debug_x64_pre110` (incremental build of HEAD first - no
change - then the binaries copied, `Intermediate` folders left out: 354 MB). All GUI runs on the
hidden desktop (`tools\run_on_hidden_desktop.ps1`), each wrapped: no `tandemcommander.exe` running,
`HKCU\Software\Tandem Commander` exported before and compared after - SHA-256 prefix
`1AB614304771DBE0` before and after every run (the probes also back up / restore / verify the key
themselves). Scratch under `%TEMP%\tc110\`.

## T001 - measured first

Route, every comparison site and the analysis: `research.md`.

- `probe/zip_collision_set.py` (`zip_collision_set_cp1250.txt`): the plug-in's old comparison is
  `CompareStringA(LOCALE_USER_DEFAULT, NORM_IGNORECASE)` on the UTF-8 bytes - a LINGUISTIC comparison
  of code-page text, not the core's byte fold that 108 measured. Over the BMP: 21,925 pairs one name
  for it and two for the file system (1,890 of different byte length, kept apart only by the length
  guard); 944 pairs the other way (case pairs outside ASCII, the 7 different-length case pairs).
  Names of one printable ASCII character: identical to the ASCII fold, case-insensitive and
  case-sensitive (longer ASCII names: see the review, SF2).
- `probe/zipname_probe.ps1` + `probe/zipfix.py` (own ZIP writer and central-directory reader -
  UTF-8 / OEM / raw-byte names, FAT / Unix host; every archive read back with CRC check). On the
  build before (the first run: 10 PASS / 18 FAIL / 2 NOT DRIVEN - `d_unixDir` and `f_split` hit a
  probe defect, a missing `Title` helper and the main window's title format; both re-run after the
  probe fix: FAIL as below; the final file `probe/zipname_result_pre110.txt` is a full re-run with
  the final probe, row `c_unixlen` included):
  - F5 `ĥ.txt` into `{Ĺ.txt}` and the other pair kinds (9 rows): one question, `Ĺ.txt` replaced;
    with both present two questions and the other member gone; Unix ZIP: the added file renamed
    to the other member's spelling - "Cannot open or create file", nothing packed;
  - F4 of one member of a pair (`f_hL1`, `f_hL2`): the other member gone; the 108 review's
    `split_zip` (`f_split`): `ĥ.txt` gone; `f_skip` (*Yes*, then *Skip*): the edited `ĥ.txt` gone and
    `Ĺ.txt` stored twice;
  - accented case pairs and the different-length pair: no question, a second member Windows folds
    onto the first;
  - Unix ZIP `{Dir/a.txt, DIR/b.txt}`, F8 `a.txt` in `Dir` (`d_unixDir`): `Dir` disappears;
  - F8 / F5 out of `{ĥ.txt, Ĺ.txt}` correct; ordinary rows as expected.

## T003 - S1: the rule (`src/common/salzipname.h`, header-only)

Contract `contracts/zip-member-identity.md`. `SalZipNameEqual` (WTF-8 on both sides: ordinal on
UTF-16 via `CompareStringOrdinal`; legacy on both sides: the old `CompareStringA` with the old
equal-length guard; across: never), `SalZipNamePrefix` (covered bytes measured on the path; never
ends inside a character or a surrogate pair), `SalZipMemberIs` (panel folder by the prefix with the
plug-in's old case rule for it - DOS ignore, Unix respect - and the rest ignoring case, as before),
`SalZipMemberIsOrIsIn`. The WTF-8 decoder is the core's (`SalWtf8ToWBytes`) copied, because the ZIP
project cannot compile `salunicode.cpp`. Low memory for names over 259 bytes: only byte-identical
names are equal (the matching then adds - it never deletes a member it did not mean).

## T004 - S2: `add.cpp CZipPack::MatchFiles`

The exact-match test and the Move folder test (empty folders off) through `SalZipMemberIs` /
`SalZipMemberIsOrIsIn`; the byte-length guards are gone (U+023A / U+2C65 ...). The Unix branch that
gives the added file the matched member's spelling copies it from `inZip + rootBytes + 1` (the
folder's bytes counted on the member) and grows `next->Name` when the spelling is longer (before 110
equal lengths were guaranteed by the guard; now `ⱥ` (3 bytes) can replace `Ⱥ` (2 bytes) - probe row
`c_unixlen`); `NameLen` follows.

## T005 - S2: `del.cpp CountFilesInRoot`

The count of files "in the panel folder" uses the selection's folder test (`CZipCommon::MatchFiles`:
`Unix ? memcmp : MemICmp`, name at least as long as the folder) instead of a case-insensitive
`CompareString` (also in a Unix ZIP) - so the number compared with the deleted files is taken by the
same rule that chose them.

## Not changed, by decision (research.md 1)

- `common.cpp CZipCommon::MatchFiles` / `BSearchName` / `CompareExtInfos` (F8, F5 out): files by index
  plus exact name - correct (measured); folders by the core's byte fold = the rule the core's listing
  merged them by. Changing it alone would make F8 on a merged folder delete half of what the panel
  shows. Belongs to the `CSalamanderDirectory` item.
- `extract.cpp CZipUnpack::FindFile`: the member is found by index; the name check only confirms and
  accepts every pair the listing merges (computed: 0 counterexamples).

## T006 - saltests `TestZipName110`

Pair tables (9 different incl. dotless i / Kelvin, NFC/NFD), the 7 different-length pairs built at
run time, every printable ASCII pair against the old comparison (case-insensitive and
case-sensitive), legacy text (never equal to UTF-8), names over 259 bytes (heap), prefixes (covered
bytes, cuts inside a character / surrogate pair, legacy), the matching helpers (root case rule, Unix,
different-length folder, `Dirx`, root longer than the target), brute-force parity with 092's
`SalNameEqualOrdinalCI` / `SalPathHasPrefixOrdinalCI` over 381 strings of a hostile alphabet (and the
old comparison for legacy pairs; 0 cross-equal), real NTFS agreement for every pair. saltests
**13,973 -> 14,132 / 0** (first draft 32,180: the ASCII loop counted one check per pair - folded into
two counters).

## T007 - the probe on both builds

`probe/zipname_result.txt` (this build): **31 PASS / 0 FAIL / 0 NOT DRIVEN**.
`probe/zipname_result_pre110.txt` (`Debug_x64_pre110`, the same final probe): **10 PASS / 21 FAIL**.

| rows | before | after |
|---|---|---|
| F5 of the other name of a pair, 9 kinds (`c_hL`, `c_IY`, `c_zz`, `c_cjk`, `c_cyr`, `c_sub`, `c_inside`, `c_oemhL`, `c_unixhL`) | 1 question, the other member replaced (Unix: "Cannot open or create file", nothing packed) | no question, both members |
| `c_hLboth` / `c_hLskip` | 2 questions, `Ĺ.txt` gone / archive unchanged after *Skip* | 1 question, `ĥ.txt` replaced, `Ĺ.txt` kept |
| `c_merged` (folders the listing merges) | `Ĺ/x.txt` replaced by `ĥ/x.txt` | `ĥ/x.txt` added beside it (behaviour change, recorded) |
| `c_Cc`, `c_len`, `c_oemCc`, `c_unixlen` (one name for Windows) | no question, a second member | 1 question, replaced (Unix: the member's longer spelling kept - the buffer growth) |
| `d_unixDir` | `Dir` gone | empty `Dir/` entry written |
| `f_hL1`, `f_hL2` | 2 questions, the other member gone | 1 question, the other member intact |
| `f_split` (108 review `split_zip`) | 4 questions, `ĥ.txt` gone | 3 questions, every member with its own edit |
| `f_skip` | edited `ĥ.txt` gone, `Ĺ.txt` stored twice | `ĥ.txt` with its edit, `Ĺ.txt` unchanged (its edit skipped as answered) |
| ordinary rows (`c_Aa`, `c_same`, `c_skip`, `c_Cc2`, `c_nfc`, `c_oem`, `c_raw`, `c_unixAa`, `d_hL`, `e_hL`) | PASS | PASS (identical results) |

Probe defects on the way (recorded, fixed in the probe before the final runs): the viewer of F3 is
the Code Viewer (title `<path>\<name> [Plain Text] - Code Viewer`); the main window's title is
`T110 - <folder> - Tandem Commander ...`; a missing `Title` helper; the overwrite question's two names
are painted, not window text (the probe records sizes and dates instead); the Edit/Write tools
turned `\uXXXX` escapes in the script into literal characters, which Windows PowerShell 5.1 then read
as CP1250 - the script is pure ASCII again (checked) and the first `c_unixlen` verdicts (a mangled
expectation, archives correct on both builds) were discarded.

## T008 - regressions and gates

| probe | result | recorded before |
|---|---|---|
| 108 `namecoll_probe` (`probe/regress_namecoll108_110.txt`) | **30 PASS / 0 FAIL**, F4 retries 0 - `hL1_zip`, `hL2_zip` now PASS | 28 / 2 (108) |
| 106 `packself_probe` (`regress_packself106_110.txt`) | PASS 70, FAIL 0, NOT DRIVEN 4 | the same (106, 108) |
| 094 `zip_gui_probe` (`regress_zip094_110.txt`) | AS EXPECTED 56, DIFFERENT 1 (X1, the self-extractor row that cannot be driven in a Debug tree) | the same (094, 106) |
| 096 `archedit_probe` (`regress_archedit096_110.txt`) | 17 of 17 UPDATED | 17 of 17 (108) |

- Debug build (incremental) 0 errors, 0 compiler warnings.
- saltests 14,132 / 0.
- `python tools\check_encoding.py --strict`: TOTAL 0.
- Full Release build (`build.cmd full release`): BUILD SUCCEEDED, 0 errors, no compiler warning (46
  MSBuild "Remote deployment might be slow" notices for language-module recipes of the full build),
  20 plug-ins registered, 189 language modules, runtime closure OK.
- Encoding of touched sources checked with Python: UTF-8 BOM + CRLF kept (`add.cpp`, `del.cpp`,
  `salarcedit.h`); new `salzipname.h` BOM + CRLF; `saltests.cpp` and `saltests.vcxproj` without BOM,
  CRLF; probe scripts ASCII + CRLF; no control characters in any touched file.
- Registry: SHA-256 prefix `1AB614304771DBE0` before and after every one of the 12 GUI runs.

## Found on the way

- **`src/common/salarcedit.h` (108) held a BACKSPACE byte** in a comment (`"Test\b.txt"` written
  through a string literal - the trap the brief warns about). Fixed (comment text only).
- `tools/run_on_hidden_desktop.ps1` (093) holds a CR, a NUL and two TAB bytes in its usage example
  comment (`\r`, `\0`, `\t` sequences of the paths turned into control characters). Not fixed (outside the
  feature; harmless to PowerShell, but the example cannot be copied) - recorded.
- The merged-folder behaviour change (`c_merged`) and the plug-in's folder tests for delete/extract
  belong to the `CSalamanderDirectory` item - NEXT-WORK item 5, entry 4 extended.
- Nothing serious enough for a new queue entry.

## Not driven

- An unpacking-only path through the matching does not exist; Test (archive test) compares no names.
- The Move branch for an empty folder with "do not add empty folders" on (`SalZipMemberIsOrIsIn`):
  rule tested in saltests only (the option is off by default).
- Low memory for names over 259 bytes (the byte-identical fallback): reasoned, not provoked.
- Drag and drop / paste into a ZIP panel: the same core packer call as F5 (106's reasoning).
- Code pages other than 1250: other pairs collided there; the new rule does not depend on the code
  page (`zip_collision_set.py` prints the set of any machine).
- Performance on very large archives: the matching is still members x added files; each comparison
  of two non-ASCII names converts both to UTF-16 (the old linguistic `CompareStringA` converted too).
  Not measured.

## Decisions recorded (spec.md)

- 092's rule for UTF-8 member names (ordinal on UTF-16, case ignored where it was ignored); legacy
  text by the old comparison; never equal across; no byte-length guard.
- Accented case pairs and the 7 different-length case pairs are one name now (overwrite question).
- Delete/extract folder tests stay with the core's listing; `CountFilesInRoot` follows the selection.
- No plug-in interface change (107), no new string, no registry change.

## Independent review (ACCEPT, no blocker) - SF1, SF2, NIT fixed or recorded

The reviewer reproduced 31/0 and checked the length indexing, the Unix buffer growth (incl. a failed
`realloc`), OEM and mixed legacy archives (identical on both builds), `co-op`/`coop` (identical) and
`CountFilesInRoot`.

- **SF1 (data loss newly reachable) - fixed.** `MatchFiles` (`add.cpp`), DOS/Windows ZIP: *Yes* put a
  member on the delete list and left the added file "add"; the next member of the same name was asked
  too, and *Skip* there turned the whole file into "do not add" - the first member deleted, the new
  file never stored. Before 110 only ASCII case pairs reached it (`{ax, Ax, AX}`, every release); 110
  made accented case pairs one name, so `{čx, Čx, ČX}` + F5 of `čx.txt` (Yes, Skip) newly lost
  `čx.txt`. Fix of the old defect itself: `CAddInfo::Replaced` (`add_del.h`) counts the members put on
  the delete list for an added file; *Skip*, *Skip all* (also an already set "skip all") and a source
  that cannot be opened at that question turn the file into "do not add" only while `Replaced` is 0 -
  otherwise they keep only that member. Invariant: a member is deleted only if the added file
  replacing it is stored. Note for probes: with NOTHING left to add the plug-in skips the deletions
  too (`NothingToDo`), so a one-file F5 hid the loss on the build before - the probe rows carry a
  second, unrelated file (`other.txt`).
  Probe rows (3 members one name, F5; answers in order): `r_3ys` Y/S/S, `r_3ysA` (ASCII) Y/S/S,
  `r_3ysy` Y/S/Y, `r_3yyy` Y/Y/Y, `r_3all` All, `r_3s` Skip, `r_3sa` Skip all, `r_3yskipall` Y/Skip all,
  `r_3yc` Y/Cancel (nothing changed), `r_3ysAU` Unix ZIP S/Y (Unix asks again after a Skip; the file
  takes `Ax.txt`), `r_3ysAM` F6 Y/S/S (source stored, then deleted). This build: 11/11
  (`probe/zipname_result.txt`, now **42 PASS / 0 FAIL**). Build before
  (`probe/zipname_result_pre110_review.txt`): 3 PASS / 8 FAIL - `r_3ysA`: `ax.txt` **gone**, the new
  file not stored; `r_3ysAM`: `ax.txt` gone, the source neither stored nor deleted; the accented rows
  fail only by the old rule (one question, `Čx`/`ČX` left beside `čx`). A first run had a probe defect:
  case folders `r_3ysA` and `r_3ysa` are ONE folder on NTFS (renamed `r_3yskipall`).
  Not covered by the invariant (pre-existing, recorded): a read error answered *Skip* while
  `PackFiles` stores a file whose member was already deleted (`DeleteFiles` runs first) - also with one
  member, needs an I/O error.
- **SF2 (claim false) - corrected.** "Printable ASCII behaves exactly as before" held only for names
  of ONE character: the old comparison was linguistic, and on a Czech (Slovak, Hungarian, Croatian ...)
  locale "ch" is one letter - `cHata.txt` / `chata.txt` were two names and are one now (the reviewer:
  1,140 equal-length ASCII pairs of up to 4 characters, all old-two -> new-one). The direction is right
  (Windows sees one file) and nothing is lost (F5 of `cHata.txt` into `{chata.txt}` asks to overwrite
  instead of adding a second member). Wording fixed in `salzipname.h`, spec (FR-002 + Clarification),
  contract, CHANGELOG. saltests: digraph pairs, and every pair of two-letter names (new = ASCII fold;
  pairs differing in one letter: none old-one -> new-two; 6 pairs old-two -> new-one on this locale:
  `cH` against `ch`/`Ch`/`CH`). saltests **14,132 -> 14,140 / 0**.
- **NIT (recorded).** In a folder made case-sensitive on disk (`fsutil file setCaseSensitiveInfo`), a
  Unix-ZIP update renames the added file to the matched member's spelling, which can name another or a
  missing file in that folder - pre-existing for ASCII, now also for accented case pairs. The reviewer
  traced it to no loss; not changed.
- **Probe**: the scratch folder is a parameter (`-Scratch`, default `%TEMP%\tc110`); F6 route added.

After the review fixes: Debug build 0 errors / 0 compiler warnings; saltests 14,140 / 0; strict guard 0;
probe 42/0 (pre-110 review rows 3/8); regressions 108 namecoll 30/0 (`regress_namecoll108_110.txt`),
106 packself 70/0/4 (`regress_packself106_110.txt`); full Release build BUILD SUCCEEDED, 0 errors, no
compiler warning, 20 plug-ins, 189 language modules, runtime closure OK. Registry prefix
`1AB614304771DBE0` before and after each of the 5 GUI runs after the review (and of the 3 runs that
found the probe defect).

## Targeted re-check of the SF1 fix: ACCEPT

The reviewer drove 17 rows on the hidden desktop (the 11 new rows plus 6 own): all pass. Cancel
after Yes leaves the archive unchanged (copy and F6, sources kept); `Replaced` is per added file
(zeroed in the constructor, `MatchFiles` runs once per operation) - Yes for one file then Skip all
for another keeps the first answer, Skip then All behaves; an unopenable source at a later
question now stays marked for adding (packing retries; never worse than before); F6 deletes only
sources still marked after packing. The read-error case (Yes, then the file fails to read while
packing, then Skip - the member was already deleted) is pre-existing and not reached more often.

## CLAUDE.md entry

Proposed for "Recent Changes" (plain text):

- 110-zip-plugin-name-matching: **the ZIP plug-in replaces only the member
  that has the added file's name.** NEXT-WORK item 5 entry 2 (found by
  108), measured first (`research.md`): `CZipPack::MatchFiles`
  (`zip/add.cpp`) compared member names with `CompareStringA` +
  `NORM_IGNORECASE` on the UTF-8 bytes - a LINGUISTIC comparison of
  code-page text (not the core's byte fold): on CP1250 21,925 BMP pairs
  were one name (`probe/zip_collision_set.py`). F5 of `ĥ.txt` into an
  archive holding `Ĺ.txt` asked to overwrite and replaced it (both present:
  two questions, both deleted); an F4 edit of one member deleted the other
  (108 rows `hL1_zip`/`hL2_zip`, review `split_zip`); *Yes* then *Skip*
  lost the edited member and stored the other twice; in a Unix ZIP the
  added file took the OTHER member's spelling and was then "not found".
  - **Rule** (`src/common/salzipname.h`, header-only, contract
    `contracts/zip-member-identity.md`): two valid WTF-8 names by
    `CompareStringOrdinal` on UTF-16 (= 092's `SalNameEqualOrdinalCI`,
    brute-force parity in saltests), legacy (non-WTF-8) text by the old
    `CompareStringA` with its equal-length guard, never equal across; no
    byte-length guard for UTF-8 (7 case pairs differ in length); a prefix's
    covered bytes are counted on the member (`SalZipNamePrefix`);
    `SalZipMemberIs` keeps the old case rule (DOS folder + name ignore
    case, Unix folder respects it). The ZIP project cannot compile shared
    `.cpp` files - the header carries the core's WTF-8 decoder.
  - **Behaviour change**: `č.txt` into `{Č.txt}` (and U+2C65/U+023A ...)
    now asks to overwrite, as `a.txt`/`A.txt` always did; ASCII names of
    one character unchanged, longer ones only from "two" to "one" (Czech
    locale: `cHata.txt` = `chata.txt` now - the old linguistic comparison
    read "ch" as one letter); OEM-named members follow the UTF-8
    rule after `ProcessName`. F5 into a folder pair the core's listing
    merges adds beside instead of replacing (recorded, entry 4).
  - **Review SF1, old defect fixed**: several members one name with the
    added file (`{ax, Ax, AX}`; with 110 also `{čx, Čx, ČX}`) - *Yes* for
    one and *Skip* for another deleted the first and never stored the new
    file. `CAddInfo::Replaced` (`add_del.h`): after a *Yes*, *Skip* / *Skip
    all* / an unopenable source keep only that member. Invariant: a member
    is deleted only if the file replacing it is stored. Probe trap: with
    nothing left to add the plug-in skips the deletions too - test with a
    second file in the operation.
  - Also fixed: `CountFilesInRoot` (`del.cpp`) ignored case in a Unix ZIP -
    deleting the last file of `Dir` beside `DIR` lost the folder; it now
    uses the selection's test (`Unix ? memcmp : MemICmp`). The Unix
    spelling copy grows its buffer (the member's spelling can be longer).
  - Not changed, by decision: delete/extract selection (files by index +
    exact name - correct; folders by the listing's byte fold),
    `FindFile` (index-based).
  - Found: a BACKSPACE byte in a comment of 108's `salarcedit.h` (fixed);
    CR/NUL/TAB bytes in `tools/run_on_hidden_desktop.ps1`'s usage comment
    (recorded).
  - Probe `probe/zipname_probe.ps1` + `zipfix.py` (own ZIP writer/reader:
    UTF-8, OEM, raw-byte, Unix members; F5, F6, F8, F5 out, F4): 42/0,
    pre-110 10/21 + review rows 3/8. Regressions: 108 namecoll 30/0 (was
    28/2), 106 packself 70/0/4, 094 ZIP 56/1 (X1 as before), 096 17/17.
    Independent review ACCEPT (SF1, SF2 fixed). saltests 13,973 -> 14,140. Interface stays 107,
    no new string, no registry change. Records:
    `specs/110-zip-plugin-name-matching/fix-log.md`.
