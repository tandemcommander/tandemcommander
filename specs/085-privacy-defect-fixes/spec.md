# Feature Specification: Privacy defect fixes (F1–F7 of feature 083)

**Feature Branch**: `085-privacy-defect-fixes`
**Created**: 2026-10-01
**Status**: Draft
**Input**: User description: "Opravy ochrany soukromí z feature 083 (NEXT-WORK bod 7): F1 — heslo zadané v adrese `ftp://user:heslo@host` se ukládá čitelně do historie (FTP Quick Connect, Change Directory, příkazová řádka); F3 — Markdown dokument umí otevřít prohlížeč bez kliknutí; F2 — User-Agent mdview je `OpenSalamander-mdview`, nekontroluje se HTTP status, cookies nejsou vypnuté; F6 — sůl správce hesel z `rand()`; F7 — zrušený dotaz na master password u SFTP tiše uloží tajemství jen zakódované; F4 — crash dumpy WebView2 se posílají Microsoftu (rozhodnout). PRIVACY.md se musí upravit ve stejné změně."

## Clarifications

### Session 2026-10-01

- Q: F4 — the viewer engine's crash dumps go to Microsoft by default. What does this feature do? → A: **Turn sending off.** Dumps stay in the viewer engine's local data folder; nothing is uploaded. Set once, for both viewers. Accepted risk: two instances of *different* program versions running at the same time cannot share the viewer engine, and the later one falls back to the plain text view. *(Correction found during implementation: neither viewer falls back to text when the engine fails after the runtime check - both show "engine unavailable" and close (`mdview/viewer.cpp` and `codeview/viewer.cpp` `EngineFailed`). The decision stands; the records state the real consequence.)*
- Q: F1, command line — where is a password searched for in a command before it goes to history? → A: **Anywhere in the command.** `curl ftp://u:secret@h/f` is kept as `curl ftp://u@h/f`; recalling it from history then needs the password typed again.
- (Scope, decided by the author from the 083 record) F5 — `architecture/11-webview2-integration.md` says the viewer data folder "holds cache only". The F4 change edits that contract anyway, so the inaccurate sentence is corrected in the same change. F9 (FTP anonymous e-mail placeholder) stays out.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — A password typed into an address is never written to history (Priority: P1)

A user connects to an FTP server by typing the whole address with the
password in it — `ftp://alice:s3cret@ftp.example.com/pub` — into FTP
Quick Connect, the Change Directory dialog, a Copy/Move target, or the
command line. The connection works as before. Afterwards, nothing that
the program keeps or saves (the drop-down lists of those fields, the
registry, an exported configuration) contains `s3cret`; the entry reads
`ftp://alice@ftp.example.com/pub`.

**Why this priority**: it is the only way a password reaches the
registry unprotected without the user choosing *Save password* (083
research, F1). Anyone who can read the user's registry or an exported
configuration can read it today.

**Independent Test**: type each of the four forms above with a
recognisable password, connect, open the field's drop-down, then save
the configuration and search the `HKCU\Software\Tandem Commander`
registry key for the password text. It must not be found; the
connection must have succeeded.

**Acceptance Scenarios**:

1. **Given** FTP Quick Connect, **When** the user types
   `ftp://alice:s3cret@host/pub` and connects, **Then** the connection
   uses the password, and the Address history holds
   `ftp://alice@host/pub`.
2. **Given** the Change Directory dialog, **When** the user enters
   `ftp://alice:s3cret@host`, **Then** the panel connects and the
   Change Directory history holds `ftp://alice@host`.
