// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

// Unit tests for the 004-long-paths-unicode foundation helpers
// (src/common/salunicode.cpp, src/common/salpath.cpp).
// Console exe; exit code = number of failed checks.

#include "precomp.h"

#include <math.h>

#include "salunicode.h"
#include "salpath.h"
#include "salfileio.h"
#include "salclip.h"
#include "themes_palette.h"
#include "salshell.h" // feature 071
#include "saltabs.h"  // feature 078
#include "salbugreport.h" // feature 079
#include "salcloseapp.h"  // feature 080
#include "sal7zlist.h"    // feature 084
#include "salarcmig.h"    // feature 084
#include "salurlpwd.h"    // feature 085
#include "salrandom.h"    // feature 086
#include "salarcname.h"   // feature 087
#include "salplugver.h"   // feature 088
#include "salarcassoc.h"  // feature 089
#include "salftpanon.h"   // feature 090
#include "salarcpwd.h"    // feature 093
#include "salzippwd.h"    // feature 094
#include "salheapstr.h"   // feature 095
#include "../plugins/shared/splunicode.h" // feature 089: the plug-in converters, checked against the core's
#include "../plugins/filecomp/fcproto.h" // feature 102: the fcremote.exe channel

#include <map>
#include <set>
#include <string>
#include <vector>
#include <algorithm>

static int g_checks = 0;
static int g_failures = 0;

#define CHECK(cond) \
    do \
    { \
        g_checks++; \
        if (!(cond)) \
        { \
            g_failures++; \
            printf("FAIL %s(%d): %s\n", __FILE__, __LINE__, #cond); \
        } \
    } while (0)

// UTF-8 byte sequences used below:
//   NFC c-caron (U+010D)          = C4 8D
//   NFD c + combining caron       = 63 CC 8C
//   NFC C-caron (U+010C)          = C4 8C
//   folder emoji (U+1F4C1)        = F0 9F 93 81
#define U8_C_CARON_NFC "\xC4\x8D"
#define U8_C_CARON_NFD "c\xCC\x8C"
#define U8_CAP_C_CARON_NFC "\xC4\x8C"
#define U8_FOLDER_EMOJI "\xF0\x9F\x93\x81"

static void TestConversions()
{
    // NFC round trip
    WCHAR* w = SalU8ToWAlloc(U8_C_CARON_NFC);
    CHECK(w != NULL && wcscmp(w, L"\x010D") == 0);
    free(w);

    // NFD is preserved exactly (no silent normalization)
    w = SalU8ToWAlloc(U8_C_CARON_NFD);
    CHECK(w != NULL && wcscmp(w, L"c\x030C") == 0);
    char* u8 = SalWToU8Alloc(w);
    CHECK(u8 != NULL && strcmp(u8, U8_C_CARON_NFD) == 0);
    free(u8);
    free(w);

    // non-BMP round trip (surrogate pair)
    w = SalU8ToWAlloc(U8_FOLDER_EMOJI);
    CHECK(w != NULL && wcscmp(w, L"\xD83D\xDCC1") == 0);
    u8 = SalWToU8Alloc(w);
    CHECK(u8 != NULL && strcmp(u8, U8_FOLDER_EMOJI) == 0);
    free(u8);
    free(w);

    // invalid UTF-8 fails instead of being replaced
    CHECK(SalU8ToWAlloc("\xC4") == NULL);
    CHECK(SalU8ToWAlloc("\xFF\xFE") == NULL);

    // unpaired surrogate travels as WTF-8 (feature 066): ED A0 BD for U+D83D
    u8 = SalWToU8Alloc(L"\xD83D");
    CHECK(u8 != NULL && strcmp(u8, "\xED\xA0\xBD") == 0);
    free(u8);

    // sized (non-null-terminated) inputs get terminated output
    WCHAR wbuf[8];
    CHECK(SalU8ToW("abcdef", 3, wbuf, 8) == 4 && wcscmp(wbuf, L"abc") == 0);
    char cbuf[8];
    CHECK(SalWToU8(L"abcdef", 3, cbuf, 8) == 4 && strcmp(cbuf, "abc") == 0);
    // exact-fit failure is detected (no silent truncation)
    CHECK(SalU8ToW("abcd", 4, wbuf, 4) == 0);

    // lossless ACP conversion: ASCII passes, emoji cannot
    char acp[16];
    CHECK(SalWToACPLossless(L"abc", -1, acp, sizeof(acp)) && strcmp(acp, "abc") == 0);
    CHECK(!SalWToACPLossless(L"\xD83D\xDCC1", -1, acp, sizeof(acp)));
}

static void TestNormalization()
{
    // NFD -> NFC composition
    WCHAR buf[8];
    CHECK(SalNormalizeNFC(L"c\x030C", -1, buf, 8) > 0 && wcscmp(buf, L"\x010D") == 0);
    // NFC input is idempotent
    CHECK(SalNormalizeNFC(L"\x010D", -1, buf, 8) > 0 && wcscmp(buf, L"\x010D") == 0);
    // ASCII passthrough
    CHECK(SalNormalizeNFC(L"abc", -1, buf, 8) > 0 && wcscmp(buf, L"abc") == 0);
    WCHAR* nfc = SalNormalizeNFCAlloc(L"c\x030C"
                                      L".txt");
    CHECK(nfc != NULL && wcscmp(nfc, L"\x010D.txt") == 0);
    free(nfc);
}

static void TestMatching()
{
    CHECK(SalIsASCII("plain.txt"));
    CHECK(!SalIsASCII(U8_C_CARON_NFC ".txt"));

    // UTF-8 character walking/counting (feature 063: list padding, tooltip clamp)
    CHECK(SalU8CharCount("abc") == 3);
    CHECK(SalU8CharCount("") == 0);
    CHECK(SalU8CharCount(U8_C_CARON_NFC "a" U8_FOLDER_EMOJI) == 3); // 2+1+4 bytes, 3 chars
    CHECK(SalU8CharCount(U8_C_CARON_NFC "a", 2) == 1);              // sized: first char only
    const char* walk = U8_C_CARON_NFC "a";
    walk = SalU8Next(walk);
    CHECK(strcmp(walk, "a") == 0); // stepped over the 2-byte character
    walk = SalU8Next(walk);
    CHECK(*walk == 0);
    CHECK(SalU8Next(walk) == walk); // identity on the terminator

    // canonical equivalence (case-sensitive)
    CHECK(SalNameEquivalent(U8_C_CARON_NFC ".txt", U8_C_CARON_NFD ".txt"));
    CHECK(SalNameEquivalent("same.txt", "same.txt"));
    CHECK(!SalNameEquivalent("a.txt", "b.txt"));
    CHECK(!SalNameEquivalent(U8_CAP_C_CARON_NFC ".txt", U8_C_CARON_NFD ".txt")); // differs in case

    // case-insensitive, form-insensitive equality (FR-008)
    CHECK(SalNameEqualCI(U8_CAP_C_CARON_NFC ".TXT", -1, U8_C_CARON_NFD ".txt", -1));
    CHECK(SalNameEqualCI("ABC", -1, "abc", -1));
    CHECK(!SalNameEqualCI("abc", -1, "abd", -1));
    CHECK(SalNameEqualCI("abc", 2, "ab", -1)); // explicit lengths

    // collation: equivalent forms compare equal, order is sign-correct
    CHECK(SalCompareNamesUTF8(U8_C_CARON_NFC, -1, U8_C_CARON_NFD, -1, FALSE) == 0);
    CHECK(SalCompareNamesUTF8("a", -1, "b", -1, FALSE) < 0);
    CHECK(SalCompareNamesUTF8("b", -1, "a", -1, FALSE) > 0);
    CHECK(SalCompareNamesUTF8("A", -1, "a", -1, TRUE) == 0);
}

static void TestPathBuf()
{
    CSalPathBuf p;
    CHECK(p.IsEmpty() && p.Length() == 0 && strcmp(p.Get(), "") == 0);

    CHECK(p.Set("C:\\dir"));
    CHECK(p.AppendComponent("sub"));
    CHECK(strcmp(p.Get(), "C:\\dir\\sub") == 0);
    CHECK(p.AppendComponent("\\slashed")); // leading separators are eaten
    CHECK(strcmp(p.Get(), "C:\\dir\\sub\\slashed") == 0);

    CHECK(p.AddBackslash() && p.AddBackslash()); // idempotent
    CHECK(strcmp(p.Get(), "C:\\dir\\sub\\slashed\\") == 0);
    p.StripBackslash();
    CHECK(strcmp(p.Get(), "C:\\dir\\sub\\slashed") == 0);

    CHECK(p.CutLastComponent() && strcmp(p.Get(), "C:\\dir\\sub") == 0);
    CHECK(p.CutLastComponent() && strcmp(p.Get(), "C:\\dir") == 0);
    CHECK(p.CutLastComponent() && strcmp(p.Get(), "C:\\") == 0);
    CHECK(!p.CutLastComponent()); // at root
    p.StripBackslash();
    CHECK(strcmp(p.Get(), "C:\\") == 0); // drive root keeps its backslash

    // UNC root protection
    CHECK(p.Set("\\\\server\\share\\dir"));
    CHECK(p.CutLastComponent() && strcmp(p.Get(), "\\\\server\\share") == 0);
    CHECK(!p.CutLastComponent()); // share is part of the root

    // growth far beyond MAX_PATH
    CHECK(p.Set("C:\\"));
    for (int i = 0; i < 200; i++)
        CHECK(p.AppendComponent("component"));
    CHECK(p.Length() > 2000);
    CHECK(p.Get()[p.Length()] == 0);

    // copy semantics
    CSalPathBuf q(p);
    CHECK(q.Length() == p.Length() && strcmp(q.Get(), p.Get()) == 0);
    CSalPathBuf r;
    r = p;
    CHECK(r.Length() == p.Length() && strcmp(r.Get(), p.Get()) == 0);
}

static void TestExtendedPaths()
{
    WCHAR* w = SalPathToWExtAlloc("C:\\dir\\file.txt");
    CHECK(w != NULL && wcscmp(w, L"\\\\?\\C:\\dir\\file.txt") == 0);
    free(w);

    // dot segments collapse, forward slashes convert
    w = SalPathToWExtAlloc("C:\\a\\b\\..\\c\\.\\d");
    CHECK(w != NULL && wcscmp(w, L"\\\\?\\C:\\a\\c\\d") == 0);
    free(w);
    w = SalPathToWExtAlloc("C:/fwd/slash");
    CHECK(w != NULL && wcscmp(w, L"\\\\?\\C:\\fwd\\slash") == 0);
    free(w);

    // UNC form
    w = SalPathToWExtAlloc("\\\\server\\share\\file");
    CHECK(w != NULL && wcscmp(w, L"\\\\?\\UNC\\server\\share\\file") == 0);
    free(w);

    // drive root
    w = SalPathToWExtAlloc("C:\\");
    CHECK(w != NULL && wcscmp(w, L"\\\\?\\C:\\") == 0);
    free(w);

    // Unicode content flows through
    w = SalPathToWExtAlloc("C:\\" U8_C_CARON_NFD "\\" U8_FOLDER_EMOJI ".txt");
    CHECK(w != NULL && wcscmp(w, L"\\\\?\\C:\\c\x030C\\\xD83D\xDCC1.txt") == 0);
    free(w);

    // climbing above the root fails
    CHECK(SalPathToWExtAlloc("C:\\a\\..\\..") == NULL);

    // feature 027 pre-scan: clean paths (skip branch) and the dirty forms it
    // must still route through canonicalization produce identical output
    w = SalPathToWExtAlloc("C:\\already\\clean\\path"); // clean -> skip branch
    CHECK(w != NULL && wcscmp(w, L"\\\\?\\C:\\already\\clean\\path") == 0);
    free(w);
    w = SalPathToWExtAlloc("C:\\trailing\\"); // trailing separator must be stripped
    CHECK(w != NULL && wcscmp(w, L"\\\\?\\C:\\trailing") == 0);
    free(w);
    w = SalPathToWExtAlloc("C:\\double\\\\sep"); // doubled separator must collapse
    CHECK(w != NULL && wcscmp(w, L"\\\\?\\C:\\double\\sep") == 0);
    free(w);
    w = SalPathToWExtAlloc("C:\\a\\.\\b"); // single-dot component must drop
    CHECK(w != NULL && wcscmp(w, L"\\\\?\\C:\\a\\b") == 0);
    free(w);
    w = SalPathToWExtAlloc("C:\\dotted.name\\file..ext"); // dots inside names are NOT components -> clean
    CHECK(w != NULL && wcscmp(w, L"\\\\?\\C:\\dotted.name\\file..ext") == 0);
    free(w);

    // already-extended input passes through
    w = SalPathToWExtAlloc("\\\\?\\C:\\x");
    CHECK(w != NULL && wcscmp(w, L"\\\\?\\C:\\x") == 0);
    free(w);

    // a long (>260) path is accepted, an absurd one (>32767) is rejected
    CSalPathBuf lp;
    CHECK(lp.Set("C:\\"));
    for (int i = 0; i < 60; i++)
        CHECK(lp.AppendComponent("component-eighteen"));
    CHECK(lp.Length() > 1000);
    w = SalPathToWExtAlloc(lp.Get());
    CHECK(w != NULL && wcsncmp(w, L"\\\\?\\C:\\", 7) == 0 && wcslen(w) > 1000);
    free(w);
    for (int i = 0; i < 1800; i++)
        lp.AppendComponent("component-eighteen");
    CHECK(SalPathToWExtAlloc(lp.Get()) == NULL);

    // relative input resolves against the current directory
    w = SalPathToWExtAlloc("relative.txt");
    CHECK(w != NULL && wcsncmp(w, L"\\\\?\\", 4) == 0 && wcsstr(w, L"relative.txt") != NULL);
    free(w);

    // display-form round trip strips the prefix
    char* u8 = SalPathFromWAlloc(L"\\\\?\\C:\\dir\\x");
    CHECK(u8 != NULL && strcmp(u8, "C:\\dir\\x") == 0);
    free(u8);
    u8 = SalPathFromWAlloc(L"\\\\?\\UNC\\server\\share\\x");
    CHECK(u8 != NULL && strcmp(u8, "\\\\server\\share\\x") == 0);
    free(u8);
}

// end-to-end: create, enumerate, rename and delete files at a path
// deeper than the legacy 260-char limit and with an NFD Unicode name
static void TestFileIO()
{
    char tmp[MAX_PATH];
    DWORD n = GetTempPathA(sizeof(tmp), tmp);
    if (n == 0 || n >= sizeof(tmp))
    {
        printf("skipping TestFileIO (no temp path)\n");
        return;
    }

    CSalPathBuf base;
    CHECK(base.Set(tmp));
    CHECK(base.AppendComponent("saltests-deep"));
    CHECK(SalCreateDirectory(base.Get(), NULL) || GetLastError() == ERROR_ALREADY_EXISTS);
    CSalPathBuf dir(base);
    while (dir.Length() < 300) // push well past MAX_PATH
    {
        CHECK(dir.AppendComponent("component-eighteen"));
        CHECK(SalCreateDirectory(dir.Get(), NULL) || GetLastError() == ERROR_ALREADY_EXISTS);
    }
    CHECK(dir.Length() > 300);

    // file with an NFD name at the deep path
    CSalPathBuf file(dir);
    CHECK(file.AppendComponent(U8_C_CARON_NFD "-deep.txt"));
    HANDLE h = SalCreateFile(file.Get(), GENERIC_WRITE, 0, NULL, CREATE_ALWAYS,
                             FILE_ATTRIBUTE_NORMAL, NULL);
    CHECK(h != INVALID_HANDLE_VALUE);
    if (h != INVALID_HANDLE_VALUE)
    {
        DWORD written;
        CHECK(WriteFile(h, "data", 4, &written, NULL) && written == 4);
        CloseHandle(h);
    }

    // attributes work at depth
    CHECK(SalGetFileAttributes(file.Get()) != INVALID_FILE_ATTRIBUTES);
    WIN32_FILE_ATTRIBUTE_DATA fad;
    CHECK(SalGetFileAttributesEx(file.Get(), &fad) && fad.nFileSizeLow == 4);

    // enumeration returns the exact NFD name (no normalization)
    CSalPathBuf pattern(dir);
    CHECK(pattern.AppendComponent("*"));
    WIN32_FIND_DATAW fd;
    HANDLE find = SalFindFirstFile(pattern.Get(), &fd);
    CHECK(find != INVALID_HANDLE_VALUE);
    BOOL seen = FALSE;
    if (find != INVALID_HANDLE_VALUE)
    {
        do
        {
            if (wcscmp(fd.cFileName, L"c\x030C-deep.txt") == 0)
                seen = TRUE;
        } while (SalFindNextFile(find, &fd));
        FindClose(find);
    }
    CHECK(seen);

    // rename + copy + delete at depth
    CSalPathBuf file2(dir);
    CHECK(file2.AppendComponent("renamed-" U8_C_CARON_NFC ".txt"));
    CHECK(SalMoveFile(file.Get(), file2.Get()));
    CSalPathBuf file3(dir);
    CHECK(file3.AppendComponent("copy.txt"));
    CHECK(SalCopyFile(file2.Get(), file3.Get(), TRUE));
    CHECK(SalDeleteFile(file2.Get()));
    CHECK(SalDeleteFile(file3.Get()));

    // tear down the deep tree
    while (dir.Length() > base.Length())
    {
        CHECK(SalRemoveDirectory(dir.Get()));
        CHECK(dir.CutLastComponent());
    }
    CHECK(SalRemoveDirectory(base.Get()));
}

// UTF-8 "ěščř" (2 bytes per char)
#define U8_ESCR "\xC4\x9B\xC5\xA1\xC4\x8D\xC5\x99"

// ---------------------------------------------------------------------------
// Feature 031: byte-length invariants of legal-length name components.
// The defect class: a component's CHARACTER count is legal (<= 255) but its
// UTF-8 BYTE length exceeds legacy MAX_PATH-sized buffers. The reported crash
// was a 215-char Czech-diacritics directory name = 330 UTF-8 bytes smashing
// a char[MAX_PATH + 4] in the panel paint path.

// the user's exact repro-name unit (43 chars):
// "ýášřtščýáíf buaweýáh čáíhšáífšfhčíáéfšh dnf"
static const WCHAR REPRO_UNIT_W[] =
    L"\x00FD\x00E1\x0161\x0159t\x0161\x010D\x00FD\x00E1\x00ED"
    L"f "
    L"buawe\x00FD\x00E1h "
    L"\x010D\x00E1\x00EDh\x0161\x00E1\x00ED"
    L"f\x0161"
    L"fh\x010D\x00ED\x00E1\x00E9"
    L"f\x0161h dnf";

// builds the full 215-char repro name (5x the unit) into 'w' (>= 216 WCHARs)
static void BuildReproNameW(WCHAR* w)
{
    w[0] = 0;
    for (int i = 0; i < 5; i++)
        wcscat(w, REPRO_UNIT_W);
}

static void TestLongComponentNames()
{
    // the repro-name unit is exactly 43 chars, the full name 215 chars
    CHECK(wcslen(REPRO_UNIT_W) == 43);
    WCHAR reproW[256];
    BuildReproNameW(reproW);
    CHECK(wcslen(reproW) == 215);

    // 215 diacritics chars -> 330 UTF-8 bytes: legal component length whose
    // byte length exceeds the legacy MAX_PATH+4 buffers (the defect class),
    // yet fits the established SAL_FIND_NAME_U8 bound with the DWORD
    // terminator used by the paint path
    char* u8 = SalWToU8Alloc(reproW);
    CHECK(u8 != NULL);
    if (u8 != NULL)
    {
        size_t len = strlen(u8);
        CHECK(len == 330);
        CHECK(len > MAX_PATH + 4);              // overflows the pre-031 buffers
        CHECK(len + 4 <= SAL_FIND_NAME_U8 + 4); // fits the 031 buffers incl. DWORD terminator
        WCHAR* back = SalU8ToWAlloc(u8);        // byte-exact round trip
        CHECK(back != NULL && wcscmp(back, reproW) == 0);
        free(back);
        free(u8);
    }

    // worst case: 255 x U+4E2D (3-byte UTF-8) = 765 bytes; DWORD-terminated
    // copies need 769 bytes and must fit SAL_FIND_NAME_U8 + 4
    WCHAR w255[256];
    for (int i = 0; i < 255; i++)
        w255[i] = 0x4E2D;
    w255[255] = 0;
    u8 = SalWToU8Alloc(w255);
    CHECK(u8 != NULL);
    if (u8 != NULL)
    {
        CHECK(strlen(u8) == 3 * 255);
        CHECK(strlen(u8) + 4 <= SAL_FIND_NAME_U8 + 4);
        free(u8);
    }

    // 255 UTF-16 units of surrogate pairs (127 pairs = 254 units): 4 UTF-8
    // bytes per pair -> 508 bytes, inside the same bound
    WCHAR wsurr[256];
    for (int i = 0; i < 127; i++)
    {
        wsurr[2 * i] = 0xD83D;     // U+1F4C1 high surrogate
        wsurr[2 * i + 1] = 0xDCC1; // U+1F4C1 low surrogate
    }
    wsurr[254] = 0;
    u8 = SalWToU8Alloc(wsurr);
    CHECK(u8 != NULL);
    if (u8 != NULL)
    {
        CHECK(strlen(u8) == 4 * 127);
        CHECK(strlen(u8) + 4 <= SAL_FIND_NAME_U8 + 4);
        free(u8);
    }

    // SalConvertFindDataW: a maximum-length component converts completely and
    // round-trips byte-exactly into the enumeration-sized buffer
    WIN32_FIND_DATAW fdw;
    memset(&fdw, 0, sizeof(fdw));
    wcscpy(fdw.cFileName, w255); // 255 chars, the OS component maximum
    char nameU8[SAL_FIND_NAME_U8];
    char dosNameU8[3 * 14 + 2];
    SalConvertFindDataW(&fdw, NULL, nameU8, sizeof(nameU8), dosNameU8, sizeof(dosNameU8));
    CHECK(strlen(nameU8) == 3 * 255);
    WCHAR* back = SalU8ToWAlloc(nameU8);
    CHECK(back != NULL && wcscmp(back, w255) == 0);
    free(back);
    CHECK(dosNameU8[0] == 0); // empty alternate name stays empty

    // the repro name converts through the same route
    wcscpy(fdw.cFileName, reproW);
    SalConvertFindDataW(&fdw, NULL, nameU8, sizeof(nameU8), NULL, 0);
    CHECK(strlen(nameU8) == 330);

    // fail-safe: a too-small target yields an EMPTY string -- never a
    // silently truncated name that could act as a different identity
    char tooSmall[64];
    SalConvertFindDataW(&fdw, NULL, tooSmall, sizeof(tooSmall), NULL, 0);
    CHECK(tooSmall[0] == 0);

    // on-disk: create the exact repro directory name, enumerate its parent,
    // and require the byte-exact 330-byte name back (the crash scenario data)
    char tmp[MAX_PATH];
    DWORD n = GetTempPathA(sizeof(tmp), tmp);
    if (n == 0 || n >= sizeof(tmp))
    {
        printf("skipping TestLongComponentNames disk part (no temp path)\n");
        return;
    }
    CSalPathBuf base;
    CHECK(base.Set(tmp));
    CHECK(base.AppendComponent("saltests-deep"));
    CHECK(SalCreateDirectory(base.Get(), NULL) || GetLastError() == ERROR_ALREADY_EXISTS);
    char* reproU8 = SalWToU8Alloc(reproW);
    CHECK(reproU8 != NULL);
    if (reproU8 != NULL)
    {
        CSalPathBuf dir(base);
        CHECK(dir.AppendComponent(reproU8));
        CHECK(SalCreateDirectory(dir.Get(), NULL) || GetLastError() == ERROR_ALREADY_EXISTS);

        CSalPathBuf pattern(base);
        CHECK(pattern.AppendComponent("*"));
        WIN32_FIND_DATAW fd;
        HANDLE find = SalFindFirstFile(pattern.Get(), &fd);
        CHECK(find != INVALID_HANDLE_VALUE);
        BOOL seen = FALSE;
        if (find != INVALID_HANDLE_VALUE)
        {
            do
            {
                if (wcscmp(fd.cFileName, reproW) == 0)
                {
                    seen = TRUE;
                    char foundU8[SAL_FIND_NAME_U8];
                    SalConvertFindDataW(&fd, NULL, foundU8, sizeof(foundU8), NULL, 0);
                    CHECK(strlen(foundU8) == 330);
                    CHECK(strcmp(foundU8, reproU8) == 0);
                }
            } while (SalFindNextFile(find, &fd));
            FindClose(find);
        }
        CHECK(seen);

        CHECK(SalRemoveDirectory(dir.Get()));
        free(reproU8);
    }
    CHECK(SalRemoveDirectory(base.Get()));
}

static void TestDropFiles()
{
    // --- build a wide CF_HDROP block from two >MAX_PATH Czech-diacritics paths
    char longA[600];
    char longB[600];
    strcpy(longA, "C:\\salamander-test\\" U8_ESCR);
    while (strlen(longA) < 560)
        strcat(longA, "\\dir-" U8_ESCR);
    strcpy(longB, longA);
    strcat(longB, "\\soubor-" U8_ESCR ".txt");
    const char* paths[2] = {longA, longB};

    HGLOBAL h = SalBuildWideDropFiles(paths, 2);
    CHECK(h != NULL);
    if (h != NULL)
    {
        SIZE_T size = GlobalSize(h);
        DROPFILES* df = (DROPFILES*)GlobalLock(h);
        CHECK(df != NULL);
        if (df != NULL)
        {
            CHECK(df->fWide);
            CHECK(df->pFiles == sizeof(DROPFILES));

            // scan reports both paths and the exact longest length
            WCHAR* wideA = SalU8ToWAlloc(longA);
            WCHAR* wideB = SalU8ToWAlloc(longB);
            CHECK(wideA != NULL && wideB != NULL);
            int longest = 0;
            CHECK(SalScanDropFiles(df, size, &longest) == 2);
            if (wideA != NULL && wideB != NULL)
            {
                CHECK(longest == (int)wcslen(wideB));
                CHECK((int)wcslen(wideB) > MAX_PATH); // the scenario actually exceeds the legacy limit

                // content round-trip: both wide strings are stored verbatim
                const WCHAR* s = (const WCHAR*)((const BYTE*)df + df->pFiles);
                CHECK(wcscmp(s, wideA) == 0);
                s += wcslen(s) + 1;
                CHECK(wcscmp(s, wideB) == 0);
                s += wcslen(s) + 1;
                CHECK(*s == 0); // double-NUL terminated

                // malformed blocks are rejected, never over-read (exact content
                // size -- GlobalSize may round the allocation up)
                SIZE_T exactSize = sizeof(DROPFILES) +
                                   (wcslen(wideA) + 1 + wcslen(wideB) + 1 + 1) * sizeof(WCHAR);
                CHECK(SalScanDropFiles(df, sizeof(DROPFILES) - 1, NULL) == -1);         // truncated header
                CHECK(SalScanDropFiles(df, exactSize - 2 * sizeof(WCHAR), NULL) == -1); // missing double-NUL
            }
            free(wideA);
            free(wideB);

            GlobalUnlock(h);
        }
        GlobalFree(h);
    }

    // --- ANSI (fWide=0) blocks are scanned too (foreign legacy producers)
    {
        const char list[] = "C:\\aa\0C:\\bbb\0";
        BYTE block[sizeof(DROPFILES) + sizeof(list)];
        memset(block, 0, sizeof(block));
        DROPFILES* df = (DROPFILES*)block;
        df->pFiles = sizeof(DROPFILES);
        df->fWide = FALSE;
        memcpy(block + sizeof(DROPFILES), list, sizeof(list));
        int longest = 0;
        CHECK(SalScanDropFiles(df, sizeof(block), &longest) == 2);
        CHECK(longest == 6); // "C:\bbb"
    }

    // --- degenerate inputs
    CHECK(SalBuildWideDropFiles(NULL, 1) == NULL);
    CHECK(SalBuildWideDropFiles(paths, 0) == NULL);
    const char* invalid[1] = {"\xC4"}; // invalid UTF-8: caller must fall back to the legacy route
    CHECK(SalBuildWideDropFiles(invalid, 1) == NULL);
    CHECK(SalScanDropFiles(NULL, 1000, NULL) == -1);
}

// ---------------------------------------------------------------------------
// Feature 028: Dark theme palette tests (src/common/themes_palette.h)
// WCAG 2.x contrast: standard text >= 4.5:1, disabled/secondary >= 3:1 (SC-005)

static double SrgbChannel(int c)
{
    double s = c / 255.0;
    return s <= 0.03928 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4);
}

static double Luminance(COLORREF c)
{
    return 0.2126 * SrgbChannel(GetRValue(c)) +
           0.7152 * SrgbChannel(GetGValue(c)) +
           0.0722 * SrgbChannel(GetBValue(c));
}

static double ContrastRatio(COLORREF a, COLORREF b)
{
    double la = Luminance(a) + 0.05;
    double lb = Luminance(b) + 0.05;
    return la > lb ? la / lb : lb / la;
}

// positional views of the palette data (order = list order in the header)
enum DarkPanelIdx
{
#define TP_ENUM(name, r, g, b) DP_##name,
    THEME_DARK_PANEL_COLORS(TP_ENUM)
#undef TP_ENUM
        DP_COUNT
};

enum DarkViewerIdx
{
#define TV_ENUM(name, r, g, b) DV_##name,
    THEME_DARK_VIEWER_COLORS(TV_ENUM)
#undef TV_ENUM
        DV_COUNT
};

static void TestDarkThemePalette()
{
    // --- chrome palette: build the LUT the app uses
    COLORREF chrome[64];
    BOOL chromeSet[64] = {0};
    for (int i = 0; i < 64; i++)
        chrome[i] = 0;
#define TC_FILL(idx, r, g, b) \
    chrome[idx] = RGB(r, g, b); \
    chromeSet[idx] = TRUE;
    THEME_DARK_SYSCOLORS(TC_FILL)
#undef TC_FILL

    // every COLOR_* index the application draws with must be mapped
    // (COLOR_3DFACE==COLOR_BTNFACE and COLOR_3DSHADOW==COLOR_BTNSHADOW share values)
    const int drawnIndexes[] = {
        COLOR_WINDOW, COLOR_WINDOWTEXT, COLOR_WINDOWFRAME, COLOR_BTNFACE,
        COLOR_BTNTEXT, COLOR_BTNSHADOW, COLOR_BTNHIGHLIGHT, COLOR_3DLIGHT,
        COLOR_3DDKSHADOW, COLOR_HIGHLIGHT, COLOR_HIGHLIGHTTEXT, COLOR_GRAYTEXT,
        COLOR_HOTLIGHT, COLOR_INFOTEXT, COLOR_INFOBK, COLOR_CAPTIONTEXT,
        COLOR_ACTIVECAPTION, COLOR_INACTIVECAPTION, COLOR_INACTIVECAPTIONTEXT,
        COLOR_SCROLLBAR, COLOR_MENU, COLOR_MENUTEXT, COLOR_3DFACE, COLOR_3DSHADOW};
    for (int i = 0; i < (int)(sizeof(drawnIndexes) / sizeof(drawnIndexes[0])); i++)
        CHECK(chromeSet[drawnIndexes[i]]);

    // chrome text/background pairs (>= 4.5:1; disabled text >= 3:1)
    CHECK(ContrastRatio(chrome[COLOR_WINDOWTEXT], chrome[COLOR_WINDOW]) >= 4.5);
    CHECK(ContrastRatio(chrome[COLOR_BTNTEXT], chrome[COLOR_BTNFACE]) >= 4.5);
    CHECK(ContrastRatio(chrome[COLOR_MENUTEXT], chrome[COLOR_MENU]) >= 4.5);
    CHECK(ContrastRatio(chrome[COLOR_HIGHLIGHTTEXT], chrome[COLOR_HIGHLIGHT]) >= 4.5);
    CHECK(ContrastRatio(chrome[COLOR_INFOTEXT], chrome[COLOR_INFOBK]) >= 4.5);
    CHECK(ContrastRatio(chrome[COLOR_CAPTIONTEXT], chrome[COLOR_ACTIVECAPTION]) >= 4.5);
    CHECK(ContrastRatio(chrome[COLOR_INACTIVECAPTIONTEXT], chrome[COLOR_INACTIVECAPTION]) >= 4.5);
    CHECK(ContrastRatio(chrome[COLOR_HOTLIGHT], chrome[COLOR_WINDOW]) >= 4.5);
    CHECK(ContrastRatio(chrome[COLOR_HOTLIGHT], chrome[COLOR_BTNFACE]) >= 4.5);
    CHECK(ContrastRatio(chrome[COLOR_GRAYTEXT], chrome[COLOR_BTNFACE]) >= 3.0);
    CHECK(ContrastRatio(chrome[COLOR_GRAYTEXT], chrome[COLOR_WINDOW]) >= 3.0);

    // feature 049: input/content surfaces sit LIGHTER than the dialog face
    // (Windows 11 dark convention; kills the "black hole" field look)
    CHECK(Luminance(chrome[COLOR_WINDOW]) > Luminance(chrome[COLOR_BTNFACE]));

    // feature 049: the hyperlink color must stay readable on the About
    // dialog's branded navy background (TC_COLOR_NAVY in src/logo.cpp)
    CHECK(ContrastRatio(chrome[COLOR_HOTLIGHT], RGB(0x0A, 0x14, 0x24)) >= 4.5);

    // --- panel palette: exact index count (positional integrity vs consts.h
    // is additionally static_assert-ed inside the application build)
    CHECK(DP_COUNT == 34);
    CHECK(DV_COUNT == 4);

    COLORREF panel[DP_COUNT];
#define TP_FILL(name, r, g, b) panel[DP_##name] = RGB(r, g, b);
    THEME_DARK_PANEL_COLORS(TP_FILL)
#undef TP_FILL

    // panel item text over its backgrounds (all item states, SC-005)
    CHECK(ContrastRatio(panel[DP_ITEM_FG_NORMAL], panel[DP_ITEM_BK_NORMAL]) >= 4.5);
    CHECK(ContrastRatio(panel[DP_ITEM_FG_SELECTED], panel[DP_ITEM_BK_SELECTED]) >= 4.5);
    CHECK(ContrastRatio(panel[DP_ITEM_FG_FOCUSED], panel[DP_ITEM_BK_FOCUSED]) >= 4.5);
    CHECK(ContrastRatio(panel[DP_ITEM_FG_FOCSEL], panel[DP_ITEM_BK_FOCSEL]) >= 4.5);
    CHECK(ContrastRatio(panel[DP_ITEM_FG_HIGHLIGHT], panel[DP_ITEM_BK_HIGHLIGHT]) >= 4.5);
    CHECK(ContrastRatio(panel[DP_HOT_PANEL], panel[DP_ITEM_BK_NORMAL]) >= 4.5);
    CHECK(ContrastRatio(panel[DP_ACTIVE_CAPTION_FG], panel[DP_ACTIVE_CAPTION_BK]) >= 4.5);
    CHECK(ContrastRatio(panel[DP_INACTIVE_CAPTION_FG], panel[DP_INACTIVE_CAPTION_BK]) >= 4.5);
    CHECK(ContrastRatio(panel[DP_HOT_ACTIVE], panel[DP_ACTIVE_CAPTION_BK]) >= 4.5);
    CHECK(ContrastRatio(panel[DP_HOT_INACTIVE], panel[DP_INACTIVE_CAPTION_BK]) >= 4.5);
    CHECK(ContrastRatio(panel[DP_PROGRESS_FG_NORMAL], panel[DP_PROGRESS_BK_NORMAL]) >= 4.5);
    CHECK(ContrastRatio(panel[DP_PROGRESS_FG_SELECTED], panel[DP_PROGRESS_BK_SELECTED]) >= 4.5);

    COLORREF viewer[DV_COUNT];
#define TV_FILL(name, r, g, b) viewer[DV_##name] = RGB(r, g, b);
    THEME_DARK_VIEWER_COLORS(TV_FILL)
#undef TV_FILL
    CHECK(ContrastRatio(viewer[DV_VIEWER_FG_NORMAL], viewer[DV_VIEWER_BK_NORMAL]) >= 4.5);
    CHECK(ContrastRatio(viewer[DV_VIEWER_FG_SELECTED], viewer[DV_VIEWER_BK_SELECTED]) >= 4.5);

    // all surfaces are truly dark (backgrounds darker than mid-gray)
    CHECK(Luminance(chrome[COLOR_WINDOW]) < 0.1);
    CHECK(Luminance(chrome[COLOR_BTNFACE]) < 0.1);
    CHECK(Luminance(panel[DP_ITEM_BK_NORMAL]) < 0.1);
    CHECK(Luminance(viewer[DV_VIEWER_BK_NORMAL]) < 0.1);
}

