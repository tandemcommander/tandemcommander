// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

// feature 102: the pure parts of the channel between fcremote.exe and the File Comparator
// plug-in (version 2, see remotmsg.h) - header-only and free of the C runtime, because
// fcremote.exe has none (only kernel32 and the Win32 heap); used by fcremote.exe, by the
// plug-in and by saltests.

#pragma once

#include <windows.h>

inline BOOL FcIsArgSpaceW(WCHAR c) { return c == L' ' || c == L'\t'; }

// Splits a command line into arguments - the rules of version 1's MakeArgv, kept as they were,
// only on UTF-16 text (version 1 split the code-page command line, which best-fit maps names:
// U+00E0 became 'a', a fullwidth quote became '"' and split or merged arguments):
//   - arguments are separated by runs of spaces and tabs;
//   - a '"' starts a quoted part that runs to the next '"' (or to the end of the line); the
//     spaces and tabs inside it belong to the argument; every '"' is removed;
//   - there is no escape character: a backslash is an ordinary character ("C:\dir\" is the
//     folder C:\dir\);
//   - the first argument is the program itself; more than 'maxarg' arguments is an error.
// Fixed on the way: an unterminated quote made version 1 step over the terminating zero and
// read past the end of the command line; every argument was cut to 259 bytes.
// On success 'argv[0..argc-1]' are HeapAlloc'ed strings (FcFreeArgsW); on failure (too many
// arguments, low memory) nothing stays allocated and 'argc' is 0.
inline void FcFreeArgsW(WCHAR** argv, int& argc)
{
    int i;
    for (i = 0; i < argc; i++)
        HeapFree(GetProcessHeap(), 0, argv[i]);
    argc = 0;
}

inline BOOL FcSplitArgsW(const WCHAR* commandLine, WCHAR** argv, int& argc, int maxarg)
{
    argc = 0;
    const WCHAR* start = commandLine;
    while (*start)
    {
        // trim the whitespace at the beginning
        while (*start && FcIsArgSpaceW(*start))
            start++;
        if (!*start)
            break;
        if (argc >= maxarg)
        {
            FcFreeArgsW(argv, argc);
            return FALSE;
        }
        const WCHAR* end = start;
        // find the end of the token
        while (*end && !FcIsArgSpaceW(*end))
        {
            if (*end++ == L'"')
            {
                while (*end && *end != L'"')
                    end++;
                if (*end) // the closing quote
                    end++;
            }
        }
        // add the token without the quotes
        WCHAR* arg = (WCHAR*)HeapAlloc(GetProcessHeap(), 0, ((SIZE_T)(end - start) + 1) * sizeof(WCHAR));
        if (arg == NULL)
        {
            FcFreeArgsW(argv, argc);
            return FALSE;
        }
        int d = 0;
        const WCHAR* s;
        for (s = start; s < end; s++)
        {
            if (*s != L'"')
                arg[d++] = *s;
        }
        arg[d] = 0;
        argv[argc++] = arg;
        start = end;
    }
    return TRUE;
}

inline BOOL FcIsSlashW(WCHAR c) { return c == L'\\' || c == L'/'; }

inline BOOL FcIsDriveW(const WCHAR* s)
{
    return ((s[0] >= L'A' && s[0] <= L'Z') || (s[0] >= L'a' && s[0] <= L'z')) && s[1] == L':';
}

// The length of the root of an absolute name with backslashes: "C:\" -> 3,
// "\\server\share\x" -> 15 (up to and including the backslash after the share, or to the end
// when there is none); 0 when the name is not absolute.
inline int FcRootLenW(const WCHAR* s)
{
    if (FcIsDriveW(s) && s[2] == L'\\')
        return 3;
    if (s[0] == L'\\' && s[1] == L'\\')
    {
        int i = 2;
        if (s[i] == 0 || s[i] == L'\\')
            return 0; // no server
        while (s[i] != 0 && s[i] != L'\\')
            i++;
        if (s[i] == 0)
            return 0; // no share
        i++;
        if (s[i] == 0 || s[i] == L'\\')
            return 0;
        while (s[i] != 0 && s[i] != L'\\')
            i++;
        if (s[i] == L'\\')
            i++;
        return i;
    }
    return 0;
}

