# Feature 092, stage S5 — sorted lists and keys: analysis and plan

Read-only analysis at branch `092-name-identity-unicode` (working tree with S1/S2 changes).
Nothing was built or run. Line numbers are those of the working tree. "Helper" =
`SalNameCompareOrdinalCI` / `SalNameEqualOrdinalCI` (`src/common/salunicode.cpp:962`, `:1049`).

## 0. Headline findings

1. **Pairs (a), (b) and (c) are one pair, not three.** `SortNames` (`salamdr6.cpp:606`) is the
   sort side of *three* searches: `FindNameInArray` (CNames), `CDirectorySizes::GetIndex`, and —
   through `fileswna.cpp:349` → `fileswna.cpp:417` — `ContainsString`. Converting them "one pair
   per commit" as tasks.md T016 says would break the drag-and-drop-to-archive look-up between
   commits. They must move in **one commit** (5 comparator lines + 2 comments).
2. **T5 is answered: no persisted sorted names exist.** Tab `Selection` is session state, never
   written to the registry (details in §1.2). No CNames is shared with another process.
3. **`CDirectorySizes` is dead code.** Both callers are commented out (`fileswn3.cpp:1680`,
   `fileswn8.cpp:1097`); nothing ever fills or queries `DirectorySizesHolder`.
4. **The disk cache must NOT be converted to the helpers.** Its key is only *partly*
   case-insensitive (archive path folded, path inside the archive case-preserved, plug-in keys
   case-sensitive by the published contract). A case-insensitive comparator over the whole key
   would make `a.txt` and `A.txt` inside one archive the same cached file. `strcmp`/`strncmp`
   have to stay. The only thing that can change is the *fold at the four producers*, and that
   needs a fold-to-buffer function (see §4).
5. **The helper is a total order only on valid WTF-8** (its own test says so,
   `saltests.cpp:3508`). I can construct a cycle when a list mixes valid and invalid strings:
   `"_"` < `` "`\xE9" `` (both "between", upper fold) ; `` "`\xE9" `` < `"a"` (tier 3, lower fold) ;
   `"a"` < `"_"` (tier 1, upper fold). Derived by reading the code, not executed. `StrICmp` is
   total on all byte strings, so this is a (small) new exposure for lists holding legacy
   plug-in names — and for the clipboard selection, see finding 6.
6. **Found on the way (not S5, record them):**
   - `CNames::LoadFromClipboard` (`salamdr6.cpp:879`) converts `CF_UNICODETEXT` with
     `ConvertAllocU2A` (default `CP_ACP`) and the `CF_TEXT` fallback is ANSI too, then the names
     are compared with the panel's UTF-8 names. A non-ASCII name loaded from the clipboard never
     matches today, and such a list is exactly the "mixed validity" case of finding 5.
   - `fileswn9.cpp:1224-1225`: `char buf[MAX_PATH]; StrICpy(buf, GetZIPArchive());` — the source
     is `ZIPArchive[SAL_MAX_PATH_UTF8]` (`fileswnd.h:496`); unbounded copy into 260 bytes.
     `fileswn2.cpp:1305` copies into `buf[2 * MAX_PATH + 100]` (620 bytes), same class.
   - `CCacheData::NameEqual` (`cache.h:88`) has no caller.
   - `fileswn5.cpp:821` computes the name inside the archive as
     `dcFileName + strlen(GetZIPArchive()) + 1` — it relies on the folded archive name having the
     **same byte length** as the original. Any fold that changes length breaks it.

---

## 1. Pair A+B+C — `SortNames` and its three searches

### 1.1 All sites

Sort side:

| site | code |
|---|---|
| `salamdr6.cpp:616` | `while (StrICmp(files[i], pivot) < 0 && i < right)` |
| `salamdr6.cpp:618` | `while (StrICmp(pivot, files[j]) < 0 && j > left)` |
| `salamdr6.cpp:680,682` | `SortNamesCaseSensitive`: `strcmp` — unchanged |
| callers of `SortNames` | `CNames::Sort` `salamdr6.cpp:771`, `:779`; `CDirectorySizes::Sort` `:1061`; `CFilesWindow::DragDropToArcOrFS` `fileswna.cpp:349` |
| declaration | `consts.h:2338-2339` (`// quicksort s porovnavanim pres StrICmp`) |

Search side:

