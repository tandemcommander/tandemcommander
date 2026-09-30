# Contract: `PRIVACY.md` content

Binding for the first version of the statement and for every later edit.
Source requirements: spec FR-001–FR-009; evidence: [research.md](../research.md).

## C1 — Evidence before text

Every factual sentence about the product maps to at least one inventory row in
`research.md` (§ Data-surface inventory) that carries evidence (`file:line`,
installer section, or a recorded observation). A sentence without such a row is
removed or rewritten as "governed by <vendor>" (C6). The mapping is recorded in
the feature's `fix-log.md` as a claim → evidence table.

## C2 — Required sections (order fixed)

1. **Summary** — three to five sentences a reader can stop after: no
   accounts, no telemetry/analytics/advertising, nothing sent to the project,
   network only on the user's action, data stays on the user's computer.
2. **What the program stores on your computer** — every stored surface from
   the inventory, grouped (settings and history; saved connections and
   passwords; crash reports; viewer engine data; temporary files), each with
   its location in user terms.
3. **Saved passwords** — protection with a master password and *without* one
   (stated plainly as obfuscation, not encryption) and the recommendation to
   set a master password.
4. **When the program uses the network** — an exhaustive list of triggers,
   for each: who is contacted, what they receive, and that the user starts it.
   Includes opening project web pages in the browser on a click.
5. **Components governed by others** — Windows, Microsoft Edge WebView2,
   shell extensions/cloud providers whose information the panels display,
   third-party plugins, external archivers the user configures.
6. **Optional components** — built but not shipped / disabled by default
   (e.g. the update checker), only if research shows a user can obtain or
   enable them; otherwise one sentence that they are not part of the shipped
   program.
7. **Installing and uninstalling** — what the installer writes, what the
   uninstaller removes and what it leaves (configuration, crash reports,
   viewer engine data).
8. **Removing your data** — step list covering every location in section 2.
9. **Older versions** — only data-handling differences (e.g. the crash
   reporting helper shipped until 0.1.7 whose upload was disabled).
10. **Contact** — public issue tracker for general questions; private
    vulnerability reporting for sensitive matters **only once it is enabled**
    (C7).
11. **Validity** — "This statement describes Tandem Commander <version>. Last
    updated <YYYY-MM-DD>."

## C3 — Wording

- Plain language for a non-technical reader; short paragraphs; no source-code
  paths, function names or registry value names beyond the top-level key and
  folder a user may need for removal.
- Absolute statements ("never", "no") only where the inventory shows the
  absence across the whole scope (main app + installer + all enabled
  plugins). Otherwise scope the sentence ("the program itself does not …").
- Identification strings the program sends are quoted exactly as the
  evidence shows them, including legacy ones (`OpenSalamander-mdview`).

## C4 — Must not claim

- Anything about what Microsoft, GitHub, the website host, a server the user
  connects to, or a third-party plugin does with data.
- Security properties beyond the evidence ("secure", "safe") — describe the
  mechanism (e.g. "encrypted with AES using your master password") instead.
- GDPR/legal-role language (controller/processor) — the project processes no
  personal data centrally; the statement says what happens, not legal
  classifications.

## C5 — Scope statement

The document states that it covers the application as distributed by the
project (installer and program, default plugin set) and not the website, the
GitHub repository, the winget catalogue, or third-party plugins.

## C6 — Unknowns

Behaviour the project cannot establish (a vendor component) is attributed
("is provided by Microsoft and governed by Microsoft's privacy statement"),
never characterised.

## C7 — Private channel gate

The private vulnerability reporting link
(`https://github.com/tandemcommander/tandemcommander/security/advisories/new`)
appears in the document only after the repository setting reports
`enabled: true`
(`GET /repos/tandemcommander/tandemcommander/private-vulnerability-reporting`).
Until then the Contact section offers the issue tracker only.

## C8 — Change triggers (mirrored in `CLAUDE.md`)

The statement is updated in the same change as any of: new or changed network
communication; a plugin enabled in the default build or disabled one shipped;
a change to what is stored, where, or how credentials are protected; a change
to crash reporting; a change to what the installer/uninstaller writes or
removes. The validity line (C2 §11) is updated with it.
