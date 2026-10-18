# Closing report — 245 settings import from Altap Salamander / Open Salamander

Branch `245-settings-import-salamander` (from `main` at `869d9690`), commits
`0cd679d5` (spec, analysis, plan, tasks), `52d5d0ea` (engine, wizard, interface
108, FTP handler), `9391596f` (e2e matrix + fixes), `16ae2d93` (colours,
templates, saved searches), `e13ffd49` (UI probe, first-start fix), `18e0bd3c`
(documents, constitution 4.0.0, the 057 script retired), `8d103d54` (backlog),
`9aa00b98` (review round 1 + translations) and the closing commit (review
round 2). Nothing pushed.

## What changed for the user

- **Options › Import Settings from Salamander** opens a five-page wizard:
  source, what to import and how, saved passwords, preview, result.
- **First start:** a fresh configuration that finds Altap Salamander 2.5–4.0 or
  Open Salamander 5.0 settings offers the wizard once (*Import now* / *Not
  now*; Esc = not now). It never comes back.
- **Groups:** hot paths, user menu, FTP connections (bookmarks, proxy servers,
  server types, saved passwords), plugin command shortcuts, viewers and
  editors, saved searches and the ignore list, histories, confirmations, panel
  / keyboard / general / internal viewer options, colours and highlighting,
  view templates, default directories, settings of shipped plugins.
- **Safe by default:** the old settings are only read. The defaults only add.
  Everything that changes a current setting — *Replace*, option groups,
  viewers (they take files over from the `*.*` row), whole-plugin settings — is
  unticked and listed in the preview; *Import* needs an explicit consent tick.
- **Backup** of the settings (saved first) to
  `%APPDATA%\Tandem Commander\Settings backups\before-import-<stamp>.reg`;
  the result names it and how to restore it.
- **Passwords:** the old master password is verified; protected passwords are
  never stored with weaker protection without consent; Tandem Commander's own
  master password is asked before the preview.
- **Interface 108** (`SetPluginSettingsImport`) lets a plugin merge its own
  settings; FTP is the first.
- The standalone `utils/migrate-altap-settings.cmd` (057) is removed.

## Success criteria

| SC | Result | Evidence |
|----|--------|----------|
| SC-001 import in under 3 minutes without hand edits | Met in the probes (the whole wizard driven by control ids in seconds); a person's timing is owed | `probe/result_ui_final.txt` U1 |
| SC-002 old settings identical | Met in every e2e scenario (source export compared before/after) | `probe/result_e2e_final.txt` S1, S2, S12 |
| SC-003 plugins load, file types open as before | Met: plugin registration unchanged, TC-only associations kept, viewers only with consent | S1, S2, S1v |
| SC-004 nothing outside the selected groups changes | Met | S1 SC-010, S5 |
| SC-005 a second run adds nothing | Met | S3 |
| SC-007 every skipped item named | Met (reasons per line; too-long entries counted) | previews in the e2e output |
| SC-008 the backup restores | Met: `-C <backup>` restores the pre-import export exactly | S10 |
| SC-009 passwords never weaker | Met: scrambled, AES right/wrong/none, consent on/off, TC master password | S7 |
| SC-010 defaults change no current value | Met | S1 |

## Tests and probes

- `saltests`: 23,037 → 23,491 checks, 0 failed (`TestCfgImport245`: tree,
  rules, parsers, menu planning, UTF-8 text cutting, truncation, the
  option-table mirror against the forbidden list).
- e2e matrix `probe/ci245_e2e.ps1` (Debug automation seam, fixtures under
  `HKCU\Software\Tandem Commander Test 245`, product key exported, restored
  and compared): S0–S14, 94/94 (`probe/result_e2e_final.txt`).
- UI probe `probe/ci245_ui.ps1`: U1–U5 (pages, enabling rules, cancel on
  every page, first-start offer in Czech), 29/29 (`probe/result_ui_final.txt`); Release 5/5 (`probe/result_ui_release.txt`).
- `build.cmd full` and `build.cmd full release` green, 189 language modules;
  `tools/check_encoding.py` TOTAL 0.

## Reviews

- **Round 1** (three refute-first agents: plugin interface + FTP, engine,
  wizard + start-up): 34 confirmed and 20 plausible findings — among them the
  FTP Replace re-pointing the default proxy, a non-atomic FTP commit, a
  swallowed plugin crash, "Use Recycle Bin" without its masks, network access
  while planning, a failed plan still applied, viewer rows silently taking
  files from `*.*`. All fixed or answered (`fix-log.md`).
- **Round 2** (fixes; documents and privacy): the wizard captions rebranded in
  all translations (fixed), the backup missing unsaved session changes (now
  saved first), seven minor code and many document corrections (fixed).

## Owed to a person (NOT DRIVEN)

- A real Altap Salamander 4.0 configuration with AES (master-password)
  protected FTP passwords, imported and then used to log in.
- The colours of the wizard in the dark theme (`u3_dark_page*.png`).
- The translated wizard texts read by a speaker (machine translations, formal
  register; the Czech term for *hot paths* in the new texts should be compared
  with the rest of the Czech translation).

## Deviations

- Viewers are unticked by default (the plan had them ticked): rows inserted
  before the current `*.*` row change what opens files today.
- `Keep Plugins Sorted` was dropped from the options table; options with masks
  or a text are imported as units.
- Plugin shortcuts *Replace* = the imported key wins a conflict (FR-011 note).
- The translation tool gained `--formality` and a brand exemption list.
