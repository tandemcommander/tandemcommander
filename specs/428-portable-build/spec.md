# Feature Specification: Portable build of Tandem Commander

**Feature Branch**: `428-portable-build`
**Created**: 2026-11-14
**Status**: Clarified — 15 answers in three passes (2026-11-14); the remaining low-impact points
take the recommendations of the catalogue ([clarify-questions.md](clarify-questions.md), *Status*)
**Input**: The maintainer's request (Czech, paraphrased): a new kind of build — a *portable*
version. It needs no installation: download a ZIP archive, unpack, run. It never touches the
Windows registry; everything the program stores today in the registry and elsewhere lives in one
file or folder created next to `tandemcommander.exe`, so the program can be carried to another PC
with all its settings. `build.cmd` gets a new argument `portable` (e.g. `build.cmd full release
rebuild portable`) that switches the build into this mode. Open questions: whether a portable copy
should check for new versions and offer installing them (probably not — perhaps only the check);
how the program says it is portable (e.g. `[portable]` in the main window title, certainly in the
About box); whether the application icon should differ. All ambiguities and the detailed analysis
go to the interactive clarify phase.

**Supporting material**: [state-inventory.md](state-inventory.md) — every place the program
stores or reads state outside its folder today (measured, with file:line).

> **How to read this draft.** Where the request leaves a choice open, the spec states a
> *provisional* answer and cites its question in the catalogue as **(Q-nn)**. The clarify session
> confirms or replaces each one; nothing here is final until then.

## Clarifications

### Session 2026-11-14

- Q: Is the portable edition a separate executable produced only by `build.cmd … portable`, or one
  shared executable switched to portable mode by a marker next to it? (Q-07) → A: **a separate
  executable fixed at build time** — the portable exe is always portable and never uses the
  registry; the normal exe is never portable; a release carries two different (separately signed)
  programs.
- Q: Where does the portable copy keep its state, and where the web viewers' engine data (WebView2
  caches, tens of MB)? (Q-01, Q-02, Q-03) → A: **a folder `settings` (lower-case) next to the
  exe** with the configuration file, bug reports and backups; **the WebView2 data in `%TEMP%`**,
  deleted at exit (and after a crash at the next start) — measured: it holds only caches and the
  engine's bookkeeping, nothing the viewers need.
- Q: What does the portable copy do about new versions? (Q-13, Q-14) → A: **checks as the installed
  program** (on by default, about once a day, and on request); the notification only links to the
  release page; nothing is downloaded or installed; Configuration > General keeps only the check
  on / off; a release is offered only when it carries the portable ZIP. Self-update of the
  portable copy is not part of this feature.
- Q: Does the portable edition get a different icon, and is it a separate taskbar group? (Q-21,
  Q-22) → A: **the program icon with a portable badge** in all sizes (light and dark), only the
  program icon; **a separate taskbar group** with its own pinning.
- Q: How does the portable edition handle the Explorer integration (shell extension), needed to
  drag / copy from archives and plug-in file systems to Explorer? (Q-05) → A: **never registered,
  no option**; the DLLs are not packaged; the action tells the user it is unavailable in the
  portable edition instead of silently doing nothing.
- Q: What does the portable copy do when its folder cannot be written? (Q-09) → A: **starts with the
  saved (or default) settings, says once that changes cannot be saved, never saves anywhere
  else**; the same message when a save fails later, the last complete settings stay intact.
- Q: Are a portable copy and the installed program (or portable copies from different folders)
  running at once fully independent programs? (Q-11) → A: **yes — each portable folder is its own
  world**: instance check, save lock and update-check claim see only copies from the same folder.
- Q: Can the portable copy take over the installed copy's settings, and does it keep the Salamander
  import? (Q-12) → A: **no new command** — settings move only by *Export Configuration* →
  *Import Configuration* (both ways); the Salamander import stays in the menu, its first-start
  offer is dropped in the portable copy.
- Q: What happens to stored paths that point into the portable folder when the drive letter
  changes on another PC? (Q-17) → A: **converted automatically** — at save, any path inside the
  portable folder is stored relative (`$(SalDir)\…`) and resolved against the current location at
  load; paths elsewhere stay absolute; old absolute paths are not rewritten after a move.
