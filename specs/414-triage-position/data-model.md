# Data model - 414-triage-position

No stored data changes. Values in the page:

- **Triage target**: one of `Next`, `Decisions for the maintainer`, `Person steps` (`TRIAGE_TARGETS`,
  in that order). Preselected: `admittingSection(item)`.
- **Default position** (per target): `positionBySeverity(item.severity, rowsOf(target))` - 1-based.
- **Typed position**: the field's text; read by `readTriagePosition(text, rowsOf(target).length)` into
  `{ position, last }` or `{ hint }`.
- **Edited flag**: whether the maintainer typed into the field; while false, the field follows the
  default (a section change or a new board refills it).

Transitions: section changed -> edited = false, field = default of the new section. Confirm with a
valid position -> one move request; on success the board reloads and the next Inbox item is shown
(the chooser remounts for it).
