# Data Model — 077 fix-antivirus-findings

No persistent data is introduced. Three conceptual entities describe what the
build, the signing sweep and the application reason about.

## 1. Runtime Library Set

The Visual C++ runtime files shipped application-locally.

| Attribute | Value / rule |
|---|---|
| Members (today) | `vcruntime140.dll`, `vcruntime140_1.dll`, `msvcp140.dll`, `concrt140.dll` — fixed list in `build.cmd` |
| Source | `<VS_INSTALL>\VC\Redist\MSVC\<redist-version>\x64\Microsoft.VC143.CRT\`, `<redist-version>` read from `<VS_INSTALL>\VC\Auxiliary\Build\Microsoft.VCRedistVersion.default.txt` |
| Destination | root of the Release output tree (next to `tandemcommander.exe`), hence `{app}` in the installer |
| Version invariant | file version ≥ the toolset that built the product (guaranteed by taking both from the same VS installation) |
| Signature invariant | each member carries a valid Authenticode signature whose signer subject contains `O=Microsoft Corporation`; violated → signing sweep fails (pre-flight) |
| Closure invariant | every runtime-pattern DLL name imported (static or delay-load) by any shipped PE (`*.exe *.dll *.spl *.slg`, excluding `\Intermediate\`) is present in the tree root; violated → build fails |
| Runtime-name pattern | `^(vcruntime140\|vcruntime140_1\|vcruntime140_threads\|msvcp140(_[a-z0-9_]+)?\|concrt140\|vccorlib140\|vcamp140\|vcomp140\|mfc140[a-z]*\|mfcm140[a-z]*)\.dll$`, case-insensitive |
| Not members | the Universal CRT (`api-ms-win-crt-*`, `ucrtbase.dll`) — part of Windows 10+ |

## 2. Signing Classification (per candidate file)

State of a file as seen by `sign_release.ps1`, extending feature 050's
two-state model.

| State | Condition | Action | Counted as |
|---|---|---|---|
| **Ours-valid** | Authenticode `Valid`, signer thumbprint = `codesign.cfg` | skip | verified |
| **Microsoft-exempt** *(new)* | Authenticode `Valid`, signer subject contains `O=Microsoft Corporation` | skip, never strip, never re-sign | verified, reported `Exempt (Microsoft): N` |
| **Runtime-invalid** *(new)* | file name matches the runtime-name pattern AND not Microsoft-exempt | **fail the whole run before signing anything**, name the file | failed |
| **Foreign-valid** | Authenticode `Valid`, any other signer (e.g. a previous project certificate) | strip certificate table, sign with the project certificate (rotation, unchanged) | signed |
| **Unsigned / broken** | anything else | strip stale table if present, sign | signed |

Evaluation order per file: Runtime-invalid check first (needs the
Microsoft-exempt test), then Ours-valid, Microsoft-exempt, else sign.

`-VerifyOnly` exit 0 iff no file is in *Foreign-valid*, *Unsigned/broken* or
*Runtime-invalid*.

## 3. Top-Level Exception Filter Registration (process state)

| State | When | Transition |
|---|---|---|
| **Ours** | after the first `CCallStack` is constructed (`SetUnhandledExceptionFilter(TopLevelExceptionFilter)`) | — |
| **Foreign** | an in-process component (shell extension, icon handler) called `SetUnhandledExceptionFilter` with its own filter | detected implicitly: the next re-assert returns a previous value that is neither ours nor the saved original |
| **Re-asserted** | `CallStk_ReassertTopLevelExceptionFilter()` runs from `AddNewlyLoadedModulesToGlobalModulesStore()` (every 15 s on the main thread) | Foreign → Ours (the foreign filter is discarded; a `TRACE_I` records the displacement); Ours → Ours (no-op) |
| **Restored** | last `CCallStack` destroyed at exit: `SetUnhandledExceptionFilter(OldUnhandledExceptionFilter)` | unchanged behaviour |

What no longer exists: the *patched* state in which the entry of
`kernel32!SetUnhandledExceptionFilter` was overwritten with a jump to a
function returning NULL (which made every later registration by anyone a
silent no-op).
