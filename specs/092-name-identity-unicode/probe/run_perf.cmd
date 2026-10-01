@echo off
setlocal enabledelayedexpansion
::
:: run_perf.cmd - feature 092: builds (/O2) and runs perf_probe.cpp; see build_and_run.cmd
:: each from its own source and the product's src\common\salunicode.cpp (with
:: the saltests stand-in precomp.h and the product's /J):
::   obj\case_only_probe.exe     (stage S3) "only a change of case" / "the same file"
::   obj\path_identity_probe.exe (stages S4, S5) path equality, prefix tests,
::                               sorted name lists
:: Both are always built and run. Exit code 0 = both passed; otherwise the
:: exit code of the first one that failed.
:: Not part of any build; nothing here ships.
::
:: The toolchain block is the one from specs\087-7zip-2603-rar\probe\build_7zdrive.cmd.

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
set "VS_TMP=%TEMP%\probe092_vs.txt"
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
:have_cl
where cl.exe >nul 2>&1
if errorlevel 1 (
    echo ERROR: cl.exe is not on PATH after vcvars.
    exit /b 1
)
if not exist "%OBJ%" mkdir "%OBJ%"

set "FINAL=0"
call :probe perf_probe
if "%FINAL%"=="0" (echo ALL PROBES PASSED) else (echo A PROBE FAILED - exit code %FINAL%)
exit /b %FINAL%

:: builds obj\%1.exe from %1.cpp and runs it; a failure is remembered in FINAL
:probe
pushd "%HERE%"
:: /J unsigned char, /RTC1, /Od, /MDd - the product's Debug switches
cl /nologo /J /O2 /MD /EHsc /W3 /D_CRT_SECURE_NO_WARNINGS /I"%ROOT%src\saltests" /I"%ROOT%src\common" /Fo"%OBJ%\\" /Fe"%OBJ%\%1.exe" %1.cpp "%ROOT%src\common\salunicode.cpp" /link user32.lib >"%OBJ%\build_%1.log" 2>&1
set "RC=!ERRORLEVEL!"
if not "!RC!"=="0" type "%OBJ%\build_%1.log"
popd
if not "!RC!"=="0" (
    echo BUILD FAILED: %1
    if "!FINAL!"=="0" set "FINAL=!RC!"
    exit /b !RC!
)
echo.
echo ===== %1 =====
"%OBJ%\%1.exe"
set "RC=!ERRORLEVEL!"
if not "!RC!"=="0" if "!FINAL!"=="0" set "FINAL=!RC!"
exit /b !RC!
