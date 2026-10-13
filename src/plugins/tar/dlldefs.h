// SPDX-FileCopyrightText: 2023 Open Salamander Authors
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

typedef unsigned int uint32_t;
typedef unsigned short uint16_t;
typedef signed int int32_t;
typedef signed short int16_t;

// general Salamander interface - valid from plugin start until its termination
extern CSalamanderGeneralAbstract* SalamanderGeneral;

// interface for convenient work with files
extern CSalamanderSafeFileAbstract* SalamanderSafeFile;

char* LoadStr(int resID);
// feature 130: the text as UTF-8 (valid until the plug-in unloads) - for a sentence that
// holds a file name or GetErrorText(), which are UTF-8
const char* LoadStrU8(int resID);

// UTF-8: the resource text and the Windows error text (feature 130)
char* LoadErr(int resID, DWORD LastError);

// interface 104: paths crossing the plugin interface are UTF-8, so file APIs must
// be called through their W variants with the \\?\ prefix (see splunicode.h)
HANDLE CreateFileU8(const char* name, DWORD access, DWORD share, DWORD disposition, DWORD flags);
BOOL DeleteFileU8(const char* name);
BOOL SetFileAttributesU8(const char* name, DWORD attrs);

// format boundary (interface 104): decodes a name read from an archive/stream header
// to UTF-8 in place (reallocates 'name'); see the definition in tardll.cpp
BOOL ConvertNameToU8(char*& name);
