# Closing report — 244 quick search substring filter

Branch `244-quick-search-substring-filter` (from `main` at `6fc5e5d1`), commits
`3cd56a11` (spec, plan, tasks), `26e35a68` (implementation), `911c6084`
(translations, help, changelog, probes), `7536fcc2` (review fixes) and the
closing commit. Nothing pushed.

## What changed for the user

- **Matching:** typing in a panel matches names that contain the text anywhere. A name that starts with it still gets the focus first.
- **Hiding:** while a search runs, the panel shows only the matches.
- **Commands:** they act only on what is shown; a selected item hidden by the search is never touched and stays selected.
- **Ending:** the search ends with Esc, an empty text, a change of folder, tab or active panel, or an operation that focuses a non-matching item.
- **Indication:** the searching panel is lightly tinted from its colour scheme, and its directory line shows `Search: <text> (<n> of <total>)`.
- **Option:** *Configuration › Panels › Quick search finds text anywhere in names and shows only the matches* is on by default; cleared, it gives the 0.1.10 quick search (a documented exception to Constitution II, spec *Constitution note*).

## Success criteria

| SC | Result | Evidence |
|----|--------|----------|
| SC-001 find by a word inside the name | Met: `chat` focuses `2024_chatbot` (0.1.10: `alpha`) | `probe/result_after.txt` C03 vs `result_before.txt` |
| SC-002 visible = exactly the matches | Met: C08, C12, C14, C15, C18, C20, C21 (ZIP) | `result_after.txt` |
| SC-003 per-keystroke time | Met except one worst case (below) | `probe/result_perf_release.txt` |
| SC-004 Esc restores items, order, selection, filter, sort, view | Met for items and selection (C09 COPY2, C11, C13); sort/filter/view are not touched by the code paths | `result_after.txt` |
| SC-005 prefix focus as in 0.1.10 | Met: C01, C02, C04 equal; 901 prefix cases equal in `saltests` | `saltests` |
| SC-006 colours recognisable, readable | Captured in 5 view modes × 4 schemes + Dark; **the judgement is owed to the maintainer** | `probe/captures_contact_sheet.png` |
| SC-007 no hidden item touched | Met for F5, F6 and select all (C09, C10); the archive/FS drag defect found by review is fixed but **not driven** | `result_after.txt` |
| SC-008 option off = 0.1.10 | Met: every row identical to the baseline | `probe/result_option_off.txt` |

**SC-003 per-keystroke times** (Release build, the maintainer's machine):

| | 10,000 items | 100,000 items |
|---|---|---|
| ASCII names | ≤ 7 ms | ≤ 24 ms |
| Czech names, typing | ≤ 9 ms | ≤ 32 ms |
| Czech names, first all-matching keystroke | 34–42 ms | 311–335 ms |

The worst case misses the 300 ms target by about 35 ms. That is the panel's
own layout of the list (measuring every visible name, the same as opening the
folder); filed to the backlog Inbox.

## Tests and probes

- `saltests`: 22,737 → 23,030 checks, 0 failed. They cover the matching rule (901 + 901 cases against the old matcher and a reference), keys, focus, tint, and a timing printout.
- `probe/qs244_probe.ps1`: 21 functional cases + 4 performance sets; old/new expectations; registry backed up and verified at every run (SHA-256 identical).
- `probe/qs244_capture.ps1`: idle/searching captures.
- `probe/qs244_cfgpage.ps1`: the Configuration page in 9 languages; the default is checked when the registry value is absent.
- `build.cmd full`: green, 189 language modules (translations imported).

## Reviews

- **Round 1** (three refute-first agents: data safety, option off and matching, painting and resources) found:
  - **High:** the drag from an archive or FS that would act on hidden selected items;
  - **Serious:** seconds per keystroke on non-ASCII names;
  - **Medium:** a Back-history entry added at every start;
  - several low-severity findings.
  
  All fixed except two cosmetic ones (fix-log).
- **Round 2** (one agent on the fix commit) found:
  - a latent overrun in key building;
  - a drop that kept searches it should end;
  - an uninitialised read of the dot tolerance after a wildcard;
  - two low-severity findings.
  
  All fixed and tested; the canonical-reordering gap is filed.

## Backlog (Inbox, for triage)

- `quick-search-first-keystroke-over-100-000-non-ascii-names`: improvement, measure:244.
- `quick-search-keys-skip-canonical-reordering-of-combining`: bug, leftover:244.
- `judge-the-quick-search-tint-on-a-real-screen-and-try-shift`: person step.
- `drag-from-a-zip-or-sftp-panel-during-a-quick-search-acts`: person step, review:244.
- A log line on `translations-clipped-labels`: the French Panels page.

## Not driven / owed to a person

- **Colour judgement (SC-006):** whether the tint is light but recognisable on a real screen, per scheme and in Dark (contact sheet attached).
- **Real keyboard keys:** Shift+arrows (selection among matches), Alt+letter with *Redirect typing to Command line*.
- **Drag and drop** from an archive or plug-in FS during a search: the dragged item is extracted, and a hidden selected item is not.
- **SFTP panel:** not driven; the ZIP archive was.

## Limitations

- **Highlighting:** where the match starts is not highlighted; the caret stands after its end.
- **Equality:** in the new mode, matching uses case and canonical equivalence only; the old comparison's linguistic extras (`ss` = `ß`) apply with the option off.
- **Translations:** the merge also re-fitted widths of other controls to the current English layouts (pipeline behaviour); on the Panels page, two existing French lines (not this feature's) stay clipped.