// The absolute name of the argument 'arg' (HeapAlloc'ed), NULL when it cannot be formed.
// feature 102 (review): GetFullPathNameW was used here, but it drops the trailing dots and
// spaces of EVERY component ("C:\t\dir.\b.txt" -> "C:\t\dir\b.txt"), so fcremote could name
// a different file than the one typed; the plug-in opens names with the "\\?\" prefix, which
// takes every component as it is. So the name is made absolute here, without normalising any
// component:
//   - an "\\?\" name is taken as it is;
//   - "C:\x" and "\\server\share\x" are absolute; "\x" is put on the root of 'curDir' (the
//     current directory), "C:x" on 'driveDir' (the current directory of that drive, given by
//     the caller; NULL = the name is refused), any other name on 'curDir';
//   - '/' becomes '\'; empty and "." components are dropped, ".." removes the component before
//     it (never the root); every other component is kept exactly as typed.
inline WCHAR* FcAbsoluteNameW(const WCHAR* arg, const WCHAR* curDir, const WCHAR* driveDir)
{
    int argLen = lstrlenW(arg);
    if (argLen == 0)
        return NULL;
    HANDLE heap = GetProcessHeap();
    if (argLen >= 4 && arg[0] == L'\\' && arg[1] == L'\\' && arg[2] == L'?' && arg[3] == L'\\')
    {
        WCHAR* copy = (WCHAR*)HeapAlloc(heap, 0, ((SIZE_T)argLen + 1) * sizeof(WCHAR));
        if (copy != NULL)
            lstrcpyW(copy, arg);
        return copy;
    }

    // the base the name is put on, and the part of the name that follows it
    const WCHAR* base = NULL;
    int baseLen = 0;
    const WCHAR* rest = arg;
    BOOL uncBase = FALSE; // the base is "\\?\UNC\..." given as "\\" + the rest
    if (FcIsDriveW(arg) && FcIsSlashW(arg[2]))
        ; // absolute
    else if (FcIsSlashW(arg[0]) && FcIsSlashW(arg[1]))
        ; // UNC
    else
    {
        base = FcIsDriveW(arg) ? driveDir : curDir;
        if (base == NULL || base[0] == 0)
            return NULL;
        if (base[0] == L'\\' && base[1] == L'\\' && base[2] == L'?' && base[3] == L'\\')
        { // a current directory in the "\\?\" form
            if ((base[4] == L'U' || base[4] == L'u') && (base[5] == L'N' || base[5] == L'n') &&
                (base[6] == L'C' || base[6] == L'c') && base[7] == L'\\')
            {
                base += 8;
                uncBase = TRUE;
            }
            else
                base += 4;
        }
        baseLen = lstrlenW(base);
        if (FcIsDriveW(arg))
            rest = arg + 2;
        else if (FcIsSlashW(arg[0]))
        { // root-relative: only the root of the current directory is kept
            if (!uncBase && FcIsDriveW(base))
                baseLen = 2; // "C:"
            else
            {
                // "\\server\share" of a UNC current directory: the root without its backslash
                int i = uncBase ? 0 : 2;
                if (!uncBase && !(FcIsSlashW(base[0]) && FcIsSlashW(base[1])))
                    return NULL;
                while (base[i] != 0 && !FcIsSlashW(base[i]))
                    i++;
                if (base[i] != 0)
                    i++;
                while (base[i] != 0 && !FcIsSlashW(base[i]))
                    i++;
                baseLen = i;
            }
            rest = arg + 1;
        }
    }

    // base + '\' + rest, slashes turned into backslashes (copies with lstrcpynW: a plain copy
    // loop may be compiled into a memcpy call, and fcremote.exe has no C runtime)
    int restLen = lstrlenW(rest);
    int combLen = (uncBase ? 2 : 0) + baseLen + 1 + restLen;
    WCHAR* comb = (WCHAR*)HeapAlloc(heap, 0, ((SIZE_T)combLen + 2) * sizeof(WCHAR));
    if (comb == NULL)
        return NULL;
    int n = 0;
    int i;
    if (base != NULL)
    {
        if (uncBase)
        {
            comb[n++] = L'\\';
            comb[n++] = L'\\';
        }
        lstrcpynW(comb + n, base, baseLen + 1);
        n += baseLen;
        comb[n++] = L'\\';
    }
    lstrcpyW(comb + n, rest);
    n += restLen;
    for (i = 0; i < n; i++)
    {
        if (comb[i] == L'/')
            comb[i] = L'\\';
    }

    int root = FcRootLenW(comb);
    if (root == 0)
    {
        HeapFree(heap, 0, comb);
        return NULL;
    }
    WCHAR* out = (WCHAR*)HeapAlloc(heap, 0, ((SIZE_T)n + 2) * sizeof(WCHAR));
    if (out == NULL)
    {
        HeapFree(heap, 0, comb);
        return NULL;
    }
    lstrcpynW(out, comb, root + 1);
    int o = root;
    if (out[o - 1] != L'\\')
        out[o++] = L'\\'; // "\\server\share" without its backslash
    int rootOut = o;
    i = root;
    while (comb[i] != 0)
    {
        int start = i;
        while (comb[i] != 0 && comb[i] != L'\\')
            i++;
        int len = i - start;
        if (comb[i] == L'\\')
            i++;
        if (len == 0 || (len == 1 && comb[start] == L'.'))
            continue; // "" and "."
        if (len == 2 && comb[start] == L'.' && comb[start + 1] == L'.')
        { // "..": drop the last component (never the root)
            if (o > rootOut)
            {
                o--; // its backslash
                while (o > rootOut && out[o - 1] != L'\\')
                    o--;
            }
            continue;
        }
        lstrcpynW(out + o, comb + start, len + 1);
        o += len;
        out[o++] = L'\\';
    }
    if (o > rootOut)
        o--; // no backslash after the last component
    out[o] = 0;
    HeapFree(heap, 0, comb);
    return out;
}

