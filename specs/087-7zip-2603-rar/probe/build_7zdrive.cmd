@echo off
setlocal enabledelayedexpansion
::
:: build_7zdrive.cmd [<7-Zip tree root>] - feature 087: builds obj\7zdrive.exe
:: against the interface headers of a 7-Zip source tree (default: the vendored
:: src\plugins\7zip\7za). No 7-Zip .cpp is linked; the exe drives any 7za.dll
:: with the same binary interface (16.04 or 26.03).
::
:: The toolchain block is the one from tests\mdview_htmlgen_test\build_and_run.cmd.

set "HERE=%~dp0"
set "ROOT=%HERE%..\..\..\"
set "OBJ=%HERE%obj"
set "TREE=%~1"
if "%TREE%"=="" set "TREE=%ROOT%src\plugins\7zip\7za"

if defined VSCMD_ARG_TGT_ARCH if /i "%VSCMD_ARG_TGT_ARCH%"=="x64" goto :have_cl
set "VSWHERE="
if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not defined VSWHERE (
    echo ERROR: vswhere.exe not found - is Visual Studio 2022 installed?
    exit /b 1
)
set "VS_TMP=%TEMP%\7zdrive087_vs.txt"
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
cl /nologo /EHsc /std:c++17 /W3 /MD /O2 /DUNICODE /D_UNICODE /I"%TREE%\CPP" /Fo"%OBJ%\\" /Fe"%OBJ%\7zdrive.exe" 7zdrive.cpp /link ole32.lib oleaut32.lib >"%OBJ%\build.log" 2>&1
set "RC=%ERRORLEVEL%"
:: the stand-in "7zip.spl" for the thread-trampoline check (task T025)
if "%RC%"=="0" (
    if not exist "%OBJ%\spl" mkdir "%OBJ%\spl"
    cl /nologo /W3 /MD /O2 /LD /Fo"%OBJ%\spl\\" /Fe"%OBJ%\spl\7zip.spl" fakespl.c >>"%OBJ%\build.log" 2>&1
    set "RC=!ERRORLEVEL!"
)
if not "%RC%"=="0" type "%OBJ%\build.log"
popd
if "%RC%"=="0" (echo built %OBJ%\7zdrive.exe) else (echo BUILD FAILED)
exit /b %RC%
