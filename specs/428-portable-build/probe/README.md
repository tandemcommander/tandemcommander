# Probes of feature 428 (portable build)

| Script | What it proves | Spec |
|--------|----------------|------|
| `tree_manifest.py` | the normal edition's output tree is unchanged (file list + PE hashes with time stamps, checksum, signature and debug directory zeroed) | SC-010 |
| `roundtrip_gate.py` (+ the saltests seam) | the configuration survives dump → parse without a single lost key, value, type or byte | FR-010, R-14 |
| `notrace_probe.py` | a portable session writes nothing to the registry or the profile (WebView2 runtime traces and the %TEMP% time stamp reported apart); settings persist; `--label normal` = the negative control (must FAIL) | SC-002, US1 |
| `scenarios_probe.py` | move (subst drive, non-ASCII path, `$(PortableDir)`), unwritable / damaged files, 20 kills during a save, side by side with the installed edition and another copy | SC-003, SC-006, SC-007, US2, US6, FR-011a |
| `import_probe.py` | Options > Import Configuration of the portable edition: checked at once, applied at the next lone start, `$(PortableDir)` of another copy expanded, refused file | FR-013 |
| `identity_probe.py` | title in 8 languages, About lines (pixels, not cut), the link (Enter) opens `settings`, icon resources, About screenshots Default / Dark; the normal edition unchanged | US4, FR-014 – FR-016 |
| `update_probe.py` | the new-version check with 123's fixture server (`with-portable`, `newer`, `portable-not-uploaded`): link-only notice without the level list, General page, nothing downloaded | US5, FR-017 |
| `pwdnote_probe.py` | the password note (Debug seam `TC_PORTABLE_TEST_PWDNOTE`): once, "Do not show again" kept, Set Master Password | FR-015a |
| `timing_probe.py` | start-up and exit-with-save time vs. the installed edition (Release), no rewrite without a change | SC-009 |
| `zip_check.py` | the ZIP's layout and contents; two builds of one commit: same list, same files apart from build time stamps | FR-003, SC-005 |
| `run_all.ps1` | every probe above on the hidden desktop, one summary | — |

## Rules

- GUI rows run on the hidden desktop (`tools/run_on_hidden_desktop.ps1`): the maintainer works on
  the machine. No real keyboard or clipboard there — such rows are NOT DRIVEN and owed to a person.
- Every probe that starts the program backs up `HKCU\Software\Tandem Commander` first, restores it
  at the end (also after a failure), and **checks that the installed edition's key is unchanged**
  — for a portable session that check is part of the result. An interrupted probe: restore the
  backup it names before anything else (memory rule "interrupted probe leaves registry").
- Fixtures live under `%TEMP%\tc428\`; every path a probe types must start with that root.
- Logs and results go to `probe/results/<probe>-<UTC>.txt`; the fix-log cites them.

## baseline/

Manifests of the normal trees at `ce4bab86` (before the feature) and the build logs of the first
portable builds.
