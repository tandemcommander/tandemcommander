// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salupdcheck.h
//
// Checking for a new version - the pure part (feature 123).
//
// The program asks GitHub for the latest published release of Tandem
// Commander and tells the user when it is newer than the installed one. This
// header holds every decision of that feature that can be made without
// Windows state: the order of versions, a small strict JSON reader, the rules
// a release record must meet, the addresses the program offers to open, and
// the rule for "is an automatic check due".
//
// The answer comes from the network and is treated as untrusted. Two rules
// follow from that and must be kept:
//
//   1. The program never opens an address taken from the answer. The
//      installer and release-notes addresses are CONSTRUCTED here from three
//      validated numbers; the answer only has to contain exactly these
//      addresses (which proves that the installer is really attached).
//   2. Nothing from the answer is shown except the version and the date,
//      both re-printed from parsed numbers.
//
// Header-only and free of core dependencies, so that saltests and stand-alone
// probes compile it as it is. No allocation, no I/O, no globals.
//
// Contracts: specs/123-new-version-check/contracts/update-source.md
//            specs/123-new-version-check/contracts/stored-state.md
// Data model: specs/123-new-version-check/data-model.md
//
//*****************************************************************************

#include <windows.h>
#include <string.h>

// the request (quoted in PRIVACY.md - change both together)
#define SALUPD_HOST_W L"api.github.com"
#define SALUPD_PATH_W L"/repos/tandemcommander/tandemcommander/releases/latest"
#define SALUPD_USER_AGENT_W L"TandemCommander-updatecheck"
#define SALUPD_HEADERS_W L"Accept: application/vnd.github+json\r\nX-GitHub-Api-Version: 2022-11-28\r\n"

// limits (data-model.md, Limits)
#define SALUPD_MAX_ANSWER (256 * 1024) // bytes of a 200 answer; a larger one is "unexpected"
#define SALUPD_MAX_DEPTH 32            // JSON nesting
#define SALUPD_MAX_STRING 512          // bytes of an extracted string incl. the terminating zero
#define SALUPD_MAX_VERSION_DIGITS 5    // digits of one version part
#define SALUPD_URL_MAX 200             // buffer for a constructed address
#define SALUPD_VERSION_TEXT_MAX 24     // buffer for "<major>.<minor>.<patch>"
#define SALUPD_TIME_TEXT_MAX 24        // buffer for "YYYY-MM-DDThh:mm:ssZ"

// times are UTC FILETIME values (100 ns units)
#define SALUPD_HOUR 36000000000ULL
#define SALUPD_INTERVAL_ANSWERED (24 * SALUPD_HOUR) // after an attempt the source answered
#define SALUPD_INTERVAL_UNREACHED (1 * SALUPD_HOUR) // after an attempt that never reached it

//
// ****************************************************************************
// Version
//

struct CSalUpdVersion
{
    unsigned Major;
    unsigned Minor;
    unsigned Patch;
};

// <0, 0, >0 like strcmp; a total order on (Major, Minor, Patch)
inline int SalUpdVersionCompare(const CSalUpdVersion& a, const CSalUpdVersion& b)
{
    if (a.Major != b.Major)
        return a.Major < b.Major ? -1 : 1;
    if (a.Minor != b.Minor)
        return a.Minor < b.Minor ? -1 : 1;
    if (a.Patch != b.Patch)
        return a.Patch < b.Patch ? -1 : 1;
    return 0;
}

// Parses "<major>.<minor>.<patch>" ('tagForm' FALSE) or "v<major>.<minor>.<patch>"
// ('tagForm' TRUE) from exactly 'len' bytes: three parts of 1 to
// SALUPD_MAX_VERSION_DIGITS decimal digits and nothing else - no sign, no
// space, no suffix. 'len' < 0 means zero-terminated.
inline BOOL SalUpdParseVersion(const char* s, int len, BOOL tagForm, CSalUpdVersion* v)
{
    if (s == NULL || v == NULL)
        return FALSE;
    if (len < 0)
        len = (int)strlen(s);
    int i = 0;
    if (tagForm)
    {
        if (len < 1 || s[0] != 'v')
            return FALSE;
        i = 1;
    }
    unsigned parts[3];
    for (int p = 0; p < 3; p++)
    {
        int digits = 0;
        unsigned value = 0;
        while (i < len && s[i] >= '0' && s[i] <= '9')
        {
            if (++digits > SALUPD_MAX_VERSION_DIGITS)
                return FALSE;
            value = value * 10 + (unsigned)(s[i] - '0');
            i++;
        }
        if (digits == 0)
            return FALSE;
        parts[p] = value;
        if (p < 2)
        {
            if (i >= len || s[i] != '.')
                return FALSE;
            i++;
        }
    }
    if (i != len)
        return FALSE;
    v->Major = parts[0];
    v->Minor = parts[1];
    v->Patch = parts[2];
    return TRUE;
}

