@echo off
rem Review 2 probes for feature 123 - stand-alone, no product code
setlocal
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul
cd /d "%~dp0"
cl /nologo /W3 /EHsc /Fe:r2_http.exe r2_http.cpp >build_r2.log 2>&1
if errorlevel 1 (
  type build_r2.log
  exit /b 1
)
if exist r2_dlg.cpp (
  cl /nologo /W3 /EHsc /Fe:r2_dlg.exe r2_dlg.cpp user32.lib gdi32.lib >build_r2dlg.log 2>&1
  if errorlevel 1 (
    type build_r2dlg.log
    exit /b 1
  )
  cl /nologo /W3 /EHsc /DR2_COMCTL6 /Fe:r2_dlg6.exe /Fo:r2_dlg6.obj r2_dlg.cpp user32.lib gdi32.lib >build_r2dlg6.log 2>&1
  if errorlevel 1 (
    type build_r2dlg6.log
    exit /b 1
  )
)
echo built
