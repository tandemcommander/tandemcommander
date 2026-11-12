@echo off
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul
cd /d "%~dp0"
cl /nologo /EHsc /std:c++20 /Fe:"%TEMP%\menutest424.exe" /Fo:"%TEMP%\menutest424.obj" menutest.cpp /link user32.lib
