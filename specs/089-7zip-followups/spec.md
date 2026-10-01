# Feature Specification: 7zip plug-in follow-ups — surrogate names, updating cleaned names, one RAR association

**Feature Branch**: `089-7zip-followups`
**Created**: 2026-10-01
**Status**: Draft
**Input**: `specs/NEXT-WORK.md` item 8, "found by the reviews and not fixed" (feature 087): (a) the 7zip plug-in converts names with strict UTF-8, not the house WTF-8; (b) adding to a 7z archive matches the *stored* names, so a file added into a folder whose name had to be cleaned becomes a second item; (c) on an upgraded configuration `rar` shares the plug-in's `7z` association record, so packing into a RAR archive from the panel is refused instead of going to WinRAR as on a fresh configuration.

## Clarifications

### Session 2026-10-01

The maintainer is away and asked for the recommended option at every decision.

- Q: Where is the surrogate-name conversion fixed — in the 7zip plug-in only, or for all plug-ins? → A: **In the shared plug-in converters**, so every plug-in gets it. The core has handled such names since feature 066; the plug-in helpers were left strict, which makes *any* plug-in fail on a path the core hands it when the path contains such a name. One fix in one header.
- Q: How do fresh and upgraded configurations become the same for RAR? → A: **The program lets a plug-in that registers a format for viewing take over an association whose external archiver can never list archives** (RAR's console since feature 084), instead of adding the extension to the plug-in's own record. The 7zip plug-in repairs a configuration already joined by a development build of feature 087.
- Q: Does any released configuration contain the joined record? → A: **No** — feature 087 is unreleased. The repair exists for configurations written by development builds.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — RAR behaves the same after an update as on a new installation (Priority: P1)

A user updates from 0.1.8. In *Archives Associations in Panels* the `rar;r##` row shows the 7-Zip plug-in as the viewer and *RAR (WinRAR)* as the packer — exactly what a new installation shows. With WinRAR installed, copying a file into an open RAR archive packs it with WinRAR; without WinRAR the program says the archiver is not available. The plug-in's own row stays `7z`.

**Why this priority**: every existing user is an "updated configuration"; without this they get a different, worse behaviour than new users, and a confusing duplicate claim in the configuration.

**Independent Test**: start the new build over a 0.1.8-shaped configuration, exit; the stored associations hold one `rar;r##` record with the plug-in as unpacker and RAR as packer, and a `7z` record of the plug-in.

**Acceptance Scenarios**:

1. **Given** a configuration saved by 0.1.8 (7zip plug-in configuration version 3, core record `rar;r##` with RAR as packer and unpacker), **When** the new version starts and saves, **Then** the `rar;r##` record has the 7zip plug-in as unpacker and RAR as packer; the plug-in's record is `7z` only.
2. **Given** a configuration written by a development build of feature 087 (plug-in record `7z;rar;r##`, version 4), **When** the new version starts and saves, **Then** the result is the same as in scenario 1.
3. **Given** a new installation, **Then** the result is the same as in scenario 1 (unchanged from feature 087).
4. **Given** the user removed `rar` from every record on purpose, **When** the program starts a second time, **Then** nothing is added again (the migration runs once).
5. **Given** a RAR archive, **When** it is opened in a panel, **Then** it lists and extracts as in feature 087.

### User Story 2 — Names with unpaired surrogates survive in every plug-in (Priority: P2)

A file whose name contains an unpaired UTF-16 surrogate (legal on NTFS, produced by some tools) is packed into a 7z archive, listed, and extracted with exactly the same name. A plug-in that receives the path of such a file from the program can open it.

**Independent Test**: unit tests prove the shared converters round-trip every UTF-16 string and agree byte for byte with the core's converters; a 7z archive holding a lone-surrogate name lists under that name and extracts to a file with that name.

**Acceptance Scenarios**:

1. **Given** a 7z archive with an item whose name contains a lone surrogate, **When** it is listed and extracted, **Then** the extracted file has the same name (not a replacement character).
2. **Given** a file with such a name on disk, **When** it is packed into a 7z archive, **Then** the archive stores the same name.
3. **Given** any text that is valid Unicode, **Then** the converters produce exactly what they produced before.
4. **Given** bytes that are neither UTF-8 nor a surrogate sequence, **Then** the decoder still fails (plug-ins rely on that to detect legacy text).

### User Story 3 — Adding into a folder whose name was cleaned replaces, not duplicates (Priority: P3)

A 7z archive made elsewhere holds a folder whose stored name is unsafe on Windows (for example `a:b`); the panel shows it cleaned (`a_b`, feature 087). The user copies a file into that folder that already exists there. The file is replaced after the usual overwrite question, instead of being stored a second time under the cleaned name.

**Independent Test**: an archive with `a:b/x.txt`; adding `x.txt` into the shown folder `a_b` asks to overwrite and leaves one `x.txt`.

**Acceptance Scenarios**:

1. **Given** an archive item stored as `a:b\x.txt` (shown as `a_b\x.txt`), **When** `x.txt` is added into `a_b`, **Then** the overwrite question appears and the archive holds one item for it afterwards.
2. **Given** an archive with ordinary names, **Then** adding, replacing and deleting behave exactly as before.

### Edge Cases

- A record whose unpacker is another plug-in already claims `rar`: untouched (the user's or that plug-in's choice).
- The core's `rar;r##` record was edited to `rar` only, or to more extensions: it is taken over as it is; extensions the plug-in asked for and no record holds are added to the taken-over record.
- No record holds `rar` at all (deleted by the user) on an upgraded configuration: the extension joins the plug-in own record, as an extension update always did (the general rule for all plug-ins is unchanged), once.
- An external archiver that *can* list but is not installed (7-Zip console for `arj`) is never taken over: "not installed" is not "can never list".
- Two archive items that clean to the same name: both stay; a file added under that name replaces the first match (the usual question), never crashes.
- A lone surrogate in an archive name next to characters that are cleaned (`:` and the like): both rules apply, bytes of the surrogate sequence are never split.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: When a plug-in registers extensions for viewing only on an existing installation, and an association record whose external archiver can never list archives claims any of them, the program MUST make the plug-in the viewer of that record and keep the record's packer; extensions not claimed by any record MUST be handled as before.
- **FR-002**: That rule MUST NOT apply to records whose viewer is a plug-in, nor to external archivers that can list (installed or not).
- **FR-003**: The 7zip plug-in MUST register RAR so that updated and new configurations end with the same associations, MUST repair a configuration in which RAR shares its own `7z` record, and MUST do both once (configuration version 5).
- **FR-004**: The shared plug-in text converters MUST encode every UTF-16 string (an unpaired surrogate as its 3-byte sequence) and MUST decode exactly valid UTF-8 plus those sequences; for valid Unicode their output MUST be byte-identical to before; every other malformed input MUST still fail.
- **FR-005**: The 7zip plug-in MUST use those converters for every name it passes between the engine and the program.
- **FR-006**: When updating a 7z archive, files MUST be matched against archive items by the names the panel shows (the cleaned names).
- **FR-007**: Listing, extracting, testing, packing and deleting in archives with ordinary names MUST behave as before (no regression of feature 087's probes).
- **FR-008**: Plug-in interface version stays 107; no change to the product version.

### Key Entities

- **Association record**: extensions + viewer (unpacker) + optional packer, in *Archives Associations in Panels*.
- **Archiver that can never list**: an external archiver with no listing command by design (RAR's console program).
- **Cleaned name**: the safe form of a name stored in an archive (feature 087).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Starting from a 0.1.8-shaped, a feature-087-development-shaped and an empty configuration, the stored associations for `rar` and `7z` are **identical** in all three.
- **SC-002**: A second start changes **0** association values.
- **SC-003**: The converters round-trip **100 %** of the test strings (valid text, astral characters, every kind of unpaired surrogate) and agree with the core's converters on every one; malformed inputs are rejected in **100 %** of cases.
- **SC-004**: Feature 087's engine probe and unit tests pass unchanged; Debug and Release builds succeed.
- **SC-005**: Adding an existing file into a cleaned-name folder leaves **1** item, not 2.

## Assumptions

- WinRAR's console program is the only external archiver without a listing command (feature 084).
- GUI confirmation of the associations page and of packing into RAR with WinRAR installed remains a step for a person; the stored configuration is checked by a probe.