// ---------------------------------------------------------------------------
// Feature 044: dark Find-window surfaces (status bar, separators, disabled
// edit/toolbar text, progress bar) draw with these palette pairs (SC-002)

static void TestFindDarkModeSurfaces()
{
    COLORREF chrome[64];
    for (int i = 0; i < 64; i++)
        chrome[i] = 0;
#define TC_FILL(idx, r, g, b) chrome[idx] = RGB(r, g, b);
    THEME_DARK_SYSCOLORS(TC_FILL)
#undef TC_FILL

    // status bar text / "Found Items" label / header labels on the dark face
    CHECK(ContrastRatio(chrome[COLOR_BTNTEXT], chrome[COLOR_BTNFACE]) >= 4.5);
    // disabled edit text ("No Advanced Options") and disabled toolbar captions
    CHECK(ContrastRatio(chrome[COLOR_GRAYTEXT], chrome[COLOR_BTNFACE]) >= 3.0);
    // etched separators: a visible dark bevel pair, both halves darker than
    // the light-theme lines they replace (255/160)
    CHECK(chrome[COLOR_3DDKSHADOW] != chrome[COLOR_3DLIGHT]);
    CHECK(Luminance(chrome[COLOR_3DDKSHADOW]) < 0.1);
    CHECK(Luminance(chrome[COLOR_3DLIGHT]) < 0.1);
    // progress bar: accent bar visible on its dark track
    CHECK(ContrastRatio(chrome[COLOR_HIGHLIGHT], chrome[COLOR_BTNSHADOW]) >= 1.5);
    CHECK(Luminance(chrome[COLOR_BTNSHADOW]) < 0.1);
}

// ---------------------------------------------------------------------------
// Feature 029: dark adaptation of toolbar glyph colors
// (ThemeDarkAdaptColor in src/common/themes_palette.h; SC-002: adapted
// neutral strokes must reach >= 3:1 contrast on the dark COLOR_BTNFACE)

static void TestDarkIconColorAdaptation()
{
    const COLORREF darkBtnFace = RGB(45, 45, 45); // THEME_DARK_SYSCOLORS COLOR_BTNFACE
    int r, g, b;

    // pure black (typical outline) becomes the lightest adapted gray
    r = g = b = 0;
    ThemeDarkAdaptColor(&r, &g, &b);
    CHECK(r == 220 && g == 220 && b == 220);

    // neutral sweep [0,140): output stays neutral, lands in (140,220],
    // is monotonically non-increasing, and clears 3:1 on the dark toolbar
    int prev = 220;
    for (int v = 0; v < 140; v++)
    {
        r = g = b = v;
        ThemeDarkAdaptColor(&r, &g, &b);
        CHECK(r == g && g == b);
        CHECK(r > 140 && r <= 220);
        CHECK(r <= prev);
        prev = r;
        CHECK(ContrastRatio(RGB(r, g, b), darkBtnFace) >= 3.0);
    }

    // neutrals at/above 140 and white are left untouched
    for (int v = 140; v <= 255; v += 5)
    {
        r = g = b = v;
        ThemeDarkAdaptColor(&r, &g, &b);
        CHECK(r == v && g == v && b == v);
    }
    r = g = b = 255;
    ThemeDarkAdaptColor(&r, &g, &b);
    CHECK(r == 255 && g == 255 && b == 255);

    // dark saturated color: max channel scales to 170, hue (ratios) kept
    r = 100, g = 0, b = 0;
    ThemeDarkAdaptColor(&r, &g, &b);
    CHECK(r == 170 && g == 0 && b == 0);
    r = 60, g = 30, b = 0; // 2:1 red:green ratio must survive
    ThemeDarkAdaptColor(&r, &g, &b);
    CHECK(r == 170 && g == 85 && b == 0);
    r = 0, g = 0, b = 100; // dark blue accent brightens toward the same hue
    ThemeDarkAdaptColor(&r, &g, &b);
    CHECK(r == 0 && g == 0 && b == 170);

    // bright saturated accents are left untouched (colored icons stay colored)
    r = 255, g = 201, b = 14; // folder yellow
    ThemeDarkAdaptColor(&r, &g, &b);
    CHECK(r == 255 && g == 201 && b == 14);
    r = 0, g = 0, b = 255;
    ThemeDarkAdaptColor(&r, &g, &b);
    CHECK(r == 0 && g == 0 && b == 255);
    r = 200, g = 60, b = 60;
    ThemeDarkAdaptColor(&r, &g, &b);
    CHECK(r == 200 && g == 60 && b == 60);

    // deterministic: same input always produces the same output
    int r2 = 17, g2 = 17, b2 = 17;
    r = 17, g = 17, b = 17;
    ThemeDarkAdaptColor(&r, &g, &b);
    ThemeDarkAdaptColor(&r2, &g2, &b2);
    CHECK(r == r2 && g == g2 && b == b2);
}

// Feature 042: the file-name display-encoding defect class.
//
// Both reported defects were call-site defects, not helper defects, so these
// tests are the regression floor rather than the guard -- tools/check_encoding.py
// is what actually catches a recurrence. What is asserted here is the property
// every repaired call site depends on: a message composed from a localized
// template and a file name survives only when BOTH halves are UTF-8, and one
// legacy-codepage ingredient costs the whole message its wide rendering path.
static void TestComposedMessageEncoding()
{
    // The name as the file system holds it: "emoji-<U+1F642>-dir - Copy<U+011B>"
    const char* u8Name = "emoji-\xF0\x9F\x99\x82-dir - Copy\xC4\x9B";

    // (1) all-UTF-8 composition -> valid UTF-8 -> the wide path is available
    char composed[512];
    _snprintf_s(composed, _TRUNCATE, "Slozka obsahuje: %s", u8Name);
    WCHAR wide[512];
    CHECK(SalU8ToW(composed, -1, wide, _countof(wide)) != 0);
    CHECK(wcsstr(wide, L"emoji-") != NULL);
    CHECK(wcsstr(wide, L"\xD83D\xDE42") != NULL); // the surrogate pair survived
    CHECK(wcsstr(wide, L"\x011B") != NULL);       // e-caron survived

    // (2) mixed composition: one legacy-codepage byte in the template.
    //     0xE1 alone is 'a-acute' in CP1250 and is not valid UTF-8, which is
    //     exactly how a localized LoadStr() template poisoned the message.
    //     Strict conversion must REFUSE the whole string -- that refusal is the
    //     reported defect: CMessageBox then drew everything the legacy way and
    //     the name became mojibake.
    char mixed[512];
    _snprintf_s(mixed, _TRUNCATE, "Slo\xE1ka obsahuje: %s", u8Name);
    CHECK(SalU8ToW(mixed, -1, wide, _countof(wide)) == 0);

    // (3) the lenient display conversion never loses the whole string: the bad
    //     byte costs exactly one U+FFFD and the name beside it stays intact.
    CHECK(SalU8ToWDisplay(mixed, -1, wide, _countof(wide)) != 0);
    CHECK(wcsstr(wide, L"\xD83D\xDE42") != NULL);
    CHECK(wcsstr(wide, L"\x011B") != NULL);
    int replacements = 0;
    for (const WCHAR* p = wide; *p != 0; p++)
        if (*p == 0xFFFD)
            replacements++;
    CHECK(replacements == 1);

    // (4) a name outside the machine's legacy codepage must never be routed
    //     through it. This reproduces the Report 1 symptom directly: every
    //     UTF-16 unit that CP_ACP cannot represent becomes '?', so one emoji
    //     costs two. The assertion documents WHY FR-002 forbids that route.
    CHECK(SalU8ToW(u8Name, -1, wide, _countof(wide)) != 0);
    char lossy[512];
    BOOL usedDefault = FALSE;
    int n = WideCharToMultiByte(CP_ACP, 0, wide, -1, lossy, _countof(lossy), "?", &usedDefault);
    if (n > 0)
    {
        CHECK(usedDefault);                 // the codepage could not hold it
        CHECK(strstr(lossy, "??") != NULL); // two '?' for the one emoji
    }

    // (5) truncation must never split a surrogate pair in half
    // (buffer named 'tiny', not 'small' - the Windows headers define 'small' as char)
    WCHAR tiny[16];
    int written = SalU8ToWDisplay(u8Name, -1, tiny, _countof(tiny));
    if (written > 0)
    {
        WCHAR last = tiny[written - 2]; // before the terminator
        CHECK(!(last >= 0xD800 && last <= 0xDBFF));
    }
}

// Feature 043: a UTF-8 value must never be handed to a byte-oriented display
// call. Three surfaces were reported (the language picker, the configuration
// language field, the F2/F5/F6 caption) and all three shared one shape, so what
// is asserted here is the shape rather than the three instances.
static void TestUiTextEncoding()
{
    // (1) Locale display names are UTF-8 and must survive a round trip. This is
    //     what the language picker shows; it read "Cestina (Cesko)" as mojibake
    //     because the value went to the ANSI ListView_SetItemText.
    char locale[256];
    if (SalGetLocaleInfoU8(MAKELCID(MAKELANGID(LANG_CZECH, SUBLANG_DEFAULT), SORT_DEFAULT),
                           LOCALE_SLANGUAGE, locale, sizeof(locale)) != 0)
    {
        WCHAR wide[256];
        CHECK(SalU8ToW(locale, -1, wide, _countof(wide)) != 0); // valid UTF-8
        char back[256];
        CHECK(SalWToU8(wide, -1, back, sizeof(back)) != 0);
        CHECK(strcmp(locale, back) == 0); // lossless round trip
    }

    // (2) A caption composed from a UTF-8 template and a UTF-8 name stays valid
    //     UTF-8, so the wide drawing path is available. With an ANSI template
    //     the same caption is rejected and the NAME becomes mojibake while the
    //     localized words survive - which is exactly what users reported.
    const char* u8Name = "\xD0\xA2\xD0\xB5\xD1\x81\xD1\x82-\xC4\x9B\xC5\xA1"; // "Test-es" in Cyrillic + Czech
    char caption[512];
    _snprintf_s(caption, _TRUNCATE, "Prejmenovat adresar \"%s\" na", u8Name);
    WCHAR wide[512];
    CHECK(SalU8ToW(caption, -1, wide, _countof(wide)) != 0);
    CHECK(wcsstr(wide, L"\x0422\x0435\x0441\x0442") != NULL); // the Cyrillic survived
    CHECK(wcsstr(wide, L"\x011B\x0161") != NULL);             // the Czech survived

    //     the same caption with ONE legacy-code-page byte in the template is
    //     refused wholesale - the defect, asserted so it cannot come back
    char mixed[512];
    // the hex escapes are split so the letter after them is not swallowed into
    // the escape (\xF8e would parse as one very large character value)
    _snprintf_s(mixed, _TRUNCATE, "P\xF8"
                                  "ejmenovat adres\xE1"
                                  "r \"%s\" na",
                u8Name);
    CHECK(SalU8ToW(mixed, -1, wide, _countof(wide)) == 0);

    // (3) A number carrying the locale thousands separator is UTF-8 too. In
    //     Czech that separator is a non-breaking space (0xC2 0xA0), so a number
    //     sent to a byte-oriented field rendered as "1<A>234".
    char sep[16];
    if (SalGetLocaleInfoU8(LOCALE_USER_DEFAULT, LOCALE_STHOUSAND, sep, sizeof(sep)) != 0)
    {
        if (!SalIsASCII(sep)) // only meaningful where the separator is non-ASCII
        {
            char number[64];
            _snprintf_s(number, _TRUNCATE, "1%s234%s567", sep, sep);
            CHECK(SalU8ToW(number, -1, wide, _countof(wide)) != 0);
        }
    }

    // (4) Truncating a caption must never split a character or a surrogate pair.
    WCHAR tiny[12];
    int written = SalU8ToWDisplay(caption, -1, tiny, _countof(tiny));
    if (written > 0)
    {
        WCHAR last = tiny[written - 2];
        CHECK(!(last >= 0xD800 && last <= 0xDBFF));
    }
}

// Feature 067: the number-composition encoding contract. PrintDiskSize mode 1/2
// composed the ANSI LoadStr() "bytes" plural with a NumberToStr() number that
// carries the UTF-8 locale separator (feature 041), so in Czech the Drive
// Information byte counts were a MIXED string: the strict Sal*U8 sink refused
// it and the legacy fallback drew the separator as "A-circumflex + space".
// PrintDiskSize/NumberToStr are not linked into this exe (they pull in the
// whole application), so what is asserted is the property the fixed call
// sites depend on -- the 052 stance; tools/check_encoding.py guards the
// composition sites themselves.
// Contract: specs/067-fix-drive-info-encoding/contracts/number-format-encoding.md
static void TestNumberCompositionEncoding()
{
    WCHAR wide[256];

    // (1) the repaired composition: digits + the REAL locale separator +
    //     the UTF-8 unit word ("bajtu" with u-ring) is valid UTF-8 wholesale,
    //     so the wide drawing path is available
    char sep[16];
    if (SalGetLocaleInfoU8(LOCALE_USER_DEFAULT, LOCALE_STHOUSAND, sep, sizeof(sep)) == 0)
        strcpy_s(sep, " ");
    char composed[128];
    _snprintf_s(composed, _TRUNCATE, "967%s709%s523%s968 bajt\xC5\xAF", sep, sep, sep);
    CHECK(SalU8ToW(composed, -1, wide, _countof(wide)) != 0);

    // (2) the defect: the same number with the CP1250 unit word (0xF9 =
    //     u-ring in the legacy codepage) forfeits the wide path wholesale --
    //     this refusal is exactly why the "A-circumflex" fallback rendering
    //     appeared in the Ctrl+F1 dialog
    char mixed[128];
    _snprintf_s(mixed, _TRUNCATE, "967\xC2\xA0"
                                  "709\xC2\xA0"
                                  "523\xC2\xA0"
                                  "968 bajt\xF9");
    CHECK(SalU8ToW(mixed, -1, wide, _countof(wide)) == 0);

    // (3) the lenient display mirror keeps everything but the one bad byte
    CHECK(SalU8ToWDisplay(mixed, -1, wide, _countof(wide)) != 0);
    CHECK(wcsstr(wide, L"967\x00A0"
                       L"709") != NULL); // separators decoded
    int replacements = 0;
    for (const WCHAR* p = wide; *p != 0; p++)
        if (*p == 0xFFFD)
            replacements++;
    CHECK(replacements == 1);

    // (4) every separator shape Windows can supply converts strictly once the
    //     composition is all-UTF-8: NBSP (Czech), narrow NBSP (newer French
    //     locales), typographic apostrophe (Swiss)
    static const char* seps[] = {"\xC2\xA0", "\xE2\x80\xAF", "\xE2\x80\x99"};
    int i;
    for (i = 0; i < _countof(seps); i++)
    {
        char num[64];
        _snprintf_s(num, _TRUNCATE, "1%s234%s567 bajt\xC5\xAF", seps[i], seps[i]);
        CHECK(SalU8ToW(num, -1, wide, _countof(wide)) != 0);
    }
}

// Feature 052: the plugin metadata encoding contract. CPluginData's translated
// strings hold UTF-8 from every producer: plugin-supplied ANSI is normalized
// through SalLegacyToU8Alloc at the intake boundaries, and persisted values
// cross the registry facade as UTF-8 (stored UTF-16, returned UTF-8). The
// facade itself (SalRegSetValueExW8/SalRegQueryValueExW8, salamdr6.cpp) is not
// linked into this exe, so what is asserted is the conversion property both
// sides share plus the normalization helper; tools/check_encoding.py guards
// the call sites. The reported defect: the cached name of a not-loaded plugin
// (UTF-8 from the registry) went to the ANSI ListView_SetItemText and rendered
// as "HromadnA(c) ..." mojibake, while a loaded plugin's name (ANSI back then)
// rendered correctly - the same field carried two encodings.
static void TestPluginMetadataEncoding()
{
    // (1) ASCII passes through byte-identical (valid UTF-8 already)
    char* s = SalLegacyToU8Alloc("Disk Map 1.12");
    CHECK(s != NULL && strcmp(s, "Disk Map 1.12") == 0);
    free(s);

    // (2) valid UTF-8 is kept unchanged - the registry-read producer
    //     ("Hromadné přejmenování", the name from the bug report)
    const char* u8Name = "Hromadn\xC3\xA9 p\xC5\x99"
                         "ejmenov\xC3\xA1n\xC3\xAD";
    s = SalLegacyToU8Alloc(u8Name);
    CHECK(s != NULL && strcmp(s, u8Name) == 0);
    free(s);

    // (3) legacy ANSI is converted - the LoadStringA producer. Exact bytes can
    //     be asserted only under CP1250 (the conversion goes through CP_ACP).
    if (GetACP() == 1250)
    {
        const char* ansiName = "Hromadn\xE9 p\xF8"
                               "ejmenov\xE1n\xED";
        s = SalLegacyToU8Alloc(ansiName);
        CHECK(s != NULL && strcmp(s, u8Name) == 0);
        free(s);
    }

    // (4) whatever the codepage, the result is valid UTF-8 - the field must
    //     never carry mixed/legacy bytes to a consumer
    s = SalLegacyToU8Alloc("n\xE1zev \xF8"
                           "ol");
    CHECK(s != NULL);
    if (s != NULL)
    {
        WCHAR wide[64];
        CHECK(SalU8ToW(s, -1, wide, _countof(wide)) != 0);
        free(s);
    }

    // (5) the persistence round trip the registry facade performs (UTF-8 ->
    //     UTF-16 REG_SZ at rest -> UTF-8) is lossless for valid UTF-8 metadata
    WCHAR* w = SalU8ToWAlloc(u8Name);
    CHECK(w != NULL);
    if (w != NULL)
    {
        char* back = SalWToU8Alloc(w);
        CHECK(back != NULL && strcmp(back, u8Name) == 0);
        free(back);
        free(w);
    }

    // (6) clamping cuts only at a UTF-8 sequence boundary: "aé" (61 C3 A9)
    //     limited to 2 bytes drops the whole sequence, never leaves a dangling
    //     lead byte
    s = SalLegacyToU8Alloc("a\xC3\xA9", 2);
    CHECK(s != NULL && strcmp(s, "a") == 0);
    free(s);
    s = SalLegacyToU8Alloc("a\xC3\xA9", 3);
    CHECK(s != NULL && strcmp(s, "a\xC3\xA9") == 0);
    free(s);

    // (7) NULL stays NULL (callers treat it as "keep the previous value")
    CHECK(SalLegacyToU8Alloc(NULL) == NULL);
}

// WTF-8 byte sequences (feature 066): a lone surrogate U+D800..U+DFFF encodes
// as ED A0 80 .. ED BF BF
#define WTF8_D800 "\xED\xA0\x80"
#define WTF8_D801 "\xED\xA0\x81"
#define WTF8_DC00 "\xED\xB0\x80"
#define WTF8_REPRO "Lone" WTF8_D800 "surrogate.txt" // the reported repro name

static void TestWtf8()
{
    // (1) every class of lone surrogate round-trips W -> WTF-8 -> W
    //     (block boundaries + mid-range samples)
    static const WCHAR lone[] = {0xD800, 0xD83D, 0xDBFF, 0xDC00, 0xDDDD, 0xDFFF};
    for (int i = 0; i < _countof(lone); i++)
    {
        WCHAR in[2] = {lone[i], 0};
        char* u8 = SalWToU8Alloc(in);
        CHECK(u8 != NULL && strlen(u8) == 3);
        if (u8 != NULL)
        {
            WCHAR* back = SalU8ToWAlloc(u8);
            CHECK(back != NULL && wcscmp(back, in) == 0);
            free(back);
            free(u8);
        }
    }

    // (2) the reported repro name converts to the exact WTF-8 bytes and back
    const WCHAR* reproW = L"Lone\xD800surrogate.txt";
    char* u8 = SalWToU8Alloc(reproW);
    CHECK(u8 != NULL && strcmp(u8, WTF8_REPRO) == 0);
    if (u8 != NULL)
    {
        WCHAR* back = SalU8ToWAlloc(u8);
        CHECK(back != NULL && wcscmp(back, reproW) == 0);
        free(back);
        free(u8);
    }

    // (3) valid parts stay byte-identical to strict UTF-8 (a valid pair is
    //     one 4-byte sequence, never CESU-8) even next to a lone surrogate
    const WCHAR mixedW[] = {0x010D, 0xD800, 0xD83D, 0xDCC1, 0x0041, 0};
    u8 = SalWToU8Alloc(mixedW);
    CHECK(u8 != NULL && strcmp(u8, "\xC4\x8D" WTF8_D800 "\xF0\x9F\x93\x81"
                                   "A") == 0);
    if (u8 != NULL)
    {
        WCHAR* back = SalU8ToWAlloc(u8);
        CHECK(back != NULL && wcscmp(back, mixedW) == 0);
        free(back);
        free(u8);
    }

    // (4) decoder strictness is preserved for every OTHER malformed input -
    //     the "valid UTF-8, else ANSI" heuristics depend on these failing
    CHECK(SalU8ToWAlloc("\xC0\x80") == NULL);         // overlong 2-byte
    CHECK(SalU8ToWAlloc("\xE0\x80\x80") == NULL);     // overlong 3-byte
    CHECK(SalU8ToWAlloc("\xF0\x80\x80\x80") == NULL); // overlong 4-byte
    CHECK(SalU8ToWAlloc("\xED\xA0") == NULL);         // truncated surrogate sequence
    CHECK(SalU8ToWAlloc("\xED\xA0"
                        "A") == NULL);                // bad continuation byte
    CHECK(SalU8ToWAlloc("\x80") == NULL);             // stray continuation
    CHECK(SalU8ToWAlloc("\xF5\x80\x80\x80") == NULL); // lead above U+10FFFF
    CHECK(SalU8ToWAlloc("\xF4\x90\x80\x80") == NULL); // value above U+10FFFF
    CHECK(SalU8ToWAlloc("\xC4") == NULL);             // truncated 2-byte

    // (5) sized variants keep the terminator counting and the
    //     too-small-buffer -> empty-string fail-safe
    char cbuf[8];
    CHECK(SalWToU8(L"\xD800", 1, cbuf, 8) == 4 && strcmp(cbuf, WTF8_D800) == 0);
    CHECK(SalWToU8(L"\xD800", 1, cbuf, 3) == 0 && cbuf[0] == 0); // no room for the terminator
    WCHAR wbuf[8];
    CHECK(SalU8ToW(WTF8_D800, 3, wbuf, 8) == 2 && wbuf[0] == 0xD800 && wbuf[1] == 0);
    CHECK(SalU8ToW(WTF8_D800, 3, wbuf, 1) == 0 && wbuf[0] == 0); // exact-fit failure

    // (6) SalConvertFindDataW carries the true identity - the feature-066
    //     defect was exactly this intake substituting U+FFFD
    WIN32_FIND_DATAW fdw;
    memset(&fdw, 0, sizeof(fdw));
    wcscpy(fdw.cFileName, L"Lone\xD800surrogate.txt");
    char nameU8[SAL_FIND_NAME_U8];
    SalConvertFindDataW(&fdw, NULL, nameU8, sizeof(nameU8), NULL, 0);
    CHECK(strcmp(nameU8, WTF8_REPRO) == 0);
    WCHAR* back = SalU8ToWAlloc(nameU8);
    CHECK(back != NULL && wcscmp(back, fdw.cFileName) == 0);
    free(back);

    // (7) look-alike names (differing only in the lone surrogate) stay
    //     distinct and deterministically ordered; the comparison helpers
    //     must not crash on non-normalizable input (NormalizeString rejects
    //     unpaired surrogates -> byte-wise fallback)
    const char* twinA = "twin" WTF8_D800 ".txt";
    const char* twinB = "twin" WTF8_D801 ".txt";
    CHECK(!SalNameEquivalent(twinA, twinB));
    CHECK(SalNameEquivalent(twinA, twinA));
    CHECK(!SalNameEqualCI(twinA, -1, twinB, -1));
    CHECK(SalNameEqualCI(twinA, -1, twinA, -1));
    int ab = SalCompareNamesUTF8(twinA, -1, twinB, -1, TRUE);
    int ba = SalCompareNamesUTF8(twinB, -1, twinA, -1, TRUE);
    CHECK(ab != 0 && ba != 0 && (ab < 0) != (ba < 0));

    // (8) display decodes WTF-8 to the true unit (paints like Explorer);
    //     non-WTF-8 junk keeps the lenient replacement degradation
    WCHAR disp[32];
    CHECK(SalU8ToWDisplay("Lone" WTF8_D800 "s", -1, disp, _countof(disp)) > 0);
    CHECK(disp[4] == 0xD800 && disp[5] == L's');
    CHECK(SalU8ToWDisplay("a\xFF"
                          "b",
                          -1, disp, _countof(disp)) > 0);
    CHECK(disp[0] == L'a' && disp[1] == 0xFFFD);

    // (9) byte-structural helpers treat a WTF-8 sequence as one character
    CHECK(SalU8CharCount("Lone" WTF8_D800 "s", -1) == 6);
    const char* p = WTF8_D800 "s";
    CHECK(SalU8Next(p) == p + 3);

    // (10) the registry facade's data shape: a sized buffer with embedded
    //      terminators (REG_MULTI_SZ) converts as WTF-8 unit for unit
    const char multi[] = "a\0" WTF8_D800 "\0"; // "a", lone surrogate, double NUL
    WCHAR wmulti[8];
    int wl = SalU8ToW(multi, (int)sizeof(multi), wmulti, _countof(wmulti));
    CHECK(wl == 6 && wmulti[0] == L'a' && wmulti[1] == 0 &&
          wmulti[2] == 0xD800 && wmulti[3] == 0 && wmulti[4] == 0);
}

static void TestWtf8FileOps()
{
    char tmp[MAX_PATH];
    DWORD n = GetTempPathA(sizeof(tmp), tmp);
    if (n == 0 || n >= sizeof(tmp))
    {
        printf("skipping TestWtf8FileOps (no temp path)\n");
        return;
    }

    CSalPathBuf base;
    CHECK(base.Set(tmp));
    CHECK(base.AppendComponent("saltests-wtf8"));
    CHECK(SalCreateDirectory(base.Get(), NULL) || GetLastError() == ERROR_ALREADY_EXISTS);

    // create the reported repro file through the facade (WTF-8 path -> the
    // true wide name lands on disk)
    CSalPathBuf file(base);
    CHECK(file.AppendComponent(WTF8_REPRO));
    HANDLE h = SalCreateFile(file.Get(), GENERIC_WRITE, 0, NULL, CREATE_ALWAYS,
                             FILE_ATTRIBUTE_NORMAL, NULL);
    CHECK(h != INVALID_HANDLE_VALUE);
    if (h != INVALID_HANDLE_VALUE)
    {
        DWORD written;
        CHECK(WriteFile(h, "066", 3, &written, NULL) && written == 3);
        CloseHandle(h);
    }

    // ground truth: enumeration sees the real U+D800 unit and the intake
    // conversion preserves the identity byte for byte
    WIN32_FIND_DATAW fd;
    CSalPathBuf pattern(base);
    CHECK(pattern.AppendComponent("*"));
    HANDLE find = SalFindFirstFile(pattern.Get(), &fd);
    CHECK(find != INVALID_HANDLE_VALUE);
    BOOL seen = FALSE;
    char nameU8[SAL_FIND_NAME_U8];
    if (find != INVALID_HANDLE_VALUE)
    {
        do
        {
            if (wcscmp(fd.cFileName, L"Lone\xD800surrogate.txt") == 0)
            {
                seen = TRUE;
                SalConvertFindDataW(&fd, NULL, nameU8, sizeof(nameU8), NULL, 0);
                CHECK(strcmp(nameU8, WTF8_REPRO) == 0);
            }
        } while (SalFindNextFile(find, &fd));
        FindClose(find);
    }
    CHECK(seen);

    // attributes, copy, move, delete all address the true file; the copy and
    // move DESTINATION names carry lone surrogates too (name fidelity)
    CHECK(SalGetFileAttributes(file.Get()) != INVALID_FILE_ATTRIBUTES);
    CSalPathBuf copy(base);
    CHECK(copy.AppendComponent("copy" WTF8_DC00 ".txt")); // lone LOW surrogate
    CHECK(SalCopyFile(file.Get(), copy.Get(), TRUE));
    WIN32_FILE_ATTRIBUTE_DATA fad;
    CHECK(SalGetFileAttributesEx(copy.Get(), &fad) && fad.nFileSizeLow == 3);
    CSalPathBuf moved(base);
    CHECK(moved.AppendComponent("moved" WTF8_D800 ".txt"));
    CHECK(SalMoveFile(copy.Get(), moved.Get()));
    CHECK(SalGetFileAttributes(copy.Get()) == INVALID_FILE_ATTRIBUTES); // source gone
    CHECK(SalDeleteFile(moved.Get()));
    CHECK(SalDeleteFile(file.Get()));

    // a DIRECTORY with a surrogate name works as an ancestor path component
    CSalPathBuf sub(base);
    CHECK(sub.AppendComponent("dir" WTF8_D800 "sub"));
    CHECK(SalCreateDirectory(sub.Get(), NULL) || GetLastError() == ERROR_ALREADY_EXISTS);
    CSalPathBuf child(sub);
    CHECK(child.AppendComponent("child.txt"));
    h = SalCreateFile(child.Get(), GENERIC_WRITE, 0, NULL, CREATE_ALWAYS,
                      FILE_ATTRIBUTE_NORMAL, NULL);
    CHECK(h != INVALID_HANDLE_VALUE);
    if (h != INVALID_HANDLE_VALUE)
        CloseHandle(h);
    CHECK(SalDeleteFile(child.Get()));
    CHECK(SalRemoveDirectory(sub.Get()));
    CHECK(SalRemoveDirectory(base.Get()));
}

// Feature 068: encoding regression review. Pins the converter behaviors the
// review's site classification relies on (specs/068-encoding-regression-review/
// research.md R3/R7), so a later change to the machinery is caught here before
// the inventory's evidence goes stale. Per-finding property checks (the
// fail-before/pass-after proof required by FR-010) are appended to this
// function as the review confirms defects.
static void TestEncodingReview068()
{
    WCHAR wide[8];
    // (1) SalU8ToW reports "buffer too small" and "invalid input" the same way
    //     (both 0) - defect class DC-20: a caller cannot tell them apart.
    CHECK(SalU8ToW("abcdefghij", -1, wide, _countof(wide)) == 0); // 10 + NUL > 8
    CHECK(SalU8ToW("\xC0\x80", -1, wide, _countof(wide)) == 0);   // overlong NUL
    CHECK(SalU8ToW("abc", -1, wide, _countof(wide)) == 4);        // 3 + terminator

    // (2) SalLegacyToU8Alloc keeps WTF-8 bytes verbatim - its probe is WTF-8
    //     aware (feature 066), so a surrogate-bearing name is never misrouted
    //     through the CP_ACP branch.
    char* s = SalLegacyToU8Alloc(WTF8_REPRO);
    CHECK(s != NULL && strcmp(s, WTF8_REPRO) == 0);
    free(s);

    // (3) the display converter never fails: one U+FFFD per malformed byte,
    //     neighbours intact (DC-14 relies on this being display-only)
    CHECK(SalU8ToWDisplay("a\xF9"
                          "b",
                          -1, wide, _countof(wide)) != 0 &&
          wide[0] == L'a' && wide[1] == 0xFFFD && wide[2] == L'b');

    // (4) the encoder is total for a lone surrogate (066 contract)
    WCHAR lone[2] = {0xD800, 0};
    char u8[8];
    CHECK(SalWToU8(lone, -1, u8, _countof(u8)) != 0 &&
          memcmp(u8, WTF8_D800, 3) == 0 && u8[3] == 0);

    // (5) F-P3-02: srcLen == 0 is reported as a conversion FAILURE, although an
    //     empty string is a legitimate input - callers cannot tell it from
    //     malformed input (DC-20's sibling; salunicode.cpp:247 skips the WTF-8
    //     retry only for srcLen == 0).
    WCHAR w0[8];
    char c0[8];
    CHECK(SalU8ToW("", 0, w0, _countof(w0)) == 0);  // empty by length: "failure"
    CHECK(SalU8ToW("", -1, w0, _countof(w0)) == 1); // the same text by NUL: success
    CHECK(SalWToU8(L"", 0, c0, _countof(c0)) == 0); // the encoder agrees
    CHECK(w0[0] == 0 && c0[0] == 0);                // both still 0-terminate

    // (6) F-P3-09: capacity failure needs room for the terminator too - an
    //     "exact fit" buffer fails exactly like malformed input, which is why
    //     an all-ASCII selection can silently miss the wide shell path.
    WCHAR w3[4];
    CHECK(SalU8ToW("abc", -1, w3, 3) == 0); // 3 units + NUL > 3
    CHECK(SalU8ToW("abc", -1, w3, 4) == 4); // one more WCHAR is enough

    // (7) F-P3-03 (DC-09): the file facade REJECTS a path from an ANSI producer
    //     instead of falling back - the strict conversion is the whole gate.
    //     0xE8 is c-caron in CP1250 and is not valid UTF-8 in any locale.
    const char* acpPath = "C:\\\xE8"
                          "esta\\x.txt";
    SetLastError(ERROR_SUCCESS);
    CHECK(SalGetFileAttributes(acpPath) == INVALID_FILE_ATTRIBUTES);
    CHECK(GetLastError() == ERROR_INVALID_NAME); // never reached the disk
    CHECK(SalPathToWExtAlloc(acpPath) == NULL);  // and this is where it stops

    // (8) F-P1-08/F-P1-10 (DC-09) repair property: SalLegacyToU8Alloc is what
    //     makes an ANSI producer's path usable by the facade. Exact bytes are
    //     assertable only under CP1250 (the conversion goes through CP_ACP).
    if (GetACP() == 1250)
    {
        char* repaired = SalLegacyToU8Alloc(acpPath);
        CHECK(repaired != NULL);
        if (repaired != NULL)
        {
            WCHAR* wr = SalU8ToWAlloc(repaired);
            CHECK(wr != NULL); // convertible now, so the facade would accept it
            free(wr);
            free(repaired);
        }
    }

    // (9) F-P2-01/F-P6-02 (DC-19) mechanism: SalLegacyToU8Alloc's probe is
    //     ALL-OR-NOTHING. One legacy byte anywhere makes the whole buffer
    //     legacy, so the UTF-8 half is re-encoded and reaches the screen as
    //     mojibake - this is why an ANSI template plus a UTF-8 argument is a
    //     defect and not a cosmetic inconsistency.
    if (GetACP() == 1250)
    {
        //   "n<0xE1>zev: " (CP1250) + "<U+016F>" (UTF-8 C5 AF)
        char* mixedFixed = SalLegacyToU8Alloc("n\xE1"
                                              "zev: \xC5\xAF");
        //   CP1250 reads C5 AF as L-acute + Z-dot => C4 B9 C5 BB
        CHECK(mixedFixed != NULL && strstr(mixedFixed, "\xC4\xB9\xC5\xBB") != NULL);
        free(mixedFixed);
    }
    //   and the composed buffer itself has no wide path at all
    CHECK(SalU8ToWAlloc("Zobrazit polo\xBE"
                        "ku Obnoven\xC3\xAD") == NULL); // CP1250 z-caron + UTF-8

    // (10) F-P3-07 (DC-12): clamping a UTF-8 path in BYTES cuts a sequence, and
    //      the strict converter then refuses the WHOLE string - one truncated
    //      character costs the entire status-bar hint. The display converter
    //      keeps everything but the cut.
    char clipped[8];
    lstrcpyn(clipped, "abc\xC4\x8D"
                      "def",
             5); // 4 bytes + NUL: cuts C4 8D in half
    CHECK(SalU8ToW(clipped, -1, w0, _countof(w0)) == 0);
    CHECK(SalU8ToWDisplay(clipped, -1, w0, _countof(w0)) != 0 &&
          w0[0] == L'a' && w0[3] == 0xFFFD);
    //      the byte-safe way to clamp: walk characters, never bytes
    CHECK(SalU8CharCount("abc\xC4\x8D"
                         "def",
                         -1) == 7);
    const char* walk = "\xC4\x8D"
                       "def";
    CHECK(SalU8Next(walk) == walk + 2); // one character, two bytes

    // (11) F-P1-16/F-P1-18 (DC-20) caller property: on failure the converter
    //      0-terminates the destination, so a caller that ignores the return
    //      value gets an EMPTY string - never the indeterminate stack contents
    //      those two findings describe. The defect is the caller's, and this is
    //      the guarantee a fix can rely on.
    WCHAR poisoned[8];
    int k;
    for (k = 0; k < _countof(poisoned); k++)
        poisoned[k] = L'X';
    CHECK(SalU8ToW("\xC0\x80", -1, poisoned, _countof(poisoned)) == 0);
    CHECK(poisoned[0] == 0);

    // (12) WTF-8 stays byte-identical to UTF-8 for valid text, and the pair
    //      round-trips a lone surrogate through the display converter too -
    //      P1's and P6's operational sites all assume this (066 contract).
    WCHAR wtf[32];
    char back[32];
    CHECK(SalU8ToW(WTF8_REPRO, -1, wtf, _countof(wtf)) != 0);
    CHECK(SalWToU8(wtf, -1, back, _countof(back)) != 0 &&
          strcmp(back, WTF8_REPRO) == 0);
    CHECK(SalU8ToWDisplay(WTF8_REPRO, -1, wtf, _countof(wtf)) != 0 &&
          wtf[4] == 0xD800); // display keeps the true unit, not U+FFFD
}

