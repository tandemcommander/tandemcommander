# Feature Specification: 7-Zip engine 26.03 and RAR out of the box

**Feature Branch**: `087-7zip-2603-rar`
**Created**: 2026-10-01
**Status**: Draft
**Input**: User description: "Upgrade vendorovaného 7-Zip enginu ve 7zip pluginu z 16.04 na 26.03 a čtení RAR přes plugin (stage S7 feature 084). Rozhodnutí (2026-10-01): cílová verze 26.03 (opravuje CVE 2018-2026 v RAR, RAR5, PPMd, Shrink, XZ, CopyCoder; generátor náhodných čísel pro 7z/ZIP AES seedovaný RtlGenRandom); rozsah = upgrade + RAR4/RAR5 čtení (detekce formátu, vícesvazkové archivy, Unicode heslo, registrace + migrace konfigurace; balení RAR jen přes WinRAR); 7za.dll obsahuje jen handlery, které plugin používá (7z, RAR, RAR5 + kodeky pro 7z); 7zwrapper.dll (bez volajícího) odstranit. Lokální patche (obaly vláken pro call stack, spl/main.cpp, JRY FIX) přenést nebo zdůvodnit. Archivy vytvořené dřívějšími verzemi musí zůstat čitelné, plugin ABI beze změny."

## Clarifications

### Session 2026-10-01

