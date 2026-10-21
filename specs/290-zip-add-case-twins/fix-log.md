# Fix log: 290 - adding into a ZIP that holds names differing only in case

From backlog item `adding-a-file-into-a-zip-that-holds-names-differing-only-in` (measure:271): adding
a file into a ZIP that holds case twins matches the members ignoring case and replaces the twin the
user did not name.

## Measured (before) - at 1e402ea2

By reading:
- `src/plugins/zip/add.cpp` `CZipPack::MatchFiles`: the pre-pass over the central directory sets
  `pathFlag = 0` / `Unix = TRUE` only for an HS_UNIX entry; the match loop calls
  `SalZipMemberIs(inZip, ..., destNameBuf, ..., RootLen, pathFlag == NORM_IGNORECASE, ...)` and, for
  a folder of a Move, `SalZipMemberIsOrIsIn(...)`. Every match is asked (DialogOverwrite) and, on
  Yes, put on the delete list; on Unix the first Yes turns the item into AF_OVERWRITE (no more
  questions) and renames the added file to the member's spelling.
- `src/common/salzipname.h` `SalZipMemberIs`: `rootIgnoreCase` covers only the first `RootLen`
  bytes (the panel's folder); the rest is compared by `SalZipNameEqual(..., TRUE)` - ALWAYS ignoring
  case, also in a Unix archive. So the item's premise "as a Unix-made ZIP already does" is wrong.
- Caller chain: Copy / Move from a disk panel into the archive panel -> core ->
  `CPluginInterfaceForArchiver::PackToArchive` (`main.cpp`) -> `CZipPack` -> `MatchFiles`
  (`add.cpp` L118). The core passes no listing data (271 contract point 4).

Probe `probe/zip290_probe.ps1` (new; 271's fixtures by .NET `ZipArchive`, host 0; UNIX rows patch
it to 3; left panel a disk folder with the one item to add, right panel the archive; Home, Down,
Copy 727, OK, Yes to every overwrite question) on the Debug build of HEAD (`.\build.cmd` -> up to
date), hidden desktop, run from `%TEMP%` before the branch existed (`-Lib` -> 098's library),
`probe/result_before.txt`: **6 FAIL, 12 PASS** (9 RUN rows + 9 END rows):
- ZIP-CONTROL: `readme.txt=NEW, z.txt`, 1 question - PASS (to keep);
- ZIP-ADDDIR: `d/x.txt=NEW, d/y.txt=Y`, 1 question - **D/x.txt lost**;
- ZIP-ADDFILE: `a.txt=NEW, z.txt`, 2 questions - **A.txt lost**;
- ZIP-ADDFOLDER (folder d with x.txt added into the root): `d/x.txt=NEW, d/y.txt` - **D/x.txt lost**;
- ZIP-NEWNAME (A.txt, a.txt, b.txt=old; add B.txt): `A.txt, B.txt=NEW, a.txt`, 1 question - b.txt
  replaced (today's behaviour; the known change of 290);
- UNIX-CONTROL: `README.txt=NEW, z.txt`, 1 question - PASS (to keep; the Unix rename);
- UNIX-ADDDIR: PASS, no question (the panel's folder is compared exactly on Unix);
- UNIX-ADDFILE: `A.txt=NEW, a.txt=lower`, 1 question naming A.txt - **the wrong twin replaced**;
- UNIX-ADDFOLDER: `D/x.txt=NEW, d/y.txt` - **the wrong twin replaced**.
Registry restored, identical (SHA-256 8079B0...0CAE).

## Decisions

- A ZIP holding twins anywhere (252's rule over every folder, as 271's listing) is matched by exact
  name for adding - the panel's folder and the rest - for both hosts (item *Expected*; spec
  Clarifications). Without twins nothing changes (Windows: ignoring case; Unix: folder exact, rest
  ignoring case + rename).
- The rule for "twins somewhere in these paths" goes into `src/common/salcasetwins.h` with saltests
  checks (the ZIP plug-in compiles header-only rules).
- Low memory while collecting the names: refuse with IDS_LOWMEM (nothing changed).

## Analyze (speckit-analyze)

No CRITICAL / HIGH. Fixed: C1 (MEDIUM - FR-004 / SC-003 had no check -> T006 confirms by reading).
Accepted: C2 (MEDIUM - Move of a folder into a twin ZIP not driven by the probe; the rule is
unit-checked, `SalZipMemberIsOrIsIn` with `nameIgnoreCase` FALSE, T004), C3 (LOW - the low-memory
refusal cannot be driven; reviewed by reading), C4 (LOW - exact duplicate members: code path
unchanged, research R4). Second run: no new findings.

## Work

- `src/common/salcasetwins.h`: `SalPathsHaveCaseTwins(paths, count, lowMemory)` - every prefix of
  every path ending at a whole part (before a separator that follows a part; the whole path unless it
  ends with a separator) is one name; 252's `HaveTwinsInPlace` over all of them. Low memory: TRUE
  and `*lowMemory` TRUE.
- `src/common/salzipname.h`: `SalZipMemberIs(..., int* rootBytes, BOOL nameIgnoreCase = TRUE)` and
  `SalZipMemberIsOrIsIn(..., BOOL rootIgnoreCase, BOOL nameIgnoreCase = TRUE)` - the part below the
  panel's folder by `nameIgnoreCase` (was always TRUE). Other callers: saltests only (grep).
- `src/plugins/zip/add.cpp` `CZipPack::MatchFiles`: after the HS_UNIX pre-pass, a second walk over
  `NewCentrDir` (in memory, bounds checked by the first pass) collects `ProcessName` of every header
  into one buffer; `SalPathsHaveCaseTwins` TRUE -> `pathFlag = 0`, `nameIgnoreCase = FALSE` for both
  matches. Low memory -> IDS_LOWMEM before the match loop (no question, nothing on the delete list).
  `Unix` unchanged. `ProcessName` also sets the directory attribute of a header whose name ends with a
  separator - the match loop calls it on every header anyway, so the central directory written is the
  same.
- Trap met (build attempt 1 of the plug-in): `deflate.h` of the ZIP plug-in `#define Len dl.len` -
  `salcasetwins.h` included after it did not compile (`SalCaseTwinName::Len`). The header is now
  included before `deflate.h`, and `add.cpp` fills the struct by aggregate initialization (the token
  `.Len` in `add.cpp` would expand too). Attempt 2: `BUILD SUCCEEDED`.

## Checks

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> `BUILD SUCCEEDED` (no `warning C` / `error C`); zip.spl rebuilt after the last
  source edit.
- `saltests.exe` -> `saltests: 25277 checks, 0 failed` (before the review; after it 25281 / 0 -
  see *Review*) (TestPathTwins290: the item's cases, a 4000-set
  randomized cross-check against `SalDirTreeHasCaseTwins` on the case-sensitive tree, the
  `nameIgnoreCase` variants of `SalZipMemberIs` / `SalZipMemberIsOrIsIn`).
- Unit negative control: the prefixes disabled in `SalPathsHaveCaseTwins` (only whole paths) ->
  `saltests: 25277 checks, 9 failed` (the item's cases, deep twins, the legacy pair and the
  cross-check `agree == rounds`); restored (git grep NEGCTL290 -> nothing), rebuilt, 0 failed.
- FR-004 / SC-003 by reading: the new walk reads `NewCentrDir`, which the add already holds; no file
  read was added (the diff of `add.cpp` holds no read call).

## Measured (after)

Probe `probe/result_after.txt`: **18 PASS, 0 FAIL, 0 NOT DRIVEN** (before 6 FAIL):
- ZIP-ADDDIR: `D/x.txt=X, d/x.txt=NEW, d/y.txt=Y`, no question;
- ZIP-ADDFILE: `A.txt=UPPER, a.txt=NEW, z.txt`, 1 question;
- ZIP-ADDFOLDER: `D/x.txt=X, d/x.txt=NEW, d/y.txt=Y`;
- ZIP-NEWNAME: `A.txt, B.txt=NEW, a.txt, b.txt=old`, no question (the known change);
- UNIX-ADDFILE: `A.txt=UPPER, a.txt=NEW, z.txt`, 1 question; UNIX-ADDFOLDER as ZIP-ADDFOLDER;
- ZIP-CONTROL / UNIX-CONTROL / UNIX-ADDDIR: as before.
- Negative control (T008): `SalPathsHaveCaseTwins` call short-circuited in `MatchFiles` ->
  `probe/result_negctl_no_twin_switch.txt` **12 PASS / 6 FAIL** - exactly the six rows of the
  before-run, with the before-run's archives; restored (git grep NEGCTL290 -> nothing), rebuilt.
- Registry restored and identical (SHA-256 8079B0...0CAE) in every run.

## Regression probes (T009)

- 271's `zip271_probe.ps1` -> `probe/regress_zip271_290.txt` **16 PASS / 0 FAIL**.
- 110's `zipname_probe.ps1`, first run -> **33 PASS / 9 FAIL**: rows `r_3ys`, `r_3ysA`, `r_3ysy`,
  `r_3yyy`, `r_3all`, `r_3yskipall`, `r_3yc`, `r_3ysAU`, `r_3ysAM` (review SF1 of 110: an added file
  equal ignoring case to several members `{cx, Cx, CX}` / `{ax, Ax, AX}`, mixed answers). These
  archives hold case twins - since 271 they are listed case-sensitively - so 290 matches the added
  file by its exact name: one question instead of three, and the other members keep their content in
  every row (for example `r_3yyy`, Yes / Yes / Yes: before, `Cx` and `CX` were deleted; now kept).
  Every result is the intended behaviour of the item; no member the user did not name is deleted. 110
  did not decide that every case variant is asked (its SF1 fixed the delete-before-store order under
  the old matching; that invariant code is unchanged). The nine rows' `Q` / `Expect` were
  re-baselined in `specs/110-zip-plugin-name-matching/probe/zipname_probe.ps1` with a comment naming
  290; re-run -> `probe/regress_zipname110_290.txt` **42 PASS / 0 FAIL / 0 NOT DRIVEN**.
  Consequence recorded: the mixed-answer path of 110's `CAddInfo::Replaced` is now reached only by
  byte-identical duplicate members (or legacy text equal by `CompareStringA` but not by the fold).
- 108's `namecoll_probe.ps1` (F4 edits packed back into archives holding colliding names, among them
  h-circumflex / L-acute, a pair of the legacy fold - a twin archive for 290) ->
  `probe/regress_namecoll108_290.txt` **30 PASS / 0 FAIL / 0 NOT DRIVEN**, F4 retries 0 (as after 110).
- Registry restored and identical in every regression run.

## Review

Review 1 (independent agent, refute-first, build of b7617570): **no MUST**. It re-ran the probe
(18 / 0, registry identical) and saltests (25277 / 0), enumerated the callers itself
(`SalZipMemberIs` / `SalZipMemberIsOrIsIn`: `add.cpp` and saltests only; `pathFlag` only in the two
calls; delete / extract `CZipCommon::MatchFiles` untouched) and drove its own rows under %TEMP% (copy
of 110's probe, not in the repository): Move of a folder into a twin ZIP (Windows, Unix, with folder
entries) - nothing replaced, the source removed (analyze C2 now driven); Move onto the exact member,
Yes - only that member replaced; Move + Skip - archive unchanged, the source stays; byte-identical
duplicates with Yes / Skip and Yes / Cancel - 110's "delete only once stored" holds; a legacy-fold
pair (h-circumflex / L-acute) with README.txt - readme.txt added beside, no question. By reading:
exact matching only shrinks the set of matches; the low-memory branch returns before any question;
no path cut, no code-page conversion.
- SHOULD 1 - `SalPathsHaveCaseTwins` compared whole prefixes: a folder name that is not valid WTF-8
  made `SalNameOrderCompareCI` fall back to the legacy fold for the whole path, and ordinal-only twins
  below it (C-caron / c-caron, apart in the cp1250 fold) were missed - `"\xFF\\Č.txt"` /
  `"\xFF\\č.txt"` gave 0 while `SalDirTreeHasCaseTwins` on the same tree gave 1 (its `cl` program).
  The randomized cross-check used ASCII parts only. **Fixed**: the rule now compares every part with
  the other parts of its folder (folder = the path's bytes up to the end of the previous part,
  compared byte for byte; parts by the two rules), exactly what the tree rule does; empty parts of
  doubled separators are skipped (`{"D\\\\x", "D\\X"}` is now twins, as the tree says). saltests: the
  reviewer's case, a two-folder control, the tree's own answer, and a second randomized set (`\xFF`,
  `\xFE`, C-caron, c-caron, `b`; 8000 rounds in all). Negative control (whole prefixes restored,
  NEGCTL290) -> `saltests: 25281 checks, 3 failed` (the reviewer's case, the doubled-separator case,
  `agree == rounds`); restored, rebuilt -> `saltests: 25281 checks, 0 failed`.
- SHOULD 2 - the re-baselined `r_3*` rows of 110 no longer drive 110's SF1 path (mixed answers for
  several matches). **Fixed**: the reviewer's rows `v_dupys` (Yes / Skip) and `v_dupyc` (Yes /
  Cancel) on byte-identical duplicate members added to 110's `zipname_probe.ps1` -> re-run
  `probe/regress_zipname110_290.txt` **44 PASS / 0 FAIL / 0 NOT DRIVEN**.