// ****************************************************************************
// Feature 069 - the contained fixes finished from the 068 handoff.
//
// One block per fix, numbered by its finding id.  Each block was proven to
// fail on the pre-fix tree before the fix landed (spec FR-008), which is why
// the assertions are written against the defect, not against the helper.

static void TestEncodingFixes069()
{
    // ---- F-P2-11 / F-P4-07: SalU8TrimIncompleteTail -----------------------
    // A byte-count clamp (lstrcpyn into a fixed field) can cut a multi-byte
    // character in half; the torn tail then fails every strict probe and the
    // whole string is drawn through the legacy code page.  Hex escapes are used
    // deliberately: this file has no BOM, so a literal non-ASCII character
    // would be read through the compiler's default code page.
    char buf[32];

    // (1) a COMPLETE character at the end must survive untouched.  This is the
    //     case a naive "strip trailing continuation bytes" loop gets wrong: the
    //     last byte of y-acute (C3 BD) IS a continuation byte.
    strcpy(buf, "Stru\xC4\x8D" "n\xC3\xBD"); // "Strucny" with caron and acute
    SalU8TrimIncompleteTail(buf);
    CHECK(strcmp(buf, "Stru\xC4\x8D" "n\xC3\xBD") == 0);

    // (2) a cut 2-byte sequence (lead byte only) is dropped whole
    strcpy(buf, "Stru\xC4\x8D" "n\xC3");
    SalU8TrimIncompleteTail(buf);
    CHECK(strcmp(buf, "Stru\xC4\x8D" "n") == 0);

    // (3) a cut 3-byte sequence, one byte short (EUR needs E2 82 AC)
    strcpy(buf, "ab\xE2\x82");
    SalU8TrimIncompleteTail(buf);
    CHECK(strcmp(buf, "ab") == 0);

    // (4) a cut 4-byte sequence, one and two bytes short (emoji F0 9F 93 81)
    strcpy(buf, "ab\xF0\x9F\x93");
    SalU8TrimIncompleteTail(buf);
    CHECK(strcmp(buf, "ab") == 0);
    strcpy(buf, "ab\xF0\x9F");
    SalU8TrimIncompleteTail(buf);
    CHECK(strcmp(buf, "ab") == 0);

    // (5) the complete 3- and 4-byte forms survive
    strcpy(buf, "ab\xE2\x82\xAC");
    SalU8TrimIncompleteTail(buf);
    CHECK(strcmp(buf, "ab\xE2\x82\xAC") == 0);
    strcpy(buf, "ab\xF0\x9F\x93\x81");
    SalU8TrimIncompleteTail(buf);
    CHECK(strcmp(buf, "ab\xF0\x9F\x93\x81") == 0);

    // (6) ASCII and the empty string are untouched (the English no-op case)
    strcpy(buf, "Detailed");
    SalU8TrimIncompleteTail(buf);
    CHECK(strcmp(buf, "Detailed") == 0);
    strcpy(buf, "");
    SalU8TrimIncompleteTail(buf);
    CHECK(buf[0] == 0);

    // (7) a lone surrogate in WTF-8 (feature 066) is a complete 3-byte
    //     sequence and must survive - internal names carry them
    strcpy(buf, "a\xED\xA0\x80");
    SalU8TrimIncompleteTail(buf);
    CHECK(strcmp(buf, "a\xED\xA0\x80") == 0);

    // (8) NULL is tolerated
    SalU8TrimIncompleteTail(NULL);

    // (9) the point of the helper: a torn tail is rejected by the strict
    //     decoder (so the sink falls back to the legacy draw and the whole
    //     string turns to mojibake), and after trimming it decodes again
    WCHAR w[32];
    strcpy(buf, "Stru\xC4\x8D" "n\xC3");
    CHECK(SalU8ToW(buf, -1, w, _countof(w)) == 0);
    SalU8TrimIncompleteTail(buf);
    CHECK(SalU8ToW(buf, -1, w, _countof(w)) != 0);

    // ---- F-P1-05: the console (OEM) boundary of the external archivers ------
    // The pair must round-trip, because the pack side names the file the
    // archiver has to find and the list side fills CFileData::Name.
    char oem[64], back[64];

    // (1) ASCII round-trips byte-identically in both directions
    CHECK(SalU8ToOEM("readme.txt", oem, sizeof(oem)) == 11);
    CHECK(strcmp(oem, "readme.txt") == 0);
    CHECK(SalOEMToU8(oem, back, sizeof(back)) == 11);
    CHECK(strcmp(back, "readme.txt") == 0);

    // (2) a name the OEM code page CAN represent survives the round trip and is
    //     NOT the same bytes in between - which is the whole point: what the
    //     archiver receives differs from what we store
    const char* u8 = "\xC5\xBElu\xC5\xA5ou\xC4\x8Dk\xC3\xBD.txt"; // zlutoucky.txt with carons
    if (SalU8ToOEM(u8, oem, sizeof(oem)) != 0) // only on a code page that has them
    {
        CHECK(strcmp(oem, u8) != 0);
        CHECK(SalOEMToU8(oem, back, sizeof(back)) != 0);
        CHECK(strcmp(back, u8) == 0); // exact round trip
    }

    // (3) the archiver must never be handed a name that does not exist: either
    //     the character cannot be represented and the call fails cleanly, or it
    //     can and the round trip is exact.  Written this way because the OEM
    //     code page is a machine property - a CJK OEM page (932/936/950) CAN
    //     represent this one, and the check has to hold there too.
    if (SalU8ToOEM("\xE6\xBC\xA2" ".txt", oem, sizeof(oem)) == 0)
    {
        CHECK(oem[0] == 0);
    }
    else
    {
        CHECK(SalOEMToU8(oem, back, sizeof(back)) != 0);
        CHECK(strcmp(back, "\xE6\xBC\xA2" ".txt") == 0);
    }

    // (4) invalid UTF-8 in, no output (the caller keeps the legacy path)
    CHECK(SalU8ToOEM("\xC4", oem, sizeof(oem)) == 0);
    CHECK(oem[0] == 0);

    // (5) a too-small target fails and empties, never truncates an identity
    CHECK(SalU8ToOEM("readme.txt", oem, 4) == 0);
    CHECK(oem[0] == 0);
    CHECK(SalOEMToU8("readme.txt", back, 4) == 0);
    CHECK(back[0] == 0);

    // (6) NULL is tolerated in both directions
    CHECK(SalU8ToOEM(NULL, oem, sizeof(oem)) == 0);
    CHECK(SalOEMToU8(NULL, back, sizeof(back)) == 0);
    CHECK(SalU8ToOEM("x", NULL, 0) == 0);
    CHECK(SalOEMToU8("x", NULL, 0) == 0);

    // ---- SalU8ToACP: UTF-8 back to the active code page --------------------
    // Added late in feature 069 to fix three HIGH review findings: an ANSI
    // OPENFILENAME's lpstrInitialDir (twice) and the plugin-facing
    // CSalamanderGeneral::GetTargetDirectory.  What those callers need is not a
    // particular transliteration - the code page is a machine property - but
    // the SAFETY properties: never overrun, always NUL-terminated, and never a
    // half-written string that a caller would then treat as a real path.
    {
        char acp[MAX_PATH];

        // (1) ASCII is byte-identical, and the length includes the terminator
        CHECK(SalU8ToACP("Hello.txt", acp, sizeof(acp)) == 10);
        CHECK(strcmp(acp, "Hello.txt") == 0);

        // (2) a too-small target fails and EMPTIES - it must never hand back a
        //     truncated path that looks usable (this is the one that matters
        //     for lpstrInitialDir: a half path would open the wrong folder)
        CHECK(SalU8ToACP("Hello.txt", acp, 4) == 0);
        CHECK(acp[0] == 0);

        // (3) NULL is tolerated in both positions
        acp[0] = 'x';
        CHECK(SalU8ToACP(NULL, acp, sizeof(acp)) == 0);
        CHECK(acp[0] == 0); // emptied before the input is even looked at
        CHECK(SalU8ToACP("x", NULL, 0) == 0);
        CHECK(SalU8ToACP("x", acp, 0) == 0);

        // (4) input that is NOT valid UTF-8 is already legacy text: it is
        //     passed through unchanged rather than destroyed, which is what
        //     keeps a caller that never migrated working
        CHECK(SalU8ToACP("\xC4", acp, sizeof(acp)) == 2);
        CHECK((unsigned char)acp[0] == 0xC4 && acp[1] == 0);

        // (5) the pass-through branch respects the target size too
        CHECK(SalU8ToACP("\xC4\xC4\xC4\xC4\xC4\xC4", acp, 3) == 3);
        CHECK(acp[2] == 0);

        // (6) a character the code page cannot express is lossy BY DESIGN -
        //     that is exactly the pre-069 behaviour of these boundaries - but
        //     it must still terminate and stay in bounds.  Written as a branch
        //     because the ACP is a machine property: on CP1250 this becomes the
        //     default character, on CP932/936/950 it converts for real.
        int n = SalU8ToACP("\xE6\xBC\xA2" ".txt", acp, sizeof(acp));
        CHECK(n == 0 || (n > 0 && n <= (int)sizeof(acp) && acp[n - 1] == 0));
    }
    // ---- G6: the per-item enumeration cost, measured not asserted ----------
    // Feature 069 moves several enumerations from FindFirstFile/FindNextFile (A)
    // to SalFindFirstFile + SalConvertFindDataW.  That is a per-item path
    // (Compare Directories walks both trees, the SFX search walks every fixed
    // drive), so the protocol wants a before/after number rather than a claim.
    // Both paths are timed in ONE run over the same directory, so the numbers
    // are directly comparable and cache state is shared.
    {
        const char* perf = getenv("TEMP");
        char pattern[MAX_PATH];
        if (perf != NULL)
        {
            _snprintf_s(pattern, _TRUNCATE, "%s\\salamander-test\\perf\\*", perf);
            WIN32_FIND_DATAA dataA;
            HANDLE hA = FindFirstFileA(pattern, &dataA);
            if (hA != INVALID_HANDLE_VALUE) // fixture present: measure
            {
                int countA = 0;
                DWORD t0 = GetTickCount();
                do
                    countA++;
                while (FindNextFileA(hA, &dataA));
                DWORD ansiMs = GetTickCount() - t0;
                FindClose(hA);

                // the feature's path: wide enumeration + per-entry conversion
                WIN32_FIND_DATAW dataW;
                WIN32_FIND_DATA legacyView;
                char nameU8[SAL_FIND_NAME_U8];
                int countU8 = 0;
                t0 = GetTickCount();
                HANDLE hW = SalFindFirstFile(pattern, &dataW);
                if (hW != INVALID_HANDLE_VALUE)
                {
                    do
                    {
                        SalConvertFindDataW(&dataW, &legacyView, nameU8, sizeof(nameU8), NULL, 0);
                        countU8++;
                    } while (SalFindNextFile(hW, &dataW));
                    FindClose(hW);
                }
                DWORD u8Ms = GetTickCount() - t0;

                printf("  G6 enumeration over %d entries: ANSI %u ms, facade+convert %u ms\n",
                       countA, ansiMs, u8Ms);
                CHECK(countU8 == countA); // the same entries are seen
                // no ratio is asserted: the gate is "within run-to-run noise",
                // which the recorded numbers are compared against by hand
            }
            else
            {
                printf("  G6 enumeration: fixture %s absent, skipped\n", pattern);
            }
        }
    }
}

//*****************************************************************************
//
// feature 071 (configurable command shell): the preset table and locate
// algorithm of src/common/salshell.cpp, driven by a fake machine
//

class CFakeShellProbe : public CSalShellProbe
{
public:
    std::set<std::string> Files;                                // existing files
    std::map<std::string, std::string> Env;                     // environment
    std::map<std::string, std::string> RegValues;               // "ROOT\subkey|value" -> data
    std::map<std::string, std::vector<std::string>> RegSubKeys; // "ROOT\subkey" -> subkey names
    std::map<std::string, std::string> Packages;                // package family -> install folder

    static std::string Root(HKEY root)
    {
        return root == HKEY_LOCAL_MACHINE ? "HKLM\\" : root == HKEY_CURRENT_USER ? "HKCU\\"
                                                                                : "?\\";
    }
    static BOOL Out(const std::string& s, char* buf, int size)
    {
        if ((int)s.size() + 1 > size)
        {
            if (size > 0)
                buf[0] = 0;
            return FALSE;
        }
        memcpy(buf, s.c_str(), s.size() + 1);
        return TRUE;
    }
    void AddReg(HKEY root, const char* subKey, const char* value, const char* data)
    {
        RegValues[Root(root) + subKey + "|" + (value != NULL ? value : "")] = data;
    }
    // 'data' NULL = the subkey exists but has no such value
    void AddSubKey(HKEY root, const char* subKey, const char* name, const char* value, const char* data)
    {
        RegSubKeys[Root(root) + subKey].push_back(name);
        if (data != NULL)
            AddReg(root, (std::string(subKey) + "\\" + name).c_str(), value, data);
    }

    virtual BOOL FileExists(const char* u8Path) const { return Files.count(u8Path) != 0; }
    virtual BOOL GetEnv(const char* name, char* u8Buf, int bufSize) const
    {
        auto it = Env.find(name);
        if (it == Env.end())
        {
            u8Buf[0] = 0;
            return FALSE;
        }
        return Out(it->second, u8Buf, bufSize);
    }
    virtual BOOL RegReadString(HKEY root, const char* subKey, const char* value, char* u8Buf, int bufSize) const
    {
        auto it = RegValues.find(Root(root) + subKey + "|" + (value != NULL ? value : ""));
        if (it == RegValues.end())
        {
            u8Buf[0] = 0;
            return FALSE;
        }
        return Out(it->second, u8Buf, bufSize);
    }
    virtual BOOL RegSubKeyString(HKEY root, const char* subKey, int index, const char* value, char* u8Buf, int bufSize) const
    {
        u8Buf[0] = 0;
        auto it = RegSubKeys.find(Root(root) + subKey);
        if (it == RegSubKeys.end() || index < 0 || index >= (int)it->second.size())
            return FALSE;
        std::string full = std::string(subKey) + "\\" + it->second[index];
        RegReadString(root, full.c_str(), value, u8Buf, bufSize); // "" when the value is missing
        return TRUE;
    }
    virtual BOOL GetPackagePath(const char* family, char* u8Buf, int bufSize) const
    {
        auto it = Packages.find(family);
        if (it == Packages.end())
        {
            u8Buf[0] = 0;
            return FALSE;
        }
        return Out(it->second, u8Buf, bufSize);
    }
};

static BOOL Located(int preset, const CSalShellProbe* probe, const char* expected)
{
    char path[2048];
    BOOL found = SalShellLocatePreset(preset, probe, path, sizeof(path));
    if (!found || strcmp(path, expected) != 0)
    {
        printf("  preset %s: got %s, expected %s\n", SalShellPresetKey(preset), found ? path : "(not found)", expected);
        return FALSE;
    }
    return TRUE;
}

static void TestCommandShell071()
{
    char path[2048];

    // Command Prompt: COMSPEC first, the System32 fallback second, not found last
    {
        CFakeShellProbe p;
        p.Env["COMSPEC"] = "C:\\WINDOWS\\system32\\cmd.exe";
        p.Env["SystemRoot"] = "C:\\WINDOWS";
        p.Files.insert("C:\\WINDOWS\\system32\\cmd.exe");
        p.Files.insert("C:\\WINDOWS\\System32\\cmd.exe");
        CHECK(Located(sspCommandPrompt, &p, "C:\\WINDOWS\\system32\\cmd.exe"));
        p.Env.erase("COMSPEC");
        CHECK(Located(sspCommandPrompt, &p, "C:\\WINDOWS\\System32\\cmd.exe"));
        p.Files.clear();
        strcpy(path, "stale");
        CHECK(!SalShellLocatePreset(sspCommandPrompt, &p, path, sizeof(path)));
        CHECK(path[0] == 0);
    }

    // Windows PowerShell: the fixed System32 location
    {
        CFakeShellProbe p;
        p.Env["SystemRoot"] = "C:\\WINDOWS";
        CHECK(!SalShellLocatePreset(sspWindowsPowerShell, &p, path, sizeof(path)));
        p.Files.insert("C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe");
        CHECK(Located(sspWindowsPowerShell, &p, "C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"));
    }

    // PowerShell 7: Program Files, MSIX alias, family alias, InstalledVersions
    // (a subkey without the exe or without the value must not stop the walk;
    // a trailing backslash in the registry is not doubled), App Paths
    {
        CFakeShellProbe p;
        p.Env["ProgramFiles"] = "C:\\Program Files";
        p.Env["LOCALAPPDATA"] = "C:\\Users\\test\\AppData\\Local";
        const char* versions = "SOFTWARE\\Microsoft\\PowerShellCore\\InstalledVersions";
        p.AddSubKey(HKEY_LOCAL_MACHINE, versions, "{old}", "InstallLocation", "D:\\Old\\PowerShell\\7");
        p.AddSubKey(HKEY_LOCAL_MACHINE, versions, "{empty}", "InstallLocation", NULL);
        p.AddSubKey(HKEY_LOCAL_MACHINE, versions, "{new}", "InstallLocation", "D:\\PowerShell\\7\\");
        p.AddReg(HKEY_LOCAL_MACHINE, "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths\\pwsh.exe", NULL, "E:\\pwsh\\pwsh.exe");
        CHECK(!SalShellLocatePreset(sspPowerShell7, &p, path, sizeof(path)));
        p.Files.insert("E:\\pwsh\\pwsh.exe");
        CHECK(Located(sspPowerShell7, &p, "E:\\pwsh\\pwsh.exe"));
        p.Files.insert("D:\\PowerShell\\7\\pwsh.exe");
        CHECK(Located(sspPowerShell7, &p, "D:\\PowerShell\\7\\pwsh.exe"));
        p.Files.insert("C:\\Users\\test\\AppData\\Local\\Microsoft\\WindowsApps\\Microsoft.PowerShell_8wekyb3d8bbwe\\pwsh.exe");
        CHECK(Located(sspPowerShell7, &p, "C:\\Users\\test\\AppData\\Local\\Microsoft\\WindowsApps\\Microsoft.PowerShell_8wekyb3d8bbwe\\pwsh.exe"));
        p.Files.insert("C:\\Users\\test\\AppData\\Local\\Microsoft\\WindowsApps\\pwsh.exe");
        CHECK(Located(sspPowerShell7, &p, "C:\\Users\\test\\AppData\\Local\\Microsoft\\WindowsApps\\pwsh.exe"));
        p.Files.insert("C:\\Program Files\\PowerShell\\7\\pwsh.exe");
        CHECK(Located(sspPowerShell7, &p, "C:\\Program Files\\PowerShell\\7\\pwsh.exe"));
        CHECK(SalShellPresetArguments(sspPowerShell7)[0] == 0);
    }

    // Windows Terminal: alias, family alias, package folder (known package
    // without wt.exe on disk falls through to not found); recipe "-d ."
    {
        CFakeShellProbe p;
        p.Env["LOCALAPPDATA"] = "C:\\Users\\test\\AppData\\Local";
        const char* pkg = "C:\\Program Files\\WindowsApps\\Microsoft.WindowsTerminal_1.24.11911.0_x64__8wekyb3d8bbwe";
        p.Packages["Microsoft.WindowsTerminal_8wekyb3d8bbwe"] = pkg;
        CHECK(!SalShellLocatePreset(sspWindowsTerminal, &p, path, sizeof(path)));
        p.Files.insert(std::string(pkg) + "\\wt.exe");
        CHECK(Located(sspWindowsTerminal, &p, (std::string(pkg) + "\\wt.exe").c_str()));
        p.Files.insert("C:\\Users\\test\\AppData\\Local\\Microsoft\\WindowsApps\\Microsoft.WindowsTerminal_8wekyb3d8bbwe\\wt.exe");
        CHECK(Located(sspWindowsTerminal, &p, "C:\\Users\\test\\AppData\\Local\\Microsoft\\WindowsApps\\Microsoft.WindowsTerminal_8wekyb3d8bbwe\\wt.exe"));
        p.Files.insert("C:\\Users\\test\\AppData\\Local\\Microsoft\\WindowsApps\\wt.exe");
        CHECK(Located(sspWindowsTerminal, &p, "C:\\Users\\test\\AppData\\Local\\Microsoft\\WindowsApps\\wt.exe"));
        CHECK(strcmp(SalShellPresetArguments(sspWindowsTerminal), "-d .") == 0);
    }

    // Git Bash: HKCU before HKLM (+ WOW6432Node), the Inno uninstall entry, the
    // default folders; a per-user folder with non-ASCII characters stays intact
    {
        CFakeShellProbe p;
        p.Env["ProgramFiles"] = "C:\\Program Files";
        const char* localAppData = "C:\\Users\\Ji" "\xC5\x99" "\xC3\xAD" "\\AppData\\Local"; // Jiří
        p.Env["LOCALAPPDATA"] = localAppData;
        CHECK(!SalShellLocatePreset(sspGitBash, &p, path, sizeof(path)));
        std::string userGit = std::string(localAppData) + "\\Programs\\Git\\git-bash.exe";
        p.Files.insert(userGit);
        CHECK(Located(sspGitBash, &p, userGit.c_str()));
        p.Files.insert("C:\\Program Files\\Git\\git-bash.exe");
        CHECK(Located(sspGitBash, &p, "C:\\Program Files\\Git\\git-bash.exe"));
        p.AddReg(HKEY_LOCAL_MACHINE, "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Git_is1", "InstallLocation", "D:\\Tools\\Git\\");
        p.Files.insert("D:\\Tools\\Git\\git-bash.exe");
        CHECK(Located(sspGitBash, &p, "D:\\Tools\\Git\\git-bash.exe"));
        p.AddReg(HKEY_LOCAL_MACHINE, "SOFTWARE\\WOW6432Node\\GitForWindows", "InstallPath", "D:\\Git32");
        p.Files.insert("D:\\Git32\\git-bash.exe");
        CHECK(Located(sspGitBash, &p, "D:\\Git32\\git-bash.exe"));
        p.AddReg(HKEY_LOCAL_MACHINE, "SOFTWARE\\GitForWindows", "InstallPath", "D:\\Git64");
        p.Files.insert("D:\\Git64\\git-bash.exe");
        CHECK(Located(sspGitBash, &p, "D:\\Git64\\git-bash.exe"));
        p.AddReg(HKEY_CURRENT_USER, "Software\\GitForWindows", "InstallPath", "D:\\GitUser");
        p.Files.insert("D:\\GitUser\\git-bash.exe");
        CHECK(Located(sspGitBash, &p, "D:\\GitUser\\git-bash.exe"));
        CHECK(SalShellPresetArguments(sspGitBash)[0] == 0);
    }

    // ids, keys, recipes, buffer contract
    {
        CFakeShellProbe p;
        CHECK(!SalShellLocatePreset(sspCustom, &p, path, sizeof(path)));
        CHECK(!SalShellLocatePreset(-1, &p, path, sizeof(path)));
        CHECK(!SalShellLocatePreset(sspCount, &p, path, sizeof(path)));
        CHECK(strcmp(SalShellPresetKey(sspCommandPrompt), "cmd") == 0);
        CHECK(strcmp(SalShellPresetKey(sspWindowsPowerShell), "powershell") == 0);
        CHECK(strcmp(SalShellPresetKey(sspPowerShell7), "pwsh") == 0);
        CHECK(strcmp(SalShellPresetKey(sspWindowsTerminal), "wt") == 0);
        CHECK(strcmp(SalShellPresetKey(sspGitBash), "git-bash") == 0);
        CHECK(strcmp(SalShellPresetKey(sspCustom), "custom") == 0);
        CHECK(SalShellPresetKey(99)[0] == 0 && SalShellPresetArguments(99)[0] == 0);
        for (int i = 0; i < sspCount; i++)
            CHECK(strstr(SalShellPresetArguments(i), "$(") == NULL);
        p.Env["COMSPEC"] = "C:\\WINDOWS\\system32\\cmd.exe";
        p.Files.insert("C:\\WINDOWS\\system32\\cmd.exe");
        char tiny[8];
        CHECK(!SalShellLocatePreset(sspCommandPrompt, &p, tiny, sizeof(tiny)) && tiny[0] == 0);
    }

    // SalGetEnvVarU8: a value outside the ANSI code page round-trips; API-like sizes
    {
        const WCHAR* valW = L"C:\\Users\\Ji\u0159\u00ed \u4e2d\\x";
        const char* valU8 = "C:\\Users\\Ji" "\xC5\x99" "\xC3\xAD" " " "\xE4\xB8\xAD" "\\x";
        CHECK(SetEnvironmentVariableW(L"SALTEST_071", valW));
        char buf[100];
        DWORD res = SalGetEnvVarU8("SALTEST_071", buf, sizeof(buf));
        CHECK(res == (DWORD)strlen(valU8) && strcmp(buf, valU8) == 0);
        CHECK(SalGetEnvVarU8("SALTEST_071", buf, 5) == (DWORD)strlen(valU8) + 1); // required size incl. terminator
        CHECK(SalGetEnvVarU8("SALTEST_071", NULL, 0) == (DWORD)strlen(valU8) + 1);
        SetEnvironmentVariableW(L"SALTEST_071", NULL);
        CHECK(SalGetEnvVarU8("SALTEST_071", buf, sizeof(buf)) == 0);
        CHECK(SalGetEnvVarU8("", buf, sizeof(buf)) == 0);
        CHECK(SalGetEnvVarU8(NULL, buf, sizeof(buf)) == 0);
    }

    // the real machine: Command Prompt and Windows PowerShell are part of Windows
    {
        CHECK(SalShellLocatePreset(sspCommandPrompt, NULL, path, sizeof(path)) && path[0] != 0);
        CHECK(SalShellLocatePreset(sspWindowsPowerShell, NULL, path, sizeof(path)) && path[0] != 0);
    }
}

// ---------------------------------------------------------------------------
// feature 078: panel tabs - the pure rules of src/common/saltabs.cpp
// ---------------------------------------------------------------------------

static bool TitleIs(const char* location, const char* expected)
{
    char title[64];
    SalTabTitleFromLocation(location, title, sizeof(title));
    return strcmp(title, expected) == 0;
}

static void TestPanelTabs078()
{
    // titles (spec FR-007)
    CHECK(TitleIs("D:\\Work\\Reports", "Reports"));
    CHECK(TitleIs("D:\\Work\\", "Work"));
    CHECK(TitleIs("D:\\Work", "Work"));
    CHECK(TitleIs("D:\\", "D:\\"));
    CHECK(TitleIs("D:", "D:\\"));
    CHECK(TitleIs("d:\\", "d:\\"));
    CHECK(TitleIs("\\\\server\\share", "\\\\server\\share"));
    CHECK(TitleIs("\\\\server\\share\\", "\\\\server\\share"));
    CHECK(TitleIs("\\\\server\\share\\sub", "sub"));
    CHECK(TitleIs("\\\\server\\share\\sub\\deeper", "deeper"));
    CHECK(TitleIs("C:\\x\\a.zip", "a.zip"));
    CHECK(TitleIs("C:\\x\\a.zip\\sub", "sub"));
    CHECK(TitleIs("C:\\x\\a.zip\\sub\\", "sub"));
    CHECK(TitleIs("ftp:ftp://user@server/dir/sub", "sub"));
    CHECK(TitleIs("ftp:ftp://user@server/dir/sub/", "sub"));
    CHECK(TitleIs("ftp:ftp://user@server", "ftp://user@server"));
    CHECK(TitleIs("ftp:ftp://user@server/", "ftp://user@server"));
    CHECK(TitleIs("sftp:host/path/", "path"));
    CHECK(TitleIs("sftp:host", "host"));
    CHECK(TitleIs("nethood:\\\\server", "\\\\server"));
    CHECK(TitleIs("G:\\M\xC5\xAFj disk\\Nov\xC3\xBD projekt", "Nov\xC3\xBD projekt")); // "G:\Muj disk\Novy projekt"
    CHECK(TitleIs("", ""));
    CHECK(TitleIs("\\", "\\"));
    // a WTF-8 unpaired surrogate (ED A0 80) survives as bytes
    CHECK(TitleIs("D:\\Lone\xED\xA0\x80" "surrogate", "Lone\xED\xA0\x80" "surrogate"));
    {
        // truncation never leaves a torn sequence: "Novy" with y-acute (C3 BD) cut inside the sequence
        char title[5];
        SalTabTitleFromLocation("D:\\Nov\xC3\xBD", title, sizeof(title));
        CHECK(strcmp(title, "Nov") == 0);
        char title2[6];
        SalTabTitleFromLocation("D:\\Nov\xC3\xBD", title2, sizeof(title2));
        CHECK(strcmp(title2, "Nov\xC3\xBD") == 0);
    }

    // index after close (spec FR-017)
    CHECK(SalTabsIndexAfterClose(3, 0, 2) == 1); // a tab left of the active one shifts it down
    CHECK(SalTabsIndexAfterClose(3, 2, 0) == 0); // a tab right of it changes nothing
    CHECK(SalTabsIndexAfterClose(3, 1, 1) == 1); // closing the active middle tab: the right neighbour takes its index
    CHECK(SalTabsIndexAfterClose(3, 2, 2) == 1); // closing the active last tab: the left neighbour
    CHECK(SalTabsIndexAfterClose(3, 0, 0) == 0); // closing the active first tab: the (former) second
    CHECK(SalTabsIndexAfterClose(1, 0, 0) == 0); // the only tab cannot be closed - index unchanged
    CHECK(SalTabsIndexAfterClose(3, 5, 1) == 1); // out of range: unchanged

    // cycling with wrap-around (US4-2)
    CHECK(SalTabsCycle(3, 0, TRUE) == 1);
    CHECK(SalTabsCycle(3, 1, TRUE) == 2);
    CHECK(SalTabsCycle(3, 2, TRUE) == 0);
    CHECK(SalTabsCycle(3, 0, FALSE) == 2);
    CHECK(SalTabsCycle(3, 2, FALSE) == 1);
    CHECK(SalTabsCycle(1, 0, TRUE) == 0);
    CHECK(SalTabsCycle(0, 0, TRUE) == 0);

    // move: the active index follows the moved tab or shifts with the others (US5-3)
    {
        int a = 2;
        SalTabsMove(3, 2, 0, &a); // "Music" before "Work": the active (moved) tab lands at 0
        CHECK(a == 0);
        a = 0;
        SalTabsMove(3, 2, 0, &a); // the active first tab is pushed right
        CHECK(a == 1);
        a = 1;
        SalTabsMove(3, 0, 2, &a); // moving the first tab to the end pulls the active middle one left
        CHECK(a == 0);
        a = 2;
        SalTabsMove(3, 0, 1, &a); // untouched tabs keep their index
        CHECK(a == 2);
        a = 1;
        SalTabsMove(3, 1, 1, &a); // no-op
        CHECK(a == 1);
        a = 1;
        SalTabsMove(3, 7, 0, &a); // out of range: no-op
        CHECK(a == 1);
    }

    // record clamping (data-model.md section 1)
    {
        CSalTabRecord rec;
        SalTabRecordInit(&rec);
        CHECK(rec.Location[0] == 0 && rec.ViewTemplateIndex == 2 && rec.SortType == 0 &&
              !rec.ReverseSort && !rec.FilterEnabled && strcmp(rec.FilterMasks, "*.*") == 0);
        CHECK(!SalTabRecordClamp(&rec, 5)); // empty location -> dropped
        lstrcpynA(rec.Location, "D:\\Work", sizeof(rec.Location));
        rec.SortType = 9;
        rec.ViewTemplateIndex = 0;
        rec.FilterMasks[0] = 0;
        CHECK(SalTabRecordClamp(&rec, 5));
        CHECK(rec.SortType == 0 && rec.ViewTemplateIndex == 2 && strcmp(rec.FilterMasks, "*.*") == 0);
        rec.SortType = 5;
        rec.ViewTemplateIndex = 7;
        CHECK(SalTabRecordClamp(&rec, 5) && rec.SortType == 5 && rec.ViewTemplateIndex == 7);
        rec.SortType = -1;
        CHECK(SalTabRecordClamp(&rec, 5) && rec.SortType == 0);
    }
}

// feature 079: crash report file name (src/common/salbugreport.cpp), contracts/crash-report.md C2
static void TestBugReport079()
{
    SYSTEMTIME t = {0};
    t.wYear = 2026;
    t.wMonth = 9;
    t.wDay = 19;
    t.wHour = 14;
    t.wMinute = 30;
    t.wSecond = 7;
    WCHAR name[64];

    // exact layout, upper-casing of the version tag, .TXT extension
    CHECK(SalFormatBugReportName(name, 64, "018X64", t, 0) && wcscmp(name, L"TC018X64-20260919-143007.TXT") == 0);
    CHECK(SalFormatBugReportName(name, 64, "018x64", t, 0) && wcscmp(name, L"TC018X64-20260919-143007.TXT") == 0);

    // zero padding of every date/time field
    SYSTEMTIME t2 = {0};
    t2.wYear = 2030;
    t2.wMonth = 1;
    t2.wDay = 2;
    t2.wHour = 3;
    t2.wMinute = 4;
    t2.wSecond = 5;
    CHECK(SalFormatBugReportName(name, 64, "100X64", t2, 0) && wcscmp(name, L"TC100X64-20300102-030405.TXT") == 0);

    // collision suffix: omitted for 0, one digit, two digits, refused above 99 or below 0
    CHECK(SalFormatBugReportName(name, 64, "018X64", t, 7) && wcscmp(name, L"TC018X64-20260919-143007-7.TXT") == 0);
    CHECK(SalFormatBugReportName(name, 64, "018X64", t, 99) && wcscmp(name, L"TC018X64-20260919-143007-99.TXT") == 0);
    CHECK(!SalFormatBugReportName(name, 64, "018X64", t, 100) && name[0] == 0);
    CHECK(!SalFormatBugReportName(name, 64, "018X64", t, -1) && name[0] == 0);

    // only A-Z 0-9 '-' '.' ever appear in the output
    CHECK(SalFormatBugReportName(name, 64, "018X64", t, 42));
    {
        BOOL clean = TRUE;
        for (const WCHAR* p = name; *p != 0; p++)
        {
            BOOL ok = (*p >= L'A' && *p <= L'Z') || (*p >= L'0' && *p <= L'9') || *p == L'-' || *p == L'.';
            if (!ok)
                clean = FALSE;
        }
        CHECK(clean);
        CHECK(wcslen(name) < 64);
    }

    // buffer bound: exact size succeeds, one character less fails and clears the buffer
    {
        const int exact = 2 + 6 + 9 + 7 + 4 + 1; // TC + version + -YYYYMMDD + -HHMMSS + .TXT + NUL
        WCHAR tight[64]; // ("small" is a Windows macro)
        CHECK(SalFormatBugReportName(tight, exact, "018X64", t, 0) && wcslen(tight) == (size_t)(exact - 1));
        tight[0] = L'x';
        CHECK(!SalFormatBugReportName(tight, exact - 1, "018X64", t, 0) && tight[0] == 0);
        const int exactSuffix = exact + 3; // "-42"
        CHECK(SalFormatBugReportName(tight, exactSuffix, "018X64", t, 42) && wcslen(tight) == (size_t)(exactSuffix - 1));
        CHECK(!SalFormatBugReportName(tight, exactSuffix - 1, "018X64", t, 42) && tight[0] == 0);
    }

    // version tag validation: empty, backslash, space, NULL
    CHECK(!SalFormatBugReportName(name, 64, "", t, 0) && name[0] == 0);
    CHECK(!SalFormatBugReportName(name, 64, "01\\8", t, 0) && name[0] == 0);
    CHECK(!SalFormatBugReportName(name, 64, "018 X64", t, 0) && name[0] == 0);
    CHECK(!SalFormatBugReportName(name, 64, NULL, t, 0) && name[0] == 0);

    // out-of-range time field is refused rather than written as garbage
    SYSTEMTIME bad = t;
    bad.wMonth = 100;
    CHECK(!SalFormatBugReportName(name, 64, "018X64", bad, 0) && name[0] == 0);
    bad = t;
    bad.wYear = 10000;
    CHECK(!SalFormatBugReportName(name, 64, "018X64", bad, 0) && name[0] == 0);

    // degenerate buffers
    CHECK(!SalFormatBugReportName(NULL, 64, "018X64", t, 0));
    CHECK(!SalFormatBugReportName(name, 0, "018X64", t, 0));
}

