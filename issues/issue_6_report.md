Thank you - a precise report, and the kind of failure nobody would find by looking at the program.

**Verdict: valid.** Fixed for the next release, **0.1.10** (feature 126, branch `126-package-api-late-bind`).

One thing first, so that nobody is misled: **Tandem Commander supports Windows 11 and newer only.** That does not change. What changes is that the program no longer refuses to start on older systems *by accident and in silence*.

### What could be verified (and what could not)

I have no Windows 7 or Server 2008 R2 machine, so the failed start itself was not reproduced. Checked independently:

| Claim | Result |
|---|---|
| `tandemcommander.exe` imports `GetPackagesByPackageFamily` and `GetPackagePathByFullName` statically | **confirmed** - both are in the import directory of `KERNEL32.dll` (read with `dumpbin` and with a separate import-table parser written for this fix) |
| they do not exist before Windows 8 | **confirmed, and one is newer than reported**: `GetPackagesByPackageFamily` needs Windows 8 / Server 2012, `GetPackagePathByFullName` needs Windows **8.1** / Server 2012 R2 (Microsoft's reference). So Windows 8.0 was affected too |
| only the main program is affected | **confirmed** - none of the other 217 executable files of the release tree (plug-ins, language modules, helpers, runtime DLLs) imports either function |
| these are the *only* functions the server lacks | **not verifiable here** - this rests on your `GetProcAddress` sweep on the server |

The two calls came in with the command-shell presets (looking up shells installed as Store packages) - an oversight, not a decision to drop older systems: the build still targets the Windows 7 API level and the program still carries its "You need at least Windows 7" check, which could never be shown because the loader stopped the process first.

### The fix

As you proposed: the two functions are looked up at run time (`GetProcAddress`); where either is missing there are simply no packages, and a packaged shell is "not found" - exactly as on a Windows 11 machine without that package. Two differences from the proposed patch:

- nothing is cached in function-local statics (the lookup is called from more than one thread; resolving each time costs a few microseconds and needs no synchronisation);
- the lookup takes the two functions as a parameter, so it can be tested with the functions "absent".

### Tests

- **Import tables**: the static imports of the release `tandemcommander.exe` went from 796 to 794 - exactly these two removed, nothing added; a scan of all 218 executable files of the release tree finds no static import of either function (the 0.1.9-state executable fails the same scan, as a control).
- **Unit tests** (27 new checks): the functions absent (Windows 7), only the first present (Windows 8.0), every error answer of either function, a package folder that does not fit the caller's buffer (refused, never cut), a folder with non-ASCII letters, and the real functions of the test machine.
- **Live on Windows 11**: for the packages installed on the test machine (Windows Terminal, Notepad, Calculator, ...) the program's lookup returns the same folder that `Get-AppxPackage` reports, and "not found" for a package that does not exist.
- The existing unit tests of the command-shell presets pass unchanged; the program starts and exits cleanly.
- An independent code review of the change.

### What I would ask of you

If you can, please try the 0.1.10 build on your Server 2008 R2 machine when it is out and confirm that it starts - that is the one test I cannot run. Two things I noticed while reading the import tables of the whole release tree, both outside this fix:

- the program needs the Universal C runtime (`api-ms-win-crt-*.dll`); the installer brings the Visual C++ runtime DLLs but not the UCRT, which Windows 7 / Server 2008 R2 get from update KB2999226 (your server evidently has it);
- the Code Viewer and Markdown Viewer plug-ins (`codeview.spl`, `mdview.spl`) import `EventSetInformation` from `advapi32.dll` through the WebView2 loader - documented for Windows 8 and newer. If it is missing, those two plug-ins will not load; the program itself is not affected.

And nothing else is tested there: problems that only occur on Windows versions before 11 may not be fixed.

The fix will be part of **Tandem Commander 0.1.10**.
