// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

// Removing passwords from history entries (feature 085, F1), see salurlpwd.h
// and specs/085-privacy-defect-fixes/contracts/history-password-strip.md.

#include "precomp.h"

#include <windows.h>
#include <stdlib.h>
#include <string.h>

#include "salurlpwd.h"

namespace
{

bool IsAsciiLetter(char c)
{
    return c >= 'A' && c <= 'Z' || c >= 'a' && c <= 'z';
}

// RFC 3986 scheme characters: ALPHA / DIGIT / "+" / "-" / "."
bool IsSchemeChar(char c)
{
    return IsAsciiLetter(c) || c >= '0' && c <= '9' || c == '+' || c == '-' || c == '.';
}

// How an address part ends: a single value only at '/' (FTP accepts spaces and
// quotes in a password); a command line also where a word ends; a URL right
// after a quote at the matching quote.
enum EPartMode
{
    pmValue,
    pmCommandLine,
    pmQuoted,
};

bool IsPartEnd(char c, EPartMode mode, char quote)
{
    if (c == 0 || c == '/')
        return true;
    if (mode == pmQuoted)
        return c == quote;
    if (mode == pmCommandLine) // bytes >= 0x80 (UTF-8 sequences) never end the part
        return (unsigned char)c <= ' ' || c == '"' || c == '\'' || c == '<' || c == '>';
    return false;
}

// "%40" / "%3A" - the escaped '@' / ':' the FTP plugin decodes before it splits
// an address (Config.ConvertHexEscSeq)
bool IsEscaped(const char* s, char hi, char lo)
{
    return s[0] == '%' && s[1] == hi &&
           (s[2] == lo || lo >= 'A' && lo <= 'Z' && s[2] == lo - 'A' + 'a');
}

BOOL StripPart(char* p, EPartMode mode, char quote)
{
    if (p == NULL)
        return FALSE;
    // the LAST '@' of the part: a password may itself contain '@' (typed
    // unescaped), and no fragment of it may stay behind
    char* at = NULL;
    for (char* e = p; !IsPartEnd(*e, mode, quote); e++)
    {
        if (*e == '@' || IsEscaped(e, '4', '0'))
            at = e;
    }
    if (at == NULL)
        return FALSE; // no user part: "host", "host:2121"
    // the FIRST ':' of the user part starts the password
    char* colon = NULL;
    for (char* c = p; c < at; c++)
    {
        if (*c == ':' || IsEscaped(c, '3', 'A'))
        {
            colon = c;
            break;
        }
    }
    if (colon == NULL)
        return FALSE; // a user name without a password
    memmove(colon, at, strlen(at) + 1);
    return TRUE;
}

// the leading forms 2 and 3 (shared by values and command lines)
BOOL StripLeading(char* text, EPartMode mode)
{
    char* s = text;
    while (*s != 0 && (unsigned char)*s <= ' ')
        s++;
    if (s[0] == '/' && s[1] == '/')
        return StripPart(s + 2, mode, 0); // "//user:pw@host" (user part of a plugin path)
    if (IsAsciiLetter(s[0]))
    {
        char* n = s;
        while (IsSchemeChar(*n))
            n++;
        // "ftp:user:pw@host" - a file-system name of 2+ characters ("C:" is a
        // drive); "name://" is left to the "://" loop
        if (n - s >= 2 && n[0] == ':' && !(n[1] == '/' && n[2] == '/'))
        {
            // a plugin path that continues with a drive ("del:C:\dir\@types",
            // the Undelete plugin) has no user part - its ':' is the drive's
            char* q = n + 1;
            if (IsAsciiLetter(q[0]) && q[1] == ':' && (q[2] == '\\' || q[2] == '/' || q[2] == 0))
                return FALSE;
            return StripPart(q, mode, 0);
        }
    }
    return FALSE;
}

BOOL StripText(char* text, bool commandLine)
{
    if (text == NULL)
        return FALSE;
    BOOL changed = StripLeading(text, commandLine ? pmCommandLine : pmValue);

    // form 1: every "scheme://" anywhere (a command line may hold several)
    for (char* p = strstr(text, "://"); p != NULL; p = strstr(p + 3, "://"))
    {
        int schemeLen = 0;
        while (p - schemeLen > text && IsSchemeChar(p[-schemeLen - 1]))
            schemeLen++;
        if (schemeLen < 2)
            continue;
        EPartMode mode = commandLine ? pmCommandLine : pmValue;
        char quote = 0;
        const char* schemeStart = p - schemeLen;
        if (commandLine && schemeStart > text && (schemeStart[-1] == '"' || schemeStart[-1] == '\''))
        {
            mode = pmQuoted; // curl "ftp://u:my pass@h/f": the quote, not the space, ends it
            quote = schemeStart[-1];
        }
        changed |= StripPart(p + 3, mode, quote);
    }
    return changed;
}

} // namespace

BOOL SalStripAuthorityPassword(char* p, BOOL commandLine)
{
    return StripPart(p, commandLine ? pmCommandLine : pmValue, 0);
}

BOOL SalStripUrlPasswords(char* text)
{
    return StripText(text, false);
}

BOOL SalStripCommandLinePasswords(char* text)
{
    return StripText(text, true);
}

BOOL SalStripAddressPassword(char* address, const char* const* fsNames, int fsNameCount)
{
    if (address == NULL)
        return FALSE;
    char* p = address;
    while (*p != 0 && (unsigned char)*p <= ' ')
        p++;
    char* n = p;
    while (IsSchemeChar(*n))
        n++;
    if (n > p && n[0] == ':' && n[1] == '/' && n[2] == '/')
        p = n + 3; // "ftp://", "ftps://" (or any other "name://")
    else
    {
        for (int i = 0; i < fsNameCount; i++)
        {
            const char* name = fsNames != NULL ? fsNames[i] : NULL;
            int len = name != NULL ? (int)strlen(name) : 0;
            if (len > 0 && _strnicmp(p, name, len) == 0 && p[len] == ':')
            {
                p += len + 1;
                break;
            }
        }
        if (p[0] == '/' && p[1] == '/')
            p += 2;
    }
    // a single value: '\' may be part of a user name ("ms-domain\name"), and
    // spaces or quotes may be part of a password
    return StripPart(p, pmValue, 0);
}

BOOL SalStripHistoryPasswords(char** history, int count, BOOL (*strip)(char* text))
{
    if (history == NULL || count <= 0 || strip == NULL)
        return FALSE;
    BOOL changed = FALSE;
    int i;
    for (i = 0; i < count; i++)
    {
        if (history[i] != NULL && strip(history[i]))
            changed = TRUE;
    }
    // an entry that became equal to a more recent one goes (most recent first)
    for (i = 1; i < count; i++)
    {
        if (history[i] == NULL)
            continue;
        for (int j = 0; j < i; j++)
        {
            if (history[j] != NULL && strcmp(history[j], history[i]) == 0)
            {
                free(history[i]);
                history[i] = NULL;
                changed = TRUE;
                break;
            }
        }
    }
    // no NULL may precede an entry: SaveHistory stops at the first NULL
    int w = 0;
    for (i = 0; i < count; i++)
    {
        if (history[i] != NULL)
        {
            if (w != i)
            {
                history[w] = history[i];
                history[i] = NULL;
                changed = TRUE;
            }
            w++;
        }
    }
    return changed;
}
