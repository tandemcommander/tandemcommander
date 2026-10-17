# Feature Specification: Release Preparation Skill `tandem-release`

**Feature Branch**: `243-tandem-release-skill`
**Created**: 2026-10-17
**Status**: Draft
**Input**: User description: "Na zaklade kontextu priprav implementaci release skillu s nazvem tandem-release. V ramci clarity faze ti odpovim na vsechny nejasnosti resp. na zminena Questions"
(Based on the conversation, prepare the implementation of a release skill named `tandem-release`; the maintainer answers the open points and the listed questions in the clarify phase.)

## Context

A release of Tandem Commander has been prepared by hand ten times (0.1.0 –
0.1.9 published, 0.1.10 prepared on 2026-10-13/14 and not published). Each
preparation edits the same set of records: the version and build number in
the source (`src/plugins/shared/spl_vers.h`), the installer script
(`setup/tandemcommander.iss`), the changelog heading and lead paragraph
(`CHANGELOG.md`), the privacy statement's validity paragraph and date
(`PRIVACY.md`), the product line and status of `CLAUDE.md` and of
`architecture/12-project-reference.md`, the *Current release* section of
`backlog/RELEASE.md`, and the GitHub release notes (now tracked in
`release_notes/release_notes_v<x.y.z>.md`; the published GitHub release bodies
equal these files).

The history shows recurring mistakes: a section dated as if released two days
early (0.1.8), changelog headings lost twice by later edits, a release date that
had to move in a growing list of places when the release slipped (now at least
six places, of which the release notes and the *Status* date of `CLAUDE.md`
appear in no written list), drafted changelog texts never folded in, and lists
of "what a release bumps" that disagree between the constitution, `CLAUDE.md`
and `RELEASE.md`. Nothing checks that the installer version equals the source
version, and the winget publishing script accepts a wrong changelog heading or
a missing lead paragraph with only a warning, so the error would reach a public
manifest. The analysis is recorded in `temp/tandem-release/PODKLADY.md` (not
tracked) and summarized in `research.md` of this feature.

The maintainer wants one command, given only the version number, that brings
the whole repository into the state from which that version is released **the
same day**: every record states that version, its build number and today's
date, the release notes are complete, and the tree is verified. Signing,
tagging, pushing, publishing the GitHub release and the winget submission stay
the maintainer's steps.

## Clarifications

### Session 2026-10-17

- Q: Which state of the repository does the skill prepare for release, and where does its commit go? → A: Always the HEAD of the current branch, and the commit goes on that branch. The normal case is `main`; when the current branch is not `main`, the skill says so explicitly and asks whether it really should prepare the release there, and goes on only after a yes. For 0.1.10 this is option C of `post-142-fixes-joining-0-1-10-decision` (features 124–241).
- Q: What does the skill run to verify the prepared tree? → A: Only the consistency check of the release records and the encoding guard. The skill only prepares and sets up the release; builds and tests are done before it runs, and the maintainer builds the complete signed program with `build.cmd` by hand afterwards. No builds, unit tests or GUI probes inside the skill.
- Q: How does the skill treat the person steps that `RELEASE.md` lists as gating the release? → A: Before any change it lists the open ones (title and link) and asks "N person steps that gate the release are open - prepare the release anyway?"; without a yes it ends with nothing changed. After a yes they are also listed in the final report and in *Current release* of `RELEASE.md`. (First answered "list only, no question"; changed by the maintainer to the question.)
- Q: What form does the changelog section of the released version take? → A: The lead paragraph `**Build N.** <Kind> release. …` is restored (at most 900 characters after the winget clean-up, no `#`). Entries are not regrouped; the constitution's *Release Documentation* rule is amended so that the Added / Changed / Fixed / Removed groups are optional and bullets citing their feature (and GitHub issue) are an accepted form.
- Q: Which inconsistencies found by the analysis does this feature fix itself, and what happens to the SHA-256 / VirusTotal step of the release notes? → A: This feature fixes the release-procedure records: `RELEASE.md` (`temp/` → `release_notes/`, the list of dates to move, the commit reference of the closing pass, "release on another day = run the skill again") and one list of release records shared by `CLAUDE.md`, the constitution and `RELEASE.md`. The SHA-256 / VirusTotal step is removed from the procedure (it was never done; winget computes the hash itself). The old copyright notices without the Tandem holder and the stale claim in the winget README go to the backlog *Inbox*. `shellext.rc`'s fixed `FILE_SALVER "0.1.0"` is out of scope: the shell extension is not in the shipped tree (whether it ships is backlog decision `copy-hook-for-drag-out-of-archives`).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Prepare a new version for release today (Priority: P1)

