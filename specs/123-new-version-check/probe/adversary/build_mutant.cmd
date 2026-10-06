@echo off
rem Builds the harness against a deliberately broken copy of the header: build_mutant.cmd <directory with salupdcheck.h>
setlocal
cd /d "%~dp0"
if not defined VSCMD_VER call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul
if errorlevel 1 exit /b 1
set M=%~1
set COMMON=/nologo /std:c++latest /W4 /EHsc /D_CRT_SECURE_NO_WARNINGS /DADV_MUTANT /I"%M%" adv_harness.cpp
cl %COMMON% /Od /J /MTd /fsanitize=address /Fo"%M%\asan.obj" /Fe"%M%\adv_asan.exe" >"%M%\build.log" 2>&1 || exit /b 1
cl %COMMON% /O2 /J /MT /Fo"%M%\o2.obj" /Fe"%M%\adv_o2.exe" >>"%M%\build.log" 2>&1 || exit /b 1
copy /y bin\clang_rt.asan_dynamic-x86_64.dll "%M%\" >nul
exit /b 0
