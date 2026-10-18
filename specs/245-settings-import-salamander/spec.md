# Feature Specification: Import settings from Altap Salamander and Open Salamander

**Feature Branch**: `245-settings-import-salamander`
**Created**: 2026-10-18
**Status**: Draft
**Input**: User description (Czech, summarised): "A new *onboarding*
capability: analyse in detail and implement the transfer (import) of settings
from older versions of Open Salamander or Altap Salamander. A user starts
Tandem Commander and can launch, from the Options menu, a wizard that imports
settings from an older Open Salamander or Altap Salamander. Essential: the
import must not break the correct working of the current Tandem Commander —
e.g. associations of files to programs and plugins. It must be
non-destructive but beneficial — e.g. transfer of hot paths (bookmarks),
stored FTP connections, keyboard shortcuts and more. Ideally a multi-step
process in which the user chooses which settings to transfer and in which
mode — overwrite, or keep the current ones and add the transferred ones, etc.
Analyse the options in detail and produce the analysis and the
implementation plan."

The evidence behind every statement about today's product is in
[analysis.md](analysis.md) (file:line references, read-only registry probe).

## Current behaviour (baseline, read from the 0.1.10 tree)

- Tandem Commander keeps its settings in its own registry key and, by a
  constitutional rule (Principle II, features 032 and 046), never reads or
  writes the settings of Open Salamander, Altap Salamander or Newt Commander.
  Nothing in the program offers to bring settings over.
- Feature 057 (released in 0.1.3) answered the same need **outside** the
  program: a downloadable console script in the source repository
  (`utils/migrate-altap-settings.cmd`), English only, Altap Salamander only,
  *replace*-only per category, backup and restore script, run while both
  programs are closed. Few users find it; it is not translated; it now stamps
  an older configuration version than the product uses (0.1.10 is one
  version ahead), so a Tandem Commander started after it performs an
  unnecessary one-time upgrade.
- *Options → Import Configuration…* today only explains how to load a
  `.reg` file exported from Tandem Commander itself.
- The original Open Salamander code that imported an older configuration at
  start-up is still present but inactive (only its list of old locations was
  removed). It replaced the whole configuration and could delete the old
  program's settings; it is not a basis for this feature.
- Keyboard shortcuts of Tandem Commander's own commands are fixed and cannot
  be changed (the Keyboard page of Configuration says so). What a user *can*
  assign are shortcuts of **plugin commands** (Plugins Manager → Keyboard),
  plus a few options that change how keys behave (e.g. quick search with
  Alt+letter, Shift+digit for hot paths).

## Clarifications

### Session 2026-10-18

- Q: Should Tandem Commander offer the import wizard on its own, once, when it starts with a fresh configuration and finds an old Salamander configuration, or only through the Options menu? → A: Options menu, plus a one-time offer at the first start with a fresh configuration when an old Salamander configuration exists; that start only checks that the old settings exist (reads none of them), and once the offer is answered either way it never appears again.
- Q: Once the wizard exists, what should happen to feature 057's standalone migration script `utils/migrate-altap-settings.cmd`? → A: Retire it: remove the script and its tests; the documentation and the changelog point to the wizard.
- Q: To merge imported FTP connections into the ones Tandem Commander already has, may the plugin interface get a new call (interface version 107 → 108; older plugins keep loading)? → A: Yes: an append-only import call in the plugin interface (interface 108, with a contract); the FTP plugin merges its own connections; other plugins can adopt it later.
- Maintainer directive (2026-10-18, when starting the plan): the 057 script overwrote some settings of the user's existing Tandem Commander; the wizard must never overwrite a current Tandem Commander setting unless the user explicitly allows it. → Applied as FR-010c: every overwriting choice (option groups, whole-plugin settings, *Replace* mode) is off by default and needs its own explicit consent; the default import only adds.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Bring hot paths and FTP connections over without losing anything (Priority: P1)