The maintainer decides to release the work collected since the last release.
They run the skill with the new version number (for example `0.1.11` after
`0.1.10` was published). The skill determines the previous release, raises the
version and the build number, turns the unreleased changelog section into the
section of the new version dated today with a lead paragraph that states the
build and the kind of release, writes the release notes, updates every other
release record, verifies the tree and commits the result locally. The
maintainer reviews one commit and then performs only their own publishing
steps.

**Why this priority**: This is the purpose of the feature; every release goes
through it.

**Independent Test**: On a copy of the repository whose last tag is `v0.1.10`
and whose changelog has an unreleased section, run the skill with `0.1.11`; the
consistency check reports every record at 0.1.11 / build (previous + 1) /
today, the release notes file exists in the established format, and exactly one
new local commit exists, nothing pushed or tagged.

**Acceptance Scenarios**:

1. **Given** the last tag `v0.1.10` (build 194) and a changelog section
   `[0.1.11] — unreleased`, **When** the maintainer runs the skill with
   `0.1.11` on 2026-11-02, **Then** the source states version 0.1.11 and build
   195 with a build-history comment naming 0.1.11, the installer script states
   0.1.11, the changelog heading is `## [0.1.11] — 2026-11-02` with a lead
   paragraph beginning `**Build 195.**`, the privacy statement describes
   0.1.11 and is dated 2026-11-02, `CLAUDE.md`, the project reference and
   `RELEASE.md` state 0.1.11 / build 195 / released 2026-11-02 from tag
   `v0.1.10`, and `release_notes/release_notes_v0.1.11.md` begins with
   `**Released 2 November 2026 · build 195 · Windows 11 or newer, 64-bit · …**`.
2. **Given** the same state, **When** the run finishes, **Then** one new commit
   exists on the local branch, no tag `v0.1.11` exists, nothing was pushed, and
   the final report lists the maintainer's remaining steps in order.

---

### User Story 2 - Re-prepare a version that was prepared but not published (Priority: P1)

A version was prepared on an earlier day but not published (today's 0.1.10:
dated 2026-10-14, build 194 already set, and a later section
`[0.1.11] — unreleased` holding the work done since). The maintainer runs the
skill with `0.1.10` on the day they intend to publish. The skill keeps the
build number, moves every release date to today, folds the later unreleased
sections into the 0.1.10 section, rewrites the lead paragraph to cover the
whole content, extends the existing release notes with the changes they do not
yet describe, and updates every record that names the content of the release
(feature range, release state, steps owed to a person).

**Why this priority**: It is the situation of the very next release, and a
slipped release date has been the most frequent source of stale records.

**Independent Test**: On the current repository (2026-10-17), run the skill
with `0.1.10`; afterwards no record states 2026-10-14 or 2026-10-13 as the
release date of 0.1.10, the changelog has no section above `[0.1.10]`, the
build stays 194, and the release notes describe the content of the merged
section.

**Acceptance Scenarios**:

1. **Given** `spl_vers.h` at 0.1.10 / build 194 with a history comment naming
   0.1.10, last tag `v0.1.9` (build 193), **When** the skill runs with
   `0.1.10`, **Then** the build number stays 194 and the comment is extended
   to name the content added since it was written.
2. **Given** `## [0.1.11] — unreleased` above `## [0.1.10] — 2026-10-14`,
   **When** the skill runs with `0.1.10` on 2026-10-17, **Then** one section
   `## [0.1.10] — 2026-10-17` holds the entries of both, the newer entries
   first, and every older section heading (0.1.9 … 0.1.0) is still present
   exactly once.