3. **Given** a Copy or Move dialog (from the core or from the FTP
   plugin's download dialog), **When** the user types the target
   `ftp://alice:s3cret@host/in`, **Then** the copy goes there and the
   target history holds `ftp://alice@host/in`.
4. **Given** the command line, **When** the user runs
   `curl ftp://alice:s3cret@host/f`, **Then** the command runs
   unchanged and the command-line history holds
   `curl ftp://alice@host/f`.
5. **Given** a history saved by an older version that already contains
   `ftp://alice:s3cret@host`, **When** this version starts and later
   saves its configuration, **Then** the stored entry becomes
   `ftp://alice@host` (or disappears if the same entry without a
   password is already in the list).

---

### User Story 2 — A document cannot open the browser by itself (Priority: P2)

A user opens a Markdown file from an untrusted source in the Markdown
Viewer. The document contains an instruction that would navigate away
on its own (for example an automatic page refresh to an internet
address). Nothing happens: no browser opens, no other viewer window or
message box appears. Clicking an ordinary link in the same document
still opens it in the browser, exactly as before.

**Why this priority**: a document can today make the program open an
arbitrary web address in the default browser without the user doing
anything, which reveals the user's IP address and the fact that the
document was opened (083 research, F3).

**Independent Test**: open a Markdown file containing an automatic
refresh to an external address and one to a relative `.md` file; wait;
nothing may open. Click a normal link; it opens.

**Acceptance Scenarios**:

1. **Given** a document with an automatic refresh to
   `https://example.com/`, **When** it is opened, **Then** no browser
   window opens.
2. **Given** the same document, **When** the user clicks an ordinary
   `https://` link in it, **Then** that link opens in the browser.
3. **Given** a document with an automatic refresh to a relative
   `other.md`, **When** it is opened, **Then** no new viewer window
   opens (clicking a link to `other.md` still opens one).
4. **Given** the Code Viewer, **When** any file is viewed, **Then** its
   behaviour is unchanged (it activates no links).

---

### User Story 3 — Remote images are fetched politely and identify the right product (Priority: P3)

A user chooses *View → Load Remote Images* in the Markdown Viewer. The
image servers receive a request that names Tandem Commander, not Open
Salamander; no cookies are stored or sent between requests; an error
page from the server (for example "404 Not Found") is shown as a broken
image instead of being treated as image data.

**Why this priority**: the identification is visibly wrong and the
privacy statement has to apologise for it; cookie handling contradicts
the code's own comment; the missing status check is a correctness gap.
Low risk, low cost.

**Independent Test**: point a document at a local test web server that
logs request headers, sets a cookie and answers 404 for one image;
load remote images twice.

**Acceptance Scenarios**:

1. **Given** consented remote images, **When** they are fetched,
   **Then** each request identifies itself as `TandemCommander-mdview`.
2. **Given** a server that answers with a cookie, **When** the next
   image is fetched, **Then** the request carries no cookie.
3. **Given** a server answering "404 Not Found" with an HTML body,
   **When** the image is fetched, **Then** the image shows as broken.

---

### User Story 4 — A cancelled Master Password prompt never saves a weaker secret (Priority: P3)

A user who protects saved passwords with a Master Password edits an
SFTP bookmark, types a new password (or key passphrase) with *Save
password* checked, and cancels the Master Password prompt. The secret
is not saved at all — the *Save password* box is cleared, as FTP
already does — instead of being saved silently in the weaker scrambled
form the user chose to avoid. A connection started from the dialog
still uses the typed secret.

**Why this priority**: the user explicitly asked for encryption; the
current behaviour silently stores the secret in a form anyone can
reverse (083 research, F7).

**Independent Test**: with a Master Password configured and not yet
entered in the session, type a new SFTP password with *Save password*
on, cancel the prompt; check the registry: no password blob for that
bookmark; *Save password* is unchecked.

**Acceptance Scenarios**:

1. **Given** Master Password in use and not entered, **When** the user
   cancels the prompt while saving a typed SFTP password, **Then**
   nothing is saved for the password and *Save password* is shown
   unchecked.
2. **Given** the same, **When** the user connects, **Then** the
   connection uses the typed password.
3. **Given** the same for the key passphrase, **Then** the same rules
   apply to *Save passphrase*.
4. **Given** the user enters the Master Password correctly, **Then**
   the secret is saved encrypted, as before.

---

### User Story 5 — Encryption salts are unpredictable (Priority: P3)

Every random value the password manager uses (the salt of each
encrypted password, the Master Password verifier's salt) comes from
the operating system's cryptographic random generator rather than a
generator seeded with the time and process number.

**Why this priority**: a predictable salt weakens the protection of
saved passwords against precomputation; the fix is local and has no
compatibility cost (salts are stored with the data they protect).

**Independent Test**: passwords encrypted by older versions still
decrypt; newly encrypted ones decrypt; the generator source is the
system's cryptographic generator (code review + build).

**Acceptance Scenarios**:

1. **Given** passwords saved by 0.1.8 under a Master Password, **When**
   this version reads them, **Then** they decrypt as before.
2. **Given** a password newly saved by this version, **When** it is
   read back (also after a restart), **Then** it decrypts.

---

### User Story 6 — The viewer engine does not send crash dumps to Microsoft (Priority: P3)

If the Markdown Viewer's or Code Viewer's rendering engine crashes,
its crash dump stays on the user's computer (in the viewer engine's
data folder) and is not uploaded to Microsoft.

**Why this priority**: the program promises it sends nothing on its
own; the engine's default crash upload is the one remaining automatic
transmission tied to the program's use (083 research, F4). Decided:
turn it off.

**Independent Test**: start a viewer, confirm the engine's
environment is created with custom crash reporting enabled (debug
trace / read-back), and that both viewers and the warm-engine keeper
share the same setting.

**Acceptance Scenarios**:

1. **Given** either viewer, **When** its engine starts, **Then** it
   starts with crash upload disabled.
2. **Given** the Markdown Viewer and the Code Viewer used in one
   session, **When** both open, **Then** both render (they still share
   one engine).

---

### Edge Cases

- **Password containing `@`** (`ftp://u:p@ss@host`): everything between
  the first `:` of the user part and the last `@` before the host is
  removed — no fragment of the password may stay behind, even where the
  FTP plugin itself parses such an address differently.
- **Percent-escaped password** (`ftp://u:p%40ss@host`): removed as typed.
- **No password** (`ftp://u@host`, `ftp://host:2121`, `ftp://[::1]:21`):
  the entry is stored unchanged — a port is never mistaken for a
  password.
- **Empty password** (`ftp://u:@host`): stored as `ftp://u@host`.
- **User name with a domain** (`ftp://corp\alice:pw@host`): the domain
  part stays, the password goes.
- **Address without the `ftp://` prefix in Quick Connect**
  (`alice:pw@host`, `//alice:pw@host`): stripped as well — Quick
  Connect's field is always an address.
- **Drive paths, UNC paths, archive paths, masks** (`C:\a:b@c`,
  `\\srv\share`, `*.txt`): never changed; one-letter "schemes" are drive
  letters.
- **Command line with several URLs**: every one is stripped.
- **A password containing an unescaped `/`** is not recognised (the
  address ends at the first `/`); the FTP plugin does not recognise it as
  a password either. Documented limitation.
- **Two history entries that become identical** after stripping: only
  the more recent one is kept.
- **History saving off**: nothing is written anyway; the in-session
  drop-down is still clean.
- **Configuration never saved** after the update (Save configuration on
  exit off and never saved by hand): old entries stay in the registry
  until the next save; *Clear History* still removes them.
- **Meta refresh to the document's own address**: allowed (it is the
  document itself), as today.