| site | code |
|---|---|
| `salamdr6.cpp:736` (`FindNameInArray`) | `int res = caseSensitive ? strcmp(items->At(m), name) : StrICmp(items->At(m), name);` |
| only caller | `CNames::Contains` `salamdr6.cpp:843` (function is not declared in any header) |
| `salamdr6.cpp:1081` (`CDirectorySizes::GetIndex`) | `int res = CaseSensitive ? strcmp(Names[m], name) : StrICmp(Names[m], name);` |
| `fileswn6.cpp:455` (`ContainsString`) | `int res = StrICmp(hw, name);` |
| callers of `ContainsString` | `fileswna.cpp:417` (list sorted by `SortNames` at `:349`); `fileswn6.cpp:497` (`AddStringToNames`, the insert side); `fileswn6.cpp:704, 799, 832, 887, 921` (look-ups in `usedNames`) |
| declaration | `consts.h:2341-2344` (`pole je serazene pomoci StrICmp`) |

Insert side of `usedNames`: `AddStringToNames` (`fileswn6.cpp:490-511`) calls `ContainsString`
to get the insertion index and does `usedNames->Insert(index, str)`. Called at
`fileswn6.cpp:708, 803, 836, 891, 925, 942`. The list is created empty at `fileswn6.cpp:663`
and deleted in the same function (`BuildScriptMain2`). It is sorted **by** the search function
itself, so this sub-pair is self-consistent with any comparator.

CNames instances (complete, core only; `plugins/tar/names.h` has an unrelated class of the same name):

| instance | fill | sort | search |
|---|---|---|---|
| `GlobalSelection` (`salamdr1.cpp:365`) | `fileswn1.cpp:2028` | `:2032` | `:2077, 2083, 2090, 2096` (via `selection->Contains`) ; cleared `dialogs4.cpp:4245` |
| local `clipboardSelection` (`fileswn1.cpp:2058`) | `LoadFromClipboard` `:2061` (→ `Add` `salamdr6.cpp:958`) | `:2062` | same four `Contains` |
| `OldSelection` (`fileswnd.h:899`) | `fileswn1.cpp:2133` | `:2137` | `:2151` |
| `HiddenNames` (`fileswnd.h:900`) | `fileswn1.cpp:2191, 2213` | `:2231` | `fileswn3.cpp:497, 955, 1080, 1129, 1347, 1370, 1612` |
| `CPanelTab::Selection` (`paneltabs.h:36`) | `paneltabs.cpp:210` | `:213` | `:316` |
| `CSalShExtPastedData::SelFilesAndDirs` (`salshlib.h:178`) | `salshlib.cpp:485, 490` | `:756` | `:783, 798` (uses `foundOnIndex`) |

`CNames::Add` always sets `NeedSort = TRUE` (`salamdr6.cpp:813`); `Contains` sorts on demand when
`NeedSort` is set (`:837-841`); `SetCaseSensitive` sets `NeedSort` when the mode changes and the
list has more than one item (`:596-603`). There is no `Load`/`Save` method — the only "load" is
`LoadFromClipboard`, which goes through `Add`.

### 1.2 T5 — precise answer

- The persisted part of a tab is `CSalTabRecord` (`common/saltabs.h:29-37`): `Location`,
  `ViewTemplateIndex`, `SortType`, `ReverseSort`, `FilterEnabled`, `FilterMasks`. Nothing else.
- Save: `mainwnd2.cpp:1226-1253` writes exactly `PANEL_PATH_REG`, `PANEL_VIEW_REG`,
  `PANEL_SORT_REG`, `PANEL_REVERSE_REG`, `PANEL_FILTER_ENABLE`, `PANEL_FILTER` per tab.
- Load: `mainwnd2.cpp:2357-2409` reads the same six values, then calls `tab->ResetSession()`
  (`paneltabs.cpp:41-49`: `Selection.Clear()`), `Visited = FALSE`.
- `paneltabs.h:33` says it in a comment: "session state … never persisted".
- `Selection` is filled only by `CaptureActiveTab` (`paneltabs.cpp:189-213`): `Clear`, `Add…`,
  `Sort()` — in this process, with the current comparator.

So a loaded record never carries selection names, and no code path sets `NeedSort = FALSE` on
data it did not sort itself. **A comparator change cannot meet a list sorted by an older build.**

Cross-process: `CSalShExtSharedMem` (`shexreg.h:196-223`) holds the fake directory names, the
target path, PIDs and `PastedDataID` — no name list. `SelFilesAndDirs` lives and is searched in
the main process only (`DoPasteOperation`, main thread). The cross-process chain research T14
warns about is `salshlib.cpp:546, 627` (`ArchiveFileName`), not this list.

