@echo off
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul
cd /d "%~dp0"
cl /nologo /EHsc /std:c++20 /MT /I E:\Projects\tandemcommander\src\common\dep\webview2\include wv2dpi.cpp /link E:\Projects\tandemcommander\src\common\dep\webview2\lib\x64\WebView2LoaderStatic.lib user32.lib ole32.lib advapi32.lib shell32.lib version.lib