// The names part of a version-2 message is consistent: 'size' bytes in all, 'headerSize' of
// them before 'names', two UTF-16 names of 'len1' and 'len2' units, each terminated, filling the
// message exactly.
inline BOOL FcCheckNames(int size, int headerSize, DWORD len1, DWORD len2, const WCHAR* names)
{
    if (size < headerSize + 2 * (int)sizeof(WCHAR) || (size - headerSize) % sizeof(WCHAR) != 0)
        return FALSE;
    DWORD units = (DWORD)(size - headerSize) / sizeof(WCHAR);
    if (len1 >= units || len2 >= units || len1 + len2 + 2 != units) // no overflow in the sum
        return FALSE;
    return names[len1] == 0 && names[len1 + 1 + len2] == 0;
}

// The display form of a UTF-8 full name (in place): "\\?\C:\x" -> "C:\x",
// "\\?\UNC\server\x" -> "\\server\x"; other names stay. The plug-in's file layer adds the
// prefix back when it opens the file, without normalizing the name.
inline void FcDisplayFormU8(char* u8)
{
    int skip = 0;
    if (u8[0] == '\\' && u8[1] == '\\' && u8[2] == '?' && u8[3] == '\\')
    {
        if ((u8[4] == 'U' || u8[4] == 'u') && (u8[5] == 'N' || u8[5] == 'n') && (u8[6] == 'C' || u8[6] == 'c') && u8[7] == '\\')
            skip = 6; // keep "\\" + "server..." : "\\?\UNC\s" -> "\\s"
        else if (u8[4] != 0 && u8[5] == ':' && u8[6] == '\\')
            skip = 4;
    }
    if (skip == 6)
    {
        char* d = u8 + 1;
        const char* s = u8 + 7;
        while ((*d++ = *s++) != 0)
            ;
    }
    else if (skip == 4)
    {
        char* d = u8;
        const char* s = u8 + 4;
        while ((*d++ = *s++) != 0)
            ;
    }
}
