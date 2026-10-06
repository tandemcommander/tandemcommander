@echo off
setlocal enabledelayedexpansion
::
:: build_and_run.cmd - feature 120: builds pixharness.exe from PictView's own engine and reader
:: sources twice - "new" from the working tree, "old" from git revision %1 (default HEAD) - and
:: runs pixref.py, which makes the fixtures with Pillow, runs both programs and compares every
:: pipette value and every histogram count with Pillow's.
::
:: Outputs under %TEMP%\tc120\pixharness (never in the repository).
:: Exit code: pixref.py's (0 = the new build matches Pillow everywhere).
::
:: Usage:  build_and_run.cmd [old-revision]
::
set "HERE=%~dp0"
set "ROOT=%HERE%..\..\..\..\"
set "PV=%ROOT%src\plugins\pictview"
set "OUT=%TEMP%\tc120\pixharness"
set "REV=%~1"
if "%REV%"=="" set "REV=HEAD"

if defined VSCMD_ARG_TGT_ARCH if /i "%VSCMD_ARG_TGT_ARCH%"=="x64" goto :have_cl
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "!VSWHERE!" (
    echo ERROR: vswhere.exe not found
    exit /b 1
)
set "VS_TMP=%TEMP%\tc120_vs.txt"
"!VSWHERE!" -latest -version "[17.0,18.0)" -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath > "!VS_TMP!" 2>nul
set /p VSPATH=<"!VS_TMP!"
del "!VS_TMP!" >nul 2>&1
call "!VSPATH!\VC\Auxiliary\Build\vcvarsall.bat" x64 >nul 2>&1
:have_cl

if exist "%OUT%" rmdir /s /q "%OUT%"
mkdir "%OUT%\new" "%OUT%\old\src" || exit /b 1

:: the build before: its engine and reader, beside the working tree's headers (the include
:: directories of the plug-in resolve everything else; "wicengine.h" is found next to the copy first)
pushd "%ROOT%"
git show "%REV%:src/plugins/pictview/PixelAccess.cpp" > "%OUT%\old\src\PixelAccess.cpp" || (popd & exit /b 1)
git show "%REV%:src/plugins/pictview/wicengine.cpp" > "%OUT%\old\src\wicengine.cpp" || (popd & exit /b 1)
git show "%REV%:src/plugins/pictview/wicengine.h" > "%OUT%\old\src\wicengine.h" || (popd & exit /b 1)
popd

:: the plug-in's Release settings (plugin_base.props + plugin_release.props + pictview.vcxproj),
:: without the precompiled header and the plug-in's DLL entry
set "CFLAGS=/nologo /c /O2 /W3 /EHsc /MD /J /std:c++latest /D NDEBUG /D WIN32 /D _WINDOWS /D _WIN64 /D _MT /D WINVER=0x0601 /D _WIN32_WINNT=0x0601 /D _WIN32_IE=0x0800 /D _CRT_SECURE_NO_WARNINGS /D _SCL_SECURE_NO_WARNINGS /D ENABLE_PROPERTYDIALOG /I "%PV%" /I "%PV%\exif" /I "%PV%\exif\libexif" /I "%ROOT%src\plugins\shared""
set "LIBS=ole32.lib oleaut32.lib user32.lib gdi32.lib shell32.lib comdlg32.lib advapi32.lib"

cl %CFLAGS% /Fo"%OUT%\new\\" "%HERE%pixharness.cpp" "%PV%\PixelAccess.cpp" "%PV%\wicengine.cpp" > "%OUT%\new\build.log" 2>&1 || (type "%OUT%\new\build.log" & exit /b 1)
link /nologo /OUT:"%OUT%\new\pixharness.exe" "%OUT%\new\*.obj" %LIBS% >> "%OUT%\new\build.log" 2>&1 || (type "%OUT%\new\build.log" & exit /b 1)

mkdir "%OUT%\old\obj"
cl %CFLAGS% /Fo"%OUT%\old\obj\\" "%HERE%pixharness.cpp" "%OUT%\old\src\PixelAccess.cpp" "%OUT%\old\src\wicengine.cpp" > "%OUT%\old\build.log" 2>&1 || (type "%OUT%\old\build.log" & exit /b 1)
link /nologo /OUT:"%OUT%\old\pixharness.exe" "%OUT%\old\obj\*.obj" %LIBS% >> "%OUT%\old\build.log" 2>&1 || (type "%OUT%\old\build.log" & exit /b 1)

python "%HERE%pixref.py" "%OUT%" "%OUT%\new\pixharness.exe" "%OUT%\old\pixharness.exe"
exit /b %ERRORLEVEL%
