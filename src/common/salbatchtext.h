// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salbatchtext.h
//
// The encoding of the batch file the User Menu runs "through a shell"
// (feature 226). Header-only, no globals: the core uses it and saltests
// checks it.
//
// cmd.exe reads a batch file in the console's code page - the OEM code page
// of a new console. The User Menu's commands, folders and the names put into
// them are UTF-8 (WTF-8); before feature 226 they were converted with
// CharToOem, which reads its input as the ANSI code page, so every letter
// outside ASCII became other letters: the command ran on another file or on
// none. Now the whole text of the batch file is converted at once:
//   - pure ASCII -> written as it is (byte for byte as before);
//   - every character has an exact OEM form (no best fit, no default
//     character) -> written in the OEM code page, after a line that switches
//     the console to it (the console may have been set to another one:
//     HKCU\Console\CodePage, a chcp in cmd's AutoRun);
//   - otherwise (CJK letters on a European system, ...) -> written in UTF-8,
//     after a line that switches the console to UTF-8 and before a line that
//     switches it back to the OEM code page (a shell window the user keeps
//     open goes on in the OEM code page - not in a code page of the user's
//     own console settings; a known limit);
//   - text that is not valid UTF-8 - a name with an unpaired surrogate
//     (WTF-8, feature 066) - has no form a batch file can hold: refused, the
//     batch file is never run with a changed name.
// An OEM code page of 65001 (Windows' "use Unicode UTF-8" option) takes the
// text as it is (a UTF-8 text). The code-page lines run chcp.com by its full
// path: cmd looks for a bare "chcp" in the current folder first - the folder
// the user browses, where a planted chcp.bat would run (review of 226). When
// the switch fails, the batch file ends instead of reading names in another
// code page.
// One character outside the OEM code page puts the whole batch file in UTF-8:
// console programs of its other lines then run with the console at 65001 too
// (and a batch file such a line calls is read as UTF-8).
//
//*****************************************************************************

#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum CSalBatchEncoding
{
    SALBATCH_OEM,     // *out holds the text in the OEM code page
    SALBATCH_UTF8,    // the text goes in UTF-8, between the code-page lines
    SALBATCH_REFUSED, // not valid UTF-8 (an unpaired surrogate): not run
};

// the batch text being built (UTF-8): the lines are collected first, the encoding is chosen for the
// whole text
class CSalBatchText
{
public:
    CSalBatchText() : Text(NULL), Len(0), Cap(0) {}
    ~CSalBatchText() { free(Text); }

    // FALSE when memory is low or the text would pass 1 GB (the text is then unchanged)
    BOOL Append(const char* s, int n)
    {
        if (n < 0 || n > 0x40000000 - Len)
            return FALSE;
        if (Len + n + 1 > Cap)
        {
            int cap = Cap < 256 ? 256 : Cap;
            while (cap < Len + n + 1)
                cap = cap <= 0x20000000 ? cap * 2 : 0x40000001;
            char* t = (char*)realloc(Text, (size_t)cap);
            if (t == NULL)
                return FALSE;
            Text = t;
            Cap = cap;
        }
        memcpy(Text + Len, s, (size_t)n);
        Len += n;
        Text[Len] = 0;
        return TRUE;
    }
    BOOL Append(const char* s) { return Append(s, (int)strlen(s)); }

    char* Text; // NULL until the first Append
    int Len;
    int Cap;

    CSalBatchText(const CSalBatchText&) = delete;
    CSalBatchText& operator=(const CSalBatchText&) = delete;
};

