# Data model - feature 321

## Listing entry (what `CSalamanderDirectory::AddFile` / `AddDir` receive)

| Field | Meaning | Rule |
|---|---|---|
| `path` | folder part relative to the listed object, or `NULL` (FS plug-ins; archive root) | with a folder part: at most `MAX_PATH - 5` bytes |
| `Name`, `NameLen` | UTF-8 name, its byte length | see below |
| file / folder | `AddFile` / `AddDir` | |

Acceptance (`src/common/sallistingname.h`):

| Folder part | File | Folder |
|---|---|---|
| given (`path != NULL`) | `pathLen <= MAX_PATH - 5` and (`NameLen <= MAX_PATH - 5` or (`NameLen < SAL_FIND_NAME_U8` and at most 255 UTF-16 units)) - unchanged (222) | `pathLen <= MAX_PATH - 5` and `NameLen <= MAX_PATH - 5` - unchanged |
| none (`path == NULL`) | `NameLen < SAL_FIND_NAME_U8` (new, 321) | `NameLen < SAL_FIND_NAME_U8` (new, 321) |

`SAL_FIND_NAME_U8` = 3 * MAX_PATH = 780 bytes: the size of the panel's name buffers.

## Tar member name source (`SCommonHeader`, `src/plugins/tar/tar.h`)

| Flag | Set when | Effect |
|---|---|---|
| `NameFromPax` (306) | a PAX `path` became the name | `SalPaxNameUsableU8(..., Listing)` (308) |
| `NameFromGnu` (321) | a GNU `L` header supplied the name | the same |
| `NameRefused` (308) | the check failed in this pass | `Ignored`; an extraction asked for it reports and fails |

All reset in `SCommonHeader::Initialize` (start of every `ReadArchiveHeader`).

## Pass over the archive (`CArchive::Listing`, 308)

| Pass | `Listing` | Refused when |
|---|---|---|
| `ListArchive` | TRUE | a component over 255 UTF-16 units, a folder part (+ .deb prefix) over `MAX_PATH - 5` bytes, a folder's own name over `MAX_PATH - 5` bytes **in a folder part or under the prefix** (321: a top-level folder name is not byte-bounded) |
| `UnpackOneFile`, `DoUnpackArchive` (selection, whole archive) | FALSE | a component over 255 UTF-16 units only |
