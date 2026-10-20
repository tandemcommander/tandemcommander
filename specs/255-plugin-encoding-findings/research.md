# Research: 255 - verdicts for the plug-in encoding findings

## R1 - How a false positive is recorded

- **Decision**: the guard's own marker `// encoding-check: allow <rule-id> - <reason>` on the
  reported line or the line above (`suppressed()` in `tools/check_encoding.py` looks at both).
- **Rationale**: the documented mechanism, used by the core (e.g. the two annotated fail-safes of
  `lossy-lenient-at-intake`); the reason sits next to the code a later change would touch.
- **Alternatives**: a baseline file of known findings in the tool - rejected: drifts with line
  numbers, hides the reason from the code reader, and changes the tool feature 239 defined.

## R2 - Criteria per rule (what makes a site harmless)

| Rule | Real when | Harmless when |
|---|---|---|
| `utf8-to-legacy-sink` | a UTF-8 text with non-ASCII letters reaches an ANSI window call (`SetWindowTextA`, `SetDlgItemTextA`, `ListView_SetItemTextA`, `CB_ADDSTRING`) | the text is ASCII by construction, or code-page text by construction (e.g. a stand-alone program that holds no UTF-8), or the window is wide and the call is W |
| `mixed-composition` | an ANSI `LoadStr` template composed with a UTF-8 name and drawn by a UTF-8 sink (localized builds show mojibake) | the template is UTF-8 (`LoadStr` of a plug-in that loads UTF-8), or the sink is a code-page sink fed only code-page text |
| `ansi-template-number` | grouped number (UTF-8 separator) composed with an ANSI template, drawn as UTF-8 | the number formatter used is ASCII-only, or the template is UTF-8 |
| `dead-dispinfow` | the W handler is the only path that fills the list | the list view is made Unicode some other way (`LVM_SETUNICODEFORMAT`, `CreateWindowExW`, NF_REQUERY elsewhere), or the A handler does the work |
| `strict-probe-rejects-wtf8` | the bytes can be a core WTF-8 name and failure takes a code-page path (spec Clarifications) | bytes from an archive, a protocol, a file's contents; or failure is only a refusal |
| `lossy-lenient-at-intake` | input can hold a lone surrogate and the result is used as a name (open / find / compare / hand back) | input is valid Unicode by construction (resources, generated text, OLE strings of a known form) or the result is only shown |

A plug-in's `LoadStr` must be read per plug-in: several plug-ins load their language module
strings as UTF-8 (feature 052 and later); a `mixed-composition` verdict depends on which.

## R3 - Grouping of real defects into items

- **Decision**: one backlog item per plug-in and defect class (e.g. "ZIP self-extractor shows its
  texts through the code page"), source `measure:255`, type `bug`, severity by the anchors (mojibake
  in a shipped plug-in 4; lost identity of a file name 3 or higher; a plug-in that is not shipped
  one lower), `who: agent`.
- **Rationale**: the item's *Approach* - "split real defects per plug-in into features"; a fix of
  one plug-in's class is one feature's worth.

## R4 - The follow-up "make the scan strict"

- **Decision**: one item (`tech-debt`), `depends-on` the real-defect items: run
  `check_encoding.py --plugins` in the build (for the shipped plug-ins) once it reports 0.
- **Rationale**: spec FR-007; feature 239's FR-001 keeps the option report-only until then.