3. **Given** the release notes of 0.1.10 dated "14 October 2026" and
   describing features 124–142 only, **When** the run finishes, **Then** they
   are dated "17 October 2026" and every user-visible entry of the merged
   changelog section is represented in them.
4. **Given** the run already succeeded today, **When** the maintainer runs it
   again the same day with the same version, **Then** nothing changes and no
   new commit is made.

---

### User Story 3 - Refuse what must not be prepared (Priority: P1)

The skill stops before changing anything when the request or the repository
state makes a preparation wrong: the version is already published (its tag
exists locally or on the remote), the version text is not a plain
`MAJOR.MINORA.MINORB`, the version is not higher than the last release, the
major or minor part changes (the configuration location depends on them and
the constitution forbids moving it without a migration), the source states a
version or build that fits neither the previous release nor the requested one,
a dated changelog section of another version stands above the previous
release, the working tree has uncommitted changes, an autonomous backlog run
holds the backlog lock, or the calendar year has passed the copyright year of
the program's notices.

**Why this priority**: A wrong preparation reaches public places (installer,
GitHub release, winget manifest, the in-app new-version check) where it cannot
be withdrawn; a published binary is never replaced.

**Independent Test**: For each refusal condition, prepare the state, run the
skill, and confirm the tree and the branch are unchanged and the message names
the condition and what to do.

**Acceptance Scenarios**:

1. **Given** tag `v0.1.9` exists, **When** the skill runs with `0.1.9`,
   **Then** it stops with "0.1.9 is already released (tag v0.1.9)" and
   changes nothing.
2. **Given** the last release 0.1.10, **When** the skill runs with `0.2.0`,
   **Then** it stops and explains that a minor-version change moves the
   configuration root and needs a migration decision first.
3. **Given** the version text `v0.1.11` or `0.1.011`, **When** the skill
   runs, **Then** it stops and states the accepted form.
4. **Given** the date is 2027-01-05 and the notices say 2026, **When** the
   skill runs, **Then** it stops and names the copyright places that need the
   maintainer's decision.

---

### User Story 4 - Verify the prepared tree before handing it over (Priority: P2)

After the edits the skill proves that the release records are right: all of
them agree (version, build, dates, previous version), the changelog's lead
paragraph will become a correct public winget summary (within the length limit,
no line lost to the publishing script's comment rule, not a bullet), the
release notes follow the established format, and the encoding guard passes. A
failure stops the run before the commit and is reported with its output. The
skill builds and tests nothing: the code was built and tested before the run,
and the maintainer builds the signed program by hand afterwards.

**Why this priority**: The commit is only useful if the maintainer can build
the signed installer from it without correcting a record first.

**Independent Test**: Introduce one inconsistency (for example the installer
version left at the old value) after the edit step; the check reports it, no
commit is made, and the report names the file and line.

**Acceptance Scenarios**:

1. **Given** a prepared tree, **When** verification runs, **Then** the report
   lists each check with its result, and no build or test was started.
2. **Given** a lead paragraph that would exceed 900 characters after the
   publishing script's clean-up, **When** verification runs, **Then** it fails
   and shows the computed summary.

---

### User Story 5 - Release notes in the established format (Priority: P2)

The skill drafts or updates `release_notes/release_notes_v<x.y.z>.md` as the
GitHub release body: title, the `**Released <d Month yyyy> · build N ·
Windows 11 or newer, 64-bit · <kind>**` line, sections *New*, *Changed*,
*Fixed* (with bold topic groups), *Removed* (empty ones left out), one-line
bullets in the user's terms with GitHub issue references, and the fixed footer
line. The content is a condensed rewrite of the release's changelog section,
not a copy.

**Why this priority**: The notes are the public face of the release; the
format is established and the content must cover the release.

**Independent Test**: Compare a generated file with the published 0.1.9 body:
same structure, same header and footer patterns; every user-visible changelog
entry of the section maps to a bullet.

**Acceptance Scenarios**:

1. **Given** a release section with entries citing GitHub issues, **When** the
   notes are written, **Then** each such entry's bullet carries `(#n)`.

---

### User Story 6 - Hand-over report and dry run (Priority: P3)

At the end the skill reports: the commit, what changed in each record, the
verification results, the maintainer's remaining steps in order (merge if
needed, signed build with installer, tag, switching the winget workflow off
while the pending winget PR is unsettled, the GitHub release with the exact
installer asset name and the release notes as its body, the after-publishing
checks), and the steps owed to a person that gate the release. With a dry-run
option it reports what it would change and does not change anything.