// appends an unsigned decimal number; returns the new end or NULL when it does not fit
inline char* SalUpdAppendNumber(char* p, char* end, unsigned value)
{
    char tmp[12];
    int n = 0;
    do
    {
        tmp[n++] = (char)('0' + value % 10);
        value /= 10;
    } while (value != 0);
    if (p == NULL || end - p <= n)
        return NULL;
    while (n > 0)
        *p++ = tmp[--n];
    *p = 0;
    return p;
}

inline char* SalUpdAppendText(char* p, char* end, const char* text)
{
    if (p == NULL)
        return NULL;
    size_t n = strlen(text);
    if ((size_t)(end - p) <= n)
        return NULL;
    memcpy(p, text, n + 1);
    return p + n;
}

inline char* SalUpdAppendVersion(char* p, char* end, const CSalUpdVersion& v)
{
    p = SalUpdAppendNumber(p, end, v.Major);
    p = SalUpdAppendText(p, end, ".");
    p = SalUpdAppendNumber(p, end, v.Minor);
    p = SalUpdAppendText(p, end, ".");
    p = SalUpdAppendNumber(p, end, v.Patch);
    return p;
}

// prints "<major>.<minor>.<patch>"; FALSE (and an empty string) when it does not fit
inline BOOL SalUpdFormatVersion(const CSalUpdVersion& v, char* buf, int bufSize)
{
    if (buf == NULL || bufSize <= 0)
        return FALSE;
    buf[0] = 0;
    if (SalUpdAppendVersion(buf, buf + bufSize, v) == NULL)
    {
        buf[0] = 0;
        return FALSE;
    }
    return TRUE;
}

//
// ****************************************************************************
// The addresses the program offers to open - constructed, never taken from
// the answer
//

#define SALUPD_RELEASES_URL "https://github.com/tandemcommander/tandemcommander/releases/"

// https://github.com/tandemcommander/tandemcommander/releases/download/v<ver>/tandemcommander-<ver>-x64-setup.exe
inline BOOL SalUpdInstallerUrl(const CSalUpdVersion& v, char* buf, int bufSize)
{
    if (buf == NULL || bufSize <= 0)
        return FALSE;
    char* end = buf + bufSize;
    buf[0] = 0;
    char* p = SalUpdAppendText(buf, end, SALUPD_RELEASES_URL "download/v");
    p = SalUpdAppendVersion(p, end, v);
    p = SalUpdAppendText(p, end, "/tandemcommander-");
    p = SalUpdAppendVersion(p, end, v);
    p = SalUpdAppendText(p, end, "-x64-setup.exe");
    if (p == NULL)
        buf[0] = 0;
    return p != NULL;
}

// tandemcommander-<ver>-x64-setup.exe
inline BOOL SalUpdInstallerName(const CSalUpdVersion& v, char* buf, int bufSize)
{
    if (buf == NULL || bufSize <= 0)
        return FALSE;
    char* end = buf + bufSize;
    buf[0] = 0;
    char* p = SalUpdAppendText(buf, end, "tandemcommander-");
    p = SalUpdAppendVersion(p, end, v);
    p = SalUpdAppendText(p, end, "-x64-setup.exe");
    if (p == NULL)
        buf[0] = 0;
    return p != NULL;
}

// https://github.com/tandemcommander/tandemcommander/releases/tag/v<ver>
inline BOOL SalUpdReleaseNotesUrl(const CSalUpdVersion& v, char* buf, int bufSize)
{
    if (buf == NULL || bufSize <= 0)
        return FALSE;
    char* end = buf + bufSize;
    buf[0] = 0;
    char* p = SalUpdAppendText(buf, end, SALUPD_RELEASES_URL "tag/v");
    p = SalUpdAppendVersion(p, end, v);
    if (p == NULL)
        buf[0] = 0;
    return p != NULL;
}

//
// ****************************************************************************
// Time
//

// Parses exactly "YYYY-MM-DDThh:mm:ssZ" (20 bytes) into a UTC FILETIME value.
// Only a real date and time passes (no 30 February, no 24:00:00, year >= 1601).
inline BOOL SalUpdParseUtcTime(const char* s, int len, ULONGLONG* fileTime)
{
    if (s == NULL || fileTime == NULL)
        return FALSE;
    if (len < 0)
        len = (int)strlen(s);
    if (len != 20)
        return FALSE;
    static const char pattern[] = "dddd-dd-ddTdd:dd:ddZ";
    for (int i = 0; i < 20; i++)
    {
        if (pattern[i] == 'd')
        {
            if (s[i] < '0' || s[i] > '9')
                return FALSE;
        }
        else if (s[i] != pattern[i])
            return FALSE;
    }
    SYSTEMTIME st;
    memset(&st, 0, sizeof(st));
    st.wYear = (WORD)((s[0] - '0') * 1000 + (s[1] - '0') * 100 + (s[2] - '0') * 10 + (s[3] - '0'));
    st.wMonth = (WORD)((s[5] - '0') * 10 + (s[6] - '0'));
    st.wDay = (WORD)((s[8] - '0') * 10 + (s[9] - '0'));
    st.wHour = (WORD)((s[11] - '0') * 10 + (s[12] - '0'));
    st.wMinute = (WORD)((s[14] - '0') * 10 + (s[15] - '0'));
    st.wSecond = (WORD)((s[17] - '0') * 10 + (s[18] - '0'));
    // SystemTimeToFileTime accepts second 60 on some systems (leap second) - a
    // release time never carries one, refuse it for a stable rule
    if (st.wYear < 1601 || st.wMonth < 1 || st.wMonth > 12 || st.wDay < 1 ||
        st.wHour > 23 || st.wMinute > 59 || st.wSecond > 59)
        return FALSE;
    static const WORD daysInMonth[12] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
    WORD maxDay = daysInMonth[st.wMonth - 1];
    if (st.wMonth == 2 && (st.wYear % 4 == 0 && (st.wYear % 100 != 0 || st.wYear % 400 == 0)))
        maxDay = 29;
    if (st.wDay > maxDay)
        return FALSE;
    FILETIME ft;
    if (!SystemTimeToFileTime(&st, &ft))
        return FALSE;
    *fileTime = ((ULONGLONG)ft.dwHighDateTime << 32) | ft.dwLowDateTime;
    return TRUE;
}