// feature 080: closing for an update (src/common/salcloseapp.cpp),
// contracts/close-request.md C1 + C6, contracts/restart-registration.md R3

// the tokenizer rule of GetCmdLine (src/salamdr1.cpp), mirrored here so that the
// composed restart command line can be read back the way the program reads it:
// an argument in double quotes ends at the next quote, "" inside it is one quote
static std::vector<std::wstring> TokenizeLikeGetCmdLine080(const WCHAR* s)
{
    std::vector<std::wstring> args;
    while (*s != 0)
    {
        WCHAR term = L' ';
        if (*s == L'"')
        {
            if (*++s == 0)
                break;
            term = L'"';
        }
        std::wstring arg;
        while (1)
        {
            if (*s == term || *s == 0)
            {
                if (*s == 0 || term != L'"' || *++s != L'"')
                {
                    if (*s != 0)
                        s++;
                    while (*s == L' ')
                        s++;
                    break;
                }
            }
            arg += *s++;
        }
        args.push_back(arg);
    }
    return args;
}

static CSalCloseAppSnapshot IdleSnapshot080()
{
    CSalCloseAppSnapshot s;
    memset(&s, 0, sizeof(s));
    s.StartupFinished = TRUE;
    return s;
}

static CSalCloseAppWindow Window080(BOOL visible, DWORD style, DWORD exStyle, CSalCloseAppWindowKind kind)
{
    CSalCloseAppWindow w;
    w.Visible = visible;
    w.Style = style;
    w.ExStyle = exStyle;
    w.Kind = kind;
    w.ClosesUnattended = FALSE;
    return w;
}

static void TestCloseApp080()
{
    const LPARAM closeApp = 0x00000001;   // ENDSESSION_CLOSEAPP
    const LPARAM critical = 0x40000000;   // ENDSESSION_CRITICAL
    const LPARAM logoff = (LPARAM)0x80000000; // ENDSESSION_LOGOFF

    // --- C1: what counts as an installer's close request
    CHECK(SalIsCloseAppRequest(closeApp, FALSE));
    CHECK(SalIsCloseAppRequest(closeApp | logoff, FALSE)); // the log-off bit does not matter
    CHECK(!SalIsCloseAppRequest(0, FALSE));                // ordinary shutdown
    CHECK(!SalIsCloseAppRequest(logoff, FALSE));           // ordinary sign-out
    CHECK(!SalIsCloseAppRequest(critical, FALSE));         // critical shutdown
    CHECK(!SalIsCloseAppRequest(closeApp | critical, FALSE)); // forced close: the critical path handles it
    CHECK(!SalIsCloseAppRequest(closeApp, TRUE));          // Windows is closing programs for servicing
    CHECK(!SalIsCloseAppRequest(closeApp | critical, TRUE));
    CHECK(!SalIsCloseAppRequest(0, TRUE));

    // --- C6: an idle instance agrees
    CSalCloseAppSnapshot idle = IdleSnapshot080();
    CHECK(SalCloseAppDecide(idle) == scadAgree);

    // every reason alone
    {
        CSalCloseAppSnapshot s = IdleSnapshot080();
        s.StartupFinished = FALSE;
        CHECK(SalCloseAppDecide(s) == scadStartupOrClosing);
        s = IdleSnapshot080();
        s.CloseInProgress = TRUE;
        CHECK(SalCloseAppDecide(s) == scadStartupOrClosing);
        s = IdleSnapshot080();
        s.Busy = TRUE;
        CHECK(SalCloseAppDecide(s) == scadBusy);
        s = IdleSnapshot080();
        s.InsidePlugin = TRUE;
        CHECK(SalCloseAppDecide(s) == scadInsidePlugin);
        s = IdleSnapshot080();
        s.FileOperations = 1;
        CHECK(SalCloseAppDecide(s) == scadFileOperations);
        s = IdleSnapshot080();
        s.FindSearching = 2;
        CHECK(SalCloseAppDecide(s) == scadFindSearching);
        s = IdleSnapshot080();
        s.ArchiveEditsPending = TRUE;
        CHECK(SalCloseAppDecide(s) == scadArchiveEdits);
        s = IdleSnapshot080();
        s.PluginFSOpen = TRUE;
        CHECK(SalCloseAppDecide(s) == scadPluginFS);
    }

    // the order: the most fundamental obstacle is the one that is named
    {
        CSalCloseAppWindow plugin = Window080(TRUE, WS_OVERLAPPEDWINDOW, 0, scawOther);
        CSalCloseAppSnapshot s = IdleSnapshot080();
        s.Windows = &plugin;
        s.WindowCount = 1;
        CHECK(SalCloseAppDecide(s) == scadForeignWindow);
        s.PluginFSOpen = TRUE;
        CHECK(SalCloseAppDecide(s) == scadPluginFS);
        s.ArchiveEditsPending = TRUE;
        CHECK(SalCloseAppDecide(s) == scadArchiveEdits);
        s.FindSearching = 1;
        CHECK(SalCloseAppDecide(s) == scadFindSearching);
        s.FileOperations = 3;
        CHECK(SalCloseAppDecide(s) == scadFileOperations);
        s.InsidePlugin = TRUE;
        CHECK(SalCloseAppDecide(s) == scadInsidePlugin);
        s.Busy = TRUE;
        CHECK(SalCloseAppDecide(s) == scadBusy);
        s.StartupFinished = FALSE;
        CHECK(SalCloseAppDecide(s) == scadStartupOrClosing);
    }

    // zero and negative counts are "none"; a NULL window list with a count is ignored, not read
    {
        CSalCloseAppSnapshot s = IdleSnapshot080();
        s.FileOperations = 0;
        s.FindSearching = -1;
        s.Windows = NULL;
        s.WindowCount = 5;
        CHECK(SalCloseAppDecide(s) == scadAgree);
    }

    // --- D8: which windows count
    // what an idle instance really has (taken from a running build): the main window visible,
    // hidden helper windows, IME windows
    {
        CSalCloseAppWindow w[5];
        w[0] = Window080(TRUE, WS_OVERLAPPEDWINDOW | WS_VISIBLE, 0, scawMain);
        w[1] = Window080(FALSE, WS_OVERLAPPEDWINDOW, 0, scawOther); // HiddenSocketsWindow
        w[2] = Window080(FALSE, WS_POPUP, WS_EX_TOOLWINDOW, scawOther); // WorkerW / ComboLBox
        w[3] = Window080(FALSE, WS_POPUP | WS_DISABLED, 0, scawOther);  // IME
        w[4] = Window080(FALSE, WS_POPUP | WS_DISABLED, 0, scawOther);  // MSCTFIME UI
        CSalCloseAppSnapshot s = IdleSnapshot080();
        s.Windows = w;
        s.WindowCount = 5;
        CHECK(SalCloseAppDecide(s) == scadAgree);
    }
    // windows the exit sequence closes by itself never count, visible or not
    CHECK(!SalCloseAppWindowIsForeign(Window080(TRUE, WS_OVERLAPPEDWINDOW, 0, scawMain)));
    CHECK(!SalCloseAppWindowIsForeign(Window080(TRUE, WS_OVERLAPPEDWINDOW, 0, scawInternalViewer)));
    CHECK(!SalCloseAppWindowIsForeign(Window080(TRUE, WS_OVERLAPPEDWINDOW, 0, scawFind)));
    CHECK(!SalCloseAppWindowIsForeign(Window080(TRUE, WS_OVERLAPPEDWINDOW, 0, scawHelp)));
    // a plug-in viewer, a plug-in dialog, a minimized plug-in window
    CHECK(SalCloseAppWindowIsForeign(Window080(TRUE, WS_OVERLAPPEDWINDOW, 0, scawOther)));
    CHECK(SalCloseAppWindowIsForeign(Window080(TRUE, WS_POPUP | WS_CAPTION | WS_SYSMENU, WS_EX_DLGMODALFRAME, scawOther)));
    CHECK(SalCloseAppWindowIsForeign(Window080(TRUE, WS_OVERLAPPEDWINDOW | WS_MINIMIZE, 0, scawOther)));
    // a captionless full-screen viewer counts - it is a window a user works in
    CHECK(SalCloseAppWindowIsForeign(Window080(TRUE, WS_POPUP, 0, scawOther)));
    // a tool window WITH a caption (a floating palette) counts too
    CHECK(SalCloseAppWindowIsForeign(Window080(TRUE, WS_POPUP | WS_CAPTION, WS_EX_TOOLWINDOW, scawOther)));
    // tooltips, IME and no-activate helpers: captionless + tool/no-activate -> never
    CHECK(!SalCloseAppWindowIsForeign(Window080(TRUE, WS_POPUP, WS_EX_TOOLWINDOW | WS_EX_TOPMOST, scawOther)));
    CHECK(!SalCloseAppWindowIsForeign(Window080(TRUE, WS_POPUP, WS_EX_NOACTIVATE, scawOther)));
    // WS_BORDER or WS_DLGFRAME alone is not a caption
    CHECK(!SalCloseAppWindowIsForeign(Window080(TRUE, WS_POPUP | WS_BORDER, WS_EX_TOOLWINDOW, scawOther)));
    // hidden windows never count
    CHECK(!SalCloseAppWindowIsForeign(Window080(FALSE, WS_OVERLAPPEDWINDOW, 0, scawOther)));
    // one foreign window among many decides
    {
        CSalCloseAppWindow w[3];
        w[0] = Window080(TRUE, WS_OVERLAPPEDWINDOW, 0, scawMain);
        w[1] = Window080(TRUE, WS_OVERLAPPEDWINDOW, 0, scawInternalViewer);
        w[2] = Window080(TRUE, WS_OVERLAPPEDWINDOW, 0, scawOther);
        CSalCloseAppSnapshot s = IdleSnapshot080();
        s.Windows = w;
        s.WindowCount = 2;
        CHECK(SalCloseAppDecide(s) == scadAgree);
        s.WindowCount = 3;
        CHECK(SalCloseAppDecide(s) == scadForeignWindow);
    }

    // --- feature 088: a window its plug-in declared (SetWindowClosesUnattended) is not foreign
    {
        CSalCloseAppWindow viewer = Window080(TRUE, WS_OVERLAPPEDWINDOW, 0, scawOther);
        CHECK(SalCloseAppWindowIsForeign(viewer));
        viewer.ClosesUnattended = TRUE;
        CHECK(!SalCloseAppWindowIsForeign(viewer));
        // a captionless full-screen viewer counted as foreign; declared, it passes too
        CSalCloseAppWindow full = Window080(TRUE, WS_POPUP, 0, scawOther);
        CHECK(SalCloseAppWindowIsForeign(full));
        full.ClosesUnattended = TRUE;
        CHECK(!SalCloseAppWindowIsForeign(full));
        // the declaration changes nothing for windows that never counted
        CSalCloseAppWindow hidden = Window080(FALSE, WS_OVERLAPPEDWINDOW, 0, scawOther);
        hidden.ClosesUnattended = TRUE;
        CHECK(!SalCloseAppWindowIsForeign(hidden));

        CSalCloseAppWindow w[4];
        w[0] = Window080(TRUE, WS_OVERLAPPEDWINDOW, 0, scawMain);
        w[1] = viewer;                                                  // declared viewer
        w[2] = viewer;                                                  // a second one
        w[3] = Window080(TRUE, WS_POPUP | WS_CAPTION, 0, scawOther);    // its Find dialog: not declared
        CSalCloseAppSnapshot s = IdleSnapshot080();
        s.Windows = w;
        s.WindowCount = 3;
        CHECK(SalCloseAppDecide(s) == scadAgree);
        s.WindowCount = 4;
        CHECK(SalCloseAppDecide(s) == scadForeignWindow); // a dialog owned by a declared window is not covered
        // declared windows do not outweigh the other reasons
        s.WindowCount = 3;
        s.PluginFSOpen = TRUE;
        CHECK(SalCloseAppDecide(s) == scadPluginFS);
        s.PluginFSOpen = FALSE;
        s.FileOperations = 1;
        CHECK(SalCloseAppDecide(s) == scadFileOperations);
    }

    // --- feature 088 (contract B3): which names a plug-in's viewer buffer can hold
    CHECK(SalViewerNameFitsPlugin(107, 100000));
    CHECK(SalViewerNameFitsPlugin(108, SAL_MAX_PATH_UTF8 - 1));
    CHECK(SalViewerNameFitsPlugin(106, MAX_PATH - 1));  // 259 bytes + terminator = the promised 260
    CHECK(!SalViewerNameFitsPlugin(106, MAX_PATH));     // 260 bytes do not fit
    CHECK(!SalViewerNameFitsPlugin(104, 5000));
    CHECK(SalViewerNameFitsPlugin(104, 0));
    CHECK(!SalViewerNameFitsPlugin(0, MAX_PATH));       // unknown version: treated as old
    CHECK(!SalViewerNameFitsPlugin(-1, MAX_PATH));

    // --- feature 097: which archive file names a handler may be given
    CHECK(SalArchiveNameFitsHandler(107, 0));
    CHECK(SalArchiveNameFitsHandler(107, MAX_PATH - 1));
    CHECK(SalArchiveNameFitsHandler(107, MAX_PATH));                 // 260 bytes: a current plug-in takes it
    CHECK(SalArchiveNameFitsHandler(107, 777));
    CHECK(SalArchiveNameFitsHandler(108, SAL_MAX_PATH_UTF8 - 1));    // the longest name the program holds
    CHECK(!SalArchiveNameFitsHandler(107, SAL_MAX_PATH_UTF8));       // would not fit with its terminator
    CHECK(!SalArchiveNameFitsHandler(107, 1000000));
    CHECK(SalArchiveNameFitsHandler(106, MAX_PATH - 1));             // an older plug-in: 259 bytes as before
    CHECK(!SalArchiveNameFitsHandler(106, MAX_PATH));                // ... and not one byte more
    CHECK(!SalArchiveNameFitsHandler(104, 777));
    CHECK(SalArchiveNameFitsHandler(0, MAX_PATH - 1));               // unknown version: treated as old
    CHECK(!SalArchiveNameFitsHandler(0, MAX_PATH));
    CHECK(!SalArchiveNameFitsHandler(-1, MAX_PATH));
    CHECK(SalArchiveNameFitsHandler(SAL_ARCHIVE_HANDLER_EXTERNAL, MAX_PATH - 1)); // external archiver
    CHECK(!SalArchiveNameFitsHandler(SAL_ARCHIVE_HANDLER_EXTERNAL, MAX_PATH));
    CHECK(!SalArchiveNameFitsHandler(SAL_ARCHIVE_HANDLER_EXTERNAL, SAL_MAX_PATH_UTF8 - 1));
    CHECK(SAL_PLUGINVER_LONG_ARCHIVE_NAMES == 107);
    CHECK(SAL_MAX_PATH_UTF8 == 3 * 32767 + 1);

    // every decision has a name, and only "agree" does not start with "decline"
    for (int d = scadAgree; d <= scadForeignWindow; d++)
    {
        const char* n = SalCloseAppDecisionName((CSalCloseAppDecision)d);
        CHECK(n != NULL && n[0] != 0);
        CHECK((d == scadAgree) == (strncmp(n, "decline", 7) != 0));
    }
    CHECK(strncmp(SalCloseAppDecisionName((CSalCloseAppDecision)999), "decline", 7) == 0);

    // --- R3: the restart command line carries identity, never location
    WCHAR cmd[1024];
    CHECK(SalRestartCommandLine(cmd, 1024, FALSE, NULL, FALSE, 0) && cmd[0] == 0);
    CHECK(SalRestartCommandLine(cmd, 1024, FALSE, L"ignored", FALSE, 2) && cmd[0] == 0);
    CHECK(SalRestartCommandLine(cmd, 1024, TRUE, L"Work", FALSE, 0) && wcscmp(cmd, L"-t \"Work\"") == 0);
    CHECK(SalRestartCommandLine(cmd, 1024, FALSE, NULL, TRUE, 2) && wcscmp(cmd, L"-i 2") == 0);
    CHECK(SalRestartCommandLine(cmd, 1024, TRUE, L"Work", TRUE, 2) && wcscmp(cmd, L"-t \"Work\" -i 2") == 0);
    CHECK(SalRestartCommandLine(cmd, 1024, TRUE, L"My \"big\" disk", FALSE, 0) &&
          wcscmp(cmd, L"-t \"My \"\"big\"\" disk\"") == 0);
    // -t with an EMPTY prefix is an identity too (it forces "no prefix" over the configured one);
    // an icon index outside 0..3 is no icon index
    CHECK(SalRestartCommandLine(cmd, 1024, TRUE, L"", TRUE, 0) && wcscmp(cmd, L"-t \"\" -i 0") == 0);
    CHECK(SalRestartCommandLine(cmd, 1024, TRUE, NULL, TRUE, 3) && wcscmp(cmd, L"-t \"\" -i 3") == 0);
    CHECK(SalRestartCommandLine(cmd, 1024, TRUE, L"", FALSE, 0) && wcscmp(cmd, L"-t \"\"") == 0);
    {
        std::vector<std::wstring> a = TokenizeLikeGetCmdLine080(L"-t \"\" -i 3");
        CHECK(a.size() == 4 && a[0] == L"-t" && a[1].empty() && a[2] == L"-i" && a[3] == L"3");
        a = TokenizeLikeGetCmdLine080(L"-t \"\"");
        CHECK(a.size() == 2 && a[0] == L"-t" && a[1].empty());
    }
    CHECK(SalRestartCommandLine(cmd, 1024, TRUE, L"A", TRUE, 4) && wcscmp(cmd, L"-t \"A\"") == 0);
    CHECK(SalRestartCommandLine(cmd, 1024, TRUE, L"A", TRUE, -1) && wcscmp(cmd, L"-t \"A\"") == 0);

    // read back the way the program reads its command line
    {
        const WCHAR* prefixes[] = {L"Work", L"two words", L"My \"big\" disk", L"\"", L"\"\"quoted\"\"",
                                   L"trailing quote\"", L"  spaces  ", L"\x010C\x00E1st \xD83D\xDCC1"};
        for (int i = 0; i < _countof(prefixes); i++)
        {
            CHECK(SalRestartCommandLine(cmd, 1024, TRUE, prefixes[i], TRUE, 1));
            std::vector<std::wstring> a = TokenizeLikeGetCmdLine080(cmd);
            CHECK(a.size() == 4 && a[0] == L"-t" && a[1] == prefixes[i] && a[2] == L"-i" && a[3] == L"1");
        }
    }

    // a part that does not fit is left out whole - never cut in the middle of a quoted argument
    {
        WCHAR tight[32];
        // -t "Work" = 9 characters + NUL
        CHECK(SalRestartCommandLine(tight, 10, TRUE, L"Work", FALSE, 0) && wcscmp(tight, L"-t \"Work\"") == 0);
        CHECK(SalRestartCommandLine(tight, 9, TRUE, L"Work", FALSE, 0) && tight[0] == 0);
        // the prefix does not fit, the icon index still does
        CHECK(SalRestartCommandLine(tight, 9, TRUE, L"Work", TRUE, 2) && wcscmp(tight, L"-i 2") == 0);
        // the prefix fits, the icon index (" -i 2" = 5 more) does not
        CHECK(SalRestartCommandLine(tight, 14, TRUE, L"Work", TRUE, 2) && wcscmp(tight, L"-t \"Work\"") == 0);
        CHECK(SalRestartCommandLine(tight, 15, TRUE, L"Work", TRUE, 2) && wcscmp(tight, L"-t \"Work\" -i 2") == 0);
        // a prefix longer than the whole limit: dropped, the result still parses
        std::wstring longPrefix(2000, L'x');
        CHECK(SalRestartCommandLine(cmd, 1024, TRUE, longPrefix.c_str(), TRUE, 1) && wcscmp(cmd, L"-i 1") == 0);
        // degenerate buffers
        CHECK(SalRestartCommandLine(tight, 1, TRUE, L"Work", TRUE, 2) && tight[0] == 0);
        CHECK(!SalRestartCommandLine(tight, 0, TRUE, L"Work", TRUE, 2));
        CHECK(!SalRestartCommandLine(NULL, 1024, TRUE, L"Work", TRUE, 2));
    }
}

//*****************************************************************************
//
// Feature 084: parser of the 7-Zip technical listing (src/common/sal7zlist.*),
// contract specs/084-archiver-cleanup/contracts/7z-slt-listing.md P4.
//

struct C7zItemCopy
{
    std::string Path;
    BOOL IsDir;
    unsigned __int64 Size;
    BOOL HasPackedSize;
    unsigned __int64 PackedSize;
    BOOL HasDate;
    SYSTEMTIME Modified;
    DWORD Attributes;
    BOOL Encrypted;
};

static BOOL Collect7zItem(const CSal7zListItem* item, void* ctx)
{
    C7zItemCopy c;
    c.Path.assign(item->Path, item->PathLen);
    c.IsDir = item->IsDir;
    c.Size = item->Size;
    c.HasPackedSize = item->HasPackedSize;
    c.PackedSize = item->PackedSize;
    c.HasDate = item->HasDate;
    c.Modified = item->Modified;
    c.Attributes = item->Attributes;
    c.Encrypted = item->Encrypted;
    ((std::vector<C7zItemCopy>*)ctx)->push_back(c);
    return TRUE;
}

static BOOL StopAfterFirst7zItem(const CSal7zListItem*, void* ctx)
{
    (*(int*)ctx)++;
    return FALSE;
}

static int Parse7z(const std::string& text, std::vector<C7zItemCopy>& items, int* errorLine = NULL)
{
    items.clear();
    return SalParse7zTechList(text.data(), text.size(), Collect7zItem, &items, errorLine);
}

// probe/fixtures/slt/unicode_7z.txt as captured from 7-Zip 22.01 x64 (CRLF) with
// -ba (the bare listing: item blocks only); names: Czech, Chinese, emoji (UTF-8 bytes)
#define U8_7Z_CZECH "P\xC5\x99\xC3\xADli\xC5\xA1 \xC5\xBElu\xC5\xA5ou\xC4\x8Dk\xC3\xBD k\xC5\xAF\xC5\x88.txt"
#define U8_7Z_CHINESE "\xE4\xB8\xAD\xE6\x96\x87.txt"
#define U8_7Z_EMOJI "\xF0\x9F\x98\x80.txt"
static const char* const Capture7z084 =
    "Path = sub dir\r\nSize = 0\r\nPacked Size = 0\r\nModified = 2026-10-01 09:27:39.3945619\r\n"
    "Attributes = D\r\nCRC = \r\nEncrypted = -\r\nMethod = \r\nBlock = \r\n\r\n"
    "Path = empty.txt\r\nSize = 0\r\nPacked Size = 0\r\nModified = 2026-10-01 09:27:39.3970710\r\n"
    "Attributes = A\r\nCRC = \r\nEncrypted = -\r\nMethod = \r\nBlock = \r\n\r\n"
    "Path = " U8_7Z_CZECH "\r\nSize = 7\r\nPacked Size = 43\r\nModified = 2026-10-01 09:27:39.3960661\r\n"
    "Attributes = A\r\nCRC = 29C83326\r\nEncrypted = -\r\nMethod = LZMA2:12\r\nBlock = 0\r\n\r\n"
    "Path = sub dir\\inner file.txt\r\nSize = 350\r\nPacked Size = \r\nModified = 2026-10-01 09:27:39.3970710\r\n"
    "Attributes = A\r\nCRC = 6AFF6CD9\r\nEncrypted = -\r\nMethod = LZMA2:12\r\nBlock = 0\r\n\r\n"
    "Path = " U8_7Z_CHINESE "\r\nSize = 9\r\nPacked Size = \r\nModified = 2026-10-01 09:27:39.3960661\r\n"
    "Attributes = A\r\nCRC = 1DF79EA9\r\nEncrypted = -\r\nMethod = LZMA2:12\r\nBlock = 0\r\n\r\n"
    "Path = " U8_7Z_EMOJI "\r\nSize = 7\r\nPacked Size = \r\nModified = 2026-10-01 09:27:39.3970710\r\n"
    "Attributes = A\r\nCRC = 62B10923\r\nEncrypted = -\r\nMethod = LZMA2:12\r\nBlock = 0\r\n\r\n";

static void Check7zCapture084(const std::vector<C7zItemCopy>& it)
{
    CHECK(it.size() == 6);
    if (it.size() != 6)
        return;
    CHECK(it[0].Path == "sub dir" && it[0].IsDir && it[0].Size == 0);
    CHECK(it[0].HasDate && it[0].Modified.wYear == 2026 && it[0].Modified.wMonth == 10 &&
          it[0].Modified.wDay == 1 && it[0].Modified.wHour == 9 && it[0].Modified.wMinute == 27 &&
          it[0].Modified.wSecond == 39 && it[0].Modified.wMilliseconds == 0);
    CHECK(it[1].Path == "empty.txt" && !it[1].IsDir && it[1].Size == 0 && it[1].HasPackedSize &&
          it[1].PackedSize == 0 && it[1].Attributes == FILE_ATTRIBUTE_ARCHIVE && !it[1].Encrypted);
    CHECK(it[2].Path == U8_7Z_CZECH && it[2].Size == 7 && it[2].HasPackedSize && it[2].PackedSize == 43);
    // a member of a solid block: "Packed Size =" is empty, which is not an error
    CHECK(it[3].Path == "sub dir\\inner file.txt" && it[3].Size == 350 && !it[3].HasPackedSize);
    CHECK(it[4].Path == U8_7Z_CHINESE && it[4].Size == 9 && !it[4].IsDir);
    CHECK(it[5].Path == U8_7Z_EMOJI && it[5].Size == 7);
}

static void TestSevenZipList084()
{
    std::vector<C7zItemCopy> it;
    int errorLine = -1;

    // --- P4: the real bare capture (CRLF)
    CHECK(Parse7z(Capture7z084, it, &errorLine) == SAL7Z_OK && errorLine == 0);
    Check7zCapture084(it);

    // --- the same output with LF line ends
    std::string lf = Capture7z084;
    for (size_t p; (p = lf.find('\r')) != std::string::npos;)
        lf.erase(p, 1);
    CHECK(Parse7z(lf, it) == SAL7Z_OK);
    Check7zCapture084(it);

    // --- no trailing blank line after the last item, and two blocks with no
    // blank line between them ("Path =" starts the next one)
    CHECK(Parse7z("Path = a.txt\nSize = 1\nPath = b.txt\nSize = 2", it) == SAL7Z_OK &&
          it.size() == 2 && it[0].Path == "a.txt" && it[0].Size == 1 && it[1].Path == "b.txt" &&
          it[1].Size == 2);

    // --- an empty archive: the bare listing is empty
    CHECK(Parse7z("", it) == SAL7Z_OK && it.empty());
    CHECK(Parse7z("\r\n", it) == SAL7Z_OK && it.empty());

    // --- review finding 2: output that is not the bare listing is refused - its
    // archive-properties part can carry a multi-line archive comment that imitates
    // the separator and the item blocks (the injection the review demonstrated
    // with a crafted ARJ; probe/fixtures review capture)
    std::string injected = "--\r\nPath = cmt.arj\r\nType = Arj\r\nComment = \r\n{\r\nWelcome BBS\r\n"
                           "----------\r\n\r\nPath = fake_entry.txt\r\nSize = 999\r\n\r\n}\r\n\r\n"
                           "----------\r\nPath = real.txt\r\nSize = 5\r\n\r\n";
    CHECK(Parse7z(injected, it, &errorLine) == SAL7Z_NOT_BARE && it.empty() && errorLine == 7);
    CHECK(Parse7z("-----------\nPath = a\n", it) == SAL7Z_OK && it.size() == 1); // 11 dashes: an ignored line
    // an item comment is flattened by 7-Zip onto one line: no phantom item
    CHECK(Parse7z("Path = real.txt\r\nSize = 5\r\nComment = c1\r_\r_Path = phantom.txt\r_Size = 123\r\n\r\n", it) ==
              SAL7Z_OK &&
          it.size() == 1 && it[0].Path == "real.txt" && it[0].Size == 5);

    // --- P3 rejections: nothing is delivered as a partial listing
    CHECK(Parse7z("Size = 5\nAttributes = A\n\n", it, &errorLine) == SAL7Z_NO_PATH && errorLine == 1);
    CHECK(Parse7z("Path = ok.txt\n\nPath = a\\..\\b.txt\n", it, &errorLine) == SAL7Z_UNSAFE_PATH &&
          errorLine == 3);
    CHECK(Parse7z("Path = \\abs.txt\n", it) == SAL7Z_UNSAFE_PATH);
    CHECK(Parse7z("Path = /abs.txt\n", it) == SAL7Z_UNSAFE_PATH);
    CHECK(Parse7z("Path = C:\\abs.txt\n", it) == SAL7Z_UNSAFE_PATH);
    CHECK(Parse7z("Path = ../up.txt\n", it) == SAL7Z_UNSAFE_PATH);
    CHECK(Parse7z("Path = \nSize = 1\n", it) == SAL7Z_UNSAFE_PATH);
    CHECK(Parse7z("Path = a.txt\nSize = 12a\n", it) == SAL7Z_BAD_SIZE);
    CHECK(Parse7z("Path = a.txt\nSize = 99999999999999999999999\n", it) == SAL7Z_BAD_SIZE);

    // --- a malformed date is not an error: the item has no date
    CHECK(Parse7z("Path = a.txt\nModified = 2026-13-01 00:00:00\n", it) == SAL7Z_OK &&
          it.size() == 1 && !it[0].HasDate);
    CHECK(Parse7z("Path = a.txt\nModified = garbage\n", it) == SAL7Z_OK &&
          it.size() == 1 && !it[0].HasDate);
    CHECK(Parse7z("Path = a.txt\nModified = 2026-02-03 04:05:06\n", it) == SAL7Z_OK &&
          it.size() == 1 && it[0].HasDate && it[0].Modified.wSecond == 6);

    // --- attributes: letters before the first space; unix part ignored
    CHECK(Parse7z("Path = a\nAttributes = A -rw-r--r--\n", it) == SAL7Z_OK &&
          it.size() == 1 && it[0].Attributes == FILE_ATTRIBUTE_ARCHIVE && !it[0].IsDir);
    CHECK(Parse7z("Path = a\nAttributes = RHSA\n", it) == SAL7Z_OK && it.size() == 1 &&
          it[0].Attributes == (FILE_ATTRIBUTE_READONLY | FILE_ATTRIBUTE_HIDDEN | FILE_ATTRIBUTE_SYSTEM |
                               FILE_ATTRIBUTE_ARCHIVE));
    CHECK(Parse7z("Path = d\nFolder = +\n", it) == SAL7Z_OK && it.size() == 1 && it[0].IsDir);
    CHECK(Parse7z("Path = e.txt\nEncrypted = +\n", it) == SAL7Z_OK && it.size() == 1 &&
          it[0].Encrypted);

    // --- a key whose value contains " = " keeps it in the value
    CHECK(Parse7z("Path = a = b.txt\n", it) == SAL7Z_OK && it.size() == 1 &&
          it[0].Path == "a = b.txt");

    // --- the callback can stop the walk
    int seen = 0;
    std::string two = "Path = a\n\nPath = b\n";
    CHECK(SalParse7zTechList(two.data(), two.size(), StopAfterFirst7zItem, &seen, NULL) == SAL7Z_STOPPED &&
          seen == 1);

    // --- SalIs7zPathSafe
    CHECK(SalIs7zPathSafe("a..b", 4));
    CHECK(SalIs7zPathSafe("..a\\b..", 7));
    CHECK(SalIs7zPathSafe("dir\\file.txt", 12));
    CHECK(!SalIs7zPathSafe("dir/../x", 8));
    CHECK(!SalIs7zPathSafe("..", 2));
    CHECK(!SalIs7zPathSafe("x:", 2));
    CHECK(!SalIs7zPathSafe("", 0));
    CHECK(!SalIs7zPathSafe(NULL, 3));
}

//*****************************************************************************
//
// Feature 084: archiver configuration migration to version 106 - the pure
// decisions (src/common/salarcmig.*), contract
// specs/084-archiver-cleanup/contracts/config-migration-106.md M1-M3.
//