- NOTE 3 - cost: a second walk over the central directory and two sorts of every path part on each
  add into an existing ZIP; the reviewer measured (/O2) about 1.0 s for 200,000 ASCII members five
  folders deep, 3.2 s for non-ASCII. Accepted and recorded as a limit (the 271 listing pays the same
  kind of check on every listing; the add itself rewrites the archive).
- NOTE 4 - a legacy-fold pair (h-circumflex / L-acute: two names to Windows) makes the whole archive
  exact for adding, so readme.txt is added beside README.txt there. Consistent with 271's listing,
  nothing lost; recorded as a limit.
- NOTE 5 - a typed target folder in another case in a twin ZIP now gets a new folder beside it: the
  existing backlog item "Copying into an archive folder typed in another case packs into a new folder
  beside it" covers it; nothing new.
- NOTE 6 - the probe asserted the question count only in ADDFILE. **Fixed**: every twin row asserts
  it (ADDFILE 1, the others 0).

After the fixes, on the final build: `.\build.cmd` BUILD SUCCEEDED; saltests 25281 / 0; encoding
guard 0; `probe/result_after.txt` (label after-review) **18 PASS / 0 FAIL / 0 NOT DRIVEN**; 110's
44 / 0; 271's `probe/regress_zip271_290.txt` 16 / 0; registry identical every time. 108's probe was
not repeated after the review fix: the rule changed only for names that are not valid WTF-8, and 108's
fixtures use valid UTF-8 names (its run on the previous build: 30 / 0).

No MUST -> no second review (SKILL step 7).