- **Keyboard activation of a link** (Tab to a link, Enter): counts as the
  user's action and opens the link.
- **Master Password prompt cancelled for an unchanged (stored) secret**:
  nothing changes — the stored blob is kept as today (only a newly
  typed secret triggers the prompt).
- **Two program versions running at once** (an older instance still
  open): the viewer engine cannot be shared between environments with
  different crash-reporting settings; the viewer started second shows
  "engine unavailable" and closes (`EngineFailed` in both viewers).
  Accepted (clarification Q1, whose wording "falls back to the text view"
  was corrected during implementation).

## Requirements *(mandatory)*

### Functional Requirements

**F1 — passwords in typed addresses**

- **FR-001**: Before a value is added to the Change Directory history,
  the Copy/Move target history (from the core dialogs and through the
  plugin-facing history service), the Find *Look in* history or the
  command-line history, the program MUST remove the password part of
  every embedded address of the form `scheme://user:password@host…`;
  the value used for the operation itself MUST stay unchanged.
- **FR-002**: For a value that *begins* with a file-system prefix
  (`ftp:`, `sftp:`, any name of two or more characters followed by `:`)
  or with `//`, the same rule MUST apply to the part right after it,
  with or without `//`.
- **FR-003**: FTP Quick Connect MUST store its Address history entry
  with the password removed, for every address form it accepts
  (`ftp://`, `ftps://`, `ftp:`, `//`, bare `user:password@host`).
- **FR-004**: The rule MUST remove everything from the first `:` (or
  `%3A`) of the user part up to the last `@` (or `%40`) of the address
  part. For a single typed value the part ends only at the first `/` or
  the end (a password may contain spaces and quotes); on the command line
  it also ends where a word ends, except inside a quoted URL. The rule
  MUST NOT change a value that has no `@` in that part or no `:` before
  it. *(Revised after the first independent review, which rejected the
  white-space/quote ending for single values.)*
- **FR-005**: When histories are loaded at start-up (core: the four
  histories in FR-001; FTP: Quick Connect Address), entries MUST be
  cleaned by the same rule; an entry that becomes identical to a more
  recent one MUST be dropped.
- **FR-006**: The rule MUST exist once, as a pure, unit-tested function
  shared by the core and the FTP plugin.

**F3 — navigation without a click**

- **FR-007**: The shared viewer host MUST still cancel every navigation
  away from its own document, and MUST hand a cancelled navigation (or
  a new-window request) to the viewer's link handler **only** when the
  engine reports it as initiated by the user.
- **FR-008**: Link clicks (mouse or keyboard) MUST keep working in the
  Markdown Viewer as today; the Code Viewer's behaviour MUST not change.

**F2 — remote image requests**

- **FR-009**: Remote image requests MUST identify as
  `TandemCommander-mdview`.
- **FR-010**: Remote image requests MUST neither store nor send cookies
  and MUST NOT perform automatic authentication.
- **FR-011**: A response with a status other than 2xx MUST be treated
  as a failed fetch (broken image), without reading its body.

