// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salpath.h
//
// Dynamic UTF-8 path buffer and extended-length path normalization.
//
// Paths held by the application are UTF-8 in "display form" (no \\?\
// prefix; C:\... or \\server\share\...). The \\?\ prefix is applied
// only at the OS boundary by SalPathToWExtAlloc and never surfaces in
// the UI or persisted data (feature 004-long-paths-unicode, R2).
//

// maximum path length accepted by W APIs with the \\?\ prefix (WCHARs)
#define SAL_MAX_PATH_W 32767
// worst-case UTF-8 byte length of such a path (3 bytes per UTF-16 unit) + null
// (also defined for plugins in src/plugins/shared/spl_base.h - same value)
#ifndef SAL_MAX_PATH_UTF8
#define SAL_MAX_PATH_UTF8 (3 * SAL_MAX_PATH_W + 1)
#endif

//*****************************************************************************
//
// CSalPathBuf
//
// Growable heap-backed UTF-8 path string replacing fixed
// char[MAX_PATH] buffers on migrated code paths (data-model.md §1).
// All methods keep the buffer null-terminated. On allocation failure
// methods return FALSE and leave the previous value intact.
//

class CSalPathBuf
{
protected:
    char* Buffer;   // null-terminated UTF-8; never NULL after construction
    int Len;        // strlen(Buffer)
    int Capacity;   // allocated bytes
    char Inline[8]; // empty-string storage before first allocation

public:
    CSalPathBuf();
    CSalPathBuf(const CSalPathBuf& other);
    ~CSalPathBuf();
    CSalPathBuf& operator=(const CSalPathBuf& other);

    const char* Get() const { return Buffer; }
    int Length() const { return Len; }
    BOOL IsEmpty() const { return Len == 0; }
    void Clear();

    BOOL Set(const char* path);          // replace content
    BOOL Set(const char* path, int len); // replace content (len bytes)
    BOOL Append(const char* text);       // raw append, no separator logic

    // append one component: ensures exactly one backslash separator
    // (mirrors SalPathAppend semantics, without any length cap)
    BOOL AppendComponent(const char* name);

    BOOL AddBackslash();   // ensure trailing backslash
    void StripBackslash(); // remove trailing backslash (keeps "C:\" root)

    // remove the last path component; FALSE when already at a root
    BOOL CutLastComponent();

    BOOL Reserve(int bytes); // pre-allocate capacity (content preserved)
};

//*****************************************************************************
//
// SalPathToWExtAlloc
//
// Convert a UTF-8 display-form path to a heap-allocated UTF-16
// extended-length path ready for W file APIs:
//   C:\dir\file            -> \\?\C:\dir\file
//   \\server\share\file    -> \\?\UNC\server\share\file
//   already \\?\-prefixed  -> converted as-is
//   relative               -> resolved against the current directory first
// "." and ".." segments are collapsed and forward slashes converted
// before prefixing (\\?\ paths bypass the OS normalization, so it is
// done here - research.md R2 consequences).
//
// Return Values
//   Heap UTF-16 string (caller frees with free()), or NULL when the
//   input is not convertible or the result would exceed SAL_MAX_PATH_W.
//
WCHAR* SalPathToWExtAlloc(const char* u8path);

//*****************************************************************************
//
// SalPathFromWAlloc
//
// Convert a UTF-16 path from the OS back to a heap-allocated UTF-8
// display-form path, stripping any \\?\ / \\?\UNC\ prefix.
// Caller frees with free(). Returns NULL on conversion failure.
//
char* SalPathFromWAlloc(const WCHAR* wpath);