- Q: What is the portable ZIP called and how is it laid out? (Q-26) → A:
  **`tandemcommander-<version>-x64-portable.zip`** with one top-level folder
  **`TandemCommander-<version>-portable\`**.
- Q: Is the portable ZIP a mandatory part of every release? (Q-29) → A: **yes** — every release
  attaches it under its exact name next to the installer; `RELEASE.md`, `/tandem-release` and
  `release.py` check it.
- Q: What exactly does the title show, and is the marker translated? (Q-19) → A:
  **`Tandem Commander 0.3.0 [portable]`**, the word untranslated in every language; with
  administrator rights `… [portable] (Administrator)`.
- Q: What does the About box say about the portable edition, and does the splash change? (Q-20)
  → A: **a "Portable edition" line plus the `settings` path as a link** that opens it in the
  active panel; the splash is unchanged.
- Q: Does the portable copy warn when passwords are saved without a master password? (Q-16) → A:
  **once, at the first password saved without a master password**, with an offer to set one and a
  "Do not show this again" option; saving is never blocked.
- Q: How does `build.cmd` combine `portable` with the other arguments, and where does the output go?
  (Q-24, Q-25) → A: **`portable` in Debug and Release**, output `<Config>_x64_portable\`, the ZIP
  only with `full release portable` into `setup\output\`; `release portable` without `full` and
  `portable setup` are errors; one run = one edition. **Maintainer's addition:** one command
  builds and signs a complete release — `build.cmd dist` = today's `full release rebuild sign
  setup` plus the signed portable ZIP (name `dist` chosen in this session; the maintainer may rename
  it).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Run the program from an unpacked folder without installing (Priority: P1)

A user downloads the portable ZIP, unpacks it into any writable folder (a USB stick, a folder in
their profile, a network share), and starts `tandemcommander.exe`. The program starts with default
settings, works fully (panels, viewers, archives, enabled plug-ins), and everything the user
changes — configuration, plug-in settings, history, hot paths, bookmarks, saved passwords — is
kept in the program's own settings location next to the executable. Nothing is written to the
Windows registry or to the user's profile folders.

**Why this priority**: this is the whole point of the feature; everything else builds on it.

**Independent Test**: on a clean Windows user account, take a registry and profile-folder snapshot,
unpack the ZIP, start the program, change a representative set of settings in every
Configuration page and in every enabled plug-in, use history, hot paths, FTP / SFTP bookmarks,
viewers (including the web-based ones), close; take the snapshot again. The difference contains
nothing the program created or changed (Windows' own bookkeeping excepted, see FR-007). The
settings location next to the executable holds all the changes, and a second start shows them.

**Acceptance Scenarios**:

1. **Given** a freshly unpacked portable folder and no settings location yet, **When** the user
   starts the program, **Then** it starts with default settings and creates its settings location
   next to the executable no later than the first save.
2. **Given** a portable copy whose settings were changed and saved, **When** the user starts it
   again, **Then** every changed setting is back exactly as saved.
3. **Given** a portable copy, **When** the user uses any feature of the program and of the enabled
   plug-ins, **Then** no key or value under `HKEY_CURRENT_USER` or `HKEY_LOCAL_MACHINE` is created,
   changed or deleted by the program, except where the user explicitly asks to change a Windows
   setting (FR-008).
4. **Given** an installed Tandem Commander on the same PC with its own settings, **When** the user
   runs the portable copy (at the same time or not), **Then** the installed copy's settings stay
   untouched and the portable copy does not read them, not even as an offer; settings move between
   the two only by the user's *Export Configuration* → *Import Configuration* (Q-12).

---

### User Story 2 - Carry the program to another PC with all its settings (Priority: P1)

A user copies the whole portable folder (or the USB stick it is on) to another PC — possibly with
another drive letter, another user name, another Windows language — and starts it there. The
program behaves exactly as on the first PC: same configuration, same plug-in settings, same
bookmarks and saved passwords, same history.

**Why this priority**: carrying the settings along is the user-visible value of "portable"; a copy
that runs but forgets or breaks its settings on another machine fails the request.

**Independent Test**: configure a portable copy on PC A (including paths that point into the
portable folder itself — e.g. a user-menu item or a hot path to a tool inside it), copy the folder
to PC B under another drive letter and user name, start it; every setting is present, and paths
that pointed into the portable folder still work (Q-17).

**Acceptance Scenarios**:

1. **Given** a configured portable copy on PC A, **When** the folder is copied to PC B and started,
   **Then** all settings, plug-in settings, bookmarks and saved passwords are present and usable.
2. **Given** the portable folder moved to a different drive letter, **When** the program starts,
   **Then** the plug-ins of the folder load and items that referred to files inside the portable
   folder still find them (Q-17).
3. **Given** saved passwords protected by a master password on PC A, **When** the copy runs on PC B,
   **Then** the same master password unlocks them; without it they stay unreadable (Q-16).
4. **Given** a portable copy with no master password, **When** the user saves the first password,
   **Then** a one-time note says saved passwords travel with the folder and offers to set a master
   password; the password is saved either way (FR-015a).

---

### User Story 3 - Build the portable package with one command (Priority: P1)

The maintainer runs `build.cmd` with the `portable` argument (e.g. `build.cmd full release rebuild
portable`, optionally with `sign`) and gets the portable program and a ready-to-publish ZIP
archive, without affecting the normal (installer) build. For a release, one command — `build.cmd
dist` — builds and signs everything: the installer and the portable ZIP.

**Why this priority**: without a reproducible build there is nothing to download (constitution I,
build reproducibility).

**Independent Test**: from a clean checkout, run the portable build; a ZIP with the documented
name appears in the documented place; unpacked, it passes User Story 1. Run the normal build
afterwards; its output and the installer are the same as without the portable build ever having
run.

**Acceptance Scenarios**:

1. **Given** a clean checkout, **When** the maintainer runs `build.cmd full release portable`,
   **Then** the build produces a portable output separate from the normal output and one ZIP archive
   named `tandemcommander-<version>-x64-portable.zip` with one top-level folder
   `TandemCommander-<version>-portable\` (Q-25, Q-26).
2. **Given** `portable` combined with `setup`, **When** the build starts, **Then** it stops before
   any work with a clear error (an installer of a portable program makes no sense) (Q-24).
3. **Given** `portable` combined with `sign`, **When** the build ends, **Then** every shipped binary
   inside the ZIP is signed and verified exactly as in the signed normal build.
4. **Given** `build.cmd help`, **When** the maintainer reads it, **Then** `portable` and `dist` are
   documented with their combinations.
5. **Given** a clean checkout with signing configured, **When** the maintainer runs `build.cmd
   dist`, **Then** one run produces the signed installer and the signed portable ZIP of the version
   in `setup\output\` and lists both with size and SHA-256 — nothing else needs to be run.
6. **Given** `build.cmd dist` and a failure in any step (build, signing, installer, ZIP), **When**
   the run ends, **Then** it exits non-zero, says which step failed, and no unsigned or partial
   release file is left that looks finished.
7. **Given** `build.cmd portable` (Debug), **When** it ends, **Then** the portable program is in
   `build\tandemcommander\Debug_x64_portable\` and the normal `Debug_x64\` tree is untouched.

---

### User Story 4 - See that this copy is the portable one (Priority: P2)

A user who has both an installed and a portable Tandem Commander can always tell which one is
running: the main window title says so (e.g. `Tandem Commander 0.3.0 [portable]`), the About box
says it is the portable edition and where its settings are stored, and the program icon carries a
portable badge.

**Why this priority**: prevents confusion ("why are my settings gone?") but is not needed for the
program to work.

**Independent Test**: start the portable copy; the title and the About box show the portable
marker in every enabled language; the installed build shows neither.

**Acceptance Scenarios**:

1. **Given** the portable copy running, **When** the user looks at the main window title (and the
   taskbar / tray tooltip that reuse it), **Then** it reads `Tandem Commander <version> [portable]`
   (plus ` (Administrator)` when elevated) in every language (Q-19).
2. **Given** the portable copy, **When** the user opens *Help > About*, **Then** it shows the line
   "Portable edition" and the path of the `settings` folder as a link; **When** the user activates
   the link, **Then** the box closes and the active panel shows the `settings` folder (Q-20).
3. **Given** the installed (normal) build, **When** the user looks at the title and the About box,
   **Then** they are unchanged from before this feature.
4. **Given** both copies running, **When** the user looks at the taskbar, Alt+Tab or Explorer,
   **Then** the portable copy shows the program icon with the portable badge and has its own taskbar
   button group; pinning it pins the portable executable, not the installed one.

---

### User Story 5 - Learn about a newer version in the portable copy (Priority: P3)

A portable user is told that a newer release exists — by the same check as the installed program
(on by default, about once a day after start-up, and on request) — and is pointed to the release
page with the portable ZIP; the program never downloads or runs anything from a portable copy.

**Why this priority**: useful, but a portable user can update by downloading a new ZIP by hand.

**Independent Test**: with the update-check fixture (feature 123's probe seam) announcing a newer
release, the portable copy shows the notification with a link to the release page, offers no
*Download* / *Install* and starts nothing; no update files appear anywhere. A release without the
portable ZIP asset is not offered to the portable copy.

**Acceptance Scenarios**:

1. **Given** a newer release published with its portable ZIP, **When** the portable copy checks (at
   start-up or on request), **Then** it shows a notification with a link to the release page, never
   *Download & Install* or *Install Now*.
2. **Given** a newer release published **without** the portable ZIP, **When** the portable copy
   checks, **Then** it offers nothing: the check at start-up stays silent, and a check the user
   starts says the release could not be checked (the installed copy is offered the release as
   today; contracts/update-check-portable.md - aligned 2026-11-14 after the test review).
3. **Given** the portable copy, **When** the user opens Configuration > General, **Then** only the
   check on / off option is there; the *When a new version is found* level list is not shown.
4. **Given** the user switched the check off, **When** the program starts, **Then** it contacts no
   server on its own; *Help > Check for New Version* still works.

---

### User Story 6 - Start where the folder cannot be written (Priority: P3)

A user starts the portable copy from a place that cannot be written (read-only media, a protected
folder such as Program Files without administrator rights, a read-only share).

**Why this priority**: a rarer situation, but it must never lose data silently or fall back to the
registry.

**Acceptance Scenarios**:

1. **Given** a portable folder that cannot be written, **When** the program starts, **Then** it
   starts with the saved settings (or the defaults when there are none), tells the user once per
   session that changes cannot be saved there, works normally (the web viewers too — their data is
   in the temporary folder), and writes the settings nowhere else.
2. **Given** a settings location that becomes unwritable while the program runs (stick removed,
   disk full), **When** the program saves, **Then** the user is told the same way and the previously
   saved complete settings stay intact.
3. **Given** a session started on an unwritable folder, **When** the user closes the program,
   **Then** no save is attempted that could damage the saved settings, and no second warning
   appears at exit.

---

### Edge Cases

- **Settings damaged or half-written** (power loss or a removed stick during a save): the next start
  gets the last complete settings, never an empty or corrupt configuration (the counterpart of
  today's backup key, inventory §1).
- **Two instances of the same portable copy** at once: they share one settings location; saving
  follows the same rules as two instances of the installed program today (the last one to save
  wins; *Save configuration on exit* semantics unchanged); *Only one instance* activates the copy
  already running from the same folder (FR-011a).
- **A portable copy and an installed copy running at once**, or two portable copies from different
  folders: fully independent programs — neither sees the other as "another instance", they share
  no save lock, update-check claim or settings (FR-011a, Q-11).
- **The folder moved or renamed while the program runs**: provisional — not supported; the next
  start in the new place works (Q-18).
- **Paths inside the settings that point into the portable folder** (user menu, viewers, editors,
  hot paths, archivers, custom icon / toolbar files): stored relative to the program folder, so a
  move or another drive letter does not break them (FR-012). Absolute paths of the old location
  that come from elsewhere (an imported configuration, a value typed with another drive letter)
  are not rewritten. A path that points to a drive that no longer exists behaves as today.
- **A path or name in the settings location's own path** that is long or non-ASCII (`D:\Nástroje\…`,
  deep folders): the program works there as anywhere else; the location path is never cut (the
  standing rule on paths).
- **A network share** (UNC path) as the program folder: works like a local folder; locking /
  latency is not specially handled (Q-10).
- **An older configuration file** (from an older portable release) found at start: it is read and
  carried forward like the installed program's settings across versions (constitution II).
- **Moving to a new version**: the new ZIP unpacks into its own versioned folder
  (`TandemCommander-<version>-portable\`), so the old copy and its `settings` stay untouched; the
  user carries the settings over by copying the `settings` folder into the new one (the README says
  so, Q-28). The new version reads the older settings as the installed program reads older
  registry settings (constitution II).
- **A newer configuration file** (the folder used by a newer release, then an older ZIP unpacked
  over it): provisional — the older program must not damage it; it behaves as the installed
  program does with newer registry settings today.
- **The upstream start-up import `config.reg` next to the executable** (inventory §4): in the
  portable copy it must not import into the registry; Q-07 decides whether it is ignored or used as
  a seed.
- **The shell extension** cannot be registered without writing the registry: in the portable copy
  dragging or copying to the clipboard from archives and plug-in file systems to Explorer is not
  available and says so (FR-006a); disk-to-Explorer drag and drop and pasting / dropping into the
  program keep working (Q-05).
- **Set as wallpaper** (PictView) changes a Windows setting by the user's explicit request (Q-06).
- **Windows' own traces** — jump list, recent files, Restart Manager registration, Explorer's view
  state, the Mark of the Web of the downloaded ZIP: Q-04 and Q-27.
- **Plug-ins** (also third-party ones built against the plug-in API) store their settings through
  the program and must keep working unchanged in the portable copy (constitution V; ABI
  append-only).
- **The settings import from Altap / Open Salamander** (feature 245) reads their registry keys
  read-only: it stays in the menu of the portable copy (the user starts it; the result and its
  backup go into `settings`); the offer at the first start of a fresh configuration is not made in
  the portable copy (Q-12).

## Requirements *(mandatory)*

### Functional Requirements

**Build and package**

- **FR-001**: `build.cmd` MUST accept a `portable` argument, order-independent like the others,
  combinable with `rebuild`, `release`, `full` and `sign`, in Debug and Release; it MUST be
  documented in `build.cmd help`. Without `full release` it builds the portable program only (for
  development); the ZIP is produced only by `full release portable`; `release portable` without
  `full` and `portable setup` MUST stop before any work with an error message. One run builds one
  edition — except `dist` (FR-001a) (Q-24).
- **FR-001a**: `build.cmd dist` MUST build a **complete release with one command**: a clean rebuild
  of the normal edition in Release with everything (`full`), signed, with the signed installer —
  what `build.cmd full release rebuild sign setup` does today — **and** a clean rebuild of the
  portable edition in Release with everything, signed, with the portable ZIP. It stops at the first
  failure with a non-zero exit code and never leaves an unsigned artefact in `setup\output\`
  looking finished; it refuses to start when signing is not configured (a release is never
  unsigned). At the end it lists the produced release files (installer and ZIP) with their size
  and SHA-256. Other arguments next to `dist` are refused (Q-24, maintainer's addition).
- **FR-002**: The portable build MUST produce its output separately from the normal build —
  `build\tandemcommander\<Config>_x64_portable\` next to `<Config>_x64\` — so that neither build
  changes the other's output, and the installer always packages the normal program; the ZIP goes to
  `setup\output\` next to the installer (Q-25).
- **FR-003**: The portable build MUST produce one ZIP archive that contains everything needed to run
  on a supported Windows 11 PC — the program, the enabled plug-ins and languages (the same policy
  files `plugins.cfg` / `languages.cfg` as the normal build), runtime data, the application-local
  Visual C++ runtime, the licence texts — and nothing that is not shipped by the installer (debug
  symbols, link libraries) and not the shell extension DLLs (FR-006a) (Q-28). The archive is named
  **`tandemcommander-<version>-x64-portable.zip`** (the counterpart of the installer's
  `tandemcommander-<version>-x64-setup.exe`; the portable copy's new-version check relies on this
  name, FR-017) and holds exactly one top-level folder **`TandemCommander-<version>-portable\`**
  with the program inside; it contains no `settings` folder (Q-26).
- **FR-004**: The portable package MUST be reproducible from the repository alone with the same
  prerequisites as the normal build; signing follows the same rules as the normal build (only with
  `release sign`; Microsoft runtime DLLs never re-signed).

**Where the portable copy keeps its state**

- **FR-005**: The portable copy MUST keep all its persistent state — the configuration, every plug-in's
  configuration, histories, hot paths, bookmarks, known SFTP host keys, saved passwords and the
  master-password check, the update-check state if any, the backup of the configuration — in one
  folder named `settings` (lower-case) next to `tandemcommander.exe` — the configuration as one
  file inside it, plus sub-folders for bug reports and backups (Q-01, Q-02). Its size stays small
  (no caches); it is created no later than the first save.
- **FR-006**: The portable copy MUST NOT create, change or delete any registry key or value
  (`HKEY_CURRENT_USER`, `HKEY_LOCAL_MACHINE`, `HKEY_CLASSES_ROOT`) on its own; in particular it MUST
  NOT run the configuration-root migration, the upgrade / old-configuration search, or register the
  shell extension (Q-05). Reading the registry for information about the system (file
  associations, drives, policies, theme) stays allowed.
- **FR-006a**: The portable copy MUST NOT register the shell extension in any form (no option to
  switch it on), and the package MUST NOT contain its DLLs. Where the installed program needs the
  extension — dragging or copying to the clipboard from an archive or a plug-in file system to
  Explorer or another program — the portable copy MUST tell the user that this is not available in
  the portable edition (and how to get the file out: copy or unpack it to a disk folder first)
  instead of silently doing nothing (Q-05).
- **FR-007**: The portable copy MUST NOT write files outside its own folder except transient working
  files in the system temporary folder that it cleans up: the archive extraction cache and list
  files (as today) and **the web viewers' engine data** (WebView2 — shader, code and HTTP caches
  and the engine's own bookkeeping, measured 27 MB / 373 files; the viewers store nothing in it
  they need, Q-03). The engine data lives in a per-copy temporary folder that the program deletes
  at exit, and a leftover of a crashed session at the next start. Bug reports, import backups, the
  default export folder and the wallpaper image MUST go inside the portable folder (Q-06, Q-08).
  Data Windows keeps
  about any program it runs (prefetch, jump lists, recent documents, Explorer view state, Restart
  Manager) is outside this requirement unless Q-04 decides otherwise.
- **FR-008**: An action whose stated purpose is to change Windows (PictView *Set as wallpaper*, the
  Registry Editor plug-in editing the registry, file operations the user starts) MAY change Windows
  as asked; any bookkeeping the program keeps about it (e.g. the previous wallpaper) goes into the
  portable settings location (Q-06).
- **FR-009**: Plug-ins MUST store and load their configuration in the portable copy without any
  change to them; the plug-in interface stays binary compatible (constitution V).
- **FR-010**: Saving the settings MUST never leave the only copy half-written: after an interruption
  at any point of a save, the next start finds either the old or the new complete settings.
- **FR-011**: When the settings location cannot be created or written, the program MUST NOT fall back
  to the registry, to the user's profile or to any other folder. It starts with the saved settings
  (or the defaults), tells the user once per session that changes cannot be saved, and otherwise
  works normally; a save that fails later (stick removed, disk full) shows the same message and
  leaves the last complete settings intact (FR-010) (Q-09).
- **FR-011a**: Every cross-process coordination of the portable copy — the *Only one instance*
  check and activation, the configuration load / save lock, the update-check claim, any other
  named lock or instance detection — MUST be scoped to its portable folder: copies started from the
  same folder coordinate as two instances of the installed program do today; copies from different
  folders and the installed program never see, activate or block each other (Q-11).
- **FR-012**: Every path the portable copy stores in its settings that lies inside its portable
  folder (plug-ins and anything the user entered: user-menu items, external viewers / editors /
  archivers, hot paths, custom files) MUST be stored relative to the program folder — as the
  store's own token `$(PortableDir)` in the settings file — and resolved against the current
  location at load, so it keeps working after the folder moves to another path or drive letter.
  Paths outside the portable folder stay as the user entered them; a `$(SalDir)` the user typed
  stays exactly as typed (implementation note, 2026-11-14: the clarification named `$(SalDir)` as
  the form; the gate test measured that the program's `$(SalDir)` ends with a backslash in commands
  and without one in initial folders, so reusing it would break `$(SalDir)tools\x.exe` — the store
  therefore uses a token of its own; the decision "relative, automatic" is unchanged). The settings
  dialogs show the resolved path, never a path cut short (Q-17).
- **FR-013**: The existing configuration export and import (*Export / Import Configuration*) MUST
  keep working in the portable copy, writing and reading files the user picks, and a file exported
  by either edition MUST import into the other — this is the only way settings move between an
  installed and a portable copy (no dedicated command, no offer). The settings import from Altap /
  Open Salamander stays available from the menu (reading their keys read-only, writing into the
  portable settings); its offer at the first start is not made in the portable copy (Q-12).

**Identity and behaviour visible to the user**

- **FR-014**: The portable copy MUST show the marker ` [portable]` right after the version in the
  main window title — `Tandem Commander 0.3.0 [portable]`, with administrator rights
  `Tandem Commander 0.3.0 [portable] (Administrator)`; any path / prefix part of the title stays in
  front as today. The word `portable` is the same in every language (not a translatable string).
  The taskbar button, Alt+Tab and the tray tooltip show it because they reuse the title (Q-19).
- **FR-015**: The About box of the portable copy MUST show, below the version, a translated line
  naming the portable edition ("Portable edition") and a line with the full path of the `settings`
  folder as a link; activating the link (mouse or keyboard) closes the box and opens that folder in
  the active panel. The path is shown whole or shortened only at whole characters with the full
  path available (tooltip), never cut silently. The splash screen is unchanged (Q-20).
- **FR-015a**: When the portable copy is about to save the first password (FTP, SFTP, encrypted
  archive, any user of the program's password store) while no master password is set, it MUST tell
  the user once that saved passwords travel with the portable folder and can be read by anyone who
  has it, and offer to set a master password now; the user can go on without one and can tick
  "Do not show this again" (kept in the portable settings). Saving the password is never blocked.
  The installed program does not show this (Q-16).
- **FR-016**: The portable executable MUST carry the program icon with a portable badge (e.g. a
  USB-stick mark in a corner) in every size the program icon has, legible in the light and dark
  taskbar / Explorer, made from the brand sources (`tools/brand/`); it is used wherever the program
  icon appears (executable, main window, taskbar, tray, Alt+Tab, About box). Toolbar, menu and
  other UI icons are unchanged. The portable copy MUST be its own taskbar group with its own
  pinning, separate from the installed copy (Q-21, Q-22).
- **FR-017**: The portable copy MUST check for a newer version exactly as the installed program
  (the same request, on by default, about once a day, and on request from *Help* and the About
  box); its notification MUST only link to the release page — it MUST NOT download or run anything,
  and it MUST NOT show any update level that downloads or installs (Configuration > General keeps
  only the check on / off). A release is offered to the portable copy only when it carries the
  portable ZIP asset under its documented name (Q-26). The update-check state is kept in the
  portable settings (FR-005) (Q-13, Q-14).
- **FR-018**: The installed (normal) build MUST behave exactly as before this feature: same title,
  About box, settings root, update behaviour, shell extension (constitution II). The edition is
  fixed when the program is built: nothing found next to a normal (installed) executable — a
  settings folder copied from a portable copy, any marker file — switches it into portable mode,
  and nothing switches a portable executable to the registry (Q-07).

**Documentation and public claims**

- **FR-019**: `PRIVACY.md` MUST describe the portable copy in the same change: what it stores and
  where, what it does not write, whether it contacts the network (CLAUDE.md, public claims).
- **FR-020**: From the first release after this feature, **every release MUST publish the portable
  ZIP** next to the installer, attached to the GitHub release under its exact name (FR-003). The
  release procedure MUST say so: `backlog/RELEASE.md` (*Release records* and the maintainer's
  steps: `build.cmd dist` replaces `build.cmd full release sign setup` as the one build step, then
  attach both files), `/tandem-release` and `tools/release/`
  check that the package of the version can be built / is present, as they do for the installer.
  The help / README MUST tell users how to use, update and remove the portable copy (delete the
  folder) (Q-29).

### Key Entities

- **Portable package**: the ZIP archive published for download, one per version:
  `tandemcommander-<version>-x64-portable.zip` with one top-level folder
  `TandemCommander-<version>-portable\` (Q-26); extra files per Q-28.
- **Portable folder**: the unpacked package anywhere the user chooses; contains the program, plug-ins,
  languages, runtime, and — once used — the settings location.
- **Settings location**: the folder `settings` next to the executable holding all persistent state
  of FR-005 (configuration file, bug reports, backups); no caches; survives copying the portable
  folder (Q-01, Q-02).
- **Web-engine scratch folder**: the web viewers' engine data of one portable copy in the system
  temporary folder; created on the first use of a web viewer, deleted at exit (or at the next
  start after a crash); never part of the portable folder (Q-03).
- **Portable edition**: the property that makes a program a portable copy — fixed when the
  executable is built by `build.cmd … portable`, never chosen at run time (Q-07); decides the
  behaviours of FR-005 to FR-018. The normal and the portable executable are two different
  programs of the same version.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can go from the downloaded ZIP to a running program in under 1 minute, with no
  administrator prompt and no installer.
- **SC-002**: After a scripted session that uses every Configuration page, every enabled plug-in's
  settings and the web viewers, a before / after comparison of the registry (`HKCU`, `HKLM`,
  `HKCR`) shows **0** keys or values created, changed or deleted by the program, and the user's
  profile folders (`%APPDATA%`, `%LOCALAPPDATA%`) show **0** files or folders created by it
  (excluding Windows' own bookkeeping of Q-04); after the program has closed, the transient files
  of FR-007 (the temporary folder, `%LOCALAPPDATA%\Temp`, included) are gone too. The `settings`
  folder holds no cache: its size does not grow with the use of the viewers.
- **SC-003**: After copying the portable folder to another PC (or another drive letter and user
  account), **100 %** of a checked list of settings (at least one per Configuration page and per
  enabled plug-in, plus bookmarks, history, hot paths and a saved password) are present and usable.
- **SC-004**: Deleting the portable folder removes **everything** the program kept: nothing of it
  remains on the PC that a later portable or installed copy would pick up.
- **SC-005a**: The maintainer produces every file of a release (signed installer and signed portable
  ZIP) with exactly **one** command and no further manual step before attaching them.
- **SC-005**: One `build.cmd` command produces the ZIP from a clean checkout; two portable builds of
  the same commit produce packages with the same file list and the same program files (apart from
  signing time stamps).
- **SC-006**: Interrupting the program during a settings save (kill at random points, 20 runs) never
  leaves a start with lost or default settings when complete settings had been saved before.
- **SC-007**: With an installed and a portable copy on the same PC, changing a setting in one never
  changes it in the other (checked both ways for at least 10 settings).
- **SC-008**: A user who sees only the main window or only the About box can tell which copy runs, in
  every enabled language.
- **SC-009**: Start-up time and the time to save the settings of the portable copy are within 10 % of
  the installed copy on the same PC (local disk).
- **SC-010**: The normal build and installer produced after this feature have an unchanged file list
  and unchanged behaviour in the existing GUI probes of the areas this feature touches.

## Assumptions

- Supported target is the same as the normal build: Windows 11 and newer, x64. WebView2 Runtime is
  part of Windows 11; the portable copy does not ship it. The Visual C++ runtime is already
  application-local in Release (077).
- "Never touches the registry" means the program's own writes. Windows itself records that a
  program ran (prefetch, jump lists, recent files, Explorer state, the Mark of the Web on a
  downloaded ZIP); preventing that is not possible from the program and is out of scope unless
  Q-04 / Q-27 decide to switch off the program's own contributions (e.g. its jump list).
- Reading the registry for system information (associations, drives, policies, theme, network) is
  allowed; it changes nothing.
- The transient temporary folder use (archive extraction cache, list files, the web viewers' engine
  data) is in `%TEMP%`; it is cleaned up and holds no settings (Q-03). Opening a web viewer for the
  first time in a session may be slower than in the installed copy (the engine rebuilds its cache);
  the plan measures it.
- The plug-in set, languages and features are the same as the installed program's; no feature is
  removed from the portable copy except those that cannot work without a registry write (the shell
  extension, Q-05) or installing (self-update).
- The saved passwords are as portable as they are today: the program does not bind them to the
  machine or the Windows account (inventory §1); a user who wants protection on a lost stick uses
  the master password, and the portable copy tells them so once (FR-015a, Q-16).
- Release, tag, GitHub publishing and a possible winget entry remain the maintainer's steps; this
  feature prepares the build, the release procedure that makes the ZIP a required asset (FR-020)
  and the documentation; a winget entry for the portable package is not part of it (Q-30).
- No version or build number changes in this feature; the changelog gets an entry under the
  unreleased heading.
- New UI strings (the About lines, the unwritable-location message, the shell-extension and password
  notes; the title marker `[portable]` is not translated) go
  through the two-stage `.slt` refresh inside this feature (CLAUDE.md).
