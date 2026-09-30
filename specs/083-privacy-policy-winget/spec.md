# Feature Specification: Privacy Statement for the winget Catalogue

**Feature Branch**: `083-privacy-policy-winget`  
**Created**: 2026-09-30  
**Status**: Draft  
**Input**: User description: "Připrav na základě kontextu soubor PRIVACY.md tak, aby mohl být vložen do šablony pro winget" (prepare, from the context, a PRIVACY.md file so that it can be referenced from the winget template)

## Context

Tandem Commander is being added to the Windows Package Manager catalogue
(microsoft/winget-pkgs#426090, open since 2026-08-29). An audit on 2026-09-30
(`specs/072-winget-distribution/REMAINING-WORK.md` § P0, item 3) found that the
catalogue's moderators have, since late September 2026, asked new packages that
store user credentials to publish a privacy disclosure and reference it from the
manifest as `PrivacyUrl` (verified on #425232: *"please publish a privacy
disclosure for the application and add its URL to the manifest as
`PrivacyUrl`"*). Tandem Commander stores FTP and SFTP passwords, so it falls in
that group. The project has no privacy statement today, and tandemcommander.org
has no privacy page.

The statement is a **public claim about the product's behaviour**. Its value
depends entirely on being true, so this feature is as much about establishing
the facts (what the product stores, what it sends, to whom, and when) as about
writing the text.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A catalogue moderator finds a privacy disclosure (Priority: P1)

A winget-pkgs moderator reviewing the Tandem Commander submission opens the
manifest's privacy link and finds a clear, accurate statement of what the
program does with user data — in particular with the stored FTP/SFTP
credentials — and does not need to ask the author for one.

**Why this priority**: It is the reason for the feature. A missing disclosure
costs a round of moderator feedback, which for this pull request has meant
weeks of waiting per round.

**Independent Test**: Render the winget manifests for a released version with
the updated template; the locale manifest contains a privacy link, the link
resolves publicly to the statement, and the manifests pass the catalogue's
local validation.

**Acceptance Scenarios**:

1. **Given** the manifests are generated for a released version, **When** a
   reviewer opens the privacy link from the locale manifest, **Then** it opens
   the privacy statement without sign-in and with a successful response.
2. **Given** the statement is open, **When** the reviewer looks for how saved
   passwords are handled, **Then** the statement says where they are kept,
   how they are protected with and without a master password, and that they
   are never sent anywhere except to the server the user connects to.
3. **Given** the generated manifests, **When** they are validated with the
   catalogue's own validator, **Then** validation succeeds.

---

### User Story 2 - A user learns what the program does with their data (Priority: P2)

A person deciding whether to install Tandem Commander, or already using it,
reads the statement and understands in a few minutes: the program collects
nothing about them, contacts the network only when they ask it to, what it
keeps on their own computer, and how to remove it.

**Why this priority**: The statement is read by users too, not only by
moderators; for them it is the only place these facts are written down.

**Independent Test**: A reader unfamiliar with the code base answers a fixed
set of questions (does it send telemetry? what does it store and where? when
does it go online? how do I remove my data?) correctly from the statement
alone.

**Acceptance Scenarios**:

1. **Given** a reader with no knowledge of the code, **When** they read the
   statement, **Then** they can answer each question in FR-004 correctly.
2. **Given** a user who wants to remove all their data, **When** they follow
   the statement, **Then** it tells them which locations hold data and that
   uninstalling alone may leave some of them in place.

---

### User Story 3 - The statement stays true as the product changes (Priority: P3)

A maintainer (or an AI-assisted session) later enables a plugin, adds an
update check, or changes how credentials are stored. The project's rules make
them update the privacy statement in the same change, so the published
statement never describes an older product.

**Why this priority**: A privacy statement that silently goes stale is worse
than none — it turns an honest product into one making a false public claim.

**Independent Test**: The project instructions name the statement and the
triggers that require updating it; a reviewer can check a change against that
list.

**Acceptance Scenarios**:

1. **Given** a change that adds network communication or changes what is
   stored, **When** the maintainer follows the project instructions, **Then**
   those instructions require the statement to be updated in the same change.
2. **Given** the statement, **When** a reader looks for its validity, **Then**
   it states the product version it describes and the date it was last
   updated.

---

### Edge Cases

- **A plugin that is built but disabled by default** (e.g. the update checker,
  which would contact a third-party server if enabled): the statement covers
  what the shipped product does by default and names such optional
  components explicitly, rather than omitting them.
- **Third-party plugins** installed by the user are outside the project's
  control; the statement says so.
- **Components provided by Windows** (the Microsoft Edge WebView2 runtime used
  to render Markdown and source files, Windows shell extensions, cloud
  storage providers whose icons the panels display) have their own data
  practices governed by their vendors; the statement names them and does not
  make claims on their behalf.
- **Remote images in Markdown documents** are fetched only after the user
  chooses to load them; the image server then sees the request (IP address,
  requested address, the program's identification string). The statement
  discloses this.
- **Crash reports** are written to a local file and never sent; a user may
  choose to attach one to a public issue report, and the statement notes the
  file can contain paths and file names.
- **Saved passwords without a master password** are only obfuscated, not
  encrypted; the statement must say this plainly and recommend the master
  password.
- **The project website and the GitHub repository** are separate services with
  their own terms; the statement covers the application only and says so.
- **Released versions described by the statement**: winget may still offer an
  older version while the statement describes the current one; the statement
  names the version it applies to and notes material differences for older
  versions only where they concern data handling (e.g. versions before 0.1.8
  shipped a separate crash-reporting helper whose upload was disabled).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The project MUST contain a privacy statement as a single
  document at the repository root named `PRIVACY.md`, written in English.
- **FR-002**: The statement MUST be reachable at a stable public address that
  does not change between releases, and that address MUST be added as
  `PrivacyUrl` to the winget locale manifest template, so that every
  generated manifest carries it. The template's authoring notes MUST record
  why the field is there.
- **FR-003**: Every factual claim in the statement MUST be established from
  the product itself before it is written — covering the main application
  and every plugin enabled in the shipped build, plus the installer — and the
  evidence for each claim MUST be recorded in the feature's records.
- **FR-004**: The statement MUST answer, at minimum:
  1. whether the program collects, transmits, or sells any personal data or
     usage data (telemetry, analytics, advertising identifiers, accounts);
  2. every situation in which the program communicates over the network, who
     it communicates with, and what the other side receives;
  3. what the program stores on the user's computer and where (configuration,
     saved connection details and passwords, history, caches, crash reports,
     temporary files, the embedded browser engine's data folder);
  4. how saved passwords are protected, both with and without a master
     password;
  5. what the installer and the uninstaller do and do not remove;
  6. which components are provided and governed by third parties (Windows,
     Microsoft Edge WebView2, shell extensions, third-party plugins);
  7. how to remove all data the program has stored;
  8. how to contact the project about privacy.
- **FR-005**: The statement MUST NOT claim anything that the evidence does not
  support; where behaviour cannot be fully established (for example, what a
  Microsoft component does), it MUST say who governs it instead of
  characterising it.
- **FR-006**: The statement MUST state the product version it describes and
  the date it was last updated.
- **FR-007**: The project instructions MUST name the statement and list the
  kinds of change that require it to be updated in the same change: any new
  or changed network communication, enabling a plugin in the default build,
  any change to what is stored or how credentials are protected, and any
  change to crash reporting.
- **FR-008**: The statement MUST be written for non-technical readers:
  plain language, short sections, no source-code references.
- **FR-009**: The statement MUST offer two contact channels and say which to
  use when: the project's public issue tracker for general privacy questions,
  and the repository's private vulnerability reporting for anything that
  should not be public (a suspected leak of stored credentials, a privacy
  defect). No e-mail address is published. Because the private channel is
  currently switched off in the repository settings (checked 2026-09-30:
  `enabled: false`), enabling it is a precondition for publishing the
  statement, and the statement MUST NOT reference it before it works.
- **FR-010**: The feature MUST NOT change product behaviour, the user
  interface, or translations, and MUST NOT by itself submit anything to the
  catalogue or push to the open pull request; how and when the new field
  reaches #426090 is decided separately (072 § P0 recommends bundling it with
  the move to 0.1.8, to avoid an extra validation round).

### Key Entities

- **Privacy statement**: the published document; attributes — product version
  covered, last-updated date, sections answering FR-004, contact.
- **Data surface**: one place where the product stores or transmits data
  (e.g. saved FTP/SFTP passwords, remote images in the Markdown viewer, crash
  report file); attributes — component, what data, where it goes or is kept,
  when (always / on user action / only if enabled), protection, how to remove,
  evidence.
- **Winget locale manifest template**: the source of truth for catalogue
  metadata; gains the privacy link.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The manifests generated for the current release contain the
  privacy link, and the link returns the statement publicly (success response,
  no sign-in) — verified once before the next catalogue submission.
- **SC-002**: 100% of data surfaces found in the evidence inventory are
  covered by the statement, and 0 statements in the document lack recorded
  evidence.
- **SC-003**: An independent reviewer who did not write the statement checks
  each claim against the evidence and finds no claim that is false or
  overstated.
- **SC-004**: A reader unfamiliar with the project answers all eight FR-004
  questions correctly from the statement alone, in under 10 minutes.
- **SC-005**: The next catalogue submission of Tandem Commander receives no
  moderator request for a privacy disclosure.

## Assumptions

- The statement covers the application as shipped by the project (default
  build per `plugins.cfg`, currently 20 enabled plugins) and its installer —
  not the website, the GitHub repository, or third-party plugins.
- The stable address is the document's page on the project's GitHub
  repository main branch, following the pattern the manifest already uses for
  `LicenseUrl`; the website may link to it but is not required to host a copy.
- English only: the catalogue manifest is `en-US`, and the statement is not
  part of the translated user interface.
- No change to the About dialog, help, or installer is in scope; linking the
  statement from inside the program can be a later feature.
- Facts already known from the 2026-09-30 audit, to be re-verified during
  implementation rather than trusted: no telemetry; crash reports are written
  locally and never sent (the helper that could upload was removed in 0.1.8);
  network use is limited to FTP/SFTP connections the user opens and remote
  images the user explicitly loads in the Markdown viewer; the update-checker
  plugin (which would contact a third-party server) is disabled in the default
  build; passwords are stored in the user's registry, AES-encrypted with a
  master password, otherwise only obfuscated; the program opens project web
  pages in the browser only when the user clicks a link.
- Enabling private vulnerability reporting is a repository setting only the
  maintainer can change (Settings → Security); the repository has no
  `SECURITY.md` yet — adding one is not required by this feature.
- Observed during fact-finding, out of scope here and recorded for follow-up:
  the Markdown viewer's remote-image requests still identify themselves as
  `OpenSalamander-mdview` — a pre-rebrand identity string the statement will
  have to quote as it is until it is changed.