**F7 — cancelled Master Password prompt (SFTP)**

- **FR-012**: When a newly typed SFTP password or passphrase is to be
  saved, the Master Password is in use but not entered, and the user
  cancels (or fails) the prompt, the secret MUST NOT be saved; the
  corresponding *Save* option MUST be turned off and shown unchecked;
  a connection started from the same dialog MUST still use the typed
  secret.

**F6 — random salts**

- **FR-013**: All random bytes the password manager uses for encryption
  salts and verifier data MUST come from the operating system's
  cryptographic random generator. Existing stored data MUST remain
  readable.

**F4 / F5 — viewer engine crash dumps**

- **FR-014**: The viewer engine MUST be started with crash upload to
  Microsoft disabled, through a single shared definition used by both
  viewers and by the warm-engine keeper.
- **FR-015**: The WebView2 integration contract
  (`architecture/11-webview2-integration.md`) MUST state the new
  environment rule, and MUST correct its description of what the user
  data folder holds (F5).

**Records**

- **FR-016**: `PRIVACY.md` MUST be updated in the same change to
  describe the fixed behaviour (F1 limitation removed, F7 limitation
  removed, the new identification, cookies, no automatic navigation,
  crash dumps kept locally), with its validity line updated.
- **FR-017**: `CHANGELOG.md` *Unreleased* MUST describe each user-visible
  change in the user's terms, including the limitations that remain.
- **FR-018**: `specs/NEXT-WORK.md` item 7 MUST record F1–F7 as fixed
  (F9 and the 083 open question about F8 stay recorded).
- **FR-019**: The plugin interface MUST NOT change (interface 106): no
  new exported function, no changed signature, no change under
  `src/plugins/shared/`.

### Key Entities

- **History entry**: a remembered value of a field (text, UTF-8),
  kept in a fixed-size, most-recent-first list per field, saved to the
  registry with the configuration.
- **Address part**: the portion of a typed value between a scheme or
  file-system prefix and the start of the path, holding
  `[user[:password]@]host[:port]`.
- **Stored secret**: an SFTP/FTP password or passphrase saved either
  encrypted (Master Password) or scrambled (no Master Password).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After typing a known password in each of the five entry
  points (Quick Connect, Change Directory, core Copy/Move target, FTP
  download target, command line) and saving the configuration, a search
  of the program's registry key and of an exported configuration finds
  the password **0 times**.
- **SC-002**: The shared stripping rule passes a unit-test table of at
  least 40 cases covering every edge case above, with **0 failures**,
  and the full existing unit test suite still passes (≥ 1647 checks,
  0 failed).
- **SC-003**: A Markdown test document with automatic navigation (to an
  external address, to a relative `.md`, to a local file) opens **0**
  browser windows, viewer windows or message boxes in 30 seconds; a
  click on an ordinary link opens it **1** time.
- **SC-004**: A local logging web server sees **0** `Cookie` headers and
  only the `TandemCommander-mdview` identification over two rounds of
  remote-image loading; its "404" image is shown broken.
- **SC-005**: Passwords saved by 0.1.8 (with and without a Master
  Password) are all still readable by the new version — **100 %**.
- **SC-006**: After a cancelled Master Password prompt, the bookmark's
  stored data contains **no** password blob.
- **SC-007**: Debug and Release builds of the whole product succeed
  with no new warnings in the touched files; the plugin interface
  version stays 106.

## Assumptions

- The connection itself keeps receiving the full typed value; only the
  copy kept for history is changed (no change to how addresses are
  parsed for connecting).
- Stripping changes what a recalled history entry contains: recalling
  it needs the password again (by the password field, a bookmark, or
  typing it). This is the intended trade-off.
- Cleaning at load relies on the next configuration save to rewrite the
  registry; no separate registry migration and no configuration
  version change is made (constitution: MINORB release must not
  migrate configuration).
- Histories not listed in FR-001 hold masks, names or search text, not
  addresses (inventory: `research.md`), and are left alone.
- Places that record the panel's *location* (Working Directories,
  panel tabs, hot paths, per-drive last folder) store the path the
  plugin reports back, which for FTP never contains the password
  (verified, `research.md`); they are out of scope. SFTP does not accept
  a password in an address at all.
- `IsUserInitiated` reported by the viewer engine is the authority for
  "the user did it"; a link activated by the keyboard counts.
- The viewer engine's other diagnostic data remains governed by
  Microsoft and the user's Windows settings, as `PRIVACY.md` already
  says.
- GUI verification of the stories needs a person (the session cannot
  drive the application on screen reliably); automated evidence is
  provided where the code allows it (unit tests, a fetch probe against a
  local server, builds), and the GUI steps are recorded as owed.