// Removes the day of the week ("dddd" or "ddd") from a Windows date picture
// (LOCALE_SLONGDATE), with the separators that would be left hanging: the
// notification shows "14 October 2026", not "Wednesday, 14 October 2026".
// Text in single quotes is literal and is left alone. Works in place.
inline void SalUpdStripWeekday(WCHAR* picture)
{
    if (picture == NULL)
        return;
    BOOL quoted = FALSE;
    for (int i = 0; picture[i] != 0; i++)
    {
        if (picture[i] == L'\'')
        {
            quoted = !quoted;
            continue;
        }
        if (quoted || picture[i] != L'd')
            continue;
        int run = 1;
        while (picture[i + run] == L'd')
            run++;
        if (run < 3) // "d" and "dd" are the day of the month
        {
            i += run - 1;
            continue;
        }
        int end = i + run;
        // separators after the name - also a quoted literal made of nothing else (se-FI:
        // "dddd', 'MMMM d") - and, when the name stood last, the ones before it
        for (;;)
        {
            while (picture[end] == L' ' || picture[end] == L',' || picture[end] == 0x00A0)
                end++;
            if (picture[end] != L'\'')
                break;
            int q = end + 1;
            while (picture[q] == L' ' || picture[q] == L',' || picture[q] == 0x00A0)
                q++;
            if (picture[q] != L'\'' || q == end + 1)
                break; // the literal holds something else (or is the escaped quote '')
            end = q + 1;
        }
        int start = i;
        if (picture[end] == 0)
        {
            while (start > 0 && (picture[start - 1] == L' ' || picture[start - 1] == L',' || picture[start - 1] == 0x00A0))
                start--;
        }
        int k = 0;
        while (picture[end + k] != 0)
        {
            picture[start + k] = picture[end + k];
            k++;
        }
        picture[start + k] = 0;
        i = start - 1;
    }
}

//
// ****************************************************************************
// Release record and results
//

struct CSalUpdRelease
{
    CSalUpdVersion Version;
    ULONGLONG PublishedUtc;                   // UTC FILETIME of 'published_at'
    char PublishedText[SALUPD_TIME_TEXT_MAX]; // 'published_at' as received (validated, 20 ASCII bytes)
};

enum CSalUpdResult
{
    surNewer,       // valid release, version > installed
    surUpToDate,    // valid release, version <= installed
    surUnreachable, // no HTTP answer (no connection, DNS, TLS, timeout)
    surRefused,     // HTTP 403 / 429 (rate limit)
    surUnexpected,  // any other status, oversized, not JSON, record fails validation
    surCancelled    // the user cancelled, or the program is closing
};

inline const char* SalUpdResultName(CSalUpdResult r)
{
    switch (r)
    {
    case surNewer:
        return "newer";
    case surUpToDate:
        return "up-to-date";
    case surUnreachable:
        return "unreachable";
    case surRefused:
        return "refused";
    case surUnexpected:
        return "unexpected";
    case surCancelled:
        return "cancelled";
    }
    return "unknown";
}

// only a valid answer replaces what the program knows (stored-state.md, rule 4)
inline BOOL SalUpdResultIsKnowledge(CSalUpdResult r) { return r == surNewer || r == surUpToDate; }

// TRUE when an attempt that ended with 'r' received an HTTP status - it used
// the user's daily contact with the source (research R5)
inline BOOL SalUpdResultWasAnswered(CSalUpdResult r)
{
    return r == surNewer || r == surUpToDate || r == surRefused || r == surUnexpected;
}

// What an HTTP status means before any body is read. Returns TRUE when the
// body should be read (status 200); otherwise stores the result class.
inline BOOL SalUpdStatusWantsBody(DWORD status, CSalUpdResult* result)
{
    if (status == 200)
        return TRUE;
    if (result != NULL)
        *result = (status == 403 || status == 429) ? surRefused : surUnexpected;
    return FALSE;
}

inline CSalUpdResult SalUpdClassify(const CSalUpdRelease& release, const CSalUpdVersion& installed)
{
    return SalUpdVersionCompare(release.Version, installed) > 0 ? surNewer : surUpToDate;
}

