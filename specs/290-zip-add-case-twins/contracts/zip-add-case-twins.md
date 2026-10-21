# Contract: matching items added into a ZIP (feature 290)

Internal to the ZIP plug-in and the header-only rules; no plug-in interface change.

1. `SalPathsHaveCaseTwins(const SalCaseTwinName* paths, int count, BOOL* lowMemory)`
   (`src/common/salcasetwins.h`): TRUE when two byte-different path prefixes (ending at a whole part,
   separators `\` and `/`) are equal by `SalNameOrderCompareCI` or by the legacy byte fold - exactly
   when some folder of the tree the paths make holds case twins (files and folders of one folder
   together, as `SalDirTreeHasCaseTwins`). `count < 2` or `paths == NULL`: FALSE. Low memory: TRUE and
   `*lowMemory` (may be NULL) = TRUE; otherwise `*lowMemory` = FALSE.
2. `SalZipMemberIs(..., BOOL rootIgnoreCase, int* rootBytes, BOOL nameIgnoreCase = TRUE)` and
   `SalZipMemberIsOrIsIn(..., BOOL rootIgnoreCase, BOOL nameIgnoreCase = TRUE)`
   (`src/common/salzipname.h`): `nameIgnoreCase` decides the comparison of the part below the
   panel's folder; TRUE is the behaviour before 290.
3. `CZipPack::MatchFiles` (`src/plugins/zip/add.cpp`): the pre-pass collects every member name;
   twins -> `pathFlag = 0` and `nameIgnoreCase = FALSE` for both matches; no twins -> as before
   (Windows: both ignoring case; Unix: folder exact, rest ignoring case). The `Unix` flag is set only
   by an HS_UNIX entry, as before. A failed collection or check returns IDS_LOWMEM before the first
   question.
4. Unchanged: the overwrite question, the delete-after-store order of 110 / 113, the listing (271).
