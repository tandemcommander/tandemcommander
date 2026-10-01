# Data Model: Working Archivers Only (feature 084)

Entities from the spec's *Key Entities*, mapped onto the existing structures.
Registry paths are relative to `HKCU\Software\Tandem Commander\0.1\Packers &
Unpackers\`. Source references are listed in [research.md](research.md).

## 1. Archiver definition (built-in table row)

One row per supported external archiver. It is compiled into the program, and
only its executable path is stored.

| Field | Meaning | After 084 |
|---|---|---|
| index | position in `ArchiverConfig`; also selects the browse row, the modify row, the default custom entry and the Autoconfiguration row | 0 = 7-Zip, 1 = RAR |
| UID | stable identity stored as `Predefined Packers\<n>\Packer UID` | 7-Zip = **13** (new), RAR = **2** (kept) |
| variable | the `$(…Executable)` name used in commands | `SevenZipExecutable` (new), `Rar32bitExecutable` (kept, so stored commands stay valid) |
| display title | shown in the dialogs | "7-Zip", "RAR (WinRAR)" (new string IDs) |
| executable path | stored in `Predefined Packers\<n>\Packer Executable` | set by Autoconfiguration or the user |
| browse operations | list / extract-selected / extract-one | 7-Zip: all three, using the `-slt` parser (§5). RAR: none (the plug-in browses) |
| modify operations | add / move / delete | 7-Zip: none. RAR: add, move, delete |
| UTF-8 I/O | list file and pipe output are UTF-8 | true for both rows (R7). *As built (R7a)*: list files are UTF-16LE with BOM (`$(ListUnicodeFullName)`); only the 7-Zip listing on the pipe is UTF-8 |
| error table | exit code to message | 7-Zip: 1, 2, 7, 8, 255. RAR: 1–12 and 255 |
| available | runtime only, never stored: the executable exists | §6 |

Removed rows: JAR 1.02 Win32/DOS, RAR 2.50 DOS, ARJ 2.60 DOS / 3.00c Win32,
LHA 2.55 DOS, UC2 2r3 DOS, ACE 1.2b Win32/DOS, PKZIP 2.50 Win32, PKZIP/PKUNZIP
2.04g DOS. Their UIDs are retired and never reused.

## 2. Archive association (format record)

Stored in `Archive Association\<n>`: `Extension List`, `Packer Supported`,
`Packer Index`, `Unpacker Index`.

| Field | Rule |
|---|---|
| Extension List | `;`-separated, `#` matches a digit (e.g. `r##`) |
| Unpacker Index | ≥ 0 means an archiver definition index; < 0 means plug-in `-(i+1)` |
| Packer Index | same encoding; meaningful only while Packer Supported is true |

**Validation**:
- A record whose unpacker is a non-existent archiver index is invalid and is
  deleted by migration (§7) or by `CheckData`.
- A record whose *external* unpacker is not *available*, or whose archiver row
  has no browse operations (RAR after 084), is skipped when the runtime
  extension table is built. It stays stored (FR-017).
- A record whose *external* packer is not available is built without packing.

**Defaults after 084** (fresh configuration):

| Extensions | Unpacker | Packer |
|---|---|---|
| `zip;pk3;jar` | zip plug-in | zip plug-in |
| `7z` | 7zip plug-in | 7zip plug-in |
| tar family, `cab`, disc images | their plug-ins (unchanged) | unchanged |
| `rar;r##` | stored as RAR index 1 (not browsable, so skipped). The 7zip plug-in takes it over once the 7-Zip upgrade feature is in (R3) | RAR (index 1), while available |
| `arj`, `lzh;lha` (as built; `a##` was not added, contract M3) | 7-Zip (index 0), while available | — |

## 3. Custom packer / unpacker entry

Stored in `Custom Packers\<n>` / `Custom Unpackers\<n>`.