- Q: Which 7-Zip version? → A: **26.03** (2026-09-03), the latest stable. The 26.0x releases fix CVEs (NTFS, XZ, SquashFS, UEFI, UDF, WIM, Ar handlers) that 25.x still has.
- Q: What does the feature include besides the engine? → A: **The engine upgrade plus reading RAR through the 7zip plugin** (feature 084's stage S7: format detection, multi-volume archives, Unicode passwords, registration and configuration migration). Creating RAR archives stays with WinRAR.
- Q: Which formats does the engine contain? → A: **Only what the plugin uses** — 7z, RAR (RAR 1.5–4) and RAR5, with the codecs they need. The other ~45 handlers are unreachable from the plugin and only add attack surface.
- Q: What happens to the unused helper `7zwrapper.dll`? → A: **Removed** (source, project, shipped file, and the file left behind on updated installations).
- (Found during specification, decided by the author as a security requirement) The plugin writes extracted files to *target folder + name stored in the archive* without cleaning the name. A crafted archive can therefore write outside the target folder (`..\`), to an absolute path, or into an NTFS alternate data stream (`name:stream`). This exists today for 7z; reading RAR downloaded from the internet makes it far more exposed, so cleaning item names is part of this feature.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Open and extract RAR archives without installing anything (Priority: P1)

A user receives a RAR archive (RAR 4 or RAR 5) and presses Enter on it in a
panel of a fresh Tandem Commander installation with no WinRAR or 7-Zip
installed. The archive opens like a folder; the user browses it, views a
file with F3, and copies files out with F5 or unpacks it with Alt+F9.
Encrypted archives ask for the password (also passwords with non-Latin
characters); archives whose file list is encrypted ask before showing it;
split archives (`.part1.rar`, `.part2.rar` … or `.rar`, `.r00` …) open from
their first part and extract across all parts; file names in any script
appear correctly.

**Why this priority**: RAR is one of the most common archive formats users
receive; today the product cannot open it at all without a third-party
program (feature 084 removed the non-working ones and blocked RAR on this
upgrade).

**Independent Test**: on a machine without any third-party archiver, open
and extract each RAR fixture of feature 084 (`specs/084-archiver-cleanup/probe/fixtures/rar/`)
and compare the extracted files with a reference extraction.

**Acceptance Scenarios**:

1. **Given** a RAR5 archive with Unicode file names, **When** the user opens
   it, **Then** the names display correctly and every file extracts
   byte-identical to the reference.
2. **Given** a RAR4 or RAR5 archive with encrypted data, **When** the user
   extracts a file, **Then** the program asks for the password, and with the
   right password the file extracts correctly; with a wrong one an error is
   shown and no file is left half-written.
3. **Given** an archive with an encrypted file list, **When** the user opens
   it, **Then** the password is asked for before the list appears; cancelling
   leaves the panel where it was.
4. **Given** the first part of an 8-part RAR5 set or a 4-part RAR4 set,
   **When** the user opens and extracts it, **Then** files spanning parts
   extract correctly; if a part is missing, a clear error names the problem.
5. **Given** a damaged RAR archive, **When** it is opened or extracted,
   **Then** an error is shown, the program does not crash, and nothing is
   reported as extracted that was not.
6. **Given** a RAR archive, **When** the user tries to add, delete or update
   files inside it through the panel, **Then** the operation is refused with
   the plugin's usual "not supported" message (packing RAR is offered only
   through WinRAR's console program, when installed — feature 084).

---

### User Story 2 — 7z archives keep working, on a patched engine (Priority: P1)

A user who works with 7z archives — browsing, extracting, testing, creating,
adding, deleting, with and without encryption, solid or not — notices no
change, except that archives from untrusted sources can no longer exploit
the defects fixed in 7-Zip since 2016.

**Why this priority**: 7z is the format the plugin has always handled; the
engine it uses is ten years old and carries known remote-code-execution
defects (research R2). Nothing that works today may stop working.

**Independent Test**: run the 7z regression set (create, list, extract,
test, update, delete, encrypted, solid, Unicode names) with the new build;
open archives created by 0.1.8 and by current 7-Zip; open the archives the
new build creates in current 7-Zip.

**Acceptance Scenarios**:

1. **Given** 7z archives created by Tandem Commander 0.1.8 (plain,
   encrypted, solid, encrypted names), **When** they are opened in this
   version, **Then** they list and extract exactly as before.
2. **Given** a 7z archive created by this version, **When** it is tested in
   an independent 7-Zip (22.01 or newer), **Then** it tests OK and extracts identically.
3. **Given** the pack dialog's existing options (compression level, solid,
   encryption), **When** an archive is created, **Then** the options take
   effect as before.
4. **Given** an encrypted 7z archive created by this version, **Then** its
   encryption uses unpredictable random values (the engine's own generator,
   seeded from the system's cryptographic source).

---

### User Story 3 — Extraction never writes outside the chosen folder (Priority: P1)

A user extracts an archive from an untrusted source. Whatever names the
archive contains — `..\..\Windows\evil.dll`, `C:\Users\x\evil`, `\\server\share\x`,
`file.txt:hidden`, names with characters Windows forbids — every file lands
inside the target folder, under a safe name, and nothing is written to an
alternate data stream or outside the folder.

**Why this priority**: an archive that can write outside the target folder
can plant programs in places Windows runs them from. This is the most
severe consequence of opening untrusted archives, and RAR makes it common.

**Independent Test**: extract crafted 7z and RAR archives containing each
kind of hostile name; check that every output is inside the target folder
and nothing exists outside it or in an alternate stream.

**Acceptance Scenarios**:

1. **Given** an item named `..\..\evil.txt`, **When** the archive is
   extracted to `D:\out`, **Then** the file is created inside `D:\out` (as
   `D:\out\evil.txt` or under an equivalent safe name) and nothing is created
   above `D:\out`.
2. **Given** items with absolute or UNC paths, **When** extracted, **Then**
   they are created relative to the target folder.
3. **Given** an item `report.txt:secret` (or an archive entry that is marked
   as an alternate data stream), **When** extracted, **Then** no alternate
   data stream is written; the entry is either skipped with a notice or
   written as an ordinary file with a safe name.
4. **Given** names with characters Windows does not allow (`<>:"|?*`, control
   characters, trailing dots or spaces), **When** the archive is listed and
   extracted, **Then** the panel shows them and the files are created under a
   predictably adjusted name.

---

### User Story 4 — A leaner engine and no dead helper (Priority: P2)

The program ships a smaller archive engine that contains only the formats it
uses, no longer ships the unused helper library, and an updated installation
does not keep the old helper on disk. The licence notices shipped with the
program match what it contains.

**Why this priority**: fewer formats compiled in means fewer places for
defects; a file nothing uses but every install carries is maintenance and
antivirus surface (feature 076/077 history).

**Independent Test**: inspect a fresh and an upgraded installation: the
helper is absent; the engine lists only the expected formats; the
third-party notices name the engine version and its licences.

**Acceptance Scenarios**:

1. **Given** an installation of 0.1.8 that is updated, **Then**
   `7zwrapper.dll` is no longer present afterwards.
2. **Given** the new engine, **When** its format list is queried, **Then** it
   reports exactly 7z, RAR and RAR5.
3. **Given** the shipped third-party notices, **Then** they state the engine
   version 26.03, the LGPL and the unRAR restriction, and no format whose code
   is not included.

---

### User Story 5 — Crash reports still cover the engine's threads (Priority: P3)

If the archive engine crashes in one of its worker threads, the program's
crash report still shows where, as it did with the old engine.

**Why this priority**: the old engine carried local changes that routed its
threads through the program's call-stack tracking; dropping them silently
would make engine crashes undiagnosable.

**Independent Test**: confirm in a debug build that every thread the engine
creates during a multi-threaded pack and extract runs through the tracking
wrapper (trace or breakpoint), including the threads the old patch missed.

**Acceptance Scenarios**:

1. **Given** a multi-threaded 7z pack and extract, **When** the engine starts
   its worker threads, **Then** each of them is registered with the
   program's call-stack tracking.

### Edge Cases

- A RAR archive needs more memory than allowed (very large dictionary,
  RAR 7): the engine refuses it with an error rather than allocating
  unbounded memory.
- A multi-volume set where a middle part is missing or renamed: an error,
  not a hang; parts are located by their standard names in the same folder.
- A file inside RAR that is a symbolic or hard link: extracted as an ordinary
  file (link targets are never followed or created).
- An archive that is RAR by content but named `.zip` (or the reverse): the
  plugin only handles extensions registered for it; detection by signature
  only confirms the registered format.
- A 7z or RAR archive with tens of thousands of entries: listing time stays
  comparable to 0.1.8's for 7z.
- Two entries that become the same name after cleaning: both extract, the
  usual overwrite prompt applies.
- Self-extracting RAR (`.exe`): not registered; out of scope.
- An encrypted archive and a password with characters outside the system
  code page (e.g. Czech diacritics on an English Windows, Cyrillic): works.

## Requirements *(mandatory)*

### Functional Requirements

**Engine**

- **FR-001**: The plugin MUST use the 7-Zip 26.03 engine; the version shown
  in the plugin's About box MUST be 26.03.
- **FR-002**: The engine MUST contain the 7z, RAR (1.5–4) and RAR5 handlers
  and the codecs and filters those formats need for reading, plus what 7z
  needs for writing; it MUST NOT contain other archive handlers.
- **FR-003**: Every thread the engine creates MUST run through the program's
  call-stack tracking, as the old engine's local patch intended (and also for
  the threads that patch missed).
