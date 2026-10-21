# Closing report - 275-arcmember-long-path
Backlog item: f3-f4-refuse-archive-members-whose-path-inside-the-archive - F3 / F4 refuse archive members whose path inside the archive has 520 bytes or more
Outcome: closed

## What changed

- `src/fileswn5.cpp` `CFilesWindow::ViewFile` (F3) and `src/fileswn6.cpp`
  `CFilesWindow::ExecuteFromArchive` (F4 / Enter): feature 095's `>= 2 * MAX_PATH` test of the path
  inside the archive removed. The listing bounds that path (a folder part of at most 255 bytes + a
  name of at most 255 UTF-16 units); the disk cache's rule for the temporary copy (feature 260) is
  the only length refusal left before extraction.
- `src/salamdr3.cpp` `CFileTimeStamps::AddFilesToListBox`: the Archive Update list line is built on
  the heap (review 1 MUST - `char buf[3 * MAX_PATH]` showed only the folder for paths of 780+ bytes,
  newly reachable through this feature).
- `src/plugins/uncab/uncab.cpp` `UnpackOneFile`: a path inside the cabinet that does not fit
  `U8_MAX_CAB_NAME` is refused with the plug-in's `IDS_TOOLONGNAME` instead of being cut by
  `lstrcpyn` (unreachable with a real cabinet).
- Feature 260's probe row ARCCAP now expects the viewer; 260's contract points to
  `contracts/arc-member-path.md`. CHANGELOG: a 275 entry under 0.1.11 (unreleased); the 260 entry
  no longer states the 520-byte limit.
- No new UI string; the plug-in interface is unchanged (the interface 104 promise already covers
  long names; F5 has handed them to archivers since 222).

## Measurements (before / after, commands)

- At HEAD 66245537: `specs/260-archive-cache-long-names/probe/cache260_probe.ps1` (hidden desktop)
  16 / 0 with ARCCAP showing the refusal of a 604-byte member - the defect.
- `probe/arcmember275_probe.ps1` (hidden desktop, `tools\run_on_hidden_desktop.ps1`):
  - before (the build of the unchanged sources): `probe/result_before.txt` **9 PASS / 5 FAIL** -
    VIEWCAP, VIEWDEEP, EDITCAP, 7Z, TAR refused with "resulting filename is too long";
  - after the core change, without review 1's fix: `probe/result_review1_before_fix.txt` 16 / 1
    (EDITDEEP-LIST: the list item = the folder only);
  - final: `probe/result_after.txt` **17 PASS / 0 FAIL** - the viewer opens on the whole name for a
    604-byte ZIP / 7z / tar member and a 557-byte member in a folder; F4 of a 604-byte and an
    857-byte member packs the edit back under the whole path, the Archive Update list shows it whole;
    OVERLIMIT (the cache's refusal) and CTL unchanged.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s).
- `.\build.cmd` -> BUILD SUCCEEDED (Debug x64; tandemcommander.exe, uncab.spl).
- `saltests.exe` -> `saltests: 24859 checks, 0 failed`.
- Probes: 275 17 / 0; `probe/regress_260.txt` 16 / 0; `probe/regress_222.txt` 10 / 0; the registry
  restored identical after every run.

## Reviews (findings and what was done)

- Review 1: M1 Archive Update list cut to the folder (fixed, probe rows EDITDEEP / EDITDEEP-LIST,
  negative control 16 / 1); S1 CHANGELOG stated the old limit (fixed); S2 the probe's view rows
  accepted any viewer window (fixed: the whole name must be in the title); N1 Copy Selected To
  refuses long targets (Inbox); N2 contract wording (adjusted); N3 / N4 no change.
- Review 2: no MUST; S1 CHANGELOG generalised editing (fixed: "tried with ZIP and 7-Zip" - the
  reviewer drove 7-Zip edit-back); N1-N4 accepted (fix-log, *Review*).

## Owed to a person (with the new person-step items)

None from this feature. Note for the maintainer: the existing person step
`editing-long-named-archive-members-the-rows-the-feature-260` names "the edit-back with a long
%TEMP% (copy path over 620 bytes)"; probe 275 row EDITCAP now drives a copy path of 649 bytes with
the system %TEMP% (the long member name gets it past the old 620-byte cut) - that row may be
checked off by the maintainer (not changed by this run).

## New Inbox items (slug - title)

- `unchm-plug-in-a-member-path-over-259-bytes-overflows-a-stack` - unchm plug-in: a member path over 259 bytes overflows a stack buffer on F3 / F4
- `tar-plug-in-ignores-pax-extended-headers` - tar plug-in ignores PAX extended headers: long or non-ASCII names listed under the ustar fallback name
- `archive-update-copy-selected-to-refuses-long-targets` - Archive Update: Copy Selected To refuses an edited member whose target path is over 259 units
