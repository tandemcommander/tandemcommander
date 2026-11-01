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

## Decisions

- Raw part (`pptStateVar`): decoded by the listing-field rule of the server (`FTPFieldToU8` with
  `FTPListingServer`, no state evidence - 288's rule for re-assigned columns stays).
- Column operand: appended as it is (decoded already).
- Literal (`pptString`): decoded alone without a server (valid UTF-8 kept, else code page - the
  result the whole-text decode gave for it) and not registered as a server name.
- The joined value is registered as a code-page name of the server when its raw part came from the
  code page or its head is a code-page name of the server (pure rule in `salftpsrvenc.h`, saltests).
- The joined value is assigned without a further decode (a new `AssignU8StringToColumn`).