// The start-up notification is wanted for a newer version the user did not skip.
inline BOOL SalUpdStartupNoticeWanted(CSalUpdResult result, const CSalUpdVersion& latest,
                                      BOOL hasSkipped, const CSalUpdVersion& skipped)
{
    if (result != surNewer)
        return FALSE;
    return !hasSkipped || SalUpdVersionCompare(latest, skipped) != 0;
}

// what the About dialog can say from the stored values alone
enum CSalUpdKnownState
{
    suksNotChecked,
    suksUpToDate,
    suksNewer
};

inline CSalUpdKnownState SalUpdKnownState(BOOL hasLatest, const CSalUpdVersion& latest,
                                          const CSalUpdVersion& installed)
{
    if (!hasLatest)
        return suksNotChecked;
    return SalUpdVersionCompare(latest, installed) > 0 ? suksNewer : suksUpToDate;
}

// Is an automatic check due? Not when the option is off. Due when there was
// no attempt yet or its time lies in the future (a wrong or changed clock
// must not stop checks for good). Otherwise due after 24 hours when the last
// attempt was answered, after 1 hour when the source was not reached at all.
inline BOOL SalUpdAutoCheckDue(BOOL checkAtStartup, BOOL hasLastAttempt, ULONGLONG lastAttempt,
                               BOOL lastAttemptAnswered, ULONGLONG now)
{
    if (!checkAtStartup)
        return FALSE;
    if (!hasLastAttempt || lastAttempt > now)
        return TRUE;
    ULONGLONG interval = lastAttemptAnswered ? SALUPD_INTERVAL_ANSWERED : SALUPD_INTERVAL_UNREACHED;
    return now - lastAttempt >= interval;
}

//
// ****************************************************************************
// A small strict JSON reader
//
// The text encoding is NOT checked: bytes of 0x80 and above pass through
// strings unchanged, valid UTF-8 or not. That is harmless here - every name
// and value the program reads is compared byte for byte with ASCII text, and
// nothing from the answer is displayed - but do not reuse this reader where
// text from the answer is shown or handed on. After a failed ReadString the
// output buffer holds an unterminated fragment; callers must not look at it.
//
// Recognises the whole grammar (RFC 8259) so that values the program does not
// read are skipped correctly - a search for "tag_name" in the text would be
// fooled by the release body, which is free text. Nesting is limited to
// SALUPD_MAX_DEPTH. Strings the program reads are unescaped into a caller's
// buffer (\uXXXX incl. surrogate pairs -> UTF-8); a string that does not fit,
// contains an escaped NUL or an unpaired surrogate escape is reported as
// "bad" without failing the grammar.
//

class CSalUpdJsonReader
{
public:
    CSalUpdJsonReader(const char* data, size_t len)
    {
        P = (const unsigned char*)data;
        End = P + (data != NULL ? len : 0);
        Failed = (data == NULL);
    }

    BOOL IsFailed() const { return Failed; }
    BOOL AtEnd()
    {
        SkipSpace();
        return P == End;
    }

    void SkipSpace()
    {
        while (P < End && (*P == ' ' || *P == '\t' || *P == '\n' || *P == '\r'))
            P++;
    }

    // the next non-space byte, or 0 at the end
    int Peek()
    {
        SkipSpace();
        return P < End ? *P : 0;
    }

    BOOL Expect(char c)
    {
        SkipSpace();
        if (Failed || P >= End || *P != (unsigned char)c)
            return Fail();
        P++;
        return TRUE;
    }