**Why this priority**: The report replaces reading `RELEASE.md` by hand; the
dry run lets the maintainer look before deciding to release today.

**Independent Test**: Run with the dry-run option on the current repository
with `0.1.10`; the tree and branch are unchanged and the report lists the
intended edits of every record.

**Acceptance Scenarios**:

1. **Given** open person steps marked as gating the release, **When** the run
   ends, **Then** the report lists them by title and link.

---

### Edge Cases

- The current branch is not `main` (for example a feature branch or
  `release-0.1.10-final`): the skill names the branch, says that releases are
  normally prepared on `main`, and asks; a "no" or no answer ends the run with
  nothing changed.
- The requested version skips a number (0.1.12 after 0.1.10): the skill asks
  the maintainer to confirm before going on.
- Release branches named for the version exist with commits the current state
  does not contain (`release-0.1.10`, `release-0.1.10-final`): the skill
  reports them and states which state it prepares; a branch recorded as
  "must not be tagged" stays recorded as such.
- The plugin interface version changed since the previous release: the
  interface history line and the "first shipped in version …" text are set to
  the new version; if unchanged, they are left alone (true for 0.1.10: 107 since
  0.1.9).
- The privacy statement was not changed since the previous release but the
  release contains changes that may be privacy-relevant (network, storage,
  plug-ins enabled, crash reports, installer): the skill reviews them and, if
  one applies, stops and asks rather than inventing a privacy claim.
- A changelog lead paragraph or bullet contains `#` (GitHub issue numbers):
  allowed in bullets, never in the lead paragraph.
- The build output directory variable points elsewhere than the directory the
  installer script packs from: the report warns the maintainer.
- The code-signing certificate expires within 60 days: the report warns.
- The run is interrupted after edits but before the commit: a second run
  starting from the dirty tree refuses (dirty tree) and the report of the
  refusal says how to discard or keep the partial edits.
- Drafted changelog texts found in fix-logs of features in the release but not
  in the changelog: reported for the maintainer; not silently added.

## Requirements *(mandatory)*

### Functional Requirements

**Invocation and preconditions**

- **FR-001**: The skill MUST take exactly one mandatory argument, the version
  `MAJOR.MINORA.MINORB` in canonical form (decimal parts without leading
  zeros, the same form the in-app new-version check accepts), and MAY take an
  explicit release date (default today, local time) and a dry-run option.
- **FR-002**: The skill MUST stop without any change when the version's tag
  exists locally or on the remote, when the version is not higher than the
  last released version, when MAJOR or MINORA differ from the last release,
  when the working tree is not clean, when the backlog lock is held, or when
  the release year is later than the copyright year of the program's notices.
- **FR-003**: The skill MUST determine the previous release from the tags and
  its build number from the source as of that tag.
- **FR-004**: The skill MUST prepare the state of the current branch's HEAD
  and MUST report release branches of the same version that hold commits not
  in HEAD. When the current branch is not `main`, it MUST say so explicitly
  and ask whether to prepare the release on that branch; without a yes it
  MUST stop without any change.
- **FR-004a**: Before any change the skill MUST list the open person steps
  that `RELEASE.md` / the backlog name as gating the release (title and link)
  and, when there is at least one, ask whether to prepare the release anyway;
  without a yes it MUST stop without any change.

**Records**

- **FR-005**: The skill MUST set the product version and the build number in
  the source: build = previous release's build + 1; when the source already
  states the requested version with that build, it MUST keep it; any other
  state MUST stop the run.
- **FR-006**: The skill MUST keep the build-history comment of the source
  naming the version and summarizing the release's content with its feature
  numbers, and MUST touch the plugin-interface history only if the interface
  version changed since the previous release.
