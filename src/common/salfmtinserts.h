// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salfmtinserts.h
//
// Feature 180: the text of a system error by FormatMessage, also when the text has inserts.
//
// FormatMessage(FORMAT_MESSAGE_FROM_SYSTEM) without arguments fails (ERROR_INVALID_PARAMETER) for
// every system text with an insert - 193 "%1 is not a valid Win32 application.", 216, 34 ... - and
// the program then showed "System error 193, text description is not available.". The arguments
// below give every insert (%1 ... %99) the text "..." - not FORMAT_MESSAGE_IGNORE_INSERTS, which
// would leave a '%' in a text that callers put into messages and formats. An insert with a numeric
// format (%1!d!) prints a number instead; nothing reads past the array. The narrow texts end in
// three zero bytes, so a wide string format (%1!ws!) of the A function stops there too.
//
// Use: FormatMessageW(SAL_FM_SYSTEM_FLAGS, NULL, error, lang, buf, size, SalFmInsertsW());
// Header-only (the core and the plug-ins).
//
//*****************************************************************************

#include <windows.h>
#include <stdarg.h>

#define SAL_FM_SYSTEM_FLAGS (FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_ARGUMENT_ARRAY)

#define SAL_FM_INS10(s) s, s, s, s, s, s, s, s, s, s

inline va_list* SalFmInsertsW()
{
    static const WCHAR* const inserts[99] = {
        SAL_FM_INS10(L"..."), SAL_FM_INS10(L"..."), SAL_FM_INS10(L"..."), SAL_FM_INS10(L"..."),
        SAL_FM_INS10(L"..."), SAL_FM_INS10(L"..."), SAL_FM_INS10(L"..."), SAL_FM_INS10(L"..."),
        SAL_FM_INS10(L"..."), L"...", L"...", L"...", L"...", L"...", L"...", L"...", L"...", L"..."};
    return (va_list*)inserts;
}

inline va_list* SalFmInsertsA()
{
    static const char* const inserts[99] = {
        SAL_FM_INS10("...\0\0"), SAL_FM_INS10("...\0\0"), SAL_FM_INS10("...\0\0"), SAL_FM_INS10("...\0\0"),
        SAL_FM_INS10("...\0\0"), SAL_FM_INS10("...\0\0"), SAL_FM_INS10("...\0\0"), SAL_FM_INS10("...\0\0"),
        SAL_FM_INS10("...\0\0"), "...\0\0", "...\0\0", "...\0\0", "...\0\0", "...\0\0", "...\0\0", "...\0\0", "...\0\0", "...\0\0"};
    return (va_list*)inserts;
}

#undef SAL_FM_INS10

// the array matching FormatMessage (A or W by UNICODE)
#ifdef UNICODE
#define SalFmInserts SalFmInsertsW
#else
#define SalFmInserts SalFmInsertsA
#endif