// the line switching the console to 'codePage': 'first' - the batch file ends when the switch
// fails (the first line; the program does not learn of it: a hidden shell then does nothing, a
// shell window shows cmd's message); otherwise the last line of a UTF-8 text, back to the OEM code
// page. 'systemDir': the system folder ("C:\Windows\System32") written into the line as it is when
// it is ASCII and short; otherwise (or NULL) %SystemRoot%\System32 - which a child environment
// without SystemRoot would turn into "\System32" of the current drive, so the absolute folder is
// preferred (second review of 226).
#define SALBATCH_LINE_SIZE (MAX_PATH + 80)
inline void SalBatchCodePageLine(UINT codePage, BOOL first, const char* systemDir, char* buf, int bufSize)
{
    BOOL useDir = systemDir != NULL && systemDir[0] != 0 && strlen(systemDir) < MAX_PATH &&
                  strchr(systemDir, '"') == NULL && strchr(systemDir, '%') == NULL;
    for (const char* s = systemDir; useDir && *s != 0; s++)
    {
        if ((unsigned char)*s >= 0x80)
            useDir = FALSE;
    }
    if (useDir)
    {
        size_t len = strlen(systemDir);
        _snprintf_s(buf, bufSize, _TRUNCATE, "@\"%s%schcp.com\" %u>nul%s\r\n", systemDir,
                    systemDir[len - 1] == '\\' ? "" : "\\", codePage, first ? " || exit /b 1" : "");
    }
    else
    {
        _snprintf_s(buf, bufSize, _TRUNCATE, "@\"%%SystemRoot%%\\System32\\chcp.com\" %u>nul%s\r\n", codePage,
                    first ? " || exit /b 1" : "");
    }
}

// TRUE when the text holds only ASCII bytes
inline BOOL SalBatchIsAscii(const char* s, int len)
{
    for (int i = 0; i < len; i++)
    {
        if ((unsigned char)s[i] >= 0x80)
            return FALSE;
    }
    return TRUE;
}

// u8 / u8Len: the batch text (UTF-8, no terminator needed); oemCP: the console's code page.
// SALBATCH_OEM: *out is a malloc'd copy in the OEM code page (*outLen bytes, also null-terminated;
// the caller frees it); otherwise *out is NULL. Out of memory: SALBATCH_REFUSED with *out NULL and
// *outOfMemory TRUE.
inline CSalBatchEncoding SalBatchChooseEncoding(const char* u8, int u8Len, UINT oemCP,
                                                char** out, int* outLen, BOOL* outOfMemory)
{
    *out = NULL;
    *outLen = 0;
    *outOfMemory = FALSE;
    int wLen = 0;
    if (u8Len > 0)
    {
        wLen = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, u8, u8Len, NULL, 0);
        if (wLen <= 0)
            return SALBATCH_REFUSED; // not valid UTF-8 (a WTF-8 surrogate is not)
    }
    if (oemCP == CP_UTF8 || u8Len == 0) // the console reads UTF-8 already / nothing to convert
    {
        char* copy = (char*)malloc((size_t)u8Len + 1);
        if (copy == NULL)
        {
            *outOfMemory = TRUE;
            return SALBATCH_REFUSED;
        }
        memcpy(copy, u8, (size_t)u8Len);
        copy[u8Len] = 0;
        *out = copy;
        *outLen = u8Len;
        return SALBATCH_OEM;
    }
    WCHAR* w = (WCHAR*)malloc((size_t)wLen * sizeof(WCHAR));
    if (w == NULL)
    {
        *outOfMemory = TRUE;
        return SALBATCH_REFUSED;
    }
    MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, u8, u8Len, w, wLen);
    CSalBatchEncoding res = SALBATCH_UTF8;
    BOOL usedDefault = FALSE;
    int oLen = WideCharToMultiByte(oemCP, WC_NO_BEST_FIT_CHARS, w, wLen, NULL, 0, NULL, &usedDefault);
    if (oLen > 0 && !usedDefault) // every character has its exact OEM form
    {
        char* o = (char*)malloc((size_t)oLen + 1);
        if (o == NULL)
        {
            *outOfMemory = TRUE;
            res = SALBATCH_REFUSED;
        }
        else
        {
            usedDefault = FALSE;
            if (WideCharToMultiByte(oemCP, WC_NO_BEST_FIT_CHARS, w, wLen, o, oLen, NULL, &usedDefault) == oLen &&
                !usedDefault)
            {
                o[oLen] = 0;
                *out = o;
                *outLen = oLen;
                res = SALBATCH_OEM;
            }
            else
                free(o);
        }
    }
    free(w);
    return res;
}

