@echo off
rem Feature 077: ship the Visual C++ runtime application-locally.
rem
rem Usage: copy_vc_runtime.cmd <VS_INSTALL> <OUT_DIR>
rem
rem Copies the runtime libraries every shipped module imports from the
rem redistributable directory of the Visual Studio installation that built
rem the product into the root of the release output tree (next to
rem tandemcommander.exe). The redistributable version is read from the
rem toolchain's own Microsoft.VCRedistVersion.default.txt - the same file
rem VsDevCmd.bat uses for VCToolsRedistDir - so the shipped runtime can never
rem be older than the compiler. No absolute path is consulted.
rem
rem Exit code 0 on success (prints one summary line), 1 on any failure
rem (prints "ERROR: Visual C++ runtime not found: <path>" plus a hint).
rem Contract: specs\077-fix-antivirus-findings\contracts\runtime-deployment.md

setlocal enabledelayedexpansion

set "VS_INSTALL=%~1"
set "OUT_DIR=%~2"
if "%VS_INSTALL%"=="" (
    echo ERROR: copy_vc_runtime.cmd: missing ^<VS_INSTALL^> argument
    exit /b 1
)
if "%OUT_DIR%"=="" (
    echo ERROR: copy_vc_runtime.cmd: missing ^<OUT_DIR^> argument
    exit /b 1
)
if not exist "%OUT_DIR%\" (
    echo ERROR: copy_vc_runtime.cmd: output tree not found: %OUT_DIR%
    exit /b 1
)

set "VER_FILE=%VS_INSTALL%\VC\Auxiliary\Build\Microsoft.VCRedistVersion.default.txt"
if not exist "%VER_FILE%" (
    echo ERROR: Visual C++ runtime not found: %VER_FILE%
    goto :hint
)
set "REDIST_VER="
for /f "usebackq delims=" %%v in ("%VER_FILE%") do if not defined REDIST_VER set "REDIST_VER=%%v"
if not defined REDIST_VER (
    echo ERROR: Visual C++ runtime not found: %VER_FILE% is empty
    goto :hint
)

set "CRT_DIR=%VS_INSTALL%\VC\Redist\MSVC\%REDIST_VER%\x64\Microsoft.VC143.CRT"
if not exist "%CRT_DIR%\" (
    echo ERROR: Visual C++ runtime not found: %CRT_DIR%
    goto :hint
)

rem Fixed list; tools\check_runtime_deps.py proves after every Release build
rem that it covers every runtime import of every shipped module.
set "RUNTIME_FILES=vcruntime140.dll vcruntime140_1.dll msvcp140.dll concrt140.dll"
set "COPIED=0"
for %%f in (%RUNTIME_FILES%) do (
    if not exist "%CRT_DIR%\%%f" (
        echo ERROR: Visual C++ runtime not found: %CRT_DIR%\%%f
        goto :hint
    )
    copy /y "%CRT_DIR%\%%f" "%OUT_DIR%\%%f" >nul
    if errorlevel 1 (
        echo ERROR: Visual C++ runtime: failed to copy %%f into %OUT_DIR%
        exit /b 1
    )
    set /a COPIED+=1
)
echo   Visual C++ runtime %REDIST_VER%: %COPIED% file(s) copied from %CRT_DIR%
exit /b 0

:hint
echo   The release tree must ship the Visual C++ runtime (feature 077). Install the
echo   "C++ 2022 Redistributable Update" component of the "Desktop development
echo   with C++" workload in Visual Studio 2022, or repair the installation.
exit /b 1