    // Reads a string. 'out' NULL: only checked and skipped. Otherwise the
    // unescaped text goes to 'out' (zero-terminated); '*bad' is set when the
    // text does not fit 'outSize', holds an escaped NUL or an unpaired
    // surrogate escape - 'out' is then empty.
    BOOL ReadString(char* out, int outSize, BOOL* bad)
    {
        if (bad != NULL)
            *bad = FALSE;
        if (out != NULL && outSize > 0)
            out[0] = 0;
        if (!Expect('"'))
            return FALSE;
        int o = 0;
        BOOL isBad = FALSE;
        for (;;)
        {
            if (P >= End)
                return Fail();
            unsigned c = *P++;
            if (c == '"')
                break;
            if (c < 0x20)
                return Fail(); // control characters must be escaped
            unsigned cp = c;
            BOOL raw = TRUE; // a byte copied as it is (UTF-8 passes through unchanged)
            if (c == '\\')
            {
                if (P >= End)
                    return Fail();
                unsigned e = *P++;
                raw = FALSE;
                switch (e)
                {
                case '"':
                    cp = '"';
                    break;
                case '\\':
                    cp = '\\';
                    break;
                case '/':
                    cp = '/';
                    break;
                case 'b':
                    cp = '\b';
                    break;
                case 'f':
                    cp = '\f';
                    break;
                case 'n':
                    cp = '\n';
                    break;
                case 'r':
                    cp = '\r';
                    break;
                case 't':
                    cp = '\t';
                    break;
                case 'u':
                {
                    if (!ReadHex4(&cp))
                        return FALSE;
                    if (cp >= 0xD800 && cp <= 0xDBFF)
                    {
                        // a high surrogate must be followed by an escaped low one
                        if (End - P >= 6 && P[0] == '\\' && P[1] == 'u')
                        {
                            const unsigned char* save = P;
                            P += 2;
                            unsigned lo;
                            if (!ReadHex4(&lo))
                                return FALSE;
                            if (lo >= 0xDC00 && lo <= 0xDFFF)
                                cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00);
                            else
                            {
                                P = save; // not a pair: the next escape is read on its own
                                isBad = TRUE;
                                cp = 0xFFFD;
                            }
                        }
                        else
                        {
                            isBad = TRUE;
                            cp = 0xFFFD;
                        }
                    }
                    else if (cp >= 0xDC00 && cp <= 0xDFFF)
                    {
                        isBad = TRUE;
                        cp = 0xFFFD;
                    }
                    else if (cp == 0)
                        isBad = TRUE;
                    break;
                }
                default:
                    return Fail();
                }
            }
            if (out == NULL || isBad)
                continue;
            // store 'cp' (a raw byte as it is, an escape as UTF-8)
            char enc[4];
            int n;
            if (raw || cp < 0x80)
            {
                enc[0] = (char)cp;
                n = 1;
            }
            else if (cp < 0x800)
            {
                enc[0] = (char)(0xC0 | (cp >> 6));
                enc[1] = (char)(0x80 | (cp & 0x3F));
                n = 2;
            }
            else if (cp < 0x10000)
            {
                enc[0] = (char)(0xE0 | (cp >> 12));
                enc[1] = (char)(0x80 | ((cp >> 6) & 0x3F));
                enc[2] = (char)(0x80 | (cp & 0x3F));
                n = 3;
            }
            else
            {
                enc[0] = (char)(0xF0 | (cp >> 18));
                enc[1] = (char)(0x80 | ((cp >> 12) & 0x3F));
                enc[2] = (char)(0x80 | ((cp >> 6) & 0x3F));
                enc[3] = (char)(0x80 | (cp & 0x3F));
                n = 4;
            }
            if (o + n >= outSize)
                isBad = TRUE; // does not fit
            else
            {
                memcpy(out + o, enc, n);
                o += n;
            }
        }
        if (out != NULL && outSize > 0)
        {
            if (isBad)
                out[0] = 0;
            else
                out[o] = 0;
        }
        if (bad != NULL)
            *bad = isBad;
        return TRUE;
    }

    // true / false / null; 'value': 1, 0, -1
    BOOL ReadLiteral(int* value)
    {
        SkipSpace();
        if (Failed)
            return FALSE;
        size_t left = (size_t)(End - P);
        if (left >= 4 && memcmp(P, "true", 4) == 0)
        {
            P += 4;
            if (value != NULL)
                *value = 1;
            return TRUE;
        }
        if (left >= 5 && memcmp(P, "false", 5) == 0)
        {
            P += 5;
            if (value != NULL)
                *value = 0;
            return TRUE;
        }
        if (left >= 4 && memcmp(P, "null", 4) == 0)
        {
            P += 4;
            if (value != NULL)
                *value = -1;
            return TRUE;
        }
        return Fail();
    }

    BOOL SkipNumber()
    {
        SkipSpace();
        if (Failed)
            return FALSE;
        if (P < End && *P == '-')
            P++;
        if (P >= End)
            return Fail();
        if (*P == '0')
            P++;
        else if (*P >= '1' && *P <= '9')
        {
            while (P < End && *P >= '0' && *P <= '9')
                P++;
        }
        else
            return Fail();
        if (P < End && *P == '.')
        {
            P++;
            if (P >= End || *P < '0' || *P > '9')
                return Fail();
            while (P < End && *P >= '0' && *P <= '9')
                P++;
        }
        if (P < End && (*P == 'e' || *P == 'E'))
        {
            P++;
            if (P < End && (*P == '+' || *P == '-'))
                P++;
            if (P >= End || *P < '0' || *P > '9')
                return Fail();
            while (P < End && *P >= '0' && *P <= '9')
                P++;
        }
        return TRUE;
    }

    // skips any value; 'depth' is the nesting level of the value itself (the
    // top-level value is 1)
    BOOL SkipValue(int depth)
    {
        if (Failed)
            return FALSE;
        int c = Peek();
        if (c == '"')
            return ReadString(NULL, 0, NULL);
        if (c == '{')
        {
            if (depth > SALUPD_MAX_DEPTH)
                return Fail();
            P++;
            if (Peek() == '}')
            {
                P++;
                return TRUE;
            }
            for (;;)
            {
                if (!ReadString(NULL, 0, NULL) || !Expect(':') || !SkipValue(depth + 1))
                    return FALSE;
                int d = Peek();
                if (d == ',')
                {
                    P++;
                    continue;
                }
                if (d == '}')
                {
                    P++;
                    return TRUE;
                }
                return Fail();
            }
        }
        if (c == '[')
        {
            if (depth > SALUPD_MAX_DEPTH)
                return Fail();
            P++;
            if (Peek() == ']')
            {
                P++;
                return TRUE;
            }
            for (;;)
            {
                if (!SkipValue(depth + 1))
                    return FALSE;
                int d = Peek();
                if (d == ',')
                {
                    P++;
                    continue;
                }
                if (d == ']')
                {
                    P++;
                    return TRUE;
                }
                return Fail();
            }
        }
        if (c == 't' || c == 'f' || c == 'n')
            return ReadLiteral(NULL);
        if (c == '-' || (c >= '0' && c <= '9'))
            return SkipNumber();
        return Fail();
    }

    // moves over one byte that Peek() returned
    void Advance()
    {
        if (P < End)
            P++;
    }

    BOOL Fail()
    {
        Failed = TRUE;
        return FALSE;
    }

