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

## R4 - User Menu submenu balance (revised after the review)

- First decision (implemented first, rejected by the review): no repair - on the belief that a list
  cut at a damaged entry was unbalanced the same way. Wrong: a cut list can only lack an end; a
  skipped damaged *beginning* leaves a stray *end*. `FillUserMenu2` (`src/mainwnd1.cpp`) stops the top
  level at it (every later item is hidden from the menu), the User Menu toolbar (`src/toolbar5.cpp`)
  goes to level -1 (the later items are not on it), and the configuration page (`src/dialogs4.cpp`)
  cannot delete an end.
- Decision: a pure rule, `CSalUMSubmenuBalance` (`src/common/salumbalance.h`): a damaged beginning is
  skipped together with its matching end (the items inside move one level up - none is lost); a
  damaged end is loaded as a plain end, created as the configuration page creates one (an end's texts
  are never used); intact entries load as read, also the user's own stray end. The damaged entry's
  type is read quietly (`GetValueAux(..., quiet TRUE)`, precedent `CheckShutdownParams` in the same
  file) - no extra box for an entry that is damaged already.
- Alternatives considered: skip the whole submenu of a damaged beginning, as the settings import does
  for a too-long one (`SalCfgImpParseUserMenu`, `skipDepth`) - loses the items inside, against the
  item's *Expected*; skip a damaged end alone - the items after it would fall into the submenu.

## R5 - Is the viewers `|` test a damage test?

- Decision: yes, an entry whose masks contain `|` is skipped like a damaged one.
- Rationale: the viewers configuration page refuses `|` (`src/dialogs5.cpp`, `forbiddenChar`), so the
  value comes only from outside; the loader already refused it.
- Alternatives considered: accepting it (a behaviour change outside the item).
