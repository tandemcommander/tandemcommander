// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salbugreport.h
//
// Crash report file name - the pure part (feature 079-remove-salmon-crash-reporter).
//
// Since feature 079 the application names and writes its crash report
// itself (the former out-of-process helper salmon.exe is gone). The name
// carries the product version and the local time of the crash:
//
//   TC<shortVersion>-YYYYMMDD-HHMMSS[-suffix].TXT      e.g. TC018X64-20260919-143007.TXT
//
// 'shortVersion' is VERSINFO_SAL_SHORT_VERSION (digits of the version plus
// the platform tag), 'suffix' 1..99 resolves a collision within the same
// second (0 = no suffix). The output is upper-case ASCII, so it never
// contains a character that is illegal in a file name.
//
// This function runs inside the top-level exception filter of a process
// that is crashing: it calls no CRT and no user32 function (digits are
// written by hand) and touches nothing but its arguments.
//
// Returns FALSE (and an empty 'out' when outLen > 0) when the name does not
// fit into 'out' (outLen counts the terminating zero), when 'suffix' is
// outside 0..99, when 'shortVersion' is empty or contains a character
// outside A-Z a-z 0-9, or when a date/time field of 't' is out of range.
//
//*****************************************************************************

BOOL SalFormatBugReportName(WCHAR* out, int outLen, const char* shortVersion, const SYSTEMTIME& t, int suffix);