protected:
    BOOL ReadHex4(unsigned* value)
    {
        if (End - P < 4)
            return Fail();
        unsigned v = 0;
        for (int i = 0; i < 4; i++)
        {
            unsigned c = P[i];
            unsigned d;
            if (c >= '0' && c <= '9')
                d = c - '0';
            else if (c >= 'a' && c <= 'f')
                d = c - 'a' + 10;
            else if (c >= 'A' && c <= 'F')
                d = c - 'A' + 10;
            else
                return Fail();
            v = (v << 4) | d;
        }
        P += 4;
        *value = v;
        return TRUE;
    }

    const unsigned char* P;
    const unsigned char* End;
    BOOL Failed;
};

//
// ****************************************************************************
// The release record (contracts/update-source.md, "Fields read")
//

// why a record was not accepted - for traces and tests only, never shown
enum CSalUpdParseError
{
    supeNone,
    supeNotJson,      // not a well-formed JSON object (or nested too deep, or trailing bytes)
    supeMissingField, // a required member is missing
    supeDuplicate,    // a member the program reads occurs twice
    supeDraft,        // "draft" is not false
    supePrerelease,   // "prerelease" is not false
    supeBadTag,       // "tag_name" is not v<major>.<minor>.<patch>
    supeBadTime,      // "published_at" is not a valid UTC time
    supeForeignNotes, // "html_url" is not the constructed release-notes address
    supeNoInstaller   // no uploaded asset with the expected name and the constructed address
};

struct CSalUpdTopFields
{
    BOOL HasDraft, HasPrerelease, HasTag, HasPublished, HasHtmlUrl, HasAssets;
    int Draft, Prerelease; // 1 true, 0 false, -1 null, -2 another type
    BOOL TagBad, PublishedBad, HtmlUrlBad;
    char Tag[SALUPD_MAX_STRING];
    char Published[SALUPD_MAX_STRING];
    char HtmlUrl[SALUPD_MAX_STRING];
};

// reads a string member's value, or skips a value of another type ('*isString' FALSE)
inline BOOL SalUpdReadStringMember(CSalUpdJsonReader& r, int depth, char* out, int outSize,
                                   BOOL* bad, BOOL* isString)
{
    if (r.Peek() == '"')
    {
        *isString = TRUE;
        return r.ReadString(out, outSize, bad);
    }
    *isString = FALSE;
    *bad = TRUE;
    if (outSize > 0)
        out[0] = 0;
    return r.SkipValue(depth);
}

// One asset object. '*matches' TRUE when it is the expected installer:
// name == 'wantName', state == "uploaded", browser_download_url == 'wantUrl',
// each member present exactly once.
inline BOOL SalUpdReadAsset(CSalUpdJsonReader& r, const char* wantName, const char* wantUrl, BOOL* matches)
{
    *matches = FALSE;
    if (r.Peek() != '{')
        return r.SkipValue(3); // not an object: skipped, cannot match
    r.Advance();
    int names = 0, states = 0, urls = 0;
    BOOL nameOk = FALSE, stateOk = FALSE, urlOk = FALSE;
    if (r.Peek() == '}')
    {
        r.Advance();
        return TRUE;
    }
    for (;;)
    {
        char key[40];
        BOOL keyBad;
        if (!r.ReadString(key, sizeof(key), &keyBad) || !r.Expect(':'))
            return FALSE;
        char value[SALUPD_MAX_STRING];
        BOOL bad, isString;
        if (!keyBad && strcmp(key, "name") == 0)
        {
            if (!SalUpdReadStringMember(r, 4, value, sizeof(value), &bad, &isString))
                return FALSE;
            names++;
            nameOk = isString && !bad && strcmp(value, wantName) == 0;
        }
        else if (!keyBad && strcmp(key, "state") == 0)
        {
            if (!SalUpdReadStringMember(r, 4, value, sizeof(value), &bad, &isString))
                return FALSE;
            states++;
            stateOk = isString && !bad && strcmp(value, "uploaded") == 0;
        }
        else if (!keyBad && strcmp(key, "browser_download_url") == 0)
        {
            if (!SalUpdReadStringMember(r, 4, value, sizeof(value), &bad, &isString))
                return FALSE;
            urls++;
            urlOk = isString && !bad && strcmp(value, wantUrl) == 0;
        }
        else if (!r.SkipValue(4))
            return FALSE;
        int d = r.Peek();
        if (d == ',')
        {
            r.Advance();
            continue;
        }
        if (d == '}')
        {
            r.Advance();
            break;
        }
        return r.Fail();
    }
    *matches = names == 1 && states == 1 && urls == 1 && nameOk && stateOk && urlOk;
    return TRUE;
}