- **FR-007**: The skill MUST set the installer script's version.
- **FR-008**: The skill MUST produce exactly one changelog section for the
  version, headed `## [x.y.z] — YYYY-MM-DD` with the release date, holding the
  entries of every unreleased section above the previous release (newest
  first) and of an earlier dated section of the same version, and MUST keep
  every older section heading exactly once and in order.
- **FR-009**: The changelog section MUST open with a lead paragraph starting
  `**Build N.** <Kind> release.`, summarizing the release, containing no `#`,
  of at most 900 characters after the winget script's clean-up, and MUST NOT
  keep notes such as "not released yet". The entries below it are kept in
  their order and form (bullets citing feature and GitHub issue); the skill
  does not regroup them.
- **FR-010**: The skill MUST update the privacy statement's validity paragraph
  ("This statement describes Tandem Commander x.y.z … In <previous>, the
  version before it, …", shifting the older version's sentence when the
  version is new) and its "Last updated" date.
- **FR-011**: The skill MUST update the product line and the *Status* section
  of `CLAUDE.md` (version, build, release date, feature range, previous
  version / build / tag) and the product line of the project
  reference, with the same values.
- **FR-012**: The skill MUST rewrite the *Current release* section of
  `RELEASE.md`: version, build, "prepared, not published", the commit to
  release, branches that must not be tagged, gating person steps and the
  verification record.
- **FR-013**: The skill MUST create or update the release notes file of the
  version in the format of User Story 5, with the release date in English
  long form, covering every user-visible entry of the changelog section.
- **FR-014**: The skill MUST NOT change historical records: older changelog
  sections, release notes of published versions, the build and interface
  history, recorded winget manifests, test data and the configuration root.
- **FR-015**: A repeated run on the same day with the same version MUST change
  nothing; a run on a later day MUST move every release date and fold any new
  unreleased entries.

**Content review**

- **FR-016**: The skill MUST review the change set since the previous release
  for user-visible changes missing from the changelog and for drafted
  changelog texts left in fix-logs, and report them; it MUST add confirmed
  user-visible omissions only with the maintainer's agreement.
- **FR-017**: The skill MUST check the change set against the privacy
  statement's triggers (network communication, a new URL, plug-ins enabled or
  shipped, stored data and credentials, crash reporting, installer and
  uninstaller) and stop and ask when a trigger applies and the statement does
  not reflect it.
- **FR-018**: When the run answers an open maintainer decision of the backlog
  about the content of this release, the skill MUST ask for confirmation and
  record it through the backlog skill; it MUST NOT change any other backlog
  item, and new findings go to the *Inbox* only.

**Verification and hand-over**

- **FR-019**: A repeatable consistency check MUST confirm that all records of
  FR-005 – FR-013 agree for the version, the build, the release date and the
  previous version, that the computed winget summary meets FR-009, and that
  the release notes follow the format; it MUST name file and line of each
  finding.
- **FR-020**: After the edits the skill MUST run the consistency check of
  FR-019 and the encoding guard; any failure MUST stop the run before the
  commit. It MUST NOT start a build, the unit tests or GUI probes.
- **FR-021**: The skill MUST make exactly one local commit with the subject
  `Version x.y.z: the tree prepared for the release (YYYY-MM-DD)` and a body
  stating what changed, what was verified and the maintainer's steps; it MUST
  NOT sign, build an installer into the archive of published installers, tag,
  push, publish or submit anything.
- **FR-022**: The final report MUST list the maintainer's steps in order, the
  gating person steps (by title and link) and the warnings of the edge cases; with the dry-run
  option it MUST list the intended edits and change nothing.

**Records of the procedure**

- **FR-023**: `RELEASE.md`, `CLAUDE.md` and the constitution MUST name the
  same list of release records (or point to one list), `RELEASE.md` MUST name
  `release_notes/` instead of the untracked `temp/` drafts, its "release on
  another day" step MUST say to run the skill again, its closing-pass
  reference MUST name the commit that recorded it (`8e5d6c8a`), and its step
  "release notes: the installer's SHA-256 and a VirusTotal link" MUST be
  removed.