### 1.3 Data

| list | strings | encoding | lifetime | threads |
|---|---|---|---|---|
| CNames (all six) | bare item names (`CFileData::Name`), `DupStr` copies | UTF-8/WTF-8 on disk panels; whatever the plug-in supplied in archive / plug-in-FS panels (may be ANSI from a legacy plug-in); ANSI for `clipboardSelection` (finding 6) | memory only; `GlobalSelection` for the session, the others until the next store / path change / tab capture | main thread |
| `CDirectorySizes::Names` | name + trailing `CQuadWord` | UTF-8 | dead code | — |
| `usedNames` | target names generated for "Copy of …" | UTF-8 | one `BuildScriptMain2` call | main thread |
| `data->Data->Names` (`CDragDropOperData`, `shellib.h:58`) | bare names from the dropped data object (`shellib.cpp:593, 704`) | UTF-8 | one drop | main thread |

### 1.4 Is the order observable?

No, for every list. None is displayed, persisted, or merged with a list in another order.

- CNames: only `Contains` is used; `foundOnIndex` is used only by `salshlib.cpp:783-800` as an
  index into the `foundDirs`/`foundFiles` flag arrays, sized by the same list.
- `data->Data->Names`: `foundIndex` indexes `nameFound[]`, sized by the same list
  (`fileswna.cpp:352, 419`); afterwards only "is every flag set" is asked (`:516-528`).
- `usedNames`: only yes/no.

The pair uses **equality plus a consistent order**; any total order works. The different
position of `[ \ ] ^ _ `` ` `` against letters is therefore harmless.

What *does* change, and is the point of the stage: the equality. Today, in a case-insensitive
list, `ĥ.txt` and `Ĺ.txt` are the same entry on a Central European system (hide one → both
vanish; store selection with one → Reselect selects both), and `Č`/`č` variants are different.

### 1.5 Exact replacement

`salamdr6.cpp:616, 618`:

```cpp
        // feature 092: the file system's identity rule; FindNameInArray, CDirectorySizes::GetIndex
        // and ContainsString search lists sorted here and must use the same comparison
        while (SalNameCompareOrdinalCI(files[i], -1, pivot, -1) < 0 && i < right)
            i++;
        while (SalNameCompareOrdinalCI(pivot, -1, files[j], -1) < 0 && j > left)
            j--;
```

`salamdr6.cpp:736`:

```cpp
        int res = caseSensitive ? strcmp(items->At(m), name)
                                : SalNameCompareOrdinalCI(items->At(m), -1, name, -1); // as SortNames
```

`salamdr6.cpp:1081`:

```cpp
        int res = CaseSensitive ? strcmp(Names[m], name)
                                : SalNameCompareOrdinalCI(Names[m], -1, name, -1); // as SortNames
```

`fileswn6.cpp:455`:

```cpp
            int res = SalNameCompareOrdinalCI(hw, -1, name, -1); // as SortNames (fileswna.cpp sorts with it)
```

`consts.h:2338` → `// quicksort; compares with SalNameCompareOrdinalCI (feature 092)`;
`consts.h:2341` → `… (pole je serazene pomoci SalNameCompareOrdinalCI - SortNames nebo AddStringToNames)`.

Not changed: `SortNamesCaseSensitive` and the `strcmp` branches (case-sensitive archives /
plug-in file systems — `IsCaseSensitive()`, `fileswn0.cpp:2316`); `SortNamesCS`
(`fileswna.cpp:810`, `strcmp`, a different list); `CDirectorySizesHolder::GetIndex`
(`salamdr6.cpp:1191`, CRT `stricmp` on a path, dead code — leave or record).

`SortNames` stays safe with any comparator: both inner loops are bounded (`i < right`,
`j > left`), and all three binary searches terminate regardless of the comparison results.

### 1.6 Recommendation: **CONVERT, as one commit** — risk: low

Complete site list = the five lines in §1.5 plus the two comments. I found no other caller of
`SortNames`, `FindNameInArray`, `ContainsString` or `AddStringToNames` in `src/` (plug-ins do
not link the core; `SortNames` is not exported through `spl_gen.h` — not checked beyond a grep
for the name in `src/plugins/`, which shows only unrelated functions).

Residual risk, to be written into the fix log:

