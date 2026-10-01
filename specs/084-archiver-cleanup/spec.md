# Feature Specification: Working Archivers Only

**Feature Branch**: `084-archiver-cleanup`
**Created**: 2026-10-01
**Status**: Draft
**Input**: User description: "Nova funkce proveri jakym zpusobem funguje system pro archivaci balicku - predevsim jak jsou pouzity a volany jednotlive archivacni programy, zdali je nutne podporvat tolik formatu, resp. jiz neexistujicich utilitek, formatu, atd. Zaroven pri pouziti asi externich programu stejne Tandem Commander napise chybu pri hledani salspawn.exe programu. V pop up okne se objevuji texty jako DOS verze atd. Cilem je mit funkcni system pro archivaci / dearchivaci souboru pouze s funkcnimi a podporovanymi programy."

(English: review how the archive pack/unpack system works — above all how the
individual archiver programs are used and invoked — and whether it needs to
support so many formats, including utilities and formats that no longer exist.
When an external program is used, Tandem Commander reports an error looking for
`salspawn.exe`, and the dialogs show texts such as "DOS version". The goal is a
working pack/unpack system offering only working, supported programs.)

## Context — what the initial review found

These are the facts this specification is built on. They were established by
reading the current source and build output (2026-10-01), and the planning
phase must re-verify them.

