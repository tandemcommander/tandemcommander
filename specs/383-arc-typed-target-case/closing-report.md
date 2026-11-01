# Closing report - 383-arc-typed-target-case
Backlog item: copying-into-an-archive-folder-typed-in-another-case-packs - Copying into an archive folder typed in another case packs into a new folder beside it
Outcome: closed

## What changed

- `src/fileswn8.cpp`: in the archive branch of `CFilesWindow::FilesAction` (Copy / Move from a disk
  panel into an archive named in the typed target), a copy of the typed path inside the archive is
  re-spelled before `PackCompress` (`RespellTypedArchiveRoot383`): the archive's listing - a panel's
  listing of the same archive whose date and size are unchanged and whose name does not lead
  elsewhere, else `PackList` (only for a format that can list, `ArchiveCanBeListed383`) - resolves
  the typed root by 382's `ResolvePathCase`; `SalArcPathApplyResolved` lays the found names over the
  typed root, a component only when `SalNameEqualOrdinalCI` takes it as the same name. The typed
  text itself (dialog, history, the way back to the dialog on an error) is unchanged. Zero-size
  archives and failed / impossible listings keep the typed root.
- `src/common/salarcpathspell.h`: `SalArcPathApplyResolved` (header-only, same-name callback).
- `src/saltests/saltests.cpp`: `TestArcPathApplyResolved383`.
- No UI string, dialog, resource, plug-in interface, stored data or network change.

## Measurements (before / after, commands)

Probe `specs/383-arc-typed-target-case/probe/arctarget383_probe.ps1`, hidden desktop
(`tools\run_on_hidden_desktop.ps1`), fixtures made by `C:\Program Files\7-Zip\7z.exe`:

| Run | Result |
|---|---|
| before (e3dfe127) | 22 / 10 (`probe/result_before.txt`): TYPED, DEEP, NEWTAIL, MOVE, TWINS fail for 7z and ZIP - `DOCS\n.txt` beside `Docs` |
| after | **44 / 0** (`probe/result_after.txt`), rows PANEL and FOLD / FOLDOW added |
| negative: the call disabled | 24 / 12 (`probe/result_negative.txt`) |
| negative: only the own listing disabled | 34 / 10 (`probe/result_negative_ownlisting.txt`) - PANEL passes on the panel's listing alone |
| negative: the same-name test disabled | FOLD / FOLDOW 4 / 4 (`probe/result_negative_samename.txt`) - files in `Ĝ`, overwrite question |
| 273's probe | 12 / 0 (`probe/regress_273_after.txt`) |
| 382's probe | 24 / 0 (`probe/regress_382_after.txt`) |

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s)
- `.\build.cmd` -> BUILD SUCCEEDED (no `full` needed: no string, resource or language change)
- `saltests.exe` -> `30477 checks, 0 failed` (the same-name test disabled: 6 failed)
- probes as above; every run restored the registry with an identical SHA-256.

## Reviews (findings and what was done)

- Review 1: MUST M1 - the listing's byte fold took typed `Č` for the folder `Ĝ` (cp1250 / cp1252
  0x8C -> 0x9C); files went into `Ĝ` and an existing member was replaced after an overwrite question
  -> fixed (same-name callback), rows FOLD / FOLDOW, saltests. SHOULD S1 - branch control for the
  panel listing -> done (34 / 10). NOTE N1 (non-ASCII case pairs) -> Inbox; NOTE N2 (extra listing) ->
  accepted limit; the panel route's own fold -> Inbox.
- Review 2: no MUST / SHOULD; data safety of the new collision proven by the reviewer's own rows
  (overwrite question; Cancel / Skip keep the member and the Move source); NOTE comment corrected,
  NOTE plain F5 into an archive panel also re-spells (reuses the panel's listing) - accepted.

## Limits

- A non-ASCII case pair (`Č` typed, `č` in the archive) is not equal by the listing's fold: packed
  beside it, as before.
- One extra listing per typed Copy / Move into an archive no panel shows unchanged (time for a large
  archive; a header-encrypted 7z may ask for its password; a listing error may precede the packer's
  error); a cancelled listing packs with the typed spelling.

## CHANGELOG entry (to be added by a person - `CHANGELOG.md` has no `## [Unreleased]` section)

```text
- **Copying or moving files into an archive folder typed in another case put them into a new folder beside it** (feature 383).
  - **Before:** F5 or F6 from a disk panel with the target typed as `<archive>\DOCS\` while the archive holds the folder `Docs` packed the files into a new folder `DOCS` beside `Docs` (7z and ZIP); deeper paths (`\dOCS\sUB\`) and a new sub-folder (`\DOCS\New\`) did the same.
  - **Now:** the typed folder is spelled as the archive spells it before packing, so the files land in `Docs` (a new sub-folder keeps the name you typed). An exact name always wins, two folders that differ only in case are never guessed, and a different letter that only looks alike to the old comparison (`Č` against `Ĝ`) is never taken for the existing folder.
  - **Limitation:** a case difference of a non-ASCII letter (`Č` typed, `č` in the archive) still makes a second folder; when no panel shows the archive, it is listed once more before packing.
```

## Owed to a person (with the new person-step items)

- Add the CHANGELOG entry above (no `## [Unreleased]` section exists; versions are the maintainer's).
- No person-step item: every probe row was driven.

## New Inbox items (slug - title)

- archive-path-typed-opens-another-letter-equal-by-byte-fold - A path typed into an archive opens another letter equal only by the byte fold
- typed-archive-target-non-ascii-case-makes-a-twin - A typed archive target in another case of a non-ASCII letter still makes a twin