- **Mixed-validity lists** (finding 5). Reachable only when a list holds names that are not
  valid UTF-8 together with names containing one of `[ \ ] ^ _ `` ` `` in the deciding position:
  legacy plug-in panels (archive or FS), and `clipboardSelection` because of the ANSI
  conversion. Effect: a name may not be found (not reselected / not hidden / reported as
  missing in the paste from archive). No crash, no loop. Options: accept and record; or fix
  `LoadFromClipboard` to produce UTF-8 (`SalWToU8`; `SalLegacyToU8Alloc` for `CF_TEXT`), which
  removes the one core producer of such lists and fixes a defect of its own — a separate
  commit.
- Legacy plug-in names that *happen* to be valid UTF-8 are compared as Unicode (research T10).

Test for "every element inserted is found again": `saltests` links only `src/common/`, so the
functions themselves are out of reach. Use the 075 probe pattern — a committed probe that
compiles the **verbatim** bodies of `SortNames`, `FindNameInArray` and
`ContainsString`/`AddStringToNames` twice (comparator = `StrICmp`, comparator = helper) and
checks, over generated name sets (ASCII incl. the six punctuation characters against letters,
case pairs of Latin-1 / Latin Extended-A / Greek / Cyrillic, the seven 2↔3-byte pairs, lone
surrogates, names of 300+ bytes, duplicates):
1. after the sort, adjacent elements compare `<= 0`;
2. every element is found, and the element at the returned index compares equal;
3. a name not in the list is not found, and `ContainsString`'s insertion index keeps the list sorted;
4. before/after difference table: `Č`/`č` (not found → found), `ĥ`/`Ĺ` (found → not found);
5. a pinned fixture for the mixed-validity cycle, so the limitation is recorded, not forgotten.
Properties 1–3 hold before and after on valid input; before, they hold on all byte strings.
`saltests.cpp:3495-3530` already proves sort-then-find for the helper with `std::sort`.

### 1.7 Performance

| use | comparisons | today | after |
|---|---|---|---|
| `HiddenNames.Contains` — per item on **every** directory read, only while names are hidden | n · log2(k) | StrICmp ≈ 10–20 ns | 20–90 ns ASCII. 100,000 files, 1,000 hidden: 1 M calls ≈ +20–70 ms. 100,000 files, 10 hidden: ≈ 0.35 M calls, +7–25 ms. Empty list: returns before any comparison (`salamdr6.cpp:826-833`) — the default case costs nothing. |
| Store / Restore selection, Reselect, tab switch | n log n once per user command | — | 100,000 selected: ≈ 1.7 M + 1.7 M calls ≈ 0.1–0.3 s worst case (ASCII), a few times more with all-non-ASCII names (two `SalU8ToW` + `CompareStringOrdinal`, ≈ 0.3–0.6 µs) |
| paste from archive (`salshlib.cpp`) | items · log2(k) once | — | negligible |
| `usedNames`, drag-and-drop names | tens to thousands | — | negligible |

Each call passes `-1` lengths, so the helper runs two `strlen`s first; acceptable here. SC-005
(refresh of 100,000 files ≤ +10 %) is not touched unless names are hidden.

---

## 2. Pair B — `CDirectorySizes` (covered by §1)

Sites: `Sort` `salamdr6.cpp:1056-1064` (`SortNames`), `GetIndex` `:1066-1100` (compare at
`:1081`), `Add` `:1015` (sets `NeedSort`), `GetSize` `:1043`. Constructed only with
`caseSensitive = FALSE` (`:1143`). **Never used**: `Store` and `Restore` have no live caller.

Recommendation: convert line 1081 **in the same commit as `SortNames`** (it must not be left
on `StrICmp` once the sort changes), or delete the class. No test needed beyond §1.6; no
performance relevance.

---

## 3. Pair C — `ContainsString` (covered by §1)

Two independent lists use it: `usedNames` (sorted by its own insertion index — self-consistent)
and the drag-and-drop names (sorted by `SortNames`). The second one is what ties it to pair A.
Recommendation: **CONVERT with §1**, risk low.

---

## 4. Pair D — disk-cache keys

### 4.1 How a key is normalised and compared, end to end

Storage: `CCacheDirData::Names` (`cache.h:157`), one sorted array per tmp-directory, of
`CCacheData*`; key = `CCacheData::Name` (`cache.h:40`, "path to original"). In memory only, per
process; accessed under the cache's critical section (`Enter`/`Leave`) from any thread.

