// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later
//
// Feature 092, stages S4 and S5 - evidence probe for the path decisions ("the
// same path", "this path is under that one") and for the sorted name lists
// (the pattern of 075's probe and of case_only_probe.cpp beside this file).
//
//   OLD = the rule the converted sites used: StrICmp / StrNICmp (x64 bodies of
//         src/common/str.cpp over a table built by CharLowerA exactly as
//         InitializeCase() builds LowerCase[]) and IsTheSamePath (body copied
//         verbatim from src/salamdr1.cpp).
//   NEW = SalNameCompareOrdinalCI / SalNameEqualOrdinalCI / SalPathEqualOrdinalCI /
//         SalPathHasPrefixOrdinalCI from src/common/salunicode.cpp, compiled
//         into this probe from the product's source.
//   NTFS = where two NAMES are compared, the file system's own answer: a file
//         is created under the first name in an empty scratch folder; does
//         opening the second name find it?
//
// A row passes when NEW gives the expected value (and agrees with NTFS where
// NTFS was asked); a row marked ASCII must also give the same answer under OLD.
// OLD's answers for non-ASCII rows depend on the system code page and are only
// shown. Exit code 0 = every row passed. This source is pure ASCII on purpose:
// every name is written with \x escapes.

#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "salunicode.h"

//
// ---- OLD: str.cpp (x64 branch) and salamdr1.cpp, verbatim -----------------
//

static BYTE LowerCase[256];

static void InitializeCase()
{
    int i;
    for (i = 0; i < 256; i++)
        LowerCase[i] = (char)(UINT_PTR)CharLowerA((LPSTR)(UINT_PTR)i);
}

// the probe is compiled with /J like the product, so *s1 is an unsigned index
static int StrICmp(const char* s1, const char* s2)
{
    int res;
    while (1)
    {
        res = (unsigned)LowerCase[*s1] - (unsigned)LowerCase[*s2++];
        if (res != 0)
            return (res < 0) ? -1 : 1; // < a >
        if (*s1++ == 0)
            return 0; // ==
    }
}

static int StrNICmp(const char* s1, const char* s2, int n)
{
    int res;
    while (n--)
    {
        res = (unsigned)LowerCase[*s1] - (unsigned)LowerCase[*s2++];
        if (res != 0)
            return (res < 0) ? -1 : 1; // < a >
        if (*s1++ == 0)
            return 0; // ==
    }
    return 0;
}

static BOOL IsTheSamePath(const char* path1, const char* path2)
{
    if (*path1 == '\\')
        path1++;
    if (*path2 == '\\')
        path2++;
    while (*path1 != 0 && LowerCase[*path1] == LowerCase[*path2])
    {
        path1++;
        path2++;
    }
    if (*path1 == '\\')
        path1++;
    if (*path2 == '\\')
        path2++;
    return *path1 == 0 && *path2 == 0;
}

static int NewCmp(const char* a, const char* b) { return SalNameCompareOrdinalCI(a, -1, b, -1); }

//
// ---- bookkeeping -----------------------------------------------------------
//

static int Rows = 0;
static int Failed = 0;
static int AsciiRows = 0;
static int OldFalseDifferent = 0; // OLD said "different" where the expected answer is "same"
static int OldFalseSame = 0;      // OLD said "same" where the expected answer is "different"
static int FsErrors = 0;
static WCHAR ScratchDir[MAX_PATH + 40];
static BOOL IsNtfs = FALSE;

static const char* YN(BOOL b) { return b ? "same" : "diff"; }

// one row: 'ntfs' is -1 when the file system was not asked
static void Row(const char* label, BOOL oldV, BOOL newV, BOOL expected, int ntfs, BOOL ascii)
{
    Rows++;
    BOOL good = newV == expected && (ntfs < 0 || (BOOL)ntfs == expected) && (!ascii || oldV == newV);
    if (ascii)
        AsciiRows++;
    if (oldV != expected)
    {
        if (expected)
            OldFalseDifferent++;
        else
            OldFalseSame++;
    }
    if (!good)
        Failed++;
    printf("  %-66s %-5s %-5s %-5s %-5s %s%s\n", label, YN(oldV), YN(newV), YN(expected),
           ntfs < 0 ? "-" : YN(ntfs), good ? "PASS" : "FAIL",
           oldV != expected ? (expected ? "  (OLD: false \"different\")" : "  (OLD: false \"same\")") : "");
}

static void Header(const char* title)
{
    printf("\n%s\n  %-66s %-5s %-5s %-5s %-5s %s\n", title, "row", "OLD", "NEW", "exp.", "NTFS", "verdict");
}

