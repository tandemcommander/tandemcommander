# Closing report - 384-ftp-joined-column

Backlog item: ftp-listing-rule-joins-utf8-with-raw-bytes - FTP: a name a listing rule extends (z/VM, AS/400, VxWorks) mixes UTF-8 with raw server bytes
Outcome: closed

## What changed

- `src/plugins/ftp/parser2.cpp`: a thread-local record (`CFTPLineRawColumns`) of the listing bytes
  each name / text column of the line being parsed was assigned from. It is reset per line and per
  rule attempt. Listing reads record the bytes; re-assignments forget them. A `cut_white_spaces*`
  cuts the bytes too (review 2), and `assign(<col>, <col>)` copies them.
  `add_string_to_column` joins the head's listed bytes with the appended part's bytes and decodes
  the whole once, as a listing field (no state evidence, 288). When the head's bytes are unknown,
  it falls back to `FTPListingJoinFieldU8`. `AssignU8StringToColumn` is split out of
  `AssignStringToColumn`; the name limit of 215 is kept.
- `src/plugins/ftp/ftputils.cpp/.h`: `FTPListingJoinFieldU8` - the part-by-part fallback. It
  remembers the joined value as a code-page name of the server when a part came from the code page.
- `src/common/salftpsrvenc.h`: pure rules `SalFtpJoinBuild`, `SalFtpJoinPartHandling` and
  `SalFtpJoinedFieldIsCodePageName`; `src/saltests/saltests.cpp`: `TestFtpJoinedColumn384`
  (19 checks).
- The built-in users of the step: z/VM CMS 1/2/3 (name), VMS (rights) and MVS (unit). The item's
  "AS/400 / VxWorks" do not use it.
- Probe `probe/ftp384_probe.ps1` with `probe/ftpmini.py`: a copy of 215's server with LISTFMT
  `zvm` (z/VM CMS listing lines and a z/VM SYST reply).

## Measurements (before / after, commands)

`powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\384-ftp-joined-column\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\384-ftp-joined-column\probe\ftp384_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"`

- Before (main 7ba0dcb8): 6 PASS / 2 FAIL. On a cp1250 z/VM listing, `nameč.extč` was shown as
  `nameÄŤ.extč`; `DELE nameÄŤ.extč` and `RETR nameÄŤ.extč` reached no file.
- After the first version: 8 / 0.
- After review 1 and review 2: 16 / 0 (`result_after_review2.txt`). The server gets `DELE nameč.extč`
  and `RETR nameč.extč`. The mixed-server rows delete the joined names in the code page. REG-COINC
  deletes `zĂ©.extč` and leaves `zé.extč`.
- Negative controls: main fails MIX-HEADCP and MIX-BOTH (`review1_mix_neg.txt`); the first version
  of 384 fails REG-COINC (`review1_dup_after.txt`).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`.
- `.\build.cmd`: BUILD SUCCEEDED (only older C4267 warnings). No UI strings, so `build.cmd full`
  and the `.slt` refresh are not needed.
- saltests: `30496 checks, 0 failed`.
- Probes: 384 16 / 0; 288 20 / 0; 269 14 / 0; 224 16 / 0. The registry was restored identical
  after every run.

## Reviews (findings and what was done)

- Review 1: rejected.
  - MUST 1, fixed. A code-page head whose bytes happen to be valid UTF-8 stayed UTF-8 and became
    another file's name, so F8 deleted that file. Fixed by the byte provenance above; the
    reviewer's registry-based fix would fail on the same case.
  - SHOULD 1, partly done. The build decision is now pure and tested; the decode itself is proved
    by the probe.
  - SHOULD 2, done. Mixed-server rows added.
  - NOTE 1, done. The fallback no longer remembers the appended fragment as a server name.
- Review 2: accepted, no MUST.
  - SHOULD 1, fixed. A whitespace cut forgot the bytes; now it cuts them. This path is NOT DRIVEN
    in the GUI: it needs a user-defined server type.
  - NOTE 1 went to the Inbox. The other notes are recorded in `fix-log.md`.

## Owed to a person (with the new person-step items)

- Add the CHANGELOG entry below. `CHANGELOG.md` has no `## [Unreleased]` section, and versions are
  the maintainer's.
- No person-step item. No real z/VM server was tried; the test server lists in the z/VM CMS form,
  and neither reviewer found it unlike a real one.

## CHANGELOG entry (to be added by a person - `CHANGELOG.md` has no `## [Unreleased]` section)

- **An FTP file on an IBM z/VM server that lists names in the Windows code page was shown, deleted
  and downloaded under another name when both its name and its file type had letters outside
  ASCII** (feature 384).
  - **Before:** `nameč.extč` was shown as `nameÄŤ.extč`. Delete, download and rename asked the
    server for a file it did not have.
  - **Now:** the name is built from the bytes the server listed and read once, so it is shown and
    addressed as the server has it. This also covers a server that lists both UTF-8 and code-page
    names, and the other server types whose listing rules join parts of a line.
  - **Limitation:** checked against a test server that lists in the z/VM form, not a real z/VM
    system.

## New Inbox items (slug - title)

- `ftp-a-listing-rule-assigning-one-column-to-another-decodes` - FTP: a listing rule assigning one
  column to another decodes the decoded text again (review:384).