// One pass over the top-level object. 'top' != NULL: the scalar members are
// collected and "assets" is skipped. 'top' == NULL: only "assets" is examined
// for the expected installer ('*installerFound'). Returns FALSE when the text
// is not a well-formed JSON object followed by nothing but white space;
// '*duplicate' reports a repeated member of interest.
inline BOOL SalUpdScanTop(const char* data, size_t len, CSalUpdTopFields* top,
                          const char* wantName, const char* wantUrl, BOOL* installerFound,
                          BOOL* duplicate)
{
    CSalUpdJsonReader r(data, len);
    *duplicate = FALSE;
    if (installerFound != NULL)
        *installerFound = FALSE;
    if (top != NULL)
        memset(top, 0, sizeof(*top));
    int assetsSeen = 0;
    if (!r.Expect('{'))
        return FALSE;
    if (r.Peek() == '}')
        r.Advance();
    else
    {
        for (;;)
        {
            char key[40];
            BOOL keyBad;
            if (!r.ReadString(key, sizeof(key), &keyBad) || !r.Expect(':'))
                return FALSE;
            BOOL isString;
            if (!keyBad && strcmp(key, "assets") == 0)
            {
                assetsSeen++;
                if (top != NULL)
                    top->HasAssets = TRUE;
                if (top != NULL || r.Peek() != '[')
                {
                    if (!r.SkipValue(2))
                        return FALSE;
                }
                else
                {
                    r.Advance();
                    if (r.Peek() == ']')
                        r.Advance();
                    else
                    {
                        for (;;)
                        {
                            BOOL matches;
                            if (!SalUpdReadAsset(r, wantName, wantUrl, &matches))
                                return FALSE;
                            if (matches && installerFound != NULL)
                                *installerFound = TRUE;
                            int d = r.Peek();
                            if (d == ',')
                            {
                                r.Advance();
                                continue;
                            }
                            if (d == ']')
                            {
                                r.Advance();
                                break;
                            }
                            return r.Fail();
                        }
                    }
                }
            }
            else if (top != NULL && !keyBad && strcmp(key, "draft") == 0)
            {
                if (top->HasDraft)
                    *duplicate = TRUE;
                top->HasDraft = TRUE;
                int c = r.Peek();
                if (c == 't' || c == 'f' || c == 'n')
                {
                    if (!r.ReadLiteral(&top->Draft))
                        return FALSE;
                }
                else
                {
                    top->Draft = -2;
                    if (!r.SkipValue(2))
                        return FALSE;
                }
            }
            else if (top != NULL && !keyBad && strcmp(key, "prerelease") == 0)
            {
                if (top->HasPrerelease)
                    *duplicate = TRUE;
                top->HasPrerelease = TRUE;
                int c = r.Peek();
                if (c == 't' || c == 'f' || c == 'n')
                {
                    if (!r.ReadLiteral(&top->Prerelease))
                        return FALSE;
                }
                else
                {
                    top->Prerelease = -2;
                    if (!r.SkipValue(2))
                        return FALSE;
                }
            }
            else if (top != NULL && !keyBad && strcmp(key, "tag_name") == 0)
            {
                if (top->HasTag)
                    *duplicate = TRUE;
                top->HasTag = TRUE;
                if (!SalUpdReadStringMember(r, 2, top->Tag, sizeof(top->Tag), &top->TagBad, &isString))
                    return FALSE;
            }
            else if (top != NULL && !keyBad && strcmp(key, "published_at") == 0)
            {
                if (top->HasPublished)
                    *duplicate = TRUE;
                top->HasPublished = TRUE;
                if (!SalUpdReadStringMember(r, 2, top->Published, sizeof(top->Published),
                                            &top->PublishedBad, &isString))
                    return FALSE;
            }
            else if (top != NULL && !keyBad && strcmp(key, "html_url") == 0)
            {
                if (top->HasHtmlUrl)
                    *duplicate = TRUE;
                top->HasHtmlUrl = TRUE;
                if (!SalUpdReadStringMember(r, 2, top->HtmlUrl, sizeof(top->HtmlUrl),
                                            &top->HtmlUrlBad, &isString))
                    return FALSE;
            }
            else if (!r.SkipValue(2))
                return FALSE;

            int d = r.Peek();
            if (d == ',')
            {
                r.Advance();
                continue;
            }
            if (d == '}')
            {
                r.Advance();
                break;
            }
            return r.Fail();
        }
    }
    if (r.IsFailed() || !r.AtEnd())
        return FALSE;
    if (assetsSeen > 1)
        *duplicate = TRUE;
    return TRUE;
}