1. **Every external archiver fails, whatever it is.** The product never calls
   an external archiver directly. It always starts a helper program,
   `utils\salspawn.exe`, and the helper starts the archiver. A release build
   never produces that helper: it is built only in a separate, rarely used
   "utilities" configuration, and its output does not land in `utils\` even
   then. The installer packages only what the build produces, so no
   Tandem Commander release has ever contained the helper. The result is the
   error the user reported. Its text also points the user to *Archivers
   Autoconfiguration*, which cannot fix it.
2. **The archiver list is from the 1990s.** The product knows 12 external
   archiver programs. **Seven are 16-bit MS-DOS programs** (ARJ 2.60, LHA 2.55,
   UC2 2r3, JAR 1.02 DOS, RAR 2.50 DOS, PKZIP/PKUNZIP 2.04g, ACE 1.2b DOS).
   64-bit Windows cannot run 16-bit programs at all, and Tandem Commander
   supports only 64-bit Windows 11. The other five are Win32 builds of JAR
   1.02, RAR 2.50, ARJ 3.00c, ACE 1.2b and PKZIP 2.50. Most of those products
   are discontinued. The ACE format in particular is abandoned after a widely
   exploited 2018 vulnerability in its extractor. Several default entries
   create "1.44MB volumes", i.e. floppy disks.
3. **The DOS texts are visible to every user.** The pack and unpack dialogs,
   the configuration pages and the menu of the *Archivers Autoconfiguration*
   search offer entries such as "ARJ (External DOS, tested with v2.60)" or
   "MS-DOS UC2 executable". The configuration also exposes "DOS name" variables
   that exist only for those programs.
4. **Plug-ins already cover the common formats.** The plug-ins enabled by
   default handle ZIP (also JAR/PK3), 7z, TAR and its compressed variants, CAB
   and disc images. The **RAR** plug-in is disabled because its decoding
   library is not shipped. So the most common format that is not built in,
   RAR, falls through to the external-program path from finding 1, and that
   path never works.

## Clarifications

### Session 2026-10-01

- Q: When an archiver is removed from the defaults, is its built-in panel
  listing logic removed too? → A: Yes. The panel readers for every removed
  archiver (JAR, ACE, ARJ, PKZIP, LHA, UC2 and all DOS versions) are removed.
  Panel browsing of those formats remains only where the 7-Zip entry takes
  over.
- Q: What does the new 7-Zip console entry do by default? → A: It browses and
  unpacks formats that no default-enabled plug-in handles (ARJ, LZH and others
  7-Zip reads). It has no default packer entry.
- Q: If WinRAR or 7-Zip is not installed, does its entry still appear in the
  Pack / Unpack dialogs? → A: No. A default external-archiver entry is offered
  only when its program was found, either by *Archivers Autoconfiguration* or
  through a configured path that exists. Otherwise it is hidden.
- Q: On upgrade, what happens to a user-created or user-edited entry that
  refers to a removed archiver? → A: It is removed, like an untouched default,
  whether or not the user edited it. Custom entries that call a program by
  their own path are kept.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Opening a RAR archive works (Priority: P1)

A user receives a `.rar` file and presses Enter on it, or chooses to unpack it,
expecting to see its contents or have the files extracted like any ZIP file.
Today the user gets an error about a missing `salspawn.exe` that they cannot
fix.

**Why this priority**: It is the defect the user reported and the most common
archive format the product does not handle internally. Every user who receives
a RAR archive hits it.

**Independent Test**: On a clean installation, open, browse and unpack a RAR
archive (single volume, multi-volume, with non-ASCII names). Test it both with
and without third-party archiving software installed.

**Acceptance Scenarios**:

1. **Given** a clean installation with no third-party archiving software and a
   valid `.rar` archive (RAR 4 or RAR 5 format), **When** the user opens it in
   the panel, **Then** its contents are listed. No error mentions a helper
   program or an internal component.
2. **Given** the RAR handling is available, **When** the user unpacks selected
   files from a RAR archive, **Then** the files appear in the target directory
   with their correct names, including names with characters outside the
   system code page.
3. **Given** a clean installation without WinRAR, **When** the user tries to
   *create* a RAR archive, **Then** RAR is not offered as a packer. The RAR
   packer entry appears once WinRAR's console program is found (FR-017).
4. **Given** an encrypted or damaged RAR archive, **When** the user opens or
   extracts it, **Then** the password is asked for, or the damage is reported
   in plain terms. Damaged data is never presented as a successful extraction.

**Decision (2026-10-01)**: RAR archives MUST open out of the box. Listing and
extracting work on a clean installation with nothing else installed. Planning
chooses the means, e.g. enabling the RAR plug-in with a redistributable
decoder, or a component built into Windows. *Creating* RAR archives still
requires the user's own WinRAR (RAR is a proprietary format).

---

### User Story 2 - External archivers start reliably (Priority: P1)

A user who has a supported external archiver installed (for example WinRAR's
console `rar.exe`) and has configured it can pack and unpack with it. The
program actually runs, its output is read, and its errors are reported in
plain terms.

**Why this priority**: Without it, every external-archiver entry in the
product is dead, whichever archivers are kept. User Stories 1 and 3 depend on
it.

**Independent Test**: Configure a supported external archiver, then pack files
into a new archive, list it, unpack one file, unpack all files, and pack with
"move" (delete originals). Repeat with an installation path and archive path
that contain non-ASCII characters and spaces.

**Acceptance Scenarios**:

1. **Given** a supported external archiver is configured, **When** the user
   packs, lists or unpacks, **Then** the operation completes. No message refers
   to `salspawn.exe` or another missing helper.
2. **Given** the configured archiver disappears after it was offered (e.g. it
   is uninstalled while Tandem Commander runs), **When** the user starts an
   operation, **Then** the message names the missing archiver and offers a way
   to fix the configuration. It does not suggest a step that cannot help.
3. **Given** the archiver exits with an error (e.g. a corrupt archive or a
   wrong password), **When** the operation ends, **Then** the user sees the
   archiver's error described in plain terms, and no files the operation did
   not finish are presented as complete.
4. **Given** a long-running pack operation, **When** the user cancels it,
   **Then** the archiver stops too and does not keep running in the
   background.

---

### User Story 3 - Only programs that can work are offered (Priority: P2)

A user opens the Pack or Unpack dialog, the archiver configuration pages, or
*Archivers Autoconfiguration*. They see only formats and programs that can
work on their Windows today. There are no MS-DOS entries, no floppy-volume
presets and no products that have not been obtainable for decades.

**Why this priority**: It removes the confusion and the "DOS version" texts the
user reported. It depends on deciding which programs remain supported. The
product is usable without it once Stories 1–2 are done.

**Independent Test**: On a fresh configuration, go through every place that
lists packers, unpackers, archiver programs or archive formats. Check every
entry against the supported-archiver list produced by this feature.

**Acceptance Scenarios**:

1. **Given** a fresh installation, **When** the user opens the Pack dialog,
   **Then** the offered packers are only plug-in packers and supported external
   ones. None mentions DOS, MS-DOS, Win32 or 1.44MB volumes.
2. **Given** a fresh installation, **When** the user runs *Archivers
   Autoconfiguration*, **Then** it searches only for supported programs and
   describes them by their current names.
3. **Given** the configuration pages for external packers and unpackers,
   **When** the user edits a command, **Then** the offered variables no longer
   include DOS-only (8.3 short name) variants. A user command that already
   uses one keeps working.

**Decision (2026-10-01)**: only maintained, currently obtainable programs stay
supported: **WinRAR's console RAR** (`rar.exe`, for RAR) and the **7-Zip
console program** (`7z.exe`), which is a new entry. All 7 MS-DOS archivers and
the Win32 entries for JAR, ACE, ARJ and PKZIP are removed, along with every
floppy-volume preset. Anyone can still add any program as their own custom
external packer or unpacker (FR-008).

---

### User Story 4 - Existing configurations are cleaned up on upgrade (Priority: P2)

A user upgrading from an earlier 0.1.x release has the old default list
(including all DOS entries) stored in their configuration. After the upgrade
they see the same cleaned-up list as a new user. Every entry that refers to a
removed archiver is removed, whether or not the user edited it. Custom entries
that call a program by their own path are kept.

**Why this priority**: Without it, only new installations benefit from
Story 3. Existing users, the people who reported the problem, would keep
seeing the obsolete entries.

**Independent Test**: Start the new version on a configuration saved by 0.1.8
with (a) untouched defaults, (b) one default entry for a removed archiver
edited, and (c) one user-added custom entry that calls a program by its own
path. Check that (a) and (b) are gone, (c) is unchanged, and nothing else in
the configuration changed.

**Acceptance Scenarios**:

1. **Given** a 0.1.8 configuration with untouched default archiver entries,
   **When** the new version starts, **Then** the obsolete default entries are
   gone and the supported ones are present.
2. **Given** a configuration with an edited entry that still refers to a
   removed archiver (it uses that archiver's program-path setting), **When**
   the new version starts, **Then** that entry is removed like an untouched
   default.
3. **Given** a configuration with a user-added custom entry that calls a
   program by its own path (not through a removed archiver's program-path
   setting), **When** the new version starts, **Then** that entry is
   preserved unchanged.
4. **Given** an extension mapped to an archiver that was removed, **When** the
   user opens a file with that extension, **Then** the file is treated as an
   ordinary file, or opened by a plug-in that supports it. No error mentions a
   removed program.

---

### User Story 5 - Maintainer has a documented inventory (Priority: P3)

The maintainer gets a written record of how the archive subsystem works: the
paths from a panel action to an external program, the role of each
component, every supported and removed format and program, and the reason for
each decision. Future changes can then rely on that record instead of the
1990s comments in the source.

**Why this priority**: The user asked explicitly for the review ("prověří jakým
způsobem funguje"). It does not change the product by itself, but it is what
the other stories' decisions rest on.

**Independent Test**: A reader who has not seen the code can answer from the
document alone: which program handles `.rar` / `.arj` / `.lzh` / `.ace` /
`.uc2` on a clean installation, what happens when it is missing, and why each
removed format was removed.

**Acceptance Scenarios**:

1. **Given** the inventory document, **When** a format is looked up, **Then**
   the document states who handles it (plug-in, external program, nobody), the
   status (kept / removed / newly added) and the reason.
2. **Given** the inventory, **When** compared with the shipped product,
   **Then** every format and program the product offers appears in it, and no
   removed item is still offered.

---

### Edge Cases

- An archive whose extension was previously mapped to a removed archiver
  (e.g. `.lzh`, `.uc2`, `.arj`, `.ace`, `.j`): the user gets a defined outcome,
  never a launch failure. If the 7-Zip console program is installed and can
  read the format (as it can ARJ and LZH), the file is unpacked through it.
  Otherwise the file is handled as an ordinary unknown file. The inventory
  (User Story 5) records the outcome for each such extension.
- A user who really still uses a 32-bit archiver that is no longer on the
  default list: it can still be configured as a custom external packer or
  unpacker (pack, unpack whole archive), and it works without the old helper.
  Browsing such an archive in the panel is not possible unless the 7-Zip entry
  can read the format.
- Multi-volume archives (`.r00`, `.a01`, `.c01` and the like): the outcome is
  defined for every kept format, and the volume extensions of removed formats
  are no longer claimed.
- Archive or target paths longer than 259 characters, with spaces, or with
  characters outside the system code page: these behave like ordinary paths
  for every kept archiver, or fail with a clear message.
- The external archiver produces no output, or output in an unexpected
  language or format (e.g. a newer RAR version with different listing
  columns): the listing either shows the files or fails with a message. It
  never shows a partial or garbled listing as if it were complete.
- An external archiver waits for keyboard input (overwrite question,
  password): the operation does not hang invisibly.
- Plug-ins call the program's archiver services through the plug-in
  interface: they keep working, and the plug-in interface does not change in a
  binary-incompatible way.
- Translations: removed texts disappear from all shipped languages, and the
  remaining texts stay correctly mapped (the string-table identity is the
  bundle ordinal; see feature 079).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Every external archiver the product offers MUST start
  successfully on a supported Windows installation that has that archiver
  installed. No operation may depend on a helper program the release does not
  contain.
- **FR-002**: The product MUST NOT offer, list, search for or describe any
  16-bit (MS-DOS) archiver, and MUST NOT offer floppy-volume ("1.44MB") presets.
- **FR-003**: The product's default external archivers MUST be exactly WinRAR's
  console RAR and the 7-Zip console program (User Story 3 decision). Each entry
  is described by its current product name without "Win32"/"DOS" qualifiers,
  and its supported versions are stated (*as built, final review #3*: **not met
  for versions** — only the tested version is recorded, in `inventory.md`:
  7-Zip 22.01; WinRAR was never run. A minimum version needs the owed WinRAR
  test and a check of the oldest 7-Zip that accepts `-ba`/`-scc`/`-scs`). The default entries for JAR, ACE,
  ARJ, PKZIP, LHA and UC2 MUST be removed. So MUST the product's built-in
  panel listing support for each of them, so the product contains no
  archiver-specific logic for a program it no longer supports.
- **FR-004**: RAR archives (RAR 4 and RAR 5 formats, including multi-volume
  and encrypted ones) MUST be listable and extractable on a clean installation
  with no third-party software installed (User Story 1 decision). Creating RAR
  archives MUST be offered only when WinRAR's console program is available.
  Any component shipped for this MUST be redistributable under terms
  compatible with the product's licence.
- **FR-005**: Error messages from the archive subsystem MUST name the program
  actually involved, and MUST suggest only remedies that can fix the reported
  condition. The current advice to run *Archivers Autoconfiguration* for a
  missing helper is an example of a remedy that cannot.
- **FR-006**: Cancelling an archive operation MUST also end the external
  program it started.
- **FR-007**: On the first start after upgrade, the stored configuration MUST
  be migrated. Every packer / unpacker entry that refers to a removed archiver
  is removed, whether or not the user edited it. An entry refers to a removed
  archiver when its command uses that archiver's program-path setting. Custom
  entries that call a program by their own path are kept unchanged. Extension
  mappings that point to a removed archiver are cleared. Everything else in the
  configuration stays as it was.
  *As built (final review #3)*: the migration also removes entries whose
  arguments equal a former floppy-volume preset (even with their own program
  path), rewrites the unedited 0.1.8 RAR default packer to *RAR (WinRAR)*,
  removes the unedited 0.1.8 RAR default unpacker, and adds the 7-Zip default
  unpacker and its ARJ/LZH records — contract `config-migration-106.md`
  M1, M1b–M1d, M3.
- **FR-008**: User-defined custom external packers and unpackers MUST keep
  working, including commands that use the short-name (8.3) variables, even
  though those variables are no longer offered for new commands.
- **FR-009**: *Archivers Autoconfiguration* MUST search only for supported
  archivers. It MUST find them in their usual current installation locations,
  e.g. the per-machine program directories of WinRAR and 7-Zip.
- **FR-010**: Formats that a default-enabled plug-in handles (ZIP/JAR/PK3, 7z,
  TAR family, CAB, disc images) MUST keep behaving exactly as before.
- **FR-011**: The plug-in interface MUST remain binary compatible (interface
  version unchanged, unless the plan proves a change unavoidable and
  documents a migration path).
- **FR-012**: The user manual pages describing archivers, packers, unpackers
  and *Archivers Autoconfiguration* MUST match the new behaviour. They must not
  mention removed programs or DOS archivers.
- **FR-013**: All shipped languages MUST be updated consistently. No shipped
  language may still show a removed entry or lose an unrelated string.
- **FR-014**: The feature MUST deliver the inventory document described in
  User Story 5, committed with the feature's records.
- **FR-015**: `CHANGELOG.md` MUST describe the change in the user's terms,
  stating which archivers were removed and why. If the change affects anything
  the privacy statement describes, `PRIVACY.md` MUST be updated in the same
  change.
- **FR-016**: When the 7-Zip console program is present, the product MUST use
  it to browse archives in the panel and unpack them, at least for ARJ (`.arj`)
  and LZH (`.lzh`). The full extension set, limited to formats no
  default-enabled plug-in handles, is fixed in planning and recorded in the
  inventory (FR-014). Browsing MUST show the same file names, sizes and dates
  that 7-Zip itself reports. The product MUST NOT offer a default 7-Zip packer
  entry.
- **FR-017**: A default external-archiver entry (WinRAR console RAR, 7-Zip
  console) MUST be offered in the Pack / Unpack dialogs, and used for panel
  browsing, only while its program is found: located by *Archivers
  Autoconfiguration*, or through a configured path that exists. While it is
  not found, the entry is hidden and the extensions it serves are handled as
  if it did not exist (plug-in or ordinary file). Installing the program and
  re-running *Archivers Autoconfiguration* makes the entry appear without any
  other step. Custom entries that call a program by their own path are
  always listed, as before. An entry whose command is exactly the archiver's
  variable (`$(Rar32bitExecutable)`, `$(SevenZipExecutable)`) is treated like
  the default entry it resembles and is hidden with it, because it cannot run
  either (clarified during implementation; independent review of 2026-10-01).

### Key Entities

- **Archive format**: a file type recognised as an archive by its extension(s).
  It has an unpacker (a plug-in, an external program or none), an optional
  packer, and multi-volume extensions where applicable.
- **External archiver**: a third-party command-line program the user installs.
  It has a name, supported versions, a usual installation location, and command
  templates for list, extract, pack and pack-with-move.
- **Packer / unpacker entry**: a user-visible item in the Pack / Unpack
  dialogs. It is either a plug-in or a custom external entry. For migration,
  what matters is whether its command uses a removed archiver's program-path
  setting (removed) or calls a program by its own path (kept). Whether the user
  edited it does not matter.
- **Supported-archiver list**: the authoritative set of external programs and
  formats the product offers after this feature. Each entry records a reason,
  and it is the source the inventory document and the migration both follow.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 0 occurrences of a "salspawn" or other missing-helper error
  across a test matrix of every kept archiver × {list, unpack selected, unpack
  all, pack, pack and move}. Pack operations apply only where the archiver has
  a default packer, so WinRAR yes and 7-Zip no.
- **SC-002**: 0 user-visible texts mentioning DOS/MS-DOS archivers, "Win32"
  qualifiers or 1.44MB volumes in any shipped language, checked across the
  Pack / Unpack dialogs, the configuration pages, *Archivers Autoconfiguration*
  and the user manual.
- **SC-003**: The default external archivers drop from 12 programs (7 of them
  unable to run on any supported Windows) to 2: WinRAR's console RAR and the
  7-Zip console program. Both pass the SC-001 matrix.
- **SC-004**: On a clean installation with no third-party software, 100 % of a
  RAR test set (RAR 4, RAR 5, multi-volume, encrypted, non-ASCII names) opens
  and extracts in a single user action, with content identical to the source
  files.
- **SC-005**: Upgrading from a 0.1.8 configuration removes 100 % of the
  entries that refer to a removed archiver (edited or not). It keeps 100 % of
  the custom entries that call a program by their own path, and changes no
  setting outside the archiver configuration (verified by comparing the stored
  configuration before and after).
- **SC-006**: Every format listed in the inventory document has a stated
  handler, status and reason, and the document matches what the product
  offers (no item offered but not documented, no removed item still offered).

## Assumptions

- Tandem Commander supports only 64-bit Windows 11 (see CLAUDE.md), so 16-bit
  programs are unusable for every user. Removing them takes away no working
  functionality. Because the helper was never shipped, no external archiver
  has worked in any Tandem Commander release, so the change does not breach
  the backward-compatibility principle.
- Migration of existing configurations (FR-007) is automatic. It removes
  every entry that refers to a removed archiver, edited or not (decision
  2026-10-01). This does not regress working functionality: none of those
  entries could run in any Tandem Commander release, because the helper was
  never shipped. The removal is disclosed in `CHANGELOG.md` (FR-015). Custom
  entries that call a program by their own path are untouched.
- The plug-in archivers enabled by default (zip, 7zip, tar, uncab, uniso) are
  out of scope except for regression checks (FR-010). Whether 7z, ZIP and so on
  could also be handled by external programs is not part of this feature.
- No third-party archiver *program* is bundled. Out-of-the-box RAR extraction
  (User Story 1 decision) may require shipping a redistributable decoding
  component, or using one built into Windows. Planning must establish that its
  licence permits redistribution alongside a GPLv2-or-later product
  (constitution IV). CLAUDE.md and `architecture/04-dependencies.md` currently
  record the RAR decoder as "not redistributable", and planning must
  re-verify that claim against its actual licence text. Shipping a new
  component, or newly enabling the RAR plug-in in the default build, triggers
  the `PRIVACY.md` rule (FR-015).
- **Dependency (decided 2026-10-01, planning)**: the built-in RAR handling is
  7-Zip's RAR decoder, which the product already ships inside the 7zip
  plug-in's engine but does not use. The vendored engine is 7-Zip 16.04, whose
  RAR code has known remote-code-execution defects (CVE-2018-10115,
  CVE-2025-53816). So RAR is exposed only after a **separate, earlier feature**
  upgrades the vendored 7-Zip to 25.x. User Story 1 is blocked on that
  feature; every other story is not. The maintainer accepts shipping and
  exposing the RAR decoder under its "unRAR restriction" licence term, and it
  is documented in `doc/third_party.txt`. See `research.md` R3–R4.
- For `.rar`, the built-in RAR handling (User Story 1) is always used for
  browsing and unpacking, even when WinRAR is installed. WinRAR's console
  program is used only to *create* RAR archives, so the RAR experience does not
  depend on which third-party software a machine has.
- The 7-Zip console program is a new default *unpacker* (browse and unpack)
  for formats no default-enabled plug-in handles. It is not a default packer,
  and it does not replace the 7z plug-in, which stays the default handler for
  `.7z`.
- Whether the old helper program is fixed and shipped, or replaced by starting
  the archiver directly, is decided in planning. The specification requires
  only that no operation depends on a component missing from the release
  (FR-001).
- Verification of actual archiving with third-party programs (WinRAR, 7-Zip)
  needs those programs installed on the test machine. Where a step needs a
  person, it is recorded as owed, as in previous features.
