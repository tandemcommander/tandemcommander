# Feature Specification: mdview onto the Shared WebView2 Host

**Feature Branch**: `081-mdview-shared-webhost`
**Created**: 2026-09-20
**Status**: Draft
**Input**: User description: "mdview onto the shared WebView2 host: the Markdown
Viewer plugin (mdview) must use the product's shared WebView2 hosting code in
`src/common/webhost/` (lifted there by feature 070 and used by the Code Viewer
since) instead of its own private copy in `src/plugins/mdview/webview.cpp`.
Today the product ships TWO copies of the WebView2 host — the exact duplication
`architecture/11-webview2-integration.md` §2.5 and
`specs/070-source-viewer-plugin/contracts/webview-host-sharing.md` exist to
prevent; this feature is the outstanding second half of that lift
(`specs/070-source-viewer-plugin/REMAINING-WORK.md` §2, `specs/NEXT-WORK.md`
item 4b). mdview's user-visible behaviour MUST NOT change; where the shared host
is stricter, mdview gains the hardening; the browser-arguments set must exist in
exactly one place; the documentation must say the migration is complete; a
written on-screen checklist is the hand-over to the person who runs the GUI
pass."

## Context

The product embeds a browser engine (WebView2) in two viewer plugins: the
**Markdown Viewer** (mdview, since feature 021) and the **Code Viewer**
(codeview, feature 070). Feature 070 lifted the engine-hosting code that both
need — engine start-up, the canonical cache folder, the security lockdown,
request interception with default-deny, accelerator routing, zoom, background
colour, and the session "keeper" that keeps the engine warm — into one shared
component, and built the Code Viewer on it. The Markdown Viewer was left on its
own, older copy of the same code, because converting a shipping feature needs a
regression pass that only a person at the screen can run, and the Code Viewer
had to be known to work first. Both conditions have since been met
(`specs/070-source-viewer-plugin/stabilization-review.md`).

Until this feature ships, a change to the lockdown or to the browser arguments
has to be made twice and can silently diverge — the failure the architecture
contract exists to prevent. Reading the two copies side by side today shows the
shared component is a **strict superset** of mdview's copy (it adds a content
security policy on the served document, refuses downloads and permission
requests, disables script dialogs, survives a window closed during a cold
engine start, and asserts the applied lockdown in debug builds); mdview's copy
received no fix of its own since the lift, so nothing would be lost.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Viewing Markdown works exactly as before (Priority: P1)

A Tandem Commander user presses F3 on a Markdown file. The rendered document
appears with the chosen colour scheme; the user cycles schemes, zooms, searches,
follows links, toggles View Source and remote images, and closes the window.
Nothing about this experience changes when the plugin is moved onto the shared
host — the user cannot tell the two builds apart.

**Why this priority**: the Markdown Viewer is a shipping feature (0.1.0 →
0.1.7). The whole point of the feature is an internal consolidation; any visible
change is a regression by definition (constitution II).

**Independent Test**: run the on-screen checklist this feature delivers
(`quickstart.md`) against the migrated build and, side by side, against a
pre-migration build of the same plugin; every row reads "same".

**Acceptance Scenarios**:

1. **Given** a Markdown file with headings, a table, a fenced code block, a
   local image and embedded HTML (`<kbd>`, `<sub>`), **When** the user presses
   F3, **Then** the document renders as in 0.1.7: real table grid with
   alignment, highlighted code, the inline image, the embedded HTML rendered
   (not literal), theme-coloured background from the first frame (never white).
2. **Given** an open viewer, **When** the user presses F9 / Shift+F9, picks a
   scheme from the View menu, or toggles *Follow system theme*, **Then** the
   scheme changes as before and is remembered for the next view.
3. **Given** an open viewer, **When** the user zooms with Ctrl+wheel, Ctrl+Plus/
   Minus, Ctrl+0 or Numpad-0, **Then** the content zooms, the title shows the
   percentage, and the zoom is remembered.
4. **Given** an open viewer, **When** the user presses Ctrl+F and enters a term,
   then F3 / Shift+F3, **Then** matches are highlighted and the view moves to
   the next / previous match; a term with no match shows the *not found*
   message as before.
5. **Given** an open viewer, **When** the user presses Ctrl+U, **Then** the raw
   source is shown (and search and zoom still work there); Ctrl+U again
   returns to the rendered view.
