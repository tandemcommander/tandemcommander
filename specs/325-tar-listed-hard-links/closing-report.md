# Closing report - 325-tar-listed-hard-links
Backlog item: tar-copy-of-listed-files-leaves-hard-links-out - Copying the files of a tar folder leaves hard-linked names out silently
Outcome: closed

## What changed

- `src/plugins/tar/untar.cpp`, `tar.h`, `precomp.h` (TAR plug-in):
  - `ListArchive` lists every hard-link member (not refused, not a folder) as a file with the size of
    the data member it stands for.
  - `DoUnpackArchive` defers an asked hard link whose target it neither wrote nor was asked for (or
    whose target is a deferred link); `ExtractDeferredLinks` reopens the archive (`ReopenStream`) and in
    one further pass writes each group's data under the first link the user lets be written (overwrite
    questions before the data is read), the other links copied by 309's `WriteOutLinkCopy`; unresolved
    links are reported and fail the operation.
  - `UnpackOneFile` (F3, disk cache) resolves a listed link and re-reads the archive for its data member.
  - Links resolve as tar extracts them (latest earlier definition of the name; ordinal-exact passes); a
    later asked member of a deferred link's name - case ignored as on Windows - supersedes it.
  - "Unknown block signature" is not shown again by a further pass; `WriteOutData` takes an already
    opened target (`openedFile`).
- `src/common/saltarlink.h`: `SAL_TAR_LINK_DEFER`, `SalTarLinkDecideAsked`, `CSalTarLinkResolver`.
- `src/saltests/saltests.cpp`: `TestTarLink325`.
- `CHANGELOG.md` (0.1.11 unreleased), `specs/FEATURE-HISTORY.md` (entry + index row "Archives").

## Measurements (before / after, commands)

`powershell -File tools\run_on_hidden_desktop.ps1 -Log ... -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\325-tar-listed-hard-links\probe\link325_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe ..."`

- Before (main 0991f43c): `probe/result_before.txt` PASS 11 / FAIL 7 - Select All + Copy inside
  `t.tar\sub` 1 of 3 files, no message (also gzip, chain); a missing-target link unlisted, nothing
  reported; End + Copy / F3 reach `c.txt` only.
- After: `probe/result_after_review2b.txt` PASS 32 / FAIL 0 (rows of both reviews included: `tar -u`
  Unpack with a mask + Delete archive, redefined target, case twin, Skip / Skip All in a group, unknown
  member type before the data).
- Negative controls: second pass + one-file re-read off `result_negctl.txt` 12 / 6; pre-review-1 code
  `result_negctl_review1.txt` 3 / 3 (stale data + archive deleted reproduced); pre-review-2 code
  `result_negctl_review2.txt` 2 / 2 and `result_negctl_review2b.txt` (COPY-BADSIG two boxes) - fail as
  expected; restored builds pass.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s).
- `.\build.cmd` -> BUILD SUCCEEDED (Debug x64; no UI string, resource or plug-in list changed - no
  `build.cmd full` / `.slt` refresh needed).
- `saltests.exe` -> `saltests: 27884 checks, 0 failed`.
- Probes: link325 32 / 0; regression (`probe/run_regress.ps1`, `probe/regress_*.txt`) pax306 30 / 0,
  unp308 12 / 0, link309 16 / 0, cpio310 52 / 0, tar321 20 / 0, unp321 12 / 0 - unchanged in every run.
  Registry restored and identical after every probe of this run.

## Reviews (findings and what was done)

- Review 1: MUST M1 (first instead of latest member of a name: stale data, archive deleted) - fixed
  (`CSalTarLinkResolver`); SHOULD S1 quadratic chains - fixed (O(1)); S2 Skip dropped the other names -
  fixed; S3 probe rows - added.
- Review 2: three launches stopped mid-probe without a report (each left the registry changed -
  restored from its backup, hashes identical, recorded in `fix-log.md`); their partial results showed
  X-RELINK2 (redefined target -> on-disk data copied, archive deleted) and X-CASE (case twin did not
  supersede) - both fixed. The fourth launch (no GUI probes): no MUST; SHOULD S1 (signature box per
  pass) and S2 (a pass per skipped link) fixed; NOTE 1 fixed; NOTEs 2, 3, 5 accepted as limits; NOTE 4
  -> Inbox.

## Owed to a person (with the new person-step items)

Nothing: every row was driven on the hidden desktop.

## New Inbox items (slug - title)

- tar-unpack-skips-fifo-and-device-members-without-a-word - Tar unpack skips FIFO and device members without a word
