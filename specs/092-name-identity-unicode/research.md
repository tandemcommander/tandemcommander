# Research: encoding cluster B-2 — code-page byte tables behind name comparison

Read-only research at HEAD of `088-plugin-interface-107` (82717958). Nothing in the
repository was modified. All `file:line` references are relative to `src/` unless
they start with `specs/` or `tools/`. Measurements marked **(measured)** were run in
this session (the guard script, and a Python/ctypes probe of `CompareStringEx` /
`CompareStringOrdinal` on this machine, Windows 11 26200, cs-CZ, ACP 1250).

## 0. Headline findings (read these first)

1. **The guard's 33 hits are not the work list.** `REMAINING-WORK.md:45` says
   *"33 report-only hits — that is the work list"*. Measured: 33 hits, of which
   **29 index the table with a drive letter** (ASCII by construction, harmless),
   3 are in the ASCII-only fast-path matchers of `masks.cpp` (reached only when
   both strings are ASCII or are not valid UTF-8 — by design since feature 004)
   and 1 is a self-consistent hash bucket (`pack3.cpp:405`). **None of the 33
   is a user-visible defect on its own.** The 068 P7 notes already said so
   (`specs/068-encoding-regression-review/findings/P7.md:215-235`: "29 of the 33 …
   false positives", proposed `DRIVE_SHAPE` narrowing to 4) but the narrowing was
   never implemented in `tools/check_encoding.py` and the 069 handoff lost the
   caveat.
2. **The real work list is the callers of the primitives**, which the regex
   cannot see: `StrICmp` / `StrNICmp` / `StrICmpEx` / `StrICpy` / `StrIStr` /
   `MemICmp` (227 lines in the core) plus `IsTheSamePath`, `HasTheSameRootPath`,
   `CommonPrefixLength`/`SalPathIsPrefix` (≈70 more call lines). About 125 of the
   227 take names or paths.
3. **"Sort order of non-ASCII names is by bytes" is no longer true.** Since
   feature 004 the panel sort goes through `SalSortCompareStr` (`sort.cpp:17-30`):
   ASCII pairs keep the legacy comparators, anything else uses
   `SalCompareNamesUTF8` = NFC + `CompareStringEx(LOCALE_NAME_USER_DEFAULT,
   LINGUISTIC_IGNORECASE)` (`common/salunicode.cpp:687-713`). Ordering is not
   the B-2 problem. **Equality is.**
4. **Two new defects found on the way** (not in 068/069 records):
   - `SalSortCompareStr` is **not a strict weak ordering when "Use locale for
     sorting" is off** (`Configuration.SortUsesLocale`, default TRUE,
     `dialogs4.cpp:292`). Measured cycle: `"a-c" < "ab"` (byte path, both ASCII),
     `"ab" < "abé"` (linguistic), `"abé" < "a-c"` (linguistic, hyphen has
     minimal weight). Quicksort result then depends on input order and the
     refresh merge (`fileswn0.cpp:2916-3011`) can mispair items.
   - `SalNameEqualCI` (the existing "correct helper" 068 recommends routing
     everything through) is **linguistic equality, not file-system equality**.
     Measured `CompareStringEx(..., LINGUISTIC_IGNORECASE)` == equal for:
     `ab` / `a<U+00AD>b` (soft hyphen), `ab` / `a<U+200D>b`, `strasse` /
     `straße`, `Ａ` (U+FF21) / `A`, `σ` / `ς`, `K` (U+212A) / `k`, and
     `a<U+0378>` / `a<U+0379>` (unassigned code points weigh nothing).
     `CompareStringOrdinal(..., TRUE)` says "different" for every one of these,
     as NTFS does. So `SalNameEqualCI` is right for *search* (quick search,
     Find) and **wrong for identity** (focus, same-path, overwrite, cache key).
     It is already used for identity-like decisions in Compare Directories
     (`mainwnd5.cpp:879,954,1300,1514` via `CmpNameExtIgnCase`).
5. The plug-in ABI freezes the *exported* functions (`spl_gen.h:1100-1265`,
   `:1438`, `:1457`); it does **not** freeze the core's internal call sites.
   The safe route is therefore "new helper + convert core call sites", never
   "change `StrICmp`".

---

## 1. The guard rule and its complete hit list

### 1.1 How to run

```
python tools/check_encoding.py --draft --rule acp-byte-table-on-name --format list
```

`--draft` runs the report-only rules (`tools/check_encoding.py:550-558`); a draft
rule passed via `--rule` implies `--draft` (`:554-555`). Exit code is always 0 in
draft mode (`:592`). The rule is `BYTE_TABLE.search(ln) and UTF8_IDENT.search(ln)`
(`:521-524`), with
`BYTE_TABLE = \b(?:IsNotAlphaNorNum|IsAlpha|LowerCase|UpperCase)\s*\[` (`:278`).
It sees only **direct table indexing on a line that also mentions a
name-ish identifier**; it does not see the table definitions, the `str.cpp`
helpers, or any call of `StrICmp` & co. (stated in
`specs/068-…/findings/P7.md:237-240`).

### 1.2 The 33 hits (measured at HEAD), classified

| # | file:line | enclosing function | code (trimmed) | class | verdict |
|---|---|---|---|---|---|
| 1 | drivelst.cpp:833 | CheckAndRestoreNetworkConnection | `GetLogicalDrives() & (1 << (LowerCase[drive] - 'a'))` | drive letter → index | benign (ASCII) |
| 2 | drivelst.cpp:838 | same | `netRemotePath[LowerCase[drive] - 'a']` | drive letter → index | benign |
| 3 | drivelst.cpp:851 | same | `RestoreNetworkConnection(…, netRemotePath[LowerCase[drive] - 'a'])` | drive letter → index | benign |
| 4 | drivelst.cpp:2830 | CDrivesList::OnContextMenu | `LowerCase[path[0]] >= 'a' && … <= 'z' && path[1] == ':'` | drive-letter range test | benign¹ |
| 5 | drivelst.cpp:3247 | CDrivesList::FindPanelPathIndex | `LowerCase[path[0]] == LowerCase[item->DriveText[0]]` | drive letter equality | benign |
| 6 | fileswn1.cpp:259 | CFilesWindowAncestor::SetPath | `int drv = UpperCase[Path[0]] - 'A' + 1;` | drive letter → index | benign |
| 7 | fileswn2.cpp:1926 | CFilesWindow::ChangePathToDisk | `LowerCase[root[0]] != LowerCase[changedPath[0]]` | drive letter equality | benign |
| 8 | fileswn3.cpp:161 | CFilesWindow::ReadDirectory | `int drv = UpperCase[fileName[0]] - 'A' + 1;` | drive letter → index | benign |
| 9 | fileswn3.cpp:2244 | CFilesWindow::ChangeDir | `path[0] = UpperCase[path[0]]; // "c:" → "C:"` | case conversion of drive letter | benign |
| 10 | fileswn3.cpp:2757 | CFilesWindow::ChangeDrive | `DefaultDir[LowerCase[drive] - 'a']` | drive letter → index | benign |
| 11 | fileswn6.cpp:236 | GetPathFlagsForCopyOp | `UpperCase[path[0]] >= 'A' && … <= 'Z' && path[1] == ':'` | drive-letter range test | benign¹ |
| 12 | fileswn6.cpp:237 | same | `GetDriveFormFactor(UpperCase[path[0]] - 'A' + 1)` | drive letter → index | benign |
| 13 | fileswn6.cpp:1244 | CFilesWindow::BuildScriptMain | `LowerCase[*targetPath] >= 'a' && … <= 'z'` | drive-letter range test | benign¹ |
| 14 | fileswn7.cpp:518 | CFilesWindow::UnpackZIPArchive | `len == 2 && LowerCase[path[0]] >= 'a' && … <= 'z'` | drive-letter range test | benign¹ |
| 15 | fileswn8.cpp:543 | CFilesWindow::FilesAction | same shape | drive-letter range test | benign¹ |
| 16 | fileswna.cpp:169 | CFilesWindow::PluginFSFilesAction | same shape (`targetPath[0]`) | drive-letter range test | benign¹ |
| 17 | find.cpp:465 | CFindIgnore::Prepare | `LowerCase[path[0]] >= 'a' && … <= 'z' && path[1] == ':'` | drive-letter range test | benign¹ |
| 18 | mainwnd1.cpp:539 | CMainWindow::UpdateDefaultDir | `DefaultDir[LowerCase[pathActive[0]] - 'a']` | drive letter → index | benign² |
| 19 | mainwnd1.cpp:548 | same | `DefaultDir[LowerCase[pathPasive[0]] - 'a']` | drive letter → index | benign² |
| 20 | mainwnd2.cpp:2768 | CMainWindow::LoadConfig | `LowerCase[path[0]] == d2` | drive letter equality | benign |
| 21 | mainwnd2.cpp:3822 | CMainWindow::LoadConfig | `DefaultDir[LowerCase[leftPanelPath[0]] - 'a']` | drive letter → index | benign² |
| 22 | mainwnd4.cpp:1064 | CMainWindow::SetDefaultDirectories | `d == LowerCase[curPath[0]]` | drive letter equality | benign |
| 23 | masks.cpp:49 | AgreeMaskA | `LowerCase[*filename] == LowerCase[*mask] \|\| *mask == '?' \|\| ('#' digit)` | **mask matching** (hot) | by design — ASCII fast path / invalid-UTF-8 fallback only (`masks.cpp:126-150`) |
| 24 | masks.cpp:52 | AgreeMaskA | `LowerCase[*filename] == LowerCase[*mask] \|\| *mask == '?'` | **mask matching** (hot) | same |
| 25 | masks.cpp:327 | AgreeQSMaskAux | `if (LowerCase[*filename] == LowerCase[*mask])` | **quick search** | by design in the core (`fileswn0.cpp:106-112` routes non-ASCII to `AgreeQSMaskU8Aux`); `AgreeQSMask` has no other core caller |
| 26 | pack3.cpp:405 | CPackerFormatConfig::PackIsArchive | `&Extensions[LowerCase[archiveName[idx]]]` | **extension lookup / hash bucket** (hot: "heavily called from CommonRefresh", `:397`) | self-consistent with the build side `pack3.cpp:328,333`; wrong only for a non-ASCII archive extension in upper case |
| 27 | salamdr2.cpp:1268 | ResolveSubsts | `GetSubstInformation(LowerCase[resPath[0]] - 'a', …)` | drive letter → index | benign² |
| 28 | salamdr5.cpp:555 | SalCheckAndRestorePath | drive-letter range test | drive-letter range test | benign¹ |
| 29 | salamdr5.cpp:630 | SalCheckAndRestorePathWithCut | drive-letter range test | drive-letter range test | benign¹ |
| 30 | salamdr5.cpp:705 | SalParsePath | `len == 2 && LowerCase[path[0]] >= 'a' …` | drive-letter range test | benign¹ |
| 31 | salamdr5.cpp:1522 | IsNetworkProviderDrive | `LowerCase[path[0]] == LowerCase[netSource->lpLocalName[0]]` | drive letter equality | benign |
| 32 | salamdr6.cpp:1820 | GetIfPathIsInaccessibleGoTo | `path[0] = UpperCase[path[0]];` | case conversion of drive letter | benign |
| 33 | toolbar6.cpp:188 | CDriveBar::Execute | `DefaultDir[LowerCase[drive] - 'a']` | drive letter → index | benign |