| Field | Note |
|---|---|
| Type | 0 = external, < 0 = plug-in |
| Title, Ext | shown in the Pack / Unpack dialogs |
| commands / arguments | may contain `$(…Executable)` variables and, for custom entries, DOS variables (still expanded, FR-008) |
| Support Long Names, Need ANSI List | kept for custom entries, behaviour unchanged |

**Classification for migration and hiding**:
- **Refers to a removed archiver**: its command or arguments contain a removed
  `$(…Executable)` variable (case-insensitive), or its arguments equal a
  former floppy-volume default. Such entries are removed by migration.
- **Refers to a kept archiver**: it uses `$(Rar32bitExecutable)` or
  `$(SevenZipExecutable)`. It is hidden in the Pack / Unpack dialogs while that
  archiver is not available (FR-017).
- **Own path**: no archiver variable at all. It is always kept and always
  listed.

**Defaults after 084**:
- Packers: the plug-in packers, plus "RAR (WinRAR)", which is hidden while RAR
  is unavailable.
- Unpackers: the plug-in unpackers (incl. "7-Zip (Plugin)" for `*.rar` once
  RAR is exposed), plus "7-Zip" for the 7-Zip default extensions, which is
  hidden while 7-Zip is unavailable.

## 4. External run (transient)

One launch of an archiver.

| Field | Note |
|---|---|
| command line | UTF-8, expanded from the table row or the custom entry |
| initial directory | from the row (`$(ArchivePath)`, `$(TargetPath)`, …) |
| mode | *listing* (hidden console, stdout and stderr piped) or *execute* (console minimized, restored after 15 s) |
| job | job object, kill-on-close |
| state | `Running` → `Exited(code)` \| `Cancelled` \| `LaunchFailed(error)` |

State transitions:

```
Running --process exits--> Exited(code) --code==0--> success
                                         --code!=0--> error via table (or "returned N")
Running --user Cancel--> Cancelled (job terminated; unpack: temporary folder removed, nothing reported;
                                   pack/delete: IDS_PACKERR_CANCELLED_ARC — contract C3 amendment)
(start) --CreateProcess fails--> LaunchFailed (message names the archiver exe)
```

## 5. 7-Zip listing record

This is the output of the pure `-slt` parser (`src/common/sal7zlist.*`). The
grammar is in [contracts/7z-slt-listing.md](contracts/7z-slt-listing.md).

| Field | From | Note |
|---|---|---|
| path | `Path =` | UTF-8; `\` or `/` both accepted |
| is directory | `Folder = +`, or `D` in `Attributes` | |
| size | `Size =` | empty means 0 |
| packed size | `Packed Size =` | may be empty (solid blocks) |
| modified | `Modified =` | `YYYY-MM-DD hh:mm:ss[.f…]`; may be absent |
| attributes | `Attributes =` | `D`, `R`, `H`, `S`, `A` letters, before any space |
| encrypted | `Encrypted = +` | informational |

## 6. Availability (runtime)

A per-archiver boolean: the configured executable path is non-empty and the
file exists.

It is recomputed at three points:
1. configuration load;
2. after Archivers Autoconfiguration applies results;
3. after the configuration dialog is closed with OK.

Recomputing it also rebuilds the runtime extension table. It is never stored
and never checked per file.

## 7. Migration rule set (config version 106)

The rules are pure data plus pure functions in `src/common/salarcmig.*`:

- **removed variables**: `Jar32bitExecutable`, `Jar16bitExecutable`,
  `Rar16bitExecutable`, `Arj32bitExecutable`, `Arj16bitExecutable`,
  `Ace32bitExecutable`, `Ace16bitExecutable`, `Lha16bitExecutable`,
  `UC216bitExecutable`, `Zip32bitExecutable`, `Zip16bitExecutable`,
  `Unzip16bitExecutable`;
- **floppy-volume argument set**: the exact former default argument strings
  containing `-v1440` / `-pav1440`;
- **old→new index map**: `1→1`; `0, 2–11 → removed`;
- **7-Zip default extensions** to add when unclaimed.

The full behaviour is in
[contracts/config-migration-106.md](contracts/config-migration-106.md).
