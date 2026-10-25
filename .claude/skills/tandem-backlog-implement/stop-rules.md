# tandem-backlog-implement — stop rules and project rules

Read all of this before step 1 of `SKILL.md`. §1 decides every question a
run meets; §2 is how the work is done; §3 is when to stop.

**The goal of a run is a closed item.** An item the maintainer planned
clearly ends `closed`, with everything that belongs to it done: the code,
the translations, the manual, the changelog entry, the merge into `main`.
Work that a tool in the repository can do is the run's own work, never a
reason to stop and never a step handed to the maintainer. A run stops only
for what needs the maintainer's judgement (§1, the maintainer-owned list),
a person's hands (a real keyboard, a server, another machine — and then
only when the change cannot be trusted without them, §3 #4), or a check
that still fails after three honest attempts. "It is a lot of work",
"it spends DeepL characters" and "a person may want to look at it" are not
reasons to stop.

---

## §1 Questions: answer yourself, or stop

Every question a run meets — a Spec Kit `[NEEDS CLARIFICATION]`, a
`speckit-clarify` question, a design choice while implementing, a prompt of
any skill — goes through this test **in order**:

1. **Is it in the maintainer-owned list below?** → do not answer; stop
   (§3, reason 1) and record it as a `decision` item.
2. **Does the item (its *Expected*, *Approach*, *Notes*, *Log*) or a
   `CLAUDE.md` standing rule already answer it?** → use that answer.
3. **Is there a recommended option** (Spec Kit shows one) → take it.
4. **Otherwise** take the most conservative option: the one that changes
   least, loses no data, refuses rather than guesses, keeps compatibility
   (constitution principle II), and keeps the existing behaviour for every
   case the item does not name.

Record every answer of steps 2–4 in the spec: in *Clarifications* as
`- Q: <question> → A: <answer> (autonomous run: <item | rule | recommended | conservative>)`,
or in *Assumptions* as `Assumption (autonomous run): …`.

### Maintainer-owned (never answered by a run)

| Area | Examples |
|---|---|
| Public claims | `PRIVACY.md`, `README.md` promises, the website, winget metadata, the GitHub release text, a **policy** stated in `CHANGELOG.md` (an entry describing this feature's fix under `## [Unreleased]` is the run's own job, SKILL.md step 8.5) |
| Network | any new or changed network communication of the product, also a new URL the program opens |
| Stored data | what is stored, where, how credentials are protected; registry layout (`HKCU\Software\Tandem Commander\Settings`, version-free since 343) |
| Plug-in interface | `LAST_VERSION_OF_SALAMANDER`, `src/plugins/shared/spl_*.h`, any contract in `specs/NNN-*/contracts/` that plug-ins rely on |
| Installer | what the installer or uninstaller writes or removes, `AppId`, privileges, Restart Manager behaviour, `setup/tandemcommander.iss` beyond a bug fix the item names |
| Shipping | enabling, disabling, shipping or removing a plug-in (`plugins.cfg`) or a language (`translations/languages.cfg`) |
| Releases | a version number, a build number, a tag, a release, a winget submission |
| Translations | changing the register policy itself (the corpus is formal: *Sie*, *vous*, *u*, *usted*), a new glossary term that replaces an established one. Not maintainer-owned: the `.slt` refresh and pins that keep the formal register, keep an established term or correct a wrong machine text — the run's own job (§2.13) |
| Recorded decisions | anything the item's *Log* records as the maintainer's decision; anything that would reverse a `rejected` item or a "Decided" entry of a feature's spec |
| Real trade-offs | every option loses something for users ("cut the name or refuse it", "slower or riskier") and neither the item nor a standing rule chooses |

### Prompts of skills (not questions about the product)

| Prompt | Answer |
|---|---|
| *Optional Hook* `/speckit-git-commit` | accept: invoke the Skill `speckit-git-commit` with the event (e.g. `after_plan`) |
| "Some checklists are incomplete. Proceed?" | no — fix the artifacts until the checklist passes, then continue |
| "Commit?", "Continue?" inside a Spec Kit flow | yes, if the tree holds only this feature's changes |
| any request to push, tag, publish, open a PR | no |

---

## §2 How the work is done (project rules for a run)

`CLAUDE.md` is loaded in the session; these are the parts a run must not
miss.

1. **Measure first.** Reproduce on the build before changing anything;
   confirm the defect is reachable from a user action; record the command
   and the result in `fix-log.md`. A negative control that does not fail is
   a finding (record it, re-think the test).
2. **The fix protocol** (`specs/069-finish-encoding-fixes/contracts/fix-protocol.md`,
   formerly `NEXT-WORK.md` *Protocol*): check that the site is still
   defective at HEAD first; **enumerate the consumers yourself** (Grep every
   caller) before writing anything.
