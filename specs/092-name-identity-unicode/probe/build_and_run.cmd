@echo off
setlocal enabledelayedexpansion
::
:: build_and_run.cmd - feature 092, stage S3: builds obj\case_only_probe.exe
:: from case_only_probe.cpp and the product's src\common\salunicode.cpp (with
:: the saltests stand-in precomp.h and the product's /J), and runs it.
:: Exit code 0 = the new name identity agrees with NTFS for every pair.
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

pushd "%HERE%"
:: /J unsigned char, /RTC1, /Od, /MDd - the product's Debug switches
cl /nologo /J /RTC1 /Od /MDd /EHsc /W3 /D_CRT_SECURE_NO_WARNINGS /I"%ROOT%src\saltests" /I"%ROOT%src\common" /Fo"%OBJ%\\" /Fe"%OBJ%\case_only_probe.exe" case_only_probe.cpp "%ROOT%src\common\salunicode.cpp" /link user32.lib >"%OBJ%\build.log" 2>&1
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" type "%OBJ%\build.log"
popd
if not "%RC%"=="0" (
    echo BUILD FAILED
    exit /b %RC%
)

"%OBJ%\case_only_probe.exe"
exit /b %ERRORLEVEL%