A long-time Altap Salamander user installs Tandem Commander, perhaps sets up a
few hot paths and an FTP connection of their own, and then wants the hot
paths, FTP connections (with their saved passwords) and user menu built up
over years in Altap Salamander. They open *Options → Import Settings from
Salamander…*. The wizard shows the Altap Salamander 4.0 settings it found,
lists what can be brought over with the number of items in each group, and
proposes *Add to my current settings* for each list. The user keeps hot
paths, FTP connections and user menu ticked, looks at the preview (what will
be added, what is already there, what cannot come over and why), confirms,
and reads the result. Their own Tandem Commander hot paths and FTP
connections are still there; the old ones are added beside them.

**Why this priority**: it is the whole value of the feature, and it is the
case the user named first; the non-destructive *add* mode is what makes it
safe to use on a Tandem Commander that is already in use.

**Independent Test**: on a Tandem Commander with 2 hot paths and 1 FTP
connection of its own and an Altap Salamander 4.0 configuration with 7 hot
paths (1 of them the same folder as a Tandem one) and 6 FTP connections, run
the wizard with only *Hot paths* and *FTP connections* in *Add* mode; then
Tandem Commander has 8 hot paths and 7 FTP connections, every connection
opens and logs in without retyping a scrambled-stored password, and no other
setting differs from before.

**Acceptance Scenarios**:

1. **Given** the situation above, **When** the import finishes, **Then** the
   2 existing hot paths keep their slots and shortcuts, the 6 new ones
   occupy their old slots where free and otherwise the first free slots, and
   the duplicate folder is reported as "already present" and not added.
2. **Given** an imported FTP connection whose name equals an existing Tandem
   Commander connection with different content, **When** it is added,
   **Then** the existing connection is unchanged and the imported one is
   added under a distinguishable name that the result names.
3. **Given** an imported FTP connection identical to an existing one,
   **When** the import runs, **Then** it is not added a second time.
4. **Given** the result page, **When** the user reads it, **Then** every
   selected group shows how many items were added, how many were already
   present, how many were skipped — and every skipped item is named with its
   reason.
5. **Given** the wizard ran with *Add* mode, **When** it is run again with
   the same choices, **Then** nothing is added twice.

---

### User Story 2 - The current Tandem Commander keeps working (Priority: P1)

Whatever the user imports, Tandem Commander keeps its own working state: the
plugins it ships (including those the old program never had, such as SFTP,
the Markdown and code viewers) stay installed and keep opening the files
they open today; archives are still handled by the archivers Tandem Commander
configures; its own new settings (dark theme, panel tabs, quick search
filter, command shell, language) are unchanged; Windows file associations
are not touched. The old program's settings are never changed.

**Why this priority**: the user called this essential. An import that breaks
the program it imports into is worse than no import.

**Independent Test**: take a Tandem Commander configuration with a
non-default theme, panel tabs on, a language set, the SFTP plugin with a
saved session and Markdown files opening in the Markdown viewer; import
*every* offered group in the mode that changes the most; then the plugin
list, the archiver settings, theme, tabs, quick search filter, language and
the Markdown association are exactly as before, every plugin still loads,
and an export of the old program's settings is identical before and after.

**Acceptance Scenarios**:

1. **Given** any import, **When** it ends, **Then** the set of installed and
   loadable plugins is the same as before the import.
2. **Given** an imported viewer association that pointed to an old plugin
   Tandem Commander does not ship (e.g. the IE viewer), **When** viewers are
   imported, **Then** that association is not imported and is reported, and
   no file type starts opening with a different plugin than before.
3. **Given** an old program configuration with its own archiver setup,
   **When** the categories are listed, **Then** archiver settings are shown
   as not transferable with the reason, and the user is pointed to
   *Archivers Autoconfiguration*.
4. **Given** any run — finished, cancelled, or failed — **When** the old
   program's settings are compared with their state before the run, **Then**
   they are identical.
5. **Given** any run, **When** it ends, **Then** no Windows-wide setting
   (file associations, shell registration) has been changed by it.

---

### User Story 3 - Choose what comes over and how (Priority: P2)

A user wants only some of the old settings, and for some of them wants the
old state to win. The wizard lets them tick each group independently and,
for each list-type group (hot paths, user menu, FTP connections, plugin
command shortcuts), choose between *Add to my current settings* (default;
nothing current is changed or removed) and *Replace my current settings*
(the group becomes what the old program had). Groups that are a set of
options rather than a list (colours, view templates, general options, …) are
taken over or left out; they are left out unless the user ticks them, because
taking them over overwrites current values (FR-010c). A preview before any change shows exactly
what each choice will do.

