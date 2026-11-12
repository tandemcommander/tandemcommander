// Experiment for backlog item remove-indentation-for-text-viewers (GitHub #29):
// which --embedded-browser-webview-dpi-awareness does WebView2 give the browser process
// when a SYSTEM-aware process creates the environment from a thread whose DPI awareness
// context is per-monitor v2?  argv[1] = "system" (no thread change) or "pmv2".
#include <windows.h>
#include <wrl.h>
#include <stdio.h>
#include "WebView2.h"
using namespace Microsoft::WRL;

static HWND g_wnd;
static ComPtr<ICoreWebView2Controller> g_ctl;

int wmain(int argc, wchar_t** argv)
{
    SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_SYSTEM_AWARE); // as the product's manifest
    bool pm = argc > 1 && (wcscmp(argv[1], L"pmv2") == 0 || wcscmp(argv[1], L"scoped") == 0);
    bool scoped = argc > 1 && wcscmp(argv[1], L"scoped") == 0;
    DPI_AWARENESS_CONTEXT old = NULL;
    if (pm)
        old = SetThreadDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
    WNDCLASSW wc = {};
    wc.lpfnWndProc = DefWindowProcW;
    wc.hInstance = GetModuleHandleW(NULL);
    wc.lpszClassName = L"wv2dpi";
    RegisterClassW(&wc);
    g_wnd = CreateWindowExW(0, L"wv2dpi", L"wv2dpi", WS_OVERLAPPEDWINDOW, 0, 0, 400, 300, NULL, NULL, wc.hInstance, NULL);
    wprintf(L"pid %lu mode %s window awareness %d\n", GetCurrentProcessId(), scoped ? L"scoped" : pm ? L"pmv2" : L"system",
            (int)GetAwarenessFromDpiAwarenessContext(GetWindowDpiAwarenessContext(g_wnd)));
    fflush(stdout);
    wchar_t udf[MAX_PATH];
    GetEnvironmentVariableW(L"TEMP", udf, MAX_PATH);
    wcscat_s(udf, scoped ? L"\\tc29m\\udf_sc" : pm ? L"\\tc29m\\udf_pm" : L"\\tc29m\\udf_sys");
    HRESULT hr = CreateCoreWebView2EnvironmentWithOptions(
        NULL, udf, NULL,
        Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
            [](HRESULT r, ICoreWebView2Environment* env) -> HRESULT
            {
                wprintf(L"environment 0x%08lX\n", (unsigned long)r);
                fflush(stdout);
                if (env)
                    env->CreateCoreWebView2Controller(
                        g_wnd, Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
                                   [](HRESULT r2, ICoreWebView2Controller* c) -> HRESULT
                                   {
                                       wprintf(L"controller 0x%08lX\n", (unsigned long)r2);
                                       fflush(stdout);
                                       g_ctl = c;
                                       return S_OK;
                                   })
                                   .Get());
                return S_OK;
            })
            .Get());
    if (scoped)
        SetThreadDpiAwarenessContext(old);
    wprintf(L"create 0x%08lX thread awareness now %d\n", (unsigned long)hr,
            (int)GetAwarenessFromDpiAwarenessContext(GetThreadDpiAwarenessContext()));
    fflush(stdout);
    ULONGLONG end = GetTickCount64() + 12000;
    MSG msg;
    while (GetTickCount64() < end)
    {
        while (PeekMessageW(&msg, NULL, 0, 0, PM_REMOVE))
        {
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }
        Sleep(20);
    }
    if (g_ctl)
        g_ctl->Close();
    g_ctl.Reset();
    DestroyWindow(g_wnd);
    return 0;
}
