// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later
//
// fakespl.c - feature 087, task T025. Built as "7zip.spl" and loaded by
// 7zdrive.exe (-spl=<path>) before the engine. It stands in for the plugin's
// AddCallStackObject export, which the engine's thread trampoline
// (7za/C/Threads.c TC_7ZIP_PATCH -> 7za/spl/splthread.c) looks up by the module
// name "7zip.spl", and it watches every thread the process starts
// (DLL_THREAD_ATTACH, with the thread's start address).
//
// Verdict (SplReport): every thread whose start address is not in ntdll.dll
// (the system's own worker threads) must have entered AddCallStackObject. The
// driver itself starts no threads, so those threads are the engine's.

#include <windows.h>

#define MAX_THREADS 4096

typedef LONG(NTAPI* FNtQueryInformationThread)(HANDLE, int, PVOID, ULONG, PULONG);

static volatile LONG g_seen;            // threads attached after load
static DWORD g_seenTid[MAX_THREADS];    // their ids
static void* g_seenStart[MAX_THREADS];  // their start addresses
static volatile LONG g_wrapped;         // entries into AddCallStackObject
static DWORD g_wrappedTid[MAX_THREADS]; // their thread ids

typedef struct
{
    LPTHREAD_START_ROUTINE StartAddress;
    LPVOID Parameter;
} AddCallStackObjectParam;

__declspec(dllexport) unsigned __stdcall AddCallStackObject(void* param)
{
    AddCallStackObjectParam* p = (AddCallStackObjectParam*)param;
    LONG i = InterlockedIncrement(&g_wrapped) - 1;
    if (i < MAX_THREADS)
        g_wrappedTid[i] = GetCurrentThreadId();
    return (unsigned)p->StartAddress(p->Parameter);
}

static BOOL InModule(const char* name, void* addr)
{
    HMODULE m = GetModuleHandleA(name);
    IMAGE_DOS_HEADER* dos = (IMAGE_DOS_HEADER*)m;
    IMAGE_NT_HEADERS* nt;
    if (m == NULL)
        return FALSE;
    nt = (IMAGE_NT_HEADERS*)((BYTE*)m + dos->e_lfanew);
    return (BYTE*)addr >= (BYTE*)m && (BYTE*)addr < (BYTE*)m + nt->OptionalHeader.SizeOfImage;
}

// returns the number of engine threads that did NOT pass the trampoline
__declspec(dllexport) int __cdecl SplReport(int* engineThreads, int* wrapped, int* systemThreads)
{
    LONG seen = g_seen < MAX_THREADS ? g_seen : MAX_THREADS;
    LONG wr = g_wrapped < MAX_THREADS ? g_wrapped : MAX_THREADS;
    int engine = 0, system = 0, missing = 0;
    LONG i, j;
    for (i = 0; i < seen; i++)
    {
        BOOL found = FALSE;
        if (InModule("ntdll.dll", g_seenStart[i]))
        {
            system++;
            continue;
        }
        engine++;
        for (j = 0; j < wr && !found; j++)
            found = g_wrappedTid[j] == g_seenTid[i];
        if (!found)
            missing++;
    }
    *engineThreads = engine;
    *wrapped = (int)g_wrapped;
    *systemThreads = system;
    return missing;
}

BOOL WINAPI DllMain(HINSTANCE inst, DWORD reason, LPVOID reserved)
{
    (void)inst;
    (void)reserved;
    if (reason == DLL_THREAD_ATTACH)
    {
        static FNtQueryInformationThread query = NULL;
        void* start = NULL;
        LONG i;
        if (query == NULL)
            query = (FNtQueryInformationThread)GetProcAddress(GetModuleHandleA("ntdll.dll"),
                                                              "NtQueryInformationThread");
        if (query != NULL)
            query(GetCurrentThread(), 9 /* ThreadQuerySetWin32StartAddress */, &start, sizeof(start), NULL);
        i = InterlockedIncrement(&g_seen) - 1;
        if (i < MAX_THREADS)
        {
            g_seenTid[i] = GetCurrentThreadId();
            g_seenStart[i] = start;
        }
    }
    return TRUE;
}