¹ Range tests `LowerCase[b] >= 'a' && <= 'z'`: on ACP 1250/1251/1252 no byte ≥ 0x80
folds into ASCII, so a UTF-8 lead byte cannot pass. On **Turkish ACP 1254**
`CharLowerA(0xDD)` == `'i'` (noted in `specs/068-…/findings/verdicts-V2.md:231-235`)
and 0xDD is a valid UTF-8 lead byte, so a relative path beginning with a
U+0740–U+077F character followed by `:` would be taken for a drive path. Remote;
a plain ASCII `IsDriveLetter()` inline would close it and silence 29 hits.

² Index sites not preceded by a range test on the same line; they rely on the
caller having established a drive path. Same Turkish-ACP remark.

**Consequence for the guard**: implement the P7 narrowing (or better: replace the
29 sites by an ASCII-only inline such as `SalDriveIndex(char c)` /
`SalIsDriveLetter(char c)` and annotate the 4 survivors), then the rule can be
promoted to strict with `TOTAL: 0`. That is a mechanical, zero-behaviour-change
first commit (section 6, stage S0).

### 1.3 Direct table-indexing sites the rule does *not* flag (no name identifier on the line)

Core, full `grep` (117 lines); the name-bearing ones:

| file:line | function | what | class |
|---|---|---|---|
| salamdr1.cpp:1196,1208,1220 | HasTheSameRootPath | UNC server/share compare | path comparison (**exported**, `spl_gen.h:1438`) |
| salamdr1.cpp:1434 | IsTheSamePath | whole-path compare | path comparison (**exported**, `spl_gen.h:1457`) |
| salamdr1.cpp:1455 | CommonPrefixLength (→ `SalPathIsPrefix` `:1502`) | prefix compare | path comparison |
| fileswn3.cpp:643,1194,1276,1455,1554 | CFilesWindow::ReadDirectory | lower-cases the extension into a scratch buffer for the association/icon lookup | extension lookup (hot: per file) |
| fileswn4.cpp:177 | CFilesWindow::DrawIcon | same | extension lookup |
| salamdr4.cpp:1445 | InternalGetType | same, then `Associations.GetIndex` | extension lookup (hot: per visible row) |
| fileswn2.cpp:3931 | CFilesWindow::RefreshListBox | same | extension lookup |
| salamdr6.cpp:1604-1608 | IsFileLink | lower-cases ≤3 ext bytes, compares to "lnk"/"pif"/"url" | extension lookup (ASCII target → safe) |
| icncache.cpp:1220,1264,1308 | CAssociations::ReadAssociations | lower-cases registry extension keys | extension lookup (build side of the pair above) |
| fileswn2.cpp:3556 | GetCommonFileTypeStr | upper-cases the extension for the "XYZ File" type text | **case conversion for display** (mangles a non-ASCII ext) |
| fileswnb.cpp:723 | CFilesWindow::WindowProc | lower-case copy | case conversion |
| masks.cpp:491-496 | COMPUTEMASKGROUPHASH | hash of first 3 ext bytes | **hash** (pair: `masks.cpp:780,795,815` `StrICmp`) |
| pack3.cpp:328,333,413,431 | BuildArray / PackIsArchive | reversed lower-case ext, bucket by last byte | hash + extension lookup |
| plugins1.cpp:781,792 | StrICmpIgnoreSpacesOnStartAndEnd | viewer/packer mask-list compare | equality on mask text |
| salamdr2.cpp:1966-2079 | AlterFileName | case conversion of names (cluster **B-4**, not B-2) | case conversion for display **and for rename** |
| zip.cpp:894,905 | CSalamanderGeneral::ToLowerCase/ToUpperCase | in-place fold of caller's buffer | **exported** (`spl_gen.h:1105-1106`) |
| codetbl.cpp:784 | CodingNameEqual | conversion-table names (code-page bytes by contract, 069) | not a name |
| codetbl.cpp:1013-1081, find.cpp:1271-1320 | code-page detection / whole-word grep | file *content* bytes | not a name (refuted in `verdicts-V2.md:237-252`) |
| menu2.cpp:141-1588, menubar.cpp:701, finddlg1.cpp:2919, plugins2.cpp:3601, dialogs5.cpp:3252 | menu / dialog hot keys | UI text accelerator | not a name (belongs to cluster B-1) |
| viewer.cpp:82,315,323; mainwnd2.cpp:3035; finddlg2.cpp:1017; salamdr4.cpp:2023; salamdr3.cpp:498-504 | hex digits, switch letters, URL scheme, drive letters | ASCII | benign |

---

## 2. Where the tables and primitives live, who uses them

### 2.1 Definitions

| item | definition | notes |
|---|---|---|
| `BYTE LowerCase[256]`, `UpperCase[256]` | `common/str.cpp:63-64`, extern `common/str.h:22-23` | filled by `InitializeCase()` `common/str.cpp:110-117` from `CharLowerA`/`CharUpperA`, one **ACP byte** in, one out; run from a static initializer (`:71`) |
| `StrICpy` | `common/str.cpp:122` | folds while copying |
| `StrICmp` | `common/str.cpp:138` (x64 C++), `:153` (x86 asm) | `LowerCase[*s1] - LowerCase[*s2]` |
| `StrNICmp` | `common/str.cpp:224` / `:240` | |
| `MemICmp` | `common/str.cpp:310` / `:320` | |
| `StrICmpEx` | `common/str.cpp:383` / `:416` | length-delimited |
| `StrCmpEx` | `common/str.cpp:488` / `:502` | case-sensitive, byte order (correct for UTF-8: byte order == code-point order) |
| `StrIStr` (2 overloads) | `common/str.cpp:522`, `:540` | |
| `IsNotAlphaNorNum[256]`, `IsAlpha[256]` | `salamdr1.cpp:380-381`, filled `:971-972` (`IsCharAlphaNumeric`/`IsCharAlpha`, ANSI) | consumers are content/heuristics, not names |
| `HasTheSameRootPath` | `salamdr1.cpp:1194` | |
| `HasTheSameRootPathAndVolume` | `salamdr1.cpp:1239` | |
| `IsTheSamePath` | `salamdr1.cpp:1428` | |
| `CommonPrefixLength` / `SalPathIsPrefix` | `salamdr1.cpp:1448` / `:1502` | |
| `StrCmpLogicalEx`, `RegSetStrICmp[Ex]`, `RegSetStrCmp[Ex]` | `sort.cpp:33`, `:181-235` | already Unicode-aware through `SalSortCompareStr` `sort.cpp:17` |
| `CSalamanderDirectory::SalDirStrCmp[Ex]` | `zip.cpp:5670`, `:5678` | `StrICmp[Ex]` unless `SALDIRFLAG_CASESENSITIVE` |
| plugin-side second copy | `plugins/shared/lukas/str.cpp:6` (`char LowerCase[256]`) | independent table in plug-ins that use the "lukas" library |