- **FR-023a**: The old copyright notices without the Tandem holder and the
  stale `PrivilegesRequiredOverridesAllowed` claim of the winget README MUST
  be recorded as *Inbox* items of the backlog (source `review:243`), not
  fixed here.
- **FR-024**: The constitution's *Release Documentation* rule MUST be amended
  (with its version and amendment record) so that the Added / Changed / Fixed
  / Removed groups are optional, bullets citing their feature are an accepted
  form, and the lead paragraph `**Build N.** <Kind> release.` is required.

### Key Entities

- **Target version**: the requested `MAJOR.MINORA.MINORB`; its tag
  `v<x.y.z>`; its installer name `tandemcommander-<x.y.z>-x64-setup.exe`.
- **Previous release**: the highest existing tag below the target; its build
  number; its version text in the privacy paragraph and product lines.
- **Build number**: one integer shared by the program and every plug-in,
  previous + 1 per release, with a history comment.
- **Release date**: the day of publication (default today); written as
  `YYYY-MM-DD` in records and as `d Month yyyy` in the release notes.
- **Release records**: the source version block, the installer script, the
  changelog section, the privacy paragraph and date, the product lines of
  `CLAUDE.md` and the project reference, the *Status* of `CLAUDE.md`, the
  *Current release* of `RELEASE.md`, the release notes file.
- **Changelog section**: heading, lead paragraph, entries with feature and
  issue references.
- **Release state**: not prepared / prepared on an earlier day / prepared
  today / released — derived from the tags, the source and the changelog.
- **Hand-over report**: changes per record, verification results, maintainer
  steps, gating person steps, warnings.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After a successful run, the consistency check finds 0 records
  that state another version, build or release date than the prepared one.
- **SC-002**: For the current repository and version 0.1.10 run on its
  publication day, 0 places still state 2026-10-13 or 2026-10-14 as the
  release date and 100 % of the user-visible entries of the 0.1.10 changelog
  section are represented in its release notes.
- **SC-003**: A second run on the same day changes 0 files and makes 0
  commits.
- **SC-004**: Every refusal condition of User Story 3 leaves the tree, the
  index and the branch unchanged (verified for each condition).
- **SC-005**: The maintainer's work after the run consists only of the steps
  listed in the report; no record needs a manual edit before tagging (checked
  on the next real release).
- **SC-006**: The run does 0 of: signing, tagging, pushing, publishing,
  winget submission, changing a published version's records.
- **SC-007**: The winget summary computed from the prepared changelog is
  between 1 and 900 characters and loses 0 lines to the publishing script's
  comment rule.

## Assumptions

The questions Q1–Q8 of the analysis: Q1–Q4 and Q6–Q8 were settled in the
clarify session of 2026-10-17 (*Clarifications*); Q5 keeps its default.

- **Q1/Q2 – what is released and where the commit goes**: settled in
  *Clarifications* (HEAD of the current branch, commit there, explicit
  question when not on `main`).
- **Q3 – verification scope**: settled in *Clarifications* (consistency
  check and encoding guard only; no builds, tests or probes).
- **Q4 – gating person steps**: settled in *Clarifications* (listed, then one
  question whether to go on).
- **Q5 – helper tool**: the mechanical edits and the consistency check are a
  repository tool with its own tests (in the manner of the backlog tool of
  feature 242); the wording (lead paragraph, release notes, comments, privacy
  paragraph) is written by the skill and reviewed by the maintainer in the
  commit.
- **Q6 – changelog form**: settled in *Clarifications* (lead restored, no
  regrouping, constitution amended).
- **Q7/Q8 – inconsistencies and the SHA-256 / VirusTotal step**: settled in
  *Clarifications* (release-procedure records fixed here, the SHA-256 step
  removed, copyrights and the winget README to *Inbox*, `shellext.rc` out of
  scope).
- The skill is started only by the maintainer (never on the model's own
  initiative) and may ask the maintainer questions; it is not an unattended
  run like `tandem-backlog-implement`.
- Repository text written by the skill is English; the maintainer may write
  in Czech.
- The local date of the maintainer's machine is the release date unless a
  date is given.
- Python is available, as for every build of the project. The code to
  release has been built and tested before the run; the skill does not
  repeat it.
