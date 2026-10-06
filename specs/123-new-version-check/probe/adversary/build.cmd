@echo off
rem Builds the adversarial harness in five variants into bin\ (see README.md).
setlocal
cd /d "%~dp0"
if not defined VSCMD_VER call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul
if errorlevel 1 exit /b 1
if not exist bin mkdir bin
if not exist obj mkdir obj
set COMMON=/nologo /std:c++latest /W4 /WX- /Zi /EHsc /D_CRT_SECURE_NO_WARNINGS adv_harness.cpp

echo === rtc_J: /Od /RTC1 /RTCc /J (the product's Debug flags)
cl %COMMON% /Od /RTC1 /RTCc /J /MTd /Foobj\rtc_J.obj /Fdobj\rtc_J.pdb /Febin\adv_rtc_J.exe || exit /b 1
echo === rtc_noJ: /Od /RTC1 /RTCc, char signed
cl %COMMON% /Od /RTC1 /RTCc /MTd /Foobj\rtc_noJ.obj /Fdobj\rtc_noJ.pdb /Febin\adv_rtc_noJ.exe || exit /b 1
echo === o2_J: /O2 /J (the product's Release flags, without LTO)
cl %COMMON% /O2 /J /MT /Foobj\o2_J.obj /Fdobj\o2_J.pdb /Febin\adv_o2_J.exe || exit /b 1
echo === asan_J: AddressSanitizer /J
cl %COMMON% /Od /J /MTd /fsanitize=address /Foobj\asan_J.obj /Fdobj\asan_J.pdb /Febin\adv_asan_J.exe || exit /b 1
echo === asan_noJ: AddressSanitizer, char signed
cl %COMMON% /Od /MTd /fsanitize=address /Foobj\asan_noJ.obj /Fdobj\asan_noJ.pdb /Febin\adv_asan_noJ.exe || exit /b 1
rem the AddressSanitizer run-time must sit next to the executables
copy /y "%VCToolsInstallDir%bin\Hostx64\x64\clang_rt.asan_dynamic-x86_64.dll" bin\ >nul || exit /b 1
echo BUILD OK
exit /b 0
