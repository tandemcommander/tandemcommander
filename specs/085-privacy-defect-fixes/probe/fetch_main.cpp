// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later
//
// fetch_main.cpp - feature 085 probe driver for MdFetchRemote
// (src/plugins/mdview/remotefetch.cpp), compiled together with that one file
// and nothing else. fetch_server.py starts a logging server and runs this exe
// with its base URL; for every path given it prints
//     <path> <ok|fail> <bytes>
// and the server-side log decides the rest (identification, cookies, ...).

#include <windows.h>

#include <stdio.h>
#include <string>
#include <vector>

#include "remotefetch.h"

int wmain(int argc, wchar_t** argv)
{
    if (argc < 3)
    {
        fwprintf(stderr, L"usage: fetch_probe <base-url> <path>...\n");
        return 2;
    }
    std::wstring base = argv[1];
    for (int i = 2; i < argc; i++)
    {
        std::vector<BYTE> out;
        bool ok = MdFetchRemote(base + argv[i], out);
        wprintf(L"%ls %ls %u\n", argv[i], ok ? L"ok" : L"fail", (unsigned)out.size());
    }
    return 0;
}
