# Contract: the release records and their formats

`<ver>` target version, `<N>` build, `<D>` release date `YYYY-MM-DD`,
`<DL>` release date long (`17 October 2026`), `<P>` previous version,
`<PN>` previous build. Line numbers are those of 2026-10-17 and only orient.

## 1. `src/plugins/shared/spl_vers.h` (UTF-8 with BOM)

```c
#define VERSINFO_SALAMANDER_MAJOR 0
#define VERSINFO_SALAMANDER_MINORA 1
#define VERSINFO_SALAMANDER_MINORB 10
…
// <N> - Tandem Commander <ver> (<summary - features …>; see CHANGELOG.md)
//       <continuation lines, 7 spaces after "//">

// ! DULEZITE: …
#define VERSINFO_BUILDNUMBER <N>
```

The history entry sits directly above the `// ! DULEZITE` line, after the
entry of `<PN>`. Lines ≤ 80 columns. `LAST_VERSION_OF_SALAMANDER` and
`REQUIRE_LAST_VERSION_OF_SALAMANDER` change only if the interface changed
since `v<P>`; then `REQUIRE_…` says `first shipped in version <ver>`.

## 2. `setup/tandemcommander.iss`

`#define MyAppVersion "<ver>"` (line 2). Nothing else.

## 3. `CHANGELOG.md`

```markdown
## [<ver>] — <D>

**Build <N>.** <Kind> release. <Summary of the release in the user's terms;
no "#"; at most 900 characters after the winget clean-up.>

- **<entry>** (feature NNN; GitHub #n) …

## [<P>] — <date of P>
```

`<Kind>`: `Feature` / `Bug-fix` / `Installer-fix` or a short phrase. Exactly
one section above `[<P>]`; every tag `v*` has exactly one section, newest
first. Entries keep their form and order (newest feature first); no
regrouping.

## 4. `PRIVACY.md` (last block)

```markdown
This statement describes Tandem Commander <ver> (`CHANGELOG.md`). In <P>,
the version before it, <what differed, or: nothing described here differed>.
In <older>: <unchanged older sentences> …
Last updated <D>.
```

For a new version the previous `In <P-old>, the version before it, X.` becomes
`In <P-old>: X.` and a new sentence for `<P>` is put before it. When a
privacy trigger applies to the release (CLAUDE.md *Public claims*), the body
of the statement must already say so — the skill asks instead of writing it.

## 5. `CLAUDE.md`

Product line under *Product identity*:

```markdown
- **Tandem Commander <ver>** (internal build <N>, release dated <D>;
  carries features <first>–<last>; previous: <P> / build <PN> / tag
  `v<P>`). Plugin interface version (`LAST_VERSION_OF_SALAMANDER`) **<I>** —
```

and `## Status (<D>)` with a paragraph that says the tree is prepared for the
`<ver>` release, names the gating person steps and the maintainer's steps.

## 6. `architecture/12-project-reference.md`

```markdown
- **Product name**: Tandem Commander, version **<ver>** (internal build <N>,
  release dated <D> — it carries features <first>–<last>,
  everything made since <P> / build <PN> / tag `v<P>`);
```

## 7. `backlog/RELEASE.md`

```markdown
## Current release: <ver> (build <N>) — prepared, not published

- The state to release is `<branch>` at the commit "Version <ver>: the tree
  prepared for the release (<D>)" (the commit cannot name its own hash).
  <Branches that must not be tagged, with the reason.>
- Gating person steps: <optional note on the line itself>
  - `<slug>` — <title>
  (or the single item `- (none)`; the tool reads the backticked slugs of the
  indented items)
- Verified: `release.py check` 0 findings; `check_encoding.py --strict`
  TOTAL 0. Built and tested before the run (not by the skill).
```

Plus the permanent sections *Release records* (the list of these 8 records),
*Preparing the tree* (= run `/tandem-release <ver>`), *Releasing (the
maintainer)*, *After publishing*, *Standing dates*.

## 8. `release_notes/release_notes_v<ver>.md` (UTF-8 without BOM)

```markdown
# Tandem Commander <ver>

**Released <DL> · build <N> · Windows 11 or newer, 64-bit · <kind>**

## New
- **<headline>** (#n). <one line>

## Changed
## Fixed

**<Topic>**

- …

## Removed

---

Install over the previous version — settings are preserved · Free software under the GNU GPL v2 or later · <https://tandemcommander.org> · full detail in `CHANGELOG.md`
```

Sections in this order, empty ones left out, at least one present. Bullets
are single lines (not wrapped). `<kind>` lower case (`feature release`,
`bug-fix release`, `installer fix`, or a short phrase). Every GitHub issue
cited in the changelog section appears as `(#n)`.