static void TestArchiverMigration084()
{
    // --- M1: every removed variable, any letter case, in any field
    const char* removed[] = {"$(Jar32bitExecutable)", "$(Jar16bitExecutable)", "$(Rar16bitExecutable)",
                             "$(Arj32bitExecutable)", "$(Arj16bitExecutable)", "$(Ace32bitExecutable)",
                             "$(Ace16bitExecutable)", "$(Lha16bitExecutable)", "$(UC216bitExecutable)",
                             "$(Zip32bitExecutable)", "$(Zip16bitExecutable)", "$(Unzip16bitExecutable)"};
    for (int i = 0; i < _countof(removed); i++)
        CHECK(SalArcMigUsesRemovedVariable(removed[i]));
    CHECK(SalArcMigUsesRemovedVariable("$(ARJ32BITEXECUTABLE)"));
    CHECK(SalArcMigUsesRemovedVariable("x \"$(ArchiveFullName)\" & $(arj16bitexecutable) e"));
    CHECK(!SalArcMigUsesRemovedVariable("$(Rar32bitExecutable)"));
    CHECK(!SalArcMigUsesRemovedVariable("$(SevenZipExecutable)"));
    CHECK(!SalArcMigUsesRemovedVariable("C:\\Tools\\arj32.exe"));                        // own path: kept
    CHECK(!SalArcMigUsesRemovedVariable("a $(ArchiveDOSFullName) !$(ListDOSFullName)")); // DOS variables still expand
    CHECK(!SalArcMigUsesRemovedVariable("$(Arj32bitExecutableX)"));
    CHECK(!SalArcMigUsesRemovedVariable("$(Arj32bitExecutable"));
    CHECK(!SalArcMigUsesRemovedVariable(""));
    CHECK(!SalArcMigUsesRemovedVariable(NULL));

    // --- M1: the floppy-volume presets, exact strings only
    CHECK(SalArcMigIsFloppyArgs("a -scol -v1440 \"$(ArchiveFullName)\" @\"$(ListFullName)\""));
    CHECK(SalArcMigIsFloppyArgs("m -scol -v1440 \"$(ArchiveFullName)\" @\"$(ListFullName)\""));
    CHECK(SalArcMigIsFloppyArgs("a -v1440 \"$(ArchiveFullName)\" @\"$(ListFullName)\""));
    CHECK(!SalArcMigIsFloppyArgs("a -scol -v1440  \"$(ArchiveFullName)\" @\"$(ListFullName)\"")); // one more space
    CHECK(!SalArcMigIsFloppyArgs("a -v700m \"$(ArchiveFullName)\" @\"$(ListFullName)\""));        // user's own volumes
    CHECK(!SalArcMigIsFloppyArgs(NULL));

    // --- M1: packers
    const char* rar = "$(Rar32bitExecutable)";
    CHECK(SalArcMigPacker(FALSE, NULL, NULL, NULL, NULL) == sameKeep); // plug-in
    CHECK(SalArcMigPacker(TRUE, "$(Arj32bitExecutable)", "a -pa \"$(ArchiveFullName)\" !\"$(ListFullName)\"",
                          "$(Arj32bitExecutable)", "m -pa \"$(ArchiveFullName)\" !\"$(ListFullName)\"") == sameDelete);
    // an EDITED default of a removed archiver goes too (clarification Q4)
    CHECK(SalArcMigPacker(TRUE, "$(Arj32bitExecutable)", "a -m4 \"$(ArchiveFullName)\" !\"$(ListFullName)\"",
                          "$(Arj32bitExecutable)", "m -m4 \"$(ArchiveFullName)\" !\"$(ListFullName)\"") == sameDelete);
    // the move command alone referring to a removed archiver is enough
    CHECK(SalArcMigPacker(TRUE, "C:\\Tools\\my.exe", "a", "$(Ace32bitExecutable)", "m") == sameDelete);
    CHECK(SalArcMigPacker(TRUE, rar, "a -scol -v1440 \"$(ArchiveFullName)\" @\"$(ListFullName)\"",
                          rar, "m -scol -v1440 \"$(ArchiveFullName)\" @\"$(ListFullName)\"") == sameDelete);
    CHECK(SalArcMigPacker(TRUE, rar, "a -scol \"$(ArchiveFullName)\" @\"$(ListFullName)\"",
                          rar, "m -scol \"$(ArchiveFullName)\" @\"$(ListFullName)\"") == sameRarDefault);
    CHECK(SalArcMigPacker(TRUE, "$(rar32bitexecutable)", "a \"$(ArchiveFullName)\" @\"$(ListFullName)\"",
                          "$(RAR32BITEXECUTABLE)", "m \"$(ArchiveFullName)\" @\"$(ListFullName)\"") == sameRarDefault);
    // the user's own RAR arguments: kept byte for byte
    CHECK(SalArcMigPacker(TRUE, rar, "a -m5 \"$(ArchiveFullName)\" @\"$(ListFullName)\"",
                          rar, "m -m5 \"$(ArchiveFullName)\" @\"$(ListFullName)\"") == sameKeep);
    // own path with the DOS variables: kept
    CHECK(SalArcMigPacker(TRUE, "C:\\Tools\\myarc.exe", "a $(ArchiveDOSFullName) @$(ListDOSFullName)",
                          "C:\\Tools\\myarc.exe", "m $(ArchiveDOSFullName) @$(ListDOSFullName)") == sameKeep);

    // --- M1: unpackers
    CHECK(SalArcMigUnpacker(FALSE, NULL, NULL) == sameKeep);
    CHECK(SalArcMigUnpacker(TRUE, "$(Lha16bitExecutable)", "x -a -l1 -c $(ArchiveDOSFullName) @$(ListDOSFullName)") == sameDelete);
    CHECK(SalArcMigUnpacker(TRUE, rar, "x -scol \"$(ArchiveFullName)\" @\"$(ListFullName)\"") == sameDelete);
    CHECK(SalArcMigUnpacker(TRUE, rar, "x -o+ \"$(ArchiveFullName)\" @\"$(ListFullName)\"") == sameKeep);
    CHECK(SalArcMigUnpacker(TRUE, "$(SevenZipExecutable)", "x \"$(ArchiveFullName)\"") == sameKeep);
    CHECK(SalArcMigUnpacker(TRUE, "C:\\x\\unace.exe", "x \"$(ArchiveFullName)\"") == sameKeep);

    // --- M2: associations
    int u, p;
    BOOL use;
    CHECK(SalArcMigAssociation(-1, -1, TRUE, &u, &p, &use) && u == -1 && p == -1 && use); // plug-in both
    CHECK(SalArcMigAssociation(1, 1, TRUE, &u, &p, &use) && u == 1 && p == 1 && use);     // rar;r##
    CHECK(!SalArcMigAssociation(0, 0, TRUE, &u, &p, &use));                               // j (JAR32)
    for (int old = 2; old <= 11; old++)
        CHECK(!SalArcMigAssociation(old, old, TRUE, &u, &p, &use));                       // arj, lzh, uc2, ace, ...
    CHECK(SalArcMigAssociation(-3, 7, TRUE, &u, &p, &use) && u == -3 && !use);            // plug-in + PKZIP25
    CHECK(SalArcMigAssociation(-3, 1, TRUE, &u, &p, &use) && u == -3 && p == 1 && use);   // plug-in + RAR
    CHECK(SalArcMigAssociation(1, 0, FALSE, &u, &p, &use) && u == 1 && !use);             // packing already off
    CHECK(SalArcMigAssociation(-2, -2, FALSE, &u, &p, &use) && u == -2 && !use);

    // --- M3: extension lists
    CHECK(SalArcMigListHasExt("arj;a##", "arj"));
    CHECK(SalArcMigListHasExt("ZIP;PK3;JAR", "jar"));
    CHECK(SalArcMigListHasExt("lzh;lha", "lha"));
    CHECK(!SalArcMigListHasExt("tlzh;lzhx", "lzh"));
    CHECK(!SalArcMigListHasExt("a##", "a01"));
    CHECK(!SalArcMigListHasExt("", "arj"));
    CHECK(!SalArcMigListHasExt("arj", ""));

    // --- idempotence: a migrated entry/record is left as it is on a second run
    CHECK(SalArcMigPacker(TRUE, rar, "a -scul -idq -y \"$(ArchiveFullName)\" @\"$(ListUnicodeFullName)\"",
                          rar, "m -scul -idq -y \"$(ArchiveFullName)\" @\"$(ListUnicodeFullName)\"") == sameKeep);
    CHECK(SalArcMigUnpacker(TRUE, "$(SevenZipExecutable)",
                            "x -y -sccUTF-8 -scsUTF-16LE \"$(ArchiveFullName)\" -o\"$(TargetPath)\" @\"$(ListUnicodeFullName)\"") == sameKeep);
    CHECK(SalArcMigAssociation(0, -1, FALSE, &u, &p, &use) == FALSE); // NB: index 0 after 084 is 7-Zip -
    // the migration runs only for configurations older than 106, whose index 0 is JAR (contract M0)
}

// ----------------------------------------------------------------------------
// feature 085 (F1): passwords typed into addresses never reach a history
// (src/common/salurlpwd.cpp, contracts/history-password-strip.md)

static std::string Strip085(const char* in)
{
    std::string buf(in);
    buf.push_back(0);
    SalStripUrlPasswords(&buf[0]);
    return std::string(buf.c_str());
}

static std::string StripCmd085(const char* in)
{
    std::string buf(in);
    buf.push_back(0);
    SalStripCommandLinePasswords(&buf[0]);
    return std::string(buf.c_str());
}

static const char* const Fs085[] = {"", NULL, "ftp", "ftps"}; // as FTP passes them before names are assigned

static std::string StripAddr085(const char* in)
{
    std::string buf(in);
    buf.push_back(0);
    SalStripAddressPassword(&buf[0], Fs085, 4);
    return std::string(buf.c_str());
}

static bool ValidU8_085(const std::string& s)
{
    return s.empty() || SalU8ToW(s.c_str(), -1, NULL, 0) != 0;
}

static void TestUrlPasswordStrip085()
{
    // --- C2, one typed value: the entry points of the spec (US1)
    CHECK(Strip085("ftp://alice:s3cret@ftp.example.com/pub") == "ftp://alice@ftp.example.com/pub");
    CHECK(Strip085("ftp://alice:s3cret@host") == "ftp://alice@host");
    CHECK(Strip085("ftps://alice:s3cret@host:990/in") == "ftps://alice@host:990/in");
    CHECK(Strip085("sftp://bob:pw@srv:2222/home") == "sftp://bob@srv:2222/home");

    // form 2: a file-system name without "//"
    CHECK(Strip085("ftp:alice:pw@host/dir") == "ftp:alice@host/dir");
    CHECK(Strip085("  ftp:alice:pw@host") == "  ftp:alice@host");
    CHECK(Strip085("sftp:bob:pw@srv:22/x") == "sftp:bob@srv:22/x");
    CHECK(Strip085("ftp:corp\\alice:pw@host") == "ftp:corp\\alice@host"); // review finding 2
    CHECK(Strip085("ftp:host:21/a:b@c") == "ftp:host:21/a:b@c");         // '@' only in the path

    // form 3: a plugin user part sent directly ("//user:pw@host")
    CHECK(Strip085("//alice:pw@host/pub") == "//alice@host/pub");
    CHECK(Strip085(" //alice:pw@host") == " //alice@host");
    CHECK(Strip085("///alice:pw@host") == "///alice:pw@host"); // empty part, nothing to do

    // passwords that look like other things - none of them may survive
    CHECK(Strip085("ftp://u:p@ss@host/x") == "ftp://u@host/x");                 // unescaped '@'
    CHECK(Strip085("ftp://u:p%40ss@host") == "ftp://u@host");                    // escaped '@' inside
    CHECK(Strip085("ftp://u:p:q@host") == "ftp://u@host");                       // ':' inside
    CHECK(Strip085("ftp://u:@host") == "ftp://u@host");                          // empty password
    CHECK(Strip085("ftp://alice:correct horse@host/x") == "ftp://alice@host/x"); // review finding 1
    CHECK(Strip085("ftp://alice:it's@host") == "ftp://alice@host");
    CHECK(Strip085("ftp://alice:a\"b<c>@host") == "ftp://alice@host");
    CHECK(Strip085("ftp://alice:pw\\x@host") == "ftp://alice@host");
    CHECK(Strip085("ftp://corp\\alice:pw@host") == "ftp://corp\\alice@host");   // domain user
    CHECK(Strip085("ftp://test.name@nas.cz:pw@host") == "ftp://test.name@nas.cz@host"); // '@' in the user name
    CHECK(Strip085("ftp://u:pa\xC4\x8D@host") == "ftp://u@host");               // UTF-8 password
    CHECK(Strip085("ftp://\xC4\x8D:pw@host/\xC4\x8D") == "ftp://\xC4\x8D@host/\xC4\x8D");
    // escaped delimiters the FTP plugin decodes (review finding 4)
    CHECK(Strip085("ftp://alice%3Apw@host") == "ftp://alice@host");
    CHECK(Strip085("ftp://alice%3apw@host") == "ftp://alice@host");
    CHECK(Strip085("ftp://alice:pw%40host") == "ftp://alice%40host");
    CHECK(Strip085("ftp://a:b%4Pc") == "ftp://a:b%4Pc");                      // "%4P" is no '@'
    CHECK(Strip085("ftp://a%3Bb@c") == "ftp://a%3Bb@c");                      // "%3B" is no ':'
    CHECK(Strip085("ftp://u:p%") == "ftp://u:p%");                            // '%' at the end: no over-read
    CHECK(Strip085("ftp://u:p%4") == "ftp://u:p%4");
    CHECK(Strip085("ftp://u:p@h%3") == "ftp://u@h%3");
    // a plugin path continuing with a drive has no user part (review 2, R1: Undelete)
    CHECK(Strip085("del:C:\\proj\\node_modules\\@types") == "del:C:\\proj\\node_modules\\@types");
    CHECK(Strip085("del:C:") == "del:C:");
    CHECK(Strip085("del:C:/x:y@z") == "del:C:/x:y@z");

    // nothing to remove: identical output
    CHECK(Strip085("ftp://alice@host/pub") == "ftp://alice@host/pub");
    CHECK(Strip085("ftp://host:2121/pub") == "ftp://host:2121/pub"); // a port is not a password
    CHECK(Strip085("ftp://[::1]:21/x") == "ftp://[::1]:21/x");
    CHECK(Strip085("ftp://alice@[::1]:21/x") == "ftp://alice@[::1]:21/x");
    CHECK(Strip085("ftp://host/a:b@c") == "ftp://host/a:b@c"); // '@' in the path
    CHECK(Strip085("ftp://a%40b@host") == "ftp://a%40b@host"); // escaped '@' in a user name
    CHECK(Strip085("C:\\a:b@c") == "C:\\a:b@c");               // drive letter
    CHECK(Strip085("C://a:b@c") == "C://a:b@c");               // one-letter scheme
    CHECK(Strip085("\\\\srv\\share\\a") == "\\\\srv\\share\\a");
    CHECK(Strip085("*.txt;*.md") == "*.txt;*.md");
    CHECK(Strip085("mailto:john@example.com") == "mailto:john@example.com");
    CHECK(Strip085("") == "");
    CHECK(Strip085("10:30") == "10:30");

    // --- C2', the command line
    CHECK(StripCmd085("curl ftp://alice:s3cret@host/f") == "curl ftp://alice@host/f");
    CHECK(StripCmd085("cp ftp://a:1@h1/x sftp://b:2@h2/y") == "cp ftp://a@h1/x sftp://b@h2/y");
    CHECK(StripCmd085("a http://u:p@h https://v:q@k") == "a http://u@h https://v@k");
    CHECK(StripCmd085("ftp://u:p@h a:b@c") == "ftp://u@h a:b@c"); // a space ends a word
    CHECK(StripCmd085("x 'ftp://u:p@h' y") == "x 'ftp://u@h' y");
    CHECK(StripCmd085("<ftp://u:p@h>") == "<ftp://u@h>");
    CHECK(StripCmd085("curl \"ftp://u:my pass@h/f\" -o x") == "curl \"ftp://u@h/f\" -o x"); // quoted URL
    CHECK(StripCmd085("curl 'ftp://u:it is@h' -v") == "curl 'ftp://u@h' -v");
    CHECK(StripCmd085("ftp:alice:pw@host") == "ftp:alice@host");
    CHECK(StripCmd085("//alice:pw@host") == "//alice@host");
    CHECK(StripCmd085("git clone https://token@github.com/x") == "git clone https://token@github.com/x");
    CHECK(StripCmd085("10:30 meeting a:b@c") == "10:30 meeting a:b@c"); // not a name, not a URL
    CHECK(StripCmd085("echo:hi a:b@c") == "echo:hi a:b@c");             // form 2 ends at the space
    CHECK(StripCmd085("net use \\\\srv\\c$ /user:x pw") == "net use \\\\srv\\c$ /user:x pw");
    CHECK(StripCmd085("dir C:\\") == "dir C:\\");

    // --- C2'', the FTP Quick Connect address field
    CHECK(StripAddr085("alice:pw@host/pub") == "alice@host/pub");
    CHECK(StripAddr085("  alice:pw@host") == "  alice@host");
    CHECK(StripAddr085("//alice:pw@host") == "//alice@host");
    CHECK(StripAddr085("ftp://alice:pw@host") == "ftp://alice@host");
    CHECK(StripAddr085("ftps://alice:pw@host:990") == "ftps://alice@host:990");
    CHECK(StripAddr085("FTP:alice:pw@host") == "FTP:alice@host");
    CHECK(StripAddr085("ftps:alice:pw@host") == "ftps:alice@host");
    CHECK(StripAddr085("ftp://alice:correct horse@host") == "ftp://alice@host");
    CHECK(StripAddr085("corp\\alice:pw@host") == "corp\\alice@host");
    CHECK(StripAddr085("alice@host") == "alice@host");
    CHECK(StripAddr085("host:21") == "host:21");
    CHECK(StripAddr085("ftp:pw@host") == "ftp:pw@host"); // "ftp:" is the file-system name here, as FTP parses it
    {
        const char* const own[] = {"myftp"};
        std::string buf("myftp:alice:pw@host");
        buf.push_back(0);
        CHECK(SalStripAddressPassword(&buf[0], own, 1));
        CHECK(strcmp(buf.c_str(), "myftp:alice@host") == 0);
        CHECK(!SalStripAddressPassword(NULL, own, 1));
        char plain[] = "alice:pw@host";
        CHECK(SalStripAddressPassword(plain, NULL, 0) && strcmp(plain, "alice@host") == 0);
    }

    // --- C1 directly
    {
        char a[] = "alice:pw@host";
        CHECK(SalStripAuthorityPassword(a, FALSE) && strcmp(a, "alice@host") == 0);
        char b[] = "alice:my pw@host";
        CHECK(!SalStripAuthorityPassword(b, TRUE)); // a command-line word ends at the space
        CHECK(SalStripAuthorityPassword(b, FALSE) && strcmp(b, "alice@host") == 0);
        CHECK(!SalStripAuthorityPassword(NULL, FALSE));
    }

    // --- C5 invariants: idempotence, no growth, UTF-8 in = UTF-8 out
    {
        const char* samples[] = {"ftp://u:p@ss@host/x", "cp ftp://a:1@h1/x sftp://b:2@h2/y",
                                 "ftp:alice:pw@host", "//alice:pw@host", "C:\\a:b@c", "x",
                                 "ftp://\xC4\x8D:\xC4\x8D@\xC4\x8D/\xC4\x8D", "curl \"ftp://u:a b@h\"",
                                 "ftp://alice%3Apw@host"};
        for (const char* s : samples)
        {
            std::string once = Strip085(s);
            CHECK(Strip085(once.c_str()) == once);
            CHECK(once.size() <= strlen(s));
            CHECK(ValidU8_085(once));
            std::string cmd = StripCmd085(s);
            CHECK(StripCmd085(cmd.c_str()) == cmd);
            CHECK(cmd.size() <= strlen(s));
            CHECK(ValidU8_085(cmd));
            std::string addr = StripAddr085(s);
            CHECK(StripAddr085(addr.c_str()) == addr);
            CHECK(addr.size() <= strlen(s));
        }
        char buf[] = "ftp://alice@host";
        CHECK(!SalStripUrlPasswords(buf));
        char buf2[] = "ftp://alice:x@host";
        CHECK(SalStripUrlPasswords(buf2));
        CHECK(!SalStripUrlPasswords(NULL));
        CHECK(!SalStripCommandLinePasswords(NULL));
    }

    // --- C3: the history array
    {
        char* h[6];
        h[0] = _strdup("ftp://alice@host");    // most recent, already clean
        h[1] = _strdup("ftp://alice:pw@host"); // becomes a duplicate of h[0] -> goes
        h[2] = NULL;                           // a hole (dropped invalid entry)
        h[3] = _strdup("C:\\work");
        h[4] = _strdup("ftp://bob:x@srv/a");
        h[5] = NULL;
        CHECK(SalStripHistoryPasswords(h, 6, SalStripUrlPasswords));
        CHECK(h[0] != NULL && strcmp(h[0], "ftp://alice@host") == 0);
        CHECK(h[1] != NULL && strcmp(h[1], "C:\\work") == 0);
        CHECK(h[2] != NULL && strcmp(h[2], "ftp://bob@srv/a") == 0);
        CHECK(h[3] == NULL && h[4] == NULL && h[5] == NULL);
        CHECK(!SalStripHistoryPasswords(h, 6, SalStripUrlPasswords)); // second run: nothing to do
        for (int i = 0; i < 6; i++)
            free(h[i]);
    }
    {
        char* h[2] = {_strdup("a"), _strdup("b")};
        CHECK(!SalStripHistoryPasswords(h, 2, SalStripUrlPasswords));
        CHECK(strcmp(h[0], "a") == 0 && strcmp(h[1], "b") == 0);
        free(h[0]);
        free(h[1]);
        CHECK(!SalStripHistoryPasswords(NULL, 2, SalStripUrlPasswords));
        CHECK(!SalStripHistoryPasswords(h, 0, SalStripUrlPasswords));
    }
}

// ----------------------------------------------------------------------------
// feature 086: the product's one source of security-relevant random bytes
// (src/common/salrandom.h, contracts/salrandom.md)

static void TestRandom086()
{
    // success, and only the requested range is written (guard bytes around it)
    {
        unsigned char buf[16 + 8];
        memset(buf, 0xA5, sizeof(buf));
        CHECK(SalGenRandom(buf + 4, 16));
        bool guards = true;
        for (int i = 0; i < 4; i++)
            guards = guards && buf[i] == 0xA5 && buf[sizeof(buf) - 1 - i] == 0xA5;
        CHECK(guards);
        bool allSame = true;
        for (int i = 5; i < 20; i++)
            allSame = allSame && buf[i] == buf[4];
        CHECK(!allSame); // 16 equal bytes: probability 2^-120
    }

    // argument rules
    {
        unsigned char buf[4] = {1, 2, 3, 4};
        CHECK(SalGenRandom(buf, 0));
        CHECK(buf[0] == 1 && buf[3] == 4); // nothing written
        CHECK(!SalGenRandom(buf, -1));
        CHECK(buf[0] == 1 && buf[3] == 4);
        CHECK(!SalGenRandom(NULL, 16));
        CHECK(SalGenRandom(NULL, 0));
    }

    // two draws differ (a salt is never repeated by construction of the source)
    {
        unsigned char a[16], b[16];
        CHECK(SalGenRandom(a, 16) && SalGenRandom(b, 16));
        CHECK(memcmp(a, b, 16) != 0);
    }

    // a 64 KiB draw holds every byte value (a stuck or narrow generator - e.g.
    // the old "(rand() >> 7) & 0xff" with a broken shift - would not)
    {
        std::vector<unsigned char> big(65536);
        CHECK(SalGenRandom(big.data(), (int)big.size()));
        bool seen[256] = {false};
        for (unsigned char c : big)
            seen[c] = true;
        int values = 0;
        for (int i = 0; i < 256; i++)
            values += seen[i] ? 1 : 0;
        CHECK(values == 256);
    }
}

// ----------------------------------------------------------------------------
// feature 087: names taken from an archive are made safe; archive signatures
// (src/common/salarcname.h, contracts/item-names.md)

static std::string Clean087(const char* in)
{
    char buf[1024];
    if (!SalArcCleanItemPath(in, buf, sizeof(buf)))
        return "<FALSE>";
    return buf;
}

static void TestArcNames087()
{
    // --- ordinary names are unchanged
    CHECK(Clean087("readme.txt") == "readme.txt");
    CHECK(Clean087("dir\\sub\\file.txt") == "dir\\sub\\file.txt");
    CHECK(Clean087("dir/sub/file.txt") == "dir\\sub\\file.txt"); // '/' is a separator
    CHECK(Clean087(".cvspass") == ".cvspass");
    CHECK(Clean087("a.b.c") == "a.b.c");
    CHECK(Clean087("..hidden") == "..hidden");     // not a ".." component
    CHECK(Clean087("dir\\...x") == "dir\\...x");
    CHECK(Clean087("con.d\\x") == "_con.d\\x"); // stem "con" is reserved
    // review of S2: the part before the first dot counts without trailing spaces;
    // the console pseudo-files, COM0/LPT0 and the superscript digits are devices too
    CHECK(Clean087("CON .txt") == "_CON .txt");
    CHECK(Clean087("com1  .txt") == "_com1  .txt");
    CHECK(Clean087("CONIN$") == "_CONIN$");
    CHECK(Clean087("conout$.log") == "_conout$.log");
    CHECK(Clean087("COM0") == "_COM0");
    CHECK(Clean087("lpt0.txt") == "_lpt0.txt");
    CHECK(Clean087("COM\xC2\xB9") == "_COM\xC2\xB9");
    CHECK(Clean087("lpt\xC2\xB3.x") == "_lpt\xC2\xB3.x");
    CHECK(Clean087("com\xC2\xB5") == "com\xC2\xB5"); // U+00B5 is no digit
    CHECK(Clean087("conin") == "conin");
    CHECK(Clean087("console.txt") == "console.txt"); // stem is not exactly "con"
    CHECK(Clean087("com10") == "com10");
    CHECK(Clean087("\xC4\x8D\xC3\xA1st\\\xE4\xB8\xAD\xE6\x96\x87\\\xF0\x9F\x93\x81.txt") ==
          "\xC4\x8D\xC3\xA1st\\\xE4\xB8\xAD\xE6\x96\x87\\\xF0\x9F\x93\x81.txt"); // UTF-8 untouched

    // --- climbing out: ".." and "." components are dropped
    CHECK(Clean087("..\\..\\evil.txt") == "evil.txt");
    CHECK(Clean087("a\\..\\..\\b") == "a\\b");
    CHECK(Clean087("../../etc/passwd") == "etc\\passwd");
    CHECK(Clean087(".\\.\\x") == "x");
    CHECK(Clean087("a\\.\\b") == "a\\b");
    CHECK(Clean087("..") == "_");
    CHECK(Clean087(".\\.\\") == "_");
    CHECK(Clean087("") == "_");
    CHECK(Clean087("a\\\\\\b") == "a\\b"); // empty components

    // --- absolute, drive, UNC and device prefixes
    CHECK(Clean087("C:\\Windows\\x.dll") == "Windows\\x.dll");
    CHECK(Clean087("c:x") == "c_x"); // not a drive: ":" replaced
    CHECK(Clean087("C:") == "_");
    CHECK(Clean087("\\x") == "x");
    CHECK(Clean087("/etc/passwd") == "etc\\passwd");
    CHECK(Clean087("\\\\srv\\share\\dir\\x") == "dir\\x");
    CHECK(Clean087("//srv/share/x") == "x");
    CHECK(Clean087("\\\\?\\C:\\x") == "x");
    CHECK(Clean087("\\\\.\\C:\\x") == "x");
    CHECK(Clean087("\\\\?\\UNC\\srv\\sh\\x") == "x");
    CHECK(Clean087("\\\\srv") == "_");

    // --- alternate data streams and forbidden characters
    CHECK(Clean087("report.txt:secret") == "report.txt_secret");
    CHECK(Clean087("x::$DATA") == "x__$DATA");
    CHECK(Clean087("dir\\a:b\\c") == "dir\\a_b\\c");
    CHECK(Clean087("a<b>c\"d|e?f*g") == "a_b_c_d_e_f_g");
    CHECK(Clean087("tab\there\x01") == "tab_here_");

    // --- trailing dots and spaces, reserved device names
    CHECK(Clean087("a.") == "a_");
    CHECK(Clean087("a ") == "a_");
    CHECK(Clean087("dir. \\x") == "dir__\\x");
    CHECK(Clean087("nul.") == "_nul_");
    CHECK(Clean087("con") == "_con");
    CHECK(Clean087("CON.txt") == "_CON.txt");
    CHECK(Clean087("dir\\aux\\prn") == "dir\\_aux\\_prn");
    CHECK(Clean087("COM1") == "_COM1");
    CHECK(Clean087("lpt9.log") == "_lpt9.log");

    // --- idempotence and the buffer limit
    {
        const char* samples[] = {"..\\..\\evil.txt", "C:\\a:b\\con.", "\\\\?\\UNC\\s\\h\\x y.", "ok\\name.txt", ""};
        for (const char* s : samples)
        {
            std::string once = Clean087(s);
            CHECK(Clean087(once.c_str()) == once);
        }
        char tiny[6];
        CHECK(SalArcCleanItemPath("abc", tiny, sizeof(tiny)) && strcmp(tiny, "abc") == 0);
        CHECK(!SalArcCleanItemPath("abcdefgh", tiny, sizeof(tiny)) && tiny[0] == 0);
        CHECK(!SalArcCleanItemPath("x", tiny, 0));
        CHECK(SalArcCleanItemPath(NULL, tiny, sizeof(tiny)) && strcmp(tiny, "_") == 0);
    }

    // --- N2 signatures
    {
        const BYTE z7[] = {0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C, 0x00, 0x04};
        const BYTE r4[] = {0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x00, 0xCF};
        const BYTE r5[] = {0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00};
        const BYTE zip[] = {0x50, 0x4B, 0x03, 0x04, 0, 0, 0, 0};
        CHECK(SalArcDetectFormat(z7, 8) == SALARC_FORMAT_7Z);
        CHECK(SalArcDetectFormat(r4, 8) == SALARC_FORMAT_RAR);
        CHECK(SalArcDetectFormat(r5, 8) == SALARC_FORMAT_RAR5);
        CHECK(SalArcDetectFormat(zip, 8) == SALARC_FORMAT_UNKNOWN);
        CHECK(SalArcDetectFormat(r5, 7) == SALARC_FORMAT_UNKNOWN); // 7 bytes of RAR5 = "Rar!\x1A\x07\x01": neither
        CHECK(SalArcDetectFormat(r4, 3) == SALARC_FORMAT_UNKNOWN);
        CHECK(SalArcDetectFormat(NULL, 8) == SALARC_FORMAT_UNKNOWN);
    }
}

//*****************************************************************************
//
// feature 089: the plug-in converters (src/plugins/shared/splunicode.h) are
// WTF-8 like the core's, and the extension-list helpers of the association
// update (src/common/salarcassoc.h)
//

static void TestSplUnicode089()
{
    // (1) parity with the core and round trip, W -> bytes -> W
    static const WCHAR* const wide[] = {
        L"", L"plain.txt", L"C:\\dir\\\x010D\x00E1st \x4E2D\x6587.bin",
        L"\xD83D\xDE00 astral pair", // U+1F600
        L"lone\xD800high.txt", L"lone\xDC00low.txt", L"\xDFFF", L"\xDBFF",
        L"\xD800\xD800\xDC00", // a lone high surrogate before a valid pair
        L"\xDC00\xD800",       // reversed pair = two lone surrogates
        L"tail\xD83D"};
    for (int i = 0; i < _countof(wide); i++)
    {
        char core[200], spl[200];
        int coreLen = SalWToU8(wide[i], -1, core, _countof(core));
        int splLen = SplWToU8(wide[i], spl, _countof(spl));
        CHECK(coreLen > 0 && splLen == coreLen);
        CHECK(memcmp(core, spl, coreLen) == 0);
        char* a = SplWToU8Alloc(wide[i]);
        CHECK(a != NULL && strcmp(a, core) == 0);
        WCHAR back[200];
        int backLen = SplU8ToW(spl, back, _countof(back));
        CHECK(backLen == (int)wcslen(wide[i]) + 1 && wcscmp(back, wide[i]) == 0);
        WCHAR* wa = SplU8ToWAlloc(spl);
        CHECK(wa != NULL && wcscmp(wa, wide[i]) == 0);
        free(a);
        free(wa);
    }

    // (2) a lone surrogate is exactly the 3-byte sequence, a pair stays one 4-byte sequence
    {
        char b[16];
        CHECK(SplWToU8(L"\xD800", b, _countof(b)) == 4 && memcmp(b, "\xED\xA0\x80", 4) == 0);
        CHECK(SplWToU8(L"\xDFFF", b, _countof(b)) == 4 && memcmp(b, "\xED\xBF\xBF", 4) == 0);
        CHECK(SplWToU8(L"\xD83D\xDE00", b, _countof(b)) == 5 && memcmp(b, "\xF0\x9F\x98\x80", 5) == 0);
    }

    // (3) every other malformed input still fails, as in the core
    static const char* const bad[] = {
        "\xE1", "caf\xE9.txt",  // code-page bytes
        "\xC0\xAF", "\xC1\xBF", // overlong
        "\xE0\x80\xAF",         // overlong 3-byte
        "\xF4\x90\x80\x80",     // above U+10FFFF
        "\xF5\x80\x80\x80",     // invalid lead byte
        "\x80", "a\xBF",        // stray continuation
        "\xE2\x82",             // truncated
        "\xED\xA0"};            // truncated surrogate sequence
    for (int i = 0; i < _countof(bad); i++)
    {
        WCHAR w[32];
        w[0] = L'x';
        CHECK(SplU8ToW(bad[i], w, _countof(w)) == 0 && w[0] == 0);
        CHECK(SplU8ToWAlloc(bad[i]) == NULL);
        CHECK(SalU8ToW(bad[i], -1, w, _countof(w)) == 0); // the core agrees
    }

    // (4) buffer limits: a result that does not fit fails and leaves an empty string
    {
        char b3[3];
        b3[0] = 'x';
        CHECK(SplWToU8(L"\xD800", b3, _countof(b3)) == 0 && b3[0] == 0); // needs 4 bytes
        char b4[4];
        CHECK(SplWToU8(L"\xD800", b4, _countof(b4)) == 4);
        WCHAR w1[1];
        w1[0] = L'x';
        CHECK(SplU8ToW("\xED\xA0\x80", w1, _countof(w1)) == 0 && w1[0] == 0); // needs 2 units
        WCHAR w2[2];
        CHECK(SplU8ToW("\xED\xA0\x80", w2, _countof(w2)) == 2 && w2[0] == 0xD800 && w2[1] == 0);
        CHECK(SplU8ToW(NULL, w2, 2) == 0 && SplWToU8(NULL, b4, 4) == 0);
        CHECK(SplU8ToWAlloc(NULL) == NULL && SplWToU8Alloc(NULL) == NULL);
    }

    // (5) the extended-length path helper accepts such a name too
    {
        WCHAR* ext = SplU8ToWExtAlloc("C:\\dir\\lone\xED\xA0\x80.txt");
        CHECK(ext != NULL && wcscmp(ext, L"\\\\?\\C:\\dir\\lone\xD800.txt") == 0);
        free(ext);
    }
}

static BOOL ExtRemove089(const char* list, const char* ext, const char* expect, BOOL expectRemoved)
{
    char out[64];
    BOOL removed = SalExtListRemove(list, ext, out, _countof(out));
    return removed == expectRemoved && strcmp(out, expect) == 0;
}

static void TestArcAssoc089()
{
    CHECK(SalExtListContains("rar;r##", "rar"));
    CHECK(SalExtListContains("rar;r##", "R##"));
    CHECK(SalExtListContains("7z;RAR;r##", "rar"));
    CHECK(!SalExtListContains("rar;r##", "ra"));
    CHECK(!SalExtListContains("rar;r##", "r#"));
    CHECK(!SalExtListContains("xrar;rarx", "rar")); // whole items only
    CHECK(!SalExtListContains("", "rar"));
    CHECK(!SalExtListContains("rar", ""));
    CHECK(!SalExtListContains(NULL, "rar"));
    CHECK(!SalExtListContains("rar", NULL));
    CHECK(SalExtListContains("a;;rar", "rar")); // an empty item is no obstacle

    CHECK(ExtRemove089("7z;rar;r##", "rar", "7z;r##", TRUE));
    CHECK(ExtRemove089("7z;rar;r##", "r##", "7z;rar", TRUE));
    CHECK(ExtRemove089("7z;rar;r##", "7Z", "rar;r##", TRUE));
    CHECK(ExtRemove089("rar", "rar", "", TRUE));
    CHECK(ExtRemove089("rar;rar;x", "rar", "x", TRUE));   // every occurrence
    CHECK(ExtRemove089("7z;rar", "zip", "7z;rar", FALSE)); // nothing to remove
    CHECK(ExtRemove089("7z;;rar;", "zip", "7z;rar", FALSE)); // empty items are dropped
    CHECK(ExtRemove089("", "rar", "", FALSE));
    CHECK(ExtRemove089(NULL, "rar", "", FALSE));
    CHECK(ExtRemove089("xrar;rar", "rar", "xrar", TRUE));
    {
        char same[32] = "7z;rar;r##"; // in place
        CHECK(SalExtListRemove(same, "7z", same, _countof(same)) && strcmp(same, "rar;r##") == 0);
        char tiny5[5];
        CHECK(!SalExtListRemove("abc;defg", "x", tiny5, _countof(tiny5)) && strcmp(tiny5, "abc") == 0); // cut at an item
    }
}

//*****************************************************************************
//
// feature 090: the FTP plug-in's placeholder for anonymous logins
// (src/common/salftpanon.h)
//

static void TestFtpAnon090()
{
    CHECK(strcmp(SAL_FTP_ANONYMOUS_DEFAULT, "anonymous@example.com") == 0);
    // the old placeholder, in any letter case, becomes the new one
    CHECK(strcmp(SalFtpAnonymousOnLoad("name@someserver.com"), SAL_FTP_ANONYMOUS_DEFAULT) == 0);
    CHECK(strcmp(SalFtpAnonymousOnLoad("Name@SomeServer.COM"), SAL_FTP_ANONYMOUS_DEFAULT) == 0);
    CHECK(strcmp(SalFtpAnonymousOnLoad(NULL), SAL_FTP_ANONYMOUS_DEFAULT) == 0);
    // everything else is the user's own value and comes back as the same pointer
    static const char* const own[] = {
        "", "me@mydomain.org", "name@someserver.co", "name@someserver.com ", " name@someserver.com",
        "name@someserver.comx", "xname@someserver.com", "name@someserver.org", "anonymous@example.com",
        "name@someserver.com\t", "n\xC3\xA1me@someserver.com"};
    for (int i = 0; i < _countof(own); i++)
        CHECK(SalFtpAnonymousOnLoad(own[i]) == own[i]);
    // idempotent
    CHECK(strcmp(SalFtpAnonymousOnLoad(SalFtpAnonymousOnLoad("name@someserver.com")), SAL_FTP_ANONYMOUS_DEFAULT) == 0);
}

