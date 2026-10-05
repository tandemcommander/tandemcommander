@echo off
rem Feature 117: builds m117_model.exe (offline model of the Verify read path) into %TEMP%\tc117_model
rem and runs it over fresh fixtures; prints the model's verdicts next to expected117.json's "after".
setlocal
set "HERE=%~dp0"
set "OUT=%TEMP%\tc117_model"
if exist "%OUT%" rmdir /s /q "%OUT%"
mkdir "%OUT%"
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
set "VS="
for /f "usebackq delims=" %%i in (`call "%%VSWHERE%%" -latest -property installationPath`) do set "VS=%%i"
if not defined VS (echo vswhere did not find Visual Studio & exit /b 1)
call "%VS%\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
cl /nologo /std:c++20 /EHsc /W4 /utf-8 /Fe"%OUT%\m117_model.exe" /Fo"%OUT%\\" "%HERE%m117_model.cpp" >"%OUT%\cl.log" || (type "%OUT%\cl.log" & exit /b 1)
python "%HERE%make_lists117.py" "%OUT%\fx" || exit /b 1
python "%HERE%run_model.py" "%OUT%\m117_model.exe" "%OUT%\fx"
exit /b %errorlevel%
