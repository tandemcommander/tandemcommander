---
description: "Task list for feature 083 — privacy statement for the winget catalogue"
---

# Tasks: Privacy Statement for the winget Catalogue

**Input**: Design documents from `specs/083-privacy-policy-winget/`
**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: No automated test code. The spec's success criteria require three
verification activities, which are tasks here: the independent claim review
(SC-003), the reader test (SC-004) and manifest validation (SC-001, W2).

**Organization**: grouped by user story (spec.md). All paths are relative to
the repository root `E:\Projects\tandemcommander`.

**Conventions for every task**:
- Markdown files in this repository are UTF-8 **without BOM**, CRLF line
  endings (as `README.md` / `CHANGELOG.md`); write with those.
- No product code, UI, translation or installer changes (FR-010). Do not push
  to microsoft/winget-pkgs, do not submit, do not run `publish.ps1 -Submit`.
- Record progress in `specs/083-privacy-policy-winget/fix-log.md` as you go
  (project convention), not only at the end.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an incomplete task)
- **[Story]**: US1 (moderator finds disclosure), US2 (reader understands), US3 (statement stays true)

---

## Phase 1: Setup

**Purpose**: the feature's working record and the one external fact that
changes the document's wording.

- [X] T001 Create `specs/083-privacy-policy-winget/fix-log.md` with sections: *Status*, *Pre-flight* (T002–T003 results), *Claim map* (table: claim text → inventory ids from research.md / `attribution` / `scope`, verdict column), *Independent review*, *Reader test*, *Manifest validation*, *Open items*.
- [X] T002 Query `GET https://api.github.com/repos/tandemcommander/tandemcommander/private-vulnerability-reporting` (read-only; token via `git credential fill` in an Authorization header, never printed) and record `enabled` with date in `specs/083-privacy-policy-winget/fix-log.md` § Pre-flight. If `false`, the Contact section of PRIVACY.md uses the issue tracker only (contract C7) and an *Open item* says: "maintainer enables Settings → Security → Private vulnerability reporting, then add the second contact line".

---

## Phase 2: Foundational (blocking prerequisites)

**Purpose**: the statement may only assert what is true at HEAD (FR-003,
FR-005). research.md was produced on 2026-09-30; re-confirm the claims whose
error would be most damaging before writing a word.

- [X] T003 Re-verify at HEAD, by opening the cited lines, these inventory rows of `specs/083-privacy-policy-winget/research.md` and record each as confirmed/changed in `fix-log.md` § Pre-flight: `net-none-core` (re-run the dumpbin import scan of `build\tandemcommander\Release_x64` from research.md, or state the build is unchanged since 2026-09-20 via `git log --since=2026-09-20 -- src/`), `crash-report` (read `src/bugreprt.cpp` sections cited and `src/callstk.cpp:724-783`), `pwd-scramble` and `pwd-aes` (`src/pwdmngr.cpp:21-114,552-575`), `ftp-history` F1 (`src/plugins/ftp/dialogs1.cpp:926-932`), `net-mdview-img` User-Agent string (`src/plugins/mdview/webglue.cpp:96`), uninstall behaviour (`setup/tandemcommander.iss` has no `[Registry]`, `[UninstallDelete]` or uninstall `[Code]`). Any changed row: update research.md in the same step.
- [X] T004 [P] Add the side findings F1–F9 from `specs/083-privacy-policy-winget/research.md` § Side findings to `specs/NEXT-WORK.md` as a new numbered item ("Privacy-relevant defects found by feature 083"), F1 first and marked highest priority, each one line with its evidence reference, pointing to research.md for detail. Do not fix any of them.

**Checkpoint**: facts confirmed; writing can start.

---

## Phase 3: User Story 1 — a catalogue moderator finds a privacy disclosure (Priority: P1) 🎯 MVP

**Goal**: `PRIVACY.md` exists, is accurate, and the winget template points to it.

**Independent Test**: quickstart.md §1, §2, §4 — every claim mapped and
`supported`; `publish.ps1 -Version 0.1.8` renders the `PrivacyUrl` line and
`winget validate` succeeds.