//*****************************************************************************
//
// feature 092 (encoding cluster B-2): name identity - the file system's rule
// (src/common/salunicode.cpp, contracts/name-identity.md)
//

// UTF-8 of one or two UTF-16 strings, for building test names from code points
static std::string U8of092(const WCHAR* w)
{
    char buf[400];
    int n = SalWToU8(w, -1, buf, _countof(buf));
    return n > 0 ? std::string(buf) : std::string();
}

static int Sign092(int v) { return v < 0 ? -1 : (v > 0 ? 1 : 0); }

// today's StrICmpEx on ASCII input: fold to LOWER case, shorter is smaller
static int RefAsciiLowerCmp092(const char* a, const char* b)
{
    int la = (int)strlen(a), lb = (int)strlen(b);
    int l = la < lb ? la : lb;
    for (int i = 0; i < l; i++)
    {
        int ca = tolower((unsigned char)a[i]), cb = tolower((unsigned char)b[i]);
        if (ca != cb)
            return ca < cb ? -1 : 1;
    }
    return la == lb ? 0 : (la < lb ? -1 : 1);
}

static BOOL Eq092(const WCHAR* a, const WCHAR* b)
{
    std::string ua = U8of092(a), ub = U8of092(b);
    BOOL eq = SalNameEqualOrdinalCI(ua.c_str(), -1, ub.c_str(), -1);
    // the yes/no answer and the three-way answer agree, in both directions
    CHECK(eq == (SalNameCompareOrdinalCI(ua.c_str(), -1, ub.c_str(), -1) == 0));
    CHECK(eq == SalNameEqualOrdinalCI(ub.c_str(), -1, ua.c_str(), -1));
    CHECK(Sign092(SalNameCompareOrdinalCI(ua.c_str(), -1, ub.c_str(), -1)) ==
          -Sign092(SalNameCompareOrdinalCI(ub.c_str(), -1, ua.c_str(), -1)));
    return eq;
}

// feature 093: overflow of a dialog field's text (contract D4) and the menu
// mnemonic of a wide message loop
static void TestDialogText093()
{
    char buf[64];
    // a: 1 byte, U+0159: 2, U+0416: 2, U+65E5: 3, U+1F4C1 (a surrogate pair): 4 = 12 bytes
    static const WCHAR text[] = L"a\x0159\x0416\x65E5\xD83D\xDCC1";
    static const char u8[] = "a\xC5\x99\xD0\x96\xE6\x97\xA5\xF0\x9F\x93\x81";

    // --- fits: identical to SalWToU8, return value includes the terminator
    memset(buf, 'x', sizeof(buf));
    CHECK(SalWToU8Truncate(text, buf, sizeof(buf)) == 13 && strcmp(buf, u8) == 0);
    memset(buf, 'x', sizeof(buf));
    CHECK(SalWToU8Truncate(text, buf, 13) == 13 && strcmp(buf, u8) == 0); // exactly
    CHECK(SalWToU8Truncate(L"", buf, sizeof(buf)) == 1 && buf[0] == 0);

    // --- does not fit: whole characters only, for every buffer size; the byte
    //     behind the terminator is never written
    static const int wholeLen[] = {0, 0, 1, 1, 3, 3, 5, 5, 5, 8, 8, 8, 8, 12}; // by bufSize
    for (int size = 1; size <= 13; size++)
    {
        memset(buf, 'x', sizeof(buf));
        int res = SalWToU8Truncate(text, buf, size);
        CHECK(res == wholeLen[size] + 1);
        CHECK((int)strlen(buf) == wholeLen[size] && memcmp(buf, u8, wholeLen[size]) == 0);
        CHECK(buf[size] == 'x');
        // the result is valid UTF-8 and a prefix of the text
        WCHAR back[16];
        CHECK(SalU8ToW(buf, -1, back, 16) != 0 && wcsncmp(back, text, wcslen(back)) == 0);
    }
    // the old fallback would have produced code-page bytes here ('?' for U+0416)
    SalWToU8Truncate(text, buf, 6);
    CHECK(strchr(buf, '?') == NULL);

    // --- a lone surrogate (WTF-8, 3 bytes) is one character for the cut
    static const WCHAR lone[] = L"ab\xD800";
    CHECK(SalWToU8Truncate(lone, buf, 6) == 6 && strcmp(buf, "ab\xED\xA0\x80") == 0);
    CHECK(SalWToU8Truncate(lone, buf, 5) == 3 && strcmp(buf, "ab") == 0);
    CHECK(SalWToU8Truncate(lone, buf, 4) == 3 && strcmp(buf, "ab") == 0);

    // --- arguments
    buf[0] = 'x';
    CHECK(SalWToU8Truncate(NULL, buf, sizeof(buf)) == 0 && buf[0] == 0);
    CHECK(SalWToU8Truncate(text, NULL, 10) == 0);
    buf[0] = 'x';
    CHECK(SalWToU8Truncate(text, buf, 0) == 0 && buf[0] == 'x');

    // --- mnemonics: ASCII, either case
    CHECK(SalMnemonicMatchW("&Files", L'f') && SalMnemonicMatchW("&Files", L'F'));
    CHECK(SalMnemonicMatchW("O&ptions", L'P') && !SalMnemonicMatchW("O&ptions", L'o'));
    CHECK(!SalMnemonicMatchW("Files", L'f') && !SalMnemonicMatchW("Files&", L'f'));
    CHECK(!SalMnemonicMatchW("", L'f') && !SalMnemonicMatchW(NULL, L'f') && !SalMnemonicMatchW("&Files", 0));
    // "&&" is a literal ampersand, the mnemonic is behind the next single one
    CHECK(SalMnemonicMatchW("R&&D &Tools", L't') && !SalMnemonicMatchW("R&&D &Tools", L'&') &&
          !SalMnemonicMatchW("R&&D &Tools", L'd'));
    CHECK(!SalMnemonicMatchW("R&&D", L'd') && !SalMnemonicMatchW("R&&D", L'&'));
    // an accented mnemonic in a UTF-8 string: U+0159 / U+0158, U+0416 / U+0436, U+65E5
    CHECK(SalMnemonicMatchW("&\xC5\x99"
                            "adit",
                            0x0159) &&
          SalMnemonicMatchW("&\xC5\x99"
                            "adit",
                            0x0158));
    CHECK(SalMnemonicMatchW("&\xD0\x96", 0x0436) && SalMnemonicMatchW("\xE6\x97\xA5 (&\xE6\x97\xA5)", 0x65E5));
    // what the truncating comparison did: U+0159 is not 'Y' (low byte 0x59)
    CHECK(!SalMnemonicMatchW("&Yes", 0x0159) && SalMnemonicMatchW("&Yes", L'y'));
    // a mnemonic outside the BMP never matches one unit; a torn sequence does not match either
    CHECK(!SalMnemonicMatchW("&\xF0\x9F\x93\x81", 0xD83D) && !SalMnemonicMatchW("&\xF0\x9F\x93\x81", 0xDCC1));
    CHECK(!SalMnemonicMatchW("&\xC5", 0x0159));

    // --- code-page side (the machine's code page decides what a byte is)
    CHECK(SalACPCharToW('a') == L'a' && SalACPCharToW('&') == L'&');
    if (GetACP() == 1250)
    {
        CHECK(SalACPCharToW((char)0xF8) == 0x0159);
        // a legacy code-page menu string: the byte 0xF8 is not UTF-8 by itself
        CHECK(SalMnemonicMatchW("&\xF8"
                                "adit",
                                0x0159) &&
              SalMnemonicMatchW("&\xF8"
                                "adit",
                                0x0158));
    }
    else
        printf("skipping the code page 1250 part of TestDialogText093 (code page %u)\n", GetACP());
}

// feature 093 (stage S3): byte offsets of UTF-8 text as UTF-16 unit offsets,
// what a Unicode edit control (the command line) counts.
static void TestCmdLineOffsets093()
{
    // a: 1 byte / 1 unit, U+0159: 2 / 1, U+0416: 2 / 1, U+65E5: 3 / 1,
    // U+1F4C1: 4 / 2 (a surrogate pair), z: 1 / 1
    static const char u8[] = "a\xC5\x99\xD0\x96\xE6\x97\xA5\xF0\x9F\x93\x81z";
    //                           byte: 0  1  2  3  4  5  6  7  8  9 10 11 12 13
    static const int units[] = {0, 1, 1, 2, 2, 3, 3, 3, 4, 4, 4, 4, 6, 7};
    for (int i = 0; i <= 13; i++)
        CHECK(SalU8OffsetToW(u8, i) == units[i]);
    // behind the end = the end; negative = the start
    CHECK(SalU8OffsetToW(u8, 14) == 7 && SalU8OffsetToW(u8, 100000) == 7);
    CHECK(SalU8OffsetToW(u8, -1) == 0 && SalU8OffsetToW(u8, -100000) == 0);
    // the result is the length of the converted prefix
    WCHAR w[16];
    CHECK(SalU8ToW(u8, -1, w, 16) == 8 && w[4] == 0xD83D && w[5] == 0xDCC1 && w[6] == L'z');

    // ASCII: bytes are units
    for (int i = 0; i <= 5; i++)
        CHECK(SalU8OffsetToW("hello", i) == i);
    CHECK(SalU8OffsetToW("", 0) == 0 && SalU8OffsetToW("", 3) == 0);

    // a lone surrogate (WTF-8: ED A0 80) is one unit; offsets inside it mean its start
    static const char lone[] = "ab\xED\xA0\x80"
                               "c";
    CHECK(SalU8OffsetToW(lone, 2) == 2 && SalU8OffsetToW(lone, 3) == 2 && SalU8OffsetToW(lone, 4) == 2);
    CHECK(SalU8OffsetToW(lone, 5) == 3 && SalU8OffsetToW(lone, 6) == 4);
    // a lone low surrogate followed by a lone high one: two units, not a pair
    static const char lowHigh[] = "\xED\xB0\x80\xED\xA0\x80";
    CHECK(SalU8OffsetToW(lowHigh, 3) == 1 && SalU8OffsetToW(lowHigh, 6) == 2);

    // not UTF-8 (a code-page byte, a torn sequence): the caller keeps byte offsets
    CHECK(SalU8OffsetToW("a\xF8"
                         "b",
                         1) == -1);
    CHECK(SalU8OffsetToW("a\xC5", 0) == -1 && SalU8OffsetToW("a\xC5", 1) == -1);
    CHECK(SalU8OffsetToW(NULL, 0) == -1);
}

// feature 093 (contract P1): the two forms of a typed archive password
// (src/common/salarcpwd.h). Code page 1250 is passed explicitly, so the
// expectations do not depend on the machine.
static void TestArchivePassword093()
{
    WCHAR out[SALARCPWD_OLD_BUFFER];
    const UINT cp = 1250;

    // --- ASCII: one form, never a second attempt
    CHECK(SalArcPwdIsAscii(L"") && SalArcPwdIsAscii(NULL) && SalArcPwdIsAscii(L"heslo-123 ~!"));
    CHECK(!SalArcPwdIsAscii(L"heslo-\x0159") && !SalArcPwdIsAscii(L"\x0080"));
    CHECK(SalArcPwdLegacy(L"heslo", out, SALARCPWD_OLD_BUFFER, cp) && wcscmp(out, L"heslo") == 0);
    CHECK(!SalArcPwdHasLegacy(L"heslo", cp) && !SalArcPwdHasLegacy(L"", cp) && !SalArcPwdHasLegacy(NULL, cp));
    CHECK(SalArcPwdLegacy(L"", out, SALARCPWD_OLD_BUFFER, cp) && out[0] == 0);

    // --- the measured case: U+0159 = C5 99 -> U+0139 U+2122 on code page 1250
    CHECK(SalArcPwdLegacy(L"heslo-\x0159", out, SALARCPWD_OLD_BUFFER, cp) && wcscmp(out, L"heslo-\x0139\x2122") == 0);
    CHECK(SalArcPwdHasLegacy(L"heslo-\x0159", cp));
    // Cyrillic "parol": D0 BF D0 B0 D1 80 D0 BE D0 BB D1 8C
    CHECK(SalArcPwdLegacy(L"\x043F\x0430\x0440\x043E\x043B\x044C", out, SALARCPWD_OLD_BUFFER, cp) &&
          wcscmp(out, L"\x0110\x017C\x0110\x00B0\x0143\x20AC\x0110\x013E\x0110\x00BB\x0143\x015A") == 0);
    // U+65E5 = E6 97 A5, U+1F4C1 = F0 9F 93 81
    CHECK(SalArcPwdLegacy(L"\x65E5", out, SALARCPWD_OLD_BUFFER, cp) && wcscmp(out, L"\x0107\x2014\x0104") == 0);
    CHECK(SalArcPwdLegacy(L"\xD83D\xDCC1", out, SALARCPWD_OLD_BUFFER, cp) && wcslen(out) == 4 && out[0] == 0x0111);

    // --- bytes code page 1250 does not define (81 83 88 90 98): the old code
    //     converted with flags 0, Windows answers with the C1 control of the
    //     same value - the legacy form must hold exactly that
    CHECK(SalArcPwdLegacy(L"\x0141", out, SALARCPWD_OLD_BUFFER, cp) && wcscmp(out, L"\x0139\x0081") == 0); // C5 81
    CHECK(SalArcPwdLegacy(L"\x0143", out, SALARCPWD_OLD_BUFFER, cp) && wcscmp(out, L"\x0139\x0083") == 0); // C5 83
    CHECK(SalArcPwdLegacy(L"\x0148", out, SALARCPWD_OLD_BUFFER, cp) && wcscmp(out, L"\x0139\x0088") == 0); // C5 88
    CHECK(SalArcPwdLegacy(L"\x0150", out, SALARCPWD_OLD_BUFFER, cp) && wcscmp(out, L"\x0139\x0090") == 0); // C5 90
    CHECK(SalArcPwdLegacy(L"\x0158", out, SALARCPWD_OLD_BUFFER, cp) && wcscmp(out, L"\x0139\x0098") == 0); // C5 98
    CHECK(SalArcPwdHasLegacy(L"\x0158", cp));

    // --- the old 128-byte buffer: 63 x U+0159 = 126 bytes fit; 64 = 128 bytes
    //     did not, and the old dialog then read the field as code-page text,
    //     which the consumers decoded back to the typed text
    WCHAR typed[SALARCPWD_OLD_BUFFER];
    int i;
    for (i = 0; i < 63; i++)
        typed[i] = 0x0159;
    typed[63] = 0;
    CHECK(SalArcPwdLegacy(typed, out, SALARCPWD_OLD_BUFFER, cp) && wcslen(out) == 126 && out[0] == 0x0139 &&
          out[125] == 0x2122);
    typed[63] = 0x0159;
    typed[64] = 0;
    CHECK(SalArcPwdLegacy(typed, out, SALARCPWD_OLD_BUFFER, cp) && wcscmp(out, typed) == 0);
    CHECK(!SalArcPwdHasLegacy(typed, cp));
    // ... and characters outside the code page became '?' there
    for (i = 0; i < 100; i++)
        typed[i] = 0x0416;
    typed[100] = 0;
    CHECK(SalArcPwdLegacy(typed, out, SALARCPWD_OLD_BUFFER, cp) && wcslen(out) == 100 && out[0] == L'?' && out[99] == L'?');
    CHECK(SalArcPwdHasLegacy(typed, cp));
    // the longest text the field takes (127 units): ASCII stays; the code-page read was cut to 127 bytes
    for (i = 0; i < 127; i++)
        typed[i] = L'a';
    typed[127] = 0;
    CHECK(SalArcPwdLegacy(typed, out, SALARCPWD_OLD_BUFFER, cp) && wcscmp(out, typed) == 0);
    for (i = 0; i < 127; i++)
        typed[i] = 0x0159;
    CHECK(SalArcPwdLegacy(typed, out, SALARCPWD_OLD_BUFFER, cp) && wcscmp(out, typed) == 0 && !SalArcPwdHasLegacy(typed, cp));
    // an unpaired surrogate was not UTF-8 for the old (strict) conversion: the code-page read again
    CHECK(SalArcPwdLegacy(L"a\xD800", out, SALARCPWD_OLD_BUFFER, cp) && wcscmp(out, L"a?") == 0);
    // three-byte characters: 42 x U+65E5 = 126 bytes fit (E6 97 A5 each), 43 = 129 bytes do not
    for (i = 0; i < 43; i++)
        typed[i] = 0x65E5;
    typed[42] = 0;
    CHECK(SalArcPwdLegacy(typed, out, SALARCPWD_OLD_BUFFER, cp) && wcslen(out) == 126 && out[0] == 0x0107 &&
          out[1] == 0x2014 && out[2] == 0x0104 && out[125] == 0x0104);
    typed[42] = 0x65E5;
    typed[43] = 0;
    CHECK(SalArcPwdLegacy(typed, out, SALARCPWD_OLD_BUFFER, cp) && wcslen(out) == 43 && out[0] == L'?' && out[42] == L'?');
    // four-byte characters (surrogate pairs): 31 pairs = 124 bytes fit, 32 pairs = 128 bytes do not;
    // the code-page read gives one '?' per UTF-16 unit
    for (i = 0; i < 32; i++)
    {
        typed[2 * i] = 0xD83D;
        typed[2 * i + 1] = 0xDCC1;
    }
    typed[62] = 0;
    CHECK(SalArcPwdLegacy(typed, out, SALARCPWD_OLD_BUFFER, cp) && wcslen(out) == 124 && out[0] == 0x0111);
    typed[62] = 0xD83D;
    typed[64] = 0;
    CHECK(SalArcPwdLegacy(typed, out, SALARCPWD_OLD_BUFFER, cp) && wcslen(out) == 64 && out[0] == L'?' && out[63] == L'?');
    // an unpaired surrogate as the last of the 127 units the field takes: 127 code-page bytes, just fit
    for (i = 0; i < 126; i++)
        typed[i] = L'a';
    typed[126] = 0xD800;
    typed[127] = 0;
    CHECK(SalArcPwdLegacy(typed, out, SALARCPWD_OLD_BUFFER, cp) && wcslen(out) == 127 && out[125] == L'a' && out[126] == L'?');
    CHECK(SalArcPwdHasLegacy(typed, cp));
    // one unit more (the field never gives that): the old read was cut to 127 bytes
    {
        WCHAR longer[130];
        for (i = 0; i < 127; i++)
            longer[i] = L'a';
        longer[127] = 0xD800;
        longer[128] = 0;
        CHECK(SalArcPwdLegacy(longer, out, SALARCPWD_OLD_BUFFER, cp) && wcslen(out) == 127 && out[126] == L'a');
    }

    // --- a machine whose code page is UTF-8: the old code was right there
    CHECK(SalArcPwdLegacy(L"heslo-\x0159", out, SALARCPWD_OLD_BUFFER, CP_UTF8) && wcscmp(out, L"heslo-\x0159") == 0);
    CHECK(!SalArcPwdHasLegacy(L"heslo-\x0159", CP_UTF8));
    // --- another code page gives another legacy form (1252: C5 = U+00C5, 99 = U+2122)
    CHECK(SalArcPwdLegacy(L"heslo-\x0159", out, SALARCPWD_OLD_BUFFER, 1252) && wcscmp(out, L"heslo-\x00C5\x2122") == 0);

    // --- arguments: a buffer too small gives FALSE and an empty string, never a cut password
    out[0] = L'x';
    CHECK(!SalArcPwdLegacy(L"heslo-\x0159", out, 8, cp) && out[0] == 0);
    CHECK(SalArcPwdLegacy(L"heslo-\x0159", out, 9, cp) && wcscmp(out, L"heslo-\x0139\x2122") == 0);
    CHECK(!SalArcPwdLegacy(L"x", NULL, 10, cp) && !SalArcPwdLegacy(L"x", out, 0, cp));
    out[0] = L'x';
    CHECK(!SalArcPwdLegacy(NULL, out, SALARCPWD_OLD_BUFFER, cp) && out[0] == 0);

    // --- the default argument is the machine's code page
    if (GetACP() == 1250)
        CHECK(SalArcPwdLegacy(L"heslo-\x0159", out, SALARCPWD_OLD_BUFFER) && wcscmp(out, L"heslo-\x0139\x2122") == 0 &&
              SalArcPwdHasLegacy(L"heslo-\x0159"));
}

// feature 094 (contract zip-password-forms.md): the byte forms of a typed ZIP
// password (src/common/salzippwd.h). Code pages 1250 / 852 are passed
// explicitly where the expectation is a literal; the rest is computed with
// the same Win32 calls the old code used.
// feature 095: the heap string that replaced the stack buffers of the archive's disk-cache name
// feature 101: the tray tip (SalU8ToWTruncate into NOTIFYICONDATAW::szTip, 128 units) and the
// share look-up's whole-path, component-boundary match (SalPathIsWithinOrdinalCI)
static void TestLeftovers101()
{
    WCHAR tip[128];
    WCHAR buf[16];

    // --- exact: Czech, Cyrillic, CJK and an emoji (a surrogate pair) - the ANSI tip showed the
    //     UTF-8 bytes as code-page text
    CHECK(SalU8ToWTruncate("d\xC5\x99" "\xD0\x96" "\xE4\xB8\xAD" "\xF0\x9F\x98\x80", tip, _countof(tip)) == 7 &&
          wcscmp(tip, L"d\x0159\x0416\x4E2D\xD83D\xDE00") == 0);
    CHECK(SalU8ToWTruncate("Tandem Commander", tip, _countof(tip)) == 17 && wcscmp(tip, L"Tandem Commander") == 0);
    CHECK(SalU8ToWTruncate("", tip, _countof(tip)) == 1 && tip[0] == 0);

    // --- the cut at the tip's 128 units: 126 x + an emoji = 128 units; the pair does not fit
    //     whole into 127 units and is left out - never its high half alone
    std::string s(126, 'x');
    s += "\xF0\x9F\x98\x80";
    CHECK(SalU8ToWTruncate(s.c_str(), tip, _countof(tip)) == 127 && wcslen(tip) == 126 && tip[125] == L'x');
    // 125 x + the emoji = 127 units: fits whole
    std::string s2(125, 'x');
    s2 += "\xF0\x9F\x98\x80";
    CHECK(SalU8ToWTruncate(s2.c_str(), tip, _countof(tip)) == 128 && tip[125] == 0xD83D && tip[126] == 0xDE00 && tip[127] == 0);
    // a long Czech title: 200 x U+0159 (400 bytes) -> 127 whole characters (the ANSI tip cut at
    // 127 BYTES, in the middle of a character)
    std::string cz;
    for (int i = 0; i < 200; i++)
        cz += "\xC5\x99";
    CHECK(SalU8ToWTruncate(cz.c_str(), tip, _countof(tip)) == 128 && wcslen(tip) == 127 && tip[126] == 0x0159);

    // --- every buffer size: whole characters only, the unit behind the terminator never written
    static const char text[] = "a\xF0\x9F\x98\x80" "b\xE4\xB8\xAD"; // a, pair, b, U+4E2D = 5 units
    static const int whole[] = {0, 0, 1, 1, 3, 4, 5};                // units kept by bufSize
    for (int size = 1; size <= 6; size++)
    {
        for (int i = 0; i < _countof(buf); i++)
            buf[i] = L'#';
        CHECK(SalU8ToWTruncate(text, buf, size) == whole[size] + 1);
        CHECK((int)wcslen(buf) == whole[size] && buf[size] == L'#');
        CHECK(wcsncmp(buf, L"a\xD83D\xDE00" L"b\x4E2D", whole[size]) == 0);
    }

    // --- lone surrogates (WTF-8) are one character each; a lone high surrogate at the cut stays
    CHECK(SalU8ToWTruncate("ab\xED\xA0\x80", buf, 4) == 4 && wcscmp(buf, L"ab\xD800") == 0);
    CHECK(SalU8ToWTruncate("a\xED\xA0\x80" "c", buf, 3) == 3 && wcscmp(buf, L"a\xD800") == 0);

    // --- legacy code-page text (not UTF-8) is read in the system code page
    {
        static const char legacy[] = "dir\xE8\xF8"; // two bytes that are not UTF-8
        WCHAR expect[16];
        CHECK(MultiByteToWideChar(CP_ACP, 0, legacy, -1, expect, _countof(expect)) > 0);
        CHECK(SalU8ToWTruncate(legacy, buf, _countof(buf)) == (int)wcslen(expect) + 1 && wcscmp(buf, expect) == 0);
    }

    // --- arguments
    buf[0] = L'#';
    CHECK(SalU8ToWTruncate(NULL, buf, _countof(buf)) == 0 && buf[0] == 0);
    CHECK(SalU8ToWTruncate("x", NULL, 5) == 0);
    buf[0] = L'#';
    CHECK(SalU8ToWTruncate("x", buf, 0) == 0 && buf[0] == L'#');

    // --- share matching: the folder itself and what lies under it, at a component boundary
    int n = -1;
    CHECK(SalPathIsWithinOrdinalCI("C:\\foo", "C:\\foo", &n) && n == 6);
    CHECK(SalPathIsWithinOrdinalCI("C:\\Foo\\x", "c:\\fOO", &n) && n == 6);
    CHECK(SalPathIsWithinOrdinalCI("C:\\foo\\", "C:\\foo", &n) && n == 6);
    n = -1;
    CHECK(!SalPathIsWithinOrdinalCI("C:\\foobar", "C:\\foo", &n) && n == 0); // the old prefix test matched
    CHECK(!SalPathIsWithinOrdinalCI("C:\\foobar\\x", "C:\\foo", &n));
    CHECK(!SalPathIsWithinOrdinalCI("C:\\fo", "C:\\foo", &n));
    // a root share "C:\"
    CHECK(SalPathIsWithinOrdinalCI("C:\\", "C:\\", &n) && n == 3);
    CHECK(SalPathIsWithinOrdinalCI("c:\\x\\y", "C:\\", &n) && n == 3);
    CHECK(SalPathIsWithinOrdinalCI("C:", "C:\\", &n) && n == 2);
    CHECK(!SalPathIsWithinOrdinalCI("D:\\x", "C:\\", &n));
    CHECK(!SalPathIsWithinOrdinalCI("C", "C:\\", &n));
    // accented names: the identity of SalPathHasPrefixOrdinalCI (U+010C / U+010D)
    CHECK(SalPathIsWithinOrdinalCI("C:\\\xC4\x8C\\x", "c:\\\xC4\x8D", &n) && n == 5);
    CHECK(!SalPathIsWithinOrdinalCI("C:\\\xC4\x8C" "a\\x", "c:\\\xC4\x8D", &n));
    // the whole path: a share at 256 + 3 bytes and a path that equals it in its first 259 bytes
    // but continues the same component - the old code cut the path to 259 bytes and appended a
    // backslash, so this matched; a deep path under the share matches with the right byte count
    {
        std::string share = "C:\\" + std::string(256, 'a');
        CHECK(!SalPathIsWithinOrdinalCI((share + "xyz").c_str(), share.c_str(), &n));
        std::string deep = share;
        for (int i = 0; i < 40; i++)
            deep += "\\" + std::string(100, 'q'); // 4,299 bytes
        CHECK(SalPathIsWithinOrdinalCI(deep.c_str(), share.c_str(), &n) && n == (int)share.size() && deep[n] == '\\');
        std::string deepU = "C:\\\xC5\x99" + std::string(2000, 'z') + "\\last"; // U+0159 + a 2,000-byte component
        CHECK(SalPathIsWithinOrdinalCI(deepU.c_str(), "c:\\\xC5\x98", &n) == FALSE); // folder U+0158 does not hold U+0159zzz...
        CHECK(SalPathIsWithinOrdinalCI(deepU.c_str(), ("C:\\\xC5\x98" + std::string(2000, 'Z')).c_str(), &n) && n == 2005);
    }
    // --- review NIT 1: the folder named by the move-check messages is shortened visibly
    {
        char out[MAX_PATH];
        CHECK(!SalU8EllipsizeMiddle("C:\\short\\path", out, MAX_PATH) && strcmp(out, "C:\\short\\path") == 0);
        std::string fit(MAX_PATH - 1, 'a'); // exactly fits
        CHECK(!SalU8EllipsizeMiddle(fit.c_str(), out, MAX_PATH) && strcmp(out, fit.c_str()) == 0);
        std::string deep = "C:\\Temp\\deep\\S\\A";
        for (int i = 0; i < 1005; i++)
            deep += "\\d";
        CHECK(SalU8EllipsizeMiddle(deep.c_str(), out, MAX_PATH));
        std::string o = out;
        CHECK(o.size() <= MAX_PATH - 1 && o.find("...") != std::string::npos);
        CHECK(o.compare(0, 15, deep, 0, 15) == 0);                                          // the start stays
        CHECK(o.compare(o.size() - 20, 20, deep, deep.size() - 20, 20) == 0);                // the end stays
        // multi-byte characters on both cuts: U+0159 (2 bytes) and U+4E2D (3 bytes) only
        std::string acc;
        for (int i = 0; i < 300; i++)
            acc += (i % 2) ? "\xC5\x99" : "\xE4\xB8\xAD";
        for (int size = 8; size <= 40; size++)
        {
            char shortBuf[64];
            CHECK(SalU8EllipsizeMiddle(acc.c_str(), shortBuf, size));
            std::string r = shortBuf;
            CHECK((int)r.size() <= size - 1 && r.find("...") != std::string::npos);
            WCHAR w[64];
            CHECK(SalU8ToW(shortBuf, -1, w, 64) != 0); // whole characters only: valid UTF-8
        }
        CHECK(SalU8EllipsizeMiddle(acc.c_str(), out, 5) && strlen(out) <= 4 && SalU8ToW(out, -1, NULL, 0) != 0); // too small for "...": a whole-character cut
        CHECK(!SalU8EllipsizeMiddle(NULL, out, MAX_PATH) && out[0] == 0);
        CHECK(!SalU8EllipsizeMiddle("x", NULL, 5));
    }

    // nothing holds anything for an empty or NULL folder
    CHECK(!SalPathIsWithinOrdinalCI("C:\\x", "", &n) && n == 0);
    CHECK(!SalPathIsWithinOrdinalCI("C:\\x", NULL, &n));
    CHECK(!SalPathIsWithinOrdinalCI(NULL, "C:\\", NULL));
}

static void TestHeapString095()
{
    // the core's LowerCase table is built exactly like this (InitializeCase in str.cpp)
    unsigned char lower[256];
    for (int i = 0; i < 256; i++)
        lower[i] = (unsigned char)(UINT_PTR)CharLowerA((LPSTR)(UINT_PTR)i);
    // what StrICpy does (src/common/str.cpp), on a buffer that is big enough
    auto oldFold = [&lower](char* dest, const char* src)
    {
        while (*src != 0)
            *dest++ = (char)lower[(unsigned char)*src++];
        *dest = 0;
    };

    CSalHeapString s;
    CHECK(s.Get() == NULL && s.Size() == 0 && strcmp(s.Text(), "") == 0);
    CHECK(!s.Copy(NULL) && s.Get() == NULL);

    // --- content equals the old fold, for ASCII, UTF-8 and code-page bytes
    const char* samples[] = {
        "", "C:\\Temp\\Archive.ZIP", "D:\\M\xC5\xAFj disk\\\xC5\x98" "E\xC5\x98ICHA.Zip",
        "\\\\Server\\Share\\\xC8\xD8\xDD.7Z", "X:\\\xED\xA0\x80lone.ZIP", "A\x01\x7F\x80\xFF"};
    for (int i = 0; i < (int)(sizeof(samples) / sizeof(samples[0])); i++)
    {
        char expect[100];
        oldFold(expect, samples[i]);
        CHECK(s.Copy(samples[i], 0, lower));
        CHECK(strcmp(s.Get(), expect) == 0 && s.Size() == (int)strlen(samples[i]) + 1);
        CHECK(s.Copy(samples[i])); // no table: the bytes as they are
        CHECK(strcmp(s.Get(), samples[i]) == 0);
    }
    CHECK(s.Copy("AbC", 0, lower) && strcmp(s.Get(), "abc") == 0);

    // --- the reserve is really there: the name is completed as the callers do
    CHECK(s.Copy("C:\\A.ZIP", 5 + 1 + 6 + 2 + 32, lower));
    CHECK(s.Size() == 8 + 1 + 5 + 1 + 6 + 2 + 32);
    strcat(s.Get(), "\\");
    strcat(s.Get(), "Inner");
    strcat(s.Get(), "\\");
    strcat(s.Get(), "B.TXT");
    sprintf(s.Get() + strlen(s.Get()), ":0x%p", (void*)(UINT_PTR)-1);
    CHECK(strncmp(s.Get(), "c:\\a.zip\\Inner\\B.TXT:0x", 23) == 0 && (int)strlen(s.Get()) < s.Size());

    // --- every length around the old buffer sizes, and the longest path the program holds
    const int lens[] = {259, 260, 261, 519, 520, 619, 620, 829, 830, 4000, SAL_MAX_PATH_UTF8 - 1};
    for (int i = 0; i < (int)(sizeof(lens) / sizeof(lens[0])); i++)
    {
        std::string src(lens[i], 'Q');
        src[0] = 'C';
        src[lens[i] / 2] = (char)0xC5; // a UTF-8 pair in the middle
        src[lens[i] / 2 + 1] = (char)0x98;
        std::string expect(lens[i] + 1, 0);
        oldFold(&expect[0], src.c_str());
        CHECK(s.Copy(src.c_str(), 3, lower));
        CHECK(s.Size() == lens[i] + 4 && (int)strlen(s.Get()) == lens[i] && memcmp(s.Get(), expect.c_str(), lens[i] + 1) == 0);
        CHECK(s.Get()[0] == 'c' && s.Get()[1] == 'q');
    }

    // --- Printf: the size is exact, a long argument is not cut
    CHECK(s.Printf("Archive %s was changed.", "C:\\a.zip"));
    CHECK(strcmp(s.Text(), "Archive C:\\a.zip was changed.") == 0 && s.Size() == (int)strlen(s.Text()) + 1);
    {
        std::string arg(SAL_MAX_PATH_UTF8 - 1, 'x');
        CHECK(s.Printf("<%s>", arg.c_str()));
        CHECK((int)strlen(s.Text()) == SAL_MAX_PATH_UTF8 + 1 && s.Text()[0] == '<' &&
              s.Text()[SAL_MAX_PATH_UTF8] == '>' && s.Text()[SAL_MAX_PATH_UTF8 - 1] == 'x');
    }
    CHECK(s.Printf("%d%%", 5) && strcmp(s.Text(), "5%") == 0);
    CHECK(!s.Printf(NULL) && strcmp(s.Text(), "") == 0 && s.Get() == NULL);
    s.Free();
    CHECK(s.Get() == NULL && s.Size() == 0);
}

static BOOL ZipPwdHas094(const CSalZipPwdCandidates& c, int index, int kind, const char* bytes, int len)
{
    return index < c.Count && c.Forms[index].Kind == kind && c.Forms[index].Len == len &&
           memcmp(c.Forms[index].Bytes, bytes, len) == 0 && c.Forms[index].Bytes[len] == 0;
}