`/J` (unsigned `char`) is set product-wide (`vcxproj/sal_base.props:14`,
`plugins/shared/vcxproj/plugin_base.props:16`) and asserted at start-up
(`salamdr1.cpp:3848`), so table indexing is never negative.

**Who compiles `common/str.cpp`**: only `vcxproj/salamand.vcxproj`,
`vcxproj/translator/translator.vcxproj`, `plugins/filecomp/vcxproj/filecomp.vcxproj`
and `plugins/renamer/vcxproj/renamer.vcxproj`. **`saltests` does not**
(its sources: `salclip, salfileio, salpath, salshell, saltabs, salbugreport,
salcloseapp, sal7zlist, salarcmig, salurlpwd, salunicode`). Editing `str.cpp`
therefore also changes two plug-ins and the translator, and is untestable by
`saltests` — a strong reason to put the new helpers in `common/salunicode.*`.

### 2.2 Call-site counts (measured, `grep` over `src/*.cpp src/*.h`, comments included)

| primitive | core (`src/*.{cpp,h}`) | `src/common` | plug-ins (direct + via interface) |
|---|---|---|---|
| `StrICmp` | 167 | 9 | 96 |
| `StrNICmp` | 43 | 9 | 55 |
| `StrICmpEx` | 9 | 5 | 8 |
| `StrCmpEx` | 9 | 4 | 2 |
| `MemICmp` | 2 (both in a commented-out timing block, `mainwnd3.cpp:93-97`) | 6 | 3 |
| `StrICpy` | 10 | 4 | 3 |
| `StrIStr` | 6 | 4 | 3 |
| `LowerCase[` | 83 | 16 | 44 |
| `UpperCase[` | 25 | 3 | 10 |
| `IsAlpha[` / `IsNotAlphaNorNum[` | 8 / 11 | 0 | 6 / 0 |
| `IsTheSamePath` | 26 | – | 9 |
| `HasTheSameRootPath` (incl. `…AndVolume`) | 36 | – | 8 |
| `SalPathIsPrefix` / `CommonPrefixLength` | 6 / 6 | – | 0 / 1 |
| `RegSetStrICmp[Ex]` / `RegSetStrCmp[Ex]` | 25+12 / 12+9 (incl. definitions/decls) | – | 7+3 / 7+3 |
| `_stricmp` / `stricmp` / `_strnicmp` / `lstrcmpi` | 31 / 78 / 5 / 1 | 0/0/2/1 | 57/0/28/64 |

(`stricmp`/`_stricmp` are CRT "C"-locale ASCII-only folds — different semantics
again, but harmless on UTF-8: no byte ≥ 0x80 is touched. They are the *safest*
existing behaviour and need no work; not classified further.)

### 2.3 Names versus other text (hand classification of the 227 `Str*`/`MemICmp`/`StrIStr` lines)

Full listing kept in the scratchpad as `stri_sites.txt`. Buckets:

**A. Not names — ASCII keywords, identifiers, class names (≈97 lines; no change needed, must keep working):**
window class names (`dialogs4.cpp:2087,2089`, `editwnd.cpp:286,290`,
`finddlg1.cpp:929,2377`, `salamdr3.cpp:2949,3722,3727,4031,4035`); command-line
switches (`salamdr1.cpp:3652-3775`, 10); file-system type names
(`fileswn6.cpp:586,1231`, `mainwnd5.cpp:1245,1255`, `salamdr6.cpp:406-408,1629`);
`convert.cfg` keywords and code-page names (`codetbl.cpp:77-198,950,1147,1165,1171`);
plug-in FS names / registry key names / DLL suffixes
(`plugins2.cpp:436,460,465,1952,2226,2338,2382,2407,2428,2816,3451`,
`fileswn2.cpp:2572`, `salamdr3.cpp:1713,1718`); extension lists typed in
configuration (`plugins1.cpp:727,925,929,948,1094`, `plugins2.cpp:2576,2622`,
`pack3.cpp:514`, `packers.cpp:987,1576`, `salamdr2.cpp:2728,2827`); variable
names (`salamdr2.cpp:807,865`, `packers.cpp:696,779`, `salamdr7.cpp:132,134,168,261`);
constants (`fileswn2.cpp:138` and `shellsup.cpp:525` "lnk", `fileswn3.cpp:592`
"system32", `cache.cpp:1513` ".tmp", `fileswn6.cpp:1530-1531` stream names,
`fileswn6.cpp:1925,2816` `\\tsclient\`, `salamdr4.cpp:2003` "file",
`shellib.cpp:2626` CLSID, `shiconov.cpp:316`, `dialogs2.cpp:670-703`,
`editwnd.cpp:314` "cd "); language module names (`dialogs2.cpp:863`,
`mainwnd2.cpp:1732`, `mainwnd3.cpp:7131`); `bugreprt.cpp:192`;
`drivelst.cpp:1579`; `salamdr5.cpp:1339` (policy list).
Comparing a name against an **ASCII constant** is exact under any table on
ACP 125x (no high byte folds to ASCII) — these are safe as they are.

**B. Names / paths (≈125 lines), by what they decide:**

| class | sites | effect of the defect |
|---|---|---|
| **Focus-by-name after refresh / operation** | `fileswn1.cpp:2465,2480` (CommonRefresh), `fileswn0.cpp:3119,3150,3165` (RefreshDirectory), `fileswn2.cpp:2739,3098,3113`, `fileswnb.cpp:930`, `fileswn1.cpp:1954` | case-only rename of an accented name loses the cursor; look-alike pair focuses the wrong item (`verdicts-V2.md:254-262`) |
| **"Is it only a change of case?" in rename / move** | `fileswn5.cpp:2191,2256` (RenameFileInternal), `worker.cpp:5817,5906` (DoMoveFile), `fileswn6.cpp:1772,1775,2648` (BuildScriptDir/File), `fileswn5.cpp:2153`, `fileswn6.cpp:689` | **the operational one**: renaming `Č.txt` → `č.txt` gives `StrICmp != 0`, so when `MoveFile` reports `ERROR_ALREADY_EXISTS` (it does on some file systems / via the copy path) the code enters the DOS-name-collision and *overwrite* branches for what is the same file. On NTFS a direct `MoveFile` case-only rename succeeds, which is why this is rarely seen; network/FAT/exFAT redirectors are the exposure. **Not verified by execution.** |
| **DOS-name-collision test** (`tgt == dosName && tgt != longName`) | `fileswn5.cpp:2204-2205`, `worker.cpp:3002-3003,5832-5833,6424-6425`, `safefile.cpp:154-155`, `cache.cpp:399,406`, `worker.cpp:4526`, `fileswn6.cpp:2696`, `pack2.cpp:501` | first guard can only fire for ASCII (8.3 names are ASCII), refuted as operational in `verdicts-V2.md:217-235`; the second half (`tgt != longName`) gives a false "different" for a case-different accented name, harmlessly |
| **Correct the case of the target to what is on disk** | `worker.cpp:3215` (CorrectCaseOfTgtName) | not applied for accented names → target keeps the typed case |
| **Path identity** | `IsTheSamePath` 26 core lines (e.g. `fileswn2.cpp` auto-refresh matching, `fileswn3.cpp` junction tests, `fileswn6.cpp:698`), `CFilesWindowAncestor::SamePath` `fileswn1.cpp:373`, `fileswn7.cpp:2043,2044,2051` (AcceptChangeOnPathNotification), `fileswnb.cpp:657,1194`, `salamdr3.cpp:1696,1703` (CPathHistoryItem::IsTheSamePath), `salamdr3.cpp:3502,3534` (CTopIndexMem), `salamdr5.cpp:767,1143`, `fileswn3.cpp:1811,1868,1911,1939`, `fileswn1.cpp:2332,2359,2377`, `dialogs3.cpp:1962,2101,2206`, `shellib.cpp:656,1581-1583,1862,1970`, `cache.cpp:365,662,667`, `dialogs5.cpp:784`, `plugins2.cpp:1386,2649,3001,3436`, `packac.cpp:1449`, `dialogs6.cpp:1134`, `drivelst.cpp:1988` | two *identical* paths always compare equal (bytes identical), so the common case works; defect = (a) false **equality** for the nine CP1250 collision pairs (`…\ĥ` vs `…\Ĺ`, `Č` vs `Ĝ`; `verdicts-V2.md:179-186`), (b) false inequality when the two spellings differ in the case of an accented letter (user-typed path vs enumerated path) → duplicate history entries, missed refresh, "different archive" |
| **Archive identity** | `fileswn2.cpp:1303,2127,2234`, `fileswn9.cpp:1240`, `salshlib.cpp:546,627`, `salamdr3.cpp:1703` | as above |
| **Disk-cache key construction** | `StrICpy(…, GetZIPArchive())` `fileswn2.cpp:1305`, `fileswn5.cpp:787`, `fileswn6.cpp:3190`, `fileswn9.cpp:1225`; `cache.h:88-89` `NameEqual`/`TmpNameEqual` | key is folded by the ACP table: `Č.zip` and `Ĝ.zip` in one directory get the **same cache key** (false equality → wrong cached file could be served; rare); see trap T3 |
| **Duplicate-name detection in a listing** | `fileswn6.cpp:3181` (ExecuteFromArchive), `shellsup.cpp:1882,1897`, `mainwnd3.cpp:2705`, `finddlg1.cpp:990,1006`, `fileswnb.cpp:1201,1207`, `salamdr3.cpp:3118-3119,3433` (CFileTimeStamps) | false positive/negative for accented names |
| **Ordering for sort + binary search (internal arrays)** | `salamdr6.cpp:616,618` (SortNames) ↔ `:736` (FindNameInArray, used by `CNames`) ↔ `:1081` (CDirectorySizes::GetIndex); `fileswn6.cpp:455` (ContainsString); `shares.cpp:187` ↔ `dialogs6.cpp:460-472`; `drivelst.cpp:1476,1492` | internally consistent today (same comparator both sides); equality defect only |
| **Archive / plug-in FS tree lookup** | `zip.cpp:5675,5683` (SalDirStrCmp[Ex]) used at `zip.cpp:5789,6191,6350,6386,6422,6489,6538,6588` | `Č\` and `č\` become two directories in a case-insensitive archive tree; `ĥ\` and `Ĺ\` merge |
| **Mask / extension equality** | `masks.cpp:780,795,815` (optimized `*.ext` masks) | `*.čxt` does not match `X.ČXT` on this path while the general `AgreeMask` path does — inconsistent |
| **Find ignore list / search** | `find.cpp:532,540,550,628` | path prefix compare |
| **Find-results list type-ahead (ANSI variant)** | `finddlg1.cpp:4262-4292` | documented as the ANSI fallback of the `SalNameEqualCI` path (`finddlg1.cpp:4239`) |
| **History de-duplication** | `salamdr6.cpp:360` (AddValueToStdHistoryValues) | duplicates differing in accented-letter case |
| **Shares list** | `shares.cpp:235,270`, `fileswn6.cpp:455` | |

### 2.4 Exported to plug-ins (frozen ABI — behaviour must not change for ANSI callers)

`CSalamanderGeneralAbstract`, `plugins/shared/spl_gen.h`:

| line | method | core forwarder |
|---|---|---|
| 1053 | `AgreeMask` | `masks.cpp:126` (already UTF-8-aware with ASCII fast path) |
| 704 | `CSalamanderMaskGroup::AgreeMasks` | `masks.cpp` |
| 1100 | `GetLowerAndUpperCase` — **hands out the raw table pointers** | `zip.cpp:878` |
| 1105 / 1106 | `ToLowerCase` / `ToUpperCase` | `zip.cpp:888` / `:899` |
| 1128 | `StrCmpEx` | `zip.cpp:910` |
| 1146 | `StrICpy` | `plugins.h:1952` |
| 1165 | `StrICmp` | `zip.cpp:920` |
| 1189 | `StrICmpEx` | `zip.cpp:925` |
| 1211 | `StrNICmp` | `plugins.h:1955` |
| 1232 | `MemICmp` | `plugins.h:1956` |
| 1239 / 1248 / 1256 / 1265 | `RegSetStrICmp` / `…Ex` / `RegSetStrCmp` / `…Ex` | `zip.cpp:940-957` (already Unicode-aware via `sort.cpp`) |
| 1438 | `HasTheSameRootPath` | `salamdr1.cpp:1194` |
| 1457 | `IsTheSamePath` (also the default of `SGP_IsTheSamePathF`, `:491`, `:2038-2045`) | `salamdr1.cpp:1428` |
| 2076 | `AlterFileName` | `salamdr2.cpp` (cluster B-4) |
| 2119-2172, `spl_fs.h:43` | disk-cache contract: *"the plug-in must lower-case names itself, see ToLowerCase"* | documented key discipline |

The header comments document the mechanism verbatim (*"to lower case using
LowerCase array (filled using CharLower Win32 API call)"*, `spl_gen.h:1135,1154,
1173,1197,1219`), i.e. the ACP fold **is the published contract**.

Plug-in consumers through the interface (measured, `SalamanderGeneral->X` only;
plug-ins that alias the pointer differently are not counted): `ftp` 29×`StrICmp`
+ 28×`StrNICmp` + `GetLowerAndUpperCase` (`ftp/ftp.cpp:221` keeps
`unsigned char* LowerCase`), `demoplug` (all of them; `demoplug.cpp:74`), `zip`
3×`StrICmp` + `MemICmp`, `uniso` 3, `pictview` 3+1, `undelete` 2×`StrNICmp` +
2×`ToLowerCase` + 2×`IsTheSamePath`, `codeview` 1, `nethood`/`portables`
`IsTheSamePath`, `AgreeMask` in 7zip/tar/uncab/unchm/uniso/unrar/zip.
FTP compares server names and protocol keywords that are ANSI in its own
buffers: changing `StrICmp` to "valid UTF-8 → Unicode fold" would alter results
for ANSI byte strings that *happen* to be valid UTF-8 (the same class of
regression 068 warns about for `GetErrorText`). `filecomp` and `renamer` compile
`common/str.cpp` directly and `filecomp/xunicode.cpp:6,23` aliases
`::LowerCase` — so even the *table contents* are observed outside the core.

**Rule**: the exported functions and the two tables stay bit-for-bit. New
semantics are new functions; the core switches its own call sites. Whether to
offer the new functions to plug-ins is an interface-107 decision (the current
branch) and is optional for B-2.

---

## 3. What a correct UTF-8-aware replacement needs

### 3.1 What the tree already has (`common/salunicode.{h,cpp}`)

| helper | where | semantics | used by |
|---|---|---|---|
| `SalIsASCII(s, len=-1)` | `salunicode.h:172`, `.cpp:503` | byte scan | fast-path gate everywhere |
| `SalU8ToW` / `SalU8ToWAlloc` / `SalWToU8` | `salunicode.*` | WTF-8 pair (feature 066); `SalU8ToW` fails on anything that is not WTF-8 | everything |
| `SalNormalizeNFC[Alloc]` | `salunicode.h:161-162` | transient NFC | sort, masks |
| `SalNameEquivalent(a, b)` | `salunicode.h:240`, `.cpp:664` | **case-sensitive** canonical equivalence; byte-equal fast path, ASCII fast path | `fileswn3.cpp:1005`, `fileswn5.cpp:2448,2530` |
| `SalCompareNamesUTF8(a, aLen, b, bLen, ignoreCase)` | `salunicode.h:256`, `.cpp:687` | NFC + `CompareStringEx(LOCALE_NAME_USER_DEFAULT, ignoreCase ? LINGUISTIC_IGNORECASE : 0)`; `memcmp` fallback when not UTF-8; **4 heap allocations per call** (2× `SalU8ToWAlloc`, 2× `SalNormalizeNFCAlloc`), no ASCII fast path | `sort.cpp:29`, `SalNameEqualCI` |
| `SalNameEqualCI(a, aLen, b, bLen)` | `salunicode.h:265`, `.cpp:721` | ASCII → `_strnicmp`; else `SalCompareNamesUTF8(...,TRUE) == 0` — **linguistic** equality | `fileswn0.cpp:73,86` (quick search), `finddlg1.cpp:4053` |
| `AgreeMask` (W twin) | `masks.cpp:80-150` | ASCII fast path, else NFC + per-unit `CharLowerW` | all mask matching |
| `SalU8Next`, `SalU8CharCount` | `salunicode.*` | character stepping | quick search |

Not present anywhere in `src/` outside `salunicode.cpp:704`: `CompareStringOrdinal`,
`LCMapStringEx`, `RtlEqualUnicodeString`, any UTF-8 case-fold-to-buffer helper
(grep over the core returned only the lines listed above).

### 3.2 What the panel sort uses today

`SortNameExt` (`sort.cpp:321-390`) → `LessNameExt` → `CmpNameExt` (`sort.cpp:267`) →
`RegSetStrICmpEx` (`:194`) → `StrCmpLogicalEx` (`:33`, digit runs compared
numerically, text segments via `SalSortCompareStr`) or `SalSortCompareStr`
directly when *Detect numbers* is off. `SalSortCompareStr` (`:17-30`):

- both segments ASCII and `SortUsesLocale` → `CompareString(LOCALE_USER_DEFAULT,
  NORM_IGNORECASE)` (ANSI, un-suffixed);
- both ASCII and not `SortUsesLocale` → `StrICmpEx` / `StrCmpEx` (byte tables);
- otherwise → `SalCompareNamesUTF8`.

`CmpNameExt`/`CmpNameExtIgnCase` then tie-break with `StrCmpEx` so NFC/NFD twins
get a deterministic order (`sort.cpp:259-261,300-305`). The other sorts
(`LessExtName` `:393`, `LessTimeNameExt` `:501`, `LessSizeNameExt` `:584`,
`LessAttrNameExt` `:666`) fall back to the same name comparison.

So **ordering is already Unicode-correct for non-ASCII names** and no B-2 work
is needed there, with one exception — the intransitivity in section 0.4 when
`SortUsesLocale` is off (the byte comparator and the linguistic comparator
disagree about punctuation, and the choice between them is made *per pair*).
Fix candidates: (a) decide per *sort run* (or simply always) instead of per
pair — i.e. when `SortUsesLocale` is off use a pure ordinal comparison for
everything: `StrICmpEx` for ASCII pairs and `CompareStringOrdinal(…, TRUE)` for
the rest are mutually consistent, because ordinal-ignore-case orders by
upper-cased UTF-16 code unit and ASCII sorts below everything else in both;
(b) leave it and document. (a) is the correct one and is small.
Note a second, smaller mismatch on the locale path: ASCII pairs use
`NORM_IGNORECASE`, non-ASCII pairs `LINGUISTIC_IGNORECASE`; under a Turkish user
locale these disagree on `i`/`I`. Not measured.

### 3.3 What NTFS and Explorer do

- **NTFS name equality**: both names are upper-cased code unit by code unit with
  the volume's `$UpCase` table (a simple one-to-one UTF-16 mapping fixed when the
  volume was formatted), then compared **binary**. No normalization (NFC and NFD
  spellings are two different files — the tree already relies on this:
  `SalNameEquivalent` twins, `sort.cpp:259`), no locale, no ignorable
  characters, lone surrogates compare as themselves.
- The user-mode equivalent is `CompareStringOrdinal(a, la, b, lb, TRUE)` /
  `RtlEqualUnicodeString(…, TRUE)`: the OS upper-case table, per code unit, then
  binary. It differs from a given volume's `$UpCase` only for characters whose
  case mapping was added to Unicode after that volume was formatted (a handful;
  accepted by .NET's `OrdinalIgnoreCase`, which is what everyone uses for
  Windows paths).
- **Measured** (this machine): `CompareStringOrdinal(TRUE)`: `Č.txt`==`č.txt`;
  `strasse`≠`straße`; `ab`≠`a<SHY>b`; `Ａ`≠`A`; `ǅ`≠`ǆ` but `Ǆ`==`ǆ` (simple
  upper-case mapping); `İ`≠`i`, `ı`≠`I`; NFC `č` ≠ NFD `č`; `σ`≠`ς`;
  `K`(U+212A)≠`k`; lone surrogates `D800`≠`D801`. Every one matches NTFS
  behaviour. `CompareStringEx(LINGUISTIC_IGNORECASE)` reported *equal* for
  `strasse`/`straße`, soft hyphen, ZWJ, full-width `Ａ`, `ǅ`/`ǆ`, NFC/NFD,
  `σ`/`ς`, Kelvin sign, and two **unassigned** code points.
- **Explorer ordering**: `StrCmpLogicalW` (the tree's `StrCmpLogicalEx` is its
  re-implementation, `sort.cpp:32`), i.e. linguistic, digit-aware — what the
  panel already does.

### 3.4 Recommended semantics

| purpose | semantics | helper |
|---|---|---|
| **Name / path identity** (focus, same path, same archive, "only a change of case", duplicates, cache keys, tree lookup) | NTFS: ordinal ignore-case on UTF-16, **no** NFC | **new** `SalNameEqualOrdinalCI` / `SalNameCompareOrdinalCI` (below) |
| **Ordering shown to the user** | what the panel uses: `RegSetStrICmp[Ex]` / `CmpNameExt` | existing; fix the per-pair comparator choice |
| **Ordering for internal sorted arrays + binary search** (`CNames`, `CDirectorySizes`, `ContainsString`, shares) | any total order consistent with the identity relation → the ordinal comparator's three-way result | new `SalNameCompareOrdinalCI` on **both** sides of each pair |
| **Search** (quick search, Find, type-ahead) | linguistic + NFC-insensitive | existing `SalNameEqualCI` — keep |
| **Mask matching** | existing `AgreeMask` (NFC + `CharLowerW` per unit) | keep; note it is a *third* fold (per-unit `CharLowerW`), close to ordinal |
| **Case conversion for display** (`GetCommonFileTypeStr`, `AlterFileName`) | `LCMapStringEx(LOCALE_NAME_USER_DEFAULT, LCMAP_UPPERCASE/LOWERCASE)` on UTF-16, convert back | cluster **B-4**, not here |

Proposed helper contract (in `common/salunicode.{h,cpp}` so `saltests` covers it):

```
// NTFS-style identity: ordinal, case-insensitive, NOT normalization-insensitive.
// <0 / 0 / >0.  aLen/bLen may be -1.
//  1. both ASCII            -> byte loop with an ASCII-only fold ('A'..'Z' | 0x20)
//  2. both valid WTF-8      -> SalU8ToW into stack buffers (heap only when longer),
//                              CompareStringOrdinal(wa, la, wb, lb, TRUE) - CSTR_EQUAL
//  3. either is not WTF-8   -> legacy StrICmpEx(a, la, b, lb)   (ANSI plug-in text,
//                              transitional data: exactly today's answer)
int  SalNameCompareOrdinalCI(const char* a, int aLen, const char* b, int bLen);
BOOL SalNameEqualOrdinalCI(const char* a, int aLen, const char* b, int bLen);
BOOL SalPathEqualOrdinalCI(const char* p1, const char* p2);   // IsTheSamePath rules: optional leading/trailing '\'
BOOL SalPathHasPrefixOrdinalCI(const char* prefix, int prefixLen, const char* path); // StrNICmp(path, prefix, len) replacement, see T2
```

Notes on the design:

- Step 1's ASCII fold differs from `LowerCase[]` only for bytes ≥ 0x80, which
  step 1 never sees — so **for ASCII input the result is bit-identical to
  today's `StrICmp`**, including the sign and (for `StrICmpEx`) the
  length tie-break. Verify the tie-break against `common/str.cpp:383-395`
  when implementing; `saltests` should pin it.
- Step 3 is the same "valid UTF-8, else legacy" discipline the rest of the tree
  uses (`AgreeMask` `masks.cpp:147`, `SalCompareNamesUTF8` `.cpp:695`).
- Mixed case (one ASCII, one not) goes to step 2; an ASCII string is valid
  UTF-8, so no special handling.
- The three-way result of step 2 (upper-cased UTF-16 unit order) and of step 1
  (lower-cased byte order) are **not the same order** for ASCII punctuation
  between `Z` and `a` (`[ \ ] ^ _ \``): upper-casing puts `_` (0x5F) after
  `Z`; lower-casing puts it before `a` — and *also after* `z`→ no: lower-casing
  maps `A-Z` to 0x61-0x7A, so `_` (0x5F) sorts **before** all letters; upper-casing
  maps `a-z` to 0x41-0x5A, so `_` sorts **after** all letters. A comparator that
  uses step 1 for ASCII pairs and step 2 otherwise would therefore be
  intransitive in exactly the way `SalSortCompareStr` is. **For the three-way
  variant, fold ASCII to upper case in step 1** (or run step 2's rule by hand),
  and accept that the *order* of internal arrays changes relative to today
  (harmless: they are rebuilt in memory, never persisted — see T5). For the
  `BOOL` equality variant the fold direction is irrelevant.

---

## 4. Performance

Hot paths among the name-bearing sites:

| path | sites | volume | today | notes |
|---|---|---|---|---|
| Panel sort | `sort.cpp:17-30` via `CmpNameExt` | O(n log n) ≈ 1.7 M compares for 100 000 names, × segments when *Detect numbers* is on | ASCII: byte loop or `CompareStringA`; non-ASCII: **4 mallocs + 2 `NormalizeString` + `CompareStringEx` per segment pair** | out of B-2 scope unless the comparator choice is fixed; if touched, add stack buffers + `IsNormalizedString` skip |
| Refresh merge | `fileswn0.cpp:2916-3011` (`LessNameExtIgnCase`/`LessNameExt`) | O(n) per refresh | same comparator | must stay the *same* function as the sort |
| Focus search after refresh | `fileswn1.cpp:2465,2480`, `fileswn0.cpp:3119-3165` | O(n) per refresh, one fixed needle | `StrICmp` | convert the needle to UTF-16 **once**, or pre-filter: `NameLen` equality is already tested at `fileswn0.cpp:3118`; a cheap pre-filter (first byte ASCII-fold equal, or both non-ASCII) keeps it near today's cost |
| Mask matching | `masks.cpp:126-150` + optimized ext path `:780-815` + hash `:491` | per file per mask (filter, Find, colouring `CHighlightMasks`, viewer/editor association) | ASCII fast path already | only `masks.cpp:780,795,815` need the equality helper; ASCII fast path covers > 99 % of extensions |
| Quick search | `fileswn0.cpp:40-112` | per keystroke × n | ASCII fast path; non-ASCII does up to `3*segChars+3` `SalNameEqualCI` calls per name per segment, each 4 mallocs | existing cost, not B-2 |
| Extension → association | `fileswn3.cpp:643…1554`, `salamdr4.cpp:1445`, `fileswn4.cpp:177` | per file on read, per visible row on paint | byte fold into scratch + binary search | leave (see T6); ASCII extensions are unaffected |
| `PackIsArchive` | `pack3.cpp:397-440` | per file on every `CommonRefresh` (comment at `:397`) | byte fold | leave |
| `CSalamanderDirectory` lookup | `zip.cpp:5789,6191,…` (`SalDirStrCmpEx`, linear scan per added path component, with an "add cache") | archive listing: O(files × dirs-in-level); *"time-critical method"* `zip.cpp:5781` | `StrICmpEx` | stage S4 only; needs the fast path and stack buffers; measure with a 100 000-entry archive |
| `IsTheSamePath` in change notifications | `fileswn2.cpp` auto-refresh, `fileswn7.cpp:2043` | per notification × panels | byte loop | trivial volume |
| `CNames`/`CDirectorySizes` sort + lookup | `salamdr6.cpp:606-760,1056-1100` | selection of n names: n log n + n log n | `StrICmp` | fast path sufficient |

Approach that keeps a pure-ASCII fast path and bounds the slow path:

1. **Single forward scan, not `SalIsASCII` twice.** Compare bytes with the ASCII
   fold while both bytes are < 0x80; return at the first ASCII difference
   *only in the equality variant* (in the three-way variant an early ASCII
   difference is also final, provided step 1 and step 2 use the same fold
   direction — upper — because UTF-16 units of non-ASCII characters are all
   ≥ 0x80 > any ASCII, and a byte ≥ 0x80 in UTF-8 always belongs to such a
   character). Only when a byte ≥ 0x80 is met in either string before a
   difference, fall to the wide path **for the remainder** (the common prefix
   is already known equal; back up to the start of the current character).
   Cost for ASCII names: identical to today's loop. Cost for `Čeština 1.txt`
   vs `Čeština 2.txt`: one wide compare.
2. **No heap** for names up to `MAX_PATH` units: `WCHAR buf[2][260]` on the
   stack, `SalU8ToW` directly (it already takes a caller buffer); heap only for
   longer paths.
3. **Byte-equal short-cut**: `strcmp(a,b)==0` ⇒ equal (already the
   `SalNameEquivalent` idiom, `salunicode.cpp:668`) — covers the dominant
   "same path twice" case of `IsTheSamePath` before any conversion.
4. Measured ballpark (Python ctypes, call overhead included, 49-unit names):
   `CompareStringOrdinal` ≈ 0.6 µs/call, `CompareStringEx` linguistic
   ≈ 1.5 µs/call. Ordinal is not a bottleneck even at 1.7 M calls (≈ 1 s
   worst case for a 100 000-name all-non-ASCII directory, *if* it were used
   for the sort — it is not).

---

## 5. Risks and traps

**T1 — the exported functions and tables are a published contract.** See 2.4.
`GetLowerAndUpperCase` hands the raw tables out; FTP keeps the pointer for the
whole session. Never change `LowerCase[]`, `StrICmp`, `StrNICmp`, `StrICmpEx`,
`MemICmp`, `StrICpy`, `ToLowerCase`, `ToUpperCase`, or the exported
`IsTheSamePath` / `HasTheSameRootPath` for input that is not valid UTF-8. For
`IsTheSamePath`/`HasTheSameRootPath` (paths *are* UTF-8 by the interface-104
convention) a "UTF-8 → ordinal, else legacy" body is defensible, but it is a
plug-in-visible behaviour change and belongs in the interface-107 notes.

**T2 — `StrNICmp(path, prefix, prefixLen)` is a byte-length prefix test.**
35 of the 43 core `StrNICmp` lines are of the form "does `path` start with
`prefix` (n = `strlen(prefix)`) and is the next byte `\\` or 0"
(`fileswn1.cpp:2332,2359,2377`, `fileswn3.cpp:1811,1939`, `fileswn7.cpp:2044`,
`cache.cpp:365,662`, `find.cpp:532,540,628`, `dialogs5.cpp:784`,
`plugins2.cpp:1386,3001,3436`, `shares.cpp:235,270`, `shellib.cpp:1581,1862`,
`fileswnb.cpp:1194`, `fileswn5.cpp:2153`, `salamdr3.cpp:3502,3534`). The callers
then index `path[prefixLen]`. Ordinal case folding can **change the UTF-8 byte
length** (`ı` U+0131 2 bytes ↔ `I` 1 byte; `ſ` U+017F ↔ `S`; `K` U+212A 3 bytes —
though the last is *not* folded by ordinal; the first two are: verify by test),
so "first n bytes" of the two strings need not cover the same characters. The
replacement must be "convert both, compare the first `m` units where `m` is the
unit length of the *prefix*", and it must return **how many bytes of `path` were
consumed** so the caller's `path[len]` test stays valid. Hence the dedicated
`SalPathHasPrefixOrdinalCI` in 3.4 rather than a drop-in `StrNICmp` clone. Also:
a byte prefix can end inside a multi-byte character of `path` — today that
"matches" garbage; the new helper must refuse.

**T3 — disk-cache keys are folded at the producer, compared exactly.**
Keys are built with `StrICpy` (`fileswn2.cpp:1305`, `fileswn5.cpp:787`,
`fileswn6.cpp:3190`, `fileswn9.cpp:1225`) and by plug-ins with `ToLowerCase`
(`regedt/fs3.cpp:392`, `undelete/fs2.cpp:1443`; contract text `spl_gen.h:2119-2172`,
`spl_fs.h:43`), then looked up by **`strcmp` binary search**
(`cache.cpp` `GetNameIndex`, per `verdicts-V6.md:95-99`), while
`cache.h:88-89` uses `StrICmp`. The fold is a pure key normalizer. Changing one
producer to a Unicode fold while another keeps the byte fold makes one archive
have **two keys** (edited file not found again → the "archive changed, update?"
prompt is skipped, or a stale copy is served). All four core producers + the
`cache.h` comparators must move in one commit, the plug-in producers cannot move
at all — but they key *their own* namespaces (`regedt`, `undelete` prefixes), so
that is safe. The existing false collision (`Č.zip` vs `Ĝ.zip`) is fixed by
such a move. Keys live only in memory (the cache is per-process), so no
migration.

**T4 — sort ↔ consumers of the sorted order must use one comparator.** Pairs:

| order produced by | order consumed by | status |
|---|---|---|
| `SortNameExt` (`sort.cpp:383`, called `fileswn3.cpp:1702-1729`) | refresh merge `fileswn0.cpp:2916-3011` (`LessNameExtIgnCase`, `LessNameExt`); precondition comment `fileswn0.cpp:2484-2498` (re-sorts when `SortUsesLocale`/`SortDetectNumbers` changed — `SortedWithRegSet`, `SortedWithDetectNum`, `fileswn3.cpp:1757-1759`) | same functions — keep; **intransitivity (0.4) breaks the merge's assumption** |
| `SortNameExt` on both panels `mainwnd5.cpp:859-865` | Compare Directories merge `mainwnd5.cpp:879,954,1300,1514` (`CmpNameExtIgnCase`) | same functions; uses *linguistic* equality to pair files (`straße.txt` pairs with `strasse.txt`) |
| `SortNames` `salamdr6.cpp:606` (`StrICmp`) / `SortNamesCaseSensitive` `:668` | `FindNameInArray` `:730-760` (`CNames`: `GlobalSelection` `salamdr1.cpp:365`, `OldSelection`/`HiddenNames` `fileswnd.h:899-900`, tab `Selection` `paneltabs.h:36`, `salshlib.h:178`) | must move together |
| `CDirectorySizes::Sort` `salamdr6.cpp:1056` | `CDirectorySizes::GetIndex` `:1066-1100` | must move together |
| sorted insert into `usedNames` | `ContainsString` `fileswn6.cpp:440-475` | must move together (find the insert side before touching) |
| `CShares` sorted `Wanted` | `shares.cpp:175-200` | must move together; share names, low value |
| `CAssociations::SortArray` `icncache.cpp:1031` + fold at `:1220,1264,1308` | `CAssociations::GetIndex` `icncache.cpp:915` with the folds at `fileswn3.cpp:643,1194,1276,1455,1554`, `fileswn4.cpp:177`, `salamdr4.cpp:1445`, `fileswn2.cpp:3931` | 9 sites, one invariant: **same fold on both sides** |
| `CPackerFormatConfig::BuildArray` `pack3.cpp:320-335` (reversed, folded, bucket = last byte) | `PackIsArchive` `pack3.cpp:397-440` | same |
| `COMPUTEMASKGROUPHASH` at insert | same macro at lookup `masks.cpp:807` + `StrICmp` `:815` | hash and equality must agree: if equality becomes ordinal, two extensions equal under it must hash alike → hash only ASCII-folded bytes, or hash the folded wide form |
| `CEnvVariables` sort `salamdr7.cpp:132-134` | `FindItemIndex` `:168` | env names; leave |
| `COneDriveBusinessStorages::SortIn` `drivelst.cpp:1476` | `:1492` | display names; leave |

**T5 — persisted sorted data.** None found for names: `CNames`, `CDirectorySizes`,
`Associations`, the packer extension table, mask hash arrays and the disk cache
are all rebuilt in memory per session. Tab records persist the *selection
names* (feature 078, `paneltabs.h:36`, "Sort()ed") — check whether the stored
order is relied on at load or re-sorted (`CNames::Sort` runs when `NeedSort`);
if a loaded record sets `NeedSort = FALSE`, a comparator change would break
the binary search for an old record. **Not verified — verify before S3.**

**T6 — extensions via the registry.** The association table is keyed by the
lower-cased extension read from `HKCR` (`icncache.cpp:1220`). A non-ASCII
extension is vanishingly rare; converting this pair buys nothing and touches a
per-file hot path and `icncache.cpp`, which 069 deliberately left alone
(`specs/069-…/REMAINING-WORK.md` §2 item 1). Leave.

**T7 — archive plug-ins and `CSalamanderDirectory`.** `SalDirStrCmp[Ex]`
(`zip.cpp:5670-5684`) decides whether an added path component is an existing
directory. Plug-ins feed names here through `AddFile`/`AddDir` — UTF-8 from the
converted plug-ins, **ANSI from any legacy/third-party plug-in**. The "valid
UTF-8 else legacy" rule handles that per call, but a tree can then contain both
kinds and an ANSI name that happens to be valid UTF-8 will be folded as
Unicode. Plug-ins also look entries up later by the names *they* hold
(`GetIndex`, `zip.cpp:6580`). Behaviour change is visible to plug-ins →
last stage, with the 7zip/zip/tar/unrar listings as regression fixtures.
`SALDIRFLAG_CASESENSITIVE` trees are unaffected.

**T8 — NFC.** Identity must **not** normalize (two files `č` NFC / NFD coexist on
NTFS; the tree keeps them apart on purpose: `sort.cpp:259-261`, `saltests.cpp:138,
1182-1187`). `SalNameEqualCI` normalizes — one more reason it is the wrong
helper for identity. On macOS-origin SMB shares the server may normalize; that
is the server's business.

**T9 — WTF-8.** Names may contain lone surrogates (feature 066). `SalU8ToW`
accepts them, `CompareStringOrdinal` compares them as units (measured:
`D800`≠`D801`, and `a<D800>` ≠ `a`). `CompareStringEx` also distinguished them
here, but that is undocumented. Add fixtures.

**T10 — "valid UTF-8, else ANSI" misclassification.** A CP1250 string such as
`Ă©` (bytes C3 A9) is valid UTF-8. For core-internal names this cannot occur
(names are UTF-8 by contract since 004); it matters only at the exported entry
points (T1) and in `CSalamanderDirectory` (T7).

**T11 — false equality becoming inequality.** Today `…\ĥ` == `…\Ĺ` for
`IsTheSamePath`. Any code that *accidentally depends* on a too-wide equality
(none found, but e.g. `CPathHistoryItem::IsTheSamePath` `salamdr3.cpp:1696`
de-duplicates history) will now keep both entries — correct, and visible.

**T12 — Turkish and other ACPs.** The byte tables depend on the ACP; the nine
collision pairs in `verdicts-V2.md:179-186` are CP1250's. Tests must not assume
them: build expectations from `CharLowerA` at run time, or test only the new
helper (which is ACP-independent on valid UTF-8). L82 in
`review-report.md:486` makes the same point.

**T13 — `str.cpp` has an x86 assembly twin** (`common/str.cpp:153-205,240-300,
320-375,416-480`) selected by `#ifdef _WIN64`. Shipping is x64 only, but the
shell extension builds x86. Another reason not to edit `str.cpp`.

**T14 — the 069 lesson on half-converted chains.** Two 069 fixes were rejected
because one end of a chain moved and the other did not
(`CLAUDE.md` entry 069: the `DROPFAKE` folder name compared by the ANSI shell
extension). The shell-extension pair `salshlib.cpp:546,627` ↔ `shellext/` is
exactly that kind of chain — exclude it from a first feature.

---

## 6. Proposed scope and staging

Guiding rule: **equality only, core-internal call sites only, new helper only.**
No change to `str.cpp`, to any exported function, to the tables, to the sort,
or to `AlterFileName`.

| stage (one commit each) | content | why here |
|---|---|---|
| **S0 — guard hygiene** (no behaviour change) | replace the 29 drive-letter table uses by an ASCII inline (`SalIsDriveLetter`, `SalDriveIndex`) or implement P7's `DRIVE_SHAPE` narrowing in `tools/check_encoding.py`; annotate `masks.cpp:49,52,327` (ASCII-only path) and `pack3.cpp:405`; promote `acp-byte-table-on-name` to strict; extend the rule (or add `byte-fold-on-name`) to flag `StrICmp|StrNICmp|StrICmpEx|StrICpy|IsTheSamePath` in files once they are converted, with a planted-defect proof as in 068 | makes the guard mean something before code moves; closes the Turkish-ACP footnote |
| **S1 — helpers + tests** | `SalNameCompareOrdinalCI`, `SalNameEqualOrdinalCI`, `SalPathEqualOrdinalCI`, `SalPathHasPrefixOrdinalCI` in `common/salunicode.*`; saltests (section 7) | pure, testable, no caller yet |
| **S2 — panel focus / identity of a single name** | `fileswn1.cpp:2465,2480`, `fileswn0.cpp:3119,3150,3165`, `fileswn2.cpp:2739,3098,3113`, `fileswnb.cpp:930,1201,1207`, `fileswn1.cpp:1954`, duplicates `fileswn6.cpp:3181`, `shellsup.cpp:1882,1897`, `mainwnd3.cpp:2705`, `finddlg1.cpp:990,1006` | the confirmed user-visible scenario (`verdicts-V2.md:254-262`); no pairs, no persistence, GUI-verifiable (rename `Č.txt` → `č.txt`, cursor follows) |
| **S3 — "only a change of case" + correct-case** | `fileswn5.cpp:2191,2204,2205,2256`, `worker.cpp:3002-3003,3215,4526,5817,5832-5833,5906,6424-6425`, `fileswn6.cpp:1772,1775,2648,2696`, `safefile.cpp:154-155`, `pack2.cpp:501`, `cache.cpp:399,406` | operational; each is a local equality of two names obtained in the same function; **independent review mandatory** (these gate overwrite prompts) |
| **S4 — core path identity** | internal `IsTheSamePath` callers switch to `SalPathEqualOrdinalCI`; `SamePath` `fileswn1.cpp:373`; `fileswn7.cpp:2043-2051`; `fileswnb.cpp:657,1194`; `salamdr3.cpp:1696,1703,3502,3534`; `salamdr5.cpp:767,1143`; `fileswn3.cpp:1811,1868,1911,1939`; `fileswn1.cpp:2332,2359,2377`; archive identity `fileswn2.cpp:1303,2127,2234`, `fileswn9.cpp:1240`; the exported `CSalamanderGeneral::IsTheSamePath` keeps calling the legacy function | uses the prefix helper (T2); bigger surface, mostly "identical bytes" in practice so low risk, but ~45 sites |
| **S5 — sorted-array pairs** | `SortNames`+`FindNameInArray`+`CDirectorySizes` (after verifying T5); disk-cache key producers + `cache.h:88-89` (T3); optimized-extension masks `masks.cpp:491-496,780,795,815` (hash + equality together) | each sub-item is a pair that must move atomically; one commit per pair |

**Deferred, with reasons:**

- **`CSalamanderDirectory` (`zip.cpp:5670-5684`)** — plug-in-visible, mixed
  ANSI/UTF-8 producers, time-critical (T7). Own feature or the tail of this one
  after a 100 000-entry listing benchmark.
- **Exported `StrICmp` family, `ToLowerCase`/`ToUpperCase`,
  `GetLowerAndUpperCase`** — frozen (T1, cluster B-5). If plug-ins should get the
  new semantics, add *new* methods in interface 107 instead.
- **Exported `IsTheSamePath` / `HasTheSameRootPath` bodies** — plug-in-visible;
  decide with interface 107.
- **Sort comparator intransitivity and the linguistic equality in Compare
  Directories** (0.4) — real, but it is a *sort* change, visible in every
  panel, and needs its own measurement on a large directory. Record it as a new
  NEXT-WORK item; do not fold it into the equality feature.
- **Association / packer extension lookups** (T6) — ASCII in practice, hot,
  self-consistent.
- **`AlterFileName`, `GetCommonFileTypeStr` upper-casing** — cluster B-4.
- **Shell-extension pair `salshlib.cpp:546,627`** — crosses into `shellext/`
  (T14).
- **Find's ANSI type-ahead `finddlg1.cpp:4262-4292`, hot-key folding in menus** —
  cluster B-1 (ANSI windows).
- **`IsAlpha[]`/`IsNotAlphaNorNum[]`** — content, not names (refuted).
- **Shares, env variables, OneDrive display names, policy lists** — not file
  names on disk; no reported defect.

Plug-in ABI: untouched by S0–S5 (no `plugins/shared/` diff). `PRIVACY.md`: not
affected. No configuration-version bump (nothing persisted changes shape).

---

## 7. Tests

### 7.1 What exists

`src/saltests/saltests.cpp` does **not** link `common/str.cpp`, so there is
**no test of `LowerCase[]`, `StrICmp`, `StrNICmp`, `StrICmpEx`, `StrICpy`,
`MemICmp`, `StrIStr`, `IsTheSamePath`, `HasTheSameRootPath`, `AgreeMask`,
`RegSetStr*` or `CmpNameExt`** (grep for those identifiers in `saltests.cpp`
returns nothing). What exists is the `salunicode` layer:

- `TestMatching` (`saltests.cpp:117-151`): `SalIsASCII` (`:119-120`),
  `SalNameEquivalent` (`:135-138`), `SalNameEqualCI` (`:141-144`: `Č.TXT` NFC ==
  `č.txt` NFD, `ABC`==`abc`, explicit lengths), `SalCompareNamesUTF8`
  (`:147-150`).
- `TestWtf8` (`:1097`, checks at `:1182-1187`): lone-surrogate twins are not
  equivalent / not equal, and the comparison is antisymmetric.
- `TestEncodingReview068` (`:1304`), `TestEncodingFixes069` (`:1445`): the
  helpers those features added; nothing on case folding.

The mask matcher, the sort comparators and the path comparators live in the
core (`masks.cpp`, `sort.cpp`, `salamdr1.cpp`) with `precomp.h` dependencies and
are not reachable from `saltests` — the same contract-C14 limitation feature 075
recorded.

### 7.2 Test plan

**Unit (`saltests`, new `TestNameIdentity0xx`)** — all on the new helpers:

1. ASCII parity: for a table of ASCII pairs (incl. `_`, `[`, digits, empty,
   prefix-of-other, explicit lengths) assert the *sign* equals a local reference
   implementation of today's `StrICmpEx` semantics (the reference is 10 lines;
   it does not need `str.cpp`). For the three-way variant assert the documented
   fold direction explicitly (`"_"` vs `"a"`).