6. **Given** a document with links of every kind, **When** the user clicks
   them, **Then**: an `#anchor` scrolls within the document; a relative `.md`
   link opens a new viewer window; another local target shows only its resolved
   path; `http`/`https`/`mailto` open in the system handler; anything else is
   refused with the *link blocked* message — exactly as before.
7. **Given** a document with a remote image, **When** the user has not
   consented, **Then** a placeholder is shown; **When** the user enables *Load
   Remote Images*, **Then** the image loads for this document.
8. **Given** the application's Dark theme is active, **When** a viewer opens,
   **Then** its menu bar and popups are drawn dark as before.
9. **Given** a machine without the browser runtime, **When** the user presses
   F3 on a Markdown file, **Then** the built-in text viewer opens instead,
   with the same message as before.
10. **Given** an open viewer, **When** the user resizes the window or gives it
    focus, **Then** the content fills the window and keyboard scrolling
    (arrows, PgUp/PgDn) works without a mouse click.

---

### User Story 2 — Hostile documents stay harmless, and get harder to abuse (Priority: P1)

A user opens a Markdown file they did not write. Whatever the file contains —
scripts, event handlers, `javascript:` links, remote images and iframes, forms,
meta-refresh, path-traversal image sources — nothing executes, nothing reaches
the network without the user's consent, and the viewer never navigates away
from the document. After this feature the same is true, and in addition the
document can no longer start a download, ask for a device permission (camera,
location, clipboard read, …) or pop a script dialog.

**Why this priority**: the security lockdown of feature 021 is the safety
property that made rendering raw HTML acceptable at all. Sharing the lockdown
routine is only acceptable if the shared routine is at least as strict.

