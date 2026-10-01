# Archive Subsystem Inventory (feature 084)

What handles which archive format in Tandem Commander after feature 084, how a
panel action reaches an external program, and why each format and program of
0.1.8 was kept, removed or added (spec US5, FR-014, SC-006). Cross-checked
against the source by `probe/inventory_check.py`.

## 1. How a panel action reaches an archiver

| User action | Entry point | Pack function | Plug-in route | External route |
|---|---|---|---|---|
| Enter on an archive | `CFilesWindow::ChangePathToArchive` (`fileswn2.cpp`) | `PackList` (`pack1.cpp`) | `ListArchive` | `PackRunArchiver`, listing mode, then `ListParser` (`Pack7zList`) |
| F5 out of an archive | `UnpackZIPArchive` (`fileswn7.cpp`) | `PackUncompress` → `PackUniversalUncompress` | `UnpackArchive` | `PackExecute` → `PackRunArchiver` |
| F3 / Enter on a file inside | `ViewFile` / `ExecuteFromArchive` | `PackUnpackOneFile` | `UnpackOneFile` | as above |
| F5 into / delete in an archive | `FilesAction`, `DragDropToArcOrFS`, `UnpackZIPArchive(delete)` | `PackCompress` / `PackDelFromArc` (`pack2.cpp`) | `PackToArchive` / `DeleteFromArchive` | as above |
| Alt+F5 Pack / Alt+F9 Unpack | `CFilesWindow::Pack` / `Unpack` | `CPackerConfig::ExecutePacker` / `CUnpackerConfig::ExecuteUnpacker` (`packers.cpp`) | plug-in custom pack/unpack | `PackUniversalCompress` / `PackUniversalUncompress` |

Component roles:

- **Plug-ins** (`zip`, `7zip`, `tar`, `uncab`, `uniso`, all on in `plugins.cfg`)
  handle their formats in-process.
- **External archivers** are third-party command-line programs the user
  installs. After 084 there are two archiver rows: index 0 = **7-Zip console**,
  index 1 = **RAR (WinRAR console)**.
  - They are started **directly**, in a kill-on-close job object, behind a wait
    window with **Cancel**. The `salspawn.exe` helper is gone; no build ever
    shipped it.
  - Names travel as UTF-16 list files (`$(ListUnicodeFullName)`) and as UTF-8
    listings.
- **Custom packers/unpackers** are the Alt+F5 / Alt+F9 entries. Defaults: "RAR
  (WinRAR)" packer and "7-Zip" unpacker. The user may add any program.
- **Associations** ("Archive Association" records) map extensions to the
  unpacker and packer.
- **Availability**: an external archiver's entries and formats are offered
  only while its program is found (FR-017), via `RefreshAvailability`,
  `CanBrowse` and `CanPack`.

## 2. Formats

Handlers are given for a clean installation, then with 7-Zip installed and with
WinRAR installed. "—" means the file is an ordinary file.

| Extension(s) | 0.1.8 handler | 084 clean install | + 7-Zip installed | + WinRAR installed | Status | Reason |
|---|---|---|---|---|---|---|
| zip, pk3, jar | zip plug-in | zip plug-in | same | same | kept | in-process, maintained |
| 7z | 7zip plug-in | 7zip plug-in | same | same | kept | in-process, maintained |
| tar, tgz, tbz, taz, gz, bz, bz2, z, rpm, cpio, deb | tar plug-in | tar plug-in | same | same | kept | in-process |
| cab | uncab plug-in | uncab plug-in | same | same | kept | in-process |
| iso, isz, nrg, bin, img, pdi, cdi, cif, ncd, c2d, mdf, dmg | uniso plug-in | uniso plug-in | same | same | kept | in-process |
| rar, r## | external RAR 2.50 Win32 via the helper: **never worked** | — until the 7-Zip upgrade feature; then the **7zip plug-in** (S7) | same | browse: 7zip plug-in (S7); pack: **RAR (WinRAR)** | kept, re-routed | the helper was never shipped; RAR is read by the shipped 7-Zip engine once it is upgraded to 25.x (R3) |
| arj | ARJ 3.00c Win32 via the helper: never worked | — | **7-Zip console** (browse, unpack) | — | kept, new handler | 7-Zip reads ARJ; ARJ itself is long discontinued |
| a## (ARJ volumes) | ARJ 3.00c Win32 | — | — | — | **removed** | multi-volume ARJ through 7-Zip has not been verified |
| lzh, lha | LHA 2.55 MS-DOS: cannot run on 64-bit Windows | — | **7-Zip console** (browse, unpack) | — | kept, new handler | 7-Zip reads LZH; `lha` added as the common alias |
| j | JAR 1.02 Win32 | — | — | — | **removed** | JAR (ARJ Software, 1990s) is discontinued; no maintained reader |
| uc2 | UC2 2r3 MS-DOS | — | — | — | **removed** | 16-bit only; cannot run on 64-bit Windows |
| ace, c## | ACE 1.2b Win32 | — | — | — | **removed** | WinACE is discontinued; its extractor (unacev2) had a widely exploited path-traversal defect (CVE-2018-20250) |

