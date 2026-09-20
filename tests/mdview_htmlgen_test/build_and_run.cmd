@echo off
setlocal enabledelayedexpansion
::
:: build_and_run.cmd - builds and runs the mdview Markdown->HTML generator test
:: harness, and the dumper that shares its sources.
::
:: Written by feature 081. The harness sources have been committed since
:: feature 021, but its .vcxproj never was (recorded in mdview's
:: IMPLEMENTATION_NOTES.md, "v2.2 verification status"), so there was no way to
:: run it from a clean checkout. This script replaces the missing project file:
:: a direct cl.exe recipe, no MSBuild, no solution entry.
::
:: The harness links the generator only - htmlgen + render + highlight + md4c.
:: It is a pure transformation test: no WebView2, no plugin runtime, and
:: therefore no stub objects (those three sources reference no plugin global).
::
:: Outputs (gitignored): obj\htmlgen_test.exe, obj\htmlgen_dump.exe, obj\build.log
:: Exit code: 0 when every assertion passed, 1 otherwise.
::
:: Usage:  build_and_run.cmd                       build and run the assertions
::         build_and_run.cmd dump <in.md> <out.html> [theme]
::                                                 build and render one file
::                                                 (specs/081-.../probe/check_csp_compat.py)
::

set "HERE=%~dp0"
set "ROOT=%HERE%..\..\"
set "OBJ=%HERE%obj"

:: ---------------------------------------------------------------- toolchain
:: Same locate-then-vcvars pattern as build.cmd, including its temp-file
:: capture: a for/f over a quoted path with spaces is the one cmd construct
:: that silently mangles this call.
if defined VSCMD_ARG_TGT_ARCH if /i "%VSCMD_ARG_TGT_ARCH%"=="x64" goto :have_cl

set "VSWHERE="
if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not defined VSWHERE (
    echo ERROR: vswhere.exe not found - is Visual Studio 2022 installed?
    exit /b 1
)

set "VS_TMP=%TEMP%\mdview_htmlgen_vs.txt"
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
if not exist "!VSPATH!\VC\Auxiliary\Build\vcvarsall.bat" (
    echo ERROR: vcvarsall.bat not found under "!VSPATH!".
    exit /b 1
)
:: stderr is silenced too: some VS installs have vcvarsall call vswhere.exe
:: without a path, which prints a harmless "not recognized" line.
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

:: ------------------------------------------------------------------ sources
set "GEN="%ROOT%src\plugins\mdview\htmlgen.cpp" "%ROOT%src\plugins\mdview\render.cpp" "%ROOT%src\plugins\mdview\highlight.cpp""

set "INC=/I"%ROOT%src\plugins\mdview" /I"%ROOT%src\plugins\shared" /I"%ROOT%src\common\dep\md4c" /I"%ROOT%src\common\webhost" /I"%ROOT%src\common\dep\webview2\include""

set "FLAGS=/nologo /EHsc /std:c++latest /W3 /MD /DNDEBUG /D_CRT_SECURE_NO_WARNINGS /DWIN32_LEAN_AND_MEAN /DWINVER=0x0A00 /D_WIN32_WINNT=0x0A00"

pushd "%HERE%"

:: md4c is C, not C++: compiled separately so /std:c++latest does not apply.
echo [1/3] md4c.c
cl %FLAGS% /c /Fo"%OBJ%\md4c.obj" "%ROOT%src\common\dep\md4c\md4c.c" >"%OBJ%\build.log" 2>&1
if errorlevel 1 goto :buildfail

if /i "%~1"=="dump" goto :dump

:: /Fo names a DIRECTORY here (trailing backslash) - with several source files
:: cl refuses a file-name prefix (D8036).
echo [2/3] htmlgen_test.exe
cl %FLAGS% %INC% /Fo"%OBJ%\\" /Fe"%OBJ%\htmlgen_test.exe" test_main.cpp %GEN% "%OBJ%\md4c.obj" /link /SUBSYSTEM:CONSOLE >>"%OBJ%\build.log" 2>&1
if errorlevel 1 goto :buildfail

echo [3/3] running the assertions
echo.
"%OBJ%\htmlgen_test.exe"
set "RC=%ERRORLEVEL%"
echo.
if "%RC%"=="0" (
    echo RESULT: PASS
) else (
    echo RESULT: FAIL ^(exit %RC%^)
)
popd
exit /b %RC%

:dump
echo [2/2] htmlgen_dump.exe
cl %FLAGS% %INC% /Fo"%OBJ%\\" /Fe"%OBJ%\htmlgen_dump.exe" dump_main.cpp %GEN% "%OBJ%\md4c.obj" /link /SUBSYSTEM:CONSOLE >>"%OBJ%\build.log" 2>&1
if errorlevel 1 goto :buildfail
"%OBJ%\htmlgen_dump.exe" %2 %3 %4
set "RC=%ERRORLEVEL%"
popd
exit /b %RC%

:buildfail
echo.
echo BUILD FAILED - last 40 lines of "%OBJ%\build.log":
echo.
powershell -NoProfile -Command "Get-Content '%OBJ%\build.log' -Tail 40"
popd
exit /b 1
