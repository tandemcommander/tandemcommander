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

## Decisions

- Raw part (`pptStateVar`): decoded by the listing-field rule of the server (`FTPFieldToU8` with
  `FTPListingServer`, no state evidence - 288's rule for re-assigned columns stays).
- Column operand: appended as it is (decoded already).
- Literal (`pptString`): decoded alone without a server (valid UTF-8 kept, else code page - the
  result the whole-text decode gave for it) and not registered as a server name.
- The joined value is registered as a code-page name of the server when its raw part came from the
  code page or its head is a code-page name of the server (pure rule in `salftpsrvenc.h`, saltests).
- The joined value is assigned without a further decode (a new `AssignU8StringToColumn`).
