@echo off
setlocal
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul
cd /d "%~dp0"
cl /nologo /W3 /EHsc /Fe:r2_dates.exe r2_dates.cpp >build_dates.log 2>&1
if errorlevel 1 (
  type build_dates.log
  exit /b 1
)
r2_dates.exe > r2_dates.txt
type r2_dates.txt