3. **Read before changing**: the `specs/FEATURE-HISTORY.md` entries of the
   area (its *Index by area*) and the standing rules of `CLAUDE.md` that the
   area touches (UTF-8 / WTF-8 names, never cut a path, same-file identity,
   safe replace, plug-in ABI append-only, WebView2 binding contract).
4. **Running log**: `specs/<NNN>-*/fix-log.md` from the first measurement
   to the closing — decisions, measurements before / after, commands,
   results, review findings, what is owed to a person.
5. **Pure decisions** (a rule that can be tested without the GUI) go into a
   header under `src/common/` with `saltests` checks.
6. **Checks that must pass** before closing — the exact commands and
   expected outputs are the table of SKILL.md step 6 (encoding guard
   `TOTAL: 0 finding(s)`, `BUILD SUCCEEDED`, `saltests: <n> checks, 0
   failed`). New, changed or removed UI strings or dialogs need the
   two-stage `.slt` refresh: the run does it itself (§2.13).
7. **GUI probes** run only on the hidden desktop, never on the maintainer's
   desktop, with the **PowerShell tool** (never Bash — it drops the
   backslashes of these paths):

   ```text
   powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\<BRANCH>\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\<BRANCH>\probe\<name>.ps1 -Exe <build>\tandemcommander\Debug_x64\tandemcommander.exe"
   ```

   `<build>` is `$env:OPENSAL_BUILD_DIR` when it is set, otherwise `build`.
   `<label>` says what was run (`before`, `after`, a row name). Probes are
   written in the style of `specs/241-pack-long-nested-folder/probe/pack241_probe.ps1`.

   A probe shares the product's registry key: back it up and restore it
   (the helpers `Backup-Reg` / `Restore-Reg` of
   `specs/098-long-path-overruns/probe/fix_probe_lib.ps1`, as
   `specs/241-pack-long-nested-folder/probe/pack241_probe.ps1` does) and
   verify the restore. Never write the real wallpaper. Fixture folders live
   under `%TEMP%`; every path a probe types must start with the fixture
   root.
8. **Never stop a running probe** (no TaskStop). After an interrupted
   probe, restore the registry from its backup (`%TEMP%\tcNNN_backup.reg`)
   before anything else.
9. **No real keyboard, mouse, clipboard or printer** on the hidden desktop:
   such rows are recorded as NOT DRIVEN in `fix-log.md` and become a
   `person-step` item at closing.
