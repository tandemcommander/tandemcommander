# CLI & Config Contracts: On-Demand Release Code Signing

Four public surfaces. Anything not specified here is an implementation detail.

## 1. `tools/codesign/sign_release.ps1` (signing core)

```
powershell -NoProfile -ExecutionPolicy Bypass -File tools\codesign\sign_release.ps1
    -Root <dir>          # sweep mode: sign all PE artifacts under <dir>
  | -File <path>         # single-file mode: sign one file (used by the props hook)
   [-Config <path>]      # signing profile; default: codesign.cfg next to the script
   [-VerifyOnly]         # no signing; report tree state and set exit code
```

- Mutually exclusive `-Root` / `-File`; exactly one required.
- Candidate selection (sweep): `*.exe, *.dll, *.spl, *.slg` recursively,
  paths containing `\Intermediate\` excluded.
- Per-file behavior: skip iff Authenticode `Valid` + thumbprint matches
  profile; otherwise sign with
  `signtool sign /sha1 <thumbprint> /tr <timestamp_url> /td sha256 /fd sha256 /v <files…>`.
  **Amended by feature 077**
  (`specs/077-fix-antivirus-findings/contracts/signing-exemption.md`): a file
  with a `Valid` signature whose signer subject contains
  `O=Microsoft Corporation` (the application-local Visual C++ runtime) is
  *exempt* — never stripped, never re-signed, counted as verified and
  reported as `Exempt (Microsoft): N`; a file whose name matches the runtime
  pattern (`vcruntime140*`, `msvcp140*`, `concrt140`, …) that is *not*
  validly Microsoft-signed fails the run before any file is touched
  (`ERROR: runtime file is not validly signed by Microsoft: <path>`, exit 1).
- Batching: ≤ 15 files per signtool invocation; per batch ≤ 3 attempts,
  5 s pause between attempts; after a failed batch, per-file fallback within
  that batch.
- Pre-flight failures (exit 1, no file modified): missing/invalid config,
  certificate not found in `Cert:\CurrentUser\My` or `Cert:\LocalMachine\My`,
  signtool not found, root/file not found, no candidates found under -Root.
- Ends with a verification pass over all candidates; prints summary
  `Signed: N  Skipped: M  Exempt (Microsoft): E  Failed: K  (of T)` plus each
  failed path on its own `FAILED: <path>` line (feature 077 added the
  `Exempt` column).
- Exit code: `0` iff every candidate verifies as signed by the configured
  certificate or is Microsoft-exempt; `1` otherwise. `-VerifyOnly`: `0` iff
  tree already fully signed (exempt files count as signed; a runtime file
  without a valid Microsoft signature is reported as
  `RUNTIME FILE NOT MICROSOFT-SIGNED: <path>`, exit 1).

## 2. `tools/codesign/codesign.cfg` (signing profile)

```ini
# Tandem Commander release signing profile
thumbprint    = a3d05ccf5ca13eaff49cc7f64d1832f0e6ef6733
timestamp_url = http://time.certum.pl
```

Contract per data-model.md (two mandatory keys, `#` comments allowed).
Consumed by `sign_release.ps1` and `setup\build_setup.cmd`.

## 3. `tools/codesign/sign_with_retry.cmd` (per-target post-build hook)

Called by every `*_release.props` as
`call ..\..\tools\codesign\sign_with_retry.cmd "$(TargetPath)"` (path depth
varies per project — the relative prefix differs, the script must not care).

- `TC_CODESIGN` env var unset/empty → **no-op, exit 0** (default: FR-002).
- `TC_CODESIGN=1` → delegates to `sign_release.ps1 -File <arg>`; propagates
  its exit code (non-zero fails the build).
- Must accept a quoted path with spaces as `%1`.

## 4. `build.cmd` (build entry point — new arguments)

```
build.cmd [rebuild] [release] [full] [sign] [setup]
```

- `sign`: after a successful build (and full-build runtime population),
  run the sweep over the output tree. **Requires `release`** — `sign`
  without `release` exits 1 before building, with an explanatory message.
  Sweep failure ⇒ overall `BUILD_EXIT` non-zero.
- `setup`: after everything else succeeds, invoke
  `setup\build_setup.cmd` — with `sign` argument iff `sign` was given.
  Requires `release` as well (installer packages the Release tree).
- Neither argument present ⇒ behavior byte-identical to before this feature.
- `:clean_release_tree` (Release only, unchanged trigger) additionally
  deletes `*.pdb`, `*.lib`, `*.exp` under the output root.
- Summary block reports signing/installer outcome lines when requested.

## 5. `setup/build_setup.cmd` (installer build)

```
setup\build_setup.cmd [sign]
```

- Locates ISCC: `C:\Program Files\Inno Setup 7\ISCC.exe` → `where iscc` →
  `C:\Program Files (x86)\Inno Setup 6\ISCC.exe`; all missing ⇒ exit 1 with
  install hint.
- Requires `..\build…\Release_x64\tandemcommander.exe` (resolves
  `OPENSAL_BUILD_DIR`, defaulting to `<repo>\build\` like build.cmd);
  missing ⇒ exit 1 telling the user to run `build.cmd full release` first.
- Without `sign`: `ISCC.exe tandemcommander.iss` — no signing dependencies
  touched.
- With `sign`:
  1. sweep: `sign_release.ps1 -Root <Release_x64>` (fails ⇒ abort, exit 1);
  2. compile: `ISCC.exe /DSIGN=1 "/Stcsign=$q<signtool>$q sign /sha1 <thumb> /tr <tsa> /td sha256 /fd sha256 /v $f" tandemcommander.iss`;
  3. verify the produced installer signature (`sign_release.ps1 -File … -VerifyOnly`
     semantics or Get-AuthenticodeSignature check); failure ⇒ exit 1.
- Output: `setup\output\tandemcommander-<version>-x64-setup.exe` (unchanged
  location/name).

## 6. `setup/tandemcommander.iss` (installer script — additions only)

```iss
[Setup]
...
#ifdef SIGN
SignTool=tcsign
SignedUninstaller=yes
#endif

[Files]
Source: "..\build\tandemcommander\Release_x64\*"; DestDir: "{app}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs; \
  Excludes: "*.pdb,*.lib,*.exp"
```

- Compiling without `/DSIGN=1` must succeed on a machine with no certificate
  and no signtool.
- `tcsign` is defined exclusively on the ISCC command line (never committed).
