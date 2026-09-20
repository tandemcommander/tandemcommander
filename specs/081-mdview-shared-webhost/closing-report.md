# Closing Report — Feature 081: mdview onto the Shared WebView2 Host

**Branch**: `081-mdview-shared-webhost` · **Baseline**: `main` at `6b4d7af`
**Date**: 2026-09-20 · **Ships with**: the unreleased 0.1.8 — **no version
bump**, plugin ABI untouched (interface 106), no new binary

---

## What this feature was for

Feature 070 lifted the WebView2 hosting code into `src/common/webhost/`
(`CTcWebHost`, `CTcWebKeeper`) and built the Code Viewer on it, but left the
Markdown Viewer on its own 984-line copy, because converting a shipping
feature needs a regression pass that only a GUI session can run and the new
plugin had to be known to work first. Until today the product therefore
shipped **two copies of the same host** — the exact duplication
`architecture/11-webview2-integration.md` exists to prevent, where a change to
the lockdown or to the browser arguments has to be made twice and can silently
diverge.

It is now one copy.

## What changed

| | |
|---|---|
| **Deleted** | `src/plugins/mdview/webview.{h,cpp}` — 982 lines: `CMdWebHost`, `MdBuildEnvOptions`, `MdUserDataFolder`, the keeper, the lockdown, the interceptor |
| **Added** | `src/plugins/mdview/webglue.{h,cpp}` — 373 lines, **COM-free**: `MdConfigureHost` (origin, scripts/messages off, the `doc.html` + `img/<n>` server, the key map), the local/WinHTTP readers, the pre-065 folder janitor, the keeper wrappers |
| **Changed** | `viewer.{h,cpp}` hold a `CTcWebHost*` and own the `DocVersion` that cache-busts the document URL (the shared host takes it from its caller, as codeview's does); `mdview.cpp` include; `mdview.props`/`mdview.vcxproj` |
| **Dropped** | `MdKeeperArmed()` — declared and defined since 065, called nowhere |
| **Shared host** | `TcWebBrowserArguments()`: the browser-arguments literal existed **three** times (mdview's host, `webhost.cpp`, and `webkeeper.cpp` — whose comment claimed to include the one definition and did not); it now has one |

Net in `src/`: **+538 / −1026**.

## What mdview gained, and what it kept

The shared host turned out to be a **strict superset** of the copy it replaced
(research R1 compared them line by line; mdview's copy had received no change
since the lift other than feature 069's keeper-class fix, which the shared one
also carries). So the migration is a hardening, not a trade:

| | Before | Now |
|---|---|---|
| content policy on the document | none | `default-src 'none'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; object-src/base-uri/form-action/frame-ancestors none` |
| downloads started by the document | the engine's default handling | cancelled |
| permission requests, script dialogs | the engine's defaults | denied / disabled |
| window closed during a cold engine start | a queued creation completion could touch a freed host | discarded |
| Debug build | — | every locked-down setting read back, `TRACE_E` on a mismatch |

Kept deliberately: a broken `img/<n>` slot still answers **404**, not the
host's default-deny 403 — returning `false` from `Serve` would have changed
what the engine reports for a missing image.

## Evidence

| Gate | Result |
|---|---|
| G1 builds | Debug and full Release, **0 errors**; both plugins link `webhost.obj`+`webkeeper.obj`; Release runtime closure OK (219 modules) |
| G2 guards | one arguments literal in the tree; **no** `#include` of `wrl.h`/`WebView2.h` anywhere under `src/plugins/`; the old files are gone |
| G3 generator | `tests/mdview_htmlgen_test/build_and_run.cmd` — **29 assertions, 0 failed** |
| G4 content policy | control document and the harness's own `sample.md` render with **0 blocked references**; each hostile fixture matched the layer that refuses it |
| G5 runtime probe | **24 checks, 0 failed** — smoke 5, nine hostile fixtures 9, keeper warm 3, keeper crash 3, close-during-cold-start 2, cross-plugin warmth 2; Release smoke 5/5 |
| G6 pixels | `10-legit-control.md` rendered by the pre-migration and migrated builds: **0 of 729,144 pixels differ** |
| G7 review | independent agent over `git diff main...HEAD -- src/`; see *Review* below |

Numbers worth keeping: the keeper's tree survived **65 s** with no viewer open
and a warm reopen took **95 ms** against a back-to-back **95 ms**; after the
engine tree was killed the next view worked (95 ms) and the one after it was
warm again (92 ms); with the Code Viewer used first, the first Markdown view
took **94 ms** — either plugin's keeper warms the other, as the contract
promises.

## Things found on the way

- **A dangling pointer in the first version of the `Serve` callback.** The
  shared host reads `TcWebResponse::Data` *after* the callback returns
  (`MakeAndSetResponse` → `SHCreateMemStream`), so image bytes read into a
  vector local to the lambda are already gone. codeview never met this because
  its answers are a module resource and a window member. Fixed with a scratch
  buffer owned by the callback; the contract now documents the trap, because
  the next plugin will write the same code.
- **The security fixture corpus feature 021's quickstart describes was never
  committed.** It exists now, under `fixtures/security/`: nine hostile files
  (each construct in several forms), a legitimate control, and a `README.md`
  mapping every file to a checklist row.
- **The generator harness had no project file** — a gap recorded in mdview's
  own notes since 022 and never closed. `build_and_run.cmd` replaces it.
- **A bug in the probe, not in the product**: `-like '*[Source]*'` is a
  character class in PowerShell, so the View Source check could never fail
  honestly. It cost one run and is now `.Contains`.
- **The Debug build already reports "Detected memory leaks!" at exit** on the
  *reference* tree (the known 078 leak). Recorded before the migration so it
  could not later be mistaken for a regression; the probes dismiss the dialog
  and the on-screen checklist warns about it.
- Two `cmd` traps and one PowerShell trap are written down in `fix-log.md`
  (`for /f` over a quoted path, `/Fo` with several sources, `$PSScriptRoot` in
  a parameter default) so the next script does not rediscover them.

## What is owed to a person

The on-screen regression pass — which is *why* this half of the lift was
deferred in 070 — is in [`quickstart.md`](quickstart.md) § A–D. The
machine-checkable part is done; what needs a human is:

1. the **network monitor** over the hostile corpus (rows B1–B9): a capture
   proving no DNS query or connection attempt for `example.invalid`;
2. the ***Keep the rendering engine ready*** toggle through the Plugins
   Manager (row C5) and **plugin unload/reload** (row C7);
3. the **dark menus** and follow-system theme (row A8), the link kinds
   (row A6), and an eye over rows A1–A10 against the preserved pre-migration
   build `build\tandemcommander\Debug_x64_prefix081\` — **do not delete that
   tree before the pass**;
4. row **B9** in particular: clicking the five download links is the one
   hardening visible on screen.

Listed in `specs/NEXT-WORK.md` item 3 with the other owed sweeps.

## Review

An agent that did not write the code reviewed `git diff main...HEAD -- src/`
with the deleted file from `main` beside it: **no blocker, 3 SHOULD-FIX, 6
NOTE**. It confirmed parity item by item (accelerator map, content types,
where and how often the document version is bumped, the navigation gate, the
default-deny, the keeper's identity and the 069 class-unregistration fix), and
verified two claims I had only argued — that the served document pointer cannot
dangle, and that the single scratch buffer cannot be clobbered re-entrantly.

**All three SHOULD-FIX findings were fixed**, and one of them reaches past this
feature:

- **The keeper leaked its state block — 88 bytes, per plugin, per session.**
  `CTcWebKeeper` allocated its state lazily and had no destructor; nothing ever
  freed it. Because the disarm call on the unload path allocates the state
  too, the block leaked even in a session where no Markdown file was ever
  viewed. The pre-081 mdview keeper was a file-static struct that allocated
  nothing, so my change introduced this for mdview — and codeview has carried
  it since feature 070.

  **Features 078 and 079 both record an unexplained "one 88-byte block from a
  plugin module unloaded before the dump".** I measured the struct
  independently (a same-layout stand-in compiled x64 gives `sizeof = 88`)
  rather than taking the review's word for it. This is the **most likely
  explanation, not a proven one** — confirming it needs an allocation stack
  from a dump. Whoever next sees that leak report should check whether it is
  now gone. Fixed with a destructor (and deleted copy operations).

  Worth noting *why this feature's own leak check could not have caught it*:
  T033 compared the migrated tree against a reference tree that already
  contained codeview's identical leak.

- **The image scratch buffer held the last served image for the window's
  life** (up to 64 MB) because `clear()` does not release capacity. Now
  released at the start of the next image request — it cannot be released at
  the end of the current one, since the host copies the bytes after the
  callback returns.

- **A comment in the shared keeper was false**: it justified unregistering the
  window class in `Disarm()` by claiming the browser-death path goes through
  `ReleaseAll()`. It goes through `Disarm()`. Behaviour is fine (the reviewer
  traced it: the window is destroyed before `UnregisterClassW`, and the next
  arm re-registers), but the comment was inherited from mdview's keeper where
  it had been true, and would have misled the next maintainer.

Two NOTEs were also acted on (the dead NULL guard now says why it is kept; the
404's new content type is listed among the contract's accepted deltas). The
stale prose in mdview's `IMPLEMENTATION_NOTES.md` sits in historical sections
that the new v2.3 section supersedes and was left as an append-only record.

## Records

- [`spec.md`](spec.md), [`plan.md`](plan.md), [`research.md`](research.md)
  (R1 the line-by-line comparison of the two hosts, R4 the CSP analysis,
  R8 the corpus design, R10 what a machine can and cannot prove)
- [`tasks.md`](tasks.md) — 50 tasks in 8 phases
- [`fix-log.md`](fix-log.md) — the running record, with every measured number
- [`contracts/mdview-host-config.md`](contracts/mdview-host-config.md),
  [`contracts/browser-arguments-single-source.md`](contracts/browser-arguments-single-source.md)
- [`quickstart.md`](quickstart.md) — the hand-over checklist
- `fixtures/security/`, `probe/` — the corpus and the three probes
- Updated elsewhere: `architecture/11-webview2-integration.md` (migration
  complete, the single source named, what a *third* consumer does),
  `specs/070-source-viewer-plugin/{REMAINING-WORK.md,contracts/webview-host-sharing.md}`,
  `specs/NEXT-WORK.md`, `src/plugins/mdview/IMPLEMENTATION_NOTES.md` (v2.3),
  `CLAUDE.md`, `CHANGELOG.md` (0.1.8 *Changed*)
