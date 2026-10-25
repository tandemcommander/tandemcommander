# `/tandem-release` — reference

Read the part a step of `SKILL.md` points to. Binding formats:
`specs/243-tandem-release-skill/contracts/records.md`; tool commands and
check rules: `contracts/cli.md`.

Notation: `<ver>` the target version, `<N>` its build, `<D>` release date
`YYYY-MM-DD`, `<DL>` the same as `17 October 2026`, `<P>` / `<PN>` the
previous release and its build, `RT` = `python tools/release/release.py`.

---

## 1. The eight release records

| # | Record | Mechanical (`RT stamp`) | Wording (the skill) |
|---|--------|-------------------------|---------------------|
| 1 | `src/plugins/shared/spl_vers.h` | `VERSINFO_SALAMANDER_*`, `VERSINFO_BUILDNUMBER`, a history entry `// <N> - Tandem Commander <ver> (TODO-SUMMARY; see CHANGELOG.md)`; `REQUIRE_…` "first shipped in version <ver>" if the interface changed since `v<P>` | the summary of the history entry (§2.2) |
| 2 | `setup/tandemcommander.iss` | `MyAppVersion` | — |
| 3 | `CHANGELOG.md` | one section `## [<ver>] — <D>` holding every unreleased section above `[<P>]`; a placeholder lead when none exists | the lead paragraph (§2.1); merge the texts of `dropped-lead:` lines into it |
| 4 | `PRIVACY.md` | "describes <ver>", the chain shift "In <P>, the version before it, TODO-PRIVACY. In <P-old>: …", `Last updated <D>.` | the sentence for `<P>` (§2.3) |
| 5 | `CLAUDE.md` | product line (version, build, release dated, feature range, previous) and `## Status (<D>)` | the *Status* paragraph (§2.5) |
| 6 | `architecture/12-project-reference.md` | product line | — |
| 7 | `backlog/RELEASE.md` | heading `## Current release: <ver> (build <N>) — prepared, not published` | the body of *Current release* (§2.6) |
| 8 | `release_notes/release_notes_v<ver>.md` | skeleton (new) or title / `**Released …**` line (existing) | the content (§3) |

Not release records (never edit for a release): every `.rc`/`.rh2` that
uses the `VERSINFO_*` macros, `translations/*/*.slt` `TEXTVERSION` (written
by the Translator, ignored on import), `tools/winget/manifests/` (made by
`publish.ps1` after publishing), older changelog sections, published
release notes, build/interface history entries of other builds, test data,
the registry root `Software\Tandem Commander\Settings` (version-free since
feature 343), `shellext.rc`'s
`FILE_SALVER` (the shell extension is not shipped).

Copyright years (`src/versinfo.rh2`, plug-in `versinfo.rh2`, standalone
`.rc`, the winget locale template) change only at a year change —
`RT status` refuses with `copyright-year`, and the maintainer decides.

## 2. Wording rules

All repository text is English, plain, in the user's terms; no internal
mechanism without the symptom.

### 2.1 Changelog lead (FR-009)

```text
**Build <N>.** <Kind> release. <2-6 sentences: what a user gets - the most
important fixes and features, data-loss fixes first, then GitHub reports,
then the rest by weight; name limits honestly.>
```

