@echo off
rem usage: b.cmd <source.cpp> [extra cl options]
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul
cd /d "%~dp0"
cl /nologo /W3 /EHsc /J /std:c++latest /D_CRT_SECURE_NO_WARNINGS %2 %3 %4 %5 %6 %1