- [X] T005 [US1] Write `PRIVACY.md` at the repository root, sections 1–11 in the order and with the content rules of `specs/083-privacy-policy-winget/contracts/privacy-statement.md` (C2–C7), drawing every fact from the inventory in `specs/083-privacy-policy-winget/research.md`. Must include: the plain-language summary; stored data grouped (settings & histories incl. the Save History / Save Working Dirs options and Clear History; saved connections; crash reports with what they contain — paths, file names, full command line, drive volume labels and serial numbers — and that they are never sent; WebView2 engine data; temporary files; the jump list); saved passwords (AES with master password; **without it only obfuscated, reversible by anyone who has the source** — recommend a master password; the FTP Address-history caveat F1: "do not type a password into the address, use the password field"; SFTP saves only when "Save password/passphrase" is ticked); network uses (FTP is **unencrypted** incl. password, FTPS unavailable in this version; SFTP encrypted, host-key prompt; remote images only after *Load Remote Images*, per window, image server sees IP address, time, address and the identification `OpenSalamander-mdview`; network drives via Windows prompts; links open only on click, incl. the third-party pictview.com page; mail via the user's mail program); components governed by others (Windows, Microsoft Edge WebView2 incl. that its diagnostic data and crash reports follow Microsoft's rules and Windows settings, shell/cloud providers, configured external archivers, third-party plugins); optional components (disabled plugins not distributed); install/uninstall (uninstall leaves `HKCU\Software\Tandem Commander`, `%LOCALAPPDATA%\Tandem Commander`, `%APPDATA%\Tandem Commander`, the shell-extension registration); removal steps for each location; older versions (0.1.0–0.1.7 crash-report helper, upload disabled); contact per T002; validity line "This statement describes Tandem Commander 0.1.8. Last updated <date>." Scope statement per C5. No source paths, no legal-role language (C4).
- [X] T006 [US1] Fill `specs/083-privacy-policy-winget/fix-log.md` § Claim map: one row per factual sentence/bullet of `PRIVACY.md` → inventory ids (or `attribution`/`scope`). Any sentence without a row: remove it or rewrite as attribution (C1, C6).
- [X] T007 [P] [US1] In `tools/winget/templates/locale.en-US.yaml.in` add `PrivacyUrl: https://github.com/tandemcommander/tandemcommander/blob/main/PRIVACY.md` directly after the `PublisherSupportUrl:` line (contract W1), and extend the template's header comment block with: why the field exists (moderators ask credential-storing packages for a privacy disclosure — `specs/072-winget-distribution/REMAINING-WORK.md` § P0 item 3, feature 083) and that `PRIVACY.md` must be updated with any change listed in its update rule. Comment lines only in the header block; never start a line inside a block scalar with `#`.
- [X] T008 [P] [US1] In `tools/winget/README.md` add one sentence/table entry stating that the locale template carries `PrivacyUrl` pointing at `PRIVACY.md` on `main`, and that the URL returns 200 only once `PRIVACY.md` is on `main` (contract W3).
- [X] T009 [US1] Run `powershell -NoProfile -ExecutionPolicy Bypass -File tools\winget\publish.ps1 -Version 0.1.8` (no `-Submit`); confirm `Manifest validation succeeded.` and that `tools\winget\manifests\0.1.8\PavelStupka.TandemCommander.locale.en-US.yaml` contains the `PrivacyUrl` line verbatim; record in `fix-log.md` § Manifest validation; then delete the generated `tools\winget\manifests\0.1.8\` directory (contract W4 — not committed by this feature).
- [X] T010 [US1] Independent claim review (SC-003): launch a separate agent that did not write `PRIVACY.md`, give it `PRIVACY.md`, `research.md` and the claim map, instruct it to re-open the cited evidence (read-only) and mark every claim `supported` / `overstated` / `false` with reasons. Record verdicts in `fix-log.md` § Independent review. Fix `PRIVACY.md` (and research.md if evidence was wrong) and repeat until every claim is `supported`.

**Checkpoint**: US1 deliverable complete — the document is true and the template references it.

---

## Phase 4: User Story 2 — a user learns what the program does with their data (Priority: P2)

**Goal**: the statement is understandable without technical knowledge.

**Independent Test**: quickstart.md §3 — 8/8 questions answered correctly from
`PRIVACY.md` alone, under 10 minutes.

- [X] T011 [US2] Reader test (SC-004): launch a separate agent with **only** `PRIVACY.md` (no repository access, no research files) and the eight questions of `specs/083-privacy-policy-winget/quickstart.md` §3; compare its answers with `research.md`; record score and any misunderstanding in `fix-log.md` § Reader test; revise `PRIVACY.md` wording (not facts) for every miss and re-run until 8/8. If wording changes touch a claim, update the claim map (T006).
- [X] T012 [P] [US2] In `README.md` add a short **Privacy** paragraph (one or two sentences: no telemetry, see PRIVACY.md) with a relative link `[PRIVACY.md](PRIVACY.md)`, placed before `## License`.

