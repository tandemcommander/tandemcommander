// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

// Feature 428: pure rules of the portable edition's settings store (src/portstore.cpp), covered
// by saltests (TestPortable428). Header-only on SalPathHasPrefixOrdinalCI (salunicode.h).
//
//   SalPortableScope            the identity of one copy (its program folder) as 16 hex digits
//   SalPortableSessionDirName   the per-copy folder in %TEMP% ("TandemCommander-portable-<scope>")
//   SalPortableScopeSuffix      the suffix of the copy's named kernel objects ("_P<scope>")
//   SalPortableRelativize       program folder -> "$(PortableDir)" in a string value (at the dump)
//   SalPortableExpand           "$(PortableDir)" -> program folder (at the seed)
//   SalPortableStartDecision    what the start does with the session hive and the settings files
//
// See specs/428-portable-build/research.md (R-03, R-04) and data-model.md.

#pragma once

#include <string>

#include "salunicode.h"
#include "salportscope.h"

// ****************************************************************************
// identity of a copy

// the scope rule itself is in salportscope.h (CRT-free - fcremote.exe uses it too)
// 'fileId' = the 16 bytes of FILE_ID_128; the result has exactly 16 lower-case hex digits
inline std::string SalPortableScope(unsigned __int64 volumeSerial, const unsigned char* fileId16)
{
    char hex[17];
    SalPortableScopeHex(volumeSerial, fileId16, hex);
    return hex;
}

#define SALPORTABLE_SESSION_PREFIX "TandemCommander-portable-"

inline std::string SalPortableSessionDirName(const std::string& scope)
{
    return SALPORTABLE_SESSION_PREFIX + scope;
}

// TRUE for a folder name made by SalPortableSessionDirName (any scope) - the stale clean-up at
// start touches only such folders
inline BOOL SalPortableIsSessionDirName(const char* name)
{
    size_t pl = sizeof(SALPORTABLE_SESSION_PREFIX) - 1;
    if (name == NULL || strncmp(name, SALPORTABLE_SESSION_PREFIX, pl) != 0)
        return FALSE;
    const char* s = name + pl;
    int n = 0;
    for (; s[n] != 0; n++)
    {
        char c = s[n];
        if (!(c >= '0' && c <= '9' || c >= 'a' && c <= 'f'))
            return FALSE;
    }
    return n == 16;
}

inline std::string SalPortableScopeSuffix(const std::string& scope)
{
    return "_P" + scope;
}

// ****************************************************************************
// paths inside the program folder (research R-03)

// The token is NOT the program's variable $(SalDir): that one expands with a trailing backslash in
// commands ("E:\TC\") and without one in initial folders, so "$(SalDir)tools\x.exe" is a valid
// command a plain text replace would turn into "E:\TCtools\x.exe" (measured by the gate test of
// 428). A $(SalDir) the user typed is left exactly as typed and keeps its own meaning; only the
// store writes and reads $(PortableDir), always followed by what followed the folder.
#define SALPORTABLE_DIRTOKEN "$(PortableDir)"

// a byte that can continue a path component or a path - a match of the program folder must not
// start right after one (it would be the tail of a longer path) nor end before one (it would be the
// head of a longer name: "E:\TC" is not inside "E:\TC2")
inline BOOL SalPortableIsPathByte(unsigned char c)
{
    return c >= 0x80 || c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' ||
           c == '\\' || c == '/' || c == ':' || c == '.' || c == '_' || c == '-' || c == '$' ||
           c == '~' || c == '!' || c == '#' || c == '&' || c == '@' || c == '+' || c == '{' ||
           c == '}' || c == '[' || c == ']' || c == '%' || c == '^' || c == '`' || c == '\'';
}

// what may follow the program folder in a value for the match to count: the end, a path separator,
// or a character that ends a path in a command line or a list
inline BOOL SalPortableIsEndOfFolder(unsigned char c)
{
    // not a space: "E:\TC tools" is another folder than "E:\TC"
    return c == 0 || c == '\\' || c == '/' || c == '"' || c == ';' || c == '|' || c == ',' || c == '>' ||
           c == '<' || c == ')';
}

