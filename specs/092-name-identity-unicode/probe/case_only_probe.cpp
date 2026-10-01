// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later
//
// Feature 092, stage S3 - evidence probe for the decisions "only a change of
// case" / "the target is the source" (the pattern of 075's probe).
//
//   OLD = the predicate the converted sites used: StrICmp(a, b) == 0, i.e. the
//         byte fold through a table built by CharLowerA exactly as
//         src/common/str.cpp InitializeCase() builds LowerCase[] (replicated
//         here verbatim - the probe does not link str.cpp).
//   NEW = SalNameEqualOrdinalCI(a, -1, b, -1) from src/common/salunicode.cpp,
//         compiled into this probe from the product's source.
//   NTFS = the file system's own answer: a file is created under the first
//         name in an empty folder; does opening the second name find it?
//
// The probe exits 0 only if NEW agrees with the file system for every pair
// (and the CorrectCaseOfTgtName rows keep their canary). This source is pure
// ASCII on purpose: every name is written with \x escapes.

#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "salunicode.h"

//
// ---- OLD: str.cpp, verbatim (x64 branch) ---------------------------------
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
        res = (unsigned)LowerCase[(BYTE)*s1] - (unsigned)LowerCase[(BYTE)*s2++];
        if (res != 0)
            return (res < 0) ? -1 : 1; // < a >
        if (*s1++ == 0)
            return 0; // ==
    }
}

static BOOL OldSame(const char* a, const char* b) { return StrICmp(a, b) == 0; }
static BOOL NewSame(const char* a, const char* b) { return SalNameEqualOrdinalCI(a, -1, b, -1); }

//
// ---- CorrectCaseOfTgtName (worker.cpp), the last two lines, pre and post --
//

static void CorrectCase_Pre(char* tgtName, const char* foundNameU8)
{
    int len = (int)strlen(foundNameU8);
    int tgtNameLen = (int)strlen(tgtName);
    if (tgtNameLen >= len && StrICmp(tgtName + tgtNameLen - len, foundNameU8) == 0)
        memcpy(tgtName + tgtNameLen - len, foundNameU8, len);
}

static void CorrectCase_Post(char* tgtName, const char* foundNameU8)
{
    int len = (int)strlen(foundNameU8);
    int tgtNameLen = (int)strlen(tgtName);
    if (tgtNameLen >= len && SalNameEqualOrdinalCI(tgtName + tgtNameLen - len, len, foundNameU8, len))
        memcpy(tgtName + tgtNameLen - len, foundNameU8, len);
}

//
// ---- the pairs -------------------------------------------------------------
//

struct CPair
{
    const char* Label;  // ASCII description (the console may not show the names)
    const WCHAR* First; // the file that exists
    const WCHAR* Second;
};

static const CPair Pairs[] = {
    {"ASCII case pair: readme.txt / README.TXT", L"readme.txt", L"README.TXT"},
    {"C-caron: Cl\\u00E1nek.txt upper/lower (U+010C / U+010D)", L"\x010Cl\x00E1nek.txt", L"\x010Dl\x00E1nek.txt"},
    {"CP1250 collision: h-circumflex U+0125 / L-acute U+0139", L"\x0125.txt", L"\x0139.txt"},
    {"sharp s: stra\\u00DFe.txt / strasse.txt", L"stra\x00DF" L"e.txt", L"strasse.txt"},
    {"NFC U+010D / NFD c + U+030C", L"\x010D.txt", L"c\x030C.txt"},
    {"Cyrillic ZHE U+0416 / U+0436", L"\x0416\x0443\x043A.txt", L"\x0436\x0443\x043A.txt"},
    {"Greek OMEGA U+03A9 / U+03C9", L"\x03A9\x03BC.txt", L"\x03C9\x03BC.txt"},
    {"lone surrogate U+D800, ASCII case differs", L"Lone\xD800x.txt", L"LONE\xD800X.TXT"},
    {"lone surrogates U+D800 / U+D801", L"Lone\xD800.txt", L"Lone\xD801.txt"},
    {"unequal UTF-8 length: U+023A (2 bytes) / U+2C65 (3 bytes)", L"\x023A.txt", L"\x2C65.txt"},
    {"dotless i U+0131 / I", L"\x0131.txt", L"I.txt"},
    {"Kelvin sign U+212A / k", L"\x212A.txt", L"k.txt"},
    {"final sigma U+03C2 / sigma U+03C3", L"\x03C2.txt", L"\x03C3.txt"},
    {"unrelated: alpha.txt / beta.txt", L"alpha.txt", L"beta.txt"},
    {"identical: same.txt / same.txt", L"same.txt", L"same.txt"},
};

