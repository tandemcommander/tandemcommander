# tandem-backlog-implement — stop rules and project rules

Read all of this before step 1 of `SKILL.md`. §1 decides every question a
run meets; §2 is how the work is done; §3 is when to stop.

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
| Public claims | `PRIVACY.md`, `README.md` promises, the website, winget metadata, the GitHub release text, a **policy** stated in `CHANGELOG.md` (an entry describing this feature's fix under `— unreleased` is the run's own job, SKILL.md step 8.5) |
| Network | any new or changed network communication of the product, also a new URL the program opens |
| Stored data | what is stored, where, how credentials are protected; registry layout (`HKCU\Software\Tandem Commander\0.1`) |
| Plug-in interface | `LAST_VERSION_OF_SALAMANDER`, `src/plugins/shared/spl_*.h`, any contract in `specs/NNN-*/contracts/` that plug-ins rely on |
| Installer | what the installer or uninstaller writes or removes, `AppId`, privileges, Restart Manager behaviour, `setup/tandemcommander.iss` beyond a bug fix the item names |
| Shipping | enabling, disabling, shipping or removing a plug-in (`plugins.cfg`) or a language (`translations/languages.cfg`) |
| Releases | a version number, a build number, a tag, a release, a winget submission |
| Translations | register / tone, pins in `translations/ui-overrides.json` beyond fixing a wrong text |
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
   failed`). New or removed UI strings need the two-stage `.slt` refresh,
   which a run does not do: stop (§3 reason 2).
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
12. **Nothing leaves the machine**: no push, no tag, no release, no winget,
    no GitHub post. (The git extension's branch hook runs `git fetch --all
    --prune`: it only reads from the remote and is allowed; nothing else
    talks to the remote.) While `microsoft/winget-pkgs#426090` is open,
    nothing under `tools/winget/templates/` changes; a run treats the PR as
    open as long as the backlog holds an item whose slug contains `426090`.

---

## §3 Stop conditions

Stop (SKILL.md step 10) — never silently, never by just ending — when:

| # | Condition | Record for the maintainer | Outcome |
|---|---|---|---|
| 1 | a maintainer-owned question (§1) | a `decision` item: *Question*, *Options* with consequences, *Recommendation* | `blocked` |
| 2 | the build, `saltests`, the encoding check or a probe still fail after **three** honest fix attempts (each attempt recorded in `fix-log.md`), or a required step cannot be done in a run (e.g. the `.slt` refresh) | in the item's block reason and `fix-log.md` | `blocked` |
| 3 | the independent review rejects the fix (MUST findings) **twice** | the review findings in `fix-log.md`; the reason names them | `blocked` |
| 4 | the change cannot be trusted without a person (real keyboard / clipboard / printer / server / other machine / admin) — when the change is sound and only a confirmation is owed, do **not** stop: finish and record a `person-step` item | a `person-step` item with exact *Steps* | `blocked` |
| 5 | the item is larger than one feature | one new item per part, each one feature's worth, `related` to the item | `split` |
| 6 | `git merge --ff-only` into `main` fails | the reason text of SKILL.md step 9, word for word (it carries the merge recipe) | `blocked` |
| 7 | the work would need to push, publish, or touch another item's work in progress | reason | `blocked` |
| 8 | Spec Kit did not create the feature (no branch, or no `specs/<BRANCH>` even after renaming the folder it made) | reason | `blocked` |
| 9 | `speckit-analyze` still reports CRITICAL after one fix round | the findings in `fix-log.md` | `blocked` |

A stop leaves: the work in progress committed on its branch
(`[<NNN>] stopped: <reason>`), the item `blocked` on `main` with the reason
and the feature number, the new items in *Inbox*, a journal row, the lock
released.