2. The motivating pairs: `Č.txt`==`č.txt`; `ĥ`≠`Ĺ`; `Č`≠`Ĝ`; and every CP1250
   collision pair from `verdicts-V2.md:182-185` built from code points (must be
   *unequal*), every upper/lower pair of Latin-1 Supplement, Latin Extended-A,
   Greek, Cyrillic generated by `CharUpperW` (must be *equal*).
3. NTFS-distinct, linguistically-equal pairs must be **unequal**: `strasse`/`straße`,
   soft hyphen, ZWJ, full-width `Ａ`/`A`, NFC/NFD `č`, `σ`/`ς`, Kelvin/`k`,
   two unassigned code points. (Each is the measured counter-example of 0.4 —
   the test that would fail if someone "simplified" the helper to
   `SalNameEqualCI`.)
4. WTF-8: lone-surrogate twins unequal; a name with a lone surrogate equals
   itself and equals its case variant in the ASCII part.
5. Not-UTF-8 fallback: two CP1250 byte strings with a byte ≥ 0x80 that is not
   valid UTF-8 → result equals the legacy byte fold computed at run time from
   `CharLowerA` (no hard-coded ACP expectation, T12).
6. Length-changing folds (T2): `SalPathHasPrefixOrdinalCI` with `ı`/`I`, `ſ`/`S`
   in the prefix — assert the returned consumed-byte count points at the
   separator; prefix ending inside a multi-byte character → FALSE.