**Why this priority**: the user asked for the selection and the modes
explicitly; it turns a one-size import into one each user can trust.

**Independent Test**: select *Hot paths* in *Replace* mode and *User menu* in
*Add* mode, leave everything else out; the preview lists the hot paths that
will disappear and the user-menu items that will be added; after confirming,
the hot paths equal the old program's, the user menu is the old one appended
to the current one, and nothing else changed.

**Acceptance Scenarios**:

1. **Given** the group list, **When** the user unticks a group, **Then**
   nothing of that group is changed.
2. **Given** a group in *Replace* mode, **When** the preview is shown,
   **Then** it names the current items that will be removed and asks for an
   explicit confirmation of that loss.
3. **Given** a group that is not available in the chosen source (empty, or
   absent in that version), **When** the list is shown, **Then** the group is
   shown as not available with the reason and cannot be ticked.
4. **Given** any step before the final confirmation, **When** the user
   cancels, **Then** nothing has been changed.

---

### User Story 4 - Passwords stay usable and stay protected (Priority: P2)

Some users protected their stored FTP passwords in Altap Salamander with a
master password. The wizard explains that these passwords can come over only
if the user types the old master password; it checks the typed password
against the old program's record and then protects the passwords the way
Tandem Commander protects its own — under Tandem Commander's master password
when it has one. If Tandem Commander has no master password, the wizard says
that the passwords would be stored with weaker protection than before and
lets the user set a master password first, accept it, or leave the
passwords out. The user may skip the step: the connections then come over
without passwords and the result says which ones need the password again.

**Why this priority**: FTP connections without their passwords are only
half useful; silently weakening or breaking password protection would be a
security regression.

**Independent Test**: with an old configuration whose FTP passwords are
protected by a master password, run the import once typing the right master
password (every connection logs in afterwards) and once skipping the step
(connections present, passwords absent, each named in the result); in
neither run does Tandem Commander's own master password change.

**Acceptance Scenarios**:

1. **Given** a wrong old master password, **When** the user confirms it,
   **Then** the wizard says it is wrong and lets them retry or skip; nothing
   is imported with undecryptable passwords.
2. **Given** Tandem Commander already has its own master password, **When**
   passwords are imported, **Then** its master password and every password it
   already protects (FTP and SFTP) remain usable and unchanged.
3. **Given** Tandem Commander has no master password and the old passwords
   were protected by one, **When** the user reaches the step, **Then**
   passwords are never stored with weaker protection without the user's
   explicit consent on that step.
4. **Given** passwords stored without a master password in the old program,
   **When** connections are imported, **Then** they come over usable without
   any question.

---

### User Story 5 - Plugin command shortcuts, options and appearance (Priority: P3)

A user who assigned keyboard shortcuts to plugin commands, tuned options
(confirmations, panel and key behaviour, viewer and editor programs),
colours, panel highlighting and column layouts wants those too. The wizard
offers them as separate groups. It states plainly that shortcuts of Tandem
Commander's own commands are fixed and therefore have nothing to import.
Imported plugin-command shortcuts never take a key that a Tandem Commander
command or another current assignment already uses; such shortcuts are
reported.

**Why this priority**: valued by power users, but each group is smaller and
the program is fully usable without them.

**Independent Test**: with an old configuration that assigns Ctrl+Shift+F to
an FTP command and Ctrl+Shift+T (a Tandem Commander tab shortcut) to another
plugin command, import *Plugin command shortcuts* in *Add* mode: the first
shortcut works in Tandem Commander, the second is reported as conflicting
and not assigned, and every Tandem Commander shortcut still works.

**Acceptance Scenarios**:

1. **Given** an imported plugin shortcut for a plugin Tandem Commander does
   not ship, **When** imported, **Then** it is reported and skipped.
2. **Given** imported viewer or editor associations in *Add* mode, **When**
   a file type already has an association in Tandem Commander, **Then** the
   current association keeps precedence and the imported one is reported as
   "already covered"; an imported association that would take files over
   from the current catch-all row (`*.*`) is shown as a change of the current
   settings and needs the consent of FR-010c (the group is unticked by
   default).
