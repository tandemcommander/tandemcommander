# Research - 375-idle-clipboard-check

## R1 Which query waits

- Decision: only `IsTextOnClipboard` waits (10 x `Sleep(10)` while `OpenClipboard` fails).
- Rationale: measured (fix-log, `probe/primitives_held.txt`): with the clipboard held open,
  `OpenClipboard` fails at once (error 5), `OleGetClipboard` fails at once (CLIPBRD_E_CANT_OPEN,
  0.6 ms), the loop costs 155-165 ms; `ClipboardPaste` / `ClipboardPasteLinks` /
  `ClipboardPasteToArcOrFS` have no retry. With the clipboard free all queries < 1.1 ms on both
  desktops.
- Alternatives: none needed.

## R2 How to avoid the wait

- Decision: a no-wait form of `IsTextOnClipboard` for the idle check (one attempt, reports busy),
  plus bounded later looks (500 ms, max 10) driven by a main-window timer.
- Rationale: the check is < 1.1 ms when the clipboard is free, so a thread is not needed; the
  later looks replace what the retry loop achieved (catching a short hold) without blocking.
- Alternatives considered:
  - Run the check on a worker thread: clipboard access needs a window/thread that owns it,
    OLE needs an STA; much larger change for a sub-millisecond query. Rejected.
  - Check only when a menu opens: the toolbars show the paste button state too, they would show
    stale state. Rejected.
  - Keep the previous enabler values while busy: changes today's result (FR-005); rejected.
  - Poll forever while busy: unbounded work for a program that keeps the clipboard for hours;
    rejected (clarification Q2).

## R3 What triggers a new series

- Decision: every setter of `IdleCheckClipboard` other than the retry timer starts a new series
  (the counter is reset when a check that was not a retry runs); opening a menu with a look
  pending looks at once (counts as a new trigger).
- Rationale: no setter needs to change (19 sites); the timer marks its own requests.