7. `SalPathEqualOrdinalCI`: the four leading/trailing-backslash combinations of
   `IsTheSamePath` (`salamdr1.cpp:1430-1441`), UNC, long paths > `MAX_PATH`
   (heap path), empty strings.
8. Order properties on a generated set of ~500 mixed names: antisymmetry and
   **transitivity** of `SalNameCompareOrdinalCI` (exhaustive triples on a
   subset) — the property `SalSortCompareStr` fails today; and
   "compare == 0 ⇔ equal".
9. Real-NTFS round trip (as `TestWtf8FileOps` does, `saltests.cpp:1214`): create
   `Č.txt` in a temp directory, assert `CreateFileW(OPEN_EXISTING)` on `č.txt`
   succeeds and on `straße`-vs-`strasse` twins creates two files — pins the
   helper to what the file system actually does on the build machine.

**Evidence probe (the 075 pattern, `specs/<feature>/probe/`)** for sites not
reachable from `saltests`: compile the verbatim pre-/post-fix bodies of
`IsTheSamePath`, the focus loop and the DOS-collision predicate with a table
built from a chosen code page (`MultiByteToWideChar(1250,…)` + `CharLowerW`, so
it runs identically on any machine — the L82 idea, `review-report.md:486`).

**Sorted-pair property tests** (S5): fill `CNames`-equivalent arrays with the
generated set, sort, and assert every element is found by the binary search —
run against both the old and the new comparator to show the invariant holds
before and after.