3. **Given** imported general options, **When** the import ends, **Then**
   the Tandem Commander settings listed as its own (FR-016) are unchanged.
4. **Given** imported commands (user menu, viewers, editors) that point to
   programs which no longer exist or lie in the old program's folder,
   **When** the preview is shown, **Then** each is flagged so the user can
   decide, and the result repeats the warning.

---

### User Story 6 - A backup and a way back (Priority: P3)

Before the first change the wizard saves a complete backup of the current
Tandem Commander settings, and the result page says where it is and how to
return to it.

**Why this priority**: the *Add* mode and the preview already prevent loss;
the backup is the safety net for a choice the user regrets.

**Independent Test**: run an import with *Replace* on two groups, restore the
backup the result page names, restart: the settings equal the pre-import
state.

**Acceptance Scenarios**:

1. **Given** a backup cannot be written, **When** the user confirms the
   import, **Then** nothing is imported and the user is told why.
2. **Given** a completed import, **When** the user follows the restore
   instructions on the result page, **Then** Tandem Commander starts with
   exactly its pre-import settings.

---

### Edge Cases

- **No old configuration found**: the wizard says so, names the program
  versions it looked for, and changes nothing.
- **Several old configurations** (e.g. Altap Salamander 3.08 and 4.0, or 4.0
  and Open Salamander 5.0): all are listed with product and version, the
  newest preselected; the user picks one source per run.
- **Very old versions** (before Altap Salamander 2.5): listed as found but
  not supported, with the reason.
- **A source written by a newer program than Tandem Commander understands**
  (a configuration version above its own): refused with the reason.
- **The old program saved its settings incompletely** (it was interrupted
  while saving): the source is offered with a warning that it may be damaged.
- **The old program is running**: import is allowed (reading is harmless),
  with a note that changes it has not saved yet will not be seen.
- **Another Tandem Commander window/instance is running**: the import is
  refused until it is closed, because it would overwrite the imported
  settings when it closes.
- **Tandem Commander started for the first time** (default settings): import
  works; *Add* and *Replace* then give the same result for lists. If an old
  configuration exists, the one-time offer (FR-002) appears; answering *Not
  now*, closing it, or the program ending before it is answered never makes
  it appear on a later start of a configuration that has since been saved.
- **First start without any old configuration**: no offer; nothing is shown.
- **All 30 hot-path slots full** in *Add* mode: the hot paths that do not fit
  are reported as skipped; none replaces a current one.
- **Hot path or command referring to the old program's own folder or
  `$(SalDir)`**: imported but flagged (the variable now means Tandem
  Commander's folder).
- **Histories** (typed paths, commands, search masks): off by default; when
  imported, user names and passwords written inside addresses are removed
  first.
- **Configuration of a plugin Tandem Commander does not ship** (Automation,
  UnRAR, IE viewer, …): reported, not imported. **A Tandem-only plugin**
  (SFTP, Markdown viewer, code viewer): never touched.
- **An FTP connection using a proxy server**: the proxy definition comes with
  it, or the connection is reported as imported without its proxy.
- **Non-English names** (accented folder names, Czech hot-path titles): come
  over unchanged.
- **Interrupted import** (crash, power loss) after the first change: the
  backup restores the previous state; the old program's settings are
  untouched by construction.
- **Language**: the old program's language choice is never imported (Tandem
  Commander ships a different set of language modules).

## Requirements *(mandatory)*

### Functional Requirements

**Entry and sources**

- **FR-001**: The Options menu MUST offer an *Import Settings from
  Salamander…* command that starts the wizard at any time.
- **FR-002**: When Tandem Commander starts with a fresh configuration (no
  settings of its own stored yet) and at least one supported old Salamander
  configuration exists, it MUST offer the wizard once, after the main window
  is shown, with the choices *Import now* and *Not now*. The offer MUST say
  that the wizard stays available in the Options menu. Once the offer has
  been answered (either way, or dismissed), it MUST never appear again for
  that Tandem Commander configuration. The check at that start MUST only
  establish that an old configuration exists; it MUST NOT read any of its
  settings. A configuration that already existed before this feature counts
  as not fresh (no offer after an upgrade).