- `<Kind>`: `Feature` (a new capability), `Bug-fix` (fixes only),
  `Installer-fix`, or a short phrase as in 0.1.10 ("Fixes for the problems
  reported on GitHub after 0.1.9").
- **No `#` anywhere** (no `GitHub #7` in the lead — say "the reports made on
  GitHub"); `publish.ps1` drops a wrapped line that starts with `#`.
- At most 900 characters after the winget clean-up — `RT summary <ver>`
  prints the length. Aim for 400–800.
- Wrap at about 78 columns like the rest of the file.
- The lead is the winget *ReleaseNotes* text and the GitHub reader's first
  paragraph: no feature numbers, no file names.
- A text printed as `dropped-lead:` by `stamp` was the `**Build N.**` lead
  of a folded section: merge what it says into the new lead. A first
  paragraph that is not such a lead is a prose entry (the form of 0.1.9's
  "New version check (feature 123). …") and stays in the body untouched.

Example (0.1.9): "**Build 193.** Feature release. The program now tells you
when a newer version has been published: on by default, one request to
GitHub about once a day, nothing about you or your computer is sent, and one
option turns it off. RAR archives open and unpack without installing
anything, …"

### 2.2 Build-history entry in `spl_vers.h`

Replace `TODO-SUMMARY` with a summary grouped by topic, each topic ending
with its features: `texts outside the code page in the Registry Editor -
features 124, 127; a shortcut opens its target - feature 128; …`. Lines at
most 80 columns; continuation lines start with `//` + 7 spaces. Keep the
closing `; see CHANGELOG.md)`. Use ranges for runs (`features 138-140`).
For a re-prepared version, extend the existing entry with the content added
since; do not create a second entry.

### 2.3 Privacy sentence (FR-010, FR-017)

`In <P>, the version before it, TODO-PRIVACY.` becomes a sentence that says
how `<P>` differs from `<ver>` **in what this statement describes**: for
each privacy-relevant change of the release (§4) the old behaviour, e.g.
"In 0.1.9, the version before it, the program does not ask a server for the
list of its shared folders." If nothing described differs: "In <P>, the
version before it, nothing described here differed." Re-wrap the paragraph
at about 78 columns. Never invent a claim; a claim cites reachable code
(feature 083).

### 2.4 Content review

- Delta: `git log --oneline v<P>..HEAD`; feature numbers from commit
  subjects `[NNN]` and from `RT status` (`features:`).
- For every feature of the delta with a user-visible effect
  (`specs/FEATURE-HISTORY.md` entry `- NNN-`), the changelog section must
  have an entry citing it. Internal tooling (like 242, 243) needs none.
- Look for changelog drafts never applied: `grep -n -i "changelog" specs/<NNN>-*/fix-log.md specs/<NNN>-*/closing-report.md`
  for the features of the delta; a drafted text not in `CHANGELOG.md` is
  reported to the maintainer.
- Report findings; add an entry only after the maintainer agrees.

### 2.5 `CLAUDE.md` *Status*

Keep it short (the file is loaded in every session):

```text
## Status (<D>)

Features up to <last> are done. The tree is **prepared for the <ver>
release** (build <N>, commit "Version <ver>: the tree prepared for the
release (<D>)" on `<branch>`, nothing pushed): <gating person steps or
"no person step gates it">; then the maintainer's steps in
`backlog/RELEASE.md` (*Releasing*). <One line on any open winget / earlier
release matter that is still true.>
```

The words "prepared for the <ver> release" are checked (`claude-status`).

### 2.6 `backlog/RELEASE.md` *Current release*

```markdown
## Current release: <ver> (build <N>) — prepared, not published

- The state to release is `<branch>` at the commit "Version <ver>: the tree
  prepared for the release (<D>)" (prepared by `/tandem-release`). It
  carries features <first>–<last> (everything since `v<P>`).
- Branches that must not be tagged: `<branch>` — <reason> (or "none").
- Gating person steps:
  - `<slug>` — <title>
- Verified by the skill: `release.py check` 0 findings,
  `check_encoding.py --strict` TOTAL 0. The code was built and tested before
  the run; the maintainer builds the signed program.
```

Keep the "must not be tagged" notes of the previous text while those
branches exist (`git branch -a --list 'release-*'`). The gating list holds
one indented item per step, its slug in backticks (the tool reads the
backticked slugs). With no gating step write the single item `  - (none)`;
the line `- Gating person steps:` itself must always be there
(`release-current`).

## 3. Release notes (`release_notes/release_notes_v<ver>.md`)

The file is the GitHub release body, published as is. Format (checked by
`RT check`, rules `notes-*`):

```markdown
# Tandem Commander <ver>

**Released <DL> · build <N> · Windows 11 or newer, 64-bit · <kind>**

## New

- **<Headline>** (#n). <One or two sentences.>

## Changed

## Fixed

**<Topic>**

- **<Headline>** <sentence>.

## Removed

---

Install over the previous version — settings are preserved · Free software under the GNU GPL v2 or later · <https://tandemcommander.org> · full detail in `CHANGELOG.md`
```

- Sections only from New / Changed / Fixed / Removed, in this order, none
  empty (leave a section out instead).
- `<kind>` lower case: `feature release`, `bug-fix release`,
  `installer fix`, or the phrase of the changelog lead.
- One bullet = one line (do not wrap); bold headline, then the effect.
  Condense: one bullet may cover several changelog entries of one topic.
- *Fixed* is grouped by bold topic lines (`**Data loss**`, `**Names and
  text in any language**`, `**Long paths**`, `**SFTP**`, `**Privacy and
  security**`, `**Other**` …), data loss first.
- Every GitHub issue cited in the changelog section appears as `(#n)`
  (`notes-issues`).
- No feature numbers, no file paths of the source tree, no SHA-256 or
  VirusTotal link (removed from the procedure by feature 243).
- Re-preparing: keep what is right, add the changes the notes do not yet
  describe, keep the style of the existing text.
- Models: `release_notes/release_notes_v0.1.9.md` (feature release) and
  `v0.1.10.md` (fix release).

## 4. Privacy triggers (CLAUDE.md, *Public claims*)

`PRIVACY.md` must already describe, in its body, any of these changes of the
release — otherwise ask the maintainer (never write the claim yourself):

- new or changed network communication, including a new URL the program
  opens;
- a plug-in enabled in the default build, or a disabled one shipped
  (`git diff v<P>..HEAD -- plugins.cfg`);
- a change to what is stored, where, or how credentials are protected;
- a change to crash reporting;
- a change to what the installer or uninstaller writes or removes
  (`git diff v<P>..HEAD --stat -- setup/`).

How to look: `git diff v<P>..HEAD --stat -- PRIVACY.md plugins.cfg setup/`,
and the FEATURE-HISTORY entries of the delta that mention privacy, network,
registry values, temporary files or the installer.

## 5. Traps (from ten releases)

| Trap | Guard |
|------|-------|
| A section dated as released before it was (0.1.8) | stamp only when the maintainer releases today; a later day = run again |
| Changelog headings lost by later edits (twice) | `changelog-history` |
| Release date moved in some records only | stamp moves all; `check` compares all |
| Drafted changelog texts never applied (075, 077) | §2.4 |
| `MyAppVersion` ≠ source version (nothing checked it) | `installer-version` |
| winget summary from a bullet / cut / lost `#` line | `changelog-lead`, `winget-summary` |
| winget takes the changelog **of the tag** | a mistake after tagging needs a new tag — check before |
| Tagging a stale release branch (`release-0.1.10`: 132 without 135) | *Current release* names branches that must not be tagged |
| The installer packs `build\` regardless of `OPENSAL_BUILD_DIR` | warning `build-dir` |
| The in-app check offers only `v<ver>` + asset `tandemcommander-<ver>-x64-setup.exe`, not draft/prerelease | maintainer's step 4 of the report |
| A released binary is never replaced (winget pins its SHA-256) | rebuild only with a new version |
| A bumped tree is not a release | the tag decides; `RT status` reads local and remote tags |

## 6. The maintainer's steps (for the final report)

1. Releasing on another day than `<D>`? First run `/tandem-release <ver>`
   again that day (it moves every date) — before building and tagging.
2. `build.cmd full release sign setup` (signed tree and installer; the
   installer packs `build\tandemcommander\Release_x64`).
3. Merge / push the branch; tag `v<ver>` on the prepared commit; push the tag.
4. While `microsoft/winget-pkgs#426090` is not settled: switch the
   **Publish to winget** workflow **off** in the Actions tab and check that
   it is off.
5. GitHub release `v<ver>`: body = `release_notes/release_notes_v<ver>.md`;
   asset `tandemcommander-<ver>-x64-setup.exe` (exact name, uploaded); not a
   draft, not a pre-release.
6. *After publishing* in `backlog/RELEASE.md` (the "newer version" check
   from the previous build, an antivirus scan, winget when unblocked).