//*****************************************************************************
//
// Inserted values in a batch line (feature 229)
//
// The names, paths and environment values the User Menu inserts into its batch
// file must reach the command as they are. cmd expands '%' in a batch line, and
// "call" (every command line of the User Menu's batch file starts with it)
// expands it a second time and doubles every '^' inside quotes: "50%off.txt"
// lost its '%', "a%OS%b.txt" became "aWindows_NTb.txt", "a^b.txt" became
// "a^^b.txt" - each another file that may exist. Only the inserted values are
// escaped - what the user typed (%VAR%, ^&, >) keeps its batch meaning:
//   '%' -> 'percentRepeat' times '%' (4 on a "call" line: the line's expansion
//          and the call's each halve it; 2 on the "cd" line, which has no call)
//   '^' -> no escape survives "call" inside quotes: the caller refuses
//          (SalBatchValueRefused)
//   '&', '|', '<', '>' outside quotes (a $(Name) the user did not quote, the
//          names of a $(ListOfSelectedNames) - quoted only when they hold a
//          space): the name "x&calc" ran "calc" - refused (review of 229)
// '!' is safe: cmd is started with /V:OFF (no delayed expansion).

// the bytes 'value' / 'len' takes escaped
inline int SalBatchEscapedLen(const char* value, int len, int percentRepeat)
{
    int n = len;
    for (int i = 0; i < len; i++)
    {
        if (value[i] == '%')
            n += percentRepeat - 1;
    }
    return n;
}

// writes the escaped value (SalBatchEscapedLen bytes, no terminator) to 'out'
inline void SalBatchCopyEscaped(char* out, const char* value, int len, int percentRepeat)
{
    for (int i = 0; i < len; i++)
    {
        if (value[i] == '%')
        {
            for (int k = 0; k < percentRepeat; k++)
                *out++ = '%';
        }
        else
            *out++ = value[i];
    }
}

// TRUE when the line text before the value ('line' up to 'lineLen' bytes) leaves an open quote
inline BOOL SalBatchInsideQuotes(const char* line, int lineLen)
{
    BOOL inside = FALSE;
    for (int i = 0; i < lineLen; i++)
    {
        if (line[i] == '"')
            inside = !inside;
    }
    return inside;
}

// TRUE when the value cannot go into the batch line unchanged: a '^' anywhere ("call" doubles it
// inside quotes), '&', '|', '<' or '>' outside quotes (another command, a redirection)
// (a '"' inside the value - the quotes of a $(ListOfSelectedNames) - switches the state as it does
// for cmd: "$(ListOfSelectedFullNames)" with a name holding a space gave ""C:\a b&calc"" - the
// '&' outside quotes; second review of 229)
inline BOOL SalBatchValueRefused(const char* value, int len, BOOL insideQuotes)
{
    for (int i = 0; i < len; i++)
    {
        char c = value[i];
        if (c == '"')
            insideQuotes = !insideQuotes;
        else if (c == '^' || !insideQuotes && (c == '&' || c == '|' || c == '<' || c == '>'))
            return TRUE;
    }
    return FALSE;
}

// TRUE when a name in a $(ListOfSelectedNames) list goes in quotes: a space - and (feature 229) a
// character cmd splits arguments at or treats as an operator: "del Smith,John.txt" deleted Smith and
// John.txt, not the selected file; "x&calc" ran calc
inline BOOL SalListNameNeedsQuotes(const char* name, int len)
{
    for (int i = 0; i < len; i++)
    {
        switch (name[i])
        {
        case ' ':
        case ',':
        case ';':
        case '=':
        case '&':
        case '|':
        case '<':
        case '>':
        case '(':
        case ')':
        case '^':
            return TRUE;
        }
    }
    return FALSE;
}