- **FR-003**: The wizard MUST find, for the current Windows user, every
  configuration of Altap Salamander (2.5 to 4.0, including the beta and
  Servant Salamander–era locations the product historically used) and Open
  Salamander 5.0, identify each by product and version, preselect the
  newest, and let the user choose one source per run. Newt Commander
  (never released) is not a source.
- **FR-004**: Sources older than Altap Salamander 2.5, and sources written by
  a configuration version newer than Tandem Commander's, MUST be listed as
  not supported with the reason and MUST NOT be imported.

**Reading the source**

- **FR-005**: The source configuration MUST be read only — in every path,
  including errors and cancellation — and only after the user started the
  wizard. The program MUST NOT read it at any other time; the only other
  access is the existence check of FR-002.
- **FR-006**: Reading the source MUST NOT show error boxes for unexpected or
  damaged values; such items are skipped and reported.
- **FR-007**: Text MUST arrive unchanged, including non-ASCII characters.

**Groups and modes**

- **FR-008**: The wizard MUST list the importable groups with the number of
  items each holds in the chosen source; unavailable groups are shown with
  the reason and cannot be selected. At least: hot paths; FTP connections
  (bookmarks, proxy servers, server types) with saved passwords; user menu;
  plugin command shortcuts; viewer, alternative viewer and editor
  associations; confirmations; colours and panel item highlighting; view
  templates (columns); internal viewer settings; general and panel options
  (including key-behaviour options and the change-drive menu options);
  per-drive default directories; search settings and the search ignore
  list; the settings of each other plugin Tandem Commander ships; histories
  (off by default). Toolbar layouts are offered only if planning confirms
  that their button numbering means the same in both programs.
