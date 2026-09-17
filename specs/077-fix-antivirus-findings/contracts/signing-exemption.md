# Contract: Signing sweep — Microsoft-signed runtime files

Amends `specs/050-code-signing/contracts/signing-cli.md` §1 ("Per-file
behavior"). Everything not restated here is unchanged (candidate selection,
batching, retries, pre-flight, summary format, exit codes).

## Per-file behaviour (replaces the two-state rule)

Evaluated per candidate, in this order:

1. **Runtime-invalid → fail before touching any file.** If the file name
   matches the runtime-name pattern
   `^(vcruntime140|vcruntime140_1|vcruntime140_threads|msvcp140(_[a-z0-9_]+)?|concrt140|vccorlib140|vcamp140|vcomp140|mfc140[a-z]*|mfcm140[a-z]*)\.dll$`
   (case-insensitive) and is **not** Microsoft-exempt (rule 3), the run
   prints `ERROR: runtime file is not validly signed by Microsoft: <path>`
   for every such file and exits 1 with nothing modified.
2. **Ours-valid → skip.** Authenticode `Valid` and signer thumbprint equals
   the profile thumbprint (unchanged from 050).
3. **Microsoft-exempt → skip, never strip, never re-sign.** Authenticode
   `Valid` and the signer certificate's subject contains
   `O=Microsoft Corporation`. Counted as verified.
4. **Otherwise → strip any stale certificate table and sign** with the
   profile certificate (unchanged: covers unsigned files, files signed by a
   previous project certificate, and third-party unsigned files).

## Summary and verification

- Summary line becomes
  `Signed: N  Skipped: M  Exempt (Microsoft): E  Failed: K  (of T)`;
  `Verified : V of T` counts Ours-valid + Microsoft-exempt.
- The final verification pass applies the same classification; a runtime
  file that lost its Microsoft signature during the run (impossible by
  construction, but checked) is reported as `FAILED: <path>`.
- `-VerifyOnly`: exit 0 iff every candidate is Ours-valid or
  Microsoft-exempt and no candidate is Runtime-invalid; each offending file
  is printed as `NOT SIGNED BY CURRENT CERT: <path>` or
  `RUNTIME FILE NOT MICROSOFT-SIGNED: <path>`.
- Single-file mode (`-File`) applies the same rules to its one candidate
  (the per-target hook never sees runtime files, but the rule is uniform).

## Compatibility

- Windows PowerShell 5.1, ASCII-only script text (unchanged constraint).
- `setup\build_setup.cmd sign` and `build.cmd ... sign` need no change: they
  call the sweep and rely on its exit code.
- `Test-SignedByCurrent` semantics for OS-catalog-signed files (050) are
  unchanged; a catalog-signed Microsoft file whose *embedded* signer is
  Microsoft is Microsoft-exempt, one whose embedded signer is the project
  certificate is Ours-valid, as before.