**Checkpoint**: US1 + US2 — true and readable.

---

## Phase 5: User Story 3 — the statement stays true as the product changes (Priority: P3)

**Goal**: future changes cannot silently make the statement false.

**Independent Test**: quickstart.md §7 — `CLAUDE.md` names `PRIVACY.md` and
lists the C8 triggers; `PRIVACY.md` carries the validity line.

- [X] T013 [US3] In `CLAUDE.md`, add to the *Key Facts* section a bullet **"Privacy statement (feature 083)"**: `PRIVACY.md` is a public claim referenced by the winget `PrivacyUrl`; it MUST be updated in the same change as any of the contract C8 triggers (new/changed network communication; a plugin enabled in the default build; a change to what is stored, where, or how credentials are protected; a change to crash reporting; a change to what the installer/uninstaller writes or removes), together with its validity line; evidence lives in `specs/083-privacy-policy-winget/research.md`.
- [X] T014 [US3] In `CLAUDE.md` *Recent Changes*, add an entry `083-privacy-policy-winget` summarising: what PRIVACY.md covers, the evidence method (four-way inventory + dumpbin import check), the `PrivacyUrl` template field, the private-reporting gate, and that F1–F9 are recorded in NEXT-WORK, not fixed.

**Checkpoint**: all three stories complete.

---

## Phase 6: Polish & cross-cutting

- [X] T015 [P] Update `specs/072-winget-distribution/REMAINING-WORK.md` § P0 item 3 and recommended-plan step 3: `PRIVACY.md` and the template field now exist (feature 083); what remains is only its reachability on `main` (W3), the private-reporting setting (if still off), and including the field in the next push to #426090. Update the pointer paragraph in `specs/NEXT-WORK.md` item 6 accordingly.
- [X] T016 Run quickstart.md §1, §2 (already done in T010), §3 (T011), §4 (T009), §6 and §7 and record the outcomes in `fix-log.md` § Status; mark §5 (URL returns 200) as **owed after merge and push to main**, with the exact `curl` command.
- [X] T017 Write `specs/083-privacy-policy-winget/closing-report.md`: deliverables, evidence, review results, what is owed to the maintainer (enable private reporting → add contact line; merge + push; verify §5; decide when the field goes to #426090 — recommended with the move to 0.1.8), and F1–F9 pointer. Mark all completed tasks `[X]` in this file.

---

## Dependencies & Execution Order

- **Phase 1 → Phase 2 → US1**: T002 decides Contact wording; T003 must pass before T005.
- **US1 internal**: T005 → T006 → T010 (review needs the claim map). T007, T008 are independent of T005 ([P]); T009 needs T007.
- **US2** needs a reviewed `PRIVACY.md` (after T010); T012 independent ([P]).
- **US3** can start after T005 (needs the validity line to exist); T013, T014 same file → sequential.
- **Polish** after all stories; T015 independent of T016/T017.

### Parallel opportunities

- T004 alongside T003.
- T007 and T008 alongside T005/T006.
- T012 alongside T011.
- T015 alongside T016.

### Parallel example (US1)

```text
T005 Write PRIVACY.md            | T007 Template PrivacyUrl line
                                 | T008 winget README sentence
T006 Claim map                   | T009 publish.ps1 validate (after T007)
T010 Independent review (after T006)
```

---

## Implementation Strategy

**MVP = Phase 1–3 (US1)**: a reviewed, evidence-mapped `PRIVACY.md` plus the
template field — enough for the next catalogue push. US2 (readability) and
US3 (update rule) should still land in the same merge: the statement must not
reach `main` without the rule that keeps it true.

**Not in this feature**: fixing F1–F9; pushing to #426090; enabling the
private-reporting setting (maintainer); committing `tools/winget/manifests/0.1.8/`.
