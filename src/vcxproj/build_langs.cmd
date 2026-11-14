@echo off
setlocal enabledelayedexpansion

:: build_langs.cmd - build the shipped .slg language modules (feature 038)
::
:: Usage (from the repository root or this directory):
::   build_langs.cmd                          Build every enabled module in every
::                                            registered language
::   build_langs.cmd --export-templates       Export a current-structure English
::                                            .slt template per module (stage 1)
::   build_langs.cmd --module sftp            Restrict to one module
::   build_langs.cmd --language czech         Restrict to one language
::   build_langs.cmd release                  Operate on the Release_x64 output
::   build_langs.cmd portable                 Operate on the portable output
::                                            (<Config>_x64_portable, feature 428)
::
:: Requires english.slg to exist, i.e. run build.cmd first.
::
:: The work is done by build_langs.ps1 -- this file only resolves paths and
:: locates MSBuild (needed once, to build translator.exe, which a normal
:: solution build does not produce). See
:: specs/038-translations-build-integration/quickstart.md

set "BUILD_CONFIG=Debug"
set "BUILD_PLATFORM=x64"
set "OUT_SUFFIX="
set "PS_ARGS="

for %%a in (%*) do (
    if /i "%%~a"=="release" (
        set "BUILD_CONFIG=Release"
    ) else if /i "%%~a"=="debug" (
        set "BUILD_CONFIG=Debug"
    ) else if /i "%%~a"=="portable" (
        set "OUT_SUFFIX=_portable"
    ) else if /i "%%~a"=="--export-templates" (
        set "PS_ARGS=!PS_ARGS! -ExportTemplates"
    ) else if /i "%%~a"=="--check-layout" (
        set "PS_ARGS=!PS_ARGS! -CheckLayout"
    ) else if /i "%%~a"=="--force" (
        set "PS_ARGS=!PS_ARGS! -Force"
    ) else if /i "%%~a"=="help" (
        goto :show_help
    ) else if /i "%%~a"=="/?" (
        goto :show_help
    ) else (
        set "PENDING=%%~a"
    )
)

:: --module / --language take a value, so re-scan pairwise
set "NEXT_IS="
for %%a in (%*) do (
    if defined NEXT_IS (
        set "PS_ARGS=!PS_ARGS! -!NEXT_IS! %%~a"
        set "NEXT_IS="
    ) else (
        if /i "%%~a"=="--module" set "NEXT_IS=Module"
        if /i "%%~a"=="--language" set "NEXT_IS=Language"
    )
)
if defined NEXT_IS (
    echo ERROR: --module and --language require a value.
    exit /b 1
)

:: Repository root is two levels above src\vcxproj\
for %%i in ("%~dp0..\..") do set "REPO_ROOT=%%~fi"

if not defined OPENSAL_BUILD_DIR (
    set "OPENSAL_BUILD_DIR=%REPO_ROOT%\build\"
    echo NOTE: OPENSAL_BUILD_DIR not set, defaulting to !OPENSAL_BUILD_DIR!
)

set "OUT_DIR=%OPENSAL_BUILD_DIR%tandemcommander\%BUILD_CONFIG%_%BUILD_PLATFORM%%OUT_SUFFIX%"

if not exist "%OUT_DIR%" (
    echo ERROR: build output not found: %OUT_DIR%
    echo        Run build.cmd first -- english.slg must exist before language
    echo        modules can be produced from it.
    exit /b 1
)

:: Locate MSBuild so build_langs.ps1 can build translator.exe on first use.
:: translator has no .Build.0 entry for Debug^|x64 or Release^|x64 in
:: salamand.sln -- it only builds under the "Utils (Release)" configuration --
:: so a normal build.cmd run never produces it.
set "MSBUILD_PATH="
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if exist "%VSWHERE%" (
    set "VS_TMP=%TEMP%\opensal_vs_langs.txt"
    "%VSWHERE%" -latest -version "[17.0,18.0)" -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath > "!VS_TMP!" 2>nul
    if exist "!VS_TMP!" (
        set /p VS_INSTALL=<"!VS_TMP!"
        del "!VS_TMP!" >nul 2>&1
    )
    if defined VS_INSTALL (
        if exist "!VS_INSTALL!\Msbuild\Current\Bin\MSBuild.exe" set "MSBUILD_PATH=!VS_INSTALL!\Msbuild\Current\Bin\MSBuild.exe"
    )
)

:: Paths go through the environment rather than the command line: "powershell
:: -File" strips quoting from arguments containing spaces, and the default VS
:: install path always has them.
set "NEWTC_REPO_ROOT=%REPO_ROOT%"
set "NEWTC_OUT_DIR=%OUT_DIR%"
set "NEWTC_BUILD_DIR=%OPENSAL_BUILD_DIR%"
set "NEWTC_MSBUILD=%MSBUILD_PATH%"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_langs.ps1" %PS_ARGS%

exit /b %ERRORLEVEL%

:show_help
echo.
echo build_langs.cmd - build .slg language modules from translations\*.slt
echo.
echo   build_langs.cmd                     all enabled modules, all languages
echo   build_langs.cmd --export-templates  export English .slt templates (stage 1)
echo   build_langs.cmd --module ^<name^>     restrict to one module
echo   build_langs.cmd --language ^<name^>   restrict to one language
echo   build_langs.cmd --check-layout      also run the layout validator (slow:
echo                                       every finding costs a 30s timeout)
echo   build_langs.cmd --force             rebuild even if up to date
echo   build_langs.cmd release             use the Release_x64 output
echo   build_langs.cmd portable            use the portable output ^(feature 428^)
echo.
echo Run build.cmd first: english.slg is the source every language module is
echo copied from.
echo.
exit /b 0
