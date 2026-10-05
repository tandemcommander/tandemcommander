# Research: feature 110 - the ZIP plug-in's member-name matching

Measured on `build\tandemcommander\Debug_x64_pre110` (HEAD c34af19e, incremental build - no
change - then the binaries copied). Windows 11, ACP 1250, OEM 852, user locale 0x0405 (Czech).

## 1. Every member-name comparison of the ZIP plug-in

`rg "CompareString|lstrcmpi|StrICmp|_stricmp|_strnicmp|MemICmp|IsTheSamePath|strcmp" src/plugins/zip`,
every hit read. Names reach the plug-in's code as `ProcessName` output: UTF-8 (interface 104;
legacy OEM / ACP names converted, bit 11 names taken verbatim), `\` separated.

| site | what it decides | old comparison | verdict |
|---|---|---|---|
| `add.cpp CZipPack::MatchFiles` (exact match) | an existing member IS the added file/folder: overwrite question, member deleted | panel folder `CompareString(pathFlag)` + rest `CompareString(NORM_IGNORECASE)` on UTF-8 bytes, equal-byte-length guard | **the defect** - changed |
| `add.cpp CZipPack::MatchFiles` (Move, folder not added) | the folder exists in the archive - the source folder may be deleted | the same, as a prefix | changed (same rule) |
| `add.cpp` Unix branch | the added file takes the matched member's spelling | `strcpy` into the source-name buffer from `inZip + RootLen` | changed: covered folder length, buffer grows |
| `del.cpp CountFilesInRoot` | after F8: were all files of the panel folder deleted? then write an empty folder entry | `CompareString(NORM_IGNORECASE)` on `rootLen` bytes, also in a Unix ZIP; no length check | **defect** (see 3) - changed to the selection's test |
| `common.cpp CZipCommon::MatchFiles` + `BSearchName` + `CompareExtInfos` | which members an F8 / F5-out selection means | files: exact name (`_tcscmp`) + central-directory index; folders and the panel prefix: core byte fold (`StrICmp`, `MemICmp`), Unix case-sensitive | correct for files (measured, 2); folders follow the core's listing (`CSalamanderDirectory`, merged by the same byte fold) - unchanged by decision |
| `extract.cpp CZipUnpack::FindFile` | F3/F4 of one member | the member is found by INDEX; then a name check (`CompareString`) only confirms | unchanged: its linguistic folder test accepts every pair the byte-fold listing merges (computed: 0 pairs merged by the byte fold and kept apart by it) |
| `common.cpp:1160` (volume names), `common2.cpp:161`, `chicon.cpp`, `dialogs*.cpp`, `iosfxset.cpp`, `main.cpp` | disk paths, SFX settings, language files, volume sorting | - | not member names |

## 2. The old comparison, and every route on the build before

`probe/zip_collision_set.py` (`zip_collision_set_cp1250.txt`): `CompareStringA(LOCALE_USER_DEFAULT,
NORM_IGNORECASE)` reads the UTF-8 bytes as CP1250 text and compares linguistically (equal sort keys).
Over the BMP (one-character names `<c>.txt`): **21,925 pairs** one name for it, two for the file
system (275 two-byte, 19,760 three-byte, 1,890 of different byte length - kept apart only by the
length guard of the update matching); h-circumflex / L-acute (U+0139; with U+013A it is two names),
I-acute / Y-acute, z-caron / z-dot, U+4E5D / U+4E4D, Cyrillic em / o all one name. The other way:
**944 pairs** one name for the file system (ordinal case-insensitive) and two for it - every case
pair outside ASCII (C-caron / c-caron) and the 7 case pairs of different UTF-8 length. Every pair of
printable ASCII characters: the old comparison equals the ASCII fold (0 differences).

`probe/zipname_probe.ps1` + `zipfix.py` (own ZIP writer: UTF-8 names with bit 11, OEM names without,
raw non-UTF-8 bytes with bit 11, FAT / Unix host; own central-directory reader with CRC check), hidden
desktop. `probe/zipname_result_pre110.txt` (the final probe; the first measurement run had two rows
NOT DRIVEN by a probe defect, re-run with the same result, see `fix-log.md`):

| rows | build before |
|---|---|
| F5 `ĥ.txt` into `{Ĺ.txt}`, also `Í`/`Ý`, `ž`/`ż`, CJK, Cyrillic, sub-folder, archive folder, OEM-named ZIP (9 rows) | one overwrite question, *Yes*: `Ĺ.txt` **gone**, replaced by `ĥ.txt` |
| F5 `ĥ.txt` into `{ĥ.txt, Ĺ.txt}` | two questions, both members deleted, one added: `Ĺ.txt` **gone** |
| the same, *Yes* then *Skip* | the skip made the operation add nothing, so nothing was deleted (archive unchanged - the source was not packed although *Yes* was given for its own member) |
| Unix ZIP, F5 `ĥ.txt` into `{Ĺ.txt}` | question; the added file renamed to `Ĺ.txt` (the matched member's spelling), which does not exist on disk: "Cannot open or create file" |
| merged folders: F5 `x.txt` into `ĥ/` of `{ĥ/a.txt, Ĺ/x.txt}` | question; `Ĺ/x.txt` replaced by `ĥ/x.txt` (nothing lost - moved to the other folder) |
| F5 `č.txt` into `{Č.txt}` (UTF-8, OEM), U+2C65 into U+023A | no question, two members that Windows folds onto one |
| F4 `ĥ.txt` only of `{ĥ.txt, Ĺ.txt}` (`f_hL1`), `Ĺ.txt` only (`f_hL2`) | two questions on Update; the OTHER member **gone** |
| F4 `d/Ĺ.txt`, `ĥ.txt`, `Ĺ.txt` (108 review `split_zip`) | three copies, the third in a new `SAL` folder, two calls, four questions: `ĥ.txt` **gone** |
| F4 both of `{ĥ.txt, Ĺ.txt}`, *Yes* then *Skip* (`f_skip`) | the second question paired `Ĺ.txt` with `ĥ.txt`'s copy: the edited `ĥ.txt` **gone**, `Ĺ.txt` stored **twice** (old content and edit) |
| Unix ZIP, F5 `Ⱥ.txt` (2 bytes) into `{ⱥ.txt}` (3 bytes) (`c_unixlen`) | no question, two members Windows folds onto one |
| Unix ZIP `{Dir/a.txt, DIR/b.txt}`: in `Dir`, F8 `a.txt` (`d_unixDir`) | `Dir` **disappears** (no empty folder entry written) |
| F8 `ĥ.txt` / F5 `ĥ.txt` out of `{ĥ.txt, Ĺ.txt}` | correct (only `ĥ.txt`) |
| ordinary: `x.txt` into `{x.txt, y.txt}` Yes / Skip, `a.txt` into `{A.txt}` DOS and Unix, `č.txt` into `{č.txt}` UTF-8 and OEM, NFC into NFD, a raw-byte member | as expected |

Totals on the build before: 10 PASS / 21 FAIL (31 rows).

## 3. `CountFilesInRoot`

After F8 inside an archive folder, `DeleteFiles` compares the number of deleted files with the number
of files "in the folder" and, when equal, writes an empty entry for the folder so it does not vanish.
The count used `CompareString(NORM_IGNORECASE)` - case-insensitive also in a Unix ZIP, linguistic,
and over `rootLen` bytes of a possibly shorter name - while the selection (`CZipCommon::MatchFiles`)
uses `Unix ? memcmp : MemICmp` with a length check. Measured: `d_unixDir` above. Now the count uses
exactly the selection's test.

## 4. Decisions on the identity rule

- 092's helpers live in `salunicode.cpp`, which the ZIP project cannot compile (its sources find
  `precomp.h` beside themselves; 086 and 094 made header-only helpers for the same reason). The
  header carries its own copy of the core's WTF-8 decoder (`SalWtf8ToWBytes`); saltests asserts
  parity with `SalNameEqualOrdinalCI` / `SalPathHasPrefixOrdinalCI` by brute force over a hostile
  alphabet (case pairs, the different-length pair, sharp s / capital sharp s, dotless i, Kelvin, an
  emoji, lone and paired surrogates, a combining mark, two code-page bytes).
- Legacy text keeps `CompareStringA` (not the core's byte fold): it is what the plug-in did.
- The prefix (panel folder) is measured on the member's own bytes (`*pathBytes`), and the Unix
  branch copies the member's spelling from there.
- Folder-pair merges of the core's listing are not repaired here (Clarifications).