10. **Data safety** (`CLAUDE.md` *Never lose the user's data*): a
    "safe to delete?" check fails closed; same-file decisions by identity;
    replacing a user's file through a temporary file + `SalReplaceWithTempW`.
11. **Scope**: only what the item describes. Other defects found on the way
    become *Inbox* items (`measure:<NNN>`), never part of this feature.
12. **Nothing leaves the machine** (except the English UI texts the
    translation merge sends to DeepL, §2.13): no push, no tag, no release, no winget,
    no GitHub post. (The git extension's branch hook runs `git fetch --all
    --prune`: it only reads from the remote and is allowed; nothing else
    talks to the remote.) While `microsoft/winget-pkgs#426090` is open,
    nothing under `tools/winget/templates/` changes; a run treats the PR as
    open as long as the backlog holds an item whose slug contains `426090`.
13. **Translations are the run's job.** Whenever the feature adds, changes
    or removes a UI string, a menu text or a dialog (control, size,
    caption) of a module — the core is the module `salamand`, a plug-in
    the name of its folder under `src/plugins/` — the run refreshes that
    module's `.slt` files for every enabled language before the checks of
    SKILL.md step 6 close. Each block below is **one** PowerShell call from
    the repository root (the PowerShell tool keeps no variables between
    calls).

    0. **List the entries** the feature touched, from
       `git diff $(git merge-base main HEAD) -- <the module's .rc / .rc2 / .rh files>`
       (never `git diff main`: once `main` moved on it shows `main`'s
       changes reversed): *new* ids (strings, menu items, dialog controls,
       a new dialog) and *changed* ids (the English text of an existing id
       changed, a review's rewording included).
    1. Build and export — two PowerShell calls, the build with a timeout of
       at least 600000 ms:

       ```text
       .\build.cmd                                                     → BUILD SUCCEEDED (builds the English module)
       src\vcxproj\build_langs.cmd --export-templates --module <mod>   → the module exported to <templates>\<mod>.slt
       ```

       `<templates>` = `$env:OPENSAL_BUILD_DIR` + `tandemcommander\translator\templates`
       when that variable is set, else `build\tandemcommander\translator\templates`
       under the repository root.
    2. **Changed English keeps its old translation** (`match.py` matches by
       id; feature 245): for every *changed* entry set its key to
       `"english_fallback"` in each enabled language's
       `translations/<language>/<module>.origin`, with the editor or a
       short script written to a file (never a here-document). **Take the
       key from the exported template** `<templates>\<mod>.slt`:
       `<KIND>:<n>:<row>`, where `[<KIND> <n>]` is the section header that
       holds the row (`DIALOG`, `MENU`, `STRINGTABLE` — for a string table
       `n` is the section's ordinal in the file, **not** `id/16+1`) and
       `<row>` is the row's first number; a dialog caption is
       `DIALOG:<n>:#caption`. Check that each key exists in the `.origin`
       before changing it — a wrong key does nothing and gives no error.
       Menu popups all have id 0 and share one key (`MENU:<n>:0`): a
       changed popup text cannot be targeted this way — pin it instead
       (step 5, key `#<English>`).
    3. Dry run — one PowerShell call:

       ```text
       $tpl = if ($env:OPENSAL_BUILD_DIR) { Join-Path $env:OPENSAL_BUILD_DIR 'tandemcommander\translator\templates' } else { Join-Path (Get-Location).Path 'build\tandemcommander\translator\templates' }; Push-Location tools; python -m translate.merge --module <mod> --templates $tpl --formality prefer_more --dry-run; Pop-Location
       ```

       It prints per language `N unique gaps, ~C chars`. N counts unique
       (context, English) pairs and skips texts that need no translation
       (`""`, `OK`, `%s`, …), so N may be **lower** than the entries of
       step 0, never higher than them plus the module's leftover
       `english_fallback` rows (`grep -c english_fallback` in the
       `.origin` before the change — e.g. `spanish/pictview`; they are
       translated too and listed in `fix-log.md`):
       - **0 gaps although texts were added** = the templates-path trap
         (feature 079: the merge writes nothing, no error) — fix the path;
       - **more gaps than that** — do not run the real merge: look for
         renumbered string bundles (rule 084; feature 079 re-sent 46 gaps a
         language and overwrote human texts) or a stale template; fix the
         cause, dry-run again.
    4. The real merge, with `--budget` = twice the sum of the dry run's
       `~C` over the languages plus 2000 (the count includes protection
       tags):

       ```text
       $tpl = if ($env:OPENSAL_BUILD_DIR) { Join-Path $env:OPENSAL_BUILD_DIR 'tandemcommander\translator\templates' } else { Join-Path (Get-Location).Path 'build\tandemcommander\translator\templates' }; Push-Location tools; python -m translate.merge --module <mod> --templates $tpl --formality prefer_more --budget <2 x estimate>; Pop-Location
       ```

       It prints `DeepL characters sent this run: …` and, when some failed,
       `validation failures (kept English):` with the entries — pin those
       (step 5). `--formality prefer_more` is required: the default is the
       informal register, the corpus is formal (feature 245). A line
       `budget cap reached …; stopping before <language>` means the merge
       stopped with exit 0 and **left the rest of the languages
       unwritten**: find why the estimate was wrong (step 3), then run
       again — never continue with languages missing.
    5. **Read every new and changed text back** in all enabled languages
       (the entries of step 0 in `git diff -- translations`), as feature
       078 did (fix-log T044). Pin in `translations/ui-overrides.json`
       every text that: still uses the informal register in de / fr / nl / es (*du*,
       *tu*, *je* / *jij*, *tú*); names a thing otherwise than the module's
       existing texts do (look up the same English word in the committed
       `.slt`); writes key names otherwise than the module's existing
       texts (e.g. `Strg+Umschalt+T` where the menus say `Ctrl+Shift+T`);
       changes the number or order of `%s` / `%d`; gives an accelerator
       `&` that `merge` reports as a duplicate; or failed validation. A pin
       goes under the module and the language folder; its key is the
       resource symbol, or `#<the English text>` (it matches every row
       with that English text in the module) for a dialog caption, a menu
       popup, or a symbol whose id appears in more than one dialog of the
       module (a symbol pin rewrites every row with that id — in
       `salamand` 80 control ids are shared); add a
       `"_feature_<NNN>": ["why …"]` note list in the module; after
       pinning check in `git diff` that only the intended rows changed. A
       brand name the rebrand step must not touch goes into
       `translations/brand-exempt.json` (feature 245). Then the real merge
       again (pins are applied as `human`; rows that failed validation are
       sent to DeepL once more).
    6. `Push-Location tools; python -m translate.slt --verify; Pop-Location` → `round-trip byte-exact` for every file.
    7. `.\build.cmd full` (timeout at least 600000 ms) → `BUILD SUCCEEDED` (the language modules import).
    8. `fix-log.md`, section *Translations*: the entries of step 0, the
       commands, the gaps per language, the characters, the validation
       failures, every pin and why, the number of re-laid-out controls.

    **Layout drift.** The merge also refits the geometry of unrelated
    dialog controls to the current English layout. Features 155 and 173
    kept only their own entries (with a session script); 244 committed the
    drift as the pipeline's normal output. **This rule overrides 155 and
    173**: the drift is committed with the feature (no repository tool
    separates it; `build.cmd full` imports it), and `fix-log.md` names the
    count per language. The read-back of step 5 is limited to the entries
    of step 0.

    **The one exception to §2.12**: the merge sends the module's English UI
    texts (nothing else) to DeepL — that is how the project translates.

    The committed `.slt`, `.origin`, `ui-overrides.json` and
    `brand-exempt.json` files belong to the feature's commit. Only DeepL
    itself failing (no key, quota exhausted, no network) after three
    attempts is a stop (§3 #2, reason `DeepL unavailable: <message>`).
    **A note in an item that a run stops for the `.slt` refresh is
    outdated: this rule overrides it** (§1 step 2 does not apply to it).
14. **A part of *Expected* the run cannot reach** inside the item's limits
    (a probe that cannot drive it, an API the binding contract forbids, a
    manual page that does not exist): when the item's main point is done,
    do **not** stop — take the conservative way (§1 step 4), record it in
    the spec (*Assumptions*) and in `fix-log.md` as a deviation with the
    measurement, add an Inbox item for the missing part (`leftover:<NNN>`),
    name it in the closing report and close. Stop only when the missing
    part is the item's main point, or the only way to reach it is
    maintainer-owned (§1).

---

## §3 Stop conditions

**Before any stop except #1, #5, #6 and #7** (a conflict outside SKILL.md
step 9's table is never resolved to avoid a stop), try to remove its cause: an
honest fix attempt is a *different* approach each time (another site,
another design inside the item's limits, another test method — not the
same change repeated), recorded in `fix-log.md`. A stop whose cause a
repository tool, a different approach or the conservative answer of §1
step 4 could remove is not a stop. A safety rule (`CLAUDE.md` *Never lose
the user's data*, §2.10, the plug-in ABI, nothing leaves the machine) is
never bent to avoid a stop.

Stop (SKILL.md step 10) — never silently, never by just ending — when:

| # | Condition | Record for the maintainer | Outcome |
|---|---|---|---|
| 1 | a maintainer-owned question (§1) | a `decision` item: *Question*, *Options* with consequences, *Recommendation* | `blocked` |
| 2 | the build, `saltests`, the encoding check or a probe still fail after **three** honest fix attempts (each attempt recorded in `fix-log.md`), or a tool a required step depends on is unavailable after three attempts (DeepL down, quota exhausted). A step a repository tool can do — the `.slt` refresh, the manual, the changelog, a merge — is never this reason: do it (§2.13) | in the item's block reason and `fix-log.md` | `blocked` |
| 3 | the independent review rejects the fix (MUST findings) **three times**, or twice with a MUST finding the second review repeats unchanged from the first (no progress) | the review findings in `fix-log.md`; the reason names them | `blocked` |
| 4 | the change cannot be trusted without a person (real keyboard / clipboard / printer / server / other machine / admin) — when the change is sound and only a confirmation is owed, do **not** stop: finish and record a `person-step` item | a `person-step` item with exact *Steps* | `blocked` |
| 5 | the item is larger than one feature | one new item per part, each one feature's worth, `related` to the item | `split` |
| 6 | `main` cannot take the branch: the item changed on `main` during the run (SKILL.md step 9's guard), SKILL.md step 9 found a conflict outside its table, or the checks after merging `main` into the branch still fail after three attempts. (A `main` that only moved on is not this reason — step 9 merges it.) | the reason text of SKILL.md step 9, word for word (it carries the merge recipe) | `blocked` |
| 7 | the work would need to push, publish, or touch another item's work in progress | reason | `blocked` |
| 8 | Spec Kit did not create the feature (no branch, or no `specs/<BRANCH>` even after renaming the folder it made) | reason | `blocked` |
| 9 | `speckit-analyze` still reports CRITICAL after one fix round | the findings in `fix-log.md` | `blocked` |

A stop leaves: the work in progress committed on its branch
(`[<NNN>] stopped: <reason>`), the item `blocked` on `main` with the reason
and the feature number, the new items in *Inbox*, a journal row, the lock
released.