static void TestZipPassword094()
{
    const UINT cp = 1250, oem = 852;
    CSalZipPwdCandidates c;
    char buf[SALZIPPWD_FORM_BUF];
    const WCHAR* typedR = L"heslo-\x0159";
    const WCHAR* typedC = L"\x043F\x0430\x0440\x043E\x043B\x044C";

    // --- ASCII: representable, exactly one candidate, pack form = the text
    CHECK(SalZipPwdRepresentable(L"heslo123", cp) && SalZipPwdRepresentable(L"heslo123"));
    SalZipPwdCandidates(L"heslo123", &c, cp, oem);
    CHECK(c.Count == 1 && ZipPwdHas094(c, 0, SALZIPPWD_ACP, "heslo123", 8));
    SalZipPwdCandidates(L"heslo123", &c); // the machine's code pages
    CHECK(c.Count == 1 && ZipPwdHas094(c, 0, SALZIPPWD_ACP, "heslo123", 8));
    CHECK(SalZipPwdPackForm(L"heslo123", buf, sizeof(buf), FALSE, cp) == 8 && strcmp(buf, "heslo123") == 0);
    CHECK(SalZipPwdPackForm(L"heslo123", buf, sizeof(buf), TRUE, cp) == 8 && strcmp(buf, "heslo123") == 0);

    // --- inside the code page: acp, oem, utf8 - and no fourth form (the old read equals acp)
    CHECK(SalZipPwdRepresentable(typedR, cp));
    SalZipPwdCandidates(typedR, &c, cp, oem);
    CHECK(c.Count == 3);
    CHECK(ZipPwdHas094(c, 0, SALZIPPWD_ACP, "heslo-\xF8", 7));
    CHECK(ZipPwdHas094(c, 1, SALZIPPWD_OEM, "heslo-\xFD", 7));
    CHECK(ZipPwdHas094(c, 2, SALZIPPWD_UTF8, "heslo-\xC5\x99", 8));
    CHECK(SalZipPwdPackForm(typedR, buf, sizeof(buf), FALSE, cp) == 7 && strcmp(buf, "heslo-\xF8") == 0);
    CHECK(SalZipPwdPackForm(typedR, buf, sizeof(buf), TRUE, cp) == 7 && strcmp(buf, "heslo-\xF8") == 0);

    // --- outside the code page: utf8 first, then what the old code read ("??????")
    CHECK(!SalZipPwdRepresentable(typedC, cp));
    SalZipPwdCandidates(typedC, &c, cp, oem);
    CHECK(c.Count == 2);
    CHECK(ZipPwdHas094(c, 0, SALZIPPWD_UTF8, "\xD0\xBF\xD0\xB0\xD1\x80\xD0\xBE\xD0\xBB\xD1\x8C", 12));
    CHECK(ZipPwdHas094(c, 1, SALZIPPWD_OLDREAD, "??????", 6));
    // a new archive is keyed with UTF-8, never with the '?' form; a self-extractor keeps the old read
    CHECK(SalZipPwdPackForm(typedC, buf, sizeof(buf), FALSE, cp) == 12 &&
          memcmp(buf, "\xD0\xBF\xD0\xB0\xD1\x80\xD0\xBE\xD0\xBB\xD1\x8C", 13) == 0);
    CHECK(SalZipPwdPackForm(typedC, buf, sizeof(buf), TRUE, cp) == 6 && strcmp(buf, "??????") == 0);
    // another word of the same length: another pack form (SC-001)
    CHECK(SalZipPwdPackForm(L"\x0434\x0440\x0443\x0433\x043E\x0439", buf, sizeof(buf), FALSE, cp) == 12 &&
          memcmp(buf, "\xD0\xBF\xD0\xB0\xD1\x80\xD0\xBE\xD0\xBB\xD1\x8C", 12) != 0);
    // mixed: one character outside
    SalZipPwdCandidates(L"ab\x0416" L"cd", &c, cp, oem);
    CHECK(c.Count == 2 && ZipPwdHas094(c, 0, SALZIPPWD_UTF8, "ab\xD0\x96" "cd", 6) &&
          ZipPwdHas094(c, 1, SALZIPPWD_OLDREAD, "ab?cd", 5));

    // --- a character the code page only approximates is NOT representable; its
    //     old-read form is what GetDlgItemTextA gave (the best-fit letter)
    {
        const WCHAR* fit = L"p\xFF21"; // FULLWIDTH LATIN CAPITAL LETTER A
        char old[16];
        int on = WideCharToMultiByte(cp, 0, fit, 2, old, sizeof(old), NULL, NULL);
        CHECK(on == 2);
        CHECK(!SalZipPwdRepresentable(fit, cp));
        SalZipPwdCandidates(fit, &c, cp, oem);
        CHECK(c.Count == 2 && ZipPwdHas094(c, 0, SALZIPPWD_UTF8, "p\xEF\xBC\xA1", 4) &&
              ZipPwdHas094(c, 1, SALZIPPWD_OLDREAD, old, on));
        CHECK(on == 2 && old[1] == 'A'); // the best fit of code page 1250
        CHECK(SalZipPwdPackForm(fit, buf, sizeof(buf), FALSE, cp) == 4 && strcmp(buf, "p\xEF\xBC\xA1") == 0);
    }

    // --- duplicates: equal byte strings are tried once
    SalZipPwdCandidates(typedR, &c, cp, cp); // "OEM" = the same code page: two candidates
    CHECK(c.Count == 2 && ZipPwdHas094(c, 0, SALZIPPWD_ACP, "heslo-\xF8", 7) &&
          ZipPwdHas094(c, 1, SALZIPPWD_UTF8, "heslo-\xC5\x99", 8));
    // a machine whose code page is UTF-8: everything is representable, acp == utf8
    SalZipPwdCandidates(typedC, &c, CP_UTF8, CP_UTF8);
    CHECK(c.Count == 1 && ZipPwdHas094(c, 0, SALZIPPWD_ACP, "\xD0\xBF\xD0\xB0\xD1\x80\xD0\xBE\xD0\xBB\xD1\x8C", 12));
    CHECK(SalZipPwdRepresentable(typedC, CP_UTF8));

    // --- empty and NULL: one empty candidate
    SalZipPwdCandidates(L"", &c, cp, oem);
    CHECK(c.Count == 1 && c.Forms[0].Len == 0 && c.Forms[0].Bytes[0] == 0);
    SalZipPwdCandidates(NULL, &c, cp, oem);
    CHECK(c.Count == 1 && c.Forms[0].Len == 0);
    CHECK(SalZipPwdPackForm(L"", buf, sizeof(buf), FALSE, cp) == 0 && buf[0] == 0);

    // --- an unpaired surrogate: not representable, the UTF-8 form is WTF-8 (ED A0 80)
    SalZipPwdCandidates(L"a\xD800", &c, cp, oem);
    CHECK(!SalZipPwdRepresentable(L"a\xD800", cp));
    CHECK(c.Count >= 1 && ZipPwdHas094(c, 0, SALZIPPWD_UTF8, "a\xED\xA0\x80", 4));
    CHECK(SalZipPwdPackForm(L"a\xD800", buf, sizeof(buf), FALSE, cp) == 4 && strcmp(buf, "a\xED\xA0\x80") == 0);
    // a pair is one 4-byte sequence
    CHECK(SalZipPwdUtf8(L"\xD83D\xDCC1", buf, sizeof(buf)) == 4 && strcmp(buf, "\xF0\x9F\x93\x81") == 0);
    // valid text: the same bytes Windows gives
    {
        char win[64];
        int wn = WideCharToMultiByte(CP_UTF8, 0, L"heslo-\x0159\x65E5\xD83D\xDCC1", -1, win, sizeof(win), NULL, NULL);
        CHECK(SalZipPwdUtf8(L"heslo-\x0159\x65E5\xD83D\xDCC1", buf, sizeof(buf)) == wn - 1 && strcmp(buf, win) == 0);
    }

    // --- lengths: all 255 characters are used; the old read had 254
    {
        WCHAR w[SALZIPPWD_MAX_CHARS + 2];
        int i;
        for (i = 0; i < SALZIPPWD_MAX_CHARS; i++)
            w[i] = L'a';
        w[SALZIPPWD_MAX_CHARS] = 0;
        CHECK(SalZipPwdPackForm(w, buf, sizeof(buf), FALSE, cp) == 255 && strlen(buf) == 255);
        CHECK(SalZipPwdPackForm(w, buf, sizeof(buf), TRUE, cp) == 254); // the stub reads 254
        SalZipPwdCandidates(w, &c, cp, oem);
        // 255 x 'a', and the 254 an archive of an earlier version is keyed with
        CHECK(c.Count == 2 && c.Forms[0].Kind == SALZIPPWD_ACP && c.Forms[0].Len == 255 &&
              c.Forms[1].Kind == SALZIPPWD_OLDREAD && c.Forms[1].Len == 254);
        w[254] = 0;
        SalZipPwdCandidates(w, &c, cp, oem);
        CHECK(c.Count == 1 && c.Forms[0].Len == 254);
        // 255 three-byte characters: 765 bytes of UTF-8 fit the form buffer
        for (i = 0; i < SALZIPPWD_MAX_CHARS; i++)
            w[i] = 0x65E5;
        w[SALZIPPWD_MAX_CHARS] = 0;
        CHECK(SalZipPwdUtf8(w, buf, sizeof(buf)) == 765 && buf[765] == 0);
        SalZipPwdCandidates(w, &c, cp, oem);
        CHECK(c.Count == 2 && c.Forms[0].Kind == SALZIPPWD_UTF8 && c.Forms[0].Len == 765 &&
              c.Forms[1].Kind == SALZIPPWD_OLDREAD && c.Forms[1].Len == 254 && c.Forms[1].Bytes[0] == '?');
        // text longer than the field accepts is cut to the field's limit
        w[SALZIPPWD_MAX_CHARS] = L'x';
        w[SALZIPPWD_MAX_CHARS + 1] = 0;
        CHECK(SalZipPwdUtf8(w, buf, sizeof(buf)) == 765);
        // the AES boundary (128 bytes) is a matter of the form: 64 two-byte letters
        // are 64 bytes in the code page and 128 in UTF-8; 65 are 65 and 130
        for (i = 0; i < 65; i++)
            w[i] = 0x0159;
        w[64] = 0;
        SalZipPwdCandidates(w, &c, cp, oem);
        CHECK(c.Count == 3 && c.Forms[0].Len == 64 && c.Forms[1].Len == 64 && c.Forms[2].Len == 128);
        CHECK(SalZipPwdPackForm(w, buf, sizeof(buf), FALSE, cp) == 64);
        w[64] = 0x0159;
        w[65] = 0;
        SalZipPwdCandidates(w, &c, cp, oem);
        CHECK(c.Forms[0].Len == 65 && c.Forms[2].Len == 130);
        SecureZeroMemory(w, sizeof(w));
    }

    // --- arguments
    buf[0] = 'x';
    CHECK(SalZipPwdAcp(typedR, buf, 7, cp) == -1 && buf[0] == 0); // does not fit: nothing, never a cut password
    CHECK(SalZipPwdAcp(typedR, buf, 8, cp) == 7);
    CHECK(SalZipPwdUtf8(typedR, buf, 8) == -1 && buf[0] == 0);
    CHECK(SalZipPwdUtf8(typedR, buf, 9) == 8);
    CHECK(SalZipPwdAcp(typedR, NULL, 8, cp) == -1 && SalZipPwdUtf8(typedR, buf, 0) == -1);
    CHECK(SalZipPwdAcp(typedC, buf, sizeof(buf), cp) == -1);

    // --- wipe
    SalZipPwdCandidates(typedR, &c, cp, oem);
    SalZipPwdWipe(&c);
    CHECK(c.Count == 0 && c.Forms[0].Len == 0 && c.Forms[0].Bytes[0] == 0 && c.Forms[2].Bytes[6] == 0);

    // --- the machine's own code pages: the forms are what the old code produced
    {
        char acp[64], old[64], oemb[64];
        BOOL used = FALSE;
        int an;
        if (GetACP() == CP_UTF8)
            an = WideCharToMultiByte(CP_UTF8, 0, typedR, -1, acp, sizeof(acp), NULL, NULL);
        else
            an = WideCharToMultiByte(CP_ACP, WC_NO_BEST_FIT_CHARS, typedR, -1, acp, sizeof(acp), NULL, &used);
        WideCharToMultiByte(CP_ACP, 0, typedR, -1, old, sizeof(old), NULL, NULL); // GetDlgItemTextA
        CHECK(SalZipPwdOldRead(typedR, buf, sizeof(buf)) == (int)strlen(old) && strcmp(buf, old) == 0);
        CHECK(SalZipPwdRepresentable(typedR) == (an > 0 && !used));
        if (an > 0 && !used)
        {
            CharToOemA(acp, oemb); // what the old InitKeys retried with
            SalZipPwdCandidates(typedR, &c);
            CHECK(c.Count >= 1 && ZipPwdHas094(c, 0, SALZIPPWD_ACP, acp, an - 1));
            if (strcmp(oemb, acp) != 0)
                CHECK(ZipPwdHas094(c, 1, SALZIPPWD_OEM, oemb, (int)strlen(oemb)));
        }
        if (GetACP() == 1250 && GetOEMCP() == 852)
        {
            SalZipPwdCandidates(typedR, &c);
            CHECK(c.Count == 3 && ZipPwdHas094(c, 0, SALZIPPWD_ACP, "heslo-\xF8", 7) &&
                  ZipPwdHas094(c, 1, SALZIPPWD_OEM, "heslo-\xFD", 7) &&
                  ZipPwdHas094(c, 2, SALZIPPWD_UTF8, "heslo-\xC5\x99", 8));
            SalZipPwdCandidates(typedC, &c);
            CHECK(c.Count == 2 && c.Forms[0].Kind == SALZIPPWD_UTF8 && ZipPwdHas094(c, 1, SALZIPPWD_OLDREAD, "??????", 6));
        }
    }
    SalZipPwdWipe(&c);
    SecureZeroMemory(buf, sizeof(buf));
}