Plug-ins that are **off** in `plugins.cfg` and so not part of the table:
`unrar` (rar; superseded by the 7zip plug-in route, R3), `unchm`, `unmime`,
`unole`.

**Open maintainer decision (research R5)**: after the 7-Zip upgrade feature,
the shipped engine also reads ARJ and LZH. The 7zip plug-in could then handle
them without the user installing 7-Zip, which would make the console entry
nearly redundant. Clarification Q2 chose the console entry for 084.

## 3. Programs

| Program (0.1.8 name) | Platform | 0.1.8 role | Status in 084 | Reason |
|---|---|---|---|---|
| JAR 1.02 | Win32 | pack/unpack `j` | removed | discontinued (1990s), no maintained source |
| JAR 1.02 | MS-DOS | pack/unpack `j` | removed | 16-bit |
| RAR 2.50 (WinRAR console) | Win32 | pack/unpack `rar` | **kept as "RAR (WinRAR)"**, packing only, UTF-16 list, codes 9–12 | maintained (RARLAB); creating RAR needs it |
| RAR 2.50 | MS-DOS | pack/unpack `rar` | removed | 16-bit |
| ARJ 2.60 | MS-DOS | pack/unpack `arj` | removed | 16-bit |
| ARJ 3.00c | Win32 | pack/unpack `arj` | removed | discontinued; 7-Zip reads ARJ |
| LHA 2.55 | MS-DOS | pack/unpack `lzh` | removed | 16-bit; 7-Zip reads LZH |
| UC2 2r3 PRO | MS-DOS | pack/unpack `uc2` | removed | 16-bit; format dead |
| PKZIP 2.50 | Win32 | pack/unpack `zip` (alternative) | removed | the zip plug-in handles ZIP in-process |
| PKZIP/PKUNZIP 2.04g | MS-DOS | pack/unpack `zip` (alternative) | removed | 16-bit |
| ACE 1.2b | Win32 | pack/unpack `ace` | removed | discontinued; unsafe extractor |
| ACE 1.2b | MS-DOS | pack/unpack `ace` | removed | 16-bit |
| **7-Zip console (7z.exe)** | Win32/x64 | — | **added**, browse and unpack only | maintained; reads the formats no plug-in reads |
| `salspawn.exe` (helper) | Win32/x64 | started every external archiver | **removed** | never shipped in any release; replaced by the direct launch |

**Versions (final review #3).** Tested: 7-Zip **22.01** (x64, the version on
the development machine), with every fixture in `probe/fixtures/`. WinRAR was
**not run** (not installed); the RAR command line follows RARLAB's documented
switches only. No minimum version is claimed for either program (FR-003's
version clause is open).

## 4. Default external entries after 084

| Kind | Title | Command | Arguments | Offered when |
|---|---|---|---|---|
| packer (Alt+F5) | RAR (WinRAR) | `$(Rar32bitExecutable)` | `a -scul -idq -y "$(ArchiveFullName)" @"$(ListUnicodeFullName)"` (move: `m …`) | WinRAR's `Rar.exe` is found |
| unpacker (Alt+F9) | 7-Zip | `$(SevenZipExecutable)` | `x -y -sccUTF-8 -scsUTF-16LE "$(ArchiveFullName)" -o"$(TargetPath)" @"$(ListUnicodeFullName)"` (extracts into the temporary folder; the move to the target asks before overwriting) | `7z.exe` is found |

Panel rows (`pack1.cpp` `PackBrowseTable`, `pack2.cpp` `PackModifyTable`):

| Row | List | Extract selected | Extract one | Add / Move / Delete |
|---|---|---|---|---|
| 7-Zip | `l -slt -ba -sccUTF-8 -scsUTF-8 -- "<arc>"` → `Pack7zList` | `x -y … -o"<target>" @<UTF-16 list>` | `e -y … -o"<target>" -- "<name>"` | — |
| RAR | — (7zip plug-in) | — | — | `a/m/d -scul -idq -y … @<UTF-16 list>` |

## 5. Where the decisions are recorded

- Spec, clarifications Q1–Q4: `spec.md`.
- RAR route and licence: `research.md` R3, R4.
- 7-Zip console: research R5.
- List-file encoding: research R7a.
- Migration: `contracts/config-migration-106.md`.
- Launch: `contracts/archiver-launch.md`.