- **FR-009**: For list groups (hot paths, user menu, FTP connections, plugin
  command shortcuts) the user MUST be able to choose *Add* (default) or
  *Replace*. Viewer, alternative viewer and editor associations MUST offer
  *Add* only (replacing them would remove associations of Tandem
  Commander's own plugins). Option groups and other plugins' settings are
  taken over as a whole or left out.
- **FR-010**: *Add* MUST NOT change or remove any current item. An imported
  item identical to a current one is not added; an imported item that
  conflicts with a current one (same hot-path slot, same FTP connection
  name, same file mask, same shortcut key) MUST leave the current one as it
  is and either be added in a non-conflicting form (next free hot-path slot,
  distinguishable FTP name) or be skipped — always reported.
- **FR-010c**: The import MUST NOT overwrite or remove any current Tandem
  Commander setting unless the user explicitly allowed it for that group.
  Every overwriting choice — *Replace* mode, option groups (which take
  values over), whole-plugin settings — MUST be off by default and MUST
  require its own explicit consent in the wizard (a deliberate tick plus the
  preview's listing of every current value or item that will change, with its
  current and new value). With the defaults the wizard only adds (list
  groups in *Add* mode); option groups whose source values equal the current
  values report "nothing to change".
- **FR-011**: *Replace* MUST make the group equal to the source's content and
  MUST name, in the preview, the current items that will be removed. For
  shortcuts of plugin commands *Replace* means "the imported key wins a
  conflict" (research R5): a shortcut the user gave a command the source does
  not mention stays, because the source cannot say it should go.
- **FR-012**: Re-running the wizard with the same choices MUST NOT create
  duplicates.

**What is never imported (protecting the current program)**

- **FR-013**: The import MUST NOT change the list, order, registration or
  loadability of installed plugins, and MUST NOT change archiver
  (packer/unpacker) settings or archive associations; it MUST point the user
  to *Archivers Autoconfiguration* instead.
- **FR-014**: Viewer associations to plugins MUST be re-mapped to the same
  plugin in Tandem Commander or skipped and reported; an import MUST never
  make a file type open with a different plugin than intended.
- **FR-015**: The import MUST NOT change Windows-wide state (file
  associations, shell registration, settings of other programs), nor any
  setting of the old program.
- **FR-016**: The import MUST NOT change Tandem Commander's own settings that
  have no counterpart or a different meaning in the old programs: theme,
  panel tabs, quick search filter, command shell, language, update-check
  state, plugin installation counters, icon overlay lists, window and dialog
  positions, open panel folders and tabs, and the configuration version.
- **FR-017**: Commands, programs and folders that do not exist or point into
  the old program's installation folder MUST be flagged in the preview and
  the result; hot paths and default directories that the program would
  reject MUST be skipped and reported.

**Passwords**

- **FR-018**: Passwords the old program stored without a master password
  MUST come over usable.
- **FR-019**: Passwords protected by an old master password MUST come over
  only after the user typed that master password and it was verified; the
  user MUST be able to skip, in which case the connections come over without
  them and the result names each.
- **FR-020**: The import MUST NOT replace or remove Tandem Commander's master
  password or make any password it already protects unusable, and MUST NOT
  store passwords with weaker protection than in the source without the
  user's explicit consent.
- **FR-021**: User names and passwords written inside addresses in imported
  histories MUST be removed before they are stored.

**Plugins**

- **FR-021a**: The plugin interface MUST gain an append-only import call
  (interface version 108, documented by a contract before the change) through
  which a plugin receives the source's settings of that plugin read-only, the
  chosen mode and the master-password context, and applies them itself.
  Plugins built for older interface versions MUST keep loading and working;
  for a plugin without the call the wizard offers only taking over its
  settings as a whole (or nothing).
- **FR-021b**: The FTP plugin MUST implement the call, including *Add*
  (merge with duplicate detection and conflict handling per FR-010, keeping
  references between connections and proxy servers intact) and *Replace*.

**Flow, safety and outcome**

- **FR-022**: Before any change the wizard MUST show a preview listing, per
  group, what will be added, replaced, removed, left as is and skipped (with
  reasons), and MUST require an explicit confirmation.
- **FR-023**: Before the first change the wizard MUST save a complete backup
  of the current Tandem Commander settings; if that fails, nothing is
  changed.
- **FR-024**: The import MUST be refused, with the reason, while another
  Tandem Commander instance runs.
- **FR-025**: Imported settings MUST take effect in the running program (or
  the result MUST say which group takes effect after a restart) and MUST NOT
  be lost when Tandem Commander closes.
- **FR-026**: If a group cannot be applied, that group MUST stay as it was,
  the others are reported as applied or not, and the result says so.
- **FR-027**: The result page MUST report per group: added, already present,
  replaced, removed, skipped (each skipped item with its reason), flagged
  items, the backup location and how to restore it; the user MUST be able to
  copy or save the report. No item may be dropped silently.
- **FR-028**: Cancel MUST be possible at every step before the confirmation
  and MUST leave everything unchanged.
- **FR-029**: The wizard MUST follow the program's dialog style and be
  translated like the rest of the user interface, and MUST have a help page.
- **FR-030**: The wizard MUST NOT use the network.

**Records and rules**

- **FR-031**: The constitution's Principle II, the product-identity notes
  and the privacy statement MUST be updated in the same change to say that
  the program reads the old programs' settings read-only, only when the user
  starts the import, never writes them, and at the first start of a fresh
  configuration checks only whether they exist (FR-002). This feature supersedes the
  "no configuration migration" decisions of features 032 and 046 for this
  read-only, user-initiated case only.
- **FR-032**: The standalone migration script of feature 057
  (`utils/migrate-altap-settings.cmd`) and its test harness MUST be removed
  in this feature; the repository documentation that described it and the
  changelog MUST point users to the wizard instead. 057's records stay
  unedited as history.

### Key Entities

- **Source configuration**: the stored settings of one installed (or
  formerly installed) Altap Salamander or Open Salamander version for the
  current user; identified by product, version and configuration version;
  read only.
- **Import group**: a user-recognisable set of settings (hot paths, FTP
  connections, user menu, …) that is selected, given a mode, previewed,
  applied and reported as a unit; has an availability (available / empty /
  not transferable + reason) and an item count.
- **Import item**: one entry of a list group (a hot path, a connection, a
  menu item, a shortcut, an association) with an identity used to detect
  duplicates and conflicts.
- **Import mode**: *Add* (keep everything current, add what is new) or
  *Replace* (the group becomes the source's), per list group.
- **Import plan (preview)**: the complete list of intended changes and skips
  computed before anything is written.
- **Import result**: the per-group outcome, flagged items, backup location;
  copyable.
- **Settings backup**: a complete, restorable copy of Tandem Commander's
  settings taken before the first change.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user with an Altap Salamander 4.0 configuration brings over
  hot paths, FTP connections and user menu — from opening the wizard to
  reading the result — in under 3 minutes, without editing anything by hand.
- **SC-002**: The old program's settings are identical before and after
  100 % of runs (finished, cancelled, failed).
- **SC-003**: After any import, 100 % of plugins installed before still load,
  and 100 % of file types keep opening with the viewer they opened with
  before, unless the user explicitly replaced that group or allowed the
  viewers group's changes (FR-010c).
- **SC-004**: 0 settings outside the selected groups change; 0 current items
  change or disappear in *Add* mode.
- **SC-005**: 0 duplicates after running the same import twice.
- **SC-006**: 100 % of items reported as imported are present and work
  (every imported hot path opens its folder; every imported FTP connection
  opens and, where a password came over, logs in without retyping it).
- **SC-007**: 0 items dropped silently: every item not imported from a
  selected group appears in the result with a reason.
- **SC-008**: Restoring the backup reproduces the pre-import settings
  exactly in 100 % of runs.
- **SC-009**: 0 passwords end up stored with weaker protection than in the
  source without the user's consent; Tandem Commander's master password is
  unchanged after 100 % of runs.
- **SC-010**: An import run with the wizard's default choices changes 0
  existing Tandem Commander values (it only adds items); every overwritten
  value in any run was listed in the preview and explicitly allowed.

## Assumptions

- The source is on the same machine and belongs to the same Windows user
  (the old programs' own export can move settings between machines first).
  Importing an exported `.reg` file of an old program is out of scope.
- The old programs read and write the same kind of settings Tandem
  Commander descends from; where formats differ the import skips and
  reports rather than guesses (057's analysis showed that from Altap
  Salamander 2.5 on only two small conversions are needed).
- Session state (open folders, panel tabs, window positions, sizes) is not
  worth importing and conflicts with Tandem Commander's tabs; it is excluded.
- *Add* is the default mode for every list group, because it cannot lose
  anything; on a conflict the current Tandem Commander item wins.
- Imported viewer and editor associations are placed after the current
  specific ones and before the current catch-all row (`*.*`); taking files
  over from the catch-all is a change that needs consent, so the group is
  unticked by default (review round 1).
- Merging FTP connections uses a new, append-only plugin-interface call
  (interface 108, FR-021a); the core does not learn any plugin's private
  storage layout.
- One source per run; the wizard can be run again with another source.
- The wizard uses the program's existing settings export for the backup.
- The dormant start-up import code from Open Salamander stays inactive; the
  wizard does not reuse it (it replaces everything and can delete the old
  program's settings).

## Constitution note

Principle II today says Tandem Commander "never reads or writes Open
Salamander or Newt Commander configuration" and that identity changes are
not reintroduced piecemeal. This feature does **not** reintroduce the old
identity (registry root, binary name, inter-process names stay Tandem
Commander's) and never writes another product's settings; it adds a narrow,
explicit exception: **reading** an Altap Salamander or Open Salamander
configuration, read-only, only when the user starts the import wizard — plus
checking, once at the first start of a fresh configuration, *whether* such a
configuration exists (FR-002), without reading its contents. The
amendment (with its version bump and Sync Impact Report) is part of this
feature (FR-031). The opt-in rule of Principle II is satisfied: nothing
changes unless the user starts the wizard (from the menu or the one-time
offer) and confirms.

## Related work

- 057 (the standalone script — prior analysis reused), 032 / 046 (identity
  break, superseded only as stated in FR-031), 010 / 084 (archivers), 047
  (hot paths), 078 (tabs), 085 / 086 (passwords and histories), 116 (password
  bytes), 174 (configuration export), 244 (quick search filter).
- Observations outside this feature, to go to the backlog *Inbox* rather
  than into this feature: see [analysis.md](analysis.md) § A11.
