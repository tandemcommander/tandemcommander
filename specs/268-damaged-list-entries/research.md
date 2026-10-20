# Research - 268-damaged-list-entries

## R1 - What ends the list today

- Decision: the `else break;` after the required-value test, in all three loops.
- Rationale: measured (`fix-log.md`, probe before: every damaged row keeps only the entries before
  the damaged one). `GetValue` returns FALSE silently for a missing value and with the
  "Unexpected value type." box for a wrong type (`src/regwork.cpp`).
- Alternatives considered: none - the site is unambiguous.

## R2 - Skip, or end the list

- Decision: skip the damaged entry; continue with the next number.
- Rationale: the item's *Expected*; feature 250 chose the same for the highlighting list.
- Alternatives considered: keep ending the list (the defect).

## R3 - The low-memory paths

- Decision: keep the `break` (the list ends when an item cannot be created or added) and close the
  entry key before it.
- Rationale: the item's *Notes*; `IsGood()` of the three item classes fails only on an allocation
  failure, so continuing would only fail again.
- Alternatives considered: skip and continue (would change behaviour under memory pressure for no
  user gain).

## R4 - User Menu submenu balance

- Decision: no repair.
- Rationale: `FillUserMenu2` (`src/mainwnd1.cpp`) stops a level at an end item and bounds the walk by
  the item count; the User Menu toolbar (`src/toolbar5.cpp`) counts levels; the configuration page
  (`src/dialogs4.cpp`) handles `GetSubmenuEndIndex` = -1. A list cut at a damaged entry was already
  unbalanced the same way before the fix. A stray end at the top level hides the later items from
  the menu, but they are loaded and saved, and the configuration page shows them.
- Alternatives considered: drop a stray end / add a missing end (a new behaviour outside the item).

## R5 - Is the viewers `|` test a damage test?

- Decision: yes, an entry whose masks contain `|` is skipped like a damaged one.
- Rationale: the viewers configuration page refuses `|` (`src/dialogs5.cpp`, `forbiddenChar`), so the
  value comes only from outside; the loader already refused it.
- Alternatives considered: accepting it (a behaviour change outside the item).
