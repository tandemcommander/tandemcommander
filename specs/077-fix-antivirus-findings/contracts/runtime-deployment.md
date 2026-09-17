# Contract: Application-local Visual C++ runtime in the release tree

Two public surfaces. Anything not specified here is an implementation detail.

## 1. `build.cmd` — Release builds ship the runtime

Applies to every invocation with the `release` argument (full or incremental);
Debug builds are untouched.

- **When**: after the plugin build succeeds and, for `full` builds, after
  the runtime layout (`:populate_runtime`) is populated; before
  `:clean_release_tree`, signing and the installer. Incremental Release
  builds run the same step so that a Release tree is never left without the
  runtime once it has been built.
- **Source**: `<VS_INSTALL>\VC\Redist\MSVC\<v>\x64\Microsoft.VC143.CRT\`,
  with `<v>` = first line of
  `<VS_INSTALL>\VC\Auxiliary\Build\Microsoft.VCRedistVersion.default.txt`
  and `<VS_INSTALL>` the installation path `build.cmd` already resolves
  through `vswhere`. No environment variable and no absolute path is
  consulted. If `build.cmd` fell back to MSBuild from `PATH` (no `vswhere`),
  the step tries `%VCToolsRedistDir%` (set by a developer command prompt)
  and otherwise fails as below.
- **Files copied** (fixed list, tree root, overwrite):
  `vcruntime140.dll`, `vcruntime140_1.dll`, `msvcp140.dll`, `concrt140.dll`.
- **Implementation surface**: the copy is performed by the helper
  `src\vcxproj\copy_vc_runtime.cmd <VS_INSTALL> <OUT_DIR>` (exit 0 on
  success, 1 on any failure, messages as below), which `build.cmd` calls;
  the helper is independently runnable so the failure branch can be tested
  without touching a real Visual Studio installation.
- **Failure** (build stops, `BUILD_EXIT=1`, message on stderr/stdout):
  - `ERROR: Visual C++ runtime not found: <path>` + hint to install the
    "C++ 2022 Redistributable Update" component / "Desktop development with
    C++" workload, when the version file or the directory or any listed file
    is missing;
  - `ERROR: Visual C++ runtime check failed` when the closure check below
    reports a problem (its own output precedes the line).
- **Success output**: one line
  `  Visual C++ runtime <v>: 4 file(s) copied from <dir>` followed by the
  check's summary line.
- **Closure check**: after copying, `build.cmd` runs
  `python "%~dp0tools\check_runtime_deps.py" "%OUT_DIR%"`; a non-zero exit
  fails the build.
- **Cleaning**: `:clean_release_tree` MUST NOT remove the runtime files (it
  removes `*.pdb *.lib *.exp`, `Intermediate\`, `saltests\` only — unchanged).
- **Installer**: no change to `setup/tandemcommander.iss`; the recursive
  `[Files]` entry packages the four files into `{app}`; the uninstaller
  removes them (standard Inno behaviour for files it installed).

## 2. `tools/check_runtime_deps.py` — runtime import closure

```
python tools\check_runtime_deps.py <tree> [--pattern <regex>] [--list]
```

- Walks `<tree>` recursively for `*.exe *.dll *.spl *.slg`, skipping any path
  containing `\Intermediate\`.
- For each file parses the PE import directory and the delay-load import
  directory (PE32 and PE32+; a file that is not a PE is reported and skipped,
  exit 2 only if **no** PE was found at all).
- Collects imported DLL names (case-insensitive) matching the runtime-name
  pattern (default = the pattern in `data-model.md` §1; `--pattern`
  overrides for testing).
- **Passes** (exit 0) iff every such name exists as a file in the **root**
  of `<tree>`. Prints
  `runtime closure OK: <n> module(s) scanned, <k> runtime import(s), shipped: <names>`.
- **Fails** (exit 1) otherwise; prints one line per violation:
  `<relative module path> needs <dll> (not shipped)` and a final
  `runtime closure FAILED: <count> unsatisfied import(s)`.
- `--list` additionally prints every module with its runtime imports (for the
  record / quickstart evidence).
- Exit 2: bad arguments, tree missing, or no PE file found.
- Standard library only (Python 3.8+); UTF-8-BOM source, ASCII output.