- **FR-004**: Every local modification carried over from the 16.04 tree MUST
  be either re-applied or recorded as no longer needed, with the reason.
- **FR-005**: The plugin interface version MUST stay 106; no change under
  `src/plugins/shared/`.

**7z (regression)**

- **FR-006**: All existing 7z operations (browse, extract, test, create, add,
  delete, update, encryption, solid, compression level) MUST behave as in
  0.1.8; 7z archives created by 0.1.8 MUST stay readable; archives created by
  this version MUST be readable by an independent 7-Zip (22.01 or newer).
- **FR-007**: A wrong password MUST still fail the operation (the old local
  fix for "unpack and delete" removing the source after a failed decode).

**RAR**

- **FR-008**: The plugin MUST open archives with the RAR extensions it
  registers (`rar`, and the first-volume names of split sets) in the panel,
  confirming the format by its signature (RAR 4 and RAR 5).
- **FR-009**: Multi-volume RAR sets in both naming schemes MUST open from the
  first part and extract across parts; a missing part MUST produce an error.
- **FR-010**: Passwords MUST be entered and passed to the engine as Unicode;
  encrypted file lists MUST prompt before listing; a wrong password MUST
  produce an error and no reported success.
- **FR-011**: Changing a RAR archive (add, delete, update) through the plugin
  MUST be refused with the plugin's standard message.