static void TestNameIdentity092()
{
    // --- (1) ASCII: equality identical to the old byte fold; the three-way sign identical
    //         too, except where a character between 'Z' and 'a' meets a letter (documented:
    //         the new order folds to UPPER case, as CompareStringOrdinal does)
    static const char* const ascii[] = {"", "a", "A", "ab", "AB", "aB", "abc", "abd", "b", "Z", "z", "0", "9",
                                        "a.txt", "A.TXT", "a_b", "a-b", "a b", "readme", "README.md", "file[1]",
                                        "file_1", "~tmp", "x^y", "x`y", "{", "@"};
    for (int i = 0; i < _countof(ascii); i++)
    {
        for (int j = 0; j < _countof(ascii); j++)
        {
            int ref = RefAsciiLowerCmp092(ascii[i], ascii[j]);
            int got = SalNameCompareOrdinalCI(ascii[i], -1, ascii[j], -1);
            CHECK((got == 0) == (ref == 0));
            CHECK(SalNameEqualOrdinalCI(ascii[i], -1, ascii[j], -1) == (ref == 0));
            // equals what the OS says for the same strings
            WCHAR wi[64], wj[64];
            int ui = MultiByteToWideChar(CP_ACP, 0, ascii[i], -1, wi, 64) - 1;
            int uj = MultiByteToWideChar(CP_ACP, 0, ascii[j], -1, wj, 64) - 1;
            int os = (ui == 0 || uj == 0) ? (ui == uj ? 0 : (ui < uj ? -1 : 1))
                                          : CompareStringOrdinal(wi, ui, wj, uj, TRUE) - CSTR_EQUAL;
            CHECK(Sign092(got) == Sign092(os));
        }
    }
    // the documented fold direction: '_' (0x5F) sorts AFTER letters (upper-case fold), where the
    // old lower-case fold put it before them
    CHECK(SalNameCompareOrdinalCI("_", -1, "a", -1) > 0);
    CHECK(RefAsciiLowerCmp092("_", "a") < 0);
    // explicit lengths, NULL
    CHECK(SalNameEqualOrdinalCI("abcX", 3, "ABCY", 3));
    CHECK(!SalNameEqualOrdinalCI("abcX", 4, "ABCY", 4));
    CHECK(SalNameCompareOrdinalCI("abc", 2, "abd", 2) == 0);
    CHECK(SalNameCompareOrdinalCI(NULL, -1, "", -1) == 0);
    CHECK(SalNameCompareOrdinalCI(NULL, -1, "a", -1) < 0);
    CHECK(SalNameEqualOrdinalCI(NULL, -1, NULL, -1));

    // --- (2) the motivating pairs
    CHECK(Eq092(L"\x010C.txt", L"\x010D.txt"));  // C-caron: upper / lower
    CHECK(!Eq092(L"\x0125", L"\x0139"));         // h-circumflex vs L-acute: the old fold confused them on CP1250
    CHECK(!Eq092(L"\x010C", L"\x011C"));         // C-caron vs G-circumflex
    CHECK(Eq092(L"\x010Cl\x00E1nek.TXT", L"\x010Dl\x00C1NEK.txt"));
    // every letter with a simple one-to-one case pair in these blocks: upper == lower
    {
        int pairs = 0;
        static const int ranges[][2] = {{0x00C0, 0x00FF}, {0x0100, 0x017F}, {0x0370, 0x03FF}, {0x0400, 0x04FF}};
        for (int r = 0; r < _countof(ranges); r++)
        {
            for (int cp = ranges[r][0]; cp <= ranges[r][1]; cp++)
            {
                WCHAR lo[4] = {(WCHAR)cp, L'x', 0};
                WCHAR up[4] = {(WCHAR)cp, L'x', 0};
                CharUpperBuffW(up, 1);
                if (up[0] == lo[0])
                    continue; // not a lower-case letter with an upper-case partner
                WCHAR back[2] = {up[0], 0};
                CharLowerBuffW(back, 1);
                if (back[0] != lo[0])
                    continue; // not a one-to-one pair (e.g. U+00B5, U+017F): the OS decides those
                pairs++;
                std::string a = U8of092(lo), b = U8of092(up);
                CHECK(SalNameEqualOrdinalCI(a.c_str(), -1, b.c_str(), -1));
            }
        }
        CHECK(pairs > 250); // the loop really tested the blocks
    }
    // different letters stay different, whatever their UTF-8 bytes fold to in a code page
    {
        int checked = 0;
        for (int a = 0x0100; a < 0x0180; a++)
        {
            for (int b = a + 1; b < 0x0180; b++)
            {
                WCHAR wa[2] = {(WCHAR)a, 0}, wb[2] = {(WCHAR)b, 0};
                BOOL osEqual = CompareStringOrdinal(wa, 1, wb, 1, TRUE) == CSTR_EQUAL;
                std::string ua = U8of092(wa), ub = U8of092(wb);
                CHECK(SalNameEqualOrdinalCI(ua.c_str(), -1, ub.c_str(), -1) == osEqual);
                checked++;
            }
        }
        CHECK(checked == 128 * 127 / 2);
    }

    // --- (3) equal for a linguistic comparison, DIFFERENT for the file system
    CHECK(!Eq092(L"strasse", L"stra\x00DF" L"e"));    // sharp s
    CHECK(!Eq092(L"ab", L"a\x00AD" L"b"));            // soft hyphen
    CHECK(!Eq092(L"ab", L"a\x200D" L"b"));            // zero width joiner
    CHECK(!Eq092(L"\xFF21", L"A"));                   // full-width A
    CHECK(!Eq092(L"\x010D", L"c\x030C"));             // NFC vs NFD
    CHECK(!Eq092(L"\x03C3", L"\x03C2"));              // sigma vs final sigma
    CHECK(!Eq092(L"\x212A", L"k"));                   // Kelvin sign
    CHECK(!Eq092(L"a\x0378", L"a\x0379"));            // two unassigned code points
    // ... each of which the linguistic helper does call equal (that is why it is the wrong one)
    {
        std::string a = U8of092(L"strasse"), b = U8of092(L"stra\x00DF" L"e");
        CHECK(SalNameEqualCI(a.c_str(), -1, b.c_str(), -1));
    }

    // --- (4) WTF-8: lone surrogates are characters like any other
    CHECK(Eq092(L"Lone\xD800.TXT", L"lone\xD800.txt"));
    CHECK(!Eq092(L"lone\xD800.txt", L"lone\xD801.txt"));
    CHECK(!Eq092(L"a\xD800", L"a"));
    CHECK(Eq092(L"\xD83D\xDE00.png", L"\xD83D\xDE00.PNG")); // a real pair (emoji)

    // --- (5) text that is not WTF-8: exactly the legacy code-page fold
    {
        static const char* const legacy[] = {"\xC8.txt", "\xE8.txt", "\xE1" "bc", "\xC1" "BC", "abc\xFF", "\x80", "a\xBF" "b"};
        BYTE lower[256];
        for (int i = 0; i < 256; i++)
            lower[i] = (BYTE)(UINT_PTR)CharLowerA((LPSTR)(UINT_PTR)i);
        for (int i = 0; i < _countof(legacy); i++)
        {
            for (int j = 0; j < _countof(legacy); j++)
            {
                const char* a = legacy[i];
                const char* b = legacy[j];
                int la = (int)strlen(a), lb = (int)strlen(b), l = la < lb ? la : lb, ref = 0;
                for (int k = 0; k < l && ref == 0; k++)
                    ref = (int)lower[(BYTE)a[k]] - (int)lower[(BYTE)b[k]];
                if (ref == 0)
                    ref = la - lb;
                CHECK(Sign092(SalNameCompareOrdinalCI(a, -1, b, -1)) == Sign092(ref));
            }
        }
        // one valid and one invalid string: also the legacy fold (never a crash, never "equal" by accident)
        CHECK(SalNameCompareOrdinalCI("\xC4\x8D", -1, "\xE8", -1) != 0);
    }

    // --- (6) long names take the heap path and give the same answers
    {
        std::string a(3000, 'a'), b(3000, 'A');
        a += U8of092(L"\x010D");
        b += U8of092(L"\x010C");
        CHECK(SalNameEqualOrdinalCI(a.c_str(), -1, b.c_str(), -1));
        b += "x";
        CHECK(SalNameCompareOrdinalCI(a.c_str(), -1, b.c_str(), -1) < 0);
    }

    // --- (7) paths: IsTheSamePath's backslash rules with the new identity
    {
        std::string p1 = U8of092(L"C:\\Dokumenty\\\x010Cl\x00E1nek");
        std::string p2 = U8of092(L"c:\\dokumenty\\\x010Dl\x00C1NEK");
        CHECK(SalPathEqualOrdinalCI(p1.c_str(), p2.c_str()));
        CHECK(SalPathEqualOrdinalCI((p1 + "\\").c_str(), p2.c_str()));
        CHECK(SalPathEqualOrdinalCI(p1.c_str(), (p2 + "\\").c_str()));
        CHECK(SalPathEqualOrdinalCI((p1 + "\\").c_str(), (p2 + "\\").c_str()));
        CHECK(!SalPathEqualOrdinalCI((p1 + "\\\\").c_str(), p2.c_str()));
        CHECK(SalPathEqualOrdinalCI((p1 + "\\\\").c_str(), (p2 + "\\").c_str())); // as the legacy function
        CHECK(SalPathEqualOrdinalCI("\\a\\b", "a\\b"));                           // one leading backslash is skipped
        CHECK(SalPathEqualOrdinalCI("", "\\"));
        CHECK(SalPathEqualOrdinalCI("", ""));
        CHECK(SalPathEqualOrdinalCI(NULL, ""));
        CHECK(!SalPathEqualOrdinalCI("a", "ab"));
        std::string h = U8of092(L"C:\\\x0125"), l = U8of092(L"C:\\\x0139");
        CHECK(!SalPathEqualOrdinalCI(h.c_str(), l.c_str())); // "C:\ĥ" is not "C:\Ĺ"
        CHECK(SalPathEqualOrdinalCI("\\\\server\\share\\DIR", "\\\\SERVER\\Share\\dir\\"));
    }

    // --- (8) prefixes: the count is measured on the path, the cut never splits a character
    {
        int n = -1;
        CHECK(SalPathHasPrefixOrdinalCI("C:\\Dir\\file", "c:\\dir", -1, &n) && n == 6);
        CHECK(SalPathHasPrefixOrdinalCI("C:\\Dir", "c:\\dir", -1, &n) && n == 6);
        CHECK(!SalPathHasPrefixOrdinalCI("C:\\Di", "c:\\dir", -1, &n) && n == 0);
        CHECK(SalPathHasPrefixOrdinalCI("anything", "", -1, &n) && n == 0);
        CHECK(SalPathHasPrefixOrdinalCI("anything", "ANYx", 3, &n) && n == 3);
        CHECK(SalPathHasPrefixOrdinalCI("x", NULL, -1, NULL));
        std::string path = U8of092(L"C:\\\x010Cl\x00E1nek\\sub");
        std::string pre = U8of092(L"c:\\\x010Dl\x00C1NEK");
        CHECK(SalPathHasPrefixOrdinalCI(path.c_str(), pre.c_str(), -1, &n) && n == (int)pre.size() && path[n] == '\\');
        // a prefix that ends in the middle of a character of the path is not a prefix
        std::string cut = path.substr(0, 4); // "C:\" + the first byte of U+010C
        CHECK(!SalPathHasPrefixOrdinalCI(path.c_str(), cut.c_str(), -1, &n));
        // nor one that ends between the halves of a surrogate pair
        std::string emoji = U8of092(L"C:\\\xD83D\xDE00\\x");
        std::string half = U8of092(L"C:\\\xD83D");
        CHECK(!SalPathHasPrefixOrdinalCI(emoji.c_str(), half.c_str(), -1, &n));
        std::string whole = U8of092(L"c:\\\xD83D\xDE00");
        CHECK(SalPathHasPrefixOrdinalCI(emoji.c_str(), whole.c_str(), -1, &n) && emoji[n] == '\\');
        // different letters are not a prefix, whatever the code page fold says
        std::string ph = U8of092(L"C:\\\x0125\\x"), pl = U8of092(L"C:\\\x0139");
        CHECK(!SalPathHasPrefixOrdinalCI(ph.c_str(), pl.c_str(), -1, &n));
        // every pair the OS calls equal although the UTF-8 lengths differ: the count follows the path
        {
            int found = 0;
            for (int a = 0x80; a < 0x2000; a++)
            {
                for (int b = 'A'; b <= 'z'; b++)
                {
                    WCHAR wa[2] = {(WCHAR)a, 0}, wb[2] = {(WCHAR)b, 0};
                    if (CompareStringOrdinal(wa, 1, wb, 1, TRUE) != CSTR_EQUAL)
                        continue;
                    found++;
                    std::string pathU = "C:\\" + U8of092(wa) + "\\f";
                    std::string preU = std::string("C:\\") + (char)b;
                    int cnt = -1;
                    CHECK(SalPathHasPrefixOrdinalCI(pathU.c_str(), preU.c_str(), -1, &cnt));
                    CHECK(cnt > 0 && pathU[cnt] == '\\');
                }
            }
            printf("  name identity: %d non-ASCII characters equal an ASCII letter for the OS\n", found);
            // the comparison relies on it: an ASCII character is below every other and equals none
            CHECK(found == 0);
        }
        // legacy text: the old byte answer
        CHECK(SalPathHasPrefixOrdinalCI("\xC8" "dir\\x", "\xE8" "DIR", -1, &n) ==
              (CharLowerA((LPSTR)(UINT_PTR)0xC8) == CharLowerA((LPSTR)(UINT_PTR)0xE8)));
    }

    // --- (8b) case pairs whose UTF-8 lengths differ (review of S2): the whole BMP is searched
    //          for them; they are the same name, and a prefix made of one covers the bytes of
    //          the other - so no caller may test byte lengths before comparing
    {
        int pairsDifferentLength = 0;
        for (int cp = 0x80; cp < 0xD800; cp++)
        {
            WCHAR up[2] = {(WCHAR)cp, 0};
            CharUpperBuffW(up, 1);
            if (up[0] == (WCHAR)cp)
                continue;
            WCHAR lo[2] = {(WCHAR)cp, 0};
            if (CompareStringOrdinal(lo, 1, up, 1, TRUE) != CSTR_EQUAL)
                continue; // the OS table, not CharUpper, is the rule
            std::string a = U8of092(lo), b = U8of092(up);
            if (a.size() == b.size())
                continue;
            pairsDifferentLength++;
            CHECK(SalNameEqualOrdinalCI(a.c_str(), -1, b.c_str(), -1));
            std::string path = "C:\\" + a + "\\f";
            std::string pre = "c:\\" + b;
            int n = -1;
            CHECK(SalPathHasPrefixOrdinalCI(path.c_str(), pre.c_str(), -1, &n));
            CHECK(n == (int)(3 + a.size()) && path[n] == '\\'); // the count of the PATH, not of the prefix
        }
        printf("  name identity: %d case pairs differ in UTF-8 length\n", pairsDifferentLength);
        CHECK(pairsDifferentLength > 0);
        // two lone surrogates side by side (a non-canonical spelling of a pair): the count still
        // follows the path's own bytes
        int n = -1;
        CHECK(SalPathHasPrefixOrdinalCI("\xED\xA0\xBD\xED\xB8\x80\\x", "\xED\xA0\xBD\xED\xB8\x80", -1, &n) && n == 6);
    }
    // the early exits of the yes/no helper do not change any answer
    CHECK(!SalNameEqualOrdinalCI("", -1, "a", -1) && !SalNameEqualOrdinalCI("a", -1, "", -1));
    CHECK(SalNameEqualOrdinalCI("", -1, "", -1) && SalNameEqualOrdinalCI("x", 0, "y", 0));
    CHECK(!SalNameEqualOrdinalCI("abc", -1, "abd", -1) && SalNameEqualOrdinalCI("aBc", -1, "AbC", -1));
    CHECK(SalNameCompareOrdinalCI("a_", -1, "aB", -1) > 0);                 // '_' against a letter, all ASCII: upper-case fold
    CHECK(SalNameCompareOrdinalCI("a_\xC4\x8D", -1, "aB\xC4\x8D", -1) > 0); // the same with a valid non-ASCII tail
    CHECK(SalNameCompareOrdinalCI("a_\xE8", -1, "aB\xE8", -1) > 0);         // legacy text: the leading ASCII part folds the same way
    CHECK(SalNameCompareOrdinalCI("ab\xC4\x8D", -1, "aB", -1) > 0);         // longer, non-ASCII tail
    CHECK(SalNameCompareOrdinalCI("aB", -1, "ab\xC4\x8D", -1) < 0);

    // --- (9) a consistent order: antisymmetric and transitive over a mixed set
    {
        std::vector<std::string> names;
        static const WCHAR* const seeds[] = {L"", L"a", L"B", L"ab", L"a-c", L"a_c", L"ab\x00E9", L"AB\x00C9", L"\x010D",
                                             L"\x010C", L"\x010Dz", L"z", L"Z", L"_", L"\x00E9", L"\x4E2D", L"\xD800",
                                             L"\xD83D\xDE00", L"a\x0301", L"\x00E1", L"A\x0301", L"1", L"10", L"2", L"~",
                                             L"\xFF21", L"stra\x00DF" L"e", L"strasse", L"\x03C3", L"\x03A3", L"\x0436", L"\x0416"};
        for (int i = 0; i < _countof(seeds); i++)
            names.push_back(U8of092(seeds[i]));
        // text that is not UTF-8, also next to ASCII and next to valid names (the mix that an
        // "either invalid -> legacy fold" rule ordered in a cycle)
        names.push_back("\xE8");
        names.push_back("\xC8");
        names.push_back("a\xE8");
        names.push_back("a_\xE8");
        names.push_back("aB\xE8");
        names.push_back("\xC4");
        names.push_back("\xC4\x8D\xFF");
        names.push_back("ab\xFF");
        int n = (int)names.size();
        int violations = 0;
        for (int i = 0; i < n; i++)
        {
            for (int j = 0; j < n; j++)
            {
                int ij = Sign092(SalNameCompareOrdinalCI(names[i].c_str(), -1, names[j].c_str(), -1));
                int ji = Sign092(SalNameCompareOrdinalCI(names[j].c_str(), -1, names[i].c_str(), -1));
                if (ij != -ji)
                    violations++;
                for (int k = 0; k < n; k++) // a total order over everything, legacy text included
                {
                    int jk = Sign092(SalNameCompareOrdinalCI(names[j].c_str(), -1, names[k].c_str(), -1));
                    int ik = Sign092(SalNameCompareOrdinalCI(names[i].c_str(), -1, names[k].c_str(), -1));
                    if (ij <= 0 && jk <= 0 && ik > 0)
                        violations++;
                    if (ij == 0 && jk == 0 && ik != 0)
                        violations++;
                }
            }
        }
        CHECK(violations == 0);
        // sort with it, then find every element again by binary search with the same comparison
        std::vector<std::string> sorted = names;
        std::sort(sorted.begin(), sorted.end(), [](const std::string& x, const std::string& y)
                  { return SalNameCompareOrdinalCI(x.c_str(), -1, y.c_str(), -1) < 0; });
        int notFound = 0;
        for (size_t i = 0; i < sorted.size(); i++)
        {
            int lo = 0, hi = (int)sorted.size() - 1;
            BOOL found = FALSE;
            while (lo <= hi && !found)
            {
                int mid = (lo + hi) / 2;
                int c = SalNameCompareOrdinalCI(sorted[i].c_str(), -1, sorted[mid].c_str(), -1);
                if (c == 0)
                    found = TRUE;
                else if (c < 0)
                    hi = mid - 1;
                else
                    lo = mid + 1;
            }
            if (!found)
                notFound++;
        }
        CHECK(notFound == 0);
    }

    // --- (10) the file system agrees (real NTFS in the temp directory)
    {
        WCHAR tmp[MAX_PATH];
        WCHAR dir[MAX_PATH];
        if (GetTempPathW(MAX_PATH, tmp) == 0 || swprintf_s(dir, L"%ssal092_%u", tmp, GetCurrentProcessId()) < 0 ||
            !CreateDirectoryW(dir, NULL))
        {
            printf("skipping the NTFS part of TestNameIdentity092 (no temp directory)\n");
            return;
        }
        static const WCHAR* const pairs[][2] = {
            {L"\x010C.txt", L"\x010D.txt"}, {L"\x0125.txt", L"\x0139.txt"}, {L"strasse.txt", L"stra\x00DF" L"e.txt"},
            {L"\x010D" L"1.txt", L"c\x030C" L"1.txt"}, {L"\x0416.txt", L"\x0436.txt"}, {L"\x03A3.txt", L"\x03C3.txt"},
            {L"\x03C3" L"2.txt", L"\x03C2" L"2.txt"}, {L"A3.txt", L"a3.txt"}, {L"\x212A.txt", L"k.txt"},
            {L"\xFF21" L"4.txt", L"A4.txt"}, {L"\x00DC.txt", L"\x00FC.txt"}, {L"\x0130" L"5.txt", L"i5.txt"},
            {L"\x0131" L"6.txt", L"I6.txt"}, {L"\x017F" L"7.txt", L"S7.txt"}, {L"\x01C5" L"8.txt", L"\x01C6" L"8.txt"},
            {L"\x01C4" L"9.txt", L"\x01C6" L"9.txt"}};
        int disagreements = 0;
        for (int i = 0; i < _countof(pairs); i++)
        {
            WCHAR f1[MAX_PATH], f2[MAX_PATH];
            swprintf_s(f1, L"%s\\%s", dir, pairs[i][0]);
            swprintf_s(f2, L"%s\\%s", dir, pairs[i][1]);
            HANDLE h = CreateFileW(f1, GENERIC_WRITE, 0, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
            if (h == INVALID_HANDLE_VALUE)
                continue;
            CloseHandle(h);
            // is the second name the same file for the file system?
            HANDLE h2 = CreateFileW(f2, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL,
                                    OPEN_EXISTING, 0, NULL);
            BOOL fsSame = h2 != INVALID_HANDLE_VALUE;
            if (fsSame)
                CloseHandle(h2);
            std::string a = U8of092(pairs[i][0]), b = U8of092(pairs[i][1]);
            BOOL ours = SalNameEqualOrdinalCI(a.c_str(), -1, b.c_str(), -1);
            if (ours != fsSame)
            {
                disagreements++;
                printf("  name identity: pair %d - file system says %s, helper says %s\n", i,
                       fsSame ? "same" : "different", ours ? "same" : "different");
            }
            DeleteFileW(f1);
        }
        RemoveDirectoryW(dir);
        CHECK(disagreements == 0);
    }
}

// feature 102: the pure parts of the fcremote.exe channel (src/plugins/filecomp/fcproto.h)
static BOOL ArgsAre102(const WCHAR* cmdLine, int maxarg, int count, const WCHAR* const* want)
{
    WCHAR* argv[8];
    int argc = -1;
    BOOL ok = FcSplitArgsW(cmdLine, argv, argc, maxarg);
    BOOL same = ok && argc == count;
    int i;
    for (i = 0; same && i < count; i++)
        same = wcscmp(argv[i], want[i]) == 0;
    if (ok)
        FcFreeArgsW(argv, argc);
    return same && argc == 0;
}

static BOOL AbsIs102(const WCHAR* arg, const WCHAR* curDir, const WCHAR* driveDir, const WCHAR* want)
{
    WCHAR* got = FcAbsoluteNameW(arg, curDir, driveDir);
    BOOL ok = want == NULL ? got == NULL : (got != NULL && wcscmp(got, want) == 0);
    if (got != NULL)
        HeapFree(GetProcessHeap(), 0, got);
    return ok;
}

static void TestFcRemote102()
{
    // --- the argument split keeps version 1's rules, on UTF-16
    const WCHAR* w1[] = {L"C:\\p\\fc.exe", L"-w", L"C:\\a b\\x.txt", L"y.txt"};
    CHECK(ArgsAre102(L"\"C:\\p\\fc.exe\" -w \"C:\\a b\\x.txt\" y.txt", 4, 4, w1));
    const WCHAR* w2[] = {L"fc.exe", L"ab cd", L"e"}; // a quote inside an argument, quotes removed
    CHECK(ArgsAre102(L"fc.exe a\"b c\"d e", 4, 3, w2));
    const WCHAR* w3[] = {L"fc.exe", L"unterminated x"}; // version 1 read past the end here
    CHECK(ArgsAre102(L"fc.exe \"unterminated x", 4, 2, w3));
    const WCHAR* w4[] = {L"fc.exe", L"C:\\dir\\", L"b"}; // no escape character
    CHECK(ArgsAre102(L"fc.exe \"C:\\dir\\\" b", 4, 3, w4));
    const WCHAR* w5[] = {L"fc.exe", L"a", L"b"}; // runs of spaces and tabs
    CHECK(ArgsAre102(L"  fc.exe   a\tb  ", 4, 3, w5));
    const WCHAR* w6[] = {L"fc.exe", L""}; // an empty quoted argument
    CHECK(ArgsAre102(L"fc.exe \"\"", 4, 2, w6));
    CHECK(ArgsAre102(L"", 4, 0, NULL));
    // names outside the code page stay exact; a fullwidth quote (U+FF02) is an ordinary
    // character (the code-page command line turned it into '"')
    const WCHAR* w7[] = {L"fc.exe", L"C:\\x\\f\x65E5.txt", L"C:\\a\xFF02x\xFF02.txt", L"lone\xD800.txt"};
    CHECK(ArgsAre102(L"fc.exe \"C:\\x\\f\x65E5.txt\" C:\\a\xFF02x\xFF02.txt \"lone\xD800.txt\"", 4, 4, w7));
    // too many arguments: an error, nothing left allocated
    {
        WCHAR* argv[4];
        int argc = -1;
        CHECK(!FcSplitArgsW(L"fc.exe a b c d", argv, argc, 4) && argc == 0);
    }

    // --- the absolute name, every component kept as typed (review: GetFullPathNameW dropped the
    //     trailing dots and spaces of EVERY component, "dir.\b.txt" named "dir\b.txt")
    CHECK(AbsIs102(L"C:\\t\\dir.\\b.txt", L"C:\\cur", NULL, L"C:\\t\\dir.\\b.txt"));
    CHECK(AbsIs102(L"C:\\t\\dir \\b.txt ", L"C:\\cur", NULL, L"C:\\t\\dir \\b.txt "));
    CHECK(AbsIs102(L"a.", L"C:\\cur", NULL, L"C:\\cur\\a."));
    CHECK(AbsIs102(L"L.\\f.txt", L"C:\\cur", NULL, L"C:\\cur\\L.\\f.txt"));
    CHECK(AbsIs102(L"x/y.\\z", L"C:\\cur", NULL, L"C:\\cur\\x\\y.\\z"));                       // '/' is a separator
    CHECK(AbsIs102(L"..\\b.txt", L"C:\\cur\\sub", NULL, L"C:\\cur\\b.txt"));                   // ".." resolved
    CHECK(AbsIs102(L".\\.\\b.txt", L"C:\\cur", NULL, L"C:\\cur\\b.txt"));                      // "." dropped
    CHECK(AbsIs102(L"..\\..\\..\\b.txt", L"C:\\cur", NULL, L"C:\\b.txt"));                     // never above the root
    CHECK(AbsIs102(L"C:\\a\\\\b", L"C:\\cur", NULL, L"C:\\a\\b"));                             // empty component
    CHECK(AbsIs102(L"x\\...\\y", L"C:\\cur", NULL, L"C:\\cur\\x\\...\\y"));                    // "..." is a name
    CHECK(AbsIs102(L"\\top.\\f", L"D:\\cur\\x", NULL, L"D:\\top.\\f"));                        // root-relative
    CHECK(AbsIs102(L"\\f", L"\\\\srv\\sh\\cur", NULL, L"\\\\srv\\sh\\f"));                     // root-relative on UNC
    CHECK(AbsIs102(L"E:f.", L"C:\\cur", L"E:\\work", L"E:\\work\\f."));                       // drive-relative
    CHECK(AbsIs102(L"E:f", L"C:\\cur", NULL, NULL));                                         // ... without its directory
    CHECK(AbsIs102(L"\\\\srv\\sh\\d.\\f", L"C:\\cur", NULL, L"\\\\srv\\sh\\d.\\f"));
    CHECK(AbsIs102(L"\\\\srv\\sh\\..\\..\\f", L"C:\\cur", NULL, L"\\\\srv\\sh\\f"));           // the share is the root
    CHECK(AbsIs102(L"\\\\srv", L"C:\\cur", NULL, NULL));                                    // no share
    CHECK(AbsIs102(L"\\\\?\\C:\\x.\\f", L"C:\\cur", NULL, L"\\\\?\\C:\\x.\\f"));               // taken as it is
    CHECK(AbsIs102(L"f\x65E5\xD800.txt", L"C:\\\x0416", NULL, L"C:\\\x0416\\f\x65E5\xD800.txt"));
    CHECK(AbsIs102(L"g.txt", L"\\\\?\\C:\\long", NULL, L"C:\\long\\g.txt"));                    // a "\\?\" current directory
    CHECK(AbsIs102(L"g.txt", L"\\\\?\\UNC\\srv\\sh\\d", NULL, L"\\\\srv\\sh\\d\\g.txt"));
    CHECK(AbsIs102(L"", L"C:\\cur", NULL, NULL));
    CHECK(AbsIs102(L"C:\\", L"C:\\cur", NULL, L"C:\\"));

    // --- the names part of a version-2 message
    {
        WCHAR names[8] = {L'a', L'b', 0, L'c', 0, 0x7777, 0x7777, 0x7777};
        const int hdr = 8;
        CHECK(FcCheckNames(hdr + 5 * 2, hdr, 2, 1, names));
        CHECK(!FcCheckNames(hdr + 5 * 2, hdr, 3, 0, names));                        // terminator not where the length says
        CHECK(!FcCheckNames(hdr + 5 * 2 + 1, hdr, 2, 1, names));                    // odd size
        CHECK(!FcCheckNames(hdr + 6 * 2, hdr, 2, 1, names));                        // does not fill the message
        CHECK(!FcCheckNames(hdr + 5 * 2, hdr, 0xFFFFFFFFu, 0xFFFFFFFFu, names));    // the sum must not wrap
        CHECK(!FcCheckNames(hdr + 5 * 2, hdr, 0xFFFFFFFFu, 4, names));
        CHECK(!FcCheckNames(hdr + 3, hdr, 0, 0, names));                            // shorter than two terminators
        WCHAR unterminated[5] = {L'a', L'b', L'x', L'c', L'y'};
        CHECK(!FcCheckNames(hdr + 5 * 2, hdr, 2, 1, unterminated));
        WCHAR empty[2] = {0, 0};
        CHECK(FcCheckNames(hdr + 2 * 2, hdr, 0, 0, empty));
    }

    // --- the display form of an "\\?\" name
    {
        char a[64];
        strcpy_s(a, "\\\\?\\C:\\x\\a.");
        FcDisplayFormU8(a);
        CHECK(strcmp(a, "C:\\x\\a.") == 0);
        strcpy_s(a, "\\\\?\\UNC\\srv\\sh\\f\xE6\x97\xA5");
        FcDisplayFormU8(a);
        CHECK(strcmp(a, "\\\\srv\\sh\\f\xE6\x97\xA5") == 0);
        strcpy_s(a, "\\\\?\\unc\\s\\f");
        FcDisplayFormU8(a);
        CHECK(strcmp(a, "\\\\s\\f") == 0);
        strcpy_s(a, "C:\\x\\y");
        FcDisplayFormU8(a);
        CHECK(strcmp(a, "C:\\x\\y") == 0);
        strcpy_s(a, "\\\\?\\Volume{1}\\x"); // no drive: left as it is
        FcDisplayFormU8(a);
        CHECK(strcmp(a, "\\\\?\\Volume{1}\\x") == 0);
        strcpy_s(a, "\\\\?\\");
        FcDisplayFormU8(a);
        CHECK(strcmp(a, "\\\\?\\") == 0);
        strcpy_s(a, "\\\\server\\share\\f");
        FcDisplayFormU8(a);
        CHECK(strcmp(a, "\\\\server\\share\\f") == 0);
    }
}

//*****************************************************************************
//
// feature 103: an existing target that is the source itself
// (src/common/salsamefile.h, the UTF-8 facade in salfileio.cpp)
//

// an identity with a 64-bit id; times in whole seconds plus a sub-second part
static CSalFileIdentity Id103(DWORD vsn, ULONGLONG idx, ULONGLONG size, ULONGLONG mSec, ULONGLONG cSec,
                              DWORD links = 1, BOOL dir = FALSE, DWORD subSecond = 1234567)
{
    CSalFileIdentity id;
    SalFileIdentityClear(&id);
    id.Valid = TRUE;
    id.Has64 = TRUE;
    id.Vsn32 = vsn;
    id.Index64 = idx;
    id.Links = links;
    id.Attr = dir ? FILE_ATTRIBUTE_DIRECTORY : FILE_ATTRIBUTE_ARCHIVE;
    id.Size = size;
    ULONGLONG m = mSec * 10000000ULL + subSecond, c = cSec == 0 ? 0 : cSec * 10000000ULL + subSecond;
    id.MTime.dwLowDateTime = (DWORD)m;
    id.MTime.dwHighDateTime = (DWORD)(m >> 32);
    id.CTime.dwLowDateTime = (DWORD)c;
    id.CTime.dwHighDateTime = (DWORD)(c >> 32);
    return id;
}

// A fake file system for the temporary-name route, folding names like a macOS server:
// "cafe" + U+0301 (NFD) and "caf" + U+00E9 (NFC) are one entry, ASCII case is ignored.
// A rename onto the identical stored name is a no-op, onto an ASCII-case variant of it a
// case change, onto another spelling of the same entry "already exists" (the defect's
// server answer); MoveFile semantics otherwise (never replaces).
struct CFakeFs103
{
    struct CEntry
    {
        std::string Name, Data;
    };
    std::map<std::string, CEntry> E;  // folded full path -> stored name + content
    std::set<std::string> Locked;     // folded paths that cannot be renamed away (sharing violation)
    std::set<std::string> DenyTarget; // folded paths that cannot be created (access denied)
    std::string DenyRestoreTo;        // folded path a move from a temporary name may not go to
    int Moves = 0;

    static std::string Key(std::string n)
    {
        for (size_t p; (p = n.find("\\alias\\")) != std::string::npos;) // a folder alias: D:\alias = D:\share
            n.replace(p, 7, "\\share\\");
        for (size_t p; (p = n.find("e\xCC\x81")) != std::string::npos;) // NFD e + acute -> NFC
            n.replace(p, 3, "\xC3\xA9");
        for (size_t p; (p = n.find("\xC3\x89")) != std::string::npos;) // capital E acute -> small
            n.replace(p, 2, "\xC3\xA9");
        for (char& c : n)
            if (c >= 'A' && c <= 'Z')
                c = (char)(c - 'A' + 'a');
        return n;
    }
    void Add(const std::string& name, const std::string& data) { E[Key(name)] = {name, data}; }
    BOOL Has(const std::string& name, const std::string& data) const
    {
        auto it = E.find(Key(name));
        return it != E.end() && it->second.Name == name && it->second.Data == data;
    }
    BOOL Fail(DWORD* err, DWORD e)
    {
        *err = e;
        return FALSE;
    }
    BOOL Move(const char* from, const char* to, DWORD* err)
    {
        Moves++;
        std::string kf = Key(from), kt = Key(to);
        auto f = E.find(kf);
        if (f == E.end())
            return Fail(err, ERROR_FILE_NOT_FOUND);
        if (Locked.count(kf))
            return Fail(err, ERROR_SHARING_VIOLATION);
        if (!DenyRestoreTo.empty() && kt == DenyRestoreTo && strstr(from, "\\sal") != NULL)
            return Fail(err, ERROR_ACCESS_DENIED);
        if (DenyTarget.count(kt))
            return Fail(err, ERROR_ACCESS_DENIED);
        if (kt == kf) // the same entry
        {
            if (f->second.Name == to)
                return TRUE;
            if (_stricmp(f->second.Name.c_str(), to) == 0) // a plain case change
            {
                f->second.Name = to;
                return TRUE;
            }
            return Fail(err, ERROR_ALREADY_EXISTS); // another spelling: "already exists"
        }
        if (E.count(kt))
            return Fail(err, ERROR_ALREADY_EXISTS);
        CEntry e = f->second;
        e.Name = to;
        E.erase(f);
        E[kt] = e;
        return TRUE;
    }
};

static void TestSameFile103()
{
    const char* nfd = "D:\\share\\cafe\xCC\x81.txt"; // stored by the server (NFD)
    const char* nfc = "D:\\share\\Caf\xC3\xA9.txt";   // typed by the user (NFC, capital C)
    const DWORD exists = ERROR_ALREADY_EXISTS;

    // --- the temporary name ---
    char t[64];
    CHECK(SalBuildTempSibling("C:\\dir\\x.txt", 0x1ABC, t, sizeof(t)) && strcmp(t, "C:\\dir\\salABC") == 0);
    CHECK(SalBuildTempSibling("x.txt", 5, t, sizeof(t)) && strcmp(t, "sal005") == 0);
    CHECK(SalBuildTempSibling("C:\\d\\x", 0, t, 13) && strcmp(t, "C:\\d\\sal000") == 0); // 12 bytes + NUL fit
    CHECK(!SalBuildTempSibling("C:\\d\\x", 0, t, 12));

    // --- identity: ids ---
    CSalFileIdentity a = Id103(0x1234, 0x10, 100, 5000, 4000);
    CSalFileIdentity same = a;
    CHECK(SalFileIdMatch(a, same) == simEqual);
    CHECK(SalFileIdMatch(a, Id103(0x1234, 0x11, 100, 5000, 4000)) == simDifferent);    // another file, same metadata
    CHECK(SalFileIdMatch(a, Id103(0x9999, 0x10, 100, 5000, 4000)) == simDifferent);    // same index, other volume
    CHECK(SalFileIdMatch(a, Id103(0x1234, 0, 100, 5000, 4000)) == simUnknown);         // a server without ids
    CHECK(SalFileIdMatch(Id103(0, 0, 1, 1, 1), Id103(0, 0, 1, 1, 1)) == simUnknown);   // WebDAV: vsn 0, index 0
    CHECK(SalFileIdMatch(Id103(1, 0, 1, 1, 1), Id103(2, 0, 1, 1, 1)) == simDifferent); // no ids, two volumes
    CHECK(SalFileIdMatch(a, Id103(0x1234, ~0ULL, 100, 5000, 4000)) == simUnknown);     // all ones: not an id
    CSalFileIdentity invalid;
    SalFileIdentityClear(&invalid);
    CHECK(SalFileIdMatch(a, invalid) == simUnknown && SalFileIdMatch(invalid, a) == simUnknown);
    // 128-bit ids win over the 64-bit index (ReFS: the 64 bits may not be unique)
    CSalFileIdentity r1 = Id103(7, 0x10, 1, 1, 1), r2 = Id103(7, 0x10, 1, 1, 1);
    r1.Has128 = r2.Has128 = TRUE;
    r1.Vsn64 = r2.Vsn64 = 0x77;
    memset(r1.Id128, 0xA1, 16);
    memset(r2.Id128, 0xA1, 16);
    r2.Id128[15] = 0xA2;
    CHECK(SalFileIdMatch(r1, r2) == simDifferent);
    r2.Id128[15] = 0xA1;
    r2.Index64 = 0x20; // the 64-bit view differs, the 128-bit one decides
    CHECK(SalFileIdMatch(r1, r2) == simEqual);
    memset(r2.Id128, 0, 16); // an all-zero 128-bit id is not used: back to the 64-bit index
    CHECK(SalFileIdMatch(r1, r2) == simDifferent);
    r2.Has128 = FALSE; // one side without FileIdInfo: the 64-bit index for both
    r2.Index64 = 0x10;
    CHECK(SalFileIdMatch(r1, r2) == simEqual);

    // --- identity: metadata (used only when there are no ids) ---
    CHECK(SalFileMetaEqual(a, same));
    CHECK(SalFileMetaEqual(a, Id103(0, 0, 100, 5000, 4000, 1, FALSE, 0)));                  // rounded to seconds by a server
    CHECK(!SalFileMetaEqual(a, Id103(0, 0, 101, 5000, 4000)));                              // size
    CHECK(!SalFileMetaEqual(a, Id103(0, 0, 100, 5001, 4000)));                              // last write
    CHECK(!SalFileMetaEqual(a, Id103(0, 0, 100, 5000, 4001)));                              // creation
    CHECK(SalFileMetaEqual(a, Id103(0, 0, 100, 5000, 0)));                                  // no creation time: not compared
    CHECK(!SalFileMetaEqual(a, Id103(0, 0, 100, 5000, 4000, 1, TRUE)));                     // a directory
    CHECK(SalFileMetaEqual(Id103(0, 0, 0, 9, 9, 1, TRUE), Id103(0, 0, 77, 9, 9, 1, TRUE))); // directory sizes ignored
    CHECK(!SalFileMetaEqual(a, invalid));

    // --- the decision ---
    struct CDec103
    {
        CSalFileIdentity S, T;
        DWORD Err;
        CSalExistingTargetAction Move, Copy;
    };
    const CDec103 dec[] = {
        {a, a, ERROR_ACCESS_DENIED, setaLegacy, setaLegacy},                                       // not "already exists"
        {a, a, ERROR_FILE_EXISTS, setaViaTempName, setaRefuseSame},                                // the same file
        {a, a, exists, setaViaTempName, setaRefuseSame},                                           //
        {Id103(1, 0x10, 100, 5000, 4000, 2), Id103(1, 0x10, 100, 5000, 4000, 2), exists,           // another hard link
         setaViaTempName, setaLegacy},                                                             //
        {a, Id103(0x1234, 0x10, 999, 5000, 4000), exists, setaViaTempName, setaLegacy},            // same id, a volume clone / constant id
        {a, Id103(0x1234, 0x11, 100, 5000, 4000), exists, setaViaTempName, setaLegacy},            // other id, twin data: per-path ids? the route checks
        {a, Id103(0x1234, 0x11, 101, 5000, 4000), exists, setaLegacy, setaLegacy},                 // another file
        {a, Id103(0x1234, 0x11, 100, 5003, 4000), exists, setaLegacy, setaLegacy},                 // another file (written later)
        {a, Id103(0x9999, 0x10, 100, 5000, 4000), exists, setaViaTempName, setaLegacy},            // another volume, twin data
        {a, Id103(0x9999, 0x10, 100, 5000, 4009), exists, setaLegacy, setaLegacy},                 // another volume
        {Id103(0, 0, 10, 50, 40), Id103(0, 0, 10, 50, 40), exists, setaViaTempName, setaRefuseSame}, // WebDAV alias
        {Id103(0, 0, 10, 50, 40), Id103(0, 0, 11, 50, 40), exists, setaLegacy, setaLegacy},          // WebDAV, other file
        {Id103(0, 0, 10, 50, 40), Id103(0, 0, 10, 51, 40), exists, setaLegacy, setaLegacy},          //
        {a, invalid, exists, setaViaTempName, setaLegacy},                                         // target unreadable
        {invalid, a, exists, setaViaTempName, setaLegacy},                                         // source unreadable
    };
    for (int i = 0; i < _countof(dec); i++)
    {
        CHECK(SalDecideExistingTarget(FALSE, dec[i].Err, dec[i].S, dec[i].T) == dec[i].Move);
        CHECK(SalDecideExistingTarget(TRUE, dec[i].Err, dec[i].S, dec[i].T) == dec[i].Copy);
    }

    // --- a link moved onto what it points at (second review of 103) ---
    {
        CSalFileIdentity lnk = Id103(0x1234, 0x99, 0, 5000, 4000); // the link object itself
        lnk.Attr |= FILE_ATTRIBUTE_REPARSE_POINT;
        CHECK(SalLinkPointsAtTarget(lnk, a, a));                                   // through the link: the target
        CHECK(!SalLinkPointsAtTarget(lnk, Id103(0x1234, 0x11, 1, 1, 1), a));      // points elsewhere
        CHECK(!SalLinkPointsAtTarget(a, a, a));                                     // not a link
        CHECK(!SalLinkPointsAtTarget(lnk, invalid, a));                             // a dangling link
        CHECK(SalLinkPointsAtTarget(lnk, Id103(0, 0, 10, 50, 40), Id103(0, 0, 10, 50, 40))); // no ids, same metadata
        CHECK(!SalLinkPointsAtTarget(lnk, Id103(0, 0, 10, 50, 40), Id103(0, 0, 11, 50, 40)));
        CHECK(SalDecideExistingTarget(FALSE, exists, lnk, a) == setaLegacy); // what the rename rule alone says: the gap
    }

    // --- the temporary-name route on the folding server ---
    char tmp[128];
    DWORD err;
    { // the defect's case: the target is another spelling of the source -> renamed, nothing lost
        CFakeFs103 fs;
        fs.Add(nfd, "PRECIOUS");
        auto mv = [&fs](const char* f, const char* to, DWORD* e) { return fs.Move(f, to, e); };
        DWORD e0 = 0;
        CHECK(!fs.Move(nfd, nfc, &e0) && e0 == exists); // what MoveFile answers there
        CHECK(SalRenameViaTempName(nfd, nfc, mv, tmp, sizeof(tmp), 0, &err) == svtDone);
        CHECK(fs.E.size() == 1 && fs.Has(nfc, "PRECIOUS"));
    }
    { // another file under the target name: the source comes back, nothing touched
        CFakeFs103 fs;
        fs.Add("D:\\share\\a.txt", "PRECIOUS");
        fs.Add("D:\\share\\b.txt", "other");
        auto mv = [&fs](const char* f, const char* to, DWORD* e) { return fs.Move(f, to, e); };
        CHECK(SalRenameViaTempName("D:\\share\\a.txt", "D:\\share\\b.txt", mv, tmp, sizeof(tmp), 0, &err) == svtTargetIsOther);
        CHECK(fs.E.size() == 2 && fs.Has("D:\\share\\a.txt", "PRECIOUS") && fs.Has("D:\\share\\b.txt", "other"));
    }
    { // the source cannot be renamed at all: an error, nothing moved
        CFakeFs103 fs;
        fs.Add(nfd, "PRECIOUS");
        fs.Locked.insert(CFakeFs103::Key(nfd));
        auto mv = [&fs](const char* f, const char* to, DWORD* e) { return fs.Move(f, to, e); };
        CHECK(SalRenameViaTempName(nfd, nfc, mv, tmp, sizeof(tmp), 0, &err) == svtFailed && err == ERROR_SHARING_VIOLATION);
        CHECK(fs.E.size() == 1 && fs.Has(nfd, "PRECIOUS"));
    }
    { // the second step fails for another reason: the source is back under its own name
        CFakeFs103 fs;
        fs.Add("D:\\share\\y.txt", "Y");
        fs.DenyTarget.insert(CFakeFs103::Key("D:\\share\\x.txt"));
        auto mv = [&fs](const char* f, const char* to, DWORD* e) { return fs.Move(f, to, e); };
        CHECK(SalRenameViaTempName("D:\\share\\y.txt", "D:\\share\\x.txt", mv, tmp, sizeof(tmp), 0, &err) == svtFailed && err == ERROR_ACCESS_DENIED);
        CHECK(fs.E.size() == 1 && fs.Has("D:\\share\\y.txt", "Y"));
    }
    { // the way back fails too: the source is reported where it is
        CFakeFs103 fs;
        fs.Add("D:\\share\\a.txt", "PRECIOUS");
        fs.Add("D:\\share\\b.txt", "other");
        fs.DenyRestoreTo = CFakeFs103::Key("D:\\share\\a.txt");
        auto mv = [&fs](const char* f, const char* to, DWORD* e) { return fs.Move(f, to, e); };
        CHECK(SalRenameViaTempName("D:\\share\\a.txt", "D:\\share\\b.txt", mv, tmp, sizeof(tmp), 0x42, &err) == svtLeftAtTemp && err == exists);
        CHECK(strcmp(tmp, "D:\\share\\sal042") == 0 && fs.Has(tmp, "PRECIOUS") && fs.Has("D:\\share\\b.txt", "other"));
    }
    { // the source is itself named like a temporary name, the alias is its folder: the
      // candidate equal to its own name is skipped (a "rename" onto its own name would succeed
      // without moving it, and the route would take the source for another file - review 103)
        CFakeFs103 fs;
        fs.Add("D:\\share\\sal000", "PRECIOUS");
        auto mv = [&fs](const char* f, const char* to, DWORD* e) { return fs.Move(f, to, e); };
        DWORD e0 = 0;
        CHECK(!fs.Move("D:\\share\\sal000", "D:\\alias\\sal000", &e0) && e0 == exists);
        CHECK(SalRenameViaTempName("D:\\share\\sal000", "D:\\alias\\sal000", mv, tmp, sizeof(tmp), 0, &err) == svtDone);
        CHECK(strcmp(tmp, "D:\\share\\sal001") == 0 && fs.E.size() == 1 && fs.Has("D:\\alias\\sal000", "PRECIOUS"));
        // the target's own name is skipped too
        CFakeFs103 fs2;
        fs2.Add("D:\\share\\x.txt", "PRECIOUS");
        fs2.Add("D:\\share\\sal000", "other");
        auto mv2 = [&fs2](const char* f, const char* to, DWORD* e) { return fs2.Move(f, to, e); };
        CHECK(SalRenameViaTempName("D:\\share\\x.txt", "D:\\share\\SAL000", mv2, tmp, sizeof(tmp), 0, &err) == svtTargetIsOther);
        CHECK(strcmp(tmp, "D:\\share\\sal001") == 0 && fs2.Has("D:\\share\\x.txt", "PRECIOUS") && fs2.Has("D:\\share\\sal000", "other"));
    }
    { // temporary names in use are skipped
        CFakeFs103 fs;
        fs.Add(nfd, "PRECIOUS");
        for (int i = 0; i < 5; i++)
        {
            char nm[32];
            sprintf_s(nm, "D:\\share\\SAL%03X", i);
            fs.Add(nm, "busy");
        }
        auto mv = [&fs](const char* f, const char* to, DWORD* e) { return fs.Move(f, to, e); };
        CHECK(SalRenameViaTempName(nfd, nfc, mv, tmp, sizeof(tmp), 0, &err) == svtDone);
        CHECK(fs.E.size() == 6 && fs.Has(nfc, "PRECIOUS") && strcmp(tmp, "D:\\share\\sal005") == 0);
    }
    { // every temporary name in use: an error, the source untouched
        CFakeFs103 fs;
        fs.Add(nfd, "PRECIOUS");
        for (int i = 0; i < 0x1000; i++)
        {
            char nm[32];
            sprintf_s(nm, "D:\\share\\sal%03X", i);
            fs.Add(nm, "busy");
        }
        auto mv = [&fs](const char* f, const char* to, DWORD* e) { return fs.Move(f, to, e); };
        CHECK(SalRenameViaTempName(nfd, nfc, mv, tmp, sizeof(tmp), 0, &err) == svtFailed && err == exists);
        CHECK(fs.Has(nfd, "PRECIOUS") && fs.Moves == 0x1000);
    }
    { // no room for the temporary name: an error before anything is moved
        CFakeFs103 fs;
        fs.Add(nfd, "PRECIOUS");
        auto mv = [&fs](const char* f, const char* to, DWORD* e) { return fs.Move(f, to, e); };
        CHECK(SalRenameViaTempName(nfd, nfc, mv, tmp, 12, 0, &err) == svtFailed && err == ERROR_FILENAME_EXCED_RANGE);
        CHECK(fs.Moves == 0 && fs.Has(nfd, "PRECIOUS"));
    }

    // --- real files: identity through the UTF-8 facade, the route on NTFS ---
    WCHAR tmpPathW[MAX_PATH];
    char tmpPath[3 * MAX_PATH];
    DWORD n = GetTempPathW(MAX_PATH, tmpPathW);
    if (n == 0 || n >= MAX_PATH || SalWToU8(tmpPathW, -1, tmpPath, sizeof(tmpPath)) == 0)
    {
        printf("skipping the file part of TestSameFile103 (no temp path)\n");
        return;
    }
    char dir[3 * MAX_PATH + 40];
    sprintf_s(dir, "%ssaltests-103-%u", tmpPath, GetCurrentProcessId());
    CHECK(SalCreateDirectory(dir, NULL) || GetLastError() == ERROR_ALREADY_EXISTS);
    std::string fa = std::string(dir) + "\\longname103a.txt", fb = std::string(dir) + "\\b.txt",
                fc = std::string(dir) + "\\c.txt", fx = std::string(dir) + "\\x.txt", fy = std::string(dir) + "\\y.txt";
    auto put = [](const std::string& p, const char* text) -> BOOL
    {
        HANDLE h = SalCreateFile(p.c_str(), GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
        DWORD w = 0;
        BOOL ok = h != INVALID_HANDLE_VALUE && WriteFile(h, text, (DWORD)strlen(text), &w, NULL);
        if (h != INVALID_HANDLE_VALUE)
            CloseHandle(h);
        return ok;
    };
    CHECK(put(fa, "PRECIOUS") && put(fc, "PRECIOUS-C")); // c: another file
    WCHAR* wa = SalPathToWExtAlloc(fa.c_str());
    WCHAR* wb = SalPathToWExtAlloc(fb.c_str());
    BOOL linked = wa != NULL && wb != NULL && CreateHardLinkW(wb, wa, NULL);
    free(wa);
    free(wb);
    CHECK(linked);
    CSalFileIdentity ia, ib, ic, iaShort, idir;
    CHECK(SalGetFileIdentity(fa.c_str(), TRUE, &ia) && ia.Valid && ia.Has64 && ia.Size == 8);
    CHECK(SalGetFileIdentity(fb.c_str(), TRUE, &ib) && SalGetFileIdentity(fc.c_str(), FALSE, &ic));
    CHECK(SalFileIdMatch(ia, ib) == simEqual && ia.Links == 2 && ib.Links == 2); // one file, two names
    { // from an open (overlapped, as the asynchronous copy opens it) handle, as DoCopyFile reads the source
        HANDLE h = SalCreateFile(fa.c_str(), GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING,
                                 FILE_FLAG_OVERLAPPED | FILE_FLAG_SEQUENTIAL_SCAN, NULL);
        CSalFileIdentity ih;
        CHECK(h != INVALID_HANDLE_VALUE && SalFileIdentityFromHandle(h, &ih) && SalFileIdMatch(ia, ih) == simEqual &&
              SalFileMetaEqual(ia, ih));
        if (h != INVALID_HANDLE_VALUE)
            CloseHandle(h);
    }
    CHECK(SalFileIdMatch(ia, ic) == simDifferent);
    CHECK(SalDecideExistingTarget(TRUE, exists, ia, ib) == setaLegacy);       // copy onto its other link: as before
    CHECK(SalDecideExistingTarget(FALSE, exists, ia, ib) == setaViaTempName); // the route tells them apart
    CHECK(SalDecideExistingTarget(TRUE, exists, ia, ic) == setaLegacy && SalDecideExistingTarget(FALSE, exists, ia, ic) == setaLegacy);
    char shortPath[3 * MAX_PATH + 40];
    if (SalGetShortPathName(fa.c_str(), shortPath, sizeof(shortPath)) && _stricmp(shortPath, fa.c_str()) != 0)
    { // the same file under its 8.3 name: another path, the same identity
        CHECK(SalGetFileIdentity(shortPath, TRUE, &iaShort) && SalFileIdMatch(ia, iaShort) == simEqual);
        CHECK(SalDecideExistingTarget(FALSE, exists, ia, iaShort) == setaViaTempName);
    }
    else
        printf("TestSameFile103: no 8.3 names on the temp volume - the short-name alias is not checked\n");
    CHECK(SalGetFileIdentity(dir, TRUE, &idir) && (idir.Attr & FILE_ATTRIBUTE_DIRECTORY) && SalFileIdMatch(idir, ia) == simDifferent);
    CSalFileIdentity none;
    CHECK(!SalGetFileIdentity((std::string(dir) + "\\missing.txt").c_str(), TRUE, &none) && !none.Valid);
    { // a real symbolic link to longname103a.txt (needs Developer Mode or the privilege - skipped otherwise)
        std::string fl = std::string(dir) + "\\lnk103.txt";
        WCHAR* wl = SalPathToWExtAlloc(fl.c_str());
        WCHAR* wt = SalPathToWExtAlloc(fa.c_str());
        BOOL made = wl != NULL && wt != NULL && CreateSymbolicLinkW(wl, wt, 0x2 /* SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE */);
        free(wl);
        free(wt);
        if (made)
        {
            CSalFileIdentity il, ilThrough;
            CHECK(SalGetFileIdentity(fl.c_str(), TRUE, &il) && (il.Attr & FILE_ATTRIBUTE_REPARSE_POINT));
            CHECK(SalGetFileIdentity(fl.c_str(), FALSE, &ilThrough) && SalFileIdMatch(ilThrough, ia) == simEqual);
            CHECK(SalFileIdMatch(il, ia) == simDifferent);       // the link itself is another object
            CHECK(SalLinkPointsAtTarget(il, ilThrough, ia));     // ... but it points at the target: refused
            CHECK(!SalLinkPointsAtTarget(il, ilThrough, ic));    // onto another file: not this rule
            CHECK(SalDeleteFile(fl.c_str()));
        }
        else
            printf("TestSameFile103: no symbolic link could be created - the link checks on disk are skipped\n");
    }
    // the route on NTFS: another file under the target name, then a plain rename
    CHECK(put(fx, "X") && put(fy, "Y"));
    char tmpName[3 * MAX_PATH + 80];
    CHECK(SalRenameViaTempNameU8(fx.c_str(), fy.c_str(), tmpName, sizeof(tmpName), &err) == svtTargetIsOther);
    CHECK(SalGetFileAttributes(fx.c_str()) != INVALID_FILE_ATTRIBUTES && SalGetFileAttributes(tmpName) == INVALID_FILE_ATTRIBUTES);
    CHECK(SalDeleteFile(fy.c_str()));
    CHECK(SalRenameViaTempNameU8(fx.c_str(), fy.c_str(), tmpName, sizeof(tmpName), &err) == svtDone);
    CHECK(SalGetFileAttributes(fx.c_str()) == INVALID_FILE_ATTRIBUTES && SalGetFileAttributes(fy.c_str()) != INVALID_FILE_ATTRIBUTES);
    SalDeleteFile(fa.c_str());
    SalDeleteFile(fb.c_str());
    SalDeleteFile(fc.c_str());
    SalDeleteFile(fy.c_str());
    CHECK(SalRemoveDirectory(dir));
}

int main()
{
    TestConversions();
    TestNormalization();
    TestMatching();
    TestPathBuf();
    TestExtendedPaths();
    TestFileIO();
    TestDropFiles();
    TestLongComponentNames();
    TestDarkThemePalette();
    TestFindDarkModeSurfaces();
    TestDarkIconColorAdaptation();
    TestComposedMessageEncoding();
    TestUiTextEncoding();
    TestNumberCompositionEncoding();
    TestPluginMetadataEncoding();
    TestWtf8();
    TestWtf8FileOps();
    TestEncodingReview068();
    TestEncodingFixes069();
    TestCommandShell071();
    TestPanelTabs078();
    TestBugReport079();
    TestCloseApp080();
    TestSevenZipList084();
    TestArchiverMigration084();
    TestUrlPasswordStrip085();
    TestRandom086();
    TestArcNames087();
    TestSplUnicode089();
    TestArcAssoc089();
    TestFtpAnon090();
    TestNameIdentity092();
    TestDialogText093();
    TestCmdLineOffsets093();
    TestArchivePassword093();
    TestZipPassword094();
    TestHeapString095();
    TestLeftovers101();
    TestFcRemote102();
    TestSameFile103();

    printf("saltests: %d checks, %d failed\n", g_checks, g_failures);
    return g_failures;
}
