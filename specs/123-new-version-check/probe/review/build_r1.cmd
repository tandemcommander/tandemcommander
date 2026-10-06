@echo off
rem Review probe for feature 123 - builds and runs r1_probe.exe (stand-alone, no product code)
setlocal
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul
cd /d "%~dp0"
cl /nologo /W3 /EHsc /Fe:r1_probe.exe r1_probe.cpp >build_r1.log 2>&1
if errorlevel 1 (
  type build_r1.log
  exit /b 1
)
r1_probe.exe focus
r1_probe.exe static
r1_probe.exe cancel
