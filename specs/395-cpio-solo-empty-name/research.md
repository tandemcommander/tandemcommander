# Research - 395-cpio-solo-empty-name

## R1 - Does tar get the rule?

- Decision: yes.
- Rationale: the item's Notes put tar in scope "if measured the same". Probe row
  `UNP-TAR-SOLO-DOT-DEL` (ustar regular `.` with `AAA`) at bb8aa693: `ok.txt` only, no window,
  archive deleted - the same loss.
- Alternatives: cpio only (leaves the same data loss in tar; rejected).

## R2 - Which text?

- Decision: `GetErrorText(ERROR_INVALID_NAME)` ("(123)") + two line breaks + the raw name in quotes.
- Rationale: the item proposes "(206)" or "(123)"; "(206)" says the name is too long, which is false
  for `.`. A system text needs no new resource string (no `.slt` refresh). Quotes make an empty
  raw name visible.
- Alternatives: reuse `ReportRefusedName` (wrong text; shares the once-flag of a different problem).

## R3 - What is "asked"?

- Decision: the operation's names (`CNames::IsNamePresent`) match the member's raw name - the rule
  of every member. Measured: the default mask `*.*` matches `.`, `./` and the empty name (all three
  rows dropped the data with the archive deleted, i.e. they were in the matched set as the 394
  negative control showed for `.`); `*.txt` does not match `.` (row `UNP-SOLO-DOT-MASK`).
- Rationale: an extraction never reports a member the user did not ask for; the member is never
  listed, so only a mask can ask for it.

## R4 - When does a group carrier's data "reach no extracted name"?

- Decision: pure rule `SalEmptyNameDataDecide(regular, hasData, asked, groupMember, cpioAction,
  groupState)`: not (regular && hasData && asked) -> silent; not a group member -> report now; a
  group member whose action is `WRITE_FOR_WAITING` or whose group is already `WRITTEN` -> silent;
  else pending. `SalEmptyNamePendingCleared(cpioAction)`: a later member of the group with action
  `WRITE`, `COPY` or `REPORT` clears the mark (its data written, or the loss reported by 394's
  "(2)" box - no second box). At the end of the archive a pending group is reported.
- Rationale: covers solo, orphan and data-first (with and without a later asked name) without a
  double report.
- Alternatives: report every passing carrier at once (double box in 394's data-first layout).

## R5 - Once per operation

- Decision: own flag `EmptyNameShown` (constructor-initialised like `RefusedNameShown`; a CArchive
  object serves one operation).
