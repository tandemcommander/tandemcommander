# Implementation Plan: checksum lists (feature 117)

**Branch**: `117-checksum-lists` (from `116-ftp-passwords`, 47ad7fd6) | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)

| Stage | Content |
|---|---|
| S0 measure | Pre-change build preserved (`Debug_x64_pre117` = a copy of `Debug_x64` = HEAD 47ad7fd6, without `Intermediate` folders). Tools' output measured (coreutils 8.32 of Git for Windows, 7-Zip 22.01, Windows PowerShell 5.1; Total Commander from its `HISTORY.TXT`); the Windows primitives (`FindFirstFileW` / `GetFileAttributesExW` on `\\?\` paths with `.`, `..`, wildcards; `MultiByteToWideChar` strict on 5 code pages); which list variants coreutils and 7-Zip read (`research.md`) |
| S1 helper | `src/common/salcsumlist.h` (header-only, pure): `SalCslDetect`, `SalCslDecode` (whole-file decision, exact conversion, `SAL_CSL_BADCHAR`, marks at line starts dropped), `SalCslNameUsable`, `SalCslUnescapeName`, `SalCslBuildPath` (an absolute name only on the list's own root - review B1) |
| S2 plug-in | `src/plugins/checksum/dialogs.cpp`: `LoadFile` decodes (returns malloc'd WTF-8, callers `free`), `AnalyzeSourceFile` skips the GNU escape prefix for the hash checks, `LoadSourceFile` builds the path with `SalCslBuildPath`, refuses unusable names, looks up with `GetFileAttributesExW` (a folder is missing), `SetDispInfoText` shows WTF-8 and U+FFFD, `SaveHashes` writes md5/sha* with LF and no comment (binary mode), SFV unchanged; `wrappers.cpp`: `CGenericHashAlgo::ParseDigest` skips the escape prefix and unescapes the name |
| S3 tests | saltests `TestChecksumList117` (87 checks): detection of every form, exact conversion incl. a double-byte fallback and every single byte >= 0x80 of 18 code pages, marks, NUL, the name rule, the escape, paths |
| S4 probe | `probe/make_lists117.py` (fixtures + `expected117.json`), `probe/csumlist_probe.ps1` (13 lists + the round trip, `-Expect fixed/before`), `probe/m117_model.cpp` + `build_model.cmd` + `run_model.py` (offline model of the read path on the helper: 48 rows, 0 mismatches) |
| S5 gates | Debug + full Release builds (0 warnings), saltests, strict guard, BOM / CRLF; hostile re-read; records (fix-log with the proposed CLAUDE.md entry, CHANGELOG, NEXT-WORK) |

No plug-in interface change (107), no new string, no registry or configuration change, no
translation work. PRIVACY.md unchanged (no network, storage or credential change).
