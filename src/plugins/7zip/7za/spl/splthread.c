// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

//
// This is a modification for the Tandem Commander 7-Zip plugin: every thread
// the engine starts (C/Threads.c, TC_7ZIP_PATCH) runs its body through the
// plugin's call-stack tracking, so a crash in an engine thread is reported with
// a call stack. Feature 087: no longer includes the removed spl/StdAfx.h and
// names the module explicitly in ANSI (the 26.03 engine is built as UNICODE).
//

#include <windows.h>

typedef struct
{
    LPTHREAD_START_ROUTINE StartAddress;
    LPVOID Parameter;
} AddCallStackObjectParam;

typedef unsigned(__stdcall* FThreadBody)(void*);

DWORD RunThreadWithCallStackObject(LPTHREAD_START_ROUTINE startAddress, LPVOID parameter)
{
    HMODULE module = NULL;
    FThreadBody addCallStackObject = NULL;

    if ((module = GetModuleHandleA("7zip.spl")) != NULL &&
        (addCallStackObject = (FThreadBody)GetProcAddress(module, "AddCallStackObject")) != NULL)
    {
        // successfully obtained AddCallStackObject from 7zip.spl
        AddCallStackObjectParam p;
        p.StartAddress = startAddress;
        p.Parameter = parameter;

        return addCallStackObject(&p);
    }
    else
    {
        // the plugin is not loaded (e.g. the engine driven by a test program):
        // run the thread body directly
        return startAddress(parameter);
    }
}