// 'programDir' = the program folder in its long-name form without a trailing backslash ("E:\TC",
// "\\server\share\TC"; a drive root as "E:"); empty = nothing is replaced. Every occurrence of the
// folder in 'text' at a path boundary (file-system identity, SalPathHasPrefixOrdinalCI) becomes
// "$(PortableDir)"; the rest of the text is kept byte for byte.
inline std::string SalPortableRelativize(const char* text, const char* programDir)
{
    std::string out;
    if (text == NULL)
        return out;
    size_t dirLen = programDir != NULL ? strlen(programDir) : 0;
    if (dirLen == 0)
        return text;
    const char* s = text;
    const char* p = text;
    while (*p != 0)
    {
        BOOL startOk = p == text || !SalPortableIsPathByte((unsigned char)p[-1]);
        int covered = 0;
        if (startOk && SalPathHasPrefixOrdinalCI(p, programDir, (int)dirLen, &covered) && covered > 0 &&
            SalPortableIsEndOfFolder((unsigned char)p[covered]))
        {
            out.append(s, p - s);
            out.append(SALPORTABLE_DIRTOKEN);
            p += covered;
            s = p;
            continue;
        }
        p++;
    }
    out.append(s);
    return out;
}

// every "$(PortableDir)" (exactly this spelling - the one SalPortableRelativize writes) becomes
// 'programDir'; empty 'programDir' = the text unchanged
inline std::string SalPortableExpand(const char* text, const char* programDir)
{
    std::string out;
    if (text == NULL)
        return out;
    if (programDir == NULL || *programDir == 0)
        return text;
    const size_t tokLen = sizeof(SALPORTABLE_DIRTOKEN) - 1;
    const char* s = text;
    const char* p;
    while ((p = strstr(s, SALPORTABLE_DIRTOKEN)) != NULL)
    {
        out.append(s, p - s);
        out.append(programDir);
        s = p + tokLen;
    }
    out.append(s);
    return out;
}

// ****************************************************************************
// the start decision (data-model.md, "Pure start decision")

enum CSalPortableSessionState
{
    spssHeld, // session.dat is loaded by a live process of this copy (its delete failed: sharing)
    spssFree, // absent, or deleted just now (a crashed session's leftover)
};

enum CSalPortableFileState
{
    spfsOk,         // read and parsed
    spfsBad,        // read, but not a configuration file of ours (or damaged)
    spfsAbsent,     // does not exist
    spfsUnreadable, // exists, but could not be read (access, I/O) - never overwrite it
};

enum CSalPortableStartAction
{
    spsaJoin,          // load the live session.dat; nothing is seeded
    spsaSeedFile,      // seed from settings\tandemcommander.reg
    spsaSeedBak,       // seed from tandemcommander.reg.bak; tell the user (IDS_PORTABLE_RESTOREDBAK)
    spsaDefaults,      // a fresh copy: default settings, nothing to tell
    spsaDefaultsDamaged, // rename the damaged file(s) aside, default settings, tell the user
    spsaReadOnly,      // a file could not be read: default settings and the store stays unwritable
};

inline CSalPortableStartAction SalPortableStartDecision(CSalPortableSessionState session,
                                                        CSalPortableFileState file,
                                                        CSalPortableFileState bak)
{
    if (session == spssHeld)
        return spsaJoin;
    if (file == spfsUnreadable || bak == spfsUnreadable)
        return spsaReadOnly; // never risk replacing a file whose content we could not see
    if (file == spfsOk)
        return spsaSeedFile;
    if (bak == spfsOk)
        return spsaSeedBak; // the main file is damaged or gone (an interrupted replace)
    if (file == spfsAbsent && bak == spfsAbsent)
        return spsaDefaults;
    return spsaDefaultsDamaged; // something exists and nothing of it parses
}