Comparison — **exact bytes everywhere**:

| site | code | role |
|---|---|---|
| `cache.cpp:431` (`GetNameIndex`) | `int res = strcmp(name, Names[m]->GetName());` | the only search; also yields the insertion index |
| `cache.cpp:535-537` | `GetNameIndex(name, i)` then `Names.Insert(i, newName)` | the only insert |
| `cache.cpp:498, 567, 580, 592, 616, 709` | `GetNameIndex(...)` | `GetName`, `NamePrepared`, `AssignName`, `ReleaseName`, `Release`, `FlushOneFile` |
| `cache.cpp:681-684` (`FlushCache`) | `GetNameIndex(name, i)` then `strncmp(Names[i]->GetName(), name, nameLen) == 0` over the contiguous run | prefix removal ("all files of one archive / one FS") |
| `cache.h:88` | `BOOL NameEqual(const char* name) { return StrICmp(Name, name) == 0; }` | **no caller** |

Not key comparisons (they compare *tmp-file paths on disk*, plain identity/prefix — S3/S4
material, independent of the key): `cache.h:89` `TmpNameEqual` (used `cache.cpp:384`),
`cache.cpp:365` and `:662` (`StrNICmp` of tmp paths against the tmp root / tmp directory),
`:399, :406` (name against the found name / DOS name), `:667`.

Producers (complete for the core — every `DiskCache.` call in `src/*.cpp`):