// Accepts the body of a "latest release" answer, or says why not. On success
// 'release' holds the version and the publication time; the addresses are
// rebuilt from the version whenever needed (SalUpdInstallerUrl,
// SalUpdReleaseNotesUrl) and are guaranteed to be the ones the record named.
inline BOOL SalUpdParseLatestRelease(const char* data, size_t len, CSalUpdRelease* release,
                                     CSalUpdParseError* error = NULL)
{
    CSalUpdParseError dummy;
    if (error == NULL)
        error = &dummy;
    *error = supeNotJson;
    if (release != NULL)
        memset(release, 0, sizeof(*release));
    if (data == NULL || release == NULL || len == 0 || len > SALUPD_MAX_ANSWER)
        return FALSE;

    // 'static' would make the function non-reentrant; the structure is 1.6 KB, fine on the stack
    CSalUpdTopFields top;
    BOOL duplicate;
    if (!SalUpdScanTop(data, len, &top, NULL, NULL, NULL, &duplicate))
        return FALSE;
    if (duplicate)
    {
        *error = supeDuplicate;
        return FALSE;
    }
    if (!top.HasDraft || !top.HasPrerelease || !top.HasTag || !top.HasPublished ||
        !top.HasHtmlUrl || !top.HasAssets)
    {
        *error = supeMissingField;
        return FALSE;
    }
    if (top.Draft != 0)
    {
        *error = supeDraft;
        return FALSE;
    }
    if (top.Prerelease != 0)
    {
        *error = supePrerelease;
        return FALSE;
    }
    CSalUpdVersion version;
    char canonicalTag[SALUPD_VERSION_TEXT_MAX + 1];
    canonicalTag[0] = 'v';
    // the tag must be the canonical print of its numbers: "v00.01.009" is not a tag of ours
    if (top.TagBad || !SalUpdParseVersion(top.Tag, -1, TRUE, &version) ||
        !SalUpdFormatVersion(version, canonicalTag + 1, sizeof(canonicalTag) - 1) ||
        strcmp(top.Tag, canonicalTag) != 0)
    {
        *error = supeBadTag;
        return FALSE;
    }
    ULONGLONG published;
    if (top.PublishedBad || !SalUpdParseUtcTime(top.Published, -1, &published))
    {
        *error = supeBadTime;
        return FALSE;
    }
    char wantNotes[SALUPD_URL_MAX];
    char wantUrl[SALUPD_URL_MAX];
    char wantName[SALUPD_URL_MAX];
    if (!SalUpdReleaseNotesUrl(version, wantNotes, sizeof(wantNotes)) ||
        !SalUpdInstallerUrl(version, wantUrl, sizeof(wantUrl)) ||
        !SalUpdInstallerName(version, wantName, sizeof(wantName)))
    {
        *error = supeBadTag;
        return FALSE;
    }
    // exact comparison with the addresses built from the numbers
    if (top.HtmlUrlBad || strcmp(top.HtmlUrl, wantNotes) != 0)
    {
        *error = supeForeignNotes;
        return FALSE;
    }
    BOOL installerFound;
    if (!SalUpdScanTop(data, len, NULL, wantName, wantUrl, &installerFound, &duplicate))
        return FALSE; // cannot happen after the first pass; kept for safety
    if (duplicate)
    {
        *error = supeDuplicate;
        return FALSE;
    }
    if (!installerFound)
    {
        *error = supeNoInstaller;
        return FALSE;
    }
    release->Version = version;
    release->PublishedUtc = published;
    memcpy(release->PublishedText, top.Published, 20);
    release->PublishedText[20] = 0;
    *error = supeNone;
    return TRUE;
}

//
// ****************************************************************************
// The Debug-only test seam (research R11): TC_UPDATECHECK_URL may point the
// request at a fixture server on the loopback interface. Only
// "http://127.0.0.1:<port>/<path>" is accepted - plain HTTP, the literal
// loopback address, an explicit port. The parser lives here so that the rule
// is tested; the core calls it in Debug builds only.
//

inline BOOL SalUpdParseLoopbackUrl(const WCHAR* url, int* port, WCHAR* path, int pathSize)
{
    static const WCHAR prefix[] = L"http://127.0.0.1:";
    const int prefixLen = (int)(sizeof(prefix) / sizeof(prefix[0])) - 1;
    if (url == NULL || port == NULL || path == NULL || pathSize <= 1)
        return FALSE;
    for (int i = 0; i < prefixLen; i++)
    {
        if (url[i] != prefix[i])
            return FALSE;
    }
    const WCHAR* p = url + prefixLen;
    int digits = 0;
    int value = 0;
    while (*p >= L'0' && *p <= L'9')
    {
        if (++digits > 5)
            return FALSE;
        value = value * 10 + (*p - L'0');
        p++;
    }
    if (digits == 0 || value < 1 || value > 65535 || *p != L'/' || url[prefixLen] == L'0')
        return FALSE;
    int n = 0;
    while (p[n] != 0)
    {
        // a plain path: printable ASCII without anything that needs encoding or could start a new header
        if (p[n] <= 0x20 || p[n] >= 0x7F || p[n] == L'#')
            return FALSE;
        n++;
    }
    if (n >= pathSize)
        return FALSE;
    memcpy(path, p, (n + 1) * sizeof(WCHAR));
    *port = value;
    return TRUE;
}