**Independent Test**: open every file of the security fixture corpus
(`specs/081-mdview-shared-webhost/fixtures/security/` — the corpus feature
021's quickstart describes was never committed, so this feature authors it) in
the migrated viewer with a network monitor attached; observe zero script
effects and zero content-triggered network requests — identical to 0.1.7 —
plus no download prompt.

**Acceptance Scenarios**:

1. **Given** a document with `<script>`, `onerror=`, `onclick=` and a
   `javascript:` link, **When** it is viewed and the link clicked, **Then** no
   script runs, and the link is refused with the *link blocked* message.
2. **Given** a document with a remote `<img>`, a remote `<iframe>` and a
   meta-refresh to a remote page, **When** it is viewed without consent,
   **Then** the network monitor records no request from the viewer and the
   view stays on the document.
3. **Given** a document that references `../../secret.png` or an absolute /
   UNC image path, **When** it is viewed, **Then** the image is refused (as
   before).
4. **Given** a document with a download link (`<a download>` to a `data:` or
   a document-relative target), **When** the link is clicked, **Then** no
   download starts and no download bubble appears (new hardening; before, the
   engine's default download handling applied). Permission prompts and script
   dialogs cannot arise at all while scripts are off — their refusal is
   defence in depth and is verified by reading the applied settings, not on
   screen.
5. **Given** a legitimate document with inline styles, a local image and a
   `data:` image, **When** it is viewed under the new content policy, **Then**
   all three render — the hardening blocks nothing a Markdown document may
   legitimately contain.

---

### User Story 3 — The second Markdown view is still instant (Priority: P2)

A user views a Markdown file (one-time engine start), closes it, works for a
while, and views another one: it opens instantly, because the plugin kept the
engine warm since the first view. The keeper arms at the first view only,
disarms immediately when the user turns *Keep the rendering engine ready* off,
disarms when the plugin is unloaded, and quietly re-arms at the next view after
the engine crashed.

**Why this priority**: feature 065's instant display is a shipped, user-noticed
improvement; the keeper is part of what moves onto the shared component, so
its behaviour must be re-proven, not assumed.

**Independent Test**: feature 065 `quickstart.md` scenarios 1, 3, 4, 5 and 7
pass unchanged on the migrated plugin.

**Acceptance Scenarios**:

1. **Given** a fresh session, **When** the user does not view Markdown, **Then**
   no browser engine process belongs to the application (zero cost before
   first use).
2. **Given** the first Markdown view of the session, **When** the viewer is
   closed and ≥ 60 s pass, **Then** the engine process tree is still running;
   the next view opens instantly (no perceptible blank stage).
3. **Given** the option *Keep the rendering engine ready* is turned off with
   no viewer open, **When** ~1 min passes, **Then** the engine tree has
   exited; the next view pays the cold start; turning the option back on arms
   again at the next view.
4. **Given** the keeper is armed and the engine process is killed externally,
   **When** the user views a Markdown file, **Then** it works (one cold
   start), and the following view is instant again.
5. **Given** the keeper is armed with no viewer open, **When** the plugin is
   unloaded from the Plugins Manager, **Then** it unloads cleanly, the engine
   tree exits, and a reload followed by a view works — and the *instant* second
   view still works after the reload (the keeper can arm again).
6. **Given** the Code Viewer has already been used in the session, **When**
   the user views a Markdown file for the first time, **Then** it attaches
   warm (either plugin's keeper warms the other — the shared-engine contract).

---

### User Story 4 — One copy of the host for the maintainer (Priority: P2)

A maintainer tightening the browser lockdown, or changing the browser
arguments, edits one component and both viewers pick up the change; the
architecture documentation names that one place and no longer describes a
pending migration.

**Why this priority**: this is the feature's reason to exist — but it delivers
its value only once stories 1–3 prove nothing regressed.

**Independent Test**: inspect the source tree: the Markdown Viewer plugin
contains no engine-hosting code of its own (no browser-engine or COM headers
included anywhere in the plugin), the browser-arguments set is written down
exactly once in the whole tree, and the documentation set names
`src/common/webhost/` as the single source with the migration marked complete.

**Acceptance Scenarios**:

1. **Given** the migrated tree, **When** the maintainer searches the Markdown
   Viewer's sources for engine start-up, lockdown, interception or keeper
   logic, **Then** none is found — only what is genuinely the plugin's own
   (document and image serving, accelerator map, link gate, cache-folder
   janitor, document-version cache-busting).
2. **Given** the migrated tree, **When** the maintainer searches for the
   browser-arguments literal, **Then** exactly one definition exists, inside
   the shared component, and both the viewer surfaces and the keepers obtain
   it from there.
3. **Given** the migrated tree, **When** the maintainer reads
   `architecture/11-webview2-integration.md`, the 070 contract and
   `REMAINING-WORK.md`, `specs/NEXT-WORK.md` and the plugin's
   `IMPLEMENTATION_NOTES.md`, **Then** each says the migration is complete and
   points at the shared component; no document still says mdview carries its
   own copy.
4. **Given** the migrated tree, **When** full Debug and Release builds run,
   **Then** both succeed, the Code Viewer is unchanged in behaviour, the
   plugin interface version is unchanged, and no new DLL appears.

---

### User Story 5 — The hand-over to the person at the screen (Priority: P3)

The maintainer who runs the GUI regression pass (the step this feature cannot
do itself) opens one file in the feature directory and finds exactly what to
verify, in which order, against which reference build, and what "pass" looks
like for each row.

**Why this priority**: the acceptance of this feature is a manual pass
(`070/REMAINING-WORK.md` §2, `NEXT-WORK.md` item 3). Without the checklist the
pass is either skipped or improvised.

**Independent Test**: a person unfamiliar with the change can execute the
checklist end to end without asking a question.

**Acceptance Scenarios**:

1. **Given** the feature is code-complete, **When** the maintainer opens
   `quickstart.md`, **Then** it lists every row of stories 1–3 as a concrete
   step with expected outcome, names the reference (pre-migration) build to
   compare against and how to obtain it, and tells where to record the result.

---

### Edge Cases

- **Viewer closed during the engine's cold start**: the window must close
  cleanly with no crash or leak report; the late engine completion is
  discarded (the shared component already guards this; mdview's copy did not).
- **Engine process crashes while a viewer is open**: the viewer shows the
  engine-failure message and closes, as before; the keeper releases quietly
  and re-arms at the next view.
- **Legitimate content under the new content policy**: inline `<style>` and
  `style=` attributes, images served from the document's own folder,
  `data:` images, search-hit marks and syntax-highlight spans must all keep
  rendering. Content that the default-deny interceptor already refused (remote
  images without consent, iframes, media, fonts from the network) is now
  refused one layer earlier — same visible outcome.
- **A form in embedded HTML**: submitting it previously produced the *link
  blocked* message (the navigation gate caught it); under the content policy
  the submission is refused before any navigation starts, so no message
  appears. Accepted: a Markdown document has no legitimate form, and refusing
  is the stricter outcome.
- **Image index out of range / unreadable local image**: the image slot stays
  empty as before (the response status for a missing image is preserved).
- **Older browser runtime lacking the newer lockdown interfaces**: the newer
  lockdowns are skipped silently; everything feature 021 required still
  applies (both copies already behaved this way).
- **Plugin unload while the keeper is armed, then reload**: the keeper's hidden
  window class is released on unload so re-arming works after a reload
  (feature 069 F-P6-01 — must stay fixed).
- **Two Markdown windows plus a Code Viewer window at once**: all three share
  one engine tree; closing any subset leaves the others working; the keepers
  of both plugins can be armed at the same time without interfering (distinct
  hidden-window class names).
- **Debug vs Release**: the lockdown read-back assertion exists only in Debug
  builds and never shows UI; Release behaviour is identical to Debug.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The Markdown Viewer MUST render through the product's shared
  browser-hosting component (the same one the Code Viewer uses) and MUST NOT
  contain its own implementation of engine start-up, cache-folder resolution,
  runtime availability check, security lockdown, request interception,
  accelerator routing, zoom/background plumbing, or the session keeper.
- **FR-002**: The Markdown Viewer MUST keep only what is genuinely its own:
  serving its generated document and its numbered image table (local file
  read; remote fetch only after per-document consent), its keyboard
  accelerator map, its link classification gate, the best-effort removal of
  the pre-065 cache folder, and the document-version cache-busting used by
  search.
- **FR-003**: Every user-visible behaviour of the Markdown Viewer listed in
  User Story 1 MUST be unchanged from version 0.1.7: rendering, schemes and
  follow-system, zoom (mouse and keyboard, title percentage, persistence),
  find (new term reload, next/previous, not-found message), View Source,
  every link kind, remote-image consent, dark menus, resize/focus behaviour,
  window placement, and the fallback to the built-in text viewer when the
  runtime is missing or the engine fails to start.
- **FR-004**: The rendering surface MUST enforce at least the feature-021
  lockdown: scripts disabled, web messages disabled, default context menu /
  developer tools / status bar / built-in error page / browser accelerator
  keys / autofill / password save / pinch-zoom / swipe navigation / reputation
  checking off, network default-deny with only the document and its image
  table served, and no navigation except the document itself and its
  fragments.
- **FR-005**: The rendering surface MUST additionally apply the shared
  component's stricter measures: a content security policy delivered with
  the document, downloads refused, permission requests denied, script dialogs
  disabled, and the debug-build read-back assertion of the applied lockdown.
  Nothing MAY be relaxed relative to either copy.
- **FR-006**: Under the content security policy every legitimate element of a
  generated Markdown document MUST keep rendering: inline styles, images from
  the document's folder, `data:` images, consented remote images, search
  marks and highlighted code.
- **FR-007**: The session keeper MUST behave as feature 065 specifies: armed
  only at the plugin's first actual view and only when *Keep the rendering
  engine ready* is on; disarmed immediately when that option is turned off,
  on plugin unload, and at process exit; every failure silent; quiet release
  and re-arm at the next view after the engine process dies; hidden window
  never visible in Alt+Tab or the taskbar; the hidden window's class released
  on unload so a reload can arm again.
- **FR-008**: All engine environments the Markdown Viewer creates (viewer
  surfaces and keeper) MUST use the product's canonical cache folder
  `%LOCALAPPDATA%\Tandem Commander\WebView2`, unchanged; the pre-065 folder
  MUST still be removed best-effort at the first view.
- **FR-009**: The browser-arguments set MUST be written down in exactly one
  place in the source tree, inside the shared component; every environment
  (both plugins' surfaces, both keepers) MUST obtain it from there.
- **FR-010**: The documentation set MUST record the migration as complete and
  name the shared component as the single source: the architecture contract
  (`architecture/11-webview2-integration.md` — its "status of the migration"
  paragraph, §2.2's pointer to the arguments helper, §4's reference
  implementation), the 070 contract's verification section and
  `REMAINING-WORK.md` §2, `specs/NEXT-WORK.md` item 4 and the plugin's
  `IMPLEMENTATION_NOTES.md`.
- **FR-011**: The feature MUST leave a written on-screen verification
  checklist (`quickstart.md` in the feature directory) covering every
  acceptance scenario of stories 1–3, naming the reference build for
  side-by-side comparison and how to obtain it, with the expected outcome per
  row and a place to record results.
- **FR-012**: The plugin interface version MUST remain 106; no new DLL MAY be
  introduced (the shared component stays compiled into each plugin); the Code
  Viewer's behaviour MUST be unchanged; no UI string MAY be added, removed or
  changed (no translation work).
- **FR-013**: The change MUST be recorded in `CHANGELOG.md` under the
  unreleased 0.1.8 section, truthfully scoped: no visible change for
  ordinary documents, hardened refusal of downloads, permission requests and
  script dialogs for hostile ones. No version bump.
- **FR-014**: Full Debug and Release builds MUST succeed, and the existing
  Markdown generator test harness (`tests/mdview_htmlgen_test/`) MUST still
  pass with its assertion count unchanged.

### Key Entities

- **Rendering surface**: the locked-down browser view inside one viewer
  window; owned by the window, created asynchronously, torn down with it.
  Configured per plugin only in: private origin name, scripts on/off, web
  messages on/off, what the interceptor serves, which keys map to which
  command, trace name. Everything else is an invariant of the shared
  component.
- **Session keeper**: one hidden, suspended engine view per plugin that keeps
  the shared engine process tree alive between viewer windows; states
  unarmed → arming → armed; identified by a hidden-window class name unique
  per plugin (mdview keeps `TandemMdKeeperWnd`).
- **Generated document**: the Markdown Viewer's HTML plus its numbered image
  table and search-match count; carries a version that changes whenever the
  content is regenerated so that a search reload is a fresh load and a
  next-match jump is a same-document scroll.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Exactly one implementation of the browser-hosting surface and
  keeper exists in the source tree; the Markdown Viewer's own sources include
  zero browser-engine or COM framework headers.
- **SC-002**: The browser-arguments set occurs exactly once in the source
  tree (excluding historical spec records).
- **SC-003**: 100 % of the rows of the on-screen checklist (every acceptance
  scenario of stories 1–3) read "same as reference" on the migrated build;
  the four hardening rows (downloads, permissions, script dialogs, content
  policy) read "stricter, nothing legitimate lost".
- **SC-004**: 100 % of the security fixtures show zero script effect and zero
  content-triggered network requests; 100 % of feature-065 quickstart
  scenarios 1, 3, 4, 5 and 7 pass unchanged.
- **SC-005**: The second Markdown view of a session opens within 2× the
  back-to-back time (feature 065 SC-002), measured on the migrated build.
- **SC-006**: Full Debug and Release builds succeed; the generator test
  harness passes with an unchanged assertion count; no Debug-CRT leak report
  is attributable to the migrated plugin across open/close cycles including a
  close during cold start.
- **SC-007**: Zero remaining statements in the repository's living
  documentation (architecture, contracts, handoffs, plugin notes) that the
  Markdown Viewer carries its own copy of the host.

## Assumptions

- **Superset verified by reading**: the shared component's lockdown is a
  strict superset of the plugin's copy (content policy, download refusal,
  permission denial, script-dialog off, close-during-cold-start guard,
  worker-source interception, debug assertion); the plugin's copy received no
  change since the lift (feature 070, 2026-08-26) other than feature 069's
  keeper-class fix, which the shared component also carries. Verified at
  `main` `6b4d7af`.
- **Content policy compatibility verified in the generator**: the generated
  document uses inline CSS only, images only from its own numbered table or
  `data:` URIs, no web fonts, no external stylesheets or scripts, no `<base>`.
  The shared component's scripts-off policy permits exactly these.
- **Accepted tiny delta**: a form submission embedded in raw HTML is refused
  silently instead of producing the *link blocked* message (see Edge Cases).
  Not a Markdown feature; stricter outcome; recorded, not asked.
- **Missing-image status preserved**: the plugin keeps answering a missing
  image slot with the same status it used before through the shared
  component's per-response status field, so the visible outcome (empty slot)
  and any engine-side logging are unchanged.
- **Reference build for the GUI pass**: a pre-migration Debug `mdview.spl`
  (built from `main` before this branch) is preserved beside the build tree
  for side-by-side comparison; the checklist names it. The GUI pass itself is
  a human step and is recorded as owed, as `070/REMAINING-WORK.md` §2 and
  `NEXT-WORK.md` item 3 already do.
- **Shipping**: inside the unreleased 0.1.8 with no version bump; the
  changelog entry is warranted because a hardened security posture is
  something a user relies on (constitution, Release Documentation).
- **Protocol**: the feature-069 fix protocol applies (check the site is still
  as described at HEAD before changing it; enumerate consumers before
  writing; independent review of the diff before merge).
- **Out of scope**, restated: plugin-API change, a core-hosted keeper service
  exposed to plugins, any Code Viewer behaviour change, translations, version
  bump, changes to the shared component's invariants beyond consolidating the
  browser-arguments literal.
