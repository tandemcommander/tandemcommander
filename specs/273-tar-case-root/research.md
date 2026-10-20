# Research - 273-tar-case-root

## R1 Where to fix: the core or the TAR plug-in

- **Decision**: the core re-spells the path inside the archive after a successful path change.
- **Rationale**: `ChangePathToArchive` (`src/fileswn2.cpp`) is the only place that sets the path
  (`SetZIPPath`; the other call resets it to ""). Every route into an archive folder - command
  line, Change Directory, hot path, history, Enter, `..`, refresh - passes through it. The path
  reaches every archive plug-in as `archiveRoot` (UnpackArchive, UnpackOneFile, PackToArchive,
  DeleteFromArchive) and the user sees it in the directory line and history. One fix gives every
  plug-in (TAR measured; UnCAB, UnISO, 7-Zip and ZIP packing by reading) the listing's names.
- **Alternatives considered**: TAR maps `archiveRoot` to its own listing's spelling - fixes TAR
  only, needs the plug-in to re-read or keep its listing, leaves the panel showing a name the
  archive does not hold. Rejected.

## R2 How to find the listing's spelling

- **Decision**: walk the components of the stored path through the listing, choosing in each
  folder the **first** sub-folder that the folder's own comparison (`SalDirStrCmpEx`) takes as
  equal - the exact rule of `CSalamanderDirectory::GetFiles` / `GetDirs` - and copy that folder's
  name bytes.
- **Rationale**: the re-spelled path then names the very folder the panel lists (same equality
  class, same first match), whether the listing is case-sensitive (identity) or not.
- **Length**: `StrICmpEx` folds byte by byte and requires equal lengths, `StrCmpEx` is exact, so the
  re-spelled path has the typed path's length. The rule still checks the output size and reports
  "too long" - the caller then keeps the typed path (CLAUDE.md: never cut a path).
- **Alternatives considered**: comparing by `SalNameEqualOrdinalCI` - could pick a different folder
  than the listing's lookup (feature 252: the two rules differ). Rejected.

## R3 Where in `ChangePathToArchive`

- **Decision**: right after the loop that shortens the path until `GetArchiveDirFiles() != NULL`,
  before the comparisons with the previous path and `CommonRefresh`.
- **Rationale**: at that point the path is known to exist in the listing; the later comparisons use
  `SalDirStrCmp` (the listing's rule) and are unaffected by the spelling; `CommonRefresh` then
  shows and the history records the archive's spelling. The early return "the new path matches the
  current one" keeps the current (already re-spelled) path.
- The tail cut off by the shortening (the name to focus) is not re-spelled (spec *Clarifications*):
  the focus lookup ignores case already.

## R4 Testing

- `saltests`: the rule over a fake tree with a case-insensitive and a case-sensitive comparator
  (first match among twins, deep path, missing and empty components, leading / trailing
  backslash, output too small, root).
- Probe `probe/arccase273_probe.ps1`: TAR / 7z COPY (`DOCS`), DEEP (`dOCS\SUB`), TWINS (folders Docs
  and DOCS opened as `DOCS`): panel path read from Change Directory, Select All, Copy, target
  checked with contents. Before: TAR-COPY / TAR-DEEP empty target. Negative control after: the
  same probe on a build without the call must fail TAR-COPY.
- Regression: 252's `arc252_probe.ps1` 16 / 0.
