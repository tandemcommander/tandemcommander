# Fix log - 384-ftp-joined-column

Backlog item `ftp-listing-rule-joins-utf8-with-raw-bytes`: FTP: a name a listing rule extends
(z/VM, AS/400, VxWorks) mixes UTF-8 with raw server bytes.

## Measurement before (main at 7ba0dcb8)

Site, by reading: `src/plugins/ftp/parser2.cpp` `CFTPParserFunction::UseFunction`, case
`fpfAdd_string_to_column`: `GetStringOperand` of the column (decoded UTF-8: `file->Name` or
`GetStringFromColumn`) and of the second operand - `pptStateVar` (`next_word` / `next_char` /
`rest_of_line`: raw listing bytes), `pptColumnID` (another column, decoded) or `pptString` (the
rule's literal) - are memcpy'd into one buffer and decoded again by
`AssignStringToColumn(.., FALSE)` -> `FTPListingFieldToU8` -> `FTPFieldToU8`.

Built-in users of the step at HEAD (`ftp3.cpp`): z/VM CMS 1/2/3 (`<name>` + `"."` + `next_word`),
VMS 1-4 (`<rights>` + `rest_of_line`), MVS 1/2 (`<unit>` + `" "` + `<name>`). The item's
"AS/400 / VxWorks" do not use it (their rules use `cut_end_of_string` / other steps).

Reachable: connect to a server whose listing autodetection resolves to a z/VM rule (no condition for
CMS 1/2; `syst_contains("z/VM")` for CMS 3; the UNIX rules are excluded by `not syst_contains("z/VM ")`).

Probe: `probe/ftp384_probe.ps1` + `probe/ftpmini.py` (a copy of 215's server with a 7th argument
LISTFMT `zvm`: LIST lines `NAME TYPE V 80 <n> 1 <yyyy-mm-dd> <hh:mm:ss> OWNER` and SYST
`215 z/VM Version 7 Release 3.0, ...`). First attempt kept SYST `UNIX Type: L8`: a UNIX rule took the
listing (name " 1 2026-11-01 ... OWNER") - the z/VM SYST reply was added, as a real z/VM server
answers.

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\384-ftp-joined-column\probe\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\384-ftp-joined-column\probe\ftp384_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
```

Result (`probe/result_before.txt`, ACP 1250): PASS 6, FAIL 2.
- ZVM-CP-DEL FAIL: confirm shows `nameÄŤ.extč`; server got `DELE nameÄŤ.extč`; the file stays.
- ZVM-CP-DL FAIL: `RETR nameÄŤ.extč`; nothing downloaded.
- ZVM-CP-ASCII PASS (`name.extč`: the joined text is decoded whole in cp1250 - right).
- ZVM-UTF-DEL PASS (UTF-8 server).
- Registry restored, identical.

## Analyze (speckit-analyze)

No CRITICAL / HIGH. U1 (MEDIUM, name limit not named in T005) fixed in tasks.md. Accepted:
C1 (MEDIUM) - no probe row for a "mixed" server (ftpmini lists one encoding per server; a folder
with both would need surrogate-escaped names on disk): FR-005 is covered by the saltests rule and
the review; C2 (LOW) - the probe drives delete and download, not view / rename (same listed name).

## Implementation

- `src/common/salftpsrvenc.h`: `SALFTPJOIN_RAW / COLUMN / LITERAL`, `SalFtpJoinPartHandling`
  (raw -> decode as the server's listing field, literal -> decode alone, column / unknown -> as is),
  `SalFtpJoinedFieldIsCodePageName`.
- `src/plugins/ftp/ftputils.cpp/.h`: `FTPListingJoinFieldU8` - decodes the part by its kind
  (`FTPFieldToU8(.., FTPListingServer, 0)` / `(.., NULL, 0)` / copy), joins, and registers the
  joined value as a code-page name of the server when the raw part was not
  `SalFtpListingFieldIsU8` or the non-ASCII head is a code-page name (`FTPIsServerNameN`).
- `src/plugins/ftp/parser2.cpp`: `AssignU8StringToColumn` split out of `AssignStringToColumn`
  (name limit of 215, invalid type / index handling kept; frees the string when not taken);
  `fpfAdd_string_to_column` takes the kind from `Parameters[1]->Type` and assigns the joined UTF-8
  without a further decode.
- `src/saltests/saltests.cpp`: `TestFtpJoinedColumn384` (10 checks).
- Trap: clang-format on the whole `saltests.cpp` / `ftputils.cpp` / `ftputils.h` reformats hundreds
  of unrelated lines (the files are not format-clean at HEAD); a `-U0` hunk filter applied to the
  reformatted file put the saltests hunks at the reformatted file's line numbers (wrong place) -
  the saltests block was re-added by hand; only the feature's own lines are formatted.

## Checks after

| Check | Result |
|---|---|
| `.\build.cmd` | BUILD SUCCEEDED (only older C4267 warnings) |
| saltests | `saltests: 30487 checks, 0 failed` |
| `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)` |
| probe 384 (`probe/result_after.txt`) | PASS 8, FAIL 0 (before 6 / 2): `DELE nameč.extč` deletes it, `RETR nameč.extč` downloads it; controls PASS; registry identical |
| negative control | the same probe on main's build (7ba0dcb8): ZVM-CP-DEL, ZVM-CP-DL FAIL (`result_before.txt`) |
| probe 288 (`probe/regress_288.txt`) | 20 / 0 |
| probe 269 (`probe/regress_269.txt`) | 14 / 0 |
| probe 224 (`probe/regress_224.txt`) | 16 / 0 |

No UI strings, dialogs or menus changed: no `.slt` refresh needed; `build.cmd full` not required.

## Review

### Review 1 (refute-first agent, 2026-11-01) - rejected: 1 MUST, 2 SHOULD, 3 NOTE

- **MUST 1** (fixed): the first version never decoded the column's value again and decoded only
  the appended part. A code-page head whose bytes happen to be valid UTF-8 (cp1250 `zĂ©` = 7A C3 A9
  = UTF-8 `zé`) stayed UTF-8, so `zĂ©.extč` was shown as `zé.extč`, the name of another file
  (7A E9 ...). F8 deleted that other file; main had deleted the right one (`probe/review1_dup_*.txt`).
  The reviewer's suggested fix (rebuild the head's bytes from the server's code-page name set) fails
  on that very case: the other file registers `zé` as a code-page name, so both heads would be
  rebuilt as 7A E9. **Fix**: true provenance. `parser2.cpp` keeps, thread-locally for the line being
  parsed, the listing bytes each name / text column was assigned from (`CFTPLineRawColumns`).
  `AssignStringToColumn` records them for listing bytes (evidence) and forgets them for re-assigned
  values. `assign(<col>, <other column>)` copies the source's bytes. They are reset with `emptyCol`
  at each line and rule attempt. `add_string_to_column` joins the head's bytes with the part's
  bytes and decodes once (`AssignStringToColumn(.., FALSE)`, then records the joined bytes for the
  next append). That is exactly main's decode, except that the head is the listed bytes instead of
  its UTF-8 - so it is right in every case main was right, plus the defect case. Only when the
  bytes are not known (the column was cut first; no built-in rule does that) the part-by-part
  `FTPListingJoinFieldU8` is the fallback. Pure decision `SalFtpJoinBuild` + 9 saltests checks.
- **SHOULD 1** (partly): the unit checks test only the switch. Now the build decision
  (`SalFtpJoinBuild`) is pure and tested. The decode itself stays in the plug-in (`FTPFieldToU8`,
  CP_ACP) and is proved by the probe rows, including the M1 row. Moving the decode into a header
  would duplicate 224's decoder; not done.
- **SHOULD 2** (done): the reviewer showed that a "mixed" server can be built with ftpmini (a cp1250
  name whose bytes are valid UTF-8). Rows MIX-HEADCP, MIX-BOTH and MIX-TAILCP are now in the probe;
  main failed MIX-HEADCP (`probe/review1_mix_neg.txt`). The analyze note C1 is superseded.
- **NOTE 1** (done): the fallback decodes the appended part without a server (`NULL`), so a
  fragment such as `extč` is not remembered as a name of the server; the joined value is.
- **NOTE 2** (accepted): a head that was cut before the join is not recognised (288's limit); with
  the new design the cut column's bytes are unknown and the fallback applies.
- **NOTE 3**: checked and fine (operand kinds, literal decode, ownership, name limit, built-in users).

After the fix: build OK; saltests 30,496 / 0; probe `probe/result_after_review1.txt` 16 / 0.
REG-COINC needed Home + 2 Down instead of End: with the names right, `zĂ©` (A-breve) sorts before
`zé`, and End had focused the other file. The negative controls of the new rows are the reviewer's
runs on main and on the first version (`probe/review1_*_neg.txt` / `review1_dup_after.txt`).

### Review 2 (refute-first agent, 2026-11-01) - accepted: no MUST, 1 SHOULD, 6 NOTE

The reviewer re-ran the probe (16 / 0, registry identical), saltests (30,496 / 0) and the encoding
guard. They traced every write route of a name / text column: listing reads record bytes,
re-assignments forget them, `assign(<col>, <col>)` copies them, and there is a reset per line, per
rule attempt and per skipped line.

- **SHOULD 1** (fixed): a `cut_white_spaces*` step that really cut something forgot the column's
  bytes, so a later join fell back to the part-by-part path and brought back MUST 1 for a custom
  rule that cuts a fixed-width name before joining (reviewer's simulation: `zĂ©.extč` -> `zé.extč`,
  F8 deletes the other file). No built-in rule cuts a name before a join (MVS cuts `<unit>`, display
  text). **Fix**: the cut is applied to the recorded bytes too. A byte <= 0x20 is never part of a
  multi-byte letter (UTF-8, ANSI and DBCS code pages), and `char` is unsigned (`/J` in
  `plugin_base.props` - checked, the comparison `<= ' '` does not take bytes >= 0x80). So cutting
  the bytes and decoding equals decoding and cutting. The fallback remains only for
  `cut_end_of_string` before a join (no built-in rule). NOT DRIVEN in the GUI: it needs a
  user-defined server type (the probe would have to write one into the configuration); the MVS
  rule (`cut_white_spaces(<unit>)`, then `add_string_to_column(<unit>, " ")` and
  `(<unit>, <name>)`) now takes the bytes path with ASCII text - same result as before.
- **NOTE 1** (Inbox): `assign(<name>, <column>)` still decodes the decoded text with name
  evidence - older, out of scope -> `ftp-a-listing-rule-assigning-one-column-to-another-decodes`.
- **NOTE 2**: the unit checks test pure rules only (as SHOULD 1 of review 1); the probe is the proof.
- **NOTE 3**: review 1's REG-COINC-ASCII row (`zĂ©.EXT`) not carried over - the bytes path treats it
  exactly as main did; optional, not added.
- **NOTE 4**: a non-ASCII UTF-8 literal joined to a code-page head is decoded in the code page as
  a whole (as main did; built-in literals are ASCII). FR-004 describes the fallback.
- **NOTE 5**: `thread_local` with a destructor - a plug-in unload leaks a few small buffers of
  other threads; harmless.
- **NOTE 6**: 288's limit unchanged (a z/VM head alone may count as UTF-8 evidence).

## Decisions

- Raw part (`pptStateVar`): decoded by the listing-field rule of the server (`FTPFieldToU8` with
  `FTPListingServer`, no state evidence - 288's rule for re-assigned columns stays).
- Column operand: appended as it is (decoded already).
- Literal (`pptString`): decoded alone without a server (valid UTF-8 kept, else code page - the
  result the whole-text decode gave for it) and not registered as a server name.
- The joined value is registered as a code-page name of the server when its raw part came from the
  code page or its head is a code-page name of the server (pure rule in `salftpsrvenc.h`, saltests).
- The joined value is assigned without a further decode (a new `AssignU8StringToColumn`).
