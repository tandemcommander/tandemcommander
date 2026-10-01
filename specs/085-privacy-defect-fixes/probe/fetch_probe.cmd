@echo off
setlocal enabledelayedexpansion
::
:: fetch_probe.cmd - feature 085, privacy defect F2.
::
:: Builds src\plugins\mdview\remotefetch.cpp ALONE (with fetch_main.cpp) and
:: runs it against a local logging HTTP server (fetch_server.py) on 127.0.0.1.
:: Nothing leaves the machine. Checks: identification, no cookies, no automatic
:: authentication, 2xx-only, redirects still followed.
::
:: Outputs (not committed): obj\fetch_probe.exe, obj\build.log
:: Exit code: 0 when every check passed.
::
:: The toolchain block is the one from tests\mdview_htmlgen_test\build_and_run.cmd.

set "HERE=%~dp0"
set "ROOT=%HERE%..\..\..\"
set "OBJ=%HERE%obj"

if defined VSCMD_ARG_TGT_ARCH if /i "%VSCMD_ARG_TGT_ARCH%"=="x64" goto :have_cl

set "VSWHERE="
if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not defined VSWHERE (
    echo ERROR: vswhere.exe not found - is Visual Studio 2022 installed?
    exit /b 1
)
set "VS_TMP=%TEMP%\fetch085_vs.txt"
set "VSPATH="
"!VSWHERE!" -latest -version "[17.0,18.0)" -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath > "!VS_TMP!" 2>nul
if exist "!VS_TMP!" (
    set /p VSPATH=<"!VS_TMP!"
    del "!VS_TMP!" >nul 2>&1
)
if not defined VSPATH (
    echo ERROR: no VS2022 installation with the C++ x64 toolset was found.
    exit /b 1
)
call "!VSPATH!\VC\Auxiliary\Build\vcvarsall.bat" x64 >nul 2>&1
if errorlevel 1 (
    echo ERROR: vcvarsall.bat x64 failed.
    exit /b 1
)
:have_cl

where cl.exe >nul 2>&1
if errorlevel 1 (
    echo ERROR: cl.exe is still not on PATH after vcvars.
    exit /b 1
)
if not exist "%OBJ%" mkdir "%OBJ%"

set "FLAGS=/nologo /EHsc /std:c++latest /W4 /WX /MD /DUNICODE /D_UNICODE /DWIN32_LEAN_AND_MEAN"

pushd "%HERE%"
:: "fetch_probe.cmd pre085" builds the PRE-085 function instead (negative
:: control, extract_pre085.py): the probe must then report failures.
set "UNIT=%ROOT%src\plugins\mdview\remotefetch.cpp"
if /i "%~1"=="pre085" (
    python extract_pre085.py "%OBJ%\remotefetch_pre085.cpp"
    if errorlevel 1 (
        echo RESULT: EXTRACT FAILED
        popd
        exit /b 1
    )
    set "UNIT=%OBJ%\remotefetch_pre085.cpp"
    set "FLAGS=/nologo /EHsc /std:c++latest /W3 /MD /DUNICODE /D_UNICODE /DWIN32_LEAN_AND_MEAN"
)
echo [1/2] fetch_probe.exe (!UNIT! alone)
cl %FLAGS% /I"%ROOT%src\plugins\mdview" /Fo"%OBJ%\\" /Fe"%OBJ%\fetch_probe.exe" fetch_main.cpp "!UNIT!" /link /SUBSYSTEM:CONSOLE winhttp.lib >"%OBJ%\build.log" 2>&1
if errorlevel 1 (
    type "%OBJ%\build.log"
    echo RESULT: BUILD FAILED
    popd
    exit /b 1
)

echo [2/2] running against the local logging server
python fetch_server.py "%OBJ%\fetch_probe.exe"
set "RC=%ERRORLEVEL%"
if "%RC%"=="0" (echo RESULT: PASS) else (echo RESULT: FAIL ^(exit %RC%^))
popd
exit /b %RC%
