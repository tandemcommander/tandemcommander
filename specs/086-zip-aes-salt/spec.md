# Feature Specification: Unpredictable salts for encrypted ZIP archives

**Feature Branch**: `086-zip-aes-salt`
**Created**: 2026-10-01
**Status**: Draft
**Input**: User description: "Oprava soli AES v ZIP pluginu: ZIP plugin generuje sůl pro AES šifrované archivy (a hlavičku ZipCrypto) přes rand() nasazený time ^ pid (src/plugins/zip/crypt.cpp:118-127 FillBufferWithRandomData, volané z src/plugins/zip/add.cpp:1632). Opakovaná sůl se stejným heslem dává stejný AES-CTR keystream (únik XOR dvou otevřených textů). Nalezeno revizí feature 085 (NEXT-WORK bod 7). Oprava: kryptografický generátor Windows (BCryptGenRandom), stejně jako F6 ve feature 085. Archivy vytvořené dřívějšími verzemi musí zůstat čitelné."

## Clarifications

### Session 2026-10-01

- (Scope, decided by the author from the code) The same generator also fills
  the random part of the classic ZIP 2.0 ("ZipCrypto") encryption header, so
  that header is fixed too. ZIP 2.0 encryption stays as weak as the format is;
  only the predictability the program added on top of it goes away.
- (Severity, corrected from the input) Packing runs on one thread and the
  generator is seeded once per program run, so within one run every salt is
  different. The real defect is that **every salt the program produced is
  determined by one 32-bit seed made of the time and the process number** — an
  attacker who can guess the time of creation can reproduce the salts. A
  repeated salt (and with the same password a repeated AES keystream) needs
  two runs that started with the same seed: unlikely, not impossible.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — AES-encrypted archives get unpredictable salts (Priority: P1)

A user creates a ZIP archive with AES-128 or AES-256 encryption. Each
encrypted file in it carries a salt that nobody can predict or reproduce —
not from the time the archive was made, not from the program's process
number, not from other archives made in the same run.

**Why this priority**: the salt is what makes the same password produce a
different encryption key for every file. A predictable salt lets an attacker
prepare for a guessing attack before the archive exists, and identical salts
with the same password would make two files share an encryption keystream.

**Independent Test**: create two AES-256 archives of the same file with the
same password, in the same run and after a restart; the salts stored in the
four archives all differ; each archive opens with the password in this
program and in an independent ZIP tool.

**Acceptance Scenarios**:

1. **Given** a file and a password, **When** the user packs it twice with
   AES-256 encryption, **Then** the two archives contain different salts and
   both extract correctly.
2. **Given** an AES-128 archive made by this version, **When** it is opened
   in another program that supports WinZip AES (for example 7-Zip), **Then**
   it extracts with the password.
3. **Given** an AES archive made by Tandem Commander 0.1.8 or older, **When**
   it is opened in this version, **Then** it extracts as before.

---

### User Story 2 — ZIP 2.0 encrypted archives no longer carry a predictable header (Priority: P2)

A user creates an archive with the classic ZIP 2.0 encryption (for
compatibility with old tools). The random part of each file's encryption
header comes from the same unpredictable source.

**Why this priority**: ZIP 2.0 encryption is weak by design, but a header the
program makes predictable gives an attacker more known material than the
format itself does.

**Independent Test**: pack the same file twice with ZIP 2.0 encryption and the
same password; the encryption headers differ; both archives extract in this
program and in another ZIP tool.

**Acceptance Scenarios**:

1. **Given** ZIP 2.0 encryption, **When** an archive is created, **Then** it
   extracts with the password here and in another ZIP tool.
2. **Given** a ZIP 2.0 archive made by an older version, **When** it is
   opened, **Then** it extracts as before.

### Edge Cases

- The system generator fails (practically never): archive creation still
  works, falling back to the old generator, and the failure is traced in
  debug output — an encrypted archive is never written with an all-zero or
  unchanged salt.
- Several files in one archive: every file gets its own salt (as today).
- Multi-volume and self-extracting archives use the same encryption path and
  are covered by the same change (verified in implementation, fix-log T007; a
  self-extracting archive can only use ZIP 2.0 encryption — AES is refused
  for it, `add_del.cpp:112`).
- Extracting never generates random data; reading old archives is unaffected
  by construction (the salt is stored in the archive).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Every random byte the ZIP plugin writes into an encrypted
  archive (the AES salt of each file, the random part of each ZIP 2.0
  encryption header) MUST come from the operating system's cryptographic
  random generator.
- **FR-002**: If that generator fails, the plugin MUST still fill the buffer
  (with the previous generator) and MUST record the failure in the debug
  trace; it MUST NOT leave the buffer unfilled.
- **FR-003**: Archives created by earlier versions MUST open and extract
  exactly as before; archives created by this version MUST open in other
  tools that support the same encryption methods.
- **FR-004**: The random-bytes routine MUST exist once in the product, shared
  by the core's password manager (feature 085, F6) and the ZIP plugin, and
  MUST be unit-tested.
- **FR-005**: The plugin interface MUST NOT change (interface 106).
- **FR-006**: `CHANGELOG.md` *Unreleased* MUST describe the change in the
  user's terms, including that ZIP 2.0 encryption remains weak by design;
  `specs/NEXT-WORK.md` MUST record the item as done.

### Key Entities

- **Salt**: random bytes stored in front of each AES-encrypted file
  (8 bytes for AES-128, 16 for AES-256) that, with the password, determine
  the file's key.
- **ZIP 2.0 encryption header**: 12 bytes in front of each ZipCrypto-encrypted
  file; 11 random bytes are drawn, of which 10 or 11 remain (the check value
  overwrites the last one when it is two bytes long).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Across 4 archives of the same file with the same password (two
  per run, two runs), **0** salts repeat.
- **SC-002**: **100 %** of archives created by 0.1.8 used as fixtures still
  extract; **100 %** of AES-128, AES-256 and ZIP 2.0 archives created by this
  version extract in this program and in an independent ZIP tool.
- **SC-003**: The shared random routine passes its unit tests with **0**
  failures and the whole unit-test suite still passes (≥ 1816 checks).
- **SC-004**: Debug and Release builds succeed; the plugin interface version
  stays 106.

## Assumptions

- `PRIVACY.md` is not affected: it makes no statement about how archives are
  encrypted (checked; no claim changes).
- No configuration, no archive format and no user interface changes.
- The verification that needs the application on screen (creating archives
  through the Pack dialog and opening them in another tool) is recorded as an
  owed human step, as in earlier features; everything that can be checked
  without the screen is automated.