- **FR-012**: The plugin's configuration MUST be migrated once so that RAR
  archives open in the panel through the plugin and *Unpack* offers the
  plugin for RAR; the RAR packer of feature 084 (WinRAR console, when
  installed) MUST stay the packer for RAR.

**Safety**

- **FR-013**: Every name taken from an archive MUST be cleaned before it is
  used to build a path (listing and extraction): no component may climb out
  of the target folder, absolute/UNC/drive prefixes are removed, alternate
  data stream syntax cannot reach the file system, and characters or forms
  Windows forbids are replaced predictably. The cleaning MUST be a pure,
  unit-tested function.
- **FR-014**: Entries the engine marks as alternate data streams MUST NOT be
  written as streams; symbolic/hard link entries MUST NOT create links.
- **FR-015**: The engine MUST bound the memory a RAR archive may request.

**Packaging and records**

- **FR-016**: `7zwrapper.dll`, its source and its project MUST be removed;
  an updated installation MUST not keep it.
- **FR-017**: `doc/third_party.txt` MUST name 7-Zip 26.03, its LGPL licence
  and the unRAR restriction; nothing for code not compiled in.
- **FR-018**: `CHANGELOG.md` *Unreleased* MUST describe the user-visible
  changes (RAR out of the box, the security fixes in user terms, the
  extraction-safety fix stated as a defect fix of earlier versions);
  `PRIVACY.md` MUST be checked (no change expected: the engine does no
  networking) and `specs/NEXT-WORK.md` item 8 and feature 084's S7 records
  MUST be closed.

### Key Entities

- **Archive engine**: the plugin's private copy of 7-Zip; a version, a list of
  formats it can open, and the codecs those need.
- **Archive item**: an entry in an archive — stored name, size, times,
  attributes, encrypted flag, directory/alt-stream/link flags.
- **Cleaned name**: the safe relative path derived from an item's stored
  name, used for the panel and for the file system.
- **Volume set**: the files that together form one multi-part archive.
- **Plugin configuration version**: the number that decides which one-time
  migrations have run.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: **100 %** of the 22 RAR fixtures of feature 084 behave as
  expected (open, extract byte-identical, or fail cleanly where they are
  damaged/missing a part) on a machine with no third-party archiver.
- **SC-002**: **100 %** of the 7z regression cases pass; **0** 7z archives
  created by 0.1.8 fail to open; **100 %** of archives created by this version
  test OK in an independent 7-Zip (22.01 or newer).
- **SC-003**: For a hostile-name corpus covering every case of User Story 3,
  **0** files are created outside the target folder and **0** alternate data
  streams are written; the name-cleaning function passes its unit tests
  with 0 failures.
- **SC-004**: The engine reports exactly **3** archive formats; the shipped
  installation contains **no** `7zwrapper.dll`.
- **SC-005**: Listing a 7z archive with 10,000 entries takes no more than
  **1.5×** the time 0.1.8 takes on the same machine.
- **SC-006**: Debug and Release builds succeed; the unit test suite passes
  (≥ 1829 checks); the plugin interface version stays 106.

## Assumptions

- The 7-Zip 26.03 source is taken from the official release (GitHub
  `ip7z/7zip`, tag `26.03`) and verified against the published SHA-256
  (`9cbde509…c0d4` for `7z2603-src.tar.xz`, research R1).
- Licence: the maintainer accepted on 2026-10-01 shipping the RAR decoder
  under the unRAR restriction (feature 084 R4).
- Archive *creation* stays 7z only; the default compression settings of the
  pack dialog are unchanged. New engine defaults that would make archives
  unreadable by older 7-Zip versions are not enabled (none are known for the
  settings the plugin uses).
- The x86 build is not shipped (the product ships x64); it must still compile
  if it compiles today.
- The verification that needs the screen (panel, dialogs, a clean machine) is
  recorded as owed to a person; everything else is automated (unit tests, a
  command-line driver of the engine over the fixtures, builds).
- Other formats in 7-Zip (ZIP, ISO, CAB, ARJ, LZH, …) remain handled by the
  product's other plugins or the external 7-Zip console entry; exposing them
  through this plugin is a later decision (feature 084 R5).
