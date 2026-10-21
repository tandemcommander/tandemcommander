# Research - 277-ftp-pwd-path-cut

## R1 - Where the cut PWD path does harm

- Decision: the operation workers (explore of a folder for copy / move / delete, upload target
  PWD) are the reachable harm; the panel routes (login PWD, Change Directory) are limited by the
  core to ~260 bytes (233), so a 300-byte cut path is refused there by the core anyway.
- Rationale: measured - AIX row: the explore took the cut path, a reconnect sent `CWD <cut>`, the
  ancestor's x.txt was downloaded as lnk\x.txt.
- Alternatives: probing the panel route - masked by the core's limit.

## R2 - Refuse vs widen

- Decision: refuse (keep `FTP_MAX_PATH`).
- Rationale: the item's *Expected*; widening the plug-in's paths is a recorded limit (233), not
  this item.

## R3 - Pure rule

- Decision: `src/common/salftppwd.h` header-only, `saltests` checks.
- Rationale: stop-rules §2.5; the FTP plug-in already includes `salftplisting.h` the same way.
- The decode step stays in the plug-in (it registers code-page texts, feature 224).

## R4 - Created folder report

- Decision: heap buffers + `unknownResult` for a name that does not fit.
- Rationale: the item: invalidate, never record a cut component; whole components need no cut.
- Alternatives: recording whole components as created - a server may have cut a long name
  itself; invalidating is always safe (a re-list).

## R5 - The "fs4.cpp target name cut at a byte" note

- Decision: dropped. `targetName[3 * MAX_PATH]` with the "filled to the last byte" refusal (215);
  only the AS/400 member-name branch cut (fixed here).