// 1 when, with a file named 'first' alone in the scratch folder, opening 'second' finds it;
// 0 when it does not; -1 on an error (counted)
static int NtfsSame(const char* firstU8, const char* secondU8)
{
    WCHAR first[300], second[300], p1[700], p2[700];
    if (SalU8ToW(firstU8, -1, first, 300) == 0 || SalU8ToW(secondU8, -1, second, 300) == 0)
    {
        FsErrors++;
        return -1;
    }
    swprintf(p1, 700, L"%s\\%s", ScratchDir, first);
    swprintf(p2, 700, L"%s\\%s", ScratchDir, second);
    HANDLE h = CreateFileW(p1, GENERIC_WRITE, 0, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
    if (h == INVALID_HANDLE_VALUE)
    {
        printf("  (cannot create the first file, error %lu)\n", GetLastError());
        FsErrors++;
        return -1;
    }
    CloseHandle(h);
    int same = 0;
    h = CreateFileW(p2, 0, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL,
                    OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (h != INVALID_HANDLE_VALUE)
    {
        same = 1;
        CloseHandle(h);
    }
    else if (GetLastError() != ERROR_FILE_NOT_FOUND)
    {
        printf("  (opening the second name failed with error %lu)\n", GetLastError());
        FsErrors++;
        same = -1;
    }
    if (!DeleteFileW(p1))
    {
        printf("  (cannot delete the first file, error %lu)\n", GetLastError());
        FsErrors++;
        same = -1;
    }
    return same;
}

//
// ---- the names --------------------------------------------------------------
//

#define U_CCARON "\xC4\x8C"      // U+010C
#define L_CCARON "\xC4\x8D"      // U+010D
#define L_AACUTE "\xC3\xA1"      // U+00E1
#define H_CIRC "\xC4\xA5"        // U+0125 (bytes C4 A5)
#define L_ACUTE "\xC4\xB9"       // U+0139 (bytes C4 B9; CP1250 folds A5 to B9)
#define SHARP_S "\xC3\x9F"       // U+00DF
#define COMB_CARON "\xCC\x8C"    // U+030C
#define A_STROKE_U "\xC8\xBA"    // U+023A, 2 bytes
#define A_STROKE_L "\xE2\xB1\xA5" // U+2C65, 3 bytes - the lower case of U+023A

struct CNamePair
{
    const char* Label;
    const char* A;
    const char* B;
    BOOL Expected; // the same name?
    BOOL Ascii;
};

static const CNamePair NamePairs[] = {
    {"ASCII: Dokumenty / DOKUMENTY", "Dokumenty", "DOKUMENTY", TRUE, TRUE},
    {"ASCII: alpha / beta", "alpha", "beta", FALSE, TRUE},
    {"C-caron upper/lower: Cl\\u00E1nek (U+010C / U+010D)", U_CCARON "l" L_AACUTE "nek", L_CCARON "l" L_AACUTE "nek", TRUE, FALSE},
    {"CP1250 collision: U+0125 / U+0139", H_CIRC, L_ACUTE, FALSE, FALSE},
    {"sharp s: stra\\u00DFe / strasse", "stra" SHARP_S "e", "strasse", FALSE, FALSE},
    {"NFC U+010D / NFD c + U+030C", L_CCARON, "c" COMB_CARON, FALSE, FALSE},
    {"unequal UTF-8 length: U+023A (2 bytes) / U+2C65 (3 bytes)", A_STROKE_U, A_STROKE_L, TRUE, FALSE},
};
#define NAME_PAIRS ((int)(sizeof(NamePairs) / sizeof(NamePairs[0])))

//
// ---- (1) IsTheSamePath vs SalPathEqualOrdinalCI ---------------------------
//

static void Section1()
{
    // the backslash matrix, ASCII: every combination against every other
    static const char* lead[] = {"", "\\", "\\\\"};
    static const char* body[] = {"", "a", "A", "a\\b", "A\\B", "ab", "C:", "c:", "C:\\Dir", "c:\\DIR", "srv\\share", "SRV\\Share\\x"};
    static const char* trail[] = {"", "\\", "\\\\"};
    static char paths[3 * 12 * 3][40];
    int count = 0;
    for (int a = 0; a < 3; a++)
        for (int b = 0; b < 12; b++)
            for (int c = 0; c < 3; c++)
                sprintf(paths[count++], "%s%s%s", lead[a], body[b], trail[c]);
    int same = 0, mismatches = 0;
    for (int i = 0; i < count; i++)
        for (int j = 0; j < count; j++)
        {
            BOOL o = IsTheSamePath(paths[i], paths[j]);
            BOOL n = SalPathEqualOrdinalCI(paths[i], paths[j]);
            if (o)
                same++;
            if (o != n)
            {
                if (mismatches < 10)
                    printf("  MISMATCH: \"%s\" vs \"%s\": OLD %s, NEW %s\n", paths[i], paths[j], YN(o), YN(n));
                mismatches++;
            }
        }
    printf("\n(1) IsTheSamePath (OLD) vs SalPathEqualOrdinalCI (NEW)\n");
    Rows++;
    AsciiRows++;
    if (mismatches != 0)
        Failed++;
    printf("  backslash matrix, ASCII: %d paths, %d ordered pairs, %d \"same\" under OLD, %d differences  %s\n",
           count, count * count, same, mismatches, mismatches == 0 ? "PASS" : "FAIL");

    Header("    named pairs as C:\\Dokumenty\\<name> (and with a trailing backslash on one side)");
    for (int i = 0; i < NAME_PAIRS; i++)
    {
        char p1[200], p2[200], p2b[200];
        sprintf(p1, "C:\\Dokumenty\\%s", NamePairs[i].A);
        sprintf(p2, "c:\\dokumenty\\%s", NamePairs[i].B);
        sprintf(p2b, "c:\\dokumenty\\%s\\", NamePairs[i].B);
        int ntfs = NtfsSame(NamePairs[i].A, NamePairs[i].B);
        Row(NamePairs[i].Label, IsTheSamePath(p1, p2), SalPathEqualOrdinalCI(p1, p2), NamePairs[i].Expected, ntfs, NamePairs[i].Ascii);
        Row("    ... second with a trailing backslash", IsTheSamePath(p1, p2b), SalPathEqualOrdinalCI(p1, p2b), NamePairs[i].Expected, -1, NamePairs[i].Ascii);
    }
}

//
// ---- (2) the "l1 == l2 && StrNICmp" shape (CFilesWindowAncestor::SamePath) --
//

static BOOL SamePath_Pre(const char* Path, const char* otherPath)
{
    int l1 = (int)strlen(Path);
    if (l1 > 0 && Path[l1 - 1] == '\\')
        l1--;
    int l2 = (int)strlen(otherPath);
    if (l2 > 0 && otherPath[l2 - 1] == '\\')
        l2--;
    return l1 == l2 && StrNICmp(Path, otherPath, l1) == 0;
}

static BOOL SamePath_Post(const char* Path, const char* otherPath)
{
    int l1 = (int)strlen(Path);
    if (l1 > 0 && Path[l1 - 1] == '\\')
        l1--;
    int l2 = (int)strlen(otherPath);
    if (l2 > 0 && otherPath[l2 - 1] == '\\')
        l2--;
    return SalNameEqualOrdinalCI(Path, l1, otherPath, l2);
}

static void Section2()
{
    Header("(2) \"l1 == l2 && StrNICmp(a, b, l1) == 0\" (SamePath, CTopIndexMem, AddUnique, PrepareSearch)");
    Row("ASCII: C:\\Dir\\ / c:\\dir", SamePath_Pre("C:\\Dir\\", "c:\\dir"), SamePath_Post("C:\\Dir\\", "c:\\dir"), TRUE, -1, TRUE);
    Row("ASCII: C:\\Dir / C:\\Dir2", SamePath_Pre("C:\\Dir", "C:\\Dir2"), SamePath_Post("C:\\Dir", "C:\\Dir2"), FALSE, -1, TRUE);
    Row("ASCII: C:\\Dir2 / C:\\Dir", SamePath_Pre("C:\\Dir2", "C:\\Dir"), SamePath_Post("C:\\Dir2", "C:\\Dir"), FALSE, -1, TRUE);
    Row("ASCII: empty / empty", SamePath_Pre("", ""), SamePath_Post("", ""), TRUE, -1, TRUE);
    Row("ASCII: C:\\ / C:", SamePath_Pre("C:\\", "C:"), SamePath_Post("C:\\", "C:"), TRUE, -1, TRUE);
    for (int i = 2; i < NAME_PAIRS; i++)
    {
        char p1[200], p2[200];
        sprintf(p1, "C:\\Dir\\%s\\", NamePairs[i].A);
        sprintf(p2, "C:\\Dir\\%s", NamePairs[i].B);
        char label[200];
        sprintf(label, "%.48s [bytes %d/%d]", NamePairs[i].Label, (int)strlen(p1) - 1, (int)strlen(p2));
        Row(label, SamePath_Pre(p1, p2), SamePath_Post(p1, p2), NamePairs[i].Expected, -1, FALSE);
    }
}

//
// ---- (3) prefix tests, reversed argument order (fileswn7 / fileswnb / fileswn5) --
//

// the shape of AcceptChangeOnPathNotification / RenameFileInternal: 'prefix' is the first
// StrNICmp argument, the character after it is read from 'path'
static BOOL Under_Pre(const char* prefix, const char* path, int* after)
{
    int len = (int)strlen(prefix);
    *after = len;
    return (int)strlen(path) >= len && // (RenameFileInternal's guard; StrNICmp stops at the end of 'path' anyway)
           StrNICmp(prefix, path, len) == 0 &&
           (path[len] == 0 || path[len] == '\\');
}

static BOOL Under_Post(const char* prefix, const char* path, int* after)
{
    int len = (int)strlen(prefix);
    int n = 0;
    BOOL ret = SalPathHasPrefixOrdinalCI(path, prefix, len, &n) &&
               (path[n] == 0 || path[n] == '\\');
    *after = n;
    return ret;
}

static void PrefixRow(const char* label, const char* prefix, const char* path, BOOL expected, BOOL ascii)
{
    int a1, a2;
    BOOL o = Under_Pre(prefix, path, &a1);
    BOOL n = Under_Post(prefix, path, &a2);
    Row(label, o, n, expected, -1, ascii);
}

static void Section3()
{
    Header("(3) \"path is under prefix\" - prefix passed FIRST to StrNICmp, then path[len] (\"same\" = is under)");
    PrefixRow("ASCII: C:\\foo, c:\\FOO\\bar (followed by a backslash)", "C:\\foo", "c:\\FOO\\bar", TRUE, TRUE);
    PrefixRow("ASCII: C:\\foo, c:\\FOO (followed by the end)", "C:\\foo", "c:\\FOO", TRUE, TRUE);
    PrefixRow("ASCII: C:\\foo, C:\\foobar (followed by another letter)", "C:\\foo", "C:\\foobar", FALSE, TRUE);
    PrefixRow("ASCII: prefix longer than the path", "C:\\foo\\bar", "C:\\foo", FALSE, TRUE);
    PrefixRow("ASCII: empty prefix, path C:\\x", "", "C:\\x", FALSE, TRUE);
    PrefixRow("ASCII: empty prefix, empty path", "", "", TRUE, TRUE);
    PrefixRow("ASCII: plug-in FS path ftp://host/dir against C:\\dir", "ftp://host/dir", "C:\\dir", FALSE, TRUE);
    PrefixRow("C-caron: C:\\<U+010C>, c:\\<U+010D>\\x", "C:\\" U_CCARON, "c:\\" L_CCARON "\\x", TRUE, FALSE);
    PrefixRow("C-caron: C:\\<U+010C>, c:\\<U+010D>x (another letter follows)", "C:\\" U_CCARON, "c:\\" L_CCARON "x", FALSE, FALSE);
    PrefixRow("collision: C:\\<U+0125>, C:\\<U+0139>\\x", "C:\\" H_CIRC, "C:\\" L_ACUTE "\\x", FALSE, FALSE);
    PrefixRow("U+023A (2 bytes) prefix, U+2C65 (3 bytes) in the path", "C:\\" A_STROKE_U, "c:\\" A_STROKE_L "\\x", TRUE, FALSE);
    PrefixRow("U+2C65 (3 bytes) prefix, U+023A (2 bytes) in the path", "C:\\" A_STROKE_L, "c:\\" A_STROKE_U "\\x", TRUE, FALSE);
    PrefixRow("U+2C65 prefix, path is exactly C:\\<U+023A> (shorter in bytes)", "C:\\" A_STROKE_L, "C:\\" A_STROKE_U, TRUE, FALSE);

    // a path over 520 UTF-16 units (the helper's heap route)
    static char longPrefix[2000], longPath[2000], longAsciiPrefix[1000], longAsciiPath[1000];
    strcpy(longPrefix, "C:\\");
    strcpy(longPath, "c:\\");
    for (int i = 0; i < 600; i++)
    {
        strcat(longPrefix, U_CCARON);
        strcat(longPath, L_CCARON);
    }
    strcat(longPath, "\\tail");
    PrefixRow("603 units: C:\\ + 600 x U+010C, c:\\ + 600 x U+010D + \\tail", longPrefix, longPath, TRUE, FALSE);
    strcpy(longAsciiPrefix, "C:\\");
    strcpy(longAsciiPath, "c:\\");
    for (int i = 0; i < 700; i++)
    {
        strcat(longAsciiPrefix, "A");
        strcat(longAsciiPath, "a");
    }
    strcat(longAsciiPath, "\\tail");
    PrefixRow("ASCII, 703 units: C:\\ + 700 x A, c:\\ + 700 x a + \\tail", longAsciiPrefix, longAsciiPath, TRUE, TRUE);

    // the raw helper against the raw old call, with the byte each of them makes the caller read
    printf("\n    the byte after the prefix: path[prefixLen] (what the old code read) vs path[returned count]\n");
    struct CAfter
    {
        const char* Label;
        const char* Prefix;
        int PrefixLen; // -1 = all
        const char* Path;
        BOOL Expected;    // is a prefix?
        int ExpectedBytes; // when it is
    };
    static const CAfter after[] = {
        {"ASCII: C:\\foo in c:\\FOO\\bar", "C:\\foo", -1, "c:\\FOO\\bar", TRUE, 6},
        {"U+023A (2 bytes) prefix, U+2C65 (3 bytes) in the path", "C:\\" A_STROKE_U, -1, "c:\\" A_STROKE_L "\\x", TRUE, 6},
        {"U+2C65 (3 bytes) prefix, U+023A (2 bytes) in the path", "C:\\" A_STROKE_L, -1, "c:\\" A_STROKE_U "\\x", TRUE, 5},
        {"prefix cut inside a 2-byte character (C4 of C4 8C)", "C:\\" U_CCARON, 4, "C:\\" U_CCARON "\\x", FALSE, 0},
        {"prefix = lone high surrogate, path has the whole pair", "C:\\\xED\xA0\xBD", -1, "C:\\\xF0\x9F\x98\x80\\x", FALSE, 0},
        {"prefix longer than the path", "C:\\" U_CCARON "\\sub", -1, "C:\\" U_CCARON, FALSE, 0},
        {"empty prefix", "", -1, "C:\\" U_CCARON, TRUE, 0},
    };
    for (int i = 0; i < (int)(sizeof(after) / sizeof(after[0])); i++)
    {
        const CAfter& r = after[i];
        int pl = r.PrefixLen < 0 ? (int)strlen(r.Prefix) : r.PrefixLen;
        int n = -1;
        BOOL newIs = SalPathHasPrefixOrdinalCI(r.Path, r.Prefix, r.PrefixLen, &n);
        BOOL oldIs = StrNICmp(r.Path, r.Prefix, pl) == 0;
        BOOL good = newIs == r.Expected && (!newIs || n == r.ExpectedBytes) && (newIs || n == 0);
        Rows++;
        if (!good)
            Failed++;
        int pathLen = (int)strlen(r.Path);
        char oldByte[20] = "-", newByte[20] = "-";
        if (pl <= pathLen)
            sprintf(oldByte, "0x%02X", (unsigned)(BYTE)r.Path[pl]);
        if (newIs)
            sprintf(newByte, "0x%02X", (unsigned)(BYTE)r.Path[n]);
        printf("  %-56s OLD %-3s NEW %-3s exp. %-3s  path[%d]=%s  path[%d]=%s  %s\n", r.Label,
               oldIs ? "yes" : "no", newIs ? "yes" : "no", r.Expected ? "yes" : "no", pl, oldByte, n, newByte,
               good ? "PASS" : "FAIL");
    }

    // a path that is not UTF-8 (legacy text): the helper must give the legacy answer and count
    {
        const char* path = "C:\\\xE8\\x"; // one code-page byte
        const char* prefix = "C:\\\xC8";
        int n = -1;
        BOOL newIs = SalPathHasPrefixOrdinalCI(path, prefix, 4, &n);
        BOOL oldIs = StrNICmp(path, prefix, 4) == 0;
        BOOL good = newIs == oldIs && (!newIs || n == 4);
        Rows++;
        if (!good)
            Failed++;
        printf("  %-56s OLD %-3s NEW %-3s exp. =OLD (legacy text)                   %s\n",
               "path is not UTF-8: C:\\<E8>\\x, prefix C:\\<C8>", oldIs ? "yes" : "no", newIs ? "yes" : "no", good ? "PASS" : "FAIL");
    }
}

//
// ---- (4) CTopIndexMem (salamdr3.cpp), pre and post ------------------------
//

#define TOP_INDEX_MEM_SIZE 50

struct CTopIndexMem
{
    char Path[4000];
    int TopIndexes[TOP_INDEX_MEM_SIZE];
    int TopIndexesCount;
    BOOL Post; // which comparison

    void Clear()
    {
        Path[0] = 0;
        TopIndexesCount = 0;
    }

    void Push(const char* path, int topIndex)
    {
        // check whether 'path' follows 'Path' (path == Path + "\\name")
        const char* s = path + strlen(path);
        if (s > path && *(s - 1) == '\\')
            s--;
        BOOL ok;
        if (s == path)
            ok = FALSE;
        else
        {
            if (s > path && *s == '\\')
                s--;
            while (s > path && *s != '\\')
                s--;

            int l = (int)strlen(Path);
            if (l > 0 && Path[l - 1] == '\\')
                l--;
            if (Post)
                ok = SalNameEqualOrdinalCI(path, (int)(s - path), Path, l);
            else
                ok = s - path == l && StrNICmp(path, Path, l) == 0;
        }

        if (ok) // it follows -> remember the next top index
        {
            if (TopIndexesCount == TOP_INDEX_MEM_SIZE) // it is necessary to drop the first stored top index
            {
                int i;
                for (i = 0; i < TOP_INDEX_MEM_SIZE - 1; i++)
                    TopIndexes[i] = TopIndexes[i + 1];
                TopIndexesCount--;
            }
            strcpy(Path, path);
            TopIndexes[TopIndexesCount++] = topIndex;
        }
        else // not sequential -> first top index in the series
        {
            strcpy(Path, path);
            TopIndexesCount = 1;
            TopIndexes[0] = topIndex;
        }
    }

    BOOL FindAndPop(const char* path, int& topIndex)
    {
        // determine whether 'path' matches Path (path == Path)
        int l1 = (int)strlen(path);
        if (l1 > 0 && path[l1 - 1] == '\\')
            l1--;
        int l2 = (int)strlen(Path);
        if (l2 > 0 && Path[l2 - 1] == '\\')
            l2--;
        if (Post ? SalNameEqualOrdinalCI(path, l1, Path, l2) : (l1 == l2 && StrNICmp(path, Path, l1) == 0))
        {
            if (TopIndexesCount > 0)
            {
                char* s = Path + strlen(Path);
                if (s > Path && *(s - 1) == '\\')
                    s--;
                if (s > Path && *s == '\\')
                    s--;
                while (s > Path && *s != '\\')
                    s--;
                *s = 0;
                topIndex = TopIndexes[--TopIndexesCount];
                return TRUE;
            }
            else // we no longer have this value (it was never stored or was dropped due to low memory)
            {
                Clear();
                return FALSE;
            }
        }
        else // querying a different path -> clear the memory because a long jump occurred
        {
            Clear();
            return FALSE;
        }
    }
};

// enter 'push1' then 'push2' (its subdirectory, possibly in another spelling of the parent),
// then leave through 'pop1' and 'pop2'; "same" = both stored indexes came back in order
static BOOL TopIndexScenario(BOOL post, const char* push1, const char* push2, const char* pop1, const char* pop2, int* levels)
{
    static CTopIndexMem m;
    m.Post = post;
    m.Clear();
    m.Push(push1, 11);
    m.Push(push2, 22);
    *levels = m.TopIndexesCount;
    int t1 = -1, t2 = -1;
    BOOL r1 = m.FindAndPop(pop1, t1);
    BOOL r2 = r1 && m.FindAndPop(pop2, t2);
    return r1 && r2 && t1 == 22 && t2 == 11;
}

static void TopRow(const char* label, const char* push1, const char* push2, const char* pop1, const char* pop2, BOOL expected, BOOL ascii)
{
    int l1, l2;
    BOOL o = TopIndexScenario(FALSE, push1, push2, pop1, pop2, &l1);
    BOOL n = TopIndexScenario(TRUE, push1, push2, pop1, pop2, &l2);
    char full[200];
    sprintf(full, "%.50s [levels %d/%d]", label, l1, l2);
    Row(full, o, n, expected, -1, ascii);
}

static void Section4()
{
    Header("(4) CTopIndexMem: Push, Push, FindAndPop, FindAndPop (\"same\" = both top indexes returned)");
    TopRow("ASCII, one spelling", "C:\\Dir", "C:\\Dir\\Sub", "C:\\Dir\\Sub", "C:\\Dir", TRUE, TRUE);
    TopRow("ASCII, pop in the other case", "C:\\Dir", "C:\\Dir\\Sub", "c:\\dir\\sub\\", "C:\\DIR", TRUE, TRUE);
    TopRow("ASCII, second push in the other case", "C:\\Dir\\", "c:\\DIR\\Sub", "C:\\Dir\\Sub", "c:\\dir", TRUE, TRUE);
    TopRow("ASCII, pop of another path", "C:\\Dir", "C:\\Dir\\Sub", "C:\\Dir\\Sub2", "C:\\Dir", FALSE, TRUE);
    TopRow("ASCII, second push is not a subdirectory", "C:\\Dir", "C:\\Other\\Sub", "C:\\Other\\Sub", "C:\\Dir", FALSE, TRUE);
    TopRow("ASCII, first path without a backslash, empty memory", "Dir", "Dir\\Sub", "Dir\\Sub", "Dir", TRUE, TRUE);
    TopRow("C-caron: pop in the other case", "C:\\" U_CCARON, "C:\\" U_CCARON "\\Sub", "c:\\" L_CCARON "\\sub", "c:\\" L_CCARON, TRUE, FALSE);
    TopRow("C-caron: second push in the other case", "C:\\" U_CCARON, "c:\\" L_CCARON "\\Sub", "C:\\" U_CCARON "\\Sub", "C:\\" U_CCARON, TRUE, FALSE);
    TopRow("U+023A pushed, U+2C65 popped (other byte length)", "C:\\" A_STROKE_U, "C:\\" A_STROKE_U "\\Sub", "C:\\" A_STROKE_L "\\Sub", "C:\\" A_STROKE_L, TRUE, FALSE);
    TopRow("U+023A, second push spelled U+2C65", "C:\\" A_STROKE_U, "C:\\" A_STROKE_L "\\Sub", "C:\\" A_STROKE_U "\\Sub", "C:\\" A_STROKE_U, TRUE, FALSE);
    TopRow("collision: U+0125 pushed, U+0139 popped", "C:\\" H_CIRC, "C:\\" H_CIRC "\\Sub", "C:\\" L_ACUTE "\\Sub", "C:\\" L_ACUTE, FALSE, FALSE);
}

//
// ---- (5) the sorted name list and its search (salamdr6.cpp, fileswn6.cpp) --
//

typedef int (*FCompare)(const char*, const char*);

// SortNames (salamdr6.cpp), verbatim but for the comparison passed in
static void SortNames(char* files[], int left, int right, FCompare cmp)
{

LABEL_SortNames:

    int i = left, j = right;
    char* pivot = files[(i + j) / 2];

    do
    {
        while (cmp(files[i], pivot) < 0 && i < right)
            i++;
        while (cmp(pivot, files[j]) < 0 && j > left)
            j--;

        if (i <= j)
        {
            char* swap = files[i];
            files[i] = files[j];
            files[j] = swap;
            i++;
            j--;
        }
    } while (i <= j);

    if (left < j)
    {
        if (i < right)
        {
            if (j - left < right - i) // we need to sort both "halves", so send the smaller one into recursion and process the other via "goto"
            {
                SortNames(files, left, j, cmp);
                left = i;
                goto LABEL_SortNames;
            }
            else
            {
                SortNames(files, i, right, cmp);
                right = j;
                goto LABEL_SortNames;
            }
        }
        else
        {
            right = j;
            goto LABEL_SortNames;
        }
    }
    else
    {
        if (i < right)
        {
            left = i;
            goto LABEL_SortNames;
        }
    }
}

// FindNameInArray (salamdr6.cpp, the case-insensitive branch) over a plain array
static BOOL FindNameInArray(char** items, int count, const char* name, FCompare cmp, int* foundOnIndex)
{
    int l = 0, r = count - 1, m;
    while (1)
    {
        m = (l + r) / 2;
        int res = cmp(items[m], name);
        if (res == 0)
        {
            if (foundOnIndex != NULL)
                *foundOnIndex = m;
            return TRUE; // found
        }
        else
        {
            if (res > 0)
            {
                if (l == r || l > m - 1)
                    return FALSE; // not found
                r = m - 1;
            }
            else
            {
                if (l == r)
                    return FALSE; // not found
                l = m + 1;
            }
        }
    }
}

// ContainsString (fileswn6.cpp) over a plain array
static BOOL ContainsString(char** usedNames, int count, const char* name, FCompare cmp, int* index)
{
    if (count == 0)
    {
        if (index != NULL)
            *index = 0;
        return FALSE;
    }

    int l = 0, r = count - 1, m;
    while (1)
    {
        m = (l + r) / 2;
        char* hw = usedNames[m];
        int res = cmp(hw, name);
        if (res == 0) // found
        {
            if (index != NULL)
                *index = m;
            return TRUE;
        }
        else
        {
            if (res > 0)
            {
                if (l == r || l > m - 1) // not found
                {
                    if (index != NULL)
                        *index = m; // should be at this position
                    return FALSE;
                }
                r = m - 1;
            }
            else
            {
                if (l == r) // not found
                {
                    if (index != NULL)
                        *index = m + 1; // should be right after this position
                    return FALSE;
                }
                l = m + 1;
            }
        }
    }
}

#define LEGACY_NAME "\xE8" "esky.txt" // one code-page byte: not UTF-8

static const char* ListNames[] = {
    "readme.txt",
    "Alpha",
    "beta",
    "Zeta.TXT",
    "_underscore",
    "[bracket]",
    "`backtick",
    "^caret",
    "a",
    "ab",
    "a.b",
    "file10.txt",
    "File2.txt",
    U_CCARON ".txt",                  // U+010C - looked up as U+010D
    L_CCARON "l" L_AACUTE "nek.txt",  // lower case - looked up in upper case
    "\xC5\xBD" "lu\xC5\xA5ou\xC4\x8Dk\xC3\xBD", // Zlutoucky with carons, upper Z-caron first
    L_ACUTE ".txt",                   // U+0139 - U+0125 must NOT find it
    A_STROKE_U ".txt",                // 2 bytes - looked up as U+2C65 (3 bytes)
    "\xD0\x96\xD1\x83\xD0\xBA.txt",   // Cyrillic, upper ZHE first
    "stra" SHARP_S "e.txt",
    "Lone\xED\xA0\x80surrogate.txt",  // WTF-8 lone surrogate
    LEGACY_NAME,
};
#define LIST_NAMES ((int)(sizeof(ListNames) / sizeof(ListNames[0])))

struct CLookup
{
    const char* Label;
    const char* Name;
    int Expected; // 1 found, 0 not found, -1 = legacy text: the old rule's answer is the expected one
    BOOL Ascii;
};

static const CLookup Lookups[] = {
    {"ASCII: README.TXT (list has readme.txt)", "README.TXT", 1, TRUE},
    {"ASCII: ALPHA", "ALPHA", 1, TRUE},
    {"ASCII: zeta.txt", "zeta.txt", 1, TRUE},
    {"ASCII: _UNDERSCORE", "_UNDERSCORE", 1, TRUE},
    {"ASCII: [BRACKET]", "[BRACKET]", 1, TRUE},
    {"ASCII: A.B", "A.B", 1, TRUE},
    {"ASCII: FILE2.TXT", "FILE2.TXT", 1, TRUE},
    {"ASCII: nothere.txt", "nothere.txt", 0, TRUE},
    {"ASCII: abc (between ab and Alpha)", "abc", 0, TRUE},
    {"U+010D.txt (list has U+010C.txt)", L_CCARON ".txt", 1, FALSE},
    {"<U+010C>L<U+00C1>NEK.TXT (list has it in lower case)", U_CCARON "L\xC3\x81NEK.TXT", 1, FALSE},
    {"z-caron word in lower case", "\xC5\xBE" "lu\xC5\xA5ou\xC4\x8Dk\xC3\xBD", 1, FALSE},
    {"U+0125.txt (list has only U+0139.txt - another name)", H_CIRC ".txt", 0, FALSE},
    {"U+2C65.txt, 3 bytes (list has U+023A.txt, 2 bytes)", A_STROKE_L ".txt", 1, FALSE},
    {"Cyrillic, lower zhe", "\xD0\xB6\xD1\x83\xD0\xBA.txt", 1, FALSE},
    {"strasse.txt (list has stra<U+00DF>e.txt - another name)", "strasse.txt", 0, FALSE},
    {"lone surrogate name, ASCII part in upper case", "LONE\xED\xA0\x80SURROGATE.TXT", 1, FALSE},
    {"another lone surrogate (U+D801)", "Lone\xED\xA0\x81surrogate.txt", 0, FALSE},
    {"not UTF-8: <C8>ESKY.TXT (list has <E8>esky.txt)", "\xC8" "ESKY.TXT", -1, FALSE},
};

static BOOL IsSorted(char** arr, int count, FCompare cmp)
{
    for (int i = 1; i < count; i++)
        if (cmp(arr[i - 1], arr[i]) > 0)
            return FALSE;
    return TRUE;
}

static void Check(const char* label, BOOL good)
{
    Rows++;
    if (!good)
        Failed++;
    printf("  %-88s %s\n", label, good ? "PASS" : "FAIL");
}

static void Section5()
{
    static char* oldList[LIST_NAMES + 300];
    static char* newList[LIST_NAMES + 300];
    static char filler[300][24];
    int count = 0;
    for (int i = 0; i < LIST_NAMES; i++)
        oldList[count++] = (char*)ListNames[i];
    // filler names so that the binary search has something to walk through
    for (int i = 0; i < 300; i++)
    {
        sprintf(filler[i], "%c%s%03d.dat", "abcXYZ_m"[i % 8], (i % 3) == 0 ? "Item" : "item", (i * 7919) % 1000);
        oldList[count++] = filler[i];
    }
    memcpy(newList, oldList, sizeof(char*) * count);
    SortNames(oldList, 0, count - 1, StrICmp);
    SortNames(newList, 0, count - 1, NewCmp);

    printf("\n(5) sorted name list + binary search (SortNames / FindNameInArray / ContainsString), %d names\n", count);
    Check("NEW: after SortNames every adjacent pair compares <= 0", IsSorted(newList, count, NewCmp));
    int notFound = 0, wrongIndex = 0, cs = 0;
    for (int i = 0; i < count; i++)
    {
        int idx = -1, idx2 = -1;
        if (!FindNameInArray(newList, count, newList[i], NewCmp, &idx))
            notFound++;
        else if (NewCmp(newList[idx], newList[i]) != 0)
            wrongIndex++;
        if (!ContainsString(newList, count, newList[i], NewCmp, &idx2) || NewCmp(newList[idx2], newList[i]) != 0)
            cs++;
    }
    Check("NEW: FindNameInArray finds every element, at an index holding an equal name", notFound == 0 && wrongIndex == 0);
    Check("NEW: ContainsString finds every element of the list SortNames sorted (drag&drop list)", cs == 0);

    // AddStringToNames: a list built by inserting at ContainsString's index
    static char* built[LIST_NAMES + 300];
    int builtCount = 0;
    int dupes = 0;
    for (int i = 0; i < count; i++)
    {
        const char* name = i < LIST_NAMES ? ListNames[i] : filler[i - LIST_NAMES];
        int index = -1;
        if (ContainsString(built, builtCount, name, NewCmp, &index))
            dupes++;
        else
        {
            memmove(built + index + 1, built + index, sizeof(char*) * (builtCount - index));
            built[index] = (char*)name;
            builtCount++;
        }
    }
    int builtMissing = 0;
    for (int i = 0; i < builtCount; i++)
        if (!ContainsString(built, builtCount, built[i], NewCmp, NULL))
            builtMissing++;
    Check("NEW: a list built by ContainsString's insertion index stays sorted and every element is found",
          IsSorted(built, builtCount, NewCmp) && builtMissing == 0 && builtCount + dupes == count);

    Header("    look-ups (\"same\" = found); OLD = list sorted and searched by StrICmp, NEW = both by SalNameCompareOrdinalCI");
    for (int i = 0; i < (int)(sizeof(Lookups) / sizeof(Lookups[0])); i++)
    {
        const CLookup& q = Lookups[i];
        BOOL o = FindNameInArray(oldList, count, q.Name, StrICmp, NULL);
        BOOL n = FindNameInArray(newList, count, q.Name, NewCmp, NULL);
        BOOL n2 = ContainsString(newList, count, q.Name, NewCmp, NULL);
        BOOL expected = q.Expected < 0 ? o : q.Expected;
        if (n != n2)
        {
            printf("  FindNameInArray and ContainsString disagree for the next row\n");
            Failed++;
        }
        Row(q.Label, o, n, expected, -1, q.Ascii);
    }

    // why both sides must change together: the new sort with the old search (and the reverse)
    int mixed1 = 0, mixed2 = 0;
    for (int i = 0; i < count; i++)
    {
        if (!FindNameInArray(newList, count, newList[i], StrICmp, NULL))
            mixed1++;
        if (!FindNameInArray(oldList, count, oldList[i], NewCmp, NULL))
            mixed2++;
    }
    printf("  for the record (not a verdict): sorted by NEW, searched by OLD: %d of %d own elements not found;\n"
           "                                  sorted by OLD, searched by NEW: %d of %d own elements not found\n",
           mixed1, count, mixed2, count);
}

int main()
{
    InitializeCase();
    printf("Feature 092 S4+S5 probe: path identity, prefix tests, sorted name lists\n");
    printf("system code page (CharLowerA table): %u\n", GetACP());

    WCHAR tmp[MAX_PATH];
    if (GetTempPathW(MAX_PATH, tmp) == 0)
        return 3;
    swprintf(ScratchDir, MAX_PATH + 40, L"%stc092s4probe_%lu", tmp, GetCurrentProcessId());
    if (!CreateDirectoryW(ScratchDir, NULL))
    {
        printf("FATAL: cannot create the probe folder, error %lu\n", GetLastError());
        return 3;
    }
    WCHAR root[MAX_PATH], fsName[64] = L"?";
    if (GetVolumePathNameW(ScratchDir, root, MAX_PATH))
        GetVolumeInformationW(root, NULL, 0, NULL, NULL, NULL, fsName, 64);
    printf("probe folder is on: %ls (%ls)\n", root, fsName);
    IsNtfs = wcscmp(fsName, L"NTFS") == 0;

    Section1();
    BOOL removed = RemoveDirectoryW(ScratchDir);
    if (!removed)
        printf("  (the probe folder could not be removed, error %lu)\n", GetLastError());
    Section2();
    Section3();
    Section4();
    Section5();

    printf("\nsummary: rows %d (ASCII parity rows %d), failed %d; OLD false \"different\": %d; OLD false \"same\": %d;\n"
           "         file-system errors: %d; probe folder removed: %s\n",
           Rows, AsciiRows, Failed, OldFalseDifferent, OldFalseSame, FsErrors, removed ? "yes" : "NO");
    if (!IsNtfs)
    {
        printf("RESULT: INCONCLUSIVE - the probe folder is not on NTFS\n");
        return 2;
    }
    if (Failed != 0 || FsErrors != 0 || !removed)
    {
        printf("RESULT: FAIL\n");
        return 1;
    }
    printf("RESULT: PASS - every NEW row has its expected value, every ASCII row is identical under OLD and NEW\n");
    return 0;
}