static void ToU8(const WCHAR* w, char* buf, int bufSize)
{
    if (SalWToU8(w, -1, buf, bufSize) == 0)
    {
        printf("FATAL: SalWToU8 failed\n");
        exit(3);
    }
}

// TRUE when, with a file named 'first' alone in 'dir', opening 'second' finds it
static BOOL NtfsSame(const WCHAR* dir, const WCHAR* first, const WCHAR* second, BOOL* ok)
{
    WCHAR p1[600], p2[600];
    swprintf(p1, 600, L"%s\\%s", dir, first);
    swprintf(p2, 600, L"%s\\%s", dir, second);
    *ok = FALSE;
    HANDLE h = CreateFileW(p1, GENERIC_WRITE, 0, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
    if (h == INVALID_HANDLE_VALUE)
    {
        printf("  (cannot create the first file, error %lu)\n", GetLastError());
        return FALSE;
    }
    CloseHandle(h);
    BOOL same = FALSE;
    h = CreateFileW(p2, 0, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL,
                    OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (h != INVALID_HANDLE_VALUE)
    {
        same = TRUE;
        CloseHandle(h);
        *ok = TRUE;
    }
    else
    {
        DWORD e = GetLastError();
        *ok = (e == ERROR_FILE_NOT_FOUND);
        if (!*ok)
            printf("  (opening the second name failed with error %lu)\n", e);
    }
    if (!DeleteFileW(p1))
    {
        printf("  (cannot delete the first file, error %lu)\n", GetLastError());
        *ok = FALSE;
    }
    return same;
}

static int CorrectCaseRow(const char* label, const char* tgt, const char* found, BOOL expectAsciiParity)
{
    // exact-size block like BuildName's, followed by a canary
    char pre[600], post[600];
    size_t l = strlen(tgt);
    memset(pre, 0x5A, sizeof(pre));
    memset(post, 0x5A, sizeof(post));
    memcpy(pre, tgt, l + 1);
    memcpy(post, tgt, l + 1);
    CorrectCase_Pre(pre, found);
    CorrectCase_Post(post, found);
    BOOL canary = TRUE;
    for (size_t i = l + 1; i < sizeof(post); i++)
        if ((BYTE)post[i] != 0x5A || (BYTE)pre[i] != 0x5A)
            canary = FALSE;
    BOOL lenKept = strlen(post) == l && strlen(pre) == l;
    BOOL preChanged = memcmp(pre, tgt, l + 1) != 0;
    BOOL postChanged = memcmp(post, tgt, l + 1) != 0;
    BOOL parity = !expectAsciiParity || memcmp(pre, post, l + 1) == 0;
    // a corrected buffer must end with the found name, byte for byte
    BOOL postRight = !postChanged ||
                     (l >= strlen(found) && memcmp(post + l - strlen(found), found, strlen(found)) == 0);
    BOOL good = canary && lenKept && parity && postRight;
    printf("  %-58s pre: %-9s post: %-9s canary: %s  %s\n", label,
           preChanged ? "corrected" : "unchanged", postChanged ? "corrected" : "unchanged",
           canary && lenKept ? "intact" : "BROKEN", good ? "ok" : "FAIL");
    return good ? 0 : 1;
}

int main()
{
    InitializeCase();
    printf("Feature 092 S3 probe: \"only a change of case\" / \"the same file\"\n");
    printf("system code page (CharLowerA table): %u\n", GetACP());

    WCHAR tmp[MAX_PATH], dir[MAX_PATH + 40];
    if (GetTempPathW(MAX_PATH, tmp) == 0)
        return 3;
    swprintf(dir, MAX_PATH + 40, L"%stc092s3probe_%lu", tmp, GetCurrentProcessId());
    if (!CreateDirectoryW(dir, NULL))
    {
        printf("FATAL: cannot create the probe folder, error %lu\n", GetLastError());
        return 3;
    }
    WCHAR root[MAX_PATH], fsName[64] = L"?";
    if (GetVolumePathNameW(dir, root, MAX_PATH))
        GetVolumeInformationW(root, NULL, 0, NULL, NULL, NULL, fsName, 64);
    printf("probe folder is on: %ls (%ls)\n\n", root, fsName);
    BOOL isNtfs = wcscmp(fsName, L"NTFS") == 0;

    int newWrong = 0, oldFalseDifferent = 0, oldFalseSame = 0, fsErrors = 0;
    printf("%-60s %-5s %-5s %-5s  %s\n", "pair (first exists; is the second the same file?)", "OLD", "NEW", "NTFS", "verdict");
    printf("%-60s %-5s %-5s %-5s  %s\n", "------------------------------------------------", "---", "---", "----", "-------");
    for (int i = 0; i < (int)(sizeof(Pairs) / sizeof(Pairs[0])); i++)
    {
        char a[300], b[300];
        ToU8(Pairs[i].First, a, sizeof(a));
        ToU8(Pairs[i].Second, b, sizeof(b));
        // the sites compare full paths with identical directory bytes; do the same
        char pa[400], pb[400];
        sprintf(pa, "C:\\Dir\\%s", a);
        sprintf(pb, "C:\\Dir\\%s", b);
        BOOL oldS = OldSame(pa, pb);
        BOOL newS = NewSame(pa, pb);
        if (OldSame(a, b) != oldS || NewSame(a, b) != newS)
        {
            printf("FATAL: name and full-path answers differ for pair %d\n", i);
            return 3;
        }
        BOOL ok;
        BOOL fsS = NtfsSame(dir, Pairs[i].First, Pairs[i].Second, &ok);
        if (!ok)
            fsErrors++;
        const char* verdict;
        if (newS != fsS)
        {
            newWrong++;
            verdict = "NEW DISAGREES WITH THE FILE SYSTEM";
        }
        else if (oldS == fsS)
            verdict = "both right";
        else if (fsS)
        {
            oldFalseDifferent++;
            verdict = "OLD wrong: false \"different\" (one file taken for two)";
        }
        else
        {
            oldFalseSame++;
            verdict = "OLD wrong: false \"same\" (two files taken for one)";
        }
        printf("%-60s %-5s %-5s %-5s  %s   [bytes %d / %d]\n", Pairs[i].Label,
               oldS ? "same" : "diff", newS ? "same" : "diff", fsS ? "same" : "diff", verdict,
               (int)strlen(a), (int)strlen(b));
    }
    RemoveDirectoryW(dir);

    printf("\nCorrectCaseOfTgtName (in-place copy of the on-disk case; the length test stays):\n");
    int ccFail = 0;
    ccFail += CorrectCaseRow("ASCII: ...\\readme.txt, found README.TXT", "C:\\Dir\\readme.txt", "README.TXT", TRUE);
    ccFail += CorrectCaseRow("ASCII: found name is not the tail", "C:\\Dir\\readme.txt", "other.txt", TRUE);
    ccFail += CorrectCaseRow("ASCII: found name longer than the path", "a.txt", "a-very-long-name.txt", TRUE);
    ccFail += CorrectCaseRow("ASCII: DOS alias PROGRA~1, found Program Files", "C:\\PROGRA~1", "Program Files", TRUE);
    ccFail += CorrectCaseRow("C-caron lower typed, upper on disk", "C:\\Dir\\\xC4\x8Dl\xC3\xA1nek.txt", "\xC4\x8Cl\xC3\xA1nek.txt", FALSE);
    ccFail += CorrectCaseRow("U+2C65 typed (3 bytes), U+023A on disk (2 bytes)", "C:\\Dir\\\xE2\xB1\xA5.txt", "\xC8\xBA.txt", FALSE);
    ccFail += CorrectCaseRow("U+023A typed (2 bytes), U+2C65 on disk (3 bytes)", "C:\\Dir\\\xC8\xBA.txt", "\xE2\xB1\xA5.txt", FALSE);
    ccFail += CorrectCaseRow("tail would start inside a character", "C:\\Dir\\\xC4\x8D.txt", "\xC2\x8D.txt", FALSE);

    printf("\nsummary: NEW disagrees with the file system: %d; OLD false \"different\": %d; OLD false \"same\": %d;\n"
           "         file-system errors: %d; CorrectCase failures: %d\n",
           newWrong, oldFalseDifferent, oldFalseSame, fsErrors, ccFail);
    if (!isNtfs)
    {
        printf("RESULT: INCONCLUSIVE - the probe folder is not on NTFS\n");
        return 2;
    }
    if (newWrong != 0 || fsErrors != 0 || ccFail != 0)
    {
        printf("RESULT: FAIL\n");
        return 1;
    }
    printf("RESULT: PASS - NEW agrees with NTFS for every pair\n");
    return 0;
}