**Guard**: plant one `StrICmp(f->Name, …)` in a converted file and show the
strict run fails (the 068 "proven to fire" requirement).

**GUI (owed to a person or the 078 PowerShell driver)**: Shift+F6 `Č.txt` →
`č.txt`, cursor follows; same in an archive; two files `ĥ.txt`/`Ĺ.txt`, refresh
keeps the cursor on the right one; F5 copy onto a case-different accented
target shows the overwrite prompt exactly once; quick search and filter
unchanged for ASCII; Compare Directories on a pair of trees with accented
names; a 100 000-file directory refresh timed before/after.

---

## 8. Sources read

- `specs/069-finish-encoding-fixes/REMAINING-WORK.md:38-47` (cluster table), §2.
- `specs/068-encoding-regression-review/review-report.md:141,147,243,255,297,486,630-640`.
- `specs/068-encoding-regression-review/findings/P3.md:466-505` (F-P3-06),
  `verdicts-V2.md:156-262`, `P5.md:44-45,87,176` and `verdicts-V6.md:70-100`
  (F-P5-02), `P7.md:205-240,317`.
- `tools/check_encoding.py:95-108,243-290,461-530,544-592`.
- Code: `common/str.{h,cpp}`, `common/salunicode.{h,cpp}`, `sort.cpp`, `masks.cpp`,
  `fileswn0.cpp`, `salamdr1.cpp`, `zip.cpp`, `salamdr6.cpp`, `pack3.cpp`,
  `worker.cpp`, `fileswn5.cpp`, `fileswn6.cpp`, `cache.{h,cpp}`,
  `plugins/shared/spl_gen.h`, `saltests/saltests.cpp` and the vcxproj files named
  above.

Not verified by execution (stated where it matters): the rename/overwrite
scenario of S3, the Turkish-ACP remarks, the `ı`/`ſ` ordinal folds, tab-record
`NeedSort` behaviour (T5), and the insert side of `usedNames` for
`ContainsString`.