| site | key |
|---|---|
| `fileswn5.cpp:787-795` (view/edit from archive) | `StrICpy(dcFileName, GetZIPArchive())` + `\` + `GetZIPPath()` + `\` + `f->Name` (+ `":0x%p"` when the listing has a byte-identical duplicate, `:836`) ; used at `:850, 890, 901, 949, 953` |
| `fileswn6.cpp:3192-3194` (execute from archive) | `StrICpy(dcFileName, GetZIPArchive())`, `SalPathAppend(GetZIPPath())`, `SalPathAppend(f->Name)` ; used at `:3225, 3266, 3273, 3325, 3329` |
| `fileswn2.cpp:1305-1306` (closing the archive) | `StrICpy(buf, GetZIPArchive()); DiskCache.FlushCache(buf);` |
| `fileswn9.cpp:1225-1226` (after packing edited files) | the same |
| `mainwnd4.cpp:830` | `"Usermenu %X"` (tick count) — no name |
| `zip.cpp:2510` | `"ViewFile %X"` — no name |
| `zip.cpp:3191, 3246, 3277, 3288, 5642` | plug-in supplied `uniqueFileName` / `fileNamesRoot`, passed through untouched |

Plug-in producers (they build their own keys, by the contract text in `spl_gen.h:2119-2172`:
"the name is compared case-sensitively; a plug-in that needs case-insensitive must convert all
names e.g. to lower case — see `ToLowerCase`"): `regedt/fs3.cpp:392` and
`undelete/fs2.cpp:1443` fold with `ToLowerCase`; `ftp` (`fs5.cpp:392`, `fs2.cpp:346-403`,
`ftp.cpp:414-1083`), `sftp` (`fs.cpp:958`, `sftp.cpp:540`), `demoplug` do not fold at all —
their servers are case-sensitive.

**"The same key" therefore means: byte-identical strings.** For archive keys that is: archive
path equal *after the producer's fold*, and path-in-archive + name **byte-exact** (case
preserved — archives legitimately hold `a.txt` and `A.txt`, and the code only disambiguates
byte-identical duplicates).

### 4.2 Can the comparators move to the three-way helper on unfolded keys? **No.**

- It would make the path inside the archive case-insensitive: `x.zip\a.txt` and `x.zip\A.txt`
  become one entry → the wrong file is served to the viewer.
- It would make plug-in keys case-insensitive, against the published contract; FTP/SFTP would
  serve `README` for `readme`.
- The key carries no marker of where the archive path ends, so a "fold only the first part"
  comparator cannot be written inside `cache.cpp`.
- `FlushCache`'s `strncmp` prefix would need `SalPathHasPrefixOrdinalCI` and different byte
  counts per element.

So `cache.cpp:431`, `:684` stay `strcmp` / `strncmp`. The research's line "the `cache.h`
comparators must move" is wrong: `cache.h:88` is dead and `cache.h:89` is not a key comparison.

### 4.3 What is actually wrong today, and what can be done at the producers

`StrICpy` folds UTF-8 bytes with the code-page table, so
- **false collision**: `ĥ.zip` and `Ĺ.zip` (C4 A5 / C4 B9 → the same bytes on CP1250) get one
  key prefix; a file with the same inner path can be served from the *other* archive's cached
  copy, and closing one archive flushes the other's files;
- **false miss**: `Č.zip` / `č.zip` spellings of one archive get different keys (a cache miss;
  or a flush that leaves the other spelling's copies — only when the same archive is open under
  two spellings).

The four producers must share one normaliser (one writes keys, two flush by prefix). Options:

| option | change | effect | cost / risk |
|---|---|---|---|
| **D0 — leave** | none; annotate the four `StrICpy` lines for the guard with the reason | both defects stay | none |
| **D1 — ASCII-only fold** | replace the four `StrICpy` by one new function that lower-cases `A`–`Z` only and copies other bytes unchanged | false collision **gone**; false miss unchanged (today's result for every non-ASCII letter anyway, since the byte fold never maps a UTF-8 case pair onto each other); ASCII paths byte-identical to today; byte length preserved, so `fileswn5.cpp:821` stays valid | needs a new ~6-line fold-to-buffer function (does not exist); very low risk |
| **D2 — true ordinal fold** | new helper: UTF-16 → OS upper-case table → UTF-8, proven `fold(a)==fold(b) ⇔ SalNameEqualOrdinalCI(a,b)` over the BMP | both defects gone | new helper + test; folded length can differ (7 BMP pairs) → `fileswn5.cpp:821` must use the folded prefix length; buffers `fileswn9.cpp:1224` (`MAX_PATH`) and `fileswn2.cpp:1241` must be sized; I did not verify which Windows mapping call reproduces `CompareStringOrdinal`'s table exactly |

Plug-in producers are not affected by any option: they key their own namespaces
(`fsname:…`), and no core code builds or flushes their keys.

### 4.4 Recommendation: **DO NOT CONVERT to the helpers** — they cannot express a folded key

Within S5: **D0** (annotate + record as deferred), unless the maintainer accepts a new small
function, in which case **D1** in one commit covering exactly `fileswn2.cpp:1305`,
`fileswn5.cpp:787`, `fileswn6.cpp:3192`, `fileswn9.cpp:1225` (risk: low). D2 belongs to a
follow-up item together with the two buffer defects of finding 6.

Invariant test (for D1/D2, 075 probe pattern, verbatim `GetNameIndex` + insert + `FlushCache`
loop): (1) every inserted key is found by `GetNameIndex`; (2) `FlushCache(fold(archive))`
removes exactly the keys produced for that archive and none of another archive — with the
fixtures `ĥ.zip`/`Ĺ.zip` (before: cross-flush; after: separate), `a.zip`/`A.ZIP` (same before
and after), `x.zip\a.txt` vs `x.zip\A.txt` (distinct before and after).

Performance: irrelevant. The fold runs once per view/execute/close; look-ups stay `strcmp`.

---

## 5. Summary table

| pair | verdict | sites | risk |
|---|---|---|---|
| A `SortNames` + `FindNameInArray` (CNames ×6) | CONVERT | `salamdr6.cpp:616, 618, 736` | low |
| B `CDirectorySizes` | CONVERT with A (dead code; or delete) | `salamdr6.cpp:1081` | none |
| C `ContainsString` + `AddStringToNames` + drag-and-drop list | CONVERT with A | `fileswn6.cpp:455`; comments `consts.h:2338, 2341` | low |
| D disk-cache keys | DO NOT CONVERT comparators; producers: leave (D0) or ASCII-only fold (D1, needs a new function) | `cache.cpp:431, 684` stay; producers `fileswn2.cpp:1305`, `fileswn5.cpp:787`, `fileswn6.cpp:3192`, `fileswn9.cpp:1225` | D0 none / D1 low |

A, B and C are one atomic commit. T5 is closed: nothing sorted is persisted or shared.

## 6. What I could not determine

- Nothing was compiled or executed: the mixed-validity cycle (finding 5) and the CP1250
  collision bytes are derived from the code and the code-page table, not measured.
- Whether any *shipped* plug-in still hands non-UTF-8 names to archive / FS panels (which
  decides how reachable finding 5 is outside the clipboard path).
- Which Windows call reproduces `CompareStringOrdinal`'s upper-case table for option D2.
- Timings in §1.7 are estimates from the 20–90 ns figure given in the brief.
