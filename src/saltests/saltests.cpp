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
#include "salsafereplace.h" // feature 105
#include "salarcedit.h"     // feature 108
#include "salzipname.h"     // feature 110
#include "salpvsource.h"    // feature 111
#include "salcacheedit.h"   // feature 112
#include "salzipmember.h"   // feature 113
#include "salfatname.h"     // feature 114
#include "salvolpaths.h"    // feature 114
#include "salnameorder.h"   // feature 115
#include "salftpsecret.h"   // feature 116
#include "salcsumlist.h"    // feature 117
#include "salpackvol.h"     // feature 119
#include "salpvpixel.h"     // feature 120
#include "salmsgwrap.h"     // feature 121
#include "salfindtext.h"    // feature 121
#include "salupdcheck.h"    // feature 123
#include "saluncserver.h"   // feature 125
#include "salshelllink.h"   // feature 128
#include "salinserts.h"     // feature 127
#include "salwideinserts.h" // feature 129
#include "saljpegkeep.h"     // feature 132
#include "salmaskname.h"     // feature 141
#include "salloopclose.h"    // feature 143
#include "salnumbername.h"   // feature 148
#include "salftpautoren.h"   // feature 141
#include "salfindignore.h"   // feature 163
#include "salzipdelete.h"    // feature 164
#include "salzipcount.h"     // feature 165
#include "salaltername.h"    // feature 169
#include "salfmtinserts.h"   // feature 180
#include "salmultisz.h"      // feature 189
#include "salregfind.h"      // feature 257
#include "salreparse.h"      // feature 197
#include "salshortname.h"    // feature 203
#include "salu8fold.h"       // feature 210
#include "salu8letter.h"     // feature 254
#include "salbatchtext.h"    // feature 226
#include "salnamerun.h"      // feature 230
#include "salmenuhotkey.h"   // feature 236
#include "salpctpath.h"      // feature 238
#include "salquickfilter.h"   // feature 244
#include "salcfgimport.h"     // feature 245
#include "salnetdrive.h"      // feature 246
#include "salcpfit.h"         // feature 248
#include "salcasetwins.h"     // feature 252
#include "salcopyname.h"      // feature 259
#include "salcachename.h"     // feature 260
#include "salcodetable.h"     // feature 262
#include "../plugins/shared/splunicode.h" // feature 089: the plug-in converters, checked against the core's
#include "../plugins/filecomp/fcproto.h" // feature 102: the fcremote.exe channel
#include "../plugins/shared/splfiledlg.h" // feature 104: the plug-ins' Unicode file and folder pickers
#include "../plugins/shared/splloadstru8.h" // feature 130: a plug-in's resource text as UTF-8

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

// feature 104: the pure parts of the plug-ins' Unicode file dialog (splfiledlg.h) and of the
// path-label painting (splunicode.h SplShortenLongTextW)
static BOOL OffsetsAre104(const char* u8, WORD file, WORD ext)
{
    WORD f = 0xFFFF, e = 0xFFFF;
    SplFileDlgDetail::NameOffsets(u8, &f, &e);
    return f == file && e == ext;
}

static void TestPluginFileDlg104()
{
    // --- nFileOffset / nFileExtension in BYTES of the UTF-8 result (the A dialog's meanings)
    CHECK(OffsetsAre104("C:\\dir\\file.txt", 7, 12));
    CHECK(OffsetsAre104("C:\\dir\\file", 7, 11));       // no extension: the terminator
    CHECK(OffsetsAre104("C:\\dir\\file.", 7, 0));        // ends with a dot: 0
    CHECK(OffsetsAre104("C:\\d.ir\\file", 8, 12));       // a dot in a folder is no extension
    CHECK(OffsetsAre104("file.tar.gz", 0, 9));             // the last dot
    CHECK(OffsetsAre104("C:/dir/x.y", 7, 9));              // a slash separates too
    CHECK(OffsetsAre104(".cvspass", 0, 1));                // as Windows does: an extension
    // "C:\<U+017E>\<U+0159>.txt": U+017E and U+0159 are 2 bytes each
    CHECK(OffsetsAre104("C:\\\xC5\xBE\\\xC5\x99.txt", 6, 9));
    // U+65E5 (3 bytes), U+1F4C1 (4 bytes) in the name
    CHECK(OffsetsAre104("D:\\\xE6\x97\xA5\xF0\x9F\x93\x81.png", 3, 11));

    // --- the code-page filter list as UTF-16, the list form kept (items + the final empty one)
    {
        static const char list[] = "Logs (*.log)\0*.log\0All\0*.*\0";
        WCHAR* w = SplFileDlgDetail::CodePageListToWAlloc(list);
        static const WCHAR expect[] = L"Logs (*.log)\0*.log\0All\0*.*\0";
        CHECK(w != NULL && memcmp(w, expect, sizeof(expect)) == 0); // incl. the double terminator
        free(w);
        WCHAR* e = SplFileDlgDetail::CodePageListToWAlloc("\0");
        CHECK(e != NULL && e[0] == 0 && e[1] == 0);
        free(e);
        CHECK(SplFileDlgDetail::CodePageListToWAlloc(NULL) == NULL);
        // a code-page byte becomes the code page's character (the resource strings are code page)
        char cp[] = {'a', (char)0xE8, 0, 0};
        WCHAR expectCp[2];
        MultiByteToWideChar(CP_ACP, 0, cp, 2, expectCp, 2);
        WCHAR* wc = SplFileDlgDetail::CodePageListToWAlloc(cp);
        CHECK(wc != NULL && wc[0] == L'a' && wc[1] == expectCp[1] && wc[2] == 0 && wc[3] == 0);
        free(wc);
        WCHAR* t = SplFileDlgDetail::CodePageToWAlloc("Save As");
        CHECK(t != NULL && wcscmp(t, L"Save As") == 0);
        free(t);
        CHECK(SplFileDlgDetail::CodePageToWAlloc(NULL) == NULL);
    }

    // --- SplShortenLongTextW: nothing up to 1,024 units, then 32 + "..." + 960, never between
    //     the halves of a surrogate pair
    {
        std::vector<WCHAR> buf;
        for (int len = 1020; len <= 1030; len++)
        {
            buf.assign(len + 1, L'x');
            buf[len] = 0;
            for (int i = 0; i < len; i++)
                buf[i] = (WCHAR)(L'A' + i % 26);
            std::vector<WCHAR> orig(buf);
            int n = SplShortenLongTextW(buf.data(), len);
            if (len <= 1024)
                CHECK(n == len && buf == orig);
            else
            {
                CHECK(n == 32 + 3 + 960 && buf[n] == 0);
                CHECK(memcmp(buf.data(), orig.data(), 32 * sizeof(WCHAR)) == 0);
                CHECK(buf[32] == L'.' && buf[33] == L'.' && buf[34] == L'.');
                CHECK(memcmp(buf.data() + 35, orig.data() + len - 960, 960 * sizeof(WCHAR)) == 0);
            }
        }
        // a surrogate pair across the head's end and across the tail's start
        int len = 2000;
        buf.assign(len + 1, L'a');
        buf[len] = 0;
        buf[31] = 0xD83D; // high surrogate as the head's last unit
        buf[32] = 0xDCC1;
        buf[len - 961] = 0xD83D;
        buf[len - 960] = 0xDCC1; // low surrogate as the tail's first unit
        int n = SplShortenLongTextW(buf.data(), len);
        CHECK(buf[30] == L'a' && buf[31] == L'.'); // the head ends before the pair
        CHECK(buf[31 + 3] == L'a');                 // the tail starts after it
        CHECK(n == 31 + 3 + 959 && buf[n] == 0);
        BOOL noLone = TRUE;
        for (int i = 0; i < n; i++) // no lone surrogate was produced
        {
            BOOL hi = buf[i] >= 0xD800 && buf[i] <= 0xDBFF, lo = buf[i] >= 0xDC00 && buf[i] <= 0xDFFF;
            if (lo && !(i > 0 && buf[i - 1] >= 0xD800 && buf[i - 1] <= 0xDBFF))
                noLone = FALSE;
            if (hi && !(i + 1 < n && buf[i + 1] >= 0xDC00 && buf[i + 1] <= 0xDFFF))
                noLone = FALSE;
        }
        CHECK(noLone);
        CHECK(SplShortenLongTextW(NULL, 5000) == 5000);
    }
}

// feature 105: an existing file is replaced only by a complete new file (src/common/salsafereplace.h)
static void TestSafeReplace105()
{
    // --- pure: what follows a failed ReplaceFileW ---
    CHECK(SalReplaceFailureNext(ERROR_ACCESS_DENIED, TRUE, TRUE) == srnKeepTarget);     // read-only target
    CHECK(SalReplaceFailureNext(ERROR_SHARING_VIOLATION, TRUE, TRUE) == srnKeepTarget); // target in use
    CHECK(SalReplaceFailureNext(ERROR_UNABLE_TO_REMOVE_REPLACED, TRUE, TRUE) == srnKeepTarget);
    CHECK(SalReplaceFailureNext(ERROR_DISK_FULL, TRUE, TRUE) == srnKeepTarget);
    CHECK(SalReplaceFailureNext(ERROR_NOT_SUPPORTED, TRUE, TRUE) == srnFallbackMove); // a file system without ReplaceFile
    CHECK(SalReplaceFailureNext(ERROR_INVALID_FUNCTION, TRUE, TRUE) == srnFallbackMove);
    CHECK(SalReplaceFailureNext(ERROR_INVALID_PARAMETER, TRUE, TRUE) == srnFallbackMove);
    CHECK(SalReplaceFailureNext(ERROR_CALL_NOT_IMPLEMENTED, TRUE, TRUE) == srnFallbackMove);
    CHECK(SalReplaceFailureNext(ERROR_NOT_SUPPORTED, TRUE, FALSE) == srnKeepTarget);              // nothing to put in place
    CHECK(SalReplaceFailureNext(ERROR_UNABLE_TO_MOVE_REPLACEMENT, FALSE, TRUE) == srnFinishMove); // the target is gone already
    CHECK(SalReplaceFailureNext(ERROR_FILE_NOT_FOUND, FALSE, TRUE) == srnFinishMove);             // deleted meanwhile
    CHECK(SalReplaceFailureNext(ERROR_FILE_NOT_FOUND, FALSE, FALSE) == srnBothGone);

    // --- pure: the temporary name next to the target ---
    WCHAR* tn = SalBuildTempNextToW(L"C:\\dir\\x.png", L"pv", 0x1ABC);
    CHECK(tn != NULL && wcscmp(tn, L"C:\\dir\\pv1ABC.tmp") == 0);
    free(tn);
    tn = SalBuildTempNextToW(L"x.png", L"pv", 0x12345); // no folder part; four hex digits
    CHECK(tn != NULL && wcscmp(tn, L"pv2345.tmp") == 0);
    free(tn);
    tn = SalBuildTempNextToW(L"\\\\?\\C:\\d\\\x010D\xD83D\xDCC1.png", L"pv", 5); // the \\?\ form, a name outside ASCII
    CHECK(tn != NULL && wcscmp(tn, L"\\\\?\\C:\\d\\pv0005.tmp") == 0);
    free(tn);

    // --- real files (NTFS %TEMP%) ---
    WCHAR tmp[MAX_PATH];
    DWORD n = GetTempPathW(MAX_PATH, tmp);
    if (n == 0 || n >= MAX_PATH)
    {
        printf("skipping the file part of TestSafeReplace105 (no temp path)\n");
        return;
    }
    std::wstring dir = std::wstring(L"\\\\?\\") + tmp + L"saltests-105-" + std::to_wstring(GetCurrentProcessId());
    CHECK(CreateDirectoryW(dir.c_str(), NULL) || GetLastError() == ERROR_ALREADY_EXISTS);
    auto put = [](const std::wstring& p, const char* text, DWORD attr) -> BOOL
    {
        SetFileAttributesW(p.c_str(), FILE_ATTRIBUTE_NORMAL);
        HANDLE h = CreateFileW(p.c_str(), GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
        DWORD w = 0;
        BOOL ok = h != INVALID_HANDLE_VALUE && WriteFile(h, text, (DWORD)strlen(text), &w, NULL);
        if (h != INVALID_HANDLE_VALUE)
            CloseHandle(h);
        if (ok && attr != FILE_ATTRIBUTE_NORMAL)
            ok = SetFileAttributesW(p.c_str(), attr);
        return ok;
    };
    auto get = [](const std::wstring& p) -> std::string
    {
        HANDLE h = CreateFileW(p.c_str(), GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL,
                               OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, NULL);
        if (h == INVALID_HANDLE_VALUE)
            return "<missing>";
        char b[64] = {0};
        DWORD r = 0;
        if (!ReadFile(h, b, sizeof(b) - 1, &r, NULL))
            strcpy_s(b, "<unreadable>");
        CloseHandle(h);
        return b;
    };
    auto exists = [](const std::wstring& p) -> BOOL
    { return GetFileAttributesW(p.c_str()) != INVALID_FILE_ATTRIBUTES; };
    // a complete new file next to 'target' through SalCreateTempNextToW, holding 'text'
    auto newTemp = [](const std::wstring& target, const char* text, std::wstring* temp) -> BOOL
    {
        WCHAR* p = NULL;
        HANDLE h = INVALID_HANDLE_VALUE;
        DWORD err = 0;
        if (!SalCreateTempNextToW(target.c_str(), L"pv", &p, &h, &err))
            return FALSE;
        DWORD w = 0;
        BOOL ok = WriteFile(h, text, (DWORD)strlen(text), &w, NULL) && FlushFileBuffers(h);
        CloseHandle(h);
        *temp = p;
        free(p);
        return ok;
    };
    std::wstring t = dir + L"\\t\x010D.png", other = dir + L"\\other.png", tmpFile;
    DWORD err = 0;

    // 1. the temporary file: in the target's folder, named pvXXXX.tmp, empty, open; two are two
    {
        WCHAR *p1 = NULL, *p2 = NULL;
        HANDLE h1 = INVALID_HANDLE_VALUE, h2 = INVALID_HANDLE_VALUE;
        CHECK(SalCreateTempNextToW(t.c_str(), L"pv", &p1, &h1, &err) && h1 != INVALID_HANDLE_VALUE);
        CHECK(SalCreateTempNextToW(t.c_str(), L"pv", &p2, &h2, &err) && h2 != INVALID_HANDLE_VALUE);
        CHECK(p1 != NULL && p2 != NULL && wcscmp(p1, p2) != 0);
        CHECK(p1 != NULL && wcsncmp(p1, (dir + L"\\pv").c_str(), dir.size() + 3) == 0 && wcslen(p1) == dir.size() + 11);
        LARGE_INTEGER size = {};
        CHECK(GetFileSizeEx(h1, &size) && size.QuadPart == 0);
        if (h1 != INVALID_HANDLE_VALUE)
            CloseHandle(h1);
        if (h2 != INVALID_HANDLE_VALUE)
            CloseHandle(h2);
        CHECK(p1 != NULL && DeleteFileW(p1));
        CHECK(p2 != NULL && DeleteFileW(p2));
        free(p1);
        free(p2);
        WCHAR* p3 = NULL;
        HANDLE h3 = INVALID_HANDLE_VALUE;
        err = 0;
        CHECK(!SalCreateTempNextToW((dir + L"\\missing\\x.png").c_str(), L"pv", &p3, &h3, &err) && err == ERROR_PATH_NOT_FOUND &&
              p3 == NULL && h3 == INVALID_HANDLE_VALUE); // no folder: an error, no endless search
    }

    // "gone" only when not found (an unreadable entry counts as present)
    CHECK(SalPathIsGoneW((dir + L"\\nothing.png").c_str()) && SalPathIsGoneW((dir + L"\\no\\nothing.png").c_str()));
    CHECK(!SalPathIsGoneW(dir.c_str()));

    // 2. a new target
    DeleteFileW(t.c_str());
    CHECK(newTemp(t, "NEW", &tmpFile));
    CHECK(SalReplaceWithTempW(t.c_str(), tmpFile.c_str(), FALSE, FALSE, &err) == srrDone);
    CHECK(get(t) == "NEW" && !exists(tmpFile));

    // 3. "new", but a file of that name appeared meanwhile: never overwritten unasked
    CHECK(put(other, "OTHER", FILE_ATTRIBUTE_NORMAL) && newTemp(other, "NEW", &tmpFile));
    err = 0;
    CHECK(SalReplaceWithTempW(other.c_str(), tmpFile.c_str(), FALSE, FALSE, &err) == srrFailedKept &&
          (err == ERROR_ALREADY_EXISTS || err == ERROR_FILE_EXISTS));
    CHECK(get(other) == "OTHER" && get(tmpFile) == "NEW"); // the caller deletes the temporary file
    CHECK(DeleteFileW(tmpFile.c_str()));

    // 4. an existing target: replaced, keeps its attributes (hidden)
    CHECK(put(t, "ORIG", FILE_ATTRIBUTE_HIDDEN | FILE_ATTRIBUTE_ARCHIVE) && newTemp(t, "NEW", &tmpFile));
    CHECK(SalReplaceWithTempW(t.c_str(), tmpFile.c_str(), TRUE, FALSE, &err) == srrDone);
    CHECK(get(t) == "NEW" && !exists(tmpFile) && (GetFileAttributesW(t.c_str()) & FILE_ATTRIBUTE_HIDDEN));

    // 5. a read-only target, not agreed: kept as it was
    CHECK(put(t, "ORIG", FILE_ATTRIBUTE_READONLY) && newTemp(t, "NEW", &tmpFile));
    err = 0;
    CHECK(SalReplaceWithTempW(t.c_str(), tmpFile.c_str(), TRUE, FALSE, &err) == srrFailedKept && err == ERROR_ACCESS_DENIED);
    CHECK(get(t) == "ORIG" && (GetFileAttributesW(t.c_str()) & FILE_ATTRIBUTE_READONLY) && get(tmpFile) == "NEW");

    // 6. ... agreed: replaced (the read-only attribute is gone, as the old delete + create left it)
    CHECK(SalReplaceWithTempW(t.c_str(), tmpFile.c_str(), TRUE, TRUE, &err) == srrDone);
    CHECK(get(t) == "NEW" && !exists(tmpFile) && !(GetFileAttributesW(t.c_str()) & FILE_ATTRIBUTE_READONLY));

    // 7. a read-only target held open without FILE_SHARE_DELETE (as the WIC decoder holds the shown
    //    image): kept, content and read-only attribute as they were
    CHECK(put(t, "ORIG", FILE_ATTRIBUTE_READONLY) && newTemp(t, "NEW", &tmpFile));
    {
        HANDLE held = CreateFileW(t.c_str(), GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
        CHECK(held != INVALID_HANDLE_VALUE);
        err = 0;
        CHECK(SalReplaceWithTempW(t.c_str(), tmpFile.c_str(), TRUE, TRUE, &err) == srrFailedKept && err == ERROR_SHARING_VIOLATION);
        if (held != INVALID_HANDLE_VALUE)
            CloseHandle(held);
    }
    CHECK(get(t) == "ORIG" && (GetFileAttributesW(t.c_str()) & FILE_ATTRIBUTE_READONLY) && get(tmpFile) == "NEW");
    CHECK(DeleteFileW(tmpFile.c_str()));

    // 8. the temporary file is missing: nothing happens to the target
    err = 0;
    CHECK(SalReplaceWithTempW(t.c_str(), tmpFile.c_str(), TRUE, TRUE, &err) == srrFailedKept && err != 0);
    CHECK(get(t) == "ORIG" && (GetFileAttributesW(t.c_str()) & FILE_ATTRIBUTE_READONLY));
    SetFileAttributesW(t.c_str(), FILE_ATTRIBUTE_NORMAL);

    // 9. the target vanished after the question: the new file takes its name
    CHECK(newTemp(t, "NEW2", &tmpFile) && DeleteFileW(t.c_str()));
    CHECK(SalReplaceWithTempW(t.c_str(), tmpFile.c_str(), TRUE, FALSE, &err) == srrDone);
    CHECK(get(t) == "NEW2" && !exists(tmpFile));

    // 10. a folder of the target's name is never replaced
    std::wstring sub = dir + L"\\sub.png";
    CHECK(CreateDirectoryW(sub.c_str(), NULL) && put(sub + L"\\inner.txt", "IN", FILE_ATTRIBUTE_NORMAL));
    CHECK(newTemp(sub, "NEW", &tmpFile));
    err = 0;
    CHECK(SalReplaceWithTempW(sub.c_str(), tmpFile.c_str(), TRUE, FALSE, &err) == srrFailedKept);
    CHECK((GetFileAttributesW(sub.c_str()) & FILE_ATTRIBUTE_DIRECTORY) && get(sub + L"\\inner.txt") == "IN" && get(tmpFile) == "NEW");
    CHECK(DeleteFileW(tmpFile.c_str()));

    // 11. another hard link of the target keeps the old content (only the name is replaced)
    std::wstring link = dir + L"\\link.png";
    CHECK(put(t, "ORIG", FILE_ATTRIBUTE_NORMAL) && CreateHardLinkW(link.c_str(), t.c_str(), NULL) && newTemp(t, "NEW", &tmpFile));
    CHECK(SalReplaceWithTempW(t.c_str(), tmpFile.c_str(), TRUE, FALSE, &err) == srrDone);
    CHECK(get(t) == "NEW" && get(link) == "ORIG");

    // 12. a path over MAX_PATH (the \\?\ form)
    std::wstring deep = dir;
    for (int i = 0; i < 6; i++)
    {
        deep += L"\\" + std::wstring(50, (WCHAR)(L'a' + i));
        CHECK(CreateDirectoryW(deep.c_str(), NULL));
    }
    std::wstring dt = deep + L"\\deep.png";
    CHECK(dt.size() > MAX_PATH + 4 && put(dt, "ORIG", FILE_ATTRIBUTE_NORMAL) && newTemp(dt, "NEW", &tmpFile));
    CHECK(SalReplaceWithTempW(dt.c_str(), tmpFile.c_str(), TRUE, FALSE, &err) == srrDone && get(dt) == "NEW" && !exists(tmpFile));

    // cleanup (explicit names only)
    DeleteFileW(dt.c_str());
    for (int i = 5; i >= 0; i--)
    {
        RemoveDirectoryW(deep.c_str());
        deep.resize(deep.rfind(L'\\'));
    }
    SetFileAttributesW(t.c_str(), FILE_ATTRIBUTE_NORMAL);
    DeleteFileW(t.c_str());
    DeleteFileW(link.c_str());
    DeleteFileW(other.c_str());
    DeleteFileW((sub + L"\\inner.txt").c_str());
    RemoveDirectoryW(sub.c_str());
    CHECK(RemoveDirectoryW(dir.c_str())); // nothing left behind (no stray temporary file)
}

// feature 106: a pack operation's output is never written over one of the files it packs
// (SalPackOutputIsSource / SalPackTargetInSelection, src/common/salsamefile.h)
static void TestPackSelf106()
{
    // --- pure: an output against a source ---
    CSalFileIdentity out = Id103(0x1234, 0x10, 8000, 5000, 4000);
    CHECK(SalPackOutputIsSource(out, out));                                      // the same file
    CHECK(SalPackOutputIsSource(out, Id103(0x1234, 0x10, 8000, 5000, 4000, 2))); // another hard link: same data
    CHECK(SalPackOutputIsSource(out, Id103(0x1234, 0x10, 0, 9, 9)));             // same id, metadata changed meanwhile
    CHECK(!SalPackOutputIsSource(out, Id103(0x1234, 0x11, 8000, 5000, 4000)));   // another file, equal metadata
    CHECK(!SalPackOutputIsSource(out, Id103(0x9999, 0x10, 8000, 5000, 4000)));   // same index, another volume
    // no usable ids (WebDAV, some servers): equal metadata is a "maybe" and counts as yes
    CSalFileIdentity noId = Id103(0, 0, 8000, 5000, 4000);
    CHECK(SalPackOutputIsSource(noId, Id103(0, 0, 8000, 5000, 4000)));
    CHECK(SalPackOutputIsSource(noId, Id103(0, 0, 8000, 5000, 0, 1, FALSE, 99))); // no creation time, other sub-second
    CHECK(!SalPackOutputIsSource(noId, Id103(0, 0, 8001, 5000, 4000)));           // other size
    CHECK(!SalPackOutputIsSource(noId, Id103(0, 0, 8000, 5001, 4000)));           // other last write
    CHECK(!SalPackOutputIsSource(noId, Id103(0, 0, 8000, 5000, 4000, 1, TRUE)));  // a directory is not the file
    CHECK(!SalPackOutputIsSource(Id103(1, 0, 8000, 5000, 4000), Id103(2, 0, 8000, 5000, 4000))); // two volumes
    CSalFileIdentity invalid;
    SalFileIdentityClear(&invalid);
    CHECK(!SalPackOutputIsSource(out, invalid) && !SalPackOutputIsSource(invalid, out)); // unreadable: not "the same"

    // --- pure: the Pack dialog's selection ---
    CSalFileIdentity arc = Id103(7, 0x50, 1000, 100, 90);
    CSalFileIdentity anc[3] = {Id103(7, 0x40, 0, 80, 70, 1, TRUE), Id103(7, 0x30, 0, 60, 50, 1, TRUE),
                               Id103(7, 0x05, 0, 10, 5, 1, TRUE)}; // parent, grandparent, root
    CHECK(SalPackTargetInSelection(arc, anc, 3, arc, FALSE));                                // the archive is a selected file
    CHECK(!SalPackTargetInSelection(arc, anc, 3, Id103(7, 0x51, 1000, 100, 90), FALSE));     // another selected file
    CHECK(SalPackTargetInSelection(arc, anc, 3, anc[0], TRUE));                              // its folder is selected
    CHECK(SalPackTargetInSelection(arc, anc, 3, anc[1], TRUE));                              // a folder above it is selected
    CHECK(!SalPackTargetInSelection(arc, anc, 3, Id103(7, 0x41, 0, 80, 70, 1, TRUE), TRUE)); // a sibling folder
    CHECK(!SalPackTargetInSelection(arc, anc, 3, arc, TRUE));                                // a "directory" equal to the file itself
    CHECK(!SalPackTargetInSelection(arc, NULL, 0, anc[0], TRUE));                            // no folders known
    CHECK(!SalPackTargetInSelection(arc, anc, 3, anc[0], FALSE));                            // a file item is compared with the archive only

    // --- real files (NTFS %TEMP%): two spellings and a hard link of one file are one source ---
    WCHAR tmp[MAX_PATH];
    DWORD n = GetTempPathW(MAX_PATH, tmp);
    if (n == 0 || n >= MAX_PATH)
    {
        printf("skipping the file part of TestPackSelf106 (no temp path)\n");
        return;
    }
    std::wstring dir = std::wstring(tmp) + L"saltests-106-" + std::to_wstring(GetCurrentProcessId());
    CHECK(CreateDirectoryW(dir.c_str(), NULL) || GetLastError() == ERROR_ALREADY_EXISTS);
    auto put = [](const std::wstring& p) -> BOOL
    {
        HANDLE h = CreateFileW(p.c_str(), GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
        DWORD w = 0;
        BOOL ok = h != INVALID_HANDLE_VALUE && WriteFile(h, "volume", 6, &w, NULL);
        if (h != INVALID_HANDLE_VALUE)
            CloseHandle(h);
        return ok;
    };
    std::wstring vol = dir + L"\\longvolumename.z01", other = dir + L"\\other.z01", link = dir + L"\\hardlink.bin";
    CHECK(put(vol) && put(other));
    CSalFileIdentity iVol, iAlias, iOther, iLink;
    CHECK(SalGetFileIdentityW(vol.c_str(), FALSE, &iVol));
    CHECK(SalGetFileIdentityW(other.c_str(), FALSE, &iOther));
    CHECK(!SalPackOutputIsSource(iVol, iOther)); // equal size, another file
    WCHAR shortName[MAX_PATH];
    DWORD sn = GetShortPathNameW(vol.c_str(), shortName, MAX_PATH);
    if (sn > 0 && sn < MAX_PATH && _wcsicmp(shortName, vol.c_str()) != 0)
    {
        CHECK(SalGetFileIdentityW(shortName, FALSE, &iAlias));
        CHECK(SalPackOutputIsSource(iAlias, iVol)); // the 8.3 spelling
    }
    else
        printf("TestPackSelf106: no 8.3 names in %ls - the alias check is skipped\n", tmp);
    std::wstring upper = vol;
    for (auto& c : upper)
        c = (WCHAR)towupper(c);
    CHECK(SalGetFileIdentityW(upper.c_str(), FALSE, &iAlias) && SalPackOutputIsSource(iAlias, iVol)); // another case
    if (CreateHardLinkW(link.c_str(), vol.c_str(), NULL))
    {
        CHECK(SalGetFileIdentityW(link.c_str(), FALSE, &iLink));
        CHECK(SalPackOutputIsSource(iLink, iVol)); // a truncation through the link reaches the source's data
        DeleteFileW(link.c_str());
    }
    CSalFileIdentity iDir;
    CHECK(SalGetFileIdentityW(dir.c_str(), FALSE, &iDir));
    CHECK(SalPackTargetInSelection(iVol, &iDir, 1, iDir, TRUE)); // the archive's own folder selected
    DeleteFileW(vol.c_str());
    DeleteFileW(other.c_str());
    CHECK(RemoveDirectoryW(dir.c_str()));
}

// feature 107: a folder copied or moved onto another path of itself, and one hard link reached
// through an alias (SalDirIsSame, SalDirChainHolds, SalSameDirEntry, SalDecideExistingTargetEx -
// src/common/salsamefile.h; SalSameDirEntryU8, SalGetFinalPathU8Alloc - salfileio)
static void TestFolderAlias107()
{
    // --- pure: is the target folder the source folder? ---
    CSalFileIdentity f = Id103(0x77, 0x40, 0, 5000, 4000, 1, TRUE);
    CHECK(SalDirIsSame(f, f, FALSE));                                                 // the same id
    CHECK(SalDirIsSame(f, Id103(0x77, 0x40, 0, 9, 9, 1, TRUE), FALSE));               // same id, times read later
    CHECK(!SalDirIsSame(f, Id103(0x77, 0x41, 0, 5000, 4000, 1, TRUE), FALSE));        // a sibling with equal times
    CHECK(!SalDirIsSame(f, Id103(0x78, 0x40, 0, 5000, 4000, 1, TRUE), TRUE));         // another volume
    CSalFileIdentity dav = Id103(0, 0, 0, 5000, 4000, 1, TRUE);                       // WebDAV: no ids
    CHECK(SalDirIsSame(dav, Id103(0, 0, 0, 5000, 4000, 1, TRUE, 99), FALSE));         // equal kind + seconds: a "maybe" = yes
    CHECK(SalDirIsSame(dav, Id103(0, 0, 0, 5000, 0, 1, TRUE), FALSE));                // no creation time on one side
    CHECK(!SalDirIsSame(dav, Id103(0, 0, 0, 5001, 4000, 1, TRUE), FALSE));            // another last write
    CHECK(!SalDirIsSame(dav, Id103(0, 0, 0, 5000, 4000, 1, FALSE), FALSE));           // a file is not the folder
    CHECK(!SalDirIsSame(Id103(1, 0, 0, 5, 4, 1, TRUE), Id103(2, 0, 0, 5, 4, 1, TRUE), TRUE)); // two volumes, no ids
    CSalFileIdentity none;
    SalFileIdentityClear(&none);
    CHECK(SalDirIsSame(f, none, TRUE) && SalDirIsSame(none, f, TRUE));   // unreadable: a move refuses
    CHECK(!SalDirIsSame(f, none, FALSE) && !SalDirIsSame(none, f, FALSE)); // ... a copy goes on
    CHECK(SalDirIsSame(none, none, TRUE) && !SalDirIsSame(none, none, FALSE));

    // --- pure: the target folder or a folder above it is the source (a move into itself) ---
    CSalFileIdentity chain[4] = {Id103(0x77, 0x42, 0, 70, 60, 1, TRUE),  // T = F\sub
                                 Id103(0x77, 0x40, 0, 5000, 4000, 1, TRUE), // F
                                 Id103(0x77, 0x30, 0, 30, 20, 1, TRUE),     // F's parent
                                 Id103(0x77, 0x05, 0, 10, 5, 1, TRUE)};     // the root
    CHECK(SalDirChainHolds(f, chain, 4) == 1);
    CHECK(SalDirChainHolds(chain[0], chain, 4) == 0);                        // T = F itself
    CHECK(SalDirChainHolds(Id103(0x77, 0x41, 0, 5000, 4000, 1, TRUE), chain, 4) == -1); // a sibling: a legitimate move
    CHECK(SalDirChainHolds(f, chain + 2, 2) == -1);                          // F's parent as the target: not "into itself"
    CHECK(SalDirChainHolds(f, NULL, 0) == -1);
    CHECK(SalDirChainHolds(none, chain, 4) == -1);                           // an unreadable source is not matched
    CSalFileIdentity davChain[2] = {Id103(0, 0, 0, 70, 60, 1, TRUE), Id103(0, 0, 0, 5000, 4000, 1, TRUE)};
    CHECK(SalDirChainHolds(dav, davChain, 2) == 1);
    // without ids the name must agree too: siblings unpacked in one second share their times
    BOOL nm[2] = {TRUE, FALSE};
    CHECK(SalDirChainHolds(dav, davChain, 2, nm) == -1);
    nm[1] = TRUE;
    CHECK(SalDirChainHolds(dav, davChain, 2, nm) == 1);
    CHECK(!SalDirIsSame(dav, Id103(0, 0, 0, 5000, 4000, 1, TRUE), FALSE, FALSE)); // equal times, another name
    CHECK(SalDirIsSame(f, f, FALSE, FALSE));                                         // ids decide, the name is not asked
    CHECK(!SalDirIsSame(f, Id103(0x77, 0x41, 0, 5000, 4000, 1, TRUE), FALSE, TRUE));
    CHECK(SalDirIsSame(none, none, TRUE, FALSE));                                    // unreadable: still fail-closed
    // a folder with an id against one without (local / SMB against WebDAV): two file systems
    CHECK(!SalDirIsSame(Id103(0x77, 0x40, 0, 5000, 4000, 1, TRUE), dav, TRUE));
    CHECK(!SalDirIsSame(dav, Id103(0x77, 0x40, 0, 5000, 4000, 1, TRUE), TRUE));
    CHECK(!SalDirIsSame(Id103(0x77, 0x40, 0, 5000, 0, 1, TRUE), Id103(0, 0, 0, 5000, 0, 1, TRUE), TRUE)); // kept times, no creation time
    CHECK(SalHasUsableFileId(f) && !SalHasUsableFileId(dav) && !SalHasUsableFileId(none));
    // the name rule: case and Unicode normalization (a WebDAV / macOS spelling), nothing else
    CHECK(SalNamesLooselyEqualU8("cafe\xCC\x81", "Caf\xC3\xA9"));
    CHECK(SalNamesLooselyEqualU8("F", "f"));
    CHECK(SalNamesLooselyEqualU8("\xD0\x9F\xD0\xB0\xD0\xBF\xD0\xBA\xD0\xB0", "\xD0\xBF\xD0\xB0\xD0\xBF\xD0\xBA\xD0\xB0")); // Papka / papka
    CHECK(!SalNamesLooselyEqualU8("F", "G"));
    CHECK(!SalNamesLooselyEqualU8("", "F"));
    CHECK(!SalNamesLooselyEqualU8("cafe", "caf\xC3\xA9"));

    // --- review SF1: snapshots (shadow copies, Previous Versions) and FAT ids ---
    DWORD tag12 = SalSnapshotTagFromPath(L"\\Device\\HarddiskVolumeShadowCopy12\\x\\F");
    CHECK(tag12 != 0);
    CHECK(SalSnapshotTagFromPath(L"\\Device\\harddiskvolumeshadowcopy12") == tag12);          // case, no tail
    CHECK(SalSnapshotTagFromPath(L"\\\\?\\GLOBALROOT\\Device\\HarddiskVolumeShadowCopy12\\y") == tag12);
    CHECK(SalSnapshotTagFromPath(L"\\Device\\HarddiskVolumeShadowCopy13\\x") != tag12);        // another snapshot
    CHECK(SalSnapshotTagFromPath(L"\\Device\\HarddiskVolume3\\x\\F") == 0);                     // the live volume
    CHECK(SalSnapshotTagFromPath(L"\\x\\MyHarddiskVolumeShadowCopy1\\F") == 0);                 // not a component start
    CHECK(SalSnapshotTagFromPath(L"\\Device\\HarddiskVolumeShadowCopy\\x") == 0);              // no number
    DWORD gmt = SalSnapshotTagFromPath(L"\\\\localhost\\C$\\@GMT-2026.10.04-12.00.00\\x\\F");
    CHECK(gmt != 0 && gmt == SalSnapshotTagFromPath(L"\\\\127.0.0.1\\C$\\@gmt-2026.10.04-12.00.00"));
    CHECK(gmt != SalSnapshotTagFromPath(L"\\\\localhost\\C$\\@GMT-2026.10.05-12.00.00\\x"));
    CHECK(SalSnapshotTagFromPath(L"\\\\localhost\\C$\\@GMT-old\\x") == 0);                      // a folder named like it
    CHECK(SalSnapshotTagFromPath(L"C:\\x\\F") == 0 && SalSnapshotTagFromPath(NULL) == 0);
    CHECK(SalFsNameHasWeakIds(L"FAT") && SalFsNameHasWeakIds(L"FAT32") && SalFsNameHasWeakIds(L"exFAT"));
    CHECK(!SalFsNameHasWeakIds(L"NTFS") && !SalFsNameHasWeakIds(L"ReFS") && !SalFsNameHasWeakIds(NULL));
    CSalFileIdentity live = Id103(0x77, 0x40, 0, 5000, 4000, 1, TRUE), snap = live;
    snap.SnapshotTag = tag12;
    CHECK(!SalDirIsSame(live, snap, TRUE) && !SalDirIsSame(snap, live, TRUE)); // restore from a snapshot merges
    CSalFileIdentity snap2 = snap;
    CHECK(SalDirIsSame(snap, snap2, FALSE));                                    // two paths into one snapshot
    snap2.SnapshotTag = SalSnapshotTagFromPath(L"\\Device\\HarddiskVolumeShadowCopy13");
    CHECK(!SalDirIsSame(snap, snap2, FALSE));                                   // two snapshots
    CSalFileIdentity fat = live;
    fat.WeakIds = TRUE;
    CHECK(SalDirIsSame(fat, fat, FALSE));                                       // FAT: equal id and times
    CHECK(!SalDirIsSame(fat, Id103(0x77, 0x40, 0, 5001, 4000, 1, TRUE), FALSE)); // FAT: equal id, other times
    CHECK(SalDirIsSame(live, Id103(0x77, 0x40, 0, 5001, 4000, 1, TRUE), FALSE)); // NTFS/SMB: the id decides (stale SMB times)
    CHECK(SalSameDirEntry(live, snap, L"a.txt", L"a.txt") == sseNo);            // a hard link restored from a snapshot
    CSalFileIdentity unk = live;
    unk.SnapshotUnknown = TRUE;                                                 // the device could not be read
    CHECK(SalDirIsSame(unk, snap, FALSE) && SalDirIsSame(snap, unk, FALSE));    // cannot tell: the ids decide (fail closed)
    CHECK(SalSameDirEntry(unk, snap, L"a.txt", L"a.txt") == sseYes);

    // --- review SF2 + re-check: without ids the RESOLVED path below the server must agree ---
    auto canon = [](const char* p) -> std::string
    {
        char* c = SalCanonicalBelowServerU8Alloc(p);
        std::string s = c != NULL ? c : "<null>";
        free(c);
        return s;
    };
    CHECK(canon("\\\\localhost@18107\\dav\\a\\F") == "\\\\dav\\a\\F");
    CHECK(canon("\\\\127.0.0.1@18107\\dav\\a\\F\\") == "\\\\dav\\a\\F");                // another server name, trailing backslash
    CHECK(canon("\\\\localhost@18107\\DavWWWRoot\\dav\\a\\F") == "\\\\dav\\a\\F");     // the redirector's root form
    CHECK(canon("\\\\host@SSL@443\\davwwwroot\\dav\\a") == "\\\\dav\\a");              // @SSL / port, case of DavWWWRoot
    CHECK(canon("\\\\host\\DavWWWRootX\\a") == "\\\\DavWWWRootX\\a");                  // only the whole component
    CHECK(canon("C:\\x\\F\\") == "C:\\x\\F" && canon("C:\\") == "C:\\");
    CHECK(canon("\\\\server") == "<null>" && canon("\\\\server\\") == "<null>" && canon("\\\\host\\DavWWWRoot") == "<null>");
    CHECK(canon("relative\\F") == "<null>" && canon(NULL) == "<null>");
    CHECK(SalNamesLooselyEqualU8(canon("\\\\s\\dav\\x\\cafe\xCC\x81\\F").c_str(), canon("\\\\t@1\\DavWWWRoot\\dav\\x\\Caf\xC3\xA9\\F").c_str()));
    CHECK(!SalNamesLooselyEqualU8(canon("\\\\s\\dav\\a\\F").c_str(), canon("\\\\s\\dav\\b\\F").c_str())); // a backup in another folder
    CHECK(!SalNamesLooselyEqualU8(canon("\\\\s\\dav\\a\\F").c_str(), canon("X:\\dav\\a\\F").c_str()));    // unresolved letter vs UNC

    // --- pure: one directory entry or two (hard links) ---
    CSalFileIdentity dirA = Id103(0x77, 0x30, 0, 30, 20, 1, TRUE), dirB = Id103(0x77, 0x31, 0, 30, 20, 1, TRUE);
    CHECK(SalSameDirEntry(dirA, dirA, L"a.txt", L"a.txt") == sseYes);  // one folder, one stored name
    CHECK(SalSameDirEntry(dirA, dirA, L"a.txt", L"b.txt") == sseNo);   // another link in the same folder
    CHECK(SalSameDirEntry(dirA, dirA, L"a.txt", L"A.txt") == sseNo);   // stored names differ only in case: a case-sensitive folder
    CHECK(SalSameDirEntry(dirA, dirB, L"a.txt", L"a.txt") == sseNo);   // a link in another folder
    CHECK(SalSameDirEntry(dirA, none, L"a.txt", L"a.txt") == sseUnknown);
    CHECK(SalSameDirEntry(dirA, dirA, NULL, L"a.txt") == sseUnknown);
    CHECK(SalSameDirEntry(dav, dav, L"a.txt", L"a.txt") == sseUnknown); // no ids on the folders
    CHECK(SalSameDirEntry(Id103(1, 0, 0, 5, 4, 1, TRUE), Id103(2, 0, 0, 5, 4, 1, TRUE), L"a", L"a") == sseNo); // two volumes

    // --- pure: the copy decision with a hard-linked source ---
    CSalFileIdentity hl = Id103(0x77, 0x90, 300, 500, 400, 2);
    CHECK(SalDecideNeedsSameEntry(TRUE, ERROR_FILE_EXISTS, hl, hl));
    CHECK(SalDecideNeedsSameEntry(TRUE, ERROR_ALREADY_EXISTS, hl, hl));
    CHECK(!SalDecideNeedsSameEntry(FALSE, ERROR_FILE_EXISTS, hl, hl));                          // a rename: the temporary-name route
    CHECK(!SalDecideNeedsSameEntry(TRUE, ERROR_ACCESS_DENIED, hl, hl));
    CHECK(!SalDecideNeedsSameEntry(TRUE, ERROR_FILE_EXISTS, Id103(0x77, 0x90, 300, 500, 400), Id103(0x77, 0x90, 300, 500, 400))); // one link
    CHECK(!SalDecideNeedsSameEntry(TRUE, ERROR_FILE_EXISTS, hl, Id103(0x77, 0x91, 300, 500, 400, 2))); // another file
    CHECK(SalDecideExistingTargetEx(TRUE, ERROR_FILE_EXISTS, hl, hl, sseNo) == setaLegacy);       // another link: as before
    CHECK(SalDecideExistingTargetEx(TRUE, ERROR_FILE_EXISTS, hl, hl, sseYes) == setaRefuseSame);  // this link through an alias
    CHECK(SalDecideExistingTargetEx(TRUE, ERROR_FILE_EXISTS, hl, hl, sseUnknown) == setaRefuseSame); // cannot tell: refuse
    CHECK(SalDecideExistingTargetEx(FALSE, ERROR_FILE_EXISTS, hl, hl, sseYes) == setaViaTempName); // rename unchanged
    CHECK(SalDecideExistingTargetEx(TRUE, ERROR_ACCESS_DENIED, hl, hl, sseYes) == setaLegacy);
    // SalDecideExistingTarget (the plug-ins) is the 103 rule: sseNo
    CSalFileIdentity set[] = {hl, Id103(0x77, 0x90, 300, 500, 400), Id103(0x77, 0x91, 300, 500, 400), Id103(0, 0, 300, 500, 400), none};
    for (int a = 0; a < 5; a++)
        for (int b = 0; b < 5; b++)
            for (int c = 0; c < 2; c++)
                CHECK(SalDecideExistingTarget(c, ERROR_FILE_EXISTS, set[a], set[b]) ==
                      SalDecideExistingTargetEx(c, ERROR_FILE_EXISTS, set[a], set[b], sseNo));

    // --- real folders and files (NTFS %TEMP%) ---
    WCHAR tmp[MAX_PATH];
    DWORD n = GetTempPathW(MAX_PATH, tmp);
    if (n == 0 || n >= MAX_PATH)
    {
        printf("skipping the file part of TestFolderAlias107 (no temp path)\n");
        return;
    }
    std::wstring base = std::wstring(tmp) + L"saltests-107-" + std::to_wstring(GetCurrentProcessId());
    std::wstring par = base + L"\\parentlongname", F = par + L"\\F", sub = F + L"\\sub", G = par + L"\\G", other = base + L"\\other";
    CHECK(CreateDirectoryW(base.c_str(), NULL) && CreateDirectoryW(par.c_str(), NULL) && CreateDirectoryW(F.c_str(), NULL) &&
          CreateDirectoryW(sub.c_str(), NULL) && CreateDirectoryW(G.c_str(), NULL) && CreateDirectoryW(other.c_str(), NULL));
    auto u8 = [](const std::wstring& w) -> std::string
    {
        char* p = SalWToU8Alloc(w.c_str());
        std::string s = p != NULL ? p : "";
        free(p);
        return s;
    };
    auto idOf = [&](const std::wstring& w, CSalFileIdentity* id) -> BOOL { return SalGetFileIdentity(u8(w).c_str(), FALSE, id); };
    CSalFileIdentity iF, iAlias, iG, iSub;
    CHECK(idOf(F, &iF) && idOf(G, &iG) && idOf(sub, &iSub));
    CHECK(!SalDirIsSame(iF, iG, TRUE)); // two folders created in the same second are told apart by their ids
    {
        CSalFileIdentity t;
        CHECK(SalGetFileIdentity(u8(F).c_str(), FALSE, &t, TRUE) && t.SnapshotTag == 0 && !t.SnapshotUnknown && !t.WeakIds); // live NTFS
        CHECK(SalDirIsSame(iF, t, FALSE));
    }
    std::wstring upper = F;
    for (auto& ch : upper)
        ch = (WCHAR)towupper(ch);
    // the path rule resolves both sides first (re-check of 107): one folder by two spellings
    CHECK(SalPathsBelowServerLooselyEqualU8(u8(F).c_str(), u8(upper).c_str()));
    CHECK(!SalPathsBelowServerLooselyEqualU8(u8(F).c_str(), u8(G).c_str()));
    CHECK(SalPathsBelowServerLooselyEqualU8(u8(base + L"\\gone1\\X").c_str(), u8(base + L"\\gone2\\X").c_str()));  // unresolved: the names
    CHECK(!SalPathsBelowServerLooselyEqualU8(u8(base + L"\\gone1\\X").c_str(), u8(base + L"\\gone2\\Y").c_str()));
    CHECK(idOf(upper, &iAlias) && SalDirIsSame(iF, iAlias, FALSE)); // another case
    WCHAR shortPar[MAX_PATH];
    DWORD sn = GetShortPathNameW(par.c_str(), shortPar, MAX_PATH);
    BOOL haveShort = sn > 0 && sn < MAX_PATH && _wcsicmp(shortPar, par.c_str()) != 0;
    if (haveShort)
    {
        CHECK(idOf(std::wstring(shortPar) + L"\\F", &iAlias) && SalDirIsSame(iF, iAlias, FALSE)); // the 8.3 spelling of a folder above
        char* fin = SalGetFinalPathU8Alloc(u8(std::wstring(shortPar) + L"\\F").c_str());
        CHECK(fin != NULL && SalPathEqualOrdinalCI(fin, u8(F).c_str())); // resolved to the long path
        free(fin);
    }
    else
        printf("TestFolderAlias107: no 8.3 names in %ls - the short-name checks are skipped\n", tmp);
    if (tmp[1] == L':')
    {
        std::wstring unc = std::wstring(L"\\\\localhost\\") + tmp[0] + L"$" + F.substr(2);
        if (idOf(unc, &iAlias) && iAlias.Has64)
            CHECK(SalDirIsSame(iF, iAlias, FALSE)); // the loopback administrative share
        else
            printf("TestFolderAlias107: %ls not reachable - the UNC check is skipped\n", unc.c_str());
    }
    // the chain of F\sub: F is in it (a move into F\sub is refused), G's is not
    {
        std::vector<CSalFileIdentity> ids;
        std::string up = u8(sub);
        while (true)
        {
            CSalFileIdentity a;
            if (SalGetFileIdentity(up.c_str(), FALSE, &a))
                ids.push_back(a);
            size_t cut = up.find_last_of('\\');
            if (cut == std::string::npos || cut < 3)
                break;
            up.resize(cut);
        }
        CHECK(ids.size() >= 3);
        int cnt = (int)ids.size();
        CHECK(SalDirChainHolds(iF, ids.data(), cnt) == 1);
        CHECK(SalDirChainHolds(iSub, ids.data(), cnt) == 0);
        CHECK(SalDirChainHolds(iG, ids.data(), cnt) == -1);
    }
    char* fin = SalGetFinalPathU8Alloc(u8(upper).c_str());
    CHECK(fin != NULL && strcmp(fin, u8(F).c_str()) == 0); // the stored case (temp path assumed stored as returned)
    free(fin);
    CHECK(SalGetFinalPathU8Alloc(u8(base + L"\\missing").c_str()) == NULL);
    // hard links: one entry or two
    std::wstring a = par + L"\\alongname.txt", b = par + L"\\b.txt", c = other + L"\\c.txt";
    {
        HANDLE h = CreateFileW(a.c_str(), GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
        CHECK(h != INVALID_HANDLE_VALUE);
        if (h != INVALID_HANDLE_VALUE)
            CloseHandle(h);
    }
    if (CreateHardLinkW(b.c_str(), a.c_str(), NULL) && CreateHardLinkW(c.c_str(), a.c_str(), NULL))
    {
        CHECK(SalSameDirEntryU8(u8(a).c_str(), u8(b).c_str()) == sseNo);  // another link, same folder
        CHECK(SalSameDirEntryU8(u8(a).c_str(), u8(c).c_str()) == sseNo);  // another link, another folder
        CHECK(SalSameDirEntryU8(u8(a).c_str(), u8(a).c_str()) == sseYes);
        std::wstring aUp = a;
        for (auto& ch : aUp)
            ch = (WCHAR)towupper(ch);
        CHECK(SalSameDirEntryU8(u8(a).c_str(), u8(aUp).c_str()) == sseYes); // this link under another case
        if (haveShort)
        {
            CHECK(SalSameDirEntryU8(u8(a).c_str(), u8(std::wstring(shortPar) + L"\\alongname.txt").c_str()) == sseYes); // through the 8.3 folder
            WCHAR shortA[MAX_PATH];
            DWORD sa = GetShortPathNameW(a.c_str(), shortA, MAX_PATH);
            if (sa > 0 && sa < MAX_PATH)
                CHECK(SalSameDirEntryU8(u8(a).c_str(), u8(shortA).c_str()) == sseYes); // its own 8.3 name
        }
        if (tmp[1] == L':')
        {
            std::wstring uncA = std::wstring(L"\\\\localhost\\") + tmp[0] + L"$" + a.substr(2);
            CSalFileIdentity ua;
            if (SalGetFileIdentity(u8(uncA).c_str(), FALSE, &ua) && ua.Has64)
            {
                CHECK(SalSameDirEntryU8(u8(a).c_str(), u8(uncA).c_str()) == sseYes);
                std::wstring uncB = std::wstring(L"\\\\localhost\\") + tmp[0] + L"$" + b.substr(2);
                CHECK(SalSameDirEntryU8(u8(a).c_str(), u8(uncB).c_str()) == sseNo);
            }
        }
        CHECK(SalSameDirEntryU8(u8(a).c_str(), u8(par + L"\\missing.txt").c_str()) == sseUnknown);
        CSalFileIdentity ia, ib;
        CHECK(idOf(a, &ia) && idOf(b, &ib) && SalDecideNeedsSameEntry(TRUE, ERROR_FILE_EXISTS, ia, ib));
    }
    else
        printf("TestFolderAlias107: no hard link could be created - the link checks on disk are skipped\n");
    // cleanup (explicit names only)
    DeleteFileW(c.c_str());
    DeleteFileW(b.c_str());
    DeleteFileW(a.c_str());
    RemoveDirectoryW(sub.c_str());
    RemoveDirectoryW(F.c_str());
    RemoveDirectoryW(G.c_str());
    RemoveDirectoryW(par.c_str());
    RemoveDirectoryW(other.c_str());
    CHECK(RemoveDirectoryW(base.c_str()));
}

// feature 108: an edited archive member is identified by its temporary copy on disk, by the file
// system's rule (SalEditedCopyIsSame, SalEditedCopiesPackTogether - src/common/salarcedit.h)
static BOOL LegacyFoldEqual108(const char* a, const char* b) // the old StrICmp: CharLowerA per byte
{
    for (;; a++, b++)
    {
        BYTE la = (BYTE)(UINT_PTR)CharLowerA((LPSTR)(UINT_PTR)(BYTE)*a);
        BYTE lb = (BYTE)(UINT_PTR)CharLowerA((LPSTR)(UINT_PTR)(BYTE)*b);
        if (la != lb)
            return FALSE;
        if (*a == 0)
            return TRUE;
    }
}

static void TestArchiveEdit108()
{
    const char* tmp = "C:\\Users\\u\\AppData\\Local\\Temp\\SAL1A2.tmp";
    // --- names: different members (the file system keeps them apart) are different copies; on
    //     CP1250 the old byte fold made each of these pairs one item (the defect)
    static const char* const differ[][2] = {
        {"\xC4\xA5" ".txt", "\xC4\xB9" ".txt"},             // h-circumflex / L-acute (C4 A5 / C4 B9)
        {"\xC3\x8D" "tem.txt", "\xC3\x9D" "tem.txt"},       // I-acute / Y-acute
        {"\xC5\xBE" ".txt", "\xC5\xBC" ".txt"},             // z-caron / z-dot
        {"\xE4\xB9\x9D" ".txt", "\xE4\xB9\x8D" ".txt"},     // two CJK ideographs (U+4E5D / U+4E4D)
        {"\xD0\xBC" ".txt", "\xD0\xBE" ".txt"},             // Cyrillic em / o
        {"\xC4\x8C" ".txt", "\xC4\x9C" ".txt"},             // C-caron / G-circumflex
        {"\xC3\xA9" ".txt", "e\xCC\x81" ".txt"},            // NFC / NFD: two names on NTFS
        {"a.txt", "b.txt"},
    };
    for (int i = 0; i < _countof(differ); i++)
    {
        CHECK(!SalEditedCopyIsSame(tmp, differ[i][0], tmp, differ[i][1]));
        CHECK(!SalEditedCopyIsSame(tmp, differ[i][1], tmp, differ[i][0]));
        CHECK(SalEditedCopyIsSame(tmp, differ[i][0], tmp, differ[i][0])); // one member opened twice
    }
    if (GetACP() == 1250) // the measured defect: the legacy fold merged the first six pairs
    {
        for (int i = 0; i < 6; i++)
            CHECK(LegacyFoldEqual108(differ[i][0], differ[i][1]));
    }
    // --- names equal by the file system's rule are ONE file on disk: one copy (the disk cache never
    //     puts two members there under such names - CCacheDirData::ContainTmpName)
    static const char* const same[][2] = {
        {"\xC4\x8C" ".txt", "\xC4\x8D" ".txt"},   // C-caron / c-caron
        {"\xC8\xBA" ".txt", "\xE2\xB1\xA5" ".txt"}, // A-stroke (2 bytes) / a-stroke (3 bytes)
        {"A.txt", "a.txt"},
        {"README.md", "readme.MD"},
    };
    for (int i = 0; i < _countof(same); i++)
        CHECK(SalEditedCopyIsSame(tmp, same[i][0], tmp, same[i][1]));
    // --- folders: the path rule (one leading/trailing backslash ignored, case by the file system)
    CHECK(SalEditedCopyIsSame(tmp, "x.txt", "c:\\users\\U\\appdata\\local\\temp\\sal1a2.TMP\\", "X.TXT"));
    CHECK(!SalEditedCopyIsSame(tmp, "x.txt", "C:\\Users\\u\\AppData\\Local\\Temp\\SAL1A3.tmp", "x.txt"));
    CHECK(!SalEditedCopyIsSame("D:\\c\\\xC4\xA5\\SAL1.tmp", "x.txt", "D:\\c\\\xC4\xB9\\SAL1.tmp", "x.txt")); // a plug-in's own cache root
    CHECK(SalEditedCopyIsSame("D:\\c\\\xC4\x8C\\SAL1.tmp", "x.txt", "D:\\C\\\xC4\x8D\\sal1.tmp", "x.txt"));
    // --- one packer call: the folder in the archive byte for byte, the folder on disk by the rule
    CHECK(SalEditedCopiesPackTogether("", tmp, "", tmp));
    CHECK(SalEditedCopiesPackTogether("dir\\sub", tmp, "dir\\sub", "c:\\USERS\\u\\AppData\\Local\\Temp\\SAL1A2.tmp"));
    CHECK(!SalEditedCopiesPackTogether("test", tmp, "Test", tmp)); // test\A.txt and Test\b.txt: two calls
    CHECK(!SalEditedCopiesPackTogether("\xC4\xA5", tmp, "\xC4\xB9", tmp));
    CHECK(!SalEditedCopiesPackTogether("", tmp, "", "C:\\Users\\u\\AppData\\Local\\Temp\\SAL1A3.tmp"));
    // --- the stored spelling of a folder replaces the typed one only when they are one name by the
    //     file system's rule (GetZIPPathAsStored108, fileswn6.cpp)
    CHECK(SalArcTakeStoredSpelling("Dir", 3, "DIR", 3));
    CHECK(SalArcTakeStoredSpelling("Dir", 3, "Dir", 3));
    CHECK(SalArcTakeStoredSpelling("\xC4\x8C", 2, "\xC4\x8D", 2));           // C-caron / c-caron
    CHECK(SalArcTakeStoredSpelling("slo\xC5\xBD" "ka", 6, "SLO\xC5\xBE" "KA", 6)); // Z-caron / z-caron
    CHECK(!SalArcTakeStoredSpelling("\xC4\xA5", 2, "\xC4\xB9", 2));          // merged by the byte fold only
    CHECK(!SalArcTakeStoredSpelling("\xC3\x8D", 2, "\xC3\x9D", 2));
    CHECK(!SalArcTakeStoredSpelling("\xC8\xBA", 2, "\xE2\xB1\xA5", 3));      // one name, other lengths: not in place
    CHECK(!SalArcTakeStoredSpelling("Dir", 3, "Dirx", 4));
    CHECK(!SalArcTakeStoredSpelling("Dir", 3, "Dix", 3));

    // --- real files (NTFS %TEMP%): the rule agrees with the file system
    WCHAR t[MAX_PATH];
    DWORD n = GetTempPathW(MAX_PATH, t);
    if (n == 0 || n >= MAX_PATH)
    {
        printf("skipping the file part of TestArchiveEdit108 (no temp path)\n");
        return;
    }
    std::wstring dir = std::wstring(t) + L"saltests-108-" + std::to_wstring(GetCurrentProcessId());
    CHECK(CreateDirectoryW(dir.c_str(), NULL) || GetLastError() == ERROR_ALREADY_EXISTS);
    char dirU8[3 * MAX_PATH];
    CHECK(SalWToU8(dir.c_str(), -1, dirU8, sizeof(dirU8)) != 0);
    std::vector<std::wstring> created;
    // creates 'second' after 'first' in one folder: TRUE when the file system made two files
    auto twoFiles = [&](const char* first, const char* second) -> BOOL
    {
        WCHAR w1[64], w2[64];
        if (SalU8ToW(first, -1, w1, 64) == 0 || SalU8ToW(second, -1, w2, 64) == 0)
            return FALSE;
        std::wstring p1 = dir + L"\\" + w1, p2 = dir + L"\\" + w2;
        HANDLE h1 = CreateFileW(p1.c_str(), GENERIC_WRITE, 0, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
        if (h1 == INVALID_HANDLE_VALUE)
            return FALSE;
        CloseHandle(h1);
        created.push_back(p1);
        HANDLE h2 = CreateFileW(p2.c_str(), GENERIC_WRITE, 0, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
        if (h2 == INVALID_HANDLE_VALUE)
            return FALSE; // ERROR_FILE_EXISTS: the same file
        CloseHandle(h2);
        created.push_back(p2);
        return TRUE;
    };
    for (int i = 0; i < _countof(differ); i++)
    {
        BOOL two = twoFiles(differ[i][0], differ[i][1]);
        CHECK(two);
        CHECK(two == !SalEditedCopyIsSame(dirU8, differ[i][0], dirU8, differ[i][1]));
        for (auto& p : created)
            DeleteFileW(p.c_str());
        created.clear();
    }
    for (int i = 0; i < _countof(same); i++)
    {
        BOOL two = twoFiles(same[i][0], same[i][1]);
        CHECK(!two);
        CHECK(two == !SalEditedCopyIsSame(dirU8, same[i][0], dirU8, same[i][1]));
        for (auto& p : created)
            DeleteFileW(p.c_str());
        created.clear();
    }
    CHECK(RemoveDirectoryW(dir.c_str()));
}

// feature 153: the Archive Update dialog's mark of a member another program changed in the archive
// since the F4 (src/common/salarcedit.h)
static void TestMemberChanged153()
{
    const unsigned __int64 t = 133000000000000000ULL, s = 21;
    // --- the archive file: the same time and size = no new listing; anything unknown or different = look
    CHECK(!SalArchiveChangedSinceEdit(TRUE, t, s, TRUE, t, s));
    CHECK(SalArchiveChangedSinceEdit(TRUE, t, s, TRUE, t + 1, s)); // rewritten in place, same size
    CHECK(SalArchiveChangedSinceEdit(TRUE, t, s, TRUE, t, s + 1)); // grown with the same time
    CHECK(SalArchiveChangedSinceEdit(FALSE, t, s, TRUE, t, s));    // unknown at the F4
    CHECK(SalArchiveChangedSinceEdit(TRUE, t, s, FALSE, t, s));    // cannot be read now
    CHECK(SalArchiveChangedSinceEdit(FALSE, 0, 0, FALSE, 0, 0));
    // --- the member in the new listing: the exact name first, then the file system's rule; never a guess
    CHECK(SalEditedMemberFound(1, 0) == semnListed);
    CHECK(SalEditedMemberFound(1, 1) == semnListed); // "x.txt" exact beside a new "X.TXT": the exact one
    CHECK(SalEditedMemberFound(0, 1) == semnListed); // stored as "X.txt" now
    CHECK(SalEditedMemberFound(0, 0) == semnMissing);
    CHECK(SalEditedMemberFound(0, 2) == semnUnknown); // two candidates by the rule
    CHECK(SalEditedMemberFound(2, 0) == semnUnknown); // an archive with the name twice
    CHECK(SalEditedMemberFound(2, 3) == semnUnknown);
    // --- the mark: removed, changed or unknown = marked; the same size and time = plain
    CHECK(!SalEditedMemberChangedInArchive(semnListed, t, s, t, s));
    CHECK(SalEditedMemberChangedInArchive(semnListed, t, s, t + 20000000, s)); // the member's time
    CHECK(SalEditedMemberChangedInArchive(semnListed, t, s, t, s + 7));        // the member's size
    CHECK(SalEditedMemberChangedInArchive(semnListed, t, s, t - 1, s));
    CHECK(SalEditedMemberChangedInArchive(semnMissing, t, s, 0, 0));
    CHECK(SalEditedMemberChangedInArchive(semnUnknown, t, s, t, s)); // fail closed: only a warning
    CHECK(SalEditedMemberChangedInArchive(semnMissing, 0, 0, 0, 0));
}

// feature 109: the disk-cache key of an archive (SalNameIdentityKeyAlloc) and the rule for one
// archive under two spellings (SalArchiveSharesCacheKey)
static std::string Key109(const char* s, int len = -1)
{
    char* k = SalNameIdentityKeyAlloc(s, len, 0);
    std::string r = k != NULL ? std::string(k) : std::string("<NULL>");
    free(k);
    return r;
}

static void TestDiskCacheKey109()
{
    // --- the per-unit fold IS the class representative of CompareStringOrdinal(..., TRUE), over
    //     every one of the 65,536 units: (1) each unit equals its fold; (2) units sorted by that
    //     comparison: neighbours that compare equal have one fold. (1) + (2) give
    //     fold(u) == fold(v) <=> CompareStringOrdinal(u, v, TRUE) == CSTR_EQUAL
    {
        std::vector<WCHAR> all(65536);
        int notInClass = 0, surrogateMoved = 0, mappedToSurrogate = 0;
        for (int i = 0; i < 65536; i++)
        {
            WCHAR u = (WCHAR)i, f = SalNameIdentityFoldUnit(u);
            all[i] = u;
            if (CompareStringOrdinal(&u, 1, &f, 1, TRUE) != CSTR_EQUAL)
                notInClass++;
            BOOL sur = u >= 0xD800 && u <= 0xDFFF;
            if (sur && f != u)
                surrogateMoved++;
            if (!sur && f >= 0xD800 && f <= 0xDFFF)
                mappedToSurrogate++;
        }
        CHECK(notInClass == 0);
        CHECK(surrogateMoved == 0); // lone surrogates stay lone, pairs stay pairs
        CHECK(mappedToSurrogate == 0);
        std::sort(all.begin(), all.end(), [](WCHAR a, WCHAR b)
                  {
                      int c = CompareStringOrdinal(&a, 1, &b, 1, TRUE);
                      return c != CSTR_EQUAL ? c == CSTR_LESS_THAN : a < b;
                  });
        int split = 0, classes = 1;
        for (int i = 1; i < 65536; i++)
        {
            if (CompareStringOrdinal(&all[i - 1], 1, &all[i], 1, TRUE) == CSTR_EQUAL)
            {
                if (SalNameIdentityFoldUnit(all[i - 1]) != SalNameIdentityFoldUnit(all[i]))
                    split++;
            }
            else
                classes++;
        }
        CHECK(split == 0);
        CHECK(classes < 65536); // there are case pairs at all
        for (int c = 'a'; c <= 'z'; c++)
            CHECK(SalNameIdentityFoldUnit((WCHAR)c) == (WCHAR)(c - 32));
        CHECK(SalNameIdentityFoldUnit(0x0131) != L'I'); // dotless i, long s, Kelvin: not ASCII letters
        CHECK(SalNameIdentityFoldUnit(0x017F) != L'S');
        CHECK(SalNameIdentityFoldUnit(0x212A) != L'K');
    }

    // --- archive names: the measured defect (CP1250: the old key, the code-page lower case, made
    //     the first five "differ" pairs one archive) and names that are one name by the rule
    static const char* const differ[][2] = {
        {"C:\\t\\\xC4\xA5.zip", "C:\\t\\\xC4\xB9.zip"},           // h-circumflex / L-acute
        {"C:\\t\\\xC3\x8D" "tem.7z", "C:\\t\\\xC3\x9D" "tem.7z"}, // I-acute / Y-acute
        {"C:\\t\\\xC5\xBE.zip", "C:\\t\\\xC5\xBC.zip"},           // z-caron / z-dot
        {"C:\\t\\\xE4\xB9\x9D.zip", "C:\\t\\\xE4\xB9\x8D.zip"},   // U+4E5D / U+4E4D
        {"C:\\t\\\xD0\xBC.zip", "C:\\t\\\xD0\xBE.zip"},           // Cyrillic em / o
        {"C:\\t\\\xC3\xA9.zip", "C:\\t\\e\xCC\x81.zip"},          // NFC / NFD: two files on NTFS
        {"C:\\t\\a.zip", "C:\\t\\b.zip"},
        {"C:\\t\\\xC4\xB1.zip", "C:\\t\\I.zip"},                  // dotless i / I
        {"C:\\t\\\xC5\xBF.zip", "C:\\t\\S.zip"},                  // long s / S
        {"C:\\t\\\xE2\x84\xAA.zip", "C:\\t\\K.zip"},              // Kelvin / K
        {"C:\\t\\\xED\xA0\x80.zip", "C:\\t\\\xED\xA0\x81.zip"},   // two lone surrogates
    };
    for (int i = 0; i < _countof(differ); i++)
    {
        CHECK(Key109(differ[i][0]) != Key109(differ[i][1]));
        CHECK(!SalNameEqualOrdinalCI(differ[i][0], -1, differ[i][1], -1));
    }
    if (GetACP() == 1250)
    {
        for (int i = 0; i < 5; i++)
            CHECK(LegacyFoldEqual108(differ[i][0], differ[i][1])); // the old key merged them
    }
    static const char* const same[][2] = {
        {"C:\\t\\\xC4\x8C.zip", "c:\\T\\\xC4\x8D.ZIP"},                         // C-caron / c-caron (the old key: two)
        {"C:\\t\\\xC8\xBA.zip", "C:\\t\\\xE2\xB1\xA5.zip"},                     // A-stroke (2 bytes) / a-stroke (3 bytes)
        {"C:\\Temp\\Arc.ZIP", "c:\\temp\\arc.zip"},
        {"\\\\Server\\Share\\\xD0\x90.zip", "\\\\server\\SHARE\\\xD0\xB0.zip"}, // Cyrillic A / a
        {"C:\\t\\\xED\xA0\x80.zip", "C:\\T\\\xED\xA0\x80.ZIP"},                 // a lone surrogate, other ASCII case
        {"C:\\t\\\xF0\x9F\x93\x81.zip", "c:\\t\\\xF0\x9F\x93\x81.zip"},         // a pair (emoji)
    };
    for (int i = 0; i < _countof(same); i++)
    {
        CHECK(Key109(same[i][0]) == Key109(same[i][1]));
        CHECK(SalNameEqualOrdinalCI(same[i][0], -1, same[i][1], -1));
    }
    if (GetACP() == 1250)
        CHECK(!LegacyFoldEqual108(same[0][0], same[0][1])); // the old key: two keys for one archive
    CHECK(Key109("C:\\Temp\\Arc.zip") == "C:\\TEMP\\ARC.ZIP"); // ASCII: upper case, nothing else
    CHECK(Key109("") == "");
    CHECK(Key109(NULL) == "");
    CHECK(Key109("abc", 2) == "AB");
    CHECK(Key109("\xC4\x8D", -1) == "\xC4\x8C"); // c-caron -> C-caron
    {
        char* k = SalNameIdentityKeyAlloc("ab", -1, 5); // the reserve is usable
        CHECK(k != NULL);
        if (k != NULL)
        {
            strcat(k, "\\x.tx");
            CHECK(strcmp(k, "AB\\x.tx") == 0);
            free(k);
        }
        k = SalNameIdentityKeyAlloc("\xC4\x8D", -1, 3); // also on the converting path
        CHECK(k != NULL);
        if (k != NULL)
        {
            strcat(k, "\\ab");
            CHECK(strcmp(k, "\xC4\x8C\\ab") == 0);
            free(k);
        }
        k = SalNameIdentityKeyAlloc("\xC8\xE8", -1, 3); // and on the legacy path
        CHECK(k != NULL);
        if (k != NULL)
        {
            strcat(k, "\\ab");
            CHECK(strlen(k) == 6 && (BYTE)k[0] == 0xFF);
            free(k);
        }
    }
    // --- text that is not WTF-8 (a legacy plug-in's code-page text): 0xFF + the legacy fold; never
    //     the key of valid text, even where the folded bytes happen to be valid UTF-8
    {
        std::string l1 = Key109("C:\\t\\\xC8\xE8.zip"); // C-caron + c-caron in CP1250: not UTF-8
        std::string l2 = Key109("C:\\T\\\xE8\xC8.ZIP");
        CHECK(!l1.empty() && (BYTE)l1[0] == 0xFF);
        CHECK((l1 == l2) == (SalNameEqualOrdinalCI("C:\\t\\\xC8\xE8.zip", -1, "C:\\T\\\xE8\xC8.ZIP", -1) != FALSE));
        CHECK(Key109("\xC1\x80\x80") != Key109("\xE1\x80\x80")); // CP1250 folds C1 to E1: still apart
        CHECK(!SalNameEqualOrdinalCI("\xC1\x80\x80", -1, "\xE1\x80\x80", -1));
    }
    // --- the relation, randomly: key equality == SalNameEqualOrdinalCI, over strings built from
    //     units with case pairs, look-alikes, both UTF-8 lengths, surrogates, combining marks
    {
        static const WCHAR alphabet[] = {L'a', L'A', L'k', L'K', L'i', L'I', L's', L'S', 0x0131, 0x0130, 0x017F, 0x212A,
                                         0x010C, 0x010D, 0x0125, 0x0139, 0x013A, 0x023A, 0x2C65, 0x00E9, 0x0301, 0x00C9,
                                         0x4E5D, 0x4E4D, 0x043C, 0x041C, 0x043E, 0x041E, 0xD800, 0xDC00, 0xD83D, 0xDCC1,
                                         0x00DF, 0x1E9E, L'\\', L'.', 0x03A3, 0x03C3, 0x03C2, 0xFF21, 0xFF41};
        unsigned rnd = 109;
        auto next = [&rnd]() -> unsigned
        {
            rnd = rnd * 1103515245u + 12345u;
            return (rnd >> 16) & 0x7FFF;
        };
        int bad = 0, equalPairs = 0;
        for (int n = 0; n < 40000; n++)
        {
            WCHAR wa[8], wb[8];
            int len = 1 + next() % 6;
            for (int i = 0; i < len; i++)
            {
                wa[i] = alphabet[next() % _countof(alphabet)];
                // b: a's unit, its fold, its linguistic lower case, or another unit
                unsigned r = next() % 4;
                WCHAR up = SalNameIdentityFoldUnit(wa[i]);
                if (r == 0)
                    wb[i] = wa[i];
                else if (r == 1)
                    wb[i] = up;
                else if (r == 2)
                    wb[i] = (WCHAR)(UINT_PTR)CharLowerW((LPWSTR)(UINT_PTR)up);
                else
                    wb[i] = alphabet[next() % _countof(alphabet)];
            }
            char a8[64], b8[64];
            if (SalWToU8(wa, len, a8, sizeof(a8)) == 0 || SalWToU8(wb, len, b8, sizeof(b8)) == 0)
            {
                bad++;
                continue;
            }
            BOOL eq = SalNameEqualOrdinalCI(a8, -1, b8, -1);
            if (eq)
                equalPairs++;
            if ((Key109(a8) == Key109(b8)) != (eq != FALSE))
                bad++;
        }
        CHECK(bad == 0);
        CHECK(equalPairs > 1000);
        // legacy and mixed: random bytes (mostly not UTF-8) against their byte-folded twins
        int badL = 0;
        for (int n = 0; n < 20000; n++)
        {
            char a[8], b[8];
            int len = 1 + next() % 6;
            for (int i = 0; i < len; i++)
            {
                a[i] = (char)(1 + next() % 255);
                unsigned r = next() % 3;
                if (r == 0)
                    b[i] = a[i];
                else if (r == 1)
                    b[i] = (char)(BYTE)(UINT_PTR)CharUpperA((LPSTR)(UINT_PTR)(BYTE)a[i]);
                else
                    b[i] = (char)(1 + next() % 255);
            }
            a[len] = b[len] = 0;
            if ((Key109(a) == Key109(b)) != (SalNameEqualOrdinalCI(a, -1, b, -1) != FALSE))
                badL++;
        }
        CHECK(badL == 0);
    }
    // --- every pair of BMP characters whose UTF-8 bytes the code page's lower case merges (CP1250:
    //     the 19,015 pairs of specs/108-.../probe/collision_set_cp1250.txt): the key keeps two names
    //     apart exactly when the file system does
    {
        std::map<std::string, std::vector<WCHAR>> byOldKey;
        for (int u = 0x80; u < 0x10000; u++)
        {
            if (u >= 0xD800 && u <= 0xDFFF)
                continue;
            WCHAR w = (WCHAR)u;
            char u8[8];
            int n = SalWToU8(&w, 1, u8, sizeof(u8));
            if (n <= 1)
                continue;
            std::string old;
            for (int i = 0; i < n - 1; i++)
                old += (char)(BYTE)(UINT_PTR)CharLowerA((LPSTR)(UINT_PTR)(BYTE)u8[i]);
            byOldKey[old].push_back(w);
        }
        long long collisions = 0, wrong = 0;
        for (auto& g : byOldKey)
        {
            for (size_t i = 0; i < g.second.size(); i++)
            {
                for (size_t j = i + 1; j < g.second.size(); j++)
                {
                    char a[8], b[8];
                    SalWToU8(&g.second[i], 1, a, sizeof(a));
                    SalWToU8(&g.second[j], 1, b, sizeof(b));
                    BOOL eq = SalNameEqualOrdinalCI(a, -1, b, -1);
                    if (!eq)
                        collisions++;
                    if ((Key109(a) == Key109(b)) != (eq != FALSE))
                        wrong++;
                }
            }
        }
        CHECK(wrong == 0);
        // 108's collision_set.py counted 19,015 such pairs among ASSIGNED characters (no private use,
        // controls, unassigned code points); every non-surrogate BMP unit is taken here (22,497 on
        // this machine's tables)
        if (GetACP() == 1250)
            CHECK(collisions >= 19015);
        printf("TestDiskCacheKey109: %lld pairs merged by the old key and kept apart by the file system (ACP %u)\n",
               collisions, GetACP());
    }
    // --- the flush prefix: key + '\\' takes the archive's members only ("p.zip" flushed "p.zip.zip")
    {
        std::string arc = Key109("C:\\t\\p.zip") + "\\";
        std::string other = Key109("C:\\t\\p.zip.zip") + "\\x.txt";
        std::string member = Key109("C:\\t\\P.ZIP") + "\\dir\\x.txt";
        CHECK(strncmp(other.c_str(), arc.c_str(), arc.size()) != 0);
        CHECK(strncmp(member.c_str(), arc.c_str(), arc.size()) == 0);
        std::string bare = Key109("C:\\t\\p.zip");
        CHECK(strncmp(other.c_str(), bare.c_str(), bare.size()) == 0); // what the bare key flushed
    }
    // --- CSalHeapString::Adopt / Swap
    {
        CSalHeapString s, t2;
        char* k = SalNameIdentityKeyAlloc("x", -1, 3);
        s.Adopt(k, 5);
        CHECK(s.Get() == k && s.Size() == 5 && strcmp(s.Text(), "X") == 0);
        CHECK(t2.Copy("y"));
        s.Swap(t2);
        CHECK(strcmp(s.Text(), "y") == 0 && strcmp(t2.Text(), "X") == 0 && t2.Size() == 5);
        t2.Adopt(NULL, 0);
        CHECK(t2.Get() == NULL && t2.Size() == 0);
    }

    // --- one archive under two spellings may share the key only by a certain identity
    {
        CSalFileIdentity a, b;
        SalFileIdentityClear(&a);
        a.Valid = a.Has64 = a.Has128 = TRUE;
        a.Vsn32 = 0x1234;
        a.Index64 = 0x00050000000012ABull;
        a.Vsn64 = 0x1234567812345678ull;
        memcpy(a.Id128, &a.Index64, 8);
        a.Size = 1000;
        a.MTime.dwLowDateTime = 100000000;
        b = a;
        CHECK(SalArchiveSharesCacheKey(a, b)); // 8.3 / SUBST / \\localhost\C$
        b.Id128[0] ^= 1;
        b.Index64 ^= 1;
        CHECK(!SalArchiveSharesCacheKey(a, b)); // another file
        b = a;
        b.Vsn64 ^= 1;
        CHECK(!SalArchiveSharesCacheKey(a, b)); // another volume
        b = a;
        b.SnapshotTag = 77;
        CHECK(!SalArchiveSharesCacheKey(a, b)); // a shadow copy of it
        b = a;
        b.SnapshotUnknown = TRUE;
        CHECK(!SalArchiveSharesCacheKey(a, b)); // the snapshot could not be read
        b = a;
        b.Has64 = b.Has128 = FALSE;
        CHECK(!SalArchiveSharesCacheKey(a, b)); // no ids (WebDAV)
        b = a;
        memset(b.Id128, 0, 16);
        b.Index64 = 0;
        CHECK(!SalArchiveSharesCacheKey(a, b)); // ids not usable
        b = a;
        a.WeakIds = b.WeakIds = TRUE;
        CHECK(SalArchiveSharesCacheKey(a, b)); // FAT: ids + equal metadata
        b.Size = 1001;
        CHECK(!SalArchiveSharesCacheKey(a, b)); // FAT: another file at that directory entry
        b = a;
        b.MTime.dwLowDateTime += 30000000;
        CHECK(!SalArchiveSharesCacheKey(a, b));
        b = a;
        b.Valid = FALSE;
        CHECK(!SalArchiveSharesCacheKey(a, b));

        // review of 109: which key a panel takes (SalArchiveCacheKeyChoice) - an EQUAL key is not
        // trusted by itself; 'other' = another file, 'noids' = a file system without ids (WebDAV)
        CSalFileIdentity other = a, noids = a;
        b = a;
        a.WeakIds = b.WeakIds = other.WeakIds = noids.WeakIds = FALSE;
        other.Index64 ^= 1;
        other.Id128[0] ^= 1;
        noids.Has64 = noids.Has128 = FALSE;
        // keys differ: share only on a certain identity
        CHECK(SalArchiveCacheKeyChoice(FALSE, FALSE, TRUE, TRUE, a, b) == sakShare);   // SUBST / UNC
        CHECK(SalArchiveCacheKeyChoice(FALSE, FALSE, TRUE, TRUE, a, other) == sakOwn);
        CHECK(SalArchiveCacheKeyChoice(FALSE, FALSE, TRUE, FALSE, a, b) == sakOwn);    // unreadable
        CHECK(SalArchiveCacheKeyChoice(FALSE, FALSE, FALSE, FALSE, a, b) == sakOwn);   // size / time differ
        // keys equal, names differ (the other key came from another spelling): the blocker - 'resubst'
        CHECK(SalArchiveCacheKeyChoice(TRUE, FALSE, TRUE, TRUE, a, other) == sakUnique);
        CHECK(SalArchiveCacheKeyChoice(TRUE, FALSE, TRUE, TRUE, a, b) == sakShare);
        CHECK(SalArchiveCacheKeyChoice(TRUE, FALSE, TRUE, FALSE, a, b) == sakUnique);  // cannot tell
        CHECK(SalArchiveCacheKeyChoice(TRUE, FALSE, TRUE, TRUE, a, noids) == sakUnique);
        CHECK(SalArchiveCacheKeyChoice(TRUE, FALSE, FALSE, FALSE, a, b) == sakUnique);
        // keys equal, one name: shared as in every release unless the ids say "another file" (a drive
        // re-pointed under the same spelling) or the size / time differ
        CHECK(SalArchiveCacheKeyChoice(TRUE, TRUE, TRUE, TRUE, a, b) == sakShare);
        CHECK(SalArchiveCacheKeyChoice(TRUE, TRUE, TRUE, TRUE, a, noids) == sakShare);  // WebDAV twice
        CHECK(SalArchiveCacheKeyChoice(TRUE, TRUE, TRUE, FALSE, a, b) == sakShare);     // unreadable
        CHECK(SalArchiveCacheKeyChoice(TRUE, TRUE, TRUE, TRUE, a, other) == sakUnique);
        CHECK(SalArchiveCacheKeyChoice(TRUE, TRUE, FALSE, FALSE, a, b) == sakUnique);
    }
    // --- real files (%TEMP%): one file through another case, its 8.3 name, \\localhost\C$ shares;
    //     another file does not
    WCHAR t[MAX_PATH];
    DWORD n = GetTempPathW(MAX_PATH, t);
    if (n == 0 || n >= MAX_PATH)
    {
        printf("skipping the file part of TestDiskCacheKey109 (no temp path)\n");
        return;
    }
    std::wstring dir = std::wstring(t) + L"saltests-109-" + std::to_wstring(GetCurrentProcessId());
    CHECK(CreateDirectoryW(dir.c_str(), NULL) || GetLastError() == ERROR_ALREADY_EXISTS);
    std::wstring f1 = dir + L"\\longarchivename109.zip", f2 = dir + L"\\other109.zip";
    const std::wstring* files[2] = {&f1, &f2};
    for (int i = 0; i < 2; i++)
    {
        HANDLE h = CreateFileW(files[i]->c_str(), GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
        CHECK(h != INVALID_HANDLE_VALUE);
        if (h != INVALID_HANDLE_VALUE)
        {
            DWORD w;
            WriteFile(h, "PK\x05\x06", 4, &w, NULL);
            CloseHandle(h);
        }
    }
    auto u8of = [](const std::wstring& w) -> std::string
    {
        char b[4 * MAX_PATH];
        return SalWToU8(w.c_str(), -1, b, sizeof(b)) != 0 ? std::string(b) : std::string();
    };
    auto idOf = [&](const std::wstring& w, CSalFileIdentity* id) -> BOOL
    { return SalGetFileIdentity(u8of(w).c_str(), FALSE, id, TRUE); };
    CSalFileIdentity i1, i2, ia;
    CHECK(idOf(f1, &i1) && idOf(f2, &i2));
    CHECK(SalArchiveSharesCacheKey(i1, i1));
    CHECK(!SalArchiveSharesCacheKey(i1, i2));
    std::wstring upper = f1;
    for (size_t i = 0; i < upper.size(); i++)
        upper[i] = (WCHAR)(UINT_PTR)CharUpperW((LPWSTR)(UINT_PTR)upper[i]);
    CHECK(idOf(upper, &ia) && SalArchiveSharesCacheKey(i1, ia));
    CHECK(Key109(u8of(upper).c_str()) == Key109(u8of(f1).c_str())); // and one key anyway
    WCHAR shortName[MAX_PATH];
    DWORD sn = GetShortPathNameW(f1.c_str(), shortName, MAX_PATH);
    if (sn > 0 && sn < MAX_PATH && _wcsicmp(shortName, f1.c_str()) != 0)
    {
        CHECK(Key109(u8of(shortName).c_str()) != Key109(u8of(f1).c_str())); // two keys by name ...
        CHECK(idOf(shortName, &ia) && SalArchiveSharesCacheKey(i1, ia));     // ... one file by identity
    }
    else
        printf("TestDiskCacheKey109: no 8.3 names in %ls - the short-name check is skipped\n", t);
    if (t[1] == L':')
    {
        std::wstring unc = std::wstring(L"\\\\localhost\\") + t[0] + L"$" + f1.substr(2);
        if (idOf(unc, &ia) && ia.Has64)
            CHECK(SalArchiveSharesCacheKey(i1, ia)); // the loopback administrative share
        else
            printf("TestDiskCacheKey109: %ls not reachable - the UNC check is skipped\n", unc.c_str());
    }
    DeleteFileW(f1.c_str());
    DeleteFileW(f2.c_str());
    CHECK(RemoveDirectoryW(dir.c_str()));
}

// feature 111: PictView's source colors and the JPEG comment's NUL byte (src/common/salpvsource.h)
static void TestPvSource111()
{
    // --- the palette's size decides the dialog's color count ---
    CHECK(SalPaletteColorsForSave(2, 8) == 2);  // a GIF of two colors is 8bppIndexed (measured)
    CHECK(SalPaletteColorsForSave(1, 1) == 2);  // a one-color palette
    CHECK(SalPaletteColorsForSave(3, 2) == 16); // the dialog has no 4 colors
    CHECK(SalPaletteColorsForSave(16, 4) == 16);
    CHECK(SalPaletteColorsForSave(17, 8) == 256);
    CHECK(SalPaletteColorsForSave(256, 8) == 256);
    CHECK(SalPaletteColorsForSave(0, 1) == 2); // no palette read: from the bits per pixel
    CHECK(SalPaletteColorsForSave(0, 2) == 16);
    CHECK(SalPaletteColorsForSave(0, 4) == 16);
    CHECK(SalPaletteColorsForSave(0, 8) == 256);
    CHECK(SalPaletteColorsForSave(0, 0) == 256);
    CHECK(SalPaletteColorsForSave(0, 32) == 256);

    // --- the alpha question: only when transparency is really there ---
    CHECK(!SalAlphaWouldBeLost(TRUE, FALSE)); // an opaque 32-bit PNG/TIFF/ICO
    CHECK(SalAlphaWouldBeLost(TRUE, TRUE));
    CHECK(!SalAlphaWouldBeLost(FALSE, TRUE)); // a palette's transparent color is no alpha channel
    CHECK(!SalAlphaWouldBeLost(FALSE, FALSE));

    // --- the NUL the Windows JPEG encoder appends to the comment ---
    // SOI, APP0 (JFIF, 16 bytes), COM "Ab" + NUL (len 5), DQT start
    const BYTE jpg[] = {0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 'J', 'F', 'I', 'F', 0, 1, 1, 0, 0, 1, 0, 1, 0, 0,
                        0xFF, 0xFE, 0x00, 0x05, 'A', 'b', 0x00, 0xFF, 0xDB, 0x00, 0x43};
    size_t lengthAt = 0, nulAt = 0;
    CHECK(SalJpegCommentNul(jpg, sizeof(jpg), 2, &lengthAt, &nulAt) && lengthAt == 22 && nulAt == 26);
    CHECK(!SalJpegCommentNul(jpg, sizeof(jpg), 3, &lengthAt, &nulAt)); // another text length: untouched
    CHECK(!SalJpegCommentNul(jpg, sizeof(jpg), 0, &lengthAt, &nulAt));
    CHECK(!SalJpegCommentNul(jpg, 26, 2, &lengthAt, &nulAt)); // the NUL is beyond what was read
    CHECK(!SalJpegCommentNul(jpg, 3, 2, &lengthAt, &nulAt));
    CHECK(!SalJpegCommentNul(NULL, 0, 2, &lengthAt, &nulAt));
    {
        BYTE noNul[sizeof(jpg)];
        memcpy(noNul, jpg, sizeof(jpg));
        noNul[26] = 'c'; // a comment that does not end with a NUL (another writer): untouched
        CHECK(!SalJpegCommentNul(noNul, sizeof(noNul), 2, &lengthAt, &nulAt));
        memcpy(noNul, jpg, sizeof(jpg));
        noNul[0] = 0x89; // not a JPEG
        CHECK(!SalJpegCommentNul(noNul, sizeof(noNul), 2, &lengthAt, &nulAt));
    }
    {
        // the image data (SOS) before any comment: no comment there
        const BYTE sos[] = {0xFF, 0xD8, 0xFF, 0xDA, 0x00, 0x08, 1, 2, 3, 4, 5, 6, 0xFF, 0xFE, 0x00, 0x05, 'A', 'b', 0};
        CHECK(!SalJpegCommentNul(sos, sizeof(sos), 2, &lengthAt, &nulAt));
        // a broken segment chain (length 1) and a chain that leaves the markers
        const BYTE bad[] = {0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x01, 0xFF, 0xFE, 0x00, 0x05, 'A', 'b', 0};
        CHECK(!SalJpegCommentNul(bad, sizeof(bad), 2, &lengthAt, &nulAt));
        const BYTE stray[] = {0xFF, 0xD8, 0x00, 0xFF, 0xFE, 0x00, 0x05, 'A', 'b', 0};
        CHECK(!SalJpegCommentNul(stray, sizeof(stray), 2, &lengthAt, &nulAt));
        // the comment first after SOI, UTF-8 text
        const BYTE first[] = {0xFF, 0xD8, 0xFF, 0xFE, 0x00, 0x06, 0xC4, 0x8D, 'x', 0x00};
        CHECK(SalJpegCommentNul(first, sizeof(first), 3, &lengthAt, &nulAt) && lengthAt == 4 && nulAt == 9);
        // only the FIRST comment counts
        const BYTE two[] = {0xFF, 0xD8, 0xFF, 0xFE, 0x00, 0x04, 'Z', 'Z', 0xFF, 0xFE, 0x00, 0x05, 'A', 'b', 0};
        CHECK(!SalJpegCommentNul(two, sizeof(two), 2, &lengthAt, &nulAt));
    }
}

// feature 120: PictView's pipette and histogram read the rows by their format (salpvpixel.h)
static BOOL Rgb120(RGBQUAD c, BYTE r, BYTE g, BYTE b)
{
    return c.rgbRed == r && c.rgbGreen == g && c.rgbBlue == b && c.rgbReserved == 0;
}
static DWORD Total120(const DWORD* a)
{
    DWORD t = 0;
    for (int i = 0; i < 256; i++)
        t += a[i];
    return t;
}
static void TestPvPixel120()
{
    // --- bits per pixel of each row format ---
    CHECK(SalPvRowBitsPerPixel(SAL_PV_COLOR_TC32) == 32);
    CHECK(SalPvRowBitsPerPixel(SAL_PV_COLOR_TC24) == 24);
    CHECK(SalPvRowBitsPerPixel(SAL_PV_COLOR_HC15) == 16);
    CHECK(SalPvRowBitsPerPixel(SAL_PV_COLOR_HC16) == 16);
    CHECK(SalPvRowBitsPerPixel(256) == 8);
    CHECK(SalPvRowBitsPerPixel(17) == 8);
    CHECK(SalPvRowBitsPerPixel(16) == 4);
    CHECK(SalPvRowBitsPerPixel(3) == 4);
    CHECK(SalPvRowBitsPerPixel(2) == 1);
    CHECK(SalPvRowBitsPerPixel(1) == 1);
    CHECK(SalPvRowBitsPerPixel(0) == 0);
    CHECK(SalPvRowBitsPerPixel(257) == 0);
    CHECK(SalPvRowBitsPerPixel(65531) == 0);

    RGBQUAD c;
    int ind = -5;
    // --- the WIC engine's rows: 4 bytes per pixel (B, G, R, unused - 255 after compositing) ---
    const BYTE tc32[] = {50, 100, 200, 255, 1, 2, 3, 255, 10, 20, 30, 255, 7, 8, 9, 255};
    CHECK(SalPvReadRowPixel(tc32, SAL_PV_COLOR_TC32, 0, NULL, &c, &ind) && Rgb120(c, 200, 100, 50) && ind == 0);
    CHECK(SalPvReadRowPixel(tc32, SAL_PV_COLOR_TC32, 1, NULL, &c, &ind) && Rgb120(c, 3, 2, 1));
    CHECK(SalPvReadRowPixel(tc32, SAL_PV_COLOR_TC32, 2, NULL, &c, &ind) && Rgb120(c, 30, 20, 10));
    CHECK(SalPvReadRowPixel(tc32, SAL_PV_COLOR_TC32, 3, NULL, &c, &ind) && Rgb120(c, 9, 8, 7));
    // the old reader took pixel 1 from bytes 3..5: blue 255 (the unused byte), green 1, red 2
    CHECK(tc32[3] == 255 && tc32[4] == 1 && tc32[5] == 2);
    // 24-bit rows (3 bytes per pixel)
    const BYTE tc24[] = {50, 100, 200, 1, 2, 3};
    CHECK(SalPvReadRowPixel(tc24, SAL_PV_COLOR_TC24, 1, NULL, &c, &ind) && Rgb120(c, 3, 2, 1));
    // 15/16-bit words, little-endian
    const BYTE hc16[] = {0x00, 0xF8, 0xE0, 0x07, 0x1F, 0x00, 0xFF, 0xFF};
    CHECK(SalPvReadRowPixel(hc16, SAL_PV_COLOR_HC16, 0, NULL, &c, &ind) && Rgb120(c, 248, 0, 0));
    CHECK(SalPvReadRowPixel(hc16, SAL_PV_COLOR_HC16, 1, NULL, &c, &ind) && Rgb120(c, 0, 252, 0));
    CHECK(SalPvReadRowPixel(hc16, SAL_PV_COLOR_HC16, 2, NULL, &c, &ind) && Rgb120(c, 0, 0, 248));
    CHECK(SalPvReadRowPixel(hc16, SAL_PV_COLOR_HC16, 3, NULL, &c, &ind) && Rgb120(c, 248, 252, 248));
    const BYTE hc15[] = {0x00, 0x7C, 0xE0, 0x03, 0x1F, 0x00};
    CHECK(SalPvReadRowPixel(hc15, SAL_PV_COLOR_HC15, 0, NULL, &c, &ind) && Rgb120(c, 248, 0, 0));
    CHECK(SalPvReadRowPixel(hc15, SAL_PV_COLOR_HC15, 1, NULL, &c, &ind) && Rgb120(c, 0, 248, 0));
    CHECK(SalPvReadRowPixel(hc15, SAL_PV_COLOR_HC15, 2, NULL, &c, &ind) && Rgb120(c, 0, 0, 248));
    // the same values as the old pipette's byte arithmetic, for every 97th word
    for (unsigned w = 0; w < 65536; w += 97)
    {
        BYTE b0 = (BYTE)(w & 0xFF), b1 = (BYTE)(w >> 8);
        const BYTE row[] = {b0, b1};
        RGBQUAD n16, n15;
        CHECK(SalPvReadRowPixel(row, SAL_PV_COLOR_HC16, 0, NULL, &n16, &ind));
        CHECK(SalPvReadRowPixel(row, SAL_PV_COLOR_HC15, 0, NULL, &n15, &ind));
        CHECK(n16.rgbBlue == (BYTE)((b0 << 3) & 0xFF) && n16.rgbGreen == (BYTE)((((b0 & 0xE0) >> 3) | (b1 << 5)) & 0xFF) &&
              n16.rgbRed == (BYTE)(b1 & 0xF8));
        CHECK(n15.rgbBlue == (BYTE)((b0 << 3) & 0xFF) && n15.rgbGreen == (BYTE)((((b0 & 0xE0) >> 2) | (b1 << 6)) & 0xFF) &&
              n15.rgbRed == (BYTE)((b1 << 1) & 0xF8));
    }
    // palette rows: 8-bit, 4-bit (high nibble first), 1-bit (most significant bit first)
    RGBQUAD pal[256];
    for (int i = 0; i < 256; i++)
    {
        pal[i].rgbRed = (BYTE)i;
        pal[i].rgbGreen = (BYTE)(255 - i);
        pal[i].rgbBlue = (BYTE)(i / 2);
        pal[i].rgbReserved = 0;
    }
    const BYTE p8[] = {0, 7, 255, 9};
    CHECK(SalPvReadRowPixel(p8, 256, 2, pal, &c, &ind) && ind == 255 && Rgb120(c, 255, 0, 127));
    CHECK(!SalPvReadRowPixel(p8, 256, 2, NULL, &c, &ind)); // no palette
    CHECK(!SalPvReadRowPixel(p8, 200, 2, pal, &c, &ind));  // index 255 outside a 200-color palette
    const BYTE p4[] = {0x3A, 0xF0};
    CHECK(SalPvReadRowPixel(p4, 16, 0, pal, &c, &ind) && ind == 3);
    CHECK(SalPvReadRowPixel(p4, 16, 1, pal, &c, &ind) && ind == 10);
    CHECK(SalPvReadRowPixel(p4, 16, 2, pal, &c, &ind) && ind == 15);
    const BYTE p1[] = {0x81, 0x40};
    CHECK(SalPvReadRowPixel(p1, 2, 0, pal, &c, &ind) && ind == 1);
    CHECK(SalPvReadRowPixel(p1, 2, 1, pal, &c, &ind) && ind == 0);
    CHECK(SalPvReadRowPixel(p1, 2, 7, pal, &c, &ind) && ind == 1);
    CHECK(SalPvReadRowPixel(p1, 2, 9, pal, &c, &ind) && ind == 1);
    CHECK(!SalPvReadRowPixel(p1, 0, 0, pal, &c, &ind));    // not a row format
    CHECK(!SalPvReadRowPixel(p1, 1000, 0, pal, &c, &ind)); // not a row format
    CHECK(!SalPvReadRowPixel(NULL, 256, 0, pal, &c, &ind));

    // --- the histogram ---
    DWORD lum[256], red[256], green[256], blue[256], rgb[256], idx[256];
#define CLEAR120()                         \
    do                                     \
    {                                      \
        memset(lum, 0, sizeof(lum));       \
        memset(red, 0, sizeof(red));       \
        memset(green, 0, sizeof(green));   \
        memset(blue, 0, sizeof(blue));     \
        memset(rgb, 0, sizeof(rgb));       \
        memset(idx, 0, sizeof(idx));       \
    } while (0)
    // six 32-bit pixels of (200, 100, 50): one level per channel; the luminosity 124 (124.2 rounded down)
    BYTE row6[6 * 4];
    for (int i = 0; i < 6; i++)
    {
        row6[4 * i] = 50;
        row6[4 * i + 1] = 100;
        row6[4 * i + 2] = 200;
        row6[4 * i + 3] = 255;
    }
    CLEAR120();
    SalPvHistogramRow(row6, SAL_PV_COLOR_TC32, 6, idx, lum, red, green, blue, rgb);
    SalPvHistogramFinish(rgb);
    CHECK(red[200] == 6 && Total120(red) == 6);
    CHECK(green[100] == 6 && Total120(green) == 6);
    CHECK(blue[50] == 6 && Total120(blue) == 6);
    CHECK(lum[124] == 6 && Total120(lum) == 6);
    CHECK(rgb[50] == 2 && rgb[100] == 2 && rgb[200] == 2 && Total120(rgb) == 6); // each level: 6 values / 3
    CHECK(red[255] == 0 && green[255] == 0 && blue[255] == 0); // the unused byte is never a color (the old reader: 255)
    // only the first 'width' pixels
    CLEAR120();
    SalPvHistogramRow(row6, SAL_PV_COLOR_TC32, 4, idx, lum, red, green, blue, rgb);
    CHECK(red[200] == 4 && Total120(red) == 4);
    // white and black: the luminosity's ends
    const BYTE wb[] = {255, 255, 255, 255, 0, 0, 0, 255};
    CLEAR120();
    SalPvHistogramRow(wb, SAL_PV_COLOR_TC32, 2, idx, lum, red, green, blue, rgb);
    CHECK(lum[255] == 1 && lum[0] == 1);
    // 15/16-bit rows: red counted as red (the old histogram swapped red and blue)
    CLEAR120();
    SalPvHistogramRow(hc16, SAL_PV_COLOR_HC16, 1, idx, lum, red, green, blue, rgb);
    CHECK(red[248] == 1 && blue[0] == 1 && green[0] == 1);
    CLEAR120();
    SalPvHistogramRow(hc15, SAL_PV_COLOR_HC15, 1, idx, lum, red, green, blue, rgb);
    CHECK(red[248] == 1 && blue[0] == 1);
    // palette rows count indexes - never the bytes or nibbles that pad a row
    CLEAR120();
    const BYTE p8pad[] = {7, 7, 9, 0xEE}; // three pixels, one padding byte
    SalPvHistogramRow(p8pad, 256, 3, idx, lum, red, green, blue, rgb);
    CHECK(idx[7] == 2 && idx[9] == 1 && idx[0xEE] == 0 && Total120(red) == 0);
    CLEAR120();
    const BYTE p4pad[] = {0x12, 0x30, 0x00, 0x00}; // three pixels (1, 2, 3), padding to four bytes
    SalPvHistogramRow(p4pad, 16, 3, idx, lum, red, green, blue, rgb);
    CHECK(idx[1] == 1 && idx[2] == 1 && idx[3] == 1 && idx[0] == 0);
    CLEAR120();
    const BYTE p1pad[] = {0xFF, 0xC0, 0x00, 0x00}; // ten pixels set, padding bits clear
    SalPvHistogramRow(p1pad, 2, 10, idx, lum, red, green, blue, rgb);
    CHECK(idx[1] == 10 && idx[0] == 0);
    // a palette color added once with its count
    CLEAR120();
    SalPvHistogramAdd(lum, red, green, blue, rgb, pal[7], 2);
    CHECK(red[7] == 2 && green[248] == 2 && blue[3] == 2);
    // not a row format: nothing
    CLEAR120();
    SalPvHistogramRow(row6, 1000, 6, idx, lum, red, green, blue, rgb);
    CHECK(Total120(red) == 0 && Total120(idx) == 0);
#undef CLEAR120

    // --- the shown position -> the row position (the viewer mirrors when it draws) ---
    int rx = -1, ry = -1;
    CHECK(SalPvShownToRow(3, 2, 40, 30, FALSE, FALSE, &rx, &ry) && rx == 3 && ry == 2);
    CHECK(SalPvShownToRow(3, 2, 40, 30, TRUE, FALSE, &rx, &ry) && rx == 36 && ry == 2);
    CHECK(SalPvShownToRow(3, 2, 40, 30, FALSE, TRUE, &rx, &ry) && rx == 3 && ry == 27);
    CHECK(SalPvShownToRow(3, 2, 40, 30, TRUE, TRUE, &rx, &ry) && rx == 36 && ry == 27);
    CHECK(SalPvShownToRow(0, 0, 1, 1, TRUE, TRUE, &rx, &ry) && rx == 0 && ry == 0);
    CHECK(SalPvShownToRow(39, 29, 40, 30, TRUE, TRUE, &rx, &ry) && rx == 0 && ry == 0);
    CHECK(!SalPvShownToRow(-1, 0, 40, 30, FALSE, FALSE, &rx, &ry));
    CHECK(!SalPvShownToRow(40, 0, 40, 30, FALSE, FALSE, &rx, &ry));
    CHECK(!SalPvShownToRow(0, 30, 40, 30, FALSE, FALSE, &rx, &ry));
    CHECK(!SalPvShownToRow(0, 0, 0, 0, FALSE, FALSE, &rx, &ry));
}

// feature 110: the ZIP plug-in's member identity (salzipname.h)
static BOOL OldZipEqual110(const std::string& a, const std::string& b, DWORD flags = NORM_IGNORECASE)
{ // what the plug-in did: CompareStringA on the UTF-8 bytes, the user's locale, an equal-length guard
    return a.size() == b.size() &&
           CompareStringA(LOCALE_USER_DEFAULT, flags, a.c_str(), (int)a.size(), b.c_str(), (int)b.size()) == CSTR_EQUAL;
}
static std::string U8of110(const WCHAR* w)
{
    char b[512];
    int n = WideCharToMultiByte(CP_UTF8, 0, w, -1, b, sizeof(b), NULL, NULL);
    return n > 0 ? std::string(b) : std::string();
}

static void TestZipName110()
{
    // --- pairs the old comparison took for one name (CP1250) and the file system keeps apart
    static const char* const differ[][2] = {
        {"\xC4\xA5" ".txt", "\xC4\xB9" ".txt"},         // h-circumflex / L-acute
        {"\xC3\x8D" "tem.txt", "\xC3\x9D" "tem.txt"},   // I-acute / Y-acute (Czech)
        {"\xC5\xBE" ".txt", "\xC5\xBC" ".txt"},         // z-caron / z-dot
        {"\xE4\xB9\x9D" ".txt", "\xE4\xB9\x8D" ".txt"}, // CJK U+4E5D / U+4E4D
        {"\xD0\xBC" ".txt", "\xD0\xBE" ".txt"},         // Cyrillic em / o
        {"\xC3\xA9" ".txt", "e\xCC\x81" ".txt"},        // NFC / NFD (apart in both rules)
        {"a.txt", "b.txt"},
        {"\xC4\xB1" ".txt", "I.txt"},                   // dotless i is not I
        {"\xE2\x84\xAA" ".txt", "K.txt"},               // Kelvin sign is not K
    };
    for (int i = 0; i < _countof(differ); i++)
    {
        CHECK(!SalZipNameEqual(differ[i][0], -1, differ[i][1], -1, TRUE));
        CHECK(!SalZipNameEqual(differ[i][1], -1, differ[i][0], -1, TRUE));
        CHECK(!SalZipNameEqual(differ[i][0], -1, differ[i][1], -1, FALSE));
        CHECK(SalZipNameEqual(differ[i][0], -1, differ[i][0], -1, TRUE));
    }
    if (GetACP() == 1250) // the measured defect
        for (int i = 0; i < 5; i++)
            CHECK(OldZipEqual110(differ[i][0], differ[i][1]));

    // --- one name for Windows: case pairs outside ASCII (the old comparison kept them apart),
    //     the 7 case pairs with different UTF-8 lengths, ASCII case (unchanged)
    std::vector<std::pair<std::string, std::string>> same = {
        {"\xC4\x8C" ".txt", "\xC4\x8D" ".txt"}, // C-caron / c-caron
        {"A.txt", "a.txt"},
        {"README.md", "readme.MD"},
        {"slo\xC5\xBD" "ka\\x.TXT", "SLO\xC5\xBE" "KA\\X.txt"},
    };
    static const WCHAR difflen[][2] = {{0x023A, 0x2C65}, {0x023E, 0x2C66}, {0x0250, 0x2C6F}, {0x0251, 0x2C6D},
                                       {0x026B, 0x2C62}, {0x0271, 0x2C6E}, {0x027D, 0x2C64}};
    for (int i = 0; i < _countof(difflen); i++)
    {
        WCHAR a[8] = {difflen[i][0], L'.', L't', L'x', L't', 0}, b[8] = {difflen[i][1], L'.', L't', L'x', L't', 0};
        std::string ua = U8of110(a), ub = U8of110(b);
        CHECK(ua.size() != ub.size());
        CHECK(!OldZipEqual110(ua, ub)); // the old length guard
        same.push_back({ua, ub});
    }
    for (auto& p : same)
    {
        CHECK(SalZipNameEqual(p.first.c_str(), -1, p.second.c_str(), -1, TRUE));
        CHECK(SalZipNameEqual(p.second.c_str(), (int)p.second.size(), p.first.c_str(), (int)p.first.size(), TRUE));
        CHECK(!SalZipNameEqual(p.first.c_str(), -1, p.second.c_str(), -1, FALSE));
    }
    if (GetACP() == 1250)
        CHECK(!OldZipEqual110(same[0].first, same[0].second)); // C-caron / c-caron: two names before

    // --- printable ASCII: the new rule is the old one (every pair of characters)
    {
        int ciDiff = 0, csDiff = 0;
        for (int x = 32; x < 127; x++)
            for (int y = 32; y < 127; y++)
            {
                std::string a = std::string("n") + (char)x + ".txt", b = std::string("n") + (char)y + ".txt";
                if (SalZipNameEqual(a.c_str(), -1, b.c_str(), -1, TRUE) != OldZipEqual110(a, b))
                    ciDiff++;
                if (SalZipNameEqual(a.c_str(), -1, b.c_str(), -1, FALSE) != (x == y) ||
                    OldZipEqual110(a, b, 0) != (x == y)) // the old case-sensitive test (Unix folder) too
                    csDiff++;
            }
        CHECK(ciDiff == 0);
        CHECK(csDiff == 0);
    }
    // --- ASCII names of more than one letter: the new rule is the ASCII fold, the old one was
    //     LINGUISTIC - on a Czech, Slovak, Hungarian, Croatian ... locale a digraph ("ch") is one
    //     letter, so "cHata.txt" and "chata.txt" were two names before and are one now (as for
    //     Windows). Every pair of two-letter names: new == fold; the old rule's changed pairs are
    //     counted (only "old two -> new one" may exist)
    {
        CHECK(SalZipNameEqual("cHata.txt", -1, "chata.txt", -1, TRUE));
        CHECK(SalZipNameEqual("CHATA.txt", -1, "cHata.TXT", -1, TRUE));
        CHECK(SalZipNameEqual("dZ.txt", -1, "dz.txt", -1, TRUE));
        CHECK(SalZipNameEqual("lY.txt", -1, "ly.txt", -1, TRUE));
        CHECK(!SalZipNameEqual("cHata.txt", -1, "chata.txt", -1, FALSE));
        if (PRIMARYLANGID(LANGIDFROMLCID(GetUserDefaultLCID())) == LANG_CZECH)
            CHECK(!OldZipEqual110("cHata.txt", "chata.txt")); // the measured change of direction
        char letters[52];
        for (int i = 0; i < 26; i++)
        {
            letters[i] = (char)('A' + i);
            letters[26 + i] = (char)('a' + i);
        }
        int newDiff = 0, oldTwoNewOne = 0, oldOneNewTwo = 0;
        char a[3] = {0}, b[3] = {0};
        for (int i = 0; i < 52 * 52; i++)
        {
            a[0] = letters[i / 52];
            a[1] = letters[i % 52];
            for (int j = 0; j < 52 * 52; j++)
            {
                b[0] = letters[j / 52];
                b[1] = letters[j % 52];
                BOOL fold = (a[0] | 0x20) == (b[0] | 0x20) && (a[1] | 0x20) == (b[1] | 0x20);
                BOOL mine = SalZipNameEqual(a, 2, b, 2, TRUE);
                if (mine != fold)
                    newDiff++;
                if (fold) // only fold-equal pairs can differ from the old rule in this direction ...
                {
                    if (!OldZipEqual110(a, b))
                        oldTwoNewOne++;
                }
                else if ((a[0] | 0x20) == (b[0] | 0x20) || (a[1] | 0x20) == (b[1] | 0x20)) // ... and near ones the other
                {
                    if (OldZipEqual110(a, b))
                        oldOneNewTwo++;
                }
            }
        }
        CHECK(newDiff == 0);
        CHECK(oldOneNewTwo == 0);
        printf("TestZipName110: two-letter ASCII names, old rule two names / new one: %d pairs (user locale 0x%04X)\n",
               oldTwoNewOne, (unsigned)GetUserDefaultLCID());
    }

    // --- legacy text (not WTF-8: a broken UTF-8 flag, a failed conversion): the old comparison;
    //     never equal to a valid WTF-8 name
    CHECK(SalZipNameEqual("\xE8" ".txt", -1, "\xC8" ".TXT", -1, TRUE) == OldZipEqual110("\xE8" ".txt", "\xC8" ".TXT"));
    CHECK(SalZipNameEqual("\xE8" ".txt", -1, "\xE8" ".txt", -1, FALSE));
    CHECK(!SalZipNameEqual("\xE8" ".txt", -1, "\xC4\x8D" ".txt", -1, TRUE));
    CHECK(!SalZipNameEqual("\xC4\x8D" ".txt", -1, "\xE8" ".txt", -1, TRUE));
    CHECK(!SalZipNameEqual("\xE8" ".txt", -1, "\xE8" ".txtx", -1, TRUE));
    CHECK(!SalZipNameIsWtf8("\xE8" ".txt", -1));
    CHECK(SalZipNameIsWtf8("\xC4\x8D" ".txt", -1));
    CHECK(SalZipNameIsWtf8("\xED\xA0\x80", -1)); // a lone surrogate (066)
    CHECK(!SalZipNameIsWtf8("\xC0\xAF", -1));    // overlong
    CHECK(SalZipNameEqual(NULL, -1, "", -1, TRUE));

    // --- names over 259 bytes take the heap buffer
    {
        std::string up, low, h, l;
        for (int i = 0; i < 150; i++)
        {
            up += "\xC4\x8C";
            low += "\xC4\x8D";
            h += "\xC4\xA5";
            l += "\xC4\xB9";
        }
        CHECK(SalZipNameEqual(up.c_str(), -1, low.c_str(), -1, TRUE));
        CHECK(!SalZipNameEqual(h.c_str(), -1, l.c_str(), -1, TRUE));
        int n = 0;
        CHECK(SalZipNamePrefix((low + "\\x").c_str(), -1, up.c_str(), -1, TRUE, &n) && n == (int)low.size());
        CHECK(!SalZipNamePrefix((l + "\\x").c_str(), -1, h.c_str(), -1, TRUE, &n));
    }

    // --- prefixes: covered bytes are counted on the path
    {
        int n = -1;
        CHECK(SalZipNamePrefix("Dir\\x.txt", -1, "DIR", 3, TRUE, &n) && n == 3);
        CHECK(!SalZipNamePrefix("Dir\\x.txt", -1, "DIR", 3, FALSE, &n));
        CHECK(SalZipNamePrefix("\xE2\xB1\xA5" "\\x", -1, "\xC8\xBA", 2, TRUE, &n) && n == 3); // a-stroke under A-stroke
        CHECK(SalZipNamePrefix("\xC8\xBA" "\\x", -1, "\xE2\xB1\xA5", 3, TRUE, &n) && n == 2);
        CHECK(!SalZipNamePrefix("\xC4\xB9" "\\x", -1, "\xC4\xA5", 2, TRUE, &n));
        CHECK(!SalZipNamePrefix("\xC4\x8D", -1, "\xC4", 1, TRUE, &n));                         // inside a character
        CHECK(!SalZipNamePrefix("\xF0\x9F\x98\x80" "x", -1, "\xED\xA0\xBD", 3, TRUE, &n));       // inside a pair
        CHECK(!SalZipNamePrefix("\xED\xA0\x80\xED\xB0\x80" "x", -1, "\xED\xA0\x80", 3, TRUE, &n)); // inside a pair of two sequences
        CHECK(SalZipNamePrefix("\xED\xA0\x80" "x", -1, "\xED\xA0\x80", 3, TRUE, &n) && n == 3);  // a lone surrogate
        CHECK(SalZipNamePrefix("abc", -1, "", 0, TRUE, &n) && n == 0);
        CHECK(!SalZipNamePrefix("ab", -1, "abc", -1, TRUE, &n));
        CHECK(SalZipNamePrefix("\xE8\\x", -1, "\xC8", 1, TRUE, &n) == OldZipEqual110("\xE8", "\xC8")); // legacy
        CHECK(!SalZipNamePrefix("\xC4\x8D\\x", -1, "\xE8", 1, TRUE, &n)); // legacy prefix, valid path
        CHECK(!SalZipNamePrefix("\xE8\\x", -1, "\xC4\x8D", 2, TRUE, &n)); // valid prefix, legacy path
    }

    // --- the update matching (add.cpp): panel folder + rest
    {
        int rb = -1;
        CHECK(SalZipMemberIs("Dir\\x.txt", -1, "DIR\\X.TXT", -1, 3, TRUE, &rb) && rb == 3);
        CHECK(!SalZipMemberIs("Dir\\x.txt", -1, "DIR\\x.txt", -1, 3, FALSE, &rb)); // Unix: the folder by case
        CHECK(SalZipMemberIs("Dir\\x.txt", -1, "Dir\\X.TXT", -1, 3, FALSE, &rb));  // Unix: the name ignoring case (as before)
        CHECK(SalZipMemberIs("\xE2\xB1\xA5" "\\x.txt", -1, "\xC8\xBA" "\\x.txt", -1, 2, TRUE, &rb) && rb == 3);
        CHECK(!SalZipMemberIs("\xC4\xB9" "\\x.txt", -1, "\xC4\xA5" "\\x.txt", -1, 2, TRUE, &rb)); // folders h/L
        CHECK(!SalZipMemberIs("\xC4\xB9" ".txt", -1, "\xC4\xA5" ".txt", -1, 0, TRUE, &rb));
        CHECK(SalZipMemberIs("\xC4\x8C" ".txt", -1, "\xC4\x8D" ".txt", -1, 0, TRUE, &rb));
        CHECK(!SalZipMemberIs("Dirx\\a", -1, "Dir\\a", -1, 3, TRUE, &rb));
        CHECK(!SalZipMemberIs("Dir", -1, "Dir\\a", -1, 3, TRUE, &rb));
        CHECK(!SalZipMemberIs("d\\a", -1, "d\\a", -1, 5, TRUE, &rb)); // root longer than the target
        CHECK(SalZipMemberIsOrIsIn("d\\sub\\x.txt", -1, "D\\SUB", -1, 0, TRUE));
        CHECK(SalZipMemberIsOrIsIn("d\\sub", -1, "D\\SUB", -1, 1, TRUE));
        CHECK(!SalZipMemberIsOrIsIn("d\\subx\\x.txt", -1, "d\\sub", -1, 0, TRUE));
        CHECK(!SalZipMemberIsOrIsIn("\xC4\xB9" "\\x", -1, "\xC4\xA5", -1, 0, TRUE));
        CHECK(SalZipMemberIsOrIsIn("\xE2\xB1\xA5" "\\x.txt", -1, "\xC8\xBA", -1, 0, TRUE));
        if (GetACP() == 1250)
            CHECK(CompareStringA(LOCALE_USER_DEFAULT, NORM_IGNORECASE, "\xC4\xB9" "\\x", 2, "\xC4\xA5", 2) == CSTR_EQUAL); // the old Move test said "inside"
    }

    // --- parity with the core's rule (092) for valid WTF-8, the old rule for legacy text, never
    //     equal across: every pair of strings over a hostile alphabet, and every prefix
    {
        static const char* const atoms[] = {"a", "A", "\\", "\xC4\x8C", "\xC4\x8D", "\xC4\xA5", "\xC4\xB9", "\xC8\xBA",
                                            "\xE2\xB1\xA5", "\xC3\x9F", "\xE1\xBA\x9E", "\xC4\xB1", "\xE2\x84\xAA",
                                            "\xF0\x9F\x98\x80", "\xED\xA0\x80", "\xED\xB0\x80", "\xCC\x81", "\xE8", "\xC8"};
        std::vector<std::string> strs;
        strs.push_back("");
        for (const char* x : atoms)
        {
            strs.push_back(x);
            for (const char* y : atoms)
                strs.push_back(std::string(x) + y);
        }
        int mismatch = 0, prefixMismatch = 0, crossEqual = 0;
        for (auto& a : strs)
        {
            BOOL va = SalZipNameIsWtf8(a.c_str(), (int)a.size());
            for (auto& b : strs)
            {
                BOOL vb = SalZipNameIsWtf8(b.c_str(), (int)b.size());
                BOOL mine = SalZipNameEqual(a.c_str(), (int)a.size(), b.c_str(), (int)b.size(), TRUE);
                BOOL want;
                if (va && vb)
                    want = SalNameEqualOrdinalCI(a.c_str(), (int)a.size(), b.c_str(), (int)b.size());
                else if (!va && !vb)
                    want = (a == b) || OldZipEqual110(a, b);
                else
                {
                    want = FALSE;
                    if (mine)
                        crossEqual++;
                }
                if (mine != want)
                    mismatch++;
                if (va && vb) // prefixes of a valid path: the core's SalPathHasPrefixOrdinalCI
                {
                    int n1 = -1, n2 = -1;
                    BOOL p1 = SalZipNamePrefix(a.c_str(), (int)a.size(), b.c_str(), (int)b.size(), TRUE, &n1);
                    BOOL p2 = SalPathHasPrefixOrdinalCI(a.c_str(), b.c_str(), (int)b.size(), &n2);
                    if (p1 != p2 || (p1 && n1 != n2))
                        prefixMismatch++;
                }
            }
        }
        CHECK(mismatch == 0);
        CHECK(prefixMismatch == 0);
        CHECK(crossEqual == 0);
        if (mismatch || prefixMismatch || crossEqual)
            printf("TestZipName110: %d equality / %d prefix mismatches, %d cross-equal over %d strings\n", mismatch,
                   prefixMismatch, crossEqual, (int)strs.size());
    }

    // --- real files (NTFS %TEMP%): "the same name" = one file
    WCHAR t[MAX_PATH];
    DWORD tn = GetTempPathW(MAX_PATH, t);
    if (tn == 0 || tn >= MAX_PATH)
    {
        printf("skipping the file part of TestZipName110 (no temp path)\n");
        return;
    }
    std::wstring dir = std::wstring(t) + L"saltests-110-" + std::to_wstring(GetCurrentProcessId());
    CHECK(CreateDirectoryW(dir.c_str(), NULL) || GetLastError() == ERROR_ALREADY_EXISTS);
    auto twoFiles = [&](const std::string& first, const std::string& second) -> BOOL
    {
        WCHAR w1[64], w2[64];
        if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, first.c_str(), -1, w1, 64) == 0 ||
            MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, second.c_str(), -1, w2, 64) == 0)
            return -1;
        std::wstring p1 = dir + L"\\" + w1, p2 = dir + L"\\" + w2;
        HANDLE h1 = CreateFileW(p1.c_str(), GENERIC_WRITE, 0, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
        if (h1 == INVALID_HANDLE_VALUE)
            return -1;
        CloseHandle(h1);
        HANDLE h2 = CreateFileW(p2.c_str(), GENERIC_WRITE, 0, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
        BOOL two = h2 != INVALID_HANDLE_VALUE;
        if (two)
            CloseHandle(h2);
        DeleteFileW(p1.c_str());
        if (two)
            DeleteFileW(p2.c_str());
        return two;
    };
    for (int i = 0; i < _countof(differ); i++)
        CHECK(twoFiles(differ[i][0], differ[i][1]) == TRUE);
    for (auto& p : same)
        if (p.first.find('\\') == std::string::npos)
            CHECK(twoFiles(p.first, p.second) == FALSE);
    CHECK(RemoveDirectoryW(dir.c_str()));
}

// feature 112: a model of one disk-cache record (CCacheData, cache.cpp) driven through the same steps
// cache.cpp takes: a look-up (GetName) adds a request, AssignName turns it into a lock, ReleaseName
// drops it, WaitSatisfied removes a lock, FlushCache / FlushOneFile meet the record. 'Pinned' = the
// rule of feature 112 (CSalCacheEditPin, salcacheedit.h); otherwise the rule of every earlier
// release. An "edit lock" is the panel's lock on a copy it tracks for packing back (crtCacheEdit; the
// old rule had crtCache there). 'PendingEdit' = the copy holds a saved edit not packed yet.
struct CCacheRec112
{
    bool Pinned;
    bool Exists;
    std::vector<bool> Locks; // true = an edit lock
    int Requests;
    BOOL OutOfDate;
    BOOL Cached;
    int Creations; // the copy was (re-)created by a look-up: the member extracted into it
    bool PendingEdit;
    int Losses; // re-created while it held a pending edit: the edit extracted over
    int Normalized;
    CSalCacheEditPin Pin;

    explicit CCacheRec112(bool pinned)
    {
        Pinned = pinned;
        Exists = false;
        Requests = 0;
        OutOfDate = Cached = FALSE;
        Creations = Losses = Normalized = 0;
        PendingEdit = false;
    }
    bool InUse() const { return !Locks.empty() || Requests > 0; }
    int EditLocks() const { return (int)std::count(Locks.begin(), Locks.end(), true); }
    void Delete()
    {
        Exists = false;
        Locks.clear();
        Requests = 0;
        OutOfDate = Cached = FALSE;
        PendingEdit = false;
        Pin = CSalCacheEditPin();
    }
    void LookUp() // CDiskCache::GetName on the key
    {
        if (!Exists)
        {
            Exists = true;
            Requests = 1;
            Creations++;
            return;
        }
        Requests++;
        if (Pinned && Pin.Normalize(&OutOfDate))
            Normalized++;
        if (OutOfDate) // CCacheData::GetName: CleanFromDisk + the caller extracts over the copy
        {
            OutOfDate = FALSE;
            Creations++;
            if (PendingEdit)
                Losses++;
            PendingEdit = false;
        }
    }
    void Assign(bool edit) // CCacheData::AssignName (crtCache / crtCacheEdit)
    {
        Requests--;
        Locks.push_back(edit);
        if (!OutOfDate)
            Cached = TRUE;
        if (edit && Pinned)
            Pin.OnEditLockAdded(&OutOfDate);
    }
    void Release(BOOL storeInCache) // CCacheData::ReleaseName + CCacheDirData::ReleaseName
    {
        Requests--;
        if (!InUse())
        {
            if (storeInCache && !OutOfDate)
                Cached = TRUE;
            if (!Cached)
                Delete();
        }
    }
    void RemoveLock(int i) // CCacheData::WaitSatisfied + CDiskCache::WaitSatisfied
    {
        bool edit = Locks[i];
        Locks.erase(Locks.begin() + i);
        if (Pinned && Pin.OnLockRemoved(edit))
        {
            Cached = FALSE;
            OutOfDate = TRUE;
        }
        if (edit && EditLocks() == 0)
            PendingEdit = false; // the panel packed its edits before letting go
        if (!InUse() && !Cached)
            Delete();
    }
    void Flush() // CCacheDirData::FlushCache / FlushOneFile
    {
        if (!Exists)
            return;
        CSalCacheFlushAction a;
        if (Pinned)
            a = Pin.OnFlush(InUse());
        else
            a = InUse() ? scfaMarkOutOfDate : scfaDelete;
        if (a == scfaDelete)
            Delete();
        else if (a == scfaMarkOutOfDate)
        {
            Cached = FALSE;
            OutOfDate = TRUE;
        }
    }
    void Save() // the editor saves into the copy
    {
        if (EditLocks() > 0)
            PendingEdit = true;
    }
    bool InvariantHolds() const
    {
        if (!Pinned)
            return true;
        if (Pin.EditLocks != EditLocks())
            return false;
        if (Pin.StaleAfterEdit && Pin.EditLocks == 0)
            return false;
        if (OutOfDate && Pin.EditLocks > 0)
            return false;
        return true;
    }
};

static void TestCacheEdit112()
{
    // --- the rule itself ---
    {
        CSalCacheEditPin p;
        CHECK(p.EditLocks == 0 && !p.StaleAfterEdit);
        CHECK(p.OnFlush(FALSE) == scfaDelete);
        CHECK(p.OnFlush(TRUE) == scfaMarkOutOfDate);
        CHECK(!p.StaleAfterEdit);
        BOOL ood = FALSE;
        p.OnEditLockAdded(&ood);
        CHECK(p.EditLocks == 1 && !ood && !p.StaleAfterEdit);
        CHECK(p.OnFlush(TRUE) == scfaDeferStale && p.StaleAfterEdit);
        CHECK(p.OnFlush(FALSE) == scfaDelete); // not in use: deleted (a record with a lock is always in use)
        CHECK(!p.OnLockRemoved(FALSE));        // a viewer's lock: nothing
        CHECK(p.EditLocks == 1 && p.StaleAfterEdit);
        CHECK(p.OnLockRemoved(TRUE)); // the last edit lock: the deferred mark is due
        CHECK(p.EditLocks == 0 && !p.StaleAfterEdit);
        CHECK(!p.OnLockRemoved(TRUE)); // no underflow, nothing due twice
        CHECK(p.EditLocks == 0);
    }
    {
        CSalCacheEditPin p; // two edit locks (both panels track the copy): due only with the second
        BOOL ood = FALSE;
        p.OnEditLockAdded(&ood);
        p.OnEditLockAdded(&ood);
        CHECK(p.OnFlush(TRUE) == scfaDeferStale);
        CHECK(!p.OnLockRemoved(TRUE));
        CHECK(p.StaleAfterEdit && p.EditLocks == 1);
        CHECK(p.OnFlush(TRUE) == scfaDeferStale);
        CHECK(p.OnLockRemoved(TRUE));
    }
    {
        CSalCacheEditPin p; // a mark set between the look-up and the edit lock is taken over
        BOOL ood = TRUE;
        p.OnEditLockAdded(&ood);
        CHECK(!ood && p.StaleAfterEdit && p.EditLocks == 1);
        CHECK(p.OnLockRemoved(TRUE));
    }
    {
        CSalCacheEditPin p; // without a flush the last edit lock leaves the copy as it is (cached)
        BOOL ood = FALSE;
        p.OnEditLockAdded(&ood);
        CHECK(!p.OnLockRemoved(TRUE));
    }
    {
        CSalCacheEditPin p; // Normalize: a consistent record is left alone
        BOOL ood = TRUE;
        CHECK(!p.Normalize(&ood) && ood);
        ood = FALSE;
        CHECK(!p.Normalize(&ood) && !ood);
        BOOL o2 = FALSE;
        p.OnEditLockAdded(&o2);
        CHECK(!p.Normalize(&ood) && !ood);
        ood = TRUE; // broken: an out-of-date mark beside an edit lock - turned into the deferred mark
        CHECK(p.Normalize(&ood) && !ood && p.StaleAfterEdit);
        CSalCacheEditPin q; // broken: a deferred mark without an edit lock - becomes the real mark
        q.StaleAfterEdit = TRUE;
        ood = FALSE;
        CHECK(q.Normalize(&ood) && ood && !q.StaleAfterEdit);
    }

    // --- the scenarios of research.md 2, the old rule vs feature 112 ---
    for (int pinned = 0; pinned < 2; pinned++)
    {
        // S1 own-F3: L F4 x + save; R updates the archive (flush); L F3 x; L leaves (packs, lets go)
        CCacheRec112 r(pinned != 0);
        r.LookUp();
        r.Assign(true); // L's edit lock
        r.Save();
        r.Flush(); // R's update of another member: the flush of the archive's keys
        r.LookUp();
        r.Assign(false); // L's F3: the viewer's lock
        CHECK(r.Losses == (pinned ? 0 : 1));
        CHECK(r.InvariantHolds());
        r.RemoveLock(1); // the viewer ends
        CHECK(r.Exists);
        r.RemoveLock(0); // L packs and lets go
        // new: the deferred mark - deleted; old: the re-created copy (the edit gone) stays cached
        CHECK(pinned ? !r.Exists : r.Exists);
        CHECK(r.InvariantHolds());
    }
    for (int pinned = 0; pinned < 2; pinned++)
    {
        // S1 own-F4: the second F4 of L on the same member (already tracked: the request is released)
        CCacheRec112 r(pinned != 0);
        r.LookUp();
        r.Assign(true);
        r.Save();
        r.Flush();
        r.LookUp();
        r.Release(FALSE);
        CHECK(r.Losses == (pinned ? 0 : 1));
        CHECK(r.Exists && r.Locks.size() == 1);
        r.Save();
        r.RemoveLock(0);
        CHECK(!r.Exists);
    }
    for (int pinned = 0; pinned < 2; pinned++)
    {
        // S6 shared: L and R track one copy; R packs and lets go, flushes; L F3; L lets go
        CCacheRec112 r(pinned != 0);
        r.LookUp();
        r.Assign(true); // L
        r.LookUp();
        r.Assign(true); // R (the same copy, it exists)
        r.Save();
        r.RemoveLock(1);      // R packs (the shared file holds the edit) and lets go
        r.PendingEdit = true; // L has not packed yet (its stamp is older than the file)
        r.Flush();
        r.LookUp();
        r.Assign(false);
        CHECK(r.Losses == (pinned ? 0 : 1));
        r.RemoveLock(1);
        r.RemoveLock(0);
        CHECK(pinned ? !r.Exists : r.Exists); // as in S1 own-F3
        CHECK(r.InvariantHolds());
    }
    {
        // a flush between the look-up and the edit lock (during the extraction): the copy is fresh,
        // not cached, and out of date only when the edit lock goes
        CCacheRec112 r(true);
        r.LookUp();
        r.Flush(); // in use by the request: marked out of date
        CHECK(r.OutOfDate);
        r.Assign(true);
        CHECK(!r.OutOfDate && !r.Cached && r.Pin.StaleAfterEdit && r.InvariantHolds());
        r.Save();
        r.LookUp();
        r.Release(FALSE);
        CHECK(r.Losses == 0 && r.Creations == 1);
        r.RemoveLock(0);
        CHECK(!r.Exists);
    }
    for (int pinned = 0; pinned < 2; pinned++)
    {
        // no flush: the panel lets go, the copy stays cached (as every release did with crtCache)
        CCacheRec112 r(pinned != 0);
        r.LookUp();
        r.Assign(true);
        r.RemoveLock(0);
        CHECK(r.Exists && r.Cached && !r.OutOfDate);
        r.LookUp(); // reused, not extracted again
        CHECK(r.Creations == 1);
        r.Release(TRUE);
        r.Flush();
        CHECK(!r.Exists);
    }
    {
        // a viewer's copy (F3, the plug-ins): marked out of date by a flush and re-created - unchanged
        CCacheRec112 r(true);
        r.LookUp();
        r.Assign(false);
        r.Flush();
        CHECK(r.OutOfDate);
        r.LookUp();
        CHECK(r.Creations == 2);
        r.Assign(false);
        r.RemoveLock(0);
        r.RemoveLock(0);
        CHECK(r.Exists && r.Cached); // the view after the re-creation: cached again
    }

    // --- random sequences: without edit locks the new rule is the old one step by step (the
    //     plug-ins' and the viewers' use of the cache is unchanged); with them no pending edit is
    //     ever extracted over, the invariant holds after every step and the deferred mark arrives
    //     with the last edit lock; the old rule loses edits ---
    unsigned seed = 112;
    auto rnd = [&seed](int n) -> int
    {
        seed = seed * 1103515245u + 12345u;
        return (int)((seed >> 16) % (unsigned)n);
    };
    int parityMismatch = 0, invariantBroken = 0, newLosses = 0, oldLosses = 0, deferredLost = 0, normalized = 0;
    for (int run = 0; run < 40000; run++)
    {
        bool withEdit = (run % 2) == 1;
        CCacheRec112 a(true), b(false);
        for (int step = 0; step < 16; step++)
        {
            int op = rnd(6);
            int pick = rnd(8);
            switch (op)
            {
            case 0: // F4 (an edit lock) or F3 (a viewer's lock)
            case 1:
            {
                bool edit = withEdit && op == 0;
                a.LookUp();
                b.LookUp();
                a.Assign(edit);
                b.Assign(edit);
                break;
            }
            case 2: // a request released (already tracked / not unpacked / stored in the cache)
            {
                BOOL store = (pick & 1) != 0;
                a.LookUp();
                b.LookUp();
                a.Release(store);
                b.Release(store);
                break;
            }
            case 3: // a lock goes
                if (!a.Locks.empty() && a.Locks.size() == b.Locks.size())
                {
                    int i = pick % (int)a.Locks.size();
                    bool due = a.Locks[i] && a.EditLocks() == 1 && a.Pin.StaleAfterEdit;
                    a.RemoveLock(i);
                    b.RemoveLock(i);
                    if (due && a.Exists && !a.OutOfDate)
                        deferredLost++;
                }
                break;
            case 4: // a flush of the archive's keys
                a.Flush();
                b.Flush();
                break;
            case 5:
                a.Save();
                b.Save();
                break;
            }
            if (!a.InvariantHolds())
                invariantBroken++;
            if (!withEdit &&
                (a.Exists != b.Exists || a.OutOfDate != b.OutOfDate || a.Cached != b.Cached ||
                 a.Creations != b.Creations || a.Locks != b.Locks || a.Requests != b.Requests))
                parityMismatch++;
        }
        newLosses += a.Losses;
        oldLosses += b.Losses;
        normalized += a.Normalized;
    }
    CHECK(parityMismatch == 0);
    CHECK(invariantBroken == 0);
    CHECK(newLosses == 0);
    CHECK(oldLosses > 0); // the model reproduces the defect under the old rule
    CHECK(deferredLost == 0);
    CHECK(normalized == 0); // the guard in the look-up never has to act
    if (parityMismatch || invariantBroken || newLosses || !oldLosses || deferredLost || normalized)
        printf("TestCacheEdit112: parity %d, invariant %d, losses new %d / old %d, deferred lost %d, normalized %d\n",
               parityMismatch, invariantBroken, newLosses, oldLosses, deferredLost, normalized);
}

// ---------------------------------------------------------------------------
// feature 113: a replaced ZIP member put back (salzipmember.h)

typedef std::vector<unsigned char> Bytes113;

static void Put16_113(Bytes113& b, unsigned v)
{
    b.push_back((unsigned char)(v & 0xFF));
    b.push_back((unsigned char)((v >> 8) & 0xFF));
}
static void Put32_113(Bytes113& b, unsigned long v)
{
    for (int i = 0; i < 4; i++)
        b.push_back((unsigned char)((v >> (8 * i)) & 0xFF));
}
static void Put64_113(Bytes113& b, unsigned long long v)
{
    for (int i = 0; i < 8; i++)
        b.push_back((unsigned char)((v >> (8 * i)) & 0xFF));
}
static unsigned Get16_113(const unsigned char* p) { return p[0] | (p[1] << 8); }
static unsigned long Get32_113(const unsigned char* p)
{
    return (unsigned long)p[0] | ((unsigned long)p[1] << 8) | ((unsigned long)p[2] << 16) | ((unsigned long)p[3] << 24);
}
static unsigned long long Get64_113(const unsigned char* p)
{
    return (unsigned long long)Get32_113(p) | ((unsigned long long)Get32_113(p + 4) << 32);
}

// a central directory record; fields that are "in64" get the marker and go into a zip64 block
// (placed after the 'before' extra bytes, followed by the 'after' extra bytes)
struct CRec113
{
    unsigned VersionNeeded = 20;
    unsigned long long Size = 100, Comp = 60, Offs = 1000;
    unsigned long Disk = 0;
    bool SizeIn64 = false, CompIn64 = false, OffsIn64 = false, DiskIn64 = false;
    bool Z64Block = true; // write the zip64 block when something is in64
    std::string Name = "dir/name.txt";
    Bytes113 Before, After; // other extra blocks
    std::string Comment;
};

static Bytes113 MakeRec113(const CRec113& r)
{
    Bytes113 z64data;
    if (r.SizeIn64)
        Put64_113(z64data, r.Size);
    if (r.CompIn64)
        Put64_113(z64data, r.Comp);
    if (r.OffsIn64)
        Put64_113(z64data, r.Offs);
    if (r.DiskIn64)
        Put32_113(z64data, r.Disk);
    Bytes113 extra = r.Before;
    if (r.Z64Block && !z64data.empty())
    {
        Put16_113(extra, 1);
        Put16_113(extra, (unsigned)z64data.size());
        extra.insert(extra.end(), z64data.begin(), z64data.end());
    }
    extra.insert(extra.end(), r.After.begin(), r.After.end());
    Bytes113 b;
    Put32_113(b, 0x02014B50UL);
    Put16_113(b, (3 << 8) | 63);   // made by: Unix, 6.3
    Put16_113(b, r.VersionNeeded); // needed
    Put16_113(b, 0x0809);          // flag (UTF-8 + descriptor + encrypted)
    Put16_113(b, 99);              // method (AES)
    Put16_113(b, 0x1234);
    Put16_113(b, 0x5678);
    Put32_113(b, 0xCAFEBABEUL);
    Put32_113(b, r.CompIn64 ? 0xFFFFFFFFUL : (unsigned long)r.Comp);
    Put32_113(b, r.SizeIn64 ? 0xFFFFFFFFUL : (unsigned long)r.Size);
    Put16_113(b, (unsigned)r.Name.size());
    Put16_113(b, (unsigned)extra.size());
    Put16_113(b, (unsigned)r.Comment.size());
    Put16_113(b, r.DiskIn64 ? 0xFFFF : (unsigned)r.Disk);
    Put16_113(b, 1);
    Put32_113(b, 0x81A40020UL);
    Put32_113(b, r.OffsIn64 ? 0xFFFFFFFFUL : (unsigned long)r.Offs);
    b.insert(b.end(), r.Name.begin(), r.Name.end());
    b.insert(b.end(), extra.begin(), extra.end());
    b.insert(b.end(), r.Comment.begin(), r.Comment.end());
    return b;
}

// reads a record the way the ZIP plug-in's ProcessHeader does (the first zip64 block, marked fields
// in order); false when a marked field has no value
static bool ParseRec113(const unsigned char* p, size_t len, unsigned long long* size, unsigned long long* comp,
                        unsigned long long* offs, unsigned long* disk)
{
    if (len < 46 || Get32_113(p) != 0x02014B50UL)
        return false;
    size_t n = Get16_113(p + 28), x = Get16_113(p + 30), c = Get16_113(p + 32);
    if (46 + n + x + c != len)
        return false;
    *size = Get32_113(p + 24);
    *comp = Get32_113(p + 20);
    *offs = Get32_113(p + 42);
    *disk = Get16_113(p + 34);
    bool needS = *size == 0xFFFFFFFFULL, needC = *comp == 0xFFFFFFFFULL, needO = *offs == 0xFFFFFFFFULL, needD = *disk == 0xFFFF;
    if (!needS && !needC && !needO && !needD)
        return true;
    const unsigned char* e = p + 46 + n;
    size_t i = 0;
    while (i + 4 <= x)
    {
        size_t id = Get16_113(e + i), l = Get16_113(e + i + 2);
        if (i + 4 + l > x)
            return false;
        if (id == 1)
        {
            const unsigned char* d = e + i + 4;
            size_t want = (needS ? 8 : 0) + (needC ? 8 : 0) + (needO ? 8 : 0) + (needD ? 4 : 0);
            if (l < want)
                return false;
            if (needS)
                *size = Get64_113(d), d += 8;
            if (needC)
                *comp = Get64_113(d), d += 8;
            if (needO)
                *offs = Get64_113(d), d += 8;
            if (needD)
                *disk = Get32_113(d);
            return true;
        }
        i += 4 + l;
    }
    return false;
}

// the extra blocks other than zip64 (id, data) - what a relocation must keep
static std::vector<Bytes113> OtherBlocks113(const unsigned char* p, size_t len)
{
    std::vector<Bytes113> out;
    size_t n = Get16_113(p + 28), x = Get16_113(p + 30);
    const unsigned char* e = p + 46 + n;
    size_t i = 0;
    while (i + 4 <= x && i + 4 + Get16_113(e + i + 2) <= x)
    {
        size_t l = Get16_113(e + i + 2);
        if (Get16_113(e + i) != 1)
            out.push_back(Bytes113(e + i, e + i + 4 + l));
        i += 4 + l;
    }
    return out;
}

static void TestZipMember113()
{
    // --- SalZipMemberSpan: the count DeleteFiles leaves out
    CHECK(SalZipMemberSpan(5, 0, 100, 0, 200, 0) == 30 + 5 + 100);
    CHECK(SalZipMemberSpan(5, 9, 100, 0x0800, 200, 0) == 30 + 5 + 9 + 100);                    // bit 11 is not bit 3
    CHECK(SalZipMemberSpan(5, 9, 100, SALZIP_GPF_DATADESCR, 200, 0) == 30 + 5 + 9 + 100 + 16); // descriptor
    CHECK(SalZipMemberSpan(5, 9, 100, SALZIP_GPF_DATADESCR, 0xFFFFFFFFULL, 0) == 30 + 5 + 9 + 100 + 24);
    CHECK(SalZipMemberSpan(5, 9, 0xFFFFFFFFULL, SALZIP_GPF_DATADESCR, 1, 0) == 30 + 5 + 9 + 0xFFFFFFFFULL + 24);
    CHECK(SalZipMemberSpan(5, 9, 100, SALZIP_GPF_DATADESCR, 200, 0xFFFFFFFFULL) == 30 + 5 + 9 + 100 + 24);
    CHECK(SalZipMemberSpan(5, 9, 100, SALZIP_GPF_DATADESCR, 200, 0xFFFFFFFEULL) == 30 + 5 + 9 + 100 + 16);
    CHECK(SalZipMemberSpan(0xFFFF, 0xFFFF, 0, 0, 0, 0) == 30 + 0xFFFFULL + 0xFFFF);

    // --- SalZipCentralRecordLen
    CRec113 base;
    base.Comment = "a comment";
    base.Before = Bytes113{0x55, 0x54, 5, 0, 1, 2, 3, 4, 5};                    // 0x5455 time stamp
    base.After = Bytes113{0x01, 0x99, 7, 0, 2, 0, 'A', 'E', 3, 8, 0};             // 0x9901 AES
    Bytes113 r0 = MakeRec113(base);
    CHECK(SalZipCentralRecordLen(r0.data(), r0.size()) == r0.size());
    CHECK(SalZipCentralRecordLen(r0.data(), r0.size() + 10) == r0.size());
    CHECK(SalZipCentralRecordLen(r0.data(), r0.size() - 1) == 0);
    CHECK(SalZipCentralRecordLen(r0.data(), 45) == 0);
    CHECK(SalZipCentralRecordLen(NULL, 100) == 0);
    {
        Bytes113 bad = r0;
        bad[0] = 0x51;
        CHECK(SalZipCentralRecordLen(bad.data(), bad.size()) == 0);
    }

    // --- relocation, fixed cases
    unsigned char dst[70000 + 64];
    {
        // 32-bit offset, new offset fits: only bytes 42..45 change
        size_t l = SalZipRelocateCentralRecord(r0.data(), r0.size(), 0x12345678ULL, dst, sizeof(dst));
        CHECK(l == r0.size());
        bool sameElse = true;
        for (size_t i = 0; i < r0.size(); i++)
            if ((i < 42 || i > 45) && dst[i] != r0[i])
                sameElse = false;
        CHECK(sameElse);
        CHECK(Get32_113(dst + 42) == 0x12345678UL);
        CHECK(SalZipRelocateCentralRecord(r0.data(), r0.size(), 0xFFFFFFFEULL, dst, sizeof(dst)) == r0.size());
        CHECK(Get32_113(dst + 42) == 0xFFFFFFFEUL);
        // too small a destination; a wrong length; no destination
        CHECK(SalZipRelocateCentralRecord(r0.data(), r0.size(), 5, dst, r0.size() - 1) == 0);
        CHECK(SalZipRelocateCentralRecord(r0.data(), r0.size() - 1, 5, dst, sizeof(dst)) == 0);
        CHECK(SalZipRelocateCentralRecord(r0.data(), r0.size(), 5, NULL, sizeof(dst)) == 0);
    }
    {
        // 32-bit offset, new offset needs 64 bits, no zip64 block: a block is added FIRST (review S1:
        // the ZIP plug-in writes its zip64 block first, and its UpdateCentrDir looked only there)
        size_t l = SalZipRelocateCentralRecord(r0.data(), r0.size(), 0x100000000ULL, dst, sizeof(dst));
        CHECK(l == r0.size() + 12);
        unsigned long long s, c, o;
        unsigned long d;
        CHECK(ParseRec113(dst, l, &s, &c, &o, &d) && o == 0x100000000ULL && s == 100 && c == 60);
        CHECK(Get32_113(dst + 42) == 0xFFFFFFFFUL);
        CHECK(Get16_113(dst + 6) == 45);
        CHECK(OtherBlocks113(dst, l) == OtherBlocks113(r0.data(), r0.size()));
        CHECK(memcmp(dst + l - base.Comment.size(), base.Comment.data(), base.Comment.size()) == 0);
        CHECK(memcmp(dst + 46, base.Name.data(), base.Name.size()) == 0);
        CHECK(memcmp(dst + 4, r0.data() + 4, 2) == 0 && memcmp(dst + 8, r0.data() + 8, 20) == 0 &&
              memcmp(dst + 32, r0.data() + 32, 10) == 0);
        size_t ex = 46 + base.Name.size();
        CHECK(Get16_113(dst + ex) == 1 && Get16_113(dst + ex + 2) == 8 && Get64_113(dst + ex + 4) == 0x100000000ULL);
        CHECK(memcmp(dst + ex + 12, r0.data() + ex, base.Before.size() + base.After.size()) == 0); // the others follow, unchanged
        // the minimum capacity is exactly 12 more
        CHECK(SalZipRelocateCentralRecord(r0.data(), r0.size(), 0x100000000ULL, dst, r0.size() + 11) == 0);
        CHECK(SalZipRelocateCentralRecord(r0.data(), r0.size(), 0x100000000ULL, dst, r0.size() + 12) == r0.size() + 12);
    }
    {
        // "version needed" keeps its high byte and is not lowered
        CRec113 v = base;
        v.VersionNeeded = 0x0314;
        Bytes113 r = MakeRec113(v);
        size_t l = SalZipRelocateCentralRecord(r.data(), r.size(), 0x200000000ULL, dst, sizeof(dst));
        CHECK(l == r.size() + 12 && Get16_113(dst + 6) == 0x032D);
        v.VersionNeeded = 63;
        r = MakeRec113(v);
        l = SalZipRelocateCentralRecord(r.data(), r.size(), 0x200000000ULL, dst, sizeof(dst));
        CHECK(l == r.size() + 12 && Get16_113(dst + 6) == 63);
    }
    {
        // the offset is marked but there is no zip64 block / the block is too short: not rewritten
        CRec113 v = base;
        v.OffsIn64 = true;
        v.Z64Block = false;
        Bytes113 r = MakeRec113(v);
        CHECK(SalZipRelocateCentralRecord(r.data(), r.size(), 5, dst, sizeof(dst)) == 0);
        CRec113 w = base;
        w.SizeIn64 = true;
        Bytes113 rs = MakeRec113(w); // block holds the size only
        rs[42] = rs[43] = rs[44] = rs[45] = 0xFF;                       // ... but the offset is marked
        CHECK(SalZipRelocateCentralRecord(rs.data(), rs.size(), 5, dst, sizeof(dst)) == 0);
    }
    {
        // a malformed extra field: a small offset is still patched in place; a large one is not
        Bytes113 r = r0;
        size_t extraAt = 46 + base.Name.size();
        r[extraAt + 2] = 0x40; // the first block claims more than the field holds
        CHECK(SalZipRelocateCentralRecord(r.data(), r.size(), 77, dst, sizeof(dst)) == r.size());
        CHECK(Get32_113(dst + 42) == 77);
        CHECK(SalZipRelocateCentralRecord(r.data(), r.size(), 0x100000000ULL, dst, sizeof(dst)) == 0);
        // trailing bytes that are not a block (3 bytes)
        CRec113 t = base;
        t.After.push_back(0xAA);
        t.After.push_back(0xBB);
        t.After.push_back(0xCC);
        Bytes113 rt = MakeRec113(t);
        CHECK(SalZipRelocateCentralRecord(rt.data(), rt.size(), 0x100000000ULL, dst, sizeof(dst)) == 0);
        CHECK(SalZipRelocateCentralRecord(rt.data(), rt.size(), 9, dst, sizeof(dst)) == rt.size());
    }
    {
        // an extra field near its 65,535-byte limit cannot take 12 (or 8) more bytes
        CRec113 big = base;
        big.Before.clear();
        big.After.clear();
        Put16_113(big.Before, 0x7777);
        Put16_113(big.Before, 65531 - 4);
        big.Before.resize(65531, 0x11); // 65,531 bytes of extra field
        big.Comment.clear();
        Bytes113 r = MakeRec113(big);
        CHECK(SalZipCentralRecordLen(r.data(), r.size()) == r.size());
        CHECK(SalZipRelocateCentralRecord(r.data(), r.size(), 0x100000000ULL, dst, sizeof(dst)) == 0); // 65,543 > 65,535
        CHECK(SalZipRelocateCentralRecord(r.data(), r.size(), 3, dst, sizeof(dst)) == r.size());
        big.Before.clear(); // 65,523 + 12 = 65,535: still fits
        Put16_113(big.Before, 0x7777);
        Put16_113(big.Before, 65523 - 4);
        big.Before.resize(65523, 0x22);
        r = MakeRec113(big);
        size_t l = SalZipRelocateCentralRecord(r.data(), r.size(), 0x100000000ULL, dst, sizeof(dst));
        CHECK(l == r.size() + 12 && Get16_113(dst + 30) == 65535);
    }

    // --- review S1: where the offset is read and updated later (the plug-in's UpdateCentrDir after an
    // F5-replace / F8 of an earlier member). Before 113 it assumed the zip64 block FIRST; now it uses
    // SalZipCentralRecordOffsetPos (the block found by its id).
    {
        auto oldPos = [](const unsigned char* rec) -> size_t { // the pre-113 UpdateCentrDir, transcribed
            if (Get32_113(rec + 42) != 0xFFFFFFFFUL || Get16_113(rec + 30) < 2 + 2 + 8)
                return 42;
            size_t p = 46 + Get16_113(rec + 28) + 4;
            if (Get32_113(rec + 20) == 0xFFFFFFFFUL)
                p += 8;
            if (Get32_113(rec + 24) == 0xFFFFFFFFUL)
                p += 8;
            return p;
        };
        Bytes113 aes{0x01, 0x99, 7, 0, 2, 0, 'A', 'E', 3, 8, 0};    // the plug-in's own AES block
        Bytes113 ntfs{0x0A, 0x00, 4, 0, 0, 0, 0, 0};                 // an NTFS block (header only)
        // a member with AES + NTFS blocks put back above 4 GiB
        CRec113 m = base;
        m.Before = ntfs;
        m.After = aes;
        Bytes113 r = MakeRec113(m);
        const unsigned long long at = 0x140000000ULL;
        size_t l = SalZipRelocateCentralRecord(r.data(), r.size(), at, dst, sizeof(dst));
        CHECK(l == r.size() + 12);
        size_t pos = SalZipCentralRecordOffsetPos(dst, l);
        CHECK(pos != 0 && pos != 42 && Get64_113(dst + pos) == at);
        CHECK(oldPos(dst) == pos); // the layout also suits the old reader
        // a later compaction moves it down by 'delta': written where the offset is, nothing else changes
        Bytes113 moved(dst, dst + l);
        unsigned long long down = at - 0x1000;
        for (int k = 0; k < 8; k++)
            moved[pos + k] = (unsigned char)((down >> (8 * k)) & 0xFF);
        unsigned long long s, c, o;
        unsigned long d;
        CHECK(ParseRec113(moved.data(), l, &s, &c, &o, &d) && o == down);
        CHECK(OtherBlocks113(moved.data(), l) == OtherBlocks113(r.data(), r.size())); // AES block intact
        // a foreign record: zip64 block AFTER the AES block (other writers, or a block appended)
        CRec113 f = base;
        f.Before = aes;
        f.After = ntfs;
        f.OffsIn64 = true;
        f.Offs = 0x180000000ULL;
        Bytes113 rf = MakeRec113(f);
        size_t posF = SalZipCentralRecordOffsetPos(rf.data(), rf.size());
        CHECK(posF != 0 && posF != 42 && Get64_113(rf.data() + posF) == f.Offs);
        CHECK(oldPos(rf.data()) != posF); // the old reader looked inside the AES block (the defect)
        CHECK(Get64_113(rf.data() + oldPos(rf.data())) != f.Offs);
        // with the size and the compressed size marked too
        f.SizeIn64 = f.CompIn64 = true;
        f.Size = 0x100000005ULL;
        f.Comp = 0x100000006ULL;
        rf = MakeRec113(f);
        posF = SalZipCentralRecordOffsetPos(rf.data(), rf.size());
        CHECK(posF != 0 && Get64_113(rf.data() + posF) == f.Offs);
        // not marked: the 32-bit field; marked without a block / with a short block / incomplete: 0
        CHECK(SalZipCentralRecordOffsetPos(r0.data(), r0.size()) == 42);
        CRec113 nb = base;
        nb.OffsIn64 = true;
        nb.Z64Block = false;
        Bytes113 rn = MakeRec113(nb);
        CHECK(SalZipCentralRecordOffsetPos(rn.data(), rn.size()) == 0);
        CHECK(SalZipCentralRecordOffsetPos(rf.data(), rf.size() - 1) == 0);
        CRec113 sh = base;
        sh.SizeIn64 = true;
        Bytes113 rs = MakeRec113(sh);
        rs[42] = rs[43] = rs[44] = rs[45] = 0xFF;
        CHECK(SalZipCentralRecordOffsetPos(rs.data(), rs.size()) == 0);
    }

    // --- review R1: a member's computed end is bounded by the next member ON DISK
    {
        // NM: the bound, or ~0 for "unknown" (the bound fails closed - re-check NIT 1)
        auto NM = [](const Bytes113& d, size_t len, unsigned long long after, unsigned long long limit) {
            unsigned long long n = 0;
            return SalZipNextMemberOffset(len ? d.data() : NULL, len, after, limit, &n) ? n : ~0ULL;
        };
        // a central directory: x at 0, y at 120 (32-bit), z at 260 (offset in zip64); w broken (marker, no block)
        CRec113 rx = base, ry = base, rz = base, rw = base;
        rx.Offs = 0;
        ry.Offs = 120;
        rz.Offs = 260;
        rz.OffsIn64 = true;
        rw.OffsIn64 = true;
        rw.Z64Block = false;
        Bytes113 dir;
        for (const CRec113* c : {&rx, &rz, &ry}) // not in disk order
        {
            Bytes113 r = MakeRec113(*c);
            dir.insert(dir.end(), r.begin(), r.end());
        }
        const unsigned long long cdOffs = 400;
        CHECK(NM(dir, dir.size(), 0, cdOffs) == 120);
        CHECK(NM(dir, dir.size(), 50, cdOffs) == 120);
        CHECK(NM(dir, dir.size(), 120, cdOffs) == 260); // the zip64 offset counts
        CHECK(NM(dir, dir.size(), 260, cdOffs) == cdOffs);
        CHECK(NM(dir, dir.size(), 0, 100) == 100); // limit below every member
        CHECK(NM(dir, 0, 0, cdOffs) == cdOffs);    // an empty directory
        // fails closed: a truncated directory, a record whose offset cannot be read - unknown, also when
        // the unreadable record comes after the nearer member
        CHECK(NM(dir, dir.size() - 1, 120, cdOffs) == ~0ULL);
        CHECK(NM(dir, dir.size() - 1, 0, cdOffs) == ~0ULL);
        Bytes113 dirW = dir, rwb0 = MakeRec113(rw);
        dirW.insert(dirW.end(), rwb0.begin(), rwb0.end());
        CHECK(NM(dirW, dirW.size(), 260, cdOffs) == ~0ULL);
        CHECK(NM(dirW, dirW.size(), 0, cdOffs) == ~0ULL);
        Bytes113 dirW2 = rwb0;
        dirW2.insert(dirW2.end(), dir.begin(), dir.end()); // the broken record first
        CHECK(NM(dirW2, dirW2.size(), 0, cdOffs) == ~0ULL);
        unsigned long long dummy = 0;
        CHECK(!SalZipNextMemberOffset(NULL, 100, 0, cdOffs, &dummy));
        unsigned long long o = 0;
        Bytes113 rwb = MakeRec113(rw);
        CHECK(!SalZipCentralRecordOffset(rwb.data(), rwb.size(), &o));
        Bytes113 rzb = MakeRec113(rz);
        CHECK(SalZipCentralRecordOffset(rzb.data(), rzb.size(), &o) && o == 260);
        // the case: x (name 9, extra 4, 80 bytes of data) written with a 12-byte descriptor (no
        // signature), y right after it. The count assumes 16 bytes: 4 past y - refused; the old guard
        // (the next DELETED member, none -> the central directory) let it through.
        unsigned long long realEnd = 30 + 9 + 4 + 80 + 12;
        unsigned long long counted = SalZipMemberSpan(9, 4, 80, SALZIP_GPF_DATADESCR, 80, 0);
        CHECK(counted == realEnd + 4);
        CRec113 x2 = base, y2 = base;
        x2.Offs = 0;
        y2.Offs = realEnd;
        Bytes113 dir2 = MakeRec113(x2), ry2 = MakeRec113(y2);
        dir2.insert(dir2.end(), ry2.begin(), ry2.end());
        CHECK(counted > NM(dir2, dir2.size(), 0, cdOffs)); // refused now
        CHECK(counted <= cdOffs);                                                     // passed before
        // with its signature (16 bytes) the end is exactly the next member: accepted
        y2.Offs = realEnd + 4;
        dir2 = MakeRec113(x2);
        ry2 = MakeRec113(y2);
        dir2.insert(dir2.end(), ry2.begin(), ry2.end());
        CHECK(counted == NM(dir2, dir2.size(), 0, cdOffs));
    }
    // --- review N-a: a length below the fixed part is never read
    {
        unsigned char tiny[8] = {0x50, 0x4B, 1, 2, 0, 0, 0, 0};
        CHECK(SalZipCentralRecordOffsetPos(tiny, 0) == 0);
        CHECK(SalZipCentralRecordOffsetPos(tiny, 8) == 0);
        CHECK(SalZipCentralRecordOffsetPos(r0.data(), 45) == 0);
        CHECK(SalZipCentralRecordOffsetPos(NULL, 100) == 0);
        CHECK(SalZipRelocateCentralRecord(tiny, 0, 5, dst, sizeof(dst)) == 0);
        CHECK(SalZipRelocateCentralRecord(r0.data(), 45, 5, dst, sizeof(dst)) == 0);
        CHECK(SalZipRelocateCentralRecord(NULL, 0, 5, dst, sizeof(dst)) == 0);
        unsigned long long o = 0;
        CHECK(!SalZipCentralRecordOffset(tiny, 0, &o));
    }

    // --- relocation, every combination: what a reader sees afterwards
    const unsigned long long offsets[] = {0, 1234, 0xFFFFFFFEULL, 0xFFFFFFFFULL, 0x100000000ULL, 0x123456789ABCULL};
    int combos = 0, bad = 0;
    for (int mask = 0; mask < 16; mask++)
    {
        for (int layout = 0; layout < 4; layout++) // other blocks: none, before, after, both
        {
            for (unsigned long long oldOffs : {500ULL, 0x1FFFFFFFFULL})
            {
                for (unsigned long long newOffs : offsets)
                {
                    CRec113 v;
                    v.SizeIn64 = (mask & 1) != 0;
                    v.CompIn64 = (mask & 2) != 0;
                    v.OffsIn64 = (mask & 4) != 0 || oldOffs >= 0xFFFFFFFFULL;
                    v.DiskIn64 = (mask & 8) != 0;
                    v.Size = 0x1000000AAULL;
                    v.Comp = 0x1000000BBULL;
                    v.Offs = oldOffs;
                    v.Disk = 0x10000;
                    if (!v.SizeIn64)
                        v.Size = 77;
                    if (!v.CompIn64)
                        v.Comp = 66;
                    if (!v.DiskIn64)
                        v.Disk = 0;
                    if (layout & 1)
                        v.Before = Bytes113{0x55, 0x54, 1, 0, 9};
                    if (layout & 2)
                        v.After = Bytes113{0x75, 0x70, 3, 0, 1, 2, 3};
                    v.Comment = (mask & 1) ? "" : "x";
                    Bytes113 r = MakeRec113(v);
                    size_t l = SalZipRelocateCentralRecord(r.data(), r.size(), newOffs, dst, sizeof(dst));
                    combos++;
                    unsigned long long s, c, o;
                    unsigned long d;
                    bool ok = l != 0 && ParseRec113(dst, l, &s, &c, &o, &d) && s == v.Size && c == v.Comp && o == newOffs &&
                              d == v.Disk && OtherBlocks113(dst, l) == OtherBlocks113(r.data(), r.size()) &&
                              memcmp(dst + 46, v.Name.data(), v.Name.size()) == 0 &&
                              memcmp(dst + l - v.Comment.size(), v.Comment.data(), v.Comment.size()) == 0 &&
                              memcmp(dst + 4, r.data() + 4, 2) == 0 && memcmp(dst + 8, r.data() + 8, 20) == 0 &&
                              memcmp(dst + 32, r.data() + 32, 10) == 0;
                    // the length grows only when the offset newly needs 64 bits
                    size_t grow = v.OffsIn64 || newOffs < 0xFFFFFFFFULL ? 0 : ((v.SizeIn64 || v.CompIn64 || v.DiskIn64) ? 8 : 12);
                    ok = ok && l == r.size() + grow;
                    size_t op = l ? SalZipCentralRecordOffsetPos(dst, l) : 0; // review S1: found by its id
                    ok = ok && op != 0 && (op == 42 ? Get32_113(dst + 42) == newOffs : Get64_113(dst + op) == newOffs);
                    if (!ok)
                    {
                        bad++;
                        if (bad <= 5)
                            printf("TestZipMember113: mask %d layout %d old %llx new %llx -> length %zu\n", mask, layout, oldOffs,
                                   newOffs, l);
                    }
                }
            }
        }
    }
    CHECK(combos == 16 * 4 * 2 * 6);
    CHECK(bad == 0);

    // --- composition: an archive written as the ZIP plug-in writes it in temporary-copy mode - the
    // kept members, the added file, then a skipped file's member copied back with its span and its
    // relocated record - is read back member by member (local header at each offset, same bytes)
    {
        struct M
        {
            std::string Name, Data;
            bool Desc;
        };
        std::vector<M> members = {{"keep1.txt", "first member data", false},
                                  {"repl.txt", "the member a skipped file was to replace", true},
                                  {"keep2.txt", "third", false}};
        Bytes113 orig;
        std::vector<Bytes113> recs;
        std::vector<unsigned long long> offs;
        for (size_t k = 0; k < members.size(); k++)
        {
            const M& m = members[k];
            offs.push_back(orig.size());
            Put32_113(orig, 0x04034B50UL);
            Put16_113(orig, 20);
            Put16_113(orig, m.Desc ? SALZIP_GPF_DATADESCR : 0);
            Put16_113(orig, 0);
            Put32_113(orig, 0);
            Put32_113(orig, m.Desc ? 0 : 0x11111111UL);
            Put32_113(orig, m.Desc ? 0 : (unsigned long)m.Data.size());
            Put32_113(orig, m.Desc ? 0 : (unsigned long)m.Data.size());
            Put16_113(orig, (unsigned)m.Name.size());
            Put16_113(orig, 4);
            orig.insert(orig.end(), m.Name.begin(), m.Name.end());
            Put16_113(orig, 0xCAFE);
            Put16_113(orig, 0);
            orig.insert(orig.end(), m.Data.begin(), m.Data.end());
            if (m.Desc)
            {
                Put32_113(orig, 0x08074B50UL);
                Put32_113(orig, 0x11111111UL);
                Put32_113(orig, (unsigned long)m.Data.size());
                Put32_113(orig, (unsigned long)m.Data.size());
            }
            CRec113 cr;
            cr.Name = m.Name;
            cr.Size = cr.Comp = m.Data.size();
            cr.Offs = offs.back();
            cr.OffsIn64 = k == 2; // the third with its offset in a zip64 block
            recs.push_back(MakeRec113(cr));
        }
        // the new archive: keep1, keep2 (moved down), an added file, then repl.txt put back
        Bytes113 out;
        std::vector<Bytes113> outRecs;
        auto copyMember = [&](size_t k) {
            const unsigned char* lh = orig.data() + offs[k];
            unsigned long long span = SalZipMemberSpan(Get16_113(lh + 26), Get16_113(lh + 28), members[k].Data.size(),
                                                       Get16_113(lh + 6), members[k].Data.size(), offs[k]);
            unsigned long long at = out.size();
            out.insert(out.end(), orig.begin() + (size_t)offs[k], orig.begin() + (size_t)(offs[k] + span));
            Bytes113 moved(recs[k].size() + SALZIP_RELOCATE_GROWTH);
            size_t l = SalZipRelocateCentralRecord(recs[k].data(), recs[k].size(), at, moved.data(), moved.size());
            moved.resize(l);
            outRecs.push_back(moved);
            return l != 0;
        };
        bool ok = copyMember(0) && copyMember(2);
        Put32_113(out, 0x04034B50UL); // the added file (its record is not part of this check)
        out.resize(out.size() + 26 + 5, 0);
        ok = ok && copyMember(1);
        CHECK(ok);
        // the span of a member with a descriptor ends exactly where the next one starts
        CHECK(offs[1] + SalZipMemberSpan((unsigned)members[1].Name.size(), 4, members[1].Data.size(), SALZIP_GPF_DATADESCR,
                                         members[1].Data.size(), offs[1]) == offs[2]);
        int found = 0;
        for (size_t k = 0; k < outRecs.size(); k++)
        {
            unsigned long long s, c, o;
            unsigned long d;
            if (!ParseRec113(outRecs[k].data(), outRecs[k].size(), &s, &c, &o, &d) || o + 30 > out.size())
                continue;
            const unsigned char* lh = out.data() + o;
            size_t nl = Get16_113(outRecs[k].data() + 28);
            std::string recName((const char*)outRecs[k].data() + 46, nl);
            if (Get32_113(lh) != 0x04034B50UL || Get16_113(lh + 26) != nl || memcmp(lh + 30, recName.data(), nl) != 0)
                continue;
            for (const M& m : members)
                if (m.Name == recName && memcmp(lh + 30 + nl + Get16_113(lh + 28), m.Data.data(), m.Data.size()) == 0)
                    found++;
        }
        CHECK(found == 3);
    }
}

// feature 114: the Undelete plug-in's FAT short-name rules (salfatname.h) and its volume paths
// in UTF-8 (salvolpaths.h)
static BYTE RefFatChecksum114(const BYTE* n)
{
    // the FAT specification's loop, written independently: rotate right by one, add the byte
    unsigned sum = 0;
    for (int i = 0; i < 11; i++)
        sum = (((sum >> 1) | ((sum & 1) << 7)) + n[i]) & 0xFF;
    return (BYTE)sum;
}

static std::wstring Sfn114(const char* raw11, BYTE ntRes, BOOL applyCase, UINT cp, BOOL* lost, int* ret = NULL)
{
    WCHAR out[32];
    int r = SalFatShortNameToW((const BYTE*)raw11, ntRes, applyCase, cp, out, 32, lost);
    if (ret != NULL)
        *ret = r;
    return r > 0 ? std::wstring(out, r) : std::wstring();
}

static void TestUndeleteNames114()
{
    // --- checksum: against the independent loop, over every first byte of two names
    {
        BYTE n[11];
        memcpy(n, "README  TXT", 11);
        int mismatch = 0;
        for (int b = 0; b < 256; b++)
        {
            n[0] = (BYTE)b;
            if (SalFatShortNameChecksum(n) != RefFatChecksum114(n))
                mismatch++;
        }
        memcpy(n, "_~1     TXT", 11);
        for (int b = 0; b < 256; b++)
        {
            n[0] = (BYTE)b;
            if (SalFatShortNameChecksum(n) != RefFatChecksum114(n))
                mismatch++;
        }
        CHECK(mismatch == 0);
        // the first byte decides the checksum one-to-one (why the candidates are few and ordered)
        std::set<int> sums;
        for (int b = 0; b < 256; b++)
        {
            n[0] = (BYTE)b;
            sums.insert(SalFatShortNameChecksum(n));
        }
        CHECK(sums.size() == 256);
    }

    // --- short names: the deletion marker, the 0x05 escape, OEM bytes, the case bits
    BOOL lost = TRUE;
    CHECK(Sfn114("FOO     TXT", 0, TRUE, 437, &lost) == L"FOO.TXT" && !lost);
    CHECK(Sfn114("\xE5OO     TXT", 0, TRUE, 437, &lost) == L"$OO.TXT" && lost);
    CHECK(Sfn114("\xE5OO     TXT", 0, TRUE, 852, &lost) == L"$OO.TXT" && lost);
    CHECK(Sfn114("\xE5       TXT", 0, TRUE, 852, &lost) == L"$.TXT" && lost);   // a one-character base
    CHECK(Sfn114("\x05" "ABC    TXT", 0, TRUE, 852, &lost) == L"\x0148" L"ABC.TXT" && !lost); // 0xE5 in CP852 = n-caron
    CHECK(Sfn114("\x05" "ABC    TXT", 0, TRUE, 437, &lost) == L"\x03C3" L"ABC.TXT" && !lost); // 0xE5 in CP437 = sigma
    CHECK(Sfn114("\xAC" "L\xB5" "NEK  TXT", 0, TRUE, 852, &lost) == L"\x010C" L"L\x00C1" L"NEK.TXT" && !lost); // C-caron L A-acute NEK
    CHECK(Sfn114("\xE5" "L\xB5" "NEK  TXT", 0, TRUE, 852, &lost) == L"$L\x00C1" L"NEK.TXT" && lost);
    CHECK(Sfn114("README  TXT", 0x08, TRUE, 437, &lost) == L"readme.TXT");
    CHECK(Sfn114("README  TXT", 0x10, TRUE, 437, &lost) == L"README.txt");
    CHECK(Sfn114("README  TXT", 0x18, TRUE, 437, &lost) == L"readme.txt");
    CHECK(Sfn114("README  TXT", 0x18, FALSE, 437, &lost) == L"README.TXT"); // shown next to a long name
    CHECK(Sfn114("\xAC" "AJ     TXT", 0x18, TRUE, 852, &lost) == L"\x010C" L"aj.txt");     // NT lower case: A-Z only (fastfat)
    CHECK(Sfn114("\xAC" "AJ     \x8F" "XT", 0x18, TRUE, 852, &lost) == L"\x010C" L"aj.\x0106" L"xt"); // also in the extension
    CHECK(Sfn114("FOO        ", 0, TRUE, 437, &lost) == L"FOO");                          // no extension, no dot
    CHECK(Sfn114("A B     TXT", 0, TRUE, 437, &lost) == L"A B.TXT");                      // only trailing spaces are padding
    CHECK(Sfn114("FOO     T  ", 0, TRUE, 437, &lost) == L"FOO.T");
    int r = -1;
    CHECK(Sfn114("        TXT", 0, TRUE, 437, &lost, &r).empty() && r == 0 && !lost);      // no base: not a name
    CHECK(Sfn114("           ", 0, TRUE, 437, &lost, &r).empty() && r == 0);
    {
        WCHAR tiny[5];
        CHECK(SalFatShortNameToW((const BYTE*)"FOO     TXT", 0, TRUE, 437, tiny, 5, &lost) == 0 && tiny[0] == 0);
        CHECK(SalFatShortNameToW((const BYTE*)"FOO     TXT", 0, TRUE, 437, tiny, 0, NULL) == 0);
    }
    // every first byte with every OEM code page at hand: 0xE5 -> '$' + lost, 0x05 -> the code
    // page's character for 0xE5, anything else -> the code page's character, never '$' + lost
    {
        UINT cps[] = {437, 850, 852, 866, 932, 936, 949, 950};
        int bad = 0, tested = 0;
        for (UINT cp : cps)
        {
            if (!IsValidCodePage(cp))
                continue;
            tested++;
            for (int b = 1; b < 256; b++)
            {
                if (b == ' ')
                    continue;
                char raw[12];
                memcpy(raw, "XAB     TXT", 12);
                raw[0] = (char)b;
                BOOL l2 = FALSE;
                std::wstring got = Sfn114(raw, 0, TRUE, cp, &l2);
                if (b == 0xE5)
                {
                    if (!(l2 && got == L"$AB.TXT"))
                        bad++;
                    continue;
                }
                char want[3] = {(char)(b == 0x05 ? 0xE5 : b), 'A', 'B'};
                WCHAR ww[8];
                int wn = MultiByteToWideChar(cp, 0, want, 3, ww, 8);
                std::wstring expect = std::wstring(ww, wn > 0 ? wn : 0) + L".TXT";
                if (l2 || got != expect)
                    bad++;
            }
        }
        printf("TestUndeleteNames114: first byte x OEM code page, %d code pages, %d mismatches\n", tested, bad);
        CHECK(tested >= 3 && bad == 0);
    }

    // --- the lost first byte: the byte Windows writes comes first
    BYTE c[3];
    int n = SalFatLostFirstByteCandidates(L"\x010Clanek.txt\0\xFFFF", 13, 852, 1250, c, 3); // C-caron
    CHECK(n >= 2 && c[0] == 0xAC);
    // a character Windows cannot put into a short name is DROPPED, not replaced (review SF1). The
    // examples measured with dir /x (NTFS, whose generator drops every character outside ASCII by
    // default - modelled here with CP437, which has neither C-caron nor a-acute):
    //   "C-caron-lanek dlouhy-acute.txt" -> LNEKDL~1.TXT, "C-caron-X.txt" -> X76F3~1.TXT,
    //   "C-caron.txt" -> 80E2~1.TXT, "U+597D.txt" -> 191D~1.TXT (hash forms)
    n = SalFatLostFirstByteCandidates(L"\x010Clanek.txt\0\xFFFF", 13, 437, 1250, c, 3); // C-caron dropped
    CHECK(n >= 1 && c[0] == 'L');
    n = SalFatLostFirstByteCandidates(L"\x010Cl\x00E1nek dlouh\x00FD", 13, 437, 1250, c, 3); // 13 units, no end seen
    CHECK(n >= 1 && c[0] == 'L');
    n = SalFatLostFirstByteCandidates(L"\x010CX.txt\0\xFFFF\xFFFF\xFFFF\xFFFF\xFFFF\xFFFF", 13, 437, 1250, c, 3);
    CHECK(n >= 1 && c[0] == 'X');
    // hash forms: nothing of the base name is kept - no Windows candidate; the old guess and
    // Linux's '_' remain (the first byte of a hash form is a hex digit: no link, damaged name)
    n = SalFatLostFirstByteCandidates(L"\x010C.txt\0\xFFFF\xFFFF\xFFFF\xFFFF\xFFFF\xFFFF\xFFFF", 13, 437, 1250, c, 3);
    CHECK(n == 2 && c[0] == 0xC8 && c[1] == '_'); // the old ANSI guess (CP1250 C-caron), then '_'
    n = SalFatLostFirstByteCandidates(L"\x597D.txt\0\xFFFF\xFFFF\xFFFF\xFFFF\xFFFF\xFFFF", 13, 852, 1250, c, 3); // U+597D: not in CP852
    CHECK(n == 2 && c[0] == '?' && c[1] == '_');
    {
        BYTE hashForm[11];
        memcpy(hashForm, "191D~1  TXT", 11);
        BYTE sum = SalFatShortNameChecksum(hashForm);
        BOOL linked = FALSE;
        for (int i = 0; i < n; i++)
        {
            hashForm[0] = c[i];
            if (SalFatShortNameChecksum(hashForm) == sum)
                linked = TRUE;
        }
        CHECK(!linked); // shown as a damaged short name, as before
    }
    // a character in the OEM code page is kept on FAT (fastfat allows extended characters)
    n = SalFatLostFirstByteCandidates(L"\x010Cl\x00E1nek dlouh\x00FD", 13, 852, 1250, c, 3);
    CHECK(n >= 1 && c[0] == 0xAC);
    n = SalFatLostFirstByteCandidates(L".gitignore\0\xFFFF\xFFFF", 13, 437, 1252, c, 3);
    CHECK(n >= 1 && c[0] == 'G'); // a leading dot does not start the extension
    n = SalFatLostFirstByteCandidates(L"\x597D.a.txt\0\xFFFF\xFFFF\xFFFF", 13, 852, 1250, c, 3);
    CHECK(n >= 1 && c[0] == 'A'); // a dot before the last one: the base is "U+597D.a", 'A' kept
    if (IsValidCodePage(936))
    {
        n = SalFatLostFirstByteCandidates(L"\x597D.txt\0\xFFFF\xFFFF\xFFFF\xFFFF\xFFFF\xFFFF", 13, 936, 936, c, 3);
        CHECK(n >= 1 && c[0] == 0xBA); // GBK BA C3
    }
    if (IsValidCodePage(932))
    {
        n = SalFatLostFirstByteCandidates(L"\x4E55.txt\0\xFFFF\xFFFF\xFFFF\xFFFF\xFFFF\xFFFF", 13, 932, 932, c, 3);
        CHECK(n >= 1 && c[0] == 0x05); // Shift-JIS E5 68: stored as the escape
    }
    n = SalFatLostFirstByteCandidates(L"readme.txt\0\xFFFF\xFFFF", 13, 437, 1252, c, 3);
    CHECK(n >= 1 && c[0] == 'R');
    n = SalFatLostFirstByteCandidates(L"..hidden\0\xFFFF\xFFFF\xFFFF\xFFFF", 13, 437, 1252, c, 3);
    CHECK(n >= 1 && c[0] == 'H'); // leading dots are dropped from a short name
    n = SalFatLostFirstByteCandidates(L"  x.txt\0\xFFFF\xFFFF\xFFFF\xFFFF\xFFFF", 13, 437, 1252, c, 3);
    CHECK(n >= 1 && c[0] == 'X'); // ... and spaces
    n = SalFatLostFirstByteCandidates(L"+plus.txt\0\xFFFF\xFFFF\xFFFF", 13, 437, 1252, c, 3);
    CHECK(n >= 1 && c[0] == '_');
    n = SalFatLostFirstByteCandidates(L"\xD83D\xDCC1" L"x.txt\0\xFFFF\xFFFF\xFFFF\xFFFF", 13, 437, 1252, c, 3);
    CHECK(n >= 1 && c[0] == 'X'); // a character outside the BMP is dropped
    n = SalFatLostFirstByteCandidates(L"\0\xFFFF\xFFFF\xFFFF\xFFFF\xFFFF\xFFFF\xFFFF\xFFFF\xFFFF\xFFFF\xFFFF\xFFFF", 13, 437, 1252, c, 3);
    CHECK(n == 0);
    n = SalFatLostFirstByteCandidates(L"readme.txt\0\xFFFF\xFFFF", 13, 437, 1252, c, 1);
    CHECK(n == 1 && c[0] == 'R');
    {
        // no duplicates, and the whole chain: a deleted entry's long name is found again
        n = SalFatLostFirstByteCandidates(L"\x010Clanek.txt\0\xFFFF", 13, 852, 1250, c, 3);
        BOOL dup = FALSE;
        for (int i = 0; i < n; i++)
            for (int j = i + 1; j < n; j++)
                if (c[i] == c[j])
                    dup = TRUE;
        CHECK(!dup);
        BYTE stored[11];
        memcpy(stored, "\xAC" "LANEK  TXT", 11);
        BYTE sum = SalFatShortNameChecksum(stored); // what the long-name entries carry
        stored[0] = 0xE5;                            // deleted
        BOOL found = FALSE;
        for (int i = 0; i < n && !found; i++)
        {
            stored[0] = c[i];
            found = SalFatShortNameChecksum(stored) == sum;
        }
        CHECK(found);
    }

    // --- volume paths: UTF-16 multi-string -> UTF-8, a path that does not fit is left out
    {
        const WCHAR multi[] = L"C:\\mnt\\voil\x00E0\\\0D:\\\0\0";
        char out[64];
        memset(out, 'x', sizeof(out));
        int k = SalVolumePathsWToU8(multi, out, sizeof(out));
        CHECK(k == 2 && strcmp(out, "C:\\mnt\\voil\xC3\xA0\\") == 0 && strcmp(out + 15, "D:\\") == 0 && out[19] == 0);
        memset(out, 'x', sizeof(out));
        k = SalVolumePathsWToU8(multi, out, 10); // the first does not fit: left out, never cut
        CHECK(k == 1 && strcmp(out, "D:\\") == 0 && out[4] == 0);
        k = SalVolumePathsWToU8(multi, out, 4); // "D:\" + terminator needs 4, + the final one 5
        CHECK(k == 0 && out[0] == 0);
        const WCHAR lone[] = L"C:\\a\xD800\\\0E:\\\0\0";
        k = SalVolumePathsWToU8(lone, out, sizeof(out));
        CHECK(k == 1 && strcmp(out, "E:\\") == 0);
        k = SalVolumePathsWToU8(L"\0\0", out, sizeof(out));
        CHECK(k == 0 && out[0] == 0 && out[1] == 0);
        k = SalVolumePathsWToU8(NULL, out, sizeof(out));
        CHECK(k == 0 && out[0] == 0);
        CHECK(SalVolumePathsWToU8(multi, out, 1) == 0);
        CHECK(SalVolumePathWToU8(L"C:\\mnt\\voil\x00E0\\", out, sizeof(out)) && strcmp(out, "C:\\mnt\\voil\xC3\xA0\\") == 0);
        CHECK(!SalVolumePathWToU8(L"C:\\mnt\\voil\x00E0\\", out, 14) && out[0] == 0); // 15 bytes needed
        CHECK(SalVolumePathWToU8(L"C:\\mnt\\voil\x00E0\\", out, 15) && strlen(out) == 14);
        CHECK(!SalVolumePathWToU8(L"C:\\a\xD800", out, sizeof(out)) && out[0] == 0);
    }
}

// feature 115: the Undelete plug-in's name order (salnameorder.h) is the core's
// SalNameCompareOrdinalCI / SalNameEqualOrdinalCI exactly - for valid WTF-8, legacy bytes,
// mixed, long (heap) names - and a sort by it keeps every group of equal names together
static void TestUndeleteLeftovers115()
{
    std::vector<std::string> names = {
        "", "a", "A", "b", "a.txt", "A.TXT", "a (1).txt", "_", "~", "z",
        "\xC4\x8C.txt",               // C-caron
        "\xC4\x8D.txt",               // c-caron
        "\xC4\x8D.TXT",
        "\xC4\x8C",
        "\xC8\xBA", "\xE2\xB1\xA5",   // U+023A / U+2C65: one case pair, different UTF-8 lengths
        "x\xC8\xBA", "x\xE2\xB1\xA5",
        "\xE2\x84\xAA", "K", "k",     // Kelvin sign is not K
        "\xC4\xB1", "i", "I",         // dotless i is not i
        "\xC5\xBF", "s", "S",         // long s is not s
        "\xE5\xA5\xBD.txt",           // U+597D
        "\xE5\xA5\xBD.TXT",
        "\xF0\x9F\x93\x81",           // a supplementary character
        "\xED\xA0\x80x.txt",          // a lone surrogate (WTF-8)
        "\xED\xA0\x80X.TXT",
        "\xC8.txt", "\xE8.txt", "\xC8.TXT", // legacy code-page bytes (not UTF-8)
        "\xC4", "\x80", "\xFF\xFE",
        "a\xC8", "A\xE8",
    };
    // long names: over the 519-byte stack buffer (the heap path), equal by case only
    std::string longA, longB;
    for (int i = 0; i < 120; i++)
    {
        longA += "\xC4\x8C\xE5\xA5\xBD";
        longB += "\xC4\x8D\xE5\xA5\xBD";
    }
    names.push_back(longA);
    names.push_back(longB);
    names.push_back(longB + "x");
    int mismatch = 0, eqMismatch = 0;
    for (size_t i = 0; i < names.size(); i++)
        for (size_t j = 0; j < names.size(); j++)
        {
            const char* a = names[i].c_str();
            const char* b = names[j].c_str();
            if (Sign092(SalNameOrderCompareCI(a, -1, b, -1)) != Sign092(SalNameCompareOrdinalCI(a, -1, b, -1)))
                mismatch++;
            if (Sign092(SalNameOrderCompareCI(a, (int)names[i].size(), b, (int)names[j].size())) !=
                Sign092(SalNameCompareOrdinalCI(a, (int)names[i].size(), b, (int)names[j].size())))
                mismatch++;
            if ((SalNameOrderEqualCI(a, -1, b, -1) != FALSE) != (SalNameEqualOrdinalCI(a, -1, b, -1) != FALSE))
                eqMismatch++;
            if ((SalNameOrderEqualCI(a, -1, b, -1) != FALSE) != (SalNameOrderCompareCI(a, -1, b, -1) == 0))
                eqMismatch++;
        }
    CHECK(mismatch == 0);
    CHECK(eqMismatch == 0);
    if (mismatch != 0 || eqMismatch != 0)
        printf("TestUndeleteLeftovers115: corpus %d order / %d equality mismatches\n", mismatch, eqMismatch);

    // the defect's names and the traps, spelled out
    CHECK(SalNameOrderEqualCI("\xC4\x8C.txt", -1, "\xC4\x8D.txt", -1));  // C-caron = c-caron (was two names)
    CHECK(SalNameOrderEqualCI("\xC4\x8C.TXT", -1, "\xC4\x8D.txt", -1));
    CHECK(SalNameOrderEqualCI("\xC8\xBA", -1, "\xE2\xB1\xA5", -1));      // different byte lengths
    CHECK(!SalNameOrderEqualCI("\xE2\x84\xAA", -1, "K", -1));            // Kelvin
    CHECK(!SalNameOrderEqualCI("\xC4\xB1", -1, "I", -1));                // dotless i
    CHECK(SalNameOrderEqualCI("a.TXT", -1, "A.txt", -1));
    CHECK(!SalNameOrderEqualCI("a.txt", -1, "a (1).txt", -1));
    CHECK(SalNameOrderEqualCI("\xED\xA0\x80x.txt", -1, "\xED\xA0\x80X.TXT", -1)); // lone surrogate kept
    CHECK(!SalNameOrderEqualCI("\xC8.txt", -1, "\xC4\x8C.txt", -1));     // legacy never equals UTF-8
    CHECK(SalNameOrderEqualCI(longA.c_str(), -1, longB.c_str(), -1));    // heap path
    CHECK(!SalNameOrderEqualCI(longA.c_str(), -1, (longB + "x").c_str(), -1));
    CHECK(SalNameOrderEqualCI(NULL, -1, "", -1) && SalNameOrderCompareCI(NULL, 0, NULL, 0) == 0);
    CHECK(SalNameOrderCompareCI("a", -1, "\xC4\x8D", -1) < 0); // ASCII sorts below a tail

    // random byte strings (valid and not): the same order as the core
    {
        unsigned int seed = 115;
        auto rnd = [&seed]() { seed = seed * 1103515245u + 12345u; return (seed >> 16) & 0x7FFF; };
        const char* pieces[] = {"a", "A", "b", "\xC4\x8C", "\xC4\x8D", "\xC8\xBA", "\xE2\xB1\xA5", "\xE5\xA5\xBD",
                                "\xED\xA0\x80", "\xF0\x9F\x93\x81", "\xC8", "\xE8", "\x80", ".", " ", "1"};
        int bad = 0;
        for (int n = 0; n < 20000; n++)
        {
            std::string x, y;
            int lx = rnd() % 5, ly = rnd() % 5;
            for (int k = 0; k < lx; k++)
                x += pieces[rnd() % 16];
            for (int k = 0; k < ly; k++)
                y += pieces[rnd() % 16];
            if (rnd() % 3 == 0)
                y = x; // often equal or equal but for case
            if (rnd() % 2 == 0)
                for (char& c : y)
                    if (c >= 'a' && c <= 'z')
                        c = (char)(c - 32);
            if (Sign092(SalNameOrderCompareCI(x.c_str(), -1, y.c_str(), -1)) != Sign092(SalNameCompareOrdinalCI(x.c_str(), -1, y.c_str(), -1)) ||
                (SalNameOrderEqualCI(x.c_str(), -1, y.c_str(), -1) != FALSE) != (SalNameEqualOrdinalCI(x.c_str(), -1, y.c_str(), -1) != FALSE))
                bad++;
        }
        CHECK(bad == 0);
        if (bad != 0)
            printf("TestUndeleteLeftovers115: random %d mismatches\n", bad);
    }

    // a sort by it keeps equal names together (the numbering and the duplicate scan look at
    // neighbours only): every equal pair is in one run of equal names
    {
        std::vector<std::string> v = names;
        for (size_t i = 0; i < names.size(); i += 3)
            v.push_back(names[i]); // some names twice
        std::sort(v.begin(), v.end(), [](const std::string& a, const std::string& b)
                  { return SalNameOrderCompareCI(a.c_str(), -1, b.c_str(), -1) < 0; });
        int split = 0;
        for (size_t i = 0; i < v.size(); i++)
            for (size_t j = i + 2; j < v.size(); j++)
                if (SalNameOrderEqualCI(v[i].c_str(), -1, v[j].c_str(), -1))
                    for (size_t k = i + 1; k < j; k++)
                        if (!SalNameOrderEqualCI(v[i].c_str(), -1, v[k].c_str(), -1))
                            split++;
        CHECK(split == 0);
        // C-caron.txt / c-caron.txt / c-caron.TXT: one run of three
        size_t first = v.size(), count = 0;
        for (size_t i = 0; i < v.size(); i++)
            if (SalNameOrderEqualCI(v[i].c_str(), -1, "\xC4\x8D.txt", -1))
            {
                if (first == v.size())
                    first = i;
                count++;
            }
        CHECK(count >= 3 && first + count <= v.size() &&
              SalNameOrderEqualCI(v[first + count - 1].c_str(), -1, "\xC4\x8C.TXT", -1));
    }
}

// feature 116: the FTP plug-in's secret fields (salftpsecret.h) - a field of
// SAL_FTP_SECRET_MAX_CHARS UTF-16 units always fits SAL_FTP_SECRET_BUF bytes as UTF-8 (WTF-8),
// whatever the units are; one unit more may not (the field's limit is what makes "too long"
// impossible); a field that shows the stored value keeps the stored bytes, which may not be what
// re-reading it gives (a 0.1.8 code-page password)
static void TestFtpSecret116()
{
    CHECK(SAL_FTP_SECRET_BUF == 301);
    CHECK(SalFtpWorstUtf8Bytes(SAL_FTP_SECRET_MAX_CHARS) == SAL_FTP_SECRET_BUF - 1);
    CHECK(SalFtpWorstUtf8Bytes(0) == 0 && SalFtpWorstUtf8Bytes(-5) == 0 && SalFtpWorstUtf8Bytes(1) == 3);

    // (1) the worst cases of 100 units, plugin and core converters agree, round trip
    struct Pattern
    {
        WCHAR Unit;
        int ExpectBytes;
    };
    static const Pattern same[] = {{L'a', 100}, {0x010D, 200}, {0x4E2D, 300}, {0xFFFF, 300}, {0xD800, 300}, {0xDC00, 300}, {0xDBFF, 300}};
    for (int p = 0; p < _countof(same); p++)
    {
        WCHAR w[SAL_FTP_SECRET_MAX_CHARS + 1];
        for (int i = 0; i < SAL_FTP_SECRET_MAX_CHARS; i++)
            w[i] = same[p].Unit;
        w[SAL_FTP_SECRET_MAX_CHARS] = 0;
        char spl[SAL_FTP_SECRET_BUF], core[SAL_FTP_SECRET_BUF];
        int splLen = SplWToU8(w, spl, SAL_FTP_SECRET_BUF);
        int coreLen = SalWToU8(w, -1, core, SAL_FTP_SECRET_BUF);
        CHECK(splLen == same[p].ExpectBytes + 1 && coreLen == splLen && memcmp(spl, core, splLen) == 0);
        WCHAR back[SAL_FTP_SECRET_MAX_CHARS + 1];
        CHECK(SplU8ToW(spl, back, _countof(back)) == SAL_FTP_SECRET_MAX_CHARS + 1 && wcscmp(back, w) == 0);
    }
    {
        // 50 surrogate pairs (emoji): 200 bytes; 99 CJK + one lone surrogate at the end: 300 bytes
        WCHAR w[SAL_FTP_SECRET_MAX_CHARS + 1];
        for (int i = 0; i < SAL_FTP_SECRET_MAX_CHARS; i += 2)
        {
            w[i] = 0xD83D;
            w[i + 1] = 0xDCC1;
        }
        w[SAL_FTP_SECRET_MAX_CHARS] = 0;
        char b[SAL_FTP_SECRET_BUF];
        CHECK(SplWToU8(w, b, SAL_FTP_SECRET_BUF) == 201);
        for (int i = 0; i < SAL_FTP_SECRET_MAX_CHARS - 1; i++)
            w[i] = 0x4E2D;
        w[SAL_FTP_SECRET_MAX_CHARS - 1] = 0xD83D; // a high surrogate without its pair
        CHECK(SplWToU8(w, b, SAL_FTP_SECRET_BUF) == 301 && (BYTE)b[297] == 0xED && (BYTE)b[298] == 0xA0 && (BYTE)b[299] == 0xBD);
    }
    {
        // random texts of 1..100 units over every kind of unit (fixed seed): always fits
        static const WCHAR kinds[] = {L'a', L'%', 0x00E0, 0x010D, 0x0416, 0x4E2D, 0xFF21, 0xFFFF, 0xD800, 0xDBFF, 0xDC00, 0xDFFF};
        unsigned seed = 116;
        int worst = 0, fits = 0, cases = 20000;
        for (int c = 0; c < cases; c++)
        {
            WCHAR w[SAL_FTP_SECRET_MAX_CHARS + 1];
            seed = seed * 1103515245u + 12345u;
            int n = 1 + (int)((seed >> 16) % SAL_FTP_SECRET_MAX_CHARS);
            for (int i = 0; i < n; i++)
            {
                seed = seed * 1103515245u + 12345u;
                int k = (int)((seed >> 16) % (_countof(kinds) + 1));
                if (k == _countof(kinds) && i + 1 < n) // a valid pair
                {
                    w[i++] = 0xD83D;
                    w[i] = 0xDE00;
                }
                else
                    w[i] = kinds[k % _countof(kinds)];
            }
            w[n] = 0;
            char b[SAL_FTP_SECRET_BUF];
            int len = SplWToU8(w, b, SAL_FTP_SECRET_BUF);
            if (len > 0 && len - 1 <= SalFtpWorstUtf8Bytes(n))
                fits++;
            if (len - 1 > worst)
                worst = len - 1;
        }
        CHECK(fits == cases && worst <= SAL_FTP_SECRET_BUF - 1);
    }

    // (2) negative controls: one unit more can overflow; the old 101-byte buffer refused 51+ c-caron
    {
        WCHAR w[SAL_FTP_SECRET_MAX_CHARS + 2];
        for (int i = 0; i < SAL_FTP_SECRET_MAX_CHARS + 1; i++)
            w[i] = 0x4E2D;
        w[SAL_FTP_SECRET_MAX_CHARS + 1] = 0;
        char b[SAL_FTP_SECRET_BUF];
        memset(b, 'x', sizeof(b));
        CHECK(SplWToU8(w, b, SAL_FTP_SECRET_BUF) == 0 && b[0] == 0); // 303 bytes do not fit
        int left = 0;
        for (int i = 0; i < SAL_FTP_SECRET_BUF; i++)
            if (b[i] != 0)
                left++;
        CHECK(left == 0); // nothing of the text stays in the buffer (a password, too)
        WCHAR c51[52], c60[61];
        for (int i = 0; i < 51; i++)
            c51[i] = 0x010D;
        c51[51] = 0;
        for (int i = 0; i < 60; i++)
            c60[i] = 0x010D;
        c60[60] = 0;
        char old[101];
        CHECK(SplWToU8(c51, old, sizeof(old)) == 0);        // 102 bytes: refused by 104, cp bytes by 0.1.8
        CHECK(SplWToU8(c60, b, SAL_FTP_SECRET_BUF) == 121); // fits now
    }

    // (3) why the stored bytes must be kept: a password 0.1.8 saved in code-page form (60 x c-caron
    // = 60 bytes 0xE8 in CP 1250) is shown correctly, but the field reads back as other bytes
    char legacy[61];
    memset(legacy, 0xE8, 60);
    legacy[60] = 0;
    WCHAR shown[61];
    CHECK(SplU8ToW(legacy, shown, _countof(shown)) == 0); // not UTF-8: the field shows it through the code page
    CHECK(MultiByteToWideChar(1250, 0, legacy, -1, shown, _countof(shown)) == 61 && shown[0] == 0x010D && shown[59] == 0x010D);
    {
        char reread[SAL_FTP_SECRET_BUF];
        CHECK(SplWToU8(shown, reread, sizeof(reread)) == 121 && memcmp(reread, legacy, 60) != 0);
    }

    // (4) the rule: the field's text is exactly what the stored value shows as -> keep the stored bytes
    CHECK(SalFtpFieldShowsStored(legacy, shown, 1250));                     // the 0.1.8 form, untouched
    CHECK(!SalFtpFieldShowsStored(legacy, shown, 1252));                    // another code page shows other letters
    CHECK(!SalFtpFieldShowsStored(legacy, L"\x010D\x010D", 1250));          // the user typed something else
    CHECK(SalFtpFieldShowsStored("heslo-\xC5\x99", L"heslo-\x0159", 1250)); // UTF-8 stored: keeping = reading
    CHECK(!SalFtpFieldShowsStored("heslo-\xC5\x99", L"heslo-\x0159x", 1250));
    CHECK(!SalFtpFieldShowsStored("heslo-\xC5\x99", L"heslo-\x00C5\x0099", 1250)); // its code-page reading is not what is shown
    CHECK(SalFtpFieldShowsStored("lone\xED\xA0\x80x", L"lone\xD800x", 1250));      // WTF-8: a lone surrogate
    CHECK(SalFtpFieldShowsStored("\xD0\x96\xD0\xB0", L"\x0416\x0430", 1250));
    CHECK(!SalFtpFieldShowsStored("", L"", 1250)); // empty: always read (the same empty value)
    CHECK(!SalFtpFieldShowsStored("", L"x", 1250));
    CHECK(!SalFtpFieldShowsStored("x", L"", 1250)); // the field was emptied: read (delete the value)
    CHECK(!SalFtpFieldShowsStored(NULL, L"x", 1250) && !SalFtpFieldShowsStored("x", NULL, 1250));
    CHECK(SalFtpFieldShowsStored("abc", L"abc", 1250) && !SalFtpFieldShowsStored("abc", L"ABC", 1250)); // case matters
}

// feature 117: reading a checksum list (src/common/salcsumlist.h) - the encoding decided for
// the whole file, exact conversion (never a look-alike), names that cannot be a file, the GNU
// escape, and the path a name stands for ('.' / '..' resolved, never above the root)
static std::string Csl117(const std::string& bytes, UINT cp, SalCslEncoding* enc = NULL, size_t* bad = NULL)
{
    char* t = SalCslDecode((const unsigned char*)bytes.data(), bytes.size(), cp, enc, bad);
    std::string r = t != NULL ? std::string(t) : std::string("<NULL>");
    free(t);
    return r;
}
static std::string U16_117(const std::wstring& w, bool le)
{
    std::string r;
    for (wchar_t c : w)
    {
        unsigned char lo = (unsigned char)(c & 0xFF), hi = (unsigned char)(c >> 8);
        r += (char)(le ? lo : hi);
        r += (char)(le ? hi : lo);
    }
    return r;
}
static std::string Path117(const char* dir, const char* name, size_t size = 1000, BOOL* ok = NULL)
{
    char out[1000];
    int r = SalCslBuildPath(dir, name, out, size);
    if (ok != NULL)
        *ok = r == SAL_CSL_PATH_OK;
    if (r == SAL_CSL_PATH_FOREIGN)
        return std::string("<FOREIGN:") + out + ">";
    return r == SAL_CSL_PATH_OK ? std::string(out) : std::string("<FALSE:") + out + ">";
}

static void TestChecksumList117()
{
    const std::string h = "0123456789abcdef0123456789abcdef  "; // an MD5 line's checksum + separator
    SalCslEncoding e = SAL_CSL_CODEPAGE;
    size_t bad = 99;

    // ---- rule 1: one encoding for the whole file ----
    CHECK(Csl117(h + "\xC4\x8D.txt\r\n", 1250, &e, &bad) == h + "\xC4\x8D.txt\r\n" && e == SAL_CSL_UTF8 && bad == 0);
    CHECK(Csl117("\xEF\xBB\xBF" + h + "a\n", 1250, &e) == h + "a\n" && e == SAL_CSL_UTF8_BOM);
    CHECK(Csl117(h + "\xE8.txt\n", 1250, &e) == h + "\xC4\x8D.txt\n" && e == SAL_CSL_CODEPAGE); // c-caron
    CHECK(Csl117("", 1250, &e) == "" && e == SAL_CSL_UTF8);
    CHECK(Csl117(h + "plain.txt\n", 1250, &e) == h + "plain.txt\n" && e == SAL_CSL_UTF8);
    // a lone surrogate (WTF-8, the plug-in's own lists can hold one) keeps the file UTF-8
    CHECK(Csl117(h + "\xED\xA0\x80.txt\n", 1250, &e) == h + "\xED\xA0\x80.txt\n" && e == SAL_CSL_UTF8);
    // an overlong sequence is not UTF-8: code page (C0 = R-acute, 80 = euro in CP1250)
    CHECK(Csl117(h + "\xC0\x80\n", 1250, &e) == h + "\xC5\x94\xE2\x82\xAC\n" && e == SAL_CSL_CODEPAGE);
    // one UTF-8 line and one code-page line: the WHOLE file is code page - never mixed per line
    // (C4 = A-umlaut, 8D = T-caron in CP1250)
    CHECK(Csl117(h + "\xC4\x8D\n" + h + "\xE8\n", 1250, &e) == h + "\xC3\x84\xC5\xA4\n" + h + "\xC4\x8D\n" && e == SAL_CSL_CODEPAGE);

    // UTF-16 with a byte order mark: CJK, a surrogate pair (emoji), a lone surrogate (WTF-8)
    const std::wstring w = L"0123456789abcdef0123456789abcdef  \x65E5\x672C\xD83D\xDCC1\xD800x.txt\r\n";
    const std::string wU8 = h + "\xE6\x97\xA5\xE6\x9C\xAC\xF0\x9F\x93\x81\xED\xA0\x80x.txt\r\n";
    CHECK(Csl117("\xFF\xFE" + U16_117(w, true), 1250, &e) == wU8 && e == SAL_CSL_UTF16LE_BOM);
    CHECK(Csl117("\xFE\xFF" + U16_117(w, false), 1250, &e) == wU8 && e == SAL_CSL_UTF16BE_BOM);
    // without the mark (NUL bytes on one parity)
    CHECK(Csl117(U16_117(w, true), 1250, &e) == wU8 && e == SAL_CSL_UTF16LE);
    CHECK(Csl117(U16_117(w, false), 1250, &e) == wU8 && e == SAL_CSL_UTF16BE);
    // a cut-off last unit -> SAL_CSL_BADCHAR; U+0000 inside -> SAL_CSL_BADCHAR (never ends the text)
    CHECK(Csl117("\xFF\xFE" + U16_117(L"ab", true) + "c", 1250, &e, &bad) == "ab\xFF" && bad == 1);
    CHECK(Csl117("\xFF\xFE" + U16_117(std::wstring(L"a\0b", 3), true), 1250, &e, &bad) == "a\xFF" "b" && bad == 1);
    // a marked UTF-8 file with a broken byte: that byte only
    CHECK(Csl117("\xEF\xBB\xBF" + h + "x\xE8y\n" + h + "\xC4\x8D\n", 1250, &e, &bad) == h + "x\xFFy\n" + h + "\xC4\x8D\n" && e == SAL_CSL_UTF8_BOM && bad == 1);
    // a stray NUL byte in an unmarked UTF-8 text
    CHECK(Csl117(h + std::string("a\0" "b\n", 4), 1250, &e, &bad) == h + "a\xFF" "b\n" && e == SAL_CSL_UTF8 && bad == 1);
    // ... but a short file whose NULs sit on one parity is UTF-16 (the threshold is 1 NUL in 16 bytes)
    CHECK(Csl117(std::string("a\0" "b\0", 4), 1250, &e) == "ab" && e == SAL_CSL_UTF16LE);
    // NULs (review S1): trailing ones, a zero-padded tail and NULs at a line's start or end are
    // ignored; inside a line a NUL is SAL_CSL_BADCHAR and the line is not cut
    const std::string l80 = h + "a.txt\n" + h + "\xC4\x8D.txt\n"; // UTF-8, about 80 bytes
    for (size_t pad : {1, 11, 13, 21, 64})
    {
        CHECK(Csl117(l80 + std::string(pad, '\0'), 1250, &e, &bad) == l80 && e == SAL_CSL_UTF8 && bad == 0);
        CHECK(Csl117(h + "a.txt" + std::string(pad, '\0'), 1250, &e, &bad) == h + "a.txt" && e == SAL_CSL_UTF8 && bad == 0);
    }
    CHECK(Csl117(h + "\xE8.txt\n" + std::string(13, '\0'), 1250, &e, &bad) == h + "\xC4\x8D.txt\n" && e == SAL_CSL_CODEPAGE && bad == 0);
    CHECK(Csl117(std::string("\0\0", 2) + h + std::string("a\0\r\n", 4) + h +std::string("b\0\0\n\0", 5), 1250, &e, &bad) == h + "a\r\n" + h + "b\n" && bad == 0);
    CHECK(Csl117(h + std::string("voil\0" "a.txt\n", 11), 1250, &e, &bad) == h + "voil\xFF" "a.txt\n" && bad == 1);
    CHECK(Csl117(h + "\xE8" + std::string("\0", 1) + "x\n", 1250, &e, &bad) == h + "\xC4\x8D\xFFx\n" && e == SAL_CSL_CODEPAGE && bad == 1);
    // UTF-16: NUL units at a line end / after the text are ignored; a padding byte too
    CHECK(Csl117("\xFF\xFE" + U16_117(std::wstring(L"ab\0\n\0\0", 6), true) + std::string("\0", 1), 1250, &e, &bad) == "ab\n" && bad == 0);
    CHECK(Csl117(U16_117(L"0123456789abcdef0123456789abcdef  a.txt\r\n", true) + std::string(7, '\0'), 1250, &e, &bad) == h + "a.txt\r\n" && e == SAL_CSL_UTF16LE && bad == 0);
    // UTF-16 without a mark needs one parity to dominate: NULs on both parities are not UTF-16
    CHECK(Csl117(std::string("a\0b\0c\0d\0e\0f\0g\0h\0i\0\0j", 20), 1250, &e) != "" && e == SAL_CSL_UTF16LE);
    CHECK((Csl117(std::string("a\0\0b\0\0c\0\0d", 10), 1250, &e), e) == SAL_CSL_UTF8);
    // byte order marks at the start of a line are dropped (concatenated lists), elsewhere kept
    CHECK(Csl117("\xEF\xBB\xBF" "a\r\n\xEF\xBB\xBF" "b\n", 1250) == "a\r\nb\n");
    CHECK(Csl117("a\xEF\xBB\xBF" "b\n", 1250) == "a\xEF\xBB\xBF" "b\n");
    CHECK(Csl117("\xFF\xFE" + U16_117(L"a\n\xFEFF" L"b\xFEFF", true), 1250) == "a\nb\xEF\xBB\xBF");

    // ---- rule 2: exact conversion ----
    CHECK(Csl117(h + "voil\xE0.txt\n", 1252) == h + "voil\xC3\xA0.txt\n");     // a-grave, not "voila"
    CHECK(Csl117(h + "voil\xE0.txt\n", 1250) == h + "voil\xC5\x95.txt\n");     // CP1250: E0 = r-acute
    CHECK(Csl117(h + "\xC6\xF3\xEA.txt\n", 1251) == h + "\xD0\x96\xD1\x83\xD0\xBA.txt\n"); // Cyrillic
    CHECK(Csl117(h + "\x9F.txt\n", 852) == h + "\xC4\x8D.txt\n");              // OEM 852 c-caron when asked for 852
    // a double-byte code page: a valid pair converts, a broken one is one SAL_CSL_BADCHAR and the
    // rest of the file (its line ends, the next line) stays
    CHECK(Csl117(h + "\x82\xA0\x82\n" + h + "b\n", 932, &e, &bad) == h + "\xE3\x81\x82\xFF\n" + h + "b\n" && e == SAL_CSL_CODEPAGE && bad == 1);
    // no byte >= 0x80 of any code page ever becomes ASCII (a look-alike) - it is SAL_CSL_BADCHAR or
    // exactly the character Windows defines for it
    const UINT cps[] = {1250, 1251, 1252, 1253, 1254, 1255, 1256, 1257, 1258, 874, 437, 850, 852, 866, 932, 936, 949, 950};
    for (UINT cp : cps)
    {
        bool good = true;
        for (int b = 0x80; b <= 0xFF; b++)
        {
            std::string r = Csl117(std::string(1, (char)b), cp);
            WCHAR wc[4];
            char c1 = (char)b;
            int n = MultiByteToWideChar(cp, MB_ERR_INVALID_CHARS, &c1, 1, wc, 4);
            if (r.empty() || (unsigned char)r[0] < 0x80)
                good = false;
            else if (n == 1)
            {
                char u8[8];
                int m = WideCharToMultiByte(CP_UTF8, 0, wc, 1, u8, 8, NULL, NULL);
                if (r != std::string(u8, m))
                    good = false;
            }
            else if (r != "\xFF")
                good = false;
        }
        CHECK(good);
    }

    // ---- rule 3: names that cannot name a file ----
    CHECK(SalCslNameUsable("a b.txt"));
    CHECK(SalCslNameUsable("\xC4\x8D.txt"));
    CHECK(SalCslNameUsable("sub\\x.txt"));
    CHECK(SalCslNameUsable("\xED\xA0\x80.txt")); // a lone surrogate is a legal NTFS name
    CHECK(SalCslNameUsable("C:\\x\\y.txt"));
    CHECK(!SalCslNameUsable("???.txt")); // what a code-page tool writes for Cyrillic / CJK
    CHECK(!SalCslNameUsable("voil?.txt"));
    CHECK(!SalCslNameUsable("*.txt"));
    CHECK(!SalCslNameUsable("<.txt"));
    CHECK(!SalCslNameUsable("a>b"));
    CHECK(!SalCslNameUsable("a\"b"));
    CHECK(!SalCslNameUsable("a|b"));
    CHECK(!SalCslNameUsable("a\nb"));
    CHECK(!SalCslNameUsable("a\x1F" "b"));
    CHECK(!SalCslNameUsable("voil\xFF.txt"));
    CHECK(!SalCslNameUsable(""));
    CHECK(!SalCslNameUsable(NULL));
    // ':' only right after a drive letter of an absolute name (review N1: streams, other drives)
    CHECK(SalCslNameUsable("C:\\x.txt"));
    CHECK(SalCslNameUsable("c:/x.txt"));
    CHECK(!SalCslNameUsable("x.txt:secret"));
    CHECK(!SalCslNameUsable("C:x.txt"));
    CHECK(!SalCslNameUsable("C:"));
    CHECK(!SalCslNameUsable("1:\\x"));
    CHECK(!SalCslNameUsable("C:\\x:y"));
    CHECK(!SalCslNameUsable("\\\\?\\C:\\x")); // device / extended spellings hold '?'

    // ---- the GNU coreutils escape ----
    char esc1[] = "sub\\\\x.txt"; // written by sha256sum for "sub\x.txt"
    SalCslUnescapeName(esc1);
    CHECK(strcmp(esc1, "sub\\x.txt") == 0);
    char esc2[] = "a\\nb\\rc";
    SalCslUnescapeName(esc2);
    CHECK(strcmp(esc2, "a\nb\rc") == 0);
    // an unknown escape and a lone backslash at the end make the name unusable (as coreutils)
    char esc3[] = "a\\qb\\";
    SalCslUnescapeName(esc3);
    CHECK(strcmp(esc3, "a\xFF" "qb\xFF") == 0 && !SalCslNameUsable(esc3));

    // ---- the path a name stands for ----
    const char* d = "C:\\l\\d";
    CHECK(Path117(d, "x.txt") == "C:\\l\\d\\x.txt");
    CHECK(Path117(d, "./x.txt") == "C:\\l\\d\\x.txt");
    CHECK(Path117(d, ".\\.\\x.txt") == "C:\\l\\d\\x.txt");
    CHECK(Path117(d, "sub/../x.txt") == "C:\\l\\d\\x.txt");
    CHECK(Path117(d, "sub/y/x.txt") == "C:\\l\\d\\sub\\y\\x.txt");
    CHECK(Path117(d, "a//b") == "C:\\l\\d\\a\\b");
    CHECK(Path117(d, "../x") == "C:\\l\\x");
    CHECK(Path117(d, "../../../../x") == "C:\\x"); // never above the drive
    CHECK(Path117(d, "\\x") == "C:\\l\\d\\x");     // one leading separator: relative, as always
    CHECK(Path117(d, "/x") == "C:\\l\\d\\x");
    // absolute names: only on the list's own drive / share (review B1: a UNC look-up connects to
    // the server named and sends the user's credentials)
    CHECK(Path117(d, "c:/l/x") == "c:\\l\\x");
    CHECK(Path117(d, "C:\\e\\..\\f") == "C:\\f");
    CHECK(Path117(d, "D:/e/f") == "<FOREIGN:>");
    CHECK(Path117(d, "d:\\e\\..\\f") == "<FOREIGN:>");
    CHECK(Path117(d, "\\\\srv\\sh\\..\\..\\x") == "<FOREIGN:>");
    CHECK(Path117(d, "//host/share/x") == "<FOREIGN:>");
    CHECK(Path117(d, "/\\host\\share\\x") == "<FOREIGN:>");
    CHECK(Path117(d, "\\/host/share/x") == "<FOREIGN:>");
    CHECK(Path117(d, "\\\\localhost\\C$\\Windows\\win.ini") == "<FOREIGN:>");
    CHECK(Path117(d, "\\\\127.0.0.1@80\\x\\y") == "<FOREIGN:>");
    CHECK(Path117(d, "\\\\?\\UNC\\srv\\sh\\x") == "<FOREIGN:>");
    CHECK(Path117(d, "\\\\?\\C:\\l\\d\\x") == "<FOREIGN:>");
    CHECK(Path117(d, "\\\\.\\pipe\\x") == "<FOREIGN:>");
    CHECK(Path117(d, "\\\\.\\C:\\x") == "<FOREIGN:>");
    CHECK(Path117(d, "\\\\\\srv\\sh\\x") == "<FOREIGN:>");
    CHECK(Path117(d, "\\\\") == "<FOREIGN:>");
    const char* u = "\\\\srv\\sh\\d"; // a list on a share
    CHECK(Path117(u, "\\\\SRV\\SH\\x") == "\\\\SRV\\SH\\x");           // the same share (case by the file system's rule)
    CHECK(Path117(u, "//srv/sh/e/../x") == "\\\\srv\\sh\\x");
    CHECK(Path117(u, "\\\\srv\\sh\\..\\..\\x") == "\\\\srv\\sh\\x"); // never above the share
    CHECK(Path117(u, "\\\\srv\\other\\x") == "<FOREIGN:>");
    CHECK(Path117(u, "\\\\srv2\\sh\\x") == "<FOREIGN:>");
    CHECK(Path117(u, "\\\\srv\\sh2\\x") == "<FOREIGN:>");
    CHECK(Path117(u, "C:\\x") == "<FOREIGN:>");
    CHECK(Path117(u, "../../x") == "\\\\srv\\sh\\x");
    CHECK(Path117("\\\\srv\\sh\\d", "../../x") == "\\\\srv\\sh\\x");
    CHECK(Path117("\\\\srv\\sh\\d", "x") == "\\\\srv\\sh\\d\\x");
    CHECK(Path117(d, "x.") == "C:\\l\\d\\x.");     // a trailing dot is another name - kept
    CHECK(Path117(d, "x ") == "C:\\l\\d\\x ");
    CHECK(Path117(d, "...") == "C:\\l\\d\\...");
    CHECK(Path117(d, ".") == "C:\\l\\d");
    CHECK(Path117("C:\\", "x") == "C:\\x");
    CHECK(Path117("C:\\", "..") == "C:\\");
    CHECK(Path117(d, "\xC4\x8D/\xE6\x97\xA5.txt") == "C:\\l\\d\\\xC4\x8D\\\xE6\x97\xA5.txt");
    BOOL ok = TRUE;
    CHECK(Path117(d, "x.txt", strlen("C:\\l\\d\\x.txt") + 1, &ok) == "C:\\l\\d\\x.txt" && ok);
    CHECK(Path117(d, "x.txt", strlen("C:\\l\\d\\x.txt"), &ok) == "<FALSE:>" && !ok);
    CHECK(Path117(d, "x.txt", 2, &ok) == "<FALSE:>" && !ok);
}

// feature 119: what a failed multi-volume pack deletes, and the archive name the last volume is
// renamed to (src/common/salpackvol.h)
static void TestPackLeftovers119()
{
    // --- the list of created volumes ---
    {
        CSalPackCreatedFiles list;
        CHECK(list.GetCount() == 0);
        CHECK(!list.Add(NULL, Id103(1, 2, 0, 1, 1)));
        CHECK(list.GetCount() == 0);
        char name[32];
        for (int i = 1; i <= 20; i++) // grows past its first capacity (8)
        {
            sprintf(name, "C:\\o\\a.z%02d", i);
            CHECK(list.Add(name, Id103(7, 0x100 + i, 0, 10, 10)));
        }
        CHECK(list.GetCount() == 20);
        CHECK(strcmp(list.GetName(0), "C:\\o\\a.z01") == 0 && list.GetId(0).Index64 == 0x101);
        CHECK(strcmp(list.GetName(19), "C:\\o\\a.z20") == 0 && list.GetId(19).Index64 == 0x114);
        sprintf(name, "changed"); // the list keeps its own copy
        CHECK(strcmp(list.GetName(19), "C:\\o\\a.z20") == 0);
        CHECK(list.Add("C:\\o\\\xC4\x8D\xC3\xAD.z01", Id103(7, 0x200, 0, 1, 1))); // UTF-8 kept byte for byte
        CHECK(strcmp(list.GetName(20), "C:\\o\\\xC4\x8D\xC3\xAD.z01") == 0);
        list.Clear();
        CHECK(list.GetCount() == 0);
        CHECK(list.Add("x", Id103(7, 1, 0, 1, 1)) && list.GetCount() == 1); // usable after Clear
        CHECK(!list.GetSizeKnown(0));                                       // no size until the volume is closed
        list.SetLastSize(4096);
        CHECK(list.GetSizeKnown(0) && list.GetSize(0) == 4096);
        CHECK(list.Add("y", Id103(7, 2, 0, 1, 1)) && !list.GetSizeKnown(1)); // only the last one gets it
        CHECK(list.GetSize(0) == 4096);
    }

    // --- the clean-up scope ---
    CHECK(SalPackVolCleanupScope(FALSE, FALSE, FALSE) == salPackVolDeleteNone); // success
    CHECK(SalPackVolCleanupScope(FALSE, TRUE, TRUE) == salPackVolDeleteNone);
    CHECK(SalPackVolCleanupScope(TRUE, FALSE, FALSE) == salPackVolDeleteAll);    // failed, fixed disk
    CHECK(SalPackVolCleanupScope(TRUE, FALSE, TRUE) == salPackVolDeleteCurrent); // failed, removable media
    CHECK(SalPackVolCleanupScope(TRUE, TRUE, FALSE) == salPackVolDeleteNone);    // the Move's clean-up failed
    CHECK(SalPackVolCleanupScope(TRUE, TRUE, TRUE) == salPackVolDeleteNone);     // ... never the archive

    // --- may a recorded volume be deleted? (keep it whenever unsure - code review SF1) ---
    CSalFileIdentity made = Id103(0x77, 0x500, 0, 100, 100);
    CHECK(SalPackCreatedMayDelete(made, TRUE, 4096, TRUE, Id103(0x77, 0x500, 4096, 200, 100)));  // the same file, written since
    CHECK(SalPackCreatedMayDelete(made, FALSE, 0, TRUE, Id103(0x77, 0x500, 9, 200, 0)));         // same id, no creation time now
    CHECK(!SalPackCreatedMayDelete(made, TRUE, 4096, TRUE, Id103(0x77, 0x500, 4096, 200, 101))); // same id, another creation time
    CHECK(!SalPackCreatedMayDelete(made, TRUE, 0, TRUE, Id103(0x77, 0x501, 0, 100, 100)));       // another file took the name
    CHECK(!SalPackCreatedMayDelete(made, TRUE, 0, TRUE, Id103(0x78, 0x500, 0, 100, 100)));       // another disk, same index
    CHECK(!SalPackCreatedMayDelete(made, TRUE, 0, FALSE, made));                                 // nothing there
    // no usable ids (a server without file ids): only the same creation time, a file, the written size
    CSalFileIdentity noId = Id103(0, 0, 0, 1, 50);
    CHECK(SalPackCreatedMayDelete(noId, TRUE, 9000, TRUE, Id103(0, 0, 9000, 60, 50)));           // all witnesses agree
    CHECK(SalPackCreatedMayDelete(noId, FALSE, 0, TRUE, Id103(0, 0, 9000, 60, 50)));             // size not tracked: the time decides
    CHECK(!SalPackCreatedMayDelete(noId, TRUE, 8000, TRUE, Id103(0, 0, 9000, 60, 50)));          // another size: replaced
    CHECK(!SalPackCreatedMayDelete(noId, TRUE, 9000, TRUE, Id103(0, 0, 9000, 60, 51)));          // another creation time
    CHECK(!SalPackCreatedMayDelete(noId, TRUE, 9000, TRUE, Id103(0, 0, 9000, 60, 0)));           // no creation time now
    CHECK(!SalPackCreatedMayDelete(Id103(0, 0, 0, 1, 0), FALSE, 0, TRUE, Id103(0, 0, 9, 2, 0))); // none recorded
    CHECK(!SalPackCreatedMayDelete(noId, FALSE, 0, TRUE, Id103(0, 0, 0, 60, 50, 1, TRUE)));      // a folder now
    CSalFileIdentity link = Id103(0, 0, 9000, 60, 50);
    link.Attr |= FILE_ATTRIBUTE_REPARSE_POINT;
    CHECK(!SalPackCreatedMayDelete(noId, TRUE, 9000, TRUE, link)); // a link now
    CSalFileIdentity unread;
    SalFileIdentityClear(&unread);
    CHECK(!SalPackCreatedMayDelete(unread, FALSE, 0, TRUE, made));                                 // the identity could not be read at creation: kept
    CHECK(!SalPackCreatedMayDelete(made, FALSE, 0, TRUE, unread));                                 // ... or now
    CHECK(!SalPackCreatedMayDelete(Id103(1, 0, 0, 1, 50), FALSE, 0, TRUE, Id103(2, 0, 0, 1, 50))); // no ids, two volumes

    // --- the archive name the last volume is renamed to ---
    CHECK(SalMultiVolFinalNameTaken(FALSE, TRUE, TRUE, FALSE, TRUE));   // fixed disk, WinZip names, name.zip exists
    CHECK(!SalMultiVolFinalNameTaken(FALSE, TRUE, TRUE, FALSE, FALSE)); // the name is free
    CHECK(!SalMultiVolFinalNameTaken(TRUE, TRUE, TRUE, FALSE, TRUE));   // a self-extractor: no rename
    CHECK(!SalMultiVolFinalNameTaken(FALSE, FALSE, TRUE, FALSE, TRUE)); // one name on every disk: asked per volume
    CHECK(!SalMultiVolFinalNameTaken(FALSE, TRUE, FALSE, FALSE, TRUE)); // name01.zip, name02.zip: no rename
    CHECK(!SalMultiVolFinalNameTaken(FALSE, TRUE, TRUE, TRUE, TRUE));   // removable: the last disk decides

    // --- real files (NTFS %TEMP%): a volume recorded from its handle, then replaced ---
    WCHAR tmp[MAX_PATH];
    DWORD n = GetTempPathW(MAX_PATH, tmp);
    if (n == 0 || n >= MAX_PATH)
    {
        printf("skipping the file part of TestPackLeftovers119 (no temp path)\n");
        return;
    }
    std::wstring dir = std::wstring(tmp) + L"saltests-119-" + std::to_wstring(GetCurrentProcessId());
    CHECK(CreateDirectoryW(dir.c_str(), NULL) || GetLastError() == ERROR_ALREADY_EXISTS);
    std::wstring vol = dir + L"\\a.z01", other = dir + L"\\other.bin";
    HANDLE h = CreateFileW(vol.c_str(), GENERIC_WRITE, 0, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
    CHECK(h != INVALID_HANDLE_VALUE);
    CSalFileIdentity rec;
    CHECK(SalFileIdentityFromHandle(h, &rec));
    DWORD w = 0;
    CHECK(WriteFile(h, "volume data", 11, &w, NULL));
    CloseHandle(h);
    CSalFileIdentity now;
    BOOL exists = SalGetFileIdentityW(vol.c_str(), TRUE, &now);
    CHECK(exists && SalPackCreatedMayDelete(rec, TRUE, 11, exists, now)); // still the volume this operation wrote
    // another file takes the name (the volume was moved away, a file of the user's moved in)
    std::wstring moved = dir + L"\\moved.z01";
    CHECK(MoveFileW(vol.c_str(), moved.c_str()));
    h = CreateFileW(other.c_str(), GENERIC_WRITE, 0, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
    CHECK(h != INVALID_HANDLE_VALUE);
    CloseHandle(h);
    CHECK(MoveFileW(other.c_str(), vol.c_str()));
    exists = SalGetFileIdentityW(vol.c_str(), TRUE, &now);
    CHECK(exists && !SalPackCreatedMayDelete(rec, TRUE, 11, exists, now)); // never deleted
    CHECK(DeleteFileW(vol.c_str()));
    exists = SalGetFileIdentityW(vol.c_str(), TRUE, &now);
    CHECK(!exists && !SalPackCreatedMayDelete(rec, TRUE, 11, exists, now)); // gone: nothing to delete
    exists = SalGetFileIdentityW(moved.c_str(), TRUE, &now);
    CHECK(exists && SalPackCreatedMayDelete(rec, TRUE, 11, exists, now)); // the identity follows the file, not the name
    // without ids (as on a server): the creation time and the size alone - the moved volume still
    // matches, the file that took the name does not (another creation time)
    CSalFileIdentity recNoId = rec, nowNoId = now;
    recNoId.Has64 = recNoId.Has128 = FALSE;
    nowNoId.Has64 = nowNoId.Has128 = FALSE;
    CHECK(SalPackCreatedMayDelete(recNoId, TRUE, 11, TRUE, nowNoId));
    CHECK(!SalPackCreatedMayDelete(recNoId, TRUE, 12, TRUE, nowNoId));
    DeleteFileW(moved.c_str());
    CHECK(RemoveDirectoryW(dir.c_str()));
}

// feature 121: the small batch - message box breaks, the Find window's Look in text, the
// plug-ins' whole-character cuts and display text, the FTP typed-login refusal, the folder
// picker's NetHood rule
template <class CH>
static bool Wrap121PiecesFit(const CH* text, int len, const int* adv, int maxWidth, const int* breaks, int n)
{
    // every piece between breaks (and white space) is at most maxWidth wide when it was split
    int prev = 0;
    for (int b = 0; b <= n; b++)
    {
        int end = b < n ? breaks[b] : len;
        if (b < n && (end <= prev || end > len))
            return false; // ascending, inside the text
        if (b > 0 || n > 0)
        {
            long long w = 0;
            for (int i = prev; i < end; i++)
            {
                if (text[i] == ' ' || text[i] == '\t' || text[i] == '\n' || text[i] == '\r')
                    w = 0;
                else
                {
                    w += adv[i];
                    if (w > maxWidth && !(i == prev && adv[i] > maxWidth)) // one over-wide character alone is allowed
                        return false;
                }
            }
        }
        prev = end;
    }
    return true;
}

static void TestSmallBatch121()
{
    // --- SalMsgWrapBreaks (message box) ---
    {
        int adv[400];
        for (int i = 0; i < 400; i++)
            adv[i] = 10;
        int br[400];
        // ordinary words: nothing to do (DrawText breaks between words)
        const char* t1 = "Hello world, these are ordinary words of a message";
        CHECK(SalMsgWrapBreaks(t1, (int)strlen(t1), adv, 100, br, 400) == 0);
        // one long word without separators: cut every 10 units at max 100
        const char* t2 = "abcdefghijabcdefghijabcdefghijabcde"; // 35
        int n = SalMsgWrapBreaks(t2, 35, adv, 100, br, 400);
        CHECK(n == 3 && br[0] == 10 && br[1] == 20 && br[2] == 30);
        CHECK(Wrap121PiecesFit(t2, 35, adv, 100, br, n));
        // the words around a long path are never broken (the old defect: every line cut at the edge)
        const char* t3 = "Cannot open C:\\aaaaaaaaa\\bbbbbbbbb\\ccccccccc\\ddddddddd\\eeee.txt because of words";
        int len3 = (int)strlen(t3);
        n = SalMsgWrapBreaks(t3, len3, adv, 150, br, 400);
        const char* p = strstr(t3, "C:\\");
        int ps = (int)(p - t3), pe = ps + (int)strlen("C:\\aaaaaaaaa\\bbbbbbbbb\\ccccccccc\\ddddddddd\\eeee.txt");
        CHECK(n >= 1);
        bool inside = true;
        for (int b = 0; b < n; b++)
            if (br[b] <= ps || br[b] >= pe)
                inside = false;
        CHECK(inside);
        CHECK(Wrap121PiecesFit(t3, len3, adv, 150, br, n));
        // after a separator: "C:\aaaaaaaaa\" is 13 units = 130 <= 150 and >= 150 / 3
        CHECK(n >= 1 && br[0] == ps + 13 && t3[br[0] - 1] == '\\');
        // a separator too early (a sliver under a third of the width) is not used
        const char* t4 = "a\\bcdefghijklmnopqrstuvwxyz"; // 27
        n = SalMsgWrapBreaks(t4, 27, adv, 100, br, 400);
        CHECK(n >= 1 && br[0] == 10);
        // breaksMax is honoured
        CHECK(SalMsgWrapBreaks(t2, 35, adv, 100, br, 2) == 2);
        // a character wider than the box stands alone and the loop ends
        int wide[3] = {500, 10, 10};
        n = SalMsgWrapBreaks("Wxy", 3, wide, 100, br, 400);
        CHECK(n == 1 && br[0] == 1);
        // invalid input
        CHECK(SalMsgWrapBreaks((const char*)NULL, 5, adv, 100, br, 400) == 0);
        CHECK(SalMsgWrapBreaks(t2, 35, adv, 0, br, 400) == 0);
        // UTF-16: a surrogate pair is never split
        WCHAR w[40];
        for (int i = 0; i < 39; i++)
            w[i] = L'x';
        w[9] = 0xD83D; // pair at 9-10: the break at 10 would split it
        w[10] = 0xDE00;
        w[39] = 0;
        n = SalMsgWrapBreaks(w, 39, adv, 100, br, 400);
        CHECK(n >= 1 && br[0] == 9);
        bool noSplit = true;
        for (int b = 0; b < n; b++)
            if (br[b] > 0 && w[br[b]] >= 0xDC00 && w[br[b]] <= 0xDFFF && w[br[b] - 1] >= 0xD800 && w[br[b] - 1] <= 0xDBFF)
                noSplit = false;
        CHECK(noSplit);
        // a wide pair alone at a piece start stays whole
        int adv2[4] = {500, 0, 10, 10};
        WCHAR w2[5] = {0xD83D, 0xDE00, L'a', L'b', 0};
        n = SalMsgWrapBreaks(w2, 4, adv2, 100, br, 400);
        CHECK(n == 1 && br[0] == 2);
        // a 3,000-unit path is cut into pieces that all fit
        static char longPath[3001];
        for (int i = 0; i < 3000; i++)
            longPath[i] = (i % 17 == 0) ? '\\' : 'a';
        longPath[3000] = 0;
        static int adv3[3000];
        for (int i = 0; i < 3000; i++)
            adv3[i] = 7;
        static int br3[3000];
        n = SalMsgWrapBreaks(longPath, 3000, adv3, 400, br3, 3000);
        CHECK(n > 40 && Wrap121PiecesFit(longPath, 3000, adv3, 400, br3, n));
    }

    // --- SalMenuLabelToTitle (the clipboard error box's title) ---
    {
        char t[64];
        SalMenuLabelToTitle(t, sizeof(t), "&Copy To Clipboard");
        CHECK(strcmp(t, "Copy To Clipboard") == 0);
        SalMenuLabelToTitle(t, sizeof(t), "Kop\xEDrovat do &schr\xE1nky"); // a code-page label, mark inside
        CHECK(strcmp(t, "Kop\xEDrovat do schr\xE1nky") == 0);
        SalMenuLabelToTitle(t, sizeof(t), "\xE5\xA4\x8D\xE5\x88\xB6 (&C)"); // CJK style: " (&C)" goes
        CHECK(strcmp(t, "\xE5\xA4\x8D\xE5\x88\xB6") == 0);
        SalMenuLabelToTitle(t, sizeof(t), "Save && E&xit");
        CHECK(strcmp(t, "Save & Exit") == 0);
        SalMenuLabelToTitle(t, sizeof(t), NULL);
        CHECK(t[0] == 0);
        char t4[4];
        SalMenuLabelToTitle(t4, sizeof(t4), "&abcdef");
        CHECK(strcmp(t4, "abc") == 0);
    }

    // --- SalFindLookInFromPath / SalFindComposeItemName (Find window) ---
    {
        char buf[32];
        CHECK(SalFindLookInFromPath("C:\\a;b", buf, sizeof(buf)) && strcmp(buf, "C:\\a;;b") == 0);
        CHECK(SalFindLookInFromPath("", buf, sizeof(buf)) && buf[0] == 0);
        CHECK(SalFindLookInFromPath(NULL, buf, sizeof(buf)) && buf[0] == 0);
        // exactly fits (9 bytes + terminator in 10), one more does not - never cut
        char b10[10];
        CHECK(SalFindLookInFromPath("C:\\abcdef", b10, sizeof(b10)) && strcmp(b10, "C:\\abcdef") == 0);
        CHECK(!SalFindLookInFromPath("C:\\abcdefg", b10, sizeof(b10)) && b10[0] == 0);
        CHECK(!SalFindLookInFromPath("C:\\abcde;", b10, sizeof(b10)) && b10[0] == 0); // the doubled ';' does not fit
        CHECK(SalFindLookInFromPath("C:\\abcd;", b10, sizeof(b10)) && strcmp(b10, "C:\\abcd;;") == 0);
        // a 600-byte accented path (the old field cut it at 259 bytes, inside a character)
        static char deep[700], out[1024];
        strcpy(deep, "C:\\");
        for (int i = 0; i < 100; i++)
            strcat(deep, "\xC4\x8D\xC5\x99\\"); // c-caron, r-caron, backslash
        CHECK(strlen(deep) == 503);
        CHECK(SalFindLookInFromPath(deep, out, sizeof(out)) && strcmp(out, deep) == 0);
        // item name: whole when it fits, cut at a whole character when not
        char name[64];
        SalFindComposeItemName(name, sizeof(name), "*.txt", "in", "C:\\x");
        CHECK(strcmp(name, "\"*.txt\" in \"C:\\x\"") == 0);
        char nameSmall[20];
        SalFindComposeItemName(nameSmall, sizeof(nameSmall), "*", "v", deep);
        CHECK(strlen(nameSmall) <= 19 && MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, nameSmall, -1, NULL, 0) > 0);
        CHECK(strncmp(nameSmall, "\"*\" v \"C:\\", 10) == 0);
        SalFindComposeItemName(nameSmall, sizeof(nameSmall), NULL, NULL, NULL);
        CHECK(strcmp(nameSmall, "\"\"  \"\"") == 0);
    }

    // --- SplU8TrimTornTail / SplU8CopyTrunc / SplDisplayTextToWAlloc (plug-ins) ---
    {
        char t[16];
        strcpy(t, "ab\xC4"); // torn 2-byte lead
        SplU8TrimTornTail(t);
        CHECK(strcmp(t, "ab") == 0);
        strcpy(t, "ab\xE2\x82"); // torn 3-byte sequence
        SplU8TrimTornTail(t);
        CHECK(strcmp(t, "ab") == 0);
        strcpy(t, "ab\xC4\x8D"); // complete character kept
        SplU8TrimTornTail(t);
        CHECK(strcmp(t, "ab\xC4\x8D") == 0);
        strcpy(t, "ab\xF0\x9F\x98"); // torn 4-byte sequence
        SplU8TrimTornTail(t);
        CHECK(strcmp(t, "ab") == 0);
        SplU8TrimTornTail(NULL); // no crash
        char d[6];
        SplU8CopyTrunc(d, sizeof(d), "abcd\xC4\x8D"); // 6 bytes into 5: the 2-byte character would be torn
        CHECK(strcmp(d, "abcd") == 0);
        SplU8CopyTrunc(d, sizeof(d), "abc\xC4\x8D"); // exactly fits
        CHECK(strcmp(d, "abc\xC4\x8D") == 0);
        SplU8CopyTrunc(d, sizeof(d), "abcdefgh"); // ASCII cut as lstrcpyn
        CHECK(strcmp(d, "abcde") == 0);
        SplU8CopyTrunc(d, sizeof(d), "ab\xE1"); // code-page text that fits is untouched
        CHECK(strcmp(d, "ab\xE1") == 0);
        SplU8CopyTrunc(d, sizeof(d), NULL);
        CHECK(d[0] == 0);
        WCHAR* w = SplDisplayTextToWAlloc("C:\\\xC4\x8D.txt"); // UTF-8
        CHECK(w != NULL && wcscmp(w, L"C:\\\x010D.txt") == 0);
        free(w);
        w = SplDisplayTextToWAlloc("C:\\\xC4\x8D\xC4"); // UTF-8 with a torn tail: shown without it
        CHECK(w != NULL && wcscmp(w, L"C:\\\x010D") == 0);
        free(w);
        w = SplDisplayTextToWAlloc("ab\xE2\x82"); // a torn 3-byte sequence (a continuation byte left)
        CHECK(w != NULL && wcscmp(w, L"ab") == 0);
        free(w);
        // review NIT 1: ASCII + one code-page letter >= 0xC0 at the end is code-page text, not a torn tail
        w = SplDisplayTextToWAlloc("Fichier utilis\xE9");
        WCHAR expectCp[32];
        MultiByteToWideChar(CP_ACP, 0, "Fichier utilis\xE9", -1, expectCp, 32);
        CHECK(w != NULL && wcscmp(w, expectCp) == 0 && wcslen(w) == 15);
        free(w);
        w = SplDisplayTextToWAlloc("\xED\xA0\x80x"); // WTF-8 lone surrogate
        CHECK(w != NULL && w[0] == 0xD800 && w[1] == L'x' && w[2] == 0);
        free(w);
        w = SplDisplayTextToWAlloc("Chyba \xE8ten\xED"); // code-page text (not UTF-8): through the code page
        WCHAR expect[32];
        MultiByteToWideChar(CP_ACP, 0, "Chyba \xE8ten\xED", -1, expect, 32);
        CHECK(w != NULL && wcscmp(w, expect) == 0);
        free(w);
        w = SplDisplayTextToWAlloc(NULL);
        CHECK(w != NULL && w[0] == 0);
        free(w);
    }

    // --- SalFtpTypedLoginTooLong (FTP Change Directory / upload target) ---
    {
        static char pw[400];
        memset(pw, 0, sizeof(pw));
        for (int i = 0; i < 300; i++)
            pw[i] = 'p';
        CHECK(!SalFtpTypedLoginTooLong("u:p@h", 610, "u", 101, "h", 201, pw, 301)); // 300 bytes fit 301
        pw[300] = 'p';
        CHECK(SalFtpTypedLoginTooLong("u:p@h", 610, "u", 101, "h", 201, pw, 301)); // 301 do not
        CHECK(!SalFtpTypedLoginTooLong("x", 610, NULL, 101, "h", 201, NULL, 301));
        static char user[200];
        memset(user, 'u', 100);
        user[100] = 0;
        CHECK(!SalFtpTypedLoginTooLong("x", 610, user, 101, "h", 201, NULL, 301));
        user[100] = 'u';
        user[101] = 0;
        CHECK(SalFtpTypedLoginTooLong("x", 610, user, 101, "h", 201, NULL, 301));
        static char host[300];
        memset(host, 'h', 201);
        host[201] = 0;
        CHECK(SalFtpTypedLoginTooLong("x", 610, NULL, 101, host, 201, NULL, 301));
        host[200] = 0;
        CHECK(!SalFtpTypedLoginTooLong("x", 610, NULL, 101, host, 201, NULL, 301));
        static char part[700];
        memset(part, 'a', 610);
        part[610] = 0;
        CHECK(SalFtpTypedLoginTooLong(part, 610, NULL, 101, "h", 201, NULL, 301)); // the copy would cut it
        part[609] = 0;
        CHECK(!SalFtpTypedLoginTooLong(part, 610, NULL, 101, "h", 201, NULL, 301));
    }

    // --- the folder picker's NetHood rule (splfiledlg.h) ---
    {
        const char* ini = "[.ShellClassInfo]\r\nCLSID2={0AFACED1-E828-11D1-9187-B532F1E9575D}\r\nFlags=2\r\n";
        CHECK(SplFileDlgDetail::IsFolderShortcutIni(ini, (int)strlen(ini)));
        const char* iniLower = "CLSID2={0afaced1-e828-11d1-9187-b532f1e9575d}";
        CHECK(SplFileDlgDetail::IsFolderShortcutIni(iniLower, (int)strlen(iniLower)));
        const char* iniPrefix = "CLSID2={0AFACED1}"; // the core matched a prefix; the whole id is required
        CHECK(!SplFileDlgDetail::IsFolderShortcutIni(iniPrefix, (int)strlen(iniPrefix)));
        const char* iniOther = "CLSID={645FF040-5081-101B-9F08-00AA002F954E}";
        CHECK(!SplFileDlgDetail::IsFolderShortcutIni(iniOther, (int)strlen(iniOther)));
        const char* iniOpen = "CLSID2={0AFACED1-E828-11D1-9187-B532F1E9575D"; // no closing brace
        CHECK(!SplFileDlgDetail::IsFolderShortcutIni(iniOpen, (int)strlen(iniOpen)));
        CHECK(!SplFileDlgDetail::IsFolderShortcutIni(NULL, 5));


        // end to end: a folder shortcut in %TEMP% (a fixed drive) pointing at another folder
        HRESULT coInit = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
        WCHAR tmp[MAX_PATH];
        DWORD tl = GetTempPathW(MAX_PATH, tmp);
        WCHAR rootDir[MAX_PATH], sc[MAX_PATH], tgt[MAX_PATH], file[MAX_PATH];
        if (tl > 0 && tl < MAX_PATH - 80)
        {
            swprintf(rootDir, MAX_PATH, L"%stc121_nethood_%lu", tmp, GetCurrentProcessId());
            swprintf(sc, MAX_PATH, L"%s\\sc \x010D", rootDir);    // the shortcut folder (accented name)
            swprintf(tgt, MAX_PATH, L"%s\\target \x0159", rootDir); // where it points
            CreateDirectoryW(rootDir, NULL);
            CreateDirectoryW(sc, NULL);
            CreateDirectoryW(tgt, NULL);
            // no desktop.ini yet: not a shortcut
            WCHAR* r = SplFileDlgDetail::ResolveNetHoodFolderW(sc);
            CHECK(r == NULL);
            free(r);
            swprintf(file, MAX_PATH, L"%s\\desktop.ini", sc);
            HANDLE h = CreateFileW(file, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, 0, NULL);
            CHECK(h != INVALID_HANDLE_VALUE);
            if (h != INVALID_HANDLE_VALUE)
            {
                DWORD wr;
                WriteFile(h, ini, (DWORD)strlen(ini), &wr, NULL);
                CloseHandle(h);
            }
            // desktop.ini but no target.lnk: not resolved
            r = SplFileDlgDetail::ResolveNetHoodFolderW(sc);
            CHECK(r == NULL);
            free(r);
            swprintf(file, MAX_PATH, L"%s\\target.lnk", sc);
            IShellLinkW* link = NULL;
            bool made = false;
            if (CoCreateInstance(CLSID_ShellLink, NULL, CLSCTX_INPROC_SERVER, IID_IShellLinkW, (LPVOID*)&link) == S_OK)
            {
                link->SetPath(tgt);
                IPersistFile* pf = NULL;
                if (link->QueryInterface(IID_IPersistFile, (LPVOID*)&pf) == S_OK)
                {
                    made = pf->Save(file, TRUE) == S_OK;
                    pf->Release();
                }
                link->Release();
            }
            CHECK(made);
            r = SplFileDlgDetail::ResolveNetHoodFolderW(sc);
            CHECK(r != NULL && _wcsicmp(r, tgt) == 0);
            free(r);
            // with a trailing backslash too
            WCHAR scSlash[MAX_PATH];
            swprintf(scSlash, MAX_PATH, L"%s\\", sc);
            r = SplFileDlgDetail::ResolveNetHoodFolderW(scSlash);
            CHECK(r != NULL && _wcsicmp(r, tgt) == 0);
            free(r);
            // a UNC path is never NetHood; NULL and "" are not
            CHECK(SplFileDlgDetail::ResolveNetHoodFolderW(L"\\\\server\\share") == NULL);
            CHECK(SplFileDlgDetail::ResolveNetHoodFolderW(L"") == NULL);
            CHECK(SplFileDlgDetail::ResolveNetHoodFolderW(NULL) == NULL);
            DeleteFileW(file);
            swprintf(file, MAX_PATH, L"%s\\desktop.ini", sc);
            DeleteFileW(file);
            RemoveDirectoryW(sc);
            RemoveDirectoryW(tgt);
            RemoveDirectoryW(rootDir);
        }
        else
            CHECK(!"GetTempPathW");
        if (SUCCEEDED(coInit))
            CoUninitialize();
    }
}

//
// ****************************************************************************
// feature 123: checking for a new version - the pure rules (salupdcheck.h)
//

static const char UpdRealRecord123[] =
#include "updcheck123_fixture.inc"
    ;

// a minimal record the reader accepts; 'tag' and the addresses are given so that tests can break each of them
static std::string UpdMakeRecord123(const char* tag, const char* published, const char* htmlUrl,
                                    const char* assetName, const char* assetState, const char* assetUrl,
                                    const char* draft = "false", const char* prerelease = "false",
                                    const char* extraTop = "", const char* extraAsset = "")
{
    std::string s = "{\"url\":\"https://api.github.com/x\",\"author\":{\"login\":\"a\",\"id\":1,\"site_admin\":false},";
    s += "\"tag_name\":\"";
    s += tag;
    s += "\",\"draft\":";
    s += draft;
    s += ",\"prerelease\":";
    s += prerelease;
    s += ",\"published_at\":\"";
    s += published;
    s += "\",\"html_url\":\"";
    s += htmlUrl;
    s += "\",";
    s += extraTop;
    s += "\"assets\":[{\"id\":7,\"name\":\"";
    s += assetName;
    s += "\",\"uploader\":{\"login\":\"a\"},\"state\":\"";
    s += assetState;
    s += "\",\"size\":8247136,";
    s += extraAsset;
    s += "\"browser_download_url\":\"";
    s += assetUrl;
    s += "\"}],\"body\":\"text with \\\"tag_name\\\":\\\"v9.9.9\\\" and {braces} [x]\\n\\u010d\\ud83d\\udcc1\"}";
    return s;
}

#define UPD_TAG_019 "v0.1.9"
#define UPD_TIME_019 "2026-10-14T08:00:00Z"
#define UPD_NOTES_019 "https://github.com/tandemcommander/tandemcommander/releases/tag/v0.1.9"
#define UPD_NAME_019 "tandemcommander-0.1.9-x64-setup.exe"
#define UPD_URL_019 "https://github.com/tandemcommander/tandemcommander/releases/download/v0.1.9/tandemcommander-0.1.9-x64-setup.exe"

static BOOL UpdParses123(const std::string& s, CSalUpdParseError* err = NULL)
{
    CSalUpdRelease rel;
    return SalUpdParseLatestRelease(s.c_str(), s.size(), &rel, err);
}

static CSalUpdParseError UpdError123(const std::string& s)
{
    CSalUpdParseError err = supeNone;
    CSalUpdRelease rel;
    if (SalUpdParseLatestRelease(s.c_str(), s.size(), &rel, &err))
        return supeNone;
    return err;
}

static void TestUpdateCheck123()
{
    // ---- versions: parsing
    CSalUpdVersion v;
    CHECK(SalUpdParseVersion("0.1.8", -1, FALSE, &v) && v.Major == 0 && v.Minor == 1 && v.Patch == 8);
    CHECK(SalUpdParseVersion("v0.1.8", -1, TRUE, &v) && v.Major == 0 && v.Minor == 1 && v.Patch == 8);
    CHECK(SalUpdParseVersion("v12.345.67890", -1, TRUE, &v) && v.Major == 12 && v.Minor == 345 && v.Patch == 67890);
    CHECK(SalUpdParseVersion("99999.99999.99999", -1, FALSE, &v) && v.Major == 99999);
    CHECK(SalUpdParseVersion("v0.01.9", -1, TRUE, &v) && v.Minor == 1); // parses; its addresses will not match (below)
    static const char* badVersions[] = {
        "", "v", "0", "0.1", "0.1.", "0.1.8.", "0.1.8.0", ".1.8", "0..8", "0.1.8 ", " 0.1.8", "0.1.8\n",
        "0.1.8-beta", "0.1.8b", "V0.1.8", "vv0.1.8", "+0.1.8", "-0.1.8", "0.-1.8", "0.1.+8", "0,1,8",
        "100000.1.8", "0.100000.8", "0.1.100000", "0x1.1.8", "1e1.1.8", "\xEF\xBC\x90.1.8",
        "0.1.8/", "0.1.8?x", "0.1.8#", "0.1.8%20", "..", "...", "a.b.c"};
    for (int i = 0; i < _countof(badVersions); i++)
    {
        CHECK(!SalUpdParseVersion(badVersions[i], -1, FALSE, &v));
        std::string t = std::string("v") + badVersions[i];
        CHECK(!SalUpdParseVersion(t.c_str(), -1, TRUE, &v));
    }
    CHECK(!SalUpdParseVersion("0.1.8", -1, TRUE, &v));   // the tag form needs the v
    CHECK(!SalUpdParseVersion("v0.1.8", -1, FALSE, &v)); // the stored form has none
    CHECK(!SalUpdParseVersion(NULL, -1, FALSE, &v) && !SalUpdParseVersion("0.1.8", -1, FALSE, NULL));
    CHECK(SalUpdParseVersion("0.1.8xyz", 5, FALSE, &v) && v.Patch == 8); // the length is honoured
    CHECK(!SalUpdParseVersion("0.1.8", 4, FALSE, &v));
    CHECK(!SalUpdParseVersion("0.1.8\0"
                              "9",
                              7, FALSE, &v)); // an embedded zero is not a digit

    // ---- versions: order
    static const CSalUpdVersion order[] = {{0, 0, 0}, {0, 0, 1}, {0, 1, 0}, {0, 1, 8}, {0, 1, 9}, {0, 1, 10}, {0, 2, 0}, {0, 10, 0}, {1, 0, 0}, {1, 0, 1}, {2, 0, 0}, {10, 0, 0}, {99999, 99999, 99999}};
    for (int i = 0; i < _countof(order); i++)
    {
        for (int j = 0; j < _countof(order); j++)
        {
            int c = SalUpdVersionCompare(order[i], order[j]);
            CHECK((i < j && c < 0) || (i == j && c == 0) || (i > j && c > 0));
        }
    }

    // ---- versions: printing and the constructed addresses
    char buf[SALUPD_URL_MAX];
    CSalUpdVersion v019 = {0, 1, 9};
    CHECK(SalUpdFormatVersion(v019, buf, sizeof(buf)) && strcmp(buf, "0.1.9") == 0);
    CHECK(SalUpdFormatVersion(order[_countof(order) - 1], buf, SALUPD_VERSION_TEXT_MAX) && strcmp(buf, "99999.99999.99999") == 0);
    CHECK(!SalUpdFormatVersion(v019, buf, 5) && buf[0] == 0); // "0.1.9" needs 6 bytes
    CHECK(SalUpdFormatVersion(v019, buf, 6));
    CHECK(SalUpdInstallerUrl(v019, buf, sizeof(buf)) && strcmp(buf, UPD_URL_019) == 0);
    CHECK(SalUpdInstallerName(v019, buf, sizeof(buf)) && strcmp(buf, UPD_NAME_019) == 0);
    CHECK(SalUpdReleaseNotesUrl(v019, buf, sizeof(buf)) && strcmp(buf, UPD_NOTES_019) == 0);
    // the longest version still fits the address buffer and CHyperLink's MAX_PATH action
    CHECK(SalUpdInstallerUrl(order[_countof(order) - 1], buf, sizeof(buf)) && strlen(buf) < SALUPD_URL_MAX && strlen(buf) < MAX_PATH);
    CHECK(!SalUpdInstallerUrl(v019, buf, 20) && buf[0] == 0);
    CHECK(!SalUpdReleaseNotesUrl(v019, buf, 20) && buf[0] == 0);
    // every constructed address starts with the official releases prefix and holds only URL-safe characters
    for (int i = 0; i < _countof(order); i++)
    {
        for (int k = 0; k < 2; k++)
        {
            CHECK(k == 0 ? SalUpdInstallerUrl(order[i], buf, sizeof(buf)) : SalUpdReleaseNotesUrl(order[i], buf, sizeof(buf)));
            CHECK(strncmp(buf, "https://github.com/tandemcommander/tandemcommander/releases/", 60) == 0);
            BOOL safe = TRUE;
            for (const char* p = buf; *p != 0; p++)
            {
                if (!((*p >= 'a' && *p <= 'z') || (*p >= '0' && *p <= '9') || strchr(":/.-", *p) != NULL))
                    safe = FALSE;
            }
            CHECK(safe);
        }
    }

    // ---- time
    ULONGLONG ft;
    CHECK(SalUpdParseUtcTime("2026-09-20T14:34:53Z", -1, &ft));
    {
        SYSTEMTIME st;
        FILETIME f;
        f.dwLowDateTime = (DWORD)(ft & 0xFFFFFFFF);
        f.dwHighDateTime = (DWORD)(ft >> 32);
        CHECK(FileTimeToSystemTime(&f, &st) && st.wYear == 2026 && st.wMonth == 9 && st.wDay == 20 &&
              st.wHour == 14 && st.wMinute == 34 && st.wSecond == 53);
    }
    CHECK(SalUpdParseUtcTime("2028-02-29T00:00:00Z", -1, &ft)); // leap year
    CHECK(SalUpdParseUtcTime("2000-02-29T23:59:59Z", -1, &ft));
    static const char* badTimes[] = {
        "", "2026-09-20", "2026-09-20T14:34:53", "2026-09-20T14:34:53z", "2026-09-20 14:34:53Z",
        "2026-09-20T14:34:53+00:00", "2026-09-20T14:34:53.000Z", "2026-13-01T00:00:00Z", "2026-00-10T00:00:00Z",
        "2026-02-29T00:00:00Z", "2100-02-29T00:00:00Z", "2026-04-31T00:00:00Z", "2026-01-00T00:00:00Z",
        "2026-01-32T00:00:00Z", "2026-01-01T24:00:00Z", "2026-01-01T00:60:00Z", "2026-01-01T00:00:60Z",
        "1600-01-01T00:00:00Z", "0000-01-01T00:00:00Z", "2026-09-20T14:34:53ZZ", " 2026-09-20T14:34:53Z",
        "2026/09/20T14:34:53Z", "2026-9-20T14:34:53Z0", "-026-09-20T14:34:53Z", "2026-09-20T14:34:5 Z"};
    for (int i = 0; i < _countof(badTimes); i++)
        CHECK(!SalUpdParseUtcTime(badTimes[i], -1, &ft));
    CHECK(!SalUpdParseUtcTime(NULL, -1, &ft) && !SalUpdParseUtcTime("2026-09-20T14:34:53Z", -1, NULL));

    // ---- the JSON reader: grammar
    static const char* goodJson[] = {
        "{}", " { } ", "{\"a\":1}", "{\"a\":-0.5e+10,\"b\":[1,2,[3,{\"c\":null}]],\"d\":true,\"e\":false}",
        "{\"a\":\"\\\"\\\\\\/\\b\\f\\n\\r\\t\\u00e9\\ud83d\\udcc1\"}", "\t\r\n{\"a\":[]}\r\n ", "{\"\":0}",
        "{\"a\":0,\"a\":1}", "{\"a\":1E5}", "{\"a\":\"\xC4\x8D\"}"};
    for (int i = 0; i < _countof(goodJson); i++)
    {
        CSalUpdJsonReader r(goodJson[i], strlen(goodJson[i]));
        CHECK(r.SkipValue(1) && !r.IsFailed() && r.AtEnd());
    }
    static const char* badJson[] = {
        "", " ", "{", "}", "{\"a\"}", "{\"a\":}", "{\"a\":1,}", "{,\"a\":1}", "{\"a\":1 \"b\":2}", "{a:1}",
        "{'a':1}", "{\"a\":01}", "{\"a\":1.}", "{\"a\":.5}", "{\"a\":1e}", "{\"a\":+1}", "{\"a\":tru}",
        "{\"a\":True}", "{\"a\":nul}", "{\"a\":\"x}", "{\"a\":\"\\x\"}", "{\"a\":\"\\u12g4\"}", "{\"a\":\"\\u12\"}",
        "{\"a\":\"line\nbreak\"}", "{\"a\":\"tab\there\"}", "{\"a\":[1,2}", "{\"a\":[1 2]}", "{\"a\":[,1]}",
        "{\"a\":1}}", "{\"a\":1}x", "{\"a\":1}{}", "[1,2", "{\"a\":--1}", "{\"a\":NaN}",
        "{\"a\":Infinity}", "{\"a\":0x10}", "{\"a\"::1}", "{\"a\":1;\"b\":2}", "{\"a\":\"\\\"}"};
    for (int i = 0; i < _countof(badJson); i++)
    {
        CSalUpdJsonReader r(badJson[i], strlen(badJson[i]));
        CHECK(!(r.SkipValue(1) && !r.IsFailed() && r.AtEnd()));
    }
    {
        static const char withZero[] = "{\"a\":1}\0x"; // a zero byte after the value is not white space
        CSalUpdJsonReader r(withZero, sizeof(withZero) - 1);
        CHECK(!(r.SkipValue(1) && r.AtEnd()));
        static const char zeroInString[] = "{\"a\":\"x\0y\"}"; // a raw control character inside a string
        CSalUpdJsonReader r2(zeroInString, sizeof(zeroInString) - 1);
        CHECK(!r2.SkipValue(1));
        CSalUpdJsonReader r3(NULL, 0);
        CHECK(r3.IsFailed() && !r3.SkipValue(1));
    }
    // nesting: SALUPD_MAX_DEPTH levels pass, one more fails (arrays and objects)
    for (int kind = 0; kind < 2; kind++)
    {
        for (int depth = SALUPD_MAX_DEPTH - 1; depth <= SALUPD_MAX_DEPTH + 1; depth++)
        {
            std::string s;
            for (int i = 0; i < depth; i++)
                s += kind == 0 ? "[" : "{\"a\":";
            s += "1";
            for (int i = 0; i < depth; i++)
                s += kind == 0 ? "]" : "}";
            CSalUpdJsonReader r(s.c_str(), s.size());
            BOOL ok = r.SkipValue(1) && r.AtEnd();
            CHECK(ok == (depth <= SALUPD_MAX_DEPTH));
        }
    }
    {
        // a deep bomb must fail fast and must not overflow the stack
        std::string s(200000, '[');
        CSalUpdJsonReader r(s.c_str(), s.size());
        CHECK(!r.SkipValue(1));
    }

    // ---- the JSON reader: strings
    {
        char out[32];
        BOOL bad;
        const char* s1 = "\"a\\u010d\\ud83d\\udcc1\\n\\\"z\"";
        CSalUpdJsonReader r1(s1, strlen(s1));
        CHECK(r1.ReadString(out, sizeof(out), &bad) && !bad && strcmp(out, "a\xC4\x8D\xF0\x9F\x93\x81\n\"z") == 0);
        const char* s2 = "\"\\ud83d\""; // a lone high surrogate
        CSalUpdJsonReader r2(s2, strlen(s2));
        CHECK(r2.ReadString(out, sizeof(out), &bad) && bad && out[0] == 0);
        const char* s3 = "\"\\udcc1x\""; // a lone low surrogate
        CSalUpdJsonReader r3(s3, strlen(s3));
        CHECK(r3.ReadString(out, sizeof(out), &bad) && bad && out[0] == 0);
        const char* s4 = "\"\\ud83d\\u0041\""; // high surrogate followed by an ordinary escape
        CSalUpdJsonReader r4(s4, strlen(s4));
        CHECK(r4.ReadString(out, sizeof(out), &bad) && bad && r4.AtEnd());
        const char* s5 = "\"ab\\u0000cd\""; // an escaped NUL would cut a C string
        CSalUpdJsonReader r5(s5, strlen(s5));
        CHECK(r5.ReadString(out, sizeof(out), &bad) && bad && out[0] == 0);
        const char* s6 = "\"0123456789\"";
        CSalUpdJsonReader r6(s6, strlen(s6));
        CHECK(r6.ReadString(out, 11, &bad) && !bad && strcmp(out, "0123456789") == 0); // fits exactly
        CSalUpdJsonReader r7(s6, strlen(s6));
        CHECK(r7.ReadString(out, 10, &bad) && bad && out[0] == 0 && r7.AtEnd()); // one byte short: bad, grammar intact
        CSalUpdJsonReader r8(s2, strlen(s2));
        CHECK(r8.ReadString(NULL, 0, NULL) && r8.AtEnd()); // skipping does not judge surrogates
    }

    // ---- the release record: the real answer for 0.1.8
    CSalUpdRelease rel;
    CSalUpdParseError err;
    size_t realLen = strlen(UpdRealRecord123);
    CHECK(realLen > 7000 && realLen < 9000);
    CHECK(SalUpdParseLatestRelease(UpdRealRecord123, realLen, &rel, &err) && err == supeNone);
    CHECK(rel.Version.Major == 0 && rel.Version.Minor == 1 && rel.Version.Patch == 8);
    CHECK(strcmp(rel.PublishedText, "2026-09-20T14:34:53Z") == 0);
    CHECK(SalUpdParseUtcTime("2026-09-20T14:34:53Z", -1, &ft) && rel.PublishedUtc == ft);
    {
        CSalUpdVersion v017 = {0, 1, 7}, v018 = {0, 1, 8}, v020 = {0, 2, 0};
        CHECK(SalUpdClassify(rel, v017) == surNewer);
        CHECK(SalUpdClassify(rel, v018) == surUpToDate);
        CHECK(SalUpdClassify(rel, v020) == surUpToDate); // a development build newer than the latest release
    }

    // mutation sweep over the real record: whatever a damaged answer parses to, it is never another
    // version than 0.1.8 (the addresses are constructed from the version, so that is the whole risk)
    {
        std::string real(UpdRealRecord123, realLen);
        int accepted = 0, wrong = 0;
        for (size_t i = 0; i < realLen; i++)
        {
            std::string m = real;
            m.erase(i, 1); // each byte deleted
            CSalUpdRelease r;
            if (SalUpdParseLatestRelease(m.c_str(), m.size(), &r))
            {
                accepted++;
                if (r.Version.Major != 0 || r.Version.Minor != 1 || r.Version.Patch != 8)
                    wrong++;
            }
        }
        CHECK(wrong == 0);
        CHECK(accepted < (int)realLen); // deletions inside skipped text are harmless, the others are refused
        static const char repl[] = "{}[]\":,\\0 v.-/";
        int wrong2 = 0;
        for (size_t i = 0; i < realLen; i++)
        {
            for (int k = 0; repl[k] != 0; k++)
            {
                if (real[i] == repl[k])
                    continue;
                std::string m = real;
                m[i] = repl[k]; // each byte replaced by each structural character
                CSalUpdRelease r;
                if (SalUpdParseLatestRelease(m.c_str(), m.size(), &r) &&
                    (r.Version.Major != 0 || r.Version.Minor != 1 || r.Version.Patch != 8))
                    wrong2++;
            }
        }
        CHECK(wrong2 == 0);
        int wrong3 = 0;
        for (size_t n = 0; n < realLen; n++) // every truncation is refused
        {
            CSalUpdRelease r;
            if (SalUpdParseLatestRelease(real.c_str(), n, &r))
                wrong3++;
        }
        CHECK(wrong3 == 0);
        // changing the version in the tag alone is not enough: the addresses must follow
        std::string m = real;
        size_t pos = m.find("\"tag_name\": \"v0.1.8\"");
        CHECK(pos != std::string::npos);
        if (pos != std::string::npos)
        {
            m.replace(pos, 20, "\"tag_name\": \"v0.1.9\"");
            CHECK(UpdError123(m) == supeForeignNotes);
        }
    }

    // ---- the release record: the rules, one broken at a time
    std::string good = UpdMakeRecord123(UPD_TAG_019, UPD_TIME_019, UPD_NOTES_019, UPD_NAME_019, "uploaded", UPD_URL_019);
    CHECK(SalUpdParseLatestRelease(good.c_str(), good.size(), &rel, &err) && err == supeNone);
    CHECK(rel.Version.Major == 0 && rel.Version.Minor == 1 && rel.Version.Patch == 9);
    CHECK(strcmp(rel.PublishedText, UPD_TIME_019) == 0);
    // the body of the record holds "tag_name":"v9.9.9" as text - it must not be taken for the member
    CHECK(rel.Version.Major != 9);

    CHECK(UpdError123(UpdMakeRecord123(UPD_TAG_019, UPD_TIME_019, UPD_NOTES_019, UPD_NAME_019, "uploaded", UPD_URL_019, "true")) == supeDraft);
    CHECK(UpdError123(UpdMakeRecord123(UPD_TAG_019, UPD_TIME_019, UPD_NOTES_019, UPD_NAME_019, "uploaded", UPD_URL_019, "null")) == supeDraft);
    CHECK(UpdError123(UpdMakeRecord123(UPD_TAG_019, UPD_TIME_019, UPD_NOTES_019, UPD_NAME_019, "uploaded", UPD_URL_019, "0")) == supeDraft);
    CHECK(UpdError123(UpdMakeRecord123(UPD_TAG_019, UPD_TIME_019, UPD_NOTES_019, UPD_NAME_019, "uploaded", UPD_URL_019, "\"false\"")) == supeDraft);
    CHECK(UpdError123(UpdMakeRecord123(UPD_TAG_019, UPD_TIME_019, UPD_NOTES_019, UPD_NAME_019, "uploaded", UPD_URL_019, "false", "true")) == supePrerelease);
    CHECK(UpdError123(UpdMakeRecord123(UPD_TAG_019, UPD_TIME_019, UPD_NOTES_019, UPD_NAME_019, "uploaded", UPD_URL_019, "false", "[]")) == supePrerelease);

    static const char* badTags[] = {"0.1.9", "v0.1", "v0.1.9-beta", "v0.1.9 ", "V0.1.9", "v0.1.9.1", "latest", "", "v0.1.123456", "v0.1.9\\u0000"};
    for (int i = 0; i < _countof(badTags); i++)
        CHECK(UpdError123(UpdMakeRecord123(badTags[i], UPD_TIME_019, UPD_NOTES_019, UPD_NAME_019, "uploaded", UPD_URL_019)) == supeBadTag);
    // leading zeros parse as a version, but the tag must be the canonical print of its numbers -
    // with addresses spelled like the tag, and (found by the independent adversarial test) with
    // canonical addresses too
    CHECK(UpdError123(UpdMakeRecord123("v0.01.9", UPD_TIME_019, "https://github.com/tandemcommander/tandemcommander/releases/tag/v0.01.9",
                                       "tandemcommander-0.01.9-x64-setup.exe", "uploaded",
                                       "https://github.com/tandemcommander/tandemcommander/releases/download/v0.01.9/tandemcommander-0.01.9-x64-setup.exe")) == supeBadTag);
    CHECK(UpdError123(UpdMakeRecord123("v00.01.009", UPD_TIME_019, UPD_NOTES_019, UPD_NAME_019, "uploaded", UPD_URL_019)) == supeBadTag);
    CHECK(UpdError123(UpdMakeRecord123("v0.1.09", UPD_TIME_019, UPD_NOTES_019, UPD_NAME_019, "uploaded", UPD_URL_019)) == supeBadTag);

    CHECK(UpdError123(UpdMakeRecord123(UPD_TAG_019, "2026-10-14", UPD_NOTES_019, UPD_NAME_019, "uploaded", UPD_URL_019)) == supeBadTime);
    CHECK(UpdError123(UpdMakeRecord123(UPD_TAG_019, "2026-02-30T08:00:00Z", UPD_NOTES_019, UPD_NAME_019, "uploaded", UPD_URL_019)) == supeBadTime);
    CHECK(UpdError123(UpdMakeRecord123(UPD_TAG_019, "", UPD_NOTES_019, UPD_NAME_019, "uploaded", UPD_URL_019)) == supeBadTime);

    static const char* badNotes[] = {
        "https://evil.example/tandemcommander/tandemcommander/releases/tag/v0.1.9",
        "http://github.com/tandemcommander/tandemcommander/releases/tag/v0.1.9",
        "https://github.com/tandemcommander/tandemcommander/releases/tag/v0.1.8",
        "https://github.com/tandemcommander/tandemcommander/releases/tag/v0.1.9/",
        "https://github.com/tandemcommander/tandemcommander/releases/tag/v0.1.9?x=1",
        "https://github.com/tandemcommander/tandemcommander/releases/tag/v0.1.9#frag",
        "https://github.com/Tandemcommander/tandemcommander/releases/tag/v0.1.9",
        "https://github.com.evil.example/tandemcommander/tandemcommander/releases/tag/v0.1.9",
        "https://github.com@evil.example/tandemcommander/tandemcommander/releases/tag/v0.1.9",
        " https://github.com/tandemcommander/tandemcommander/releases/tag/v0.1.9",
        "https://github.com/tandemcommander/tandemcommander/releases/tag/v0.1.9\\u0000",
        "https://github.com/tandemcommander/tandemcommander/releases/tag/v0.1.9\\ud83d",
        "javascript:alert(1)", "file:///C:/Windows/System32/calc.exe", ""};
    for (int i = 0; i < _countof(badNotes); i++)
        CHECK(UpdError123(UpdMakeRecord123(UPD_TAG_019, UPD_TIME_019, badNotes[i], UPD_NAME_019, "uploaded", UPD_URL_019)) == supeForeignNotes);

    static const char* badAssetUrls[] = {
        "https://evil.example/tandemcommander-0.1.9-x64-setup.exe",
        "http://github.com/tandemcommander/tandemcommander/releases/download/v0.1.9/tandemcommander-0.1.9-x64-setup.exe",
        "https://github.com/tandemcommander/tandemcommander/releases/download/v0.1.8/tandemcommander-0.1.9-x64-setup.exe",
        "https://github.com/tandemcommander/tandemcommander/releases/download/v0.1.9/tandemcommander-0.1.9-x64-setup.exe?x",
        "https://github.com/tandemcommander/tandemcommander/releases/download/v0.1.9/../../../../evil/x.exe",
        "https://github.com/other/tandemcommander/releases/download/v0.1.9/tandemcommander-0.1.9-x64-setup.exe",
        "https://GITHUB.com/tandemcommander/tandemcommander/releases/download/v0.1.9/tandemcommander-0.1.9-x64-setup.exe",
        "https://github.com/tandemcommander/tandemcommander/releases/download/v0.1.9/tandemcommander-0.1.9-x64-setup.exe ",
        "file:///C:/Windows/System32/calc.exe", "calc.exe", ""};
    for (int i = 0; i < _countof(badAssetUrls); i++)
        CHECK(UpdError123(UpdMakeRecord123(UPD_TAG_019, UPD_TIME_019, UPD_NOTES_019, UPD_NAME_019, "uploaded", badAssetUrls[i])) == supeNoInstaller);
    static const char* badAssetNames[] = {"tandemcommander-0.1.8-x64-setup.exe", "tandemcommander-0.1.9-x86-setup.exe", "setup.exe",
                                          "Tandemcommander-0.1.9-x64-setup.exe", "tandemcommander-0.1.9-x64-setup.exe.sig", ""};
    for (int i = 0; i < _countof(badAssetNames); i++)
        CHECK(UpdError123(UpdMakeRecord123(UPD_TAG_019, UPD_TIME_019, UPD_NOTES_019, badAssetNames[i], "uploaded", UPD_URL_019)) == supeNoInstaller);
    static const char* badStates[] = {"open", "new", "starter", "Uploaded", "uploaded ", ""};
    for (int i = 0; i < _countof(badStates); i++)
        CHECK(UpdError123(UpdMakeRecord123(UPD_TAG_019, UPD_TIME_019, UPD_NOTES_019, UPD_NAME_019, badStates[i], UPD_URL_019)) == supeNoInstaller);

    // duplicates of members the program reads
    CHECK(UpdError123(UpdMakeRecord123(UPD_TAG_019, UPD_TIME_019, UPD_NOTES_019, UPD_NAME_019, "uploaded", UPD_URL_019, "false", "false",
                                       "\"tag_name\":\"v0.1.9\",")) == supeDuplicate);
    CHECK(UpdError123(UpdMakeRecord123(UPD_TAG_019, UPD_TIME_019, UPD_NOTES_019, UPD_NAME_019, "uploaded", UPD_URL_019, "false", "false",
                                       "\"draft\":false,")) == supeDuplicate);
    CHECK(UpdError123(UpdMakeRecord123(UPD_TAG_019, UPD_TIME_019, UPD_NOTES_019, UPD_NAME_019, "uploaded", UPD_URL_019, "false", "false",
                                       "\"html_url\":\"" UPD_NOTES_019 "\",")) == supeDuplicate);
    CHECK(UpdError123(UpdMakeRecord123(UPD_TAG_019, UPD_TIME_019, UPD_NOTES_019, UPD_NAME_019, "uploaded", UPD_URL_019, "false", "false",
                                       "\"assets\":[],")) == supeDuplicate);
    // an escaped member name is the same member
    CHECK(UpdError123(UpdMakeRecord123(UPD_TAG_019, UPD_TIME_019, UPD_NOTES_019, UPD_NAME_019, "uploaded", UPD_URL_019, "false", "false",
                                       "\"tag\\u005fname\":\"v0.2.0\",")) == supeDuplicate);
    // inside an asset: a second state or address disqualifies that asset
    CHECK(UpdError123(UpdMakeRecord123(UPD_TAG_019, UPD_TIME_019, UPD_NOTES_019, UPD_NAME_019, "uploaded", UPD_URL_019, "false", "false", "",
                                       "\"state\":\"open\",")) == supeNoInstaller);
    CHECK(UpdError123(UpdMakeRecord123(UPD_TAG_019, UPD_TIME_019, UPD_NOTES_019, UPD_NAME_019, "uploaded", UPD_URL_019, "false", "false", "",
                                       "\"browser_download_url\":\"https://evil.example/x.exe\",")) == supeNoInstaller);

    // missing members and wrong shapes
    CHECK(UpdError123("{}") == supeMissingField);
    CHECK(UpdError123("{\"tag_name\":\"v0.1.9\"}") == supeMissingField);
    CHECK(UpdError123("[]") == supeNotJson);
    CHECK(UpdError123("\"v0.1.9\"") == supeNotJson);
    CHECK(UpdError123("null") == supeNotJson);
    CHECK(UpdError123("<html><body>Sign in to the hotel network</body></html>") == supeNotJson);
    CHECK(UpdError123("") == supeNotJson);
    CHECK(UpdError123(good + "x") == supeNotJson);
    CHECK(UpdError123(good + good) == supeNotJson);
    CHECK(UpdParses123(good + " \r\n"));
    CHECK(UpdParses123(std::string("\r\n ") + good));
    CHECK(UpdError123(std::string("\xEF\xBB\xBF") + good) == supeNotJson); // a byte-order mark is not JSON
    {
        // "assets" of another type, an empty list, a list of non-objects
        std::string a = good;
        size_t p = a.find("\"assets\":[");
        size_t q = a.find("],\"body\"");
        CHECK(p != std::string::npos && q != std::string::npos);
        if (p != std::string::npos && q != std::string::npos)
        {
            std::string head = a.substr(0, p), tail = a.substr(q + 1);
            CHECK(UpdError123(head + "\"assets\":[]" + tail) == supeNoInstaller);
            CHECK(UpdError123(head + "\"assets\":null" + tail) == supeNoInstaller);
            CHECK(UpdError123(head + "\"assets\":{}" + tail) == supeNoInstaller);
            CHECK(UpdError123(head + "\"assets\":\"" UPD_URL_019 "\"" + tail) == supeNoInstaller);
            CHECK(UpdError123(head + "\"assets\":[1,null,\"x\",[],{}]" + tail) == supeNoInstaller);
            // several assets: the installer among others is found, in any position
            std::string other = "{\"name\":\"notes.txt\",\"state\":\"uploaded\",\"browser_download_url\":\"https://github.com/tandemcommander/tandemcommander/releases/download/v0.1.9/notes.txt\"}";
            std::string inst = "{\"browser_download_url\":\"" UPD_URL_019 "\",\"state\":\"uploaded\",\"name\":\"" UPD_NAME_019 "\"}";
            CHECK(UpdParses123(head + "\"assets\":[" + other + "," + inst + "]" + tail));
            CHECK(UpdParses123(head + "\"assets\":[" + inst + "," + other + "]" + tail));
            CHECK(UpdError123(head + "\"assets\":[" + other + "," + other + "]" + tail) == supeNoInstaller);
            // the right name and the right address in two different assets are not an installer
            std::string half1 = "{\"name\":\"" UPD_NAME_019 "\",\"state\":\"uploaded\",\"browser_download_url\":\"https://evil.example/x.exe\"}";
            std::string half2 = "{\"name\":\"x.exe\",\"state\":\"uploaded\",\"browser_download_url\":\"" UPD_URL_019 "\"}";
            CHECK(UpdError123(head + "\"assets\":[" + half1 + "," + half2 + "]" + tail) == supeNoInstaller);
            // members nested one level deeper do not count
            CHECK(UpdError123(head + "\"assets\":[{\"uploader\":" + inst + "}]" + tail) == supeNoInstaller);
        }
    }
    // members of interest nested in another object are not the record's own
    CHECK(UpdError123("{\"release\":" + good + "}") == supeMissingField);
    // size limits
    {
        std::string big = good;
        big.insert(big.size() - 2, std::string(SALUPD_MAX_ANSWER, 'x'));
        CHECK(big.size() > SALUPD_MAX_ANSWER && UpdError123(big) == supeNotJson);
        std::string longTag = "v0.1.9" + std::string(SALUPD_MAX_STRING, '9');
        CHECK(UpdError123(UpdMakeRecord123(longTag.c_str(), UPD_TIME_019, UPD_NOTES_019, UPD_NAME_019, "uploaded", UPD_URL_019)) == supeBadTag);
        std::string longUrl = UPD_URL_019 + std::string(SALUPD_MAX_STRING, 'a');
        CHECK(UpdError123(UpdMakeRecord123(UPD_TAG_019, UPD_TIME_019, UPD_NOTES_019, UPD_NAME_019, "uploaded", longUrl.c_str())) == supeNoInstaller);
        CHECK(!SalUpdParseLatestRelease(good.c_str(), good.size(), NULL, &err));
        CHECK(!SalUpdParseLatestRelease(NULL, 10, &rel, &err));
    }

    // ---- cases named by the independent adversarial test (specs/123-.../probe/adversary)
    {
        // nesting at the level of the record: an ignored top-level member may nest 31 arrays, not 32
        for (int depth = 31; depth <= 32; depth++)
        {
            std::string extra = "\"x\":" + std::string(depth, '[') + std::string(depth, ']') + ",";
            std::string s = UpdMakeRecord123(UPD_TAG_019, UPD_TIME_019, UPD_NOTES_019, UPD_NAME_019, "uploaded", UPD_URL_019,
                                             "false", "false", extra.c_str());
            CHECK(UpdParses123(s) == (depth == 31));
        }
        // the size limit is exact
        for (int over = 0; over <= 1; over++)
        {
            std::string s = good;
            s.insert(s.size() - 1, std::string(SALUPD_MAX_ANSWER + over - good.size(), ' '));
            CHECK(s.size() == (size_t)SALUPD_MAX_ANSWER + over && UpdParses123(s) == (over == 0));
        }
        // "\/" is a legal way to write a slash; escaped member names are the members
        std::string esc = good;
        size_t pos;
        while ((pos = esc.find("https://")) != std::string::npos)
            esc.replace(pos, 8, "https:\\/\\/");
        CHECK(esc != good && UpdParses123(esc));
        std::string escName = good;
        pos = escName.find("\"state\"");
        CHECK(pos != std::string::npos);
        if (pos != std::string::npos)
        {
            escName.replace(pos, 7, "\"st\\u0061te\"");
            CHECK(UpdParses123(escName));
        }
        // an asset naming itself twice is not the installer, even with the right name both times
        CHECK(UpdError123(UpdMakeRecord123(UPD_TAG_019, UPD_TIME_019, UPD_NOTES_019, UPD_NAME_019, "uploaded", UPD_URL_019, "false", "false", "",
                                           "\"name\":\"" UPD_NAME_019 "\",")) == supeNoInstaller);
        // text that is not valid UTF-8 passes through skipped strings (documented in the header);
        // a member name that only resembles a read one is another member
        CHECK(UpdParses123(UpdMakeRecord123(UPD_TAG_019, UPD_TIME_019, UPD_NOTES_019, UPD_NAME_019, "uploaded", UPD_URL_019, "false", "false",
                                            "\"note\":\"\xFF\xC0\xAF\",")));
        CHECK(UpdParses123(UpdMakeRecord123(UPD_TAG_019, UPD_TIME_019, UPD_NOTES_019, UPD_NAME_019, "uploaded", UPD_URL_019, "false", "false",
                                            "\"tag_name\\u0000\":\"v9.9.9\",\"tag_names\":\"v9.9.9\",")));
        // white space that is not JSON's
        static const char* const notSpace[] = {"\f", "\v", "\xC2\xA0", "\xE2\x80\xA8"};
        for (int i = 0; i < _countof(notSpace); i++)
            CHECK(UpdError123(std::string("{") + notSpace[i] + good.substr(1)) == supeNotJson);
        // literals and numbers at their edges
        static const char* const badEdge[] = {"{\"a\":truex}", "{\"a\":nullnull}", "{\"a\":false false}", "{\"a\":-}", "{\"a\":-01}",
                                              "{\"a\":00}", "{\"a\":1e+}", "{\"a\":\"\\u00G1\"}", "{\"a\":\"\\u00:1\"}", "{\"a\":\"\\u00/1\"}"};
        for (int i = 0; i < _countof(badEdge); i++)
        {
            CSalUpdJsonReader r(badEdge[i], strlen(badEdge[i]));
            CHECK(!(r.SkipValue(1) && r.AtEnd()));
        }
        static const char* const goodEdge[] = {"{\"a\":-0}", "{\"a\":0e0}", "{\"a\":1e400}", "{\"a\":\"\\uAbCd\"}", "{\"a\":\"\x7F\"}"};
        for (int i = 0; i < _countof(goodEdge); i++)
        {
            CSalUpdJsonReader r(goodEdge[i], strlen(goodEdge[i]));
            CHECK(r.SkipValue(1) && r.AtEnd());
        }
        // an extracted string holds SALUPD_MAX_STRING - 1 bytes
        for (int n = SALUPD_MAX_STRING - 1; n <= SALUPD_MAX_STRING; n++)
        {
            std::string s = "\"" + std::string(n, 'a') + "\"";
            char out[SALUPD_MAX_STRING];
            BOOL bad;
            CSalUpdJsonReader r(s.c_str(), s.size());
            CHECK(r.ReadString(out, sizeof(out), &bad) && bad == (n == SALUPD_MAX_STRING));
        }
        // time at the ends of the range
        ULONGLONG t0;
        CHECK(SalUpdParseUtcTime("1601-01-01T00:00:00Z", -1, &t0) && t0 == 0);
        CHECK(SalUpdParseUtcTime("9999-12-31T23:59:59Z", -1, &t0) && t0 == 2650467743990000000ULL);
        CHECK(SalUpdParseUtcTime("2400-02-29T00:00:00Z", -1, &t0) && !SalUpdParseUtcTime("1900-02-29T00:00:00Z", -1, &t0));
        CHECK(!SalUpdParseUtcTime("2026-09-20T14:34:53Z", 19, &t0) && !SalUpdParseUtcTime("2026-09-20T14:34:53ZZ", 21, &t0));
        CHECK(!SalUpdStatusWantsBody(403, NULL)); // no result wanted: must not fault
        CHECK(SalUpdAutoCheckDue(TRUE, TRUE, 0xFFFFFFFFFFFFFFFFULL, TRUE, 0x8000000000000000ULL)); // a time far in the future
        CHECK(!SalUpdAutoCheckDue(TRUE, TRUE, 0xFFFFFFFFFFFFFFFFULL, TRUE, 0xFFFFFFFFFFFFFFFFULL));
        // the seam's port has no leading zero
        int port123 = 0;
        WCHAR path123[20];
        CHECK(!SalUpdParseLoopbackUrl(L"http://127.0.0.1:00080/x", &port123, path123, _countof(path123)));
        CHECK(!SalUpdParseLoopbackUrl(L"http://127.0.0.1:80/x", &port123, path123, 0) &&
              !SalUpdParseLoopbackUrl(L"http://127.0.0.1:80/x", &port123, path123, 1) &&
              !SalUpdParseLoopbackUrl(L"http://127.0.0.1:80/x", NULL, path123, _countof(path123)));
    }

    // ---- HTTP status classes
    CSalUpdResult res = surCancelled;
    CHECK(SalUpdStatusWantsBody(200, &res) && res == surCancelled);
    CHECK(!SalUpdStatusWantsBody(403, &res) && res == surRefused);
    CHECK(!SalUpdStatusWantsBody(429, &res) && res == surRefused);
    static const DWORD otherStatus[] = {0, 100, 201, 204, 206, 301, 302, 304, 307, 400, 401, 404, 407, 418, 500, 502, 503, 999};
    for (int i = 0; i < _countof(otherStatus); i++)
    {
        res = surCancelled;
        CHECK(!SalUpdStatusWantsBody(otherStatus[i], &res) && res == surUnexpected);
    }
    CHECK(SalUpdResultIsKnowledge(surNewer) && SalUpdResultIsKnowledge(surUpToDate) && !SalUpdResultIsKnowledge(surUnreachable) &&
          !SalUpdResultIsKnowledge(surRefused) && !SalUpdResultIsKnowledge(surUnexpected) && !SalUpdResultIsKnowledge(surCancelled));
    CHECK(SalUpdResultWasAnswered(surNewer) && SalUpdResultWasAnswered(surUpToDate) && SalUpdResultWasAnswered(surRefused) &&
          SalUpdResultWasAnswered(surUnexpected) && !SalUpdResultWasAnswered(surUnreachable) && !SalUpdResultWasAnswered(surCancelled));

    // ---- is an automatic check due?
    {
        const ULONGLONG now = 134000000000000000ULL;
        const ULONGLONG h = SALUPD_HOUR;
        CHECK(!SalUpdAutoCheckDue(FALSE, FALSE, 0, FALSE, now)); // option off: never
        CHECK(!SalUpdAutoCheckDue(FALSE, TRUE, now - 1000 * h, TRUE, now));
        CHECK(SalUpdAutoCheckDue(TRUE, FALSE, 0, FALSE, now));      // never tried
        CHECK(SalUpdAutoCheckDue(TRUE, FALSE, now + h, TRUE, now)); // "no attempt" wins over the stale time
        CHECK(!SalUpdAutoCheckDue(TRUE, TRUE, now, TRUE, now));     // just now
        CHECK(!SalUpdAutoCheckDue(TRUE, TRUE, now - 24 * h + 1, TRUE, now));
        CHECK(SalUpdAutoCheckDue(TRUE, TRUE, now - 24 * h, TRUE, now)); // exactly 24 hours
        CHECK(SalUpdAutoCheckDue(TRUE, TRUE, now - 25 * h, TRUE, now));
        CHECK(!SalUpdAutoCheckDue(TRUE, TRUE, now - h + 1, FALSE, now)); // not reached: one hour
        CHECK(SalUpdAutoCheckDue(TRUE, TRUE, now - h, FALSE, now));
        CHECK(!SalUpdAutoCheckDue(TRUE, TRUE, now - 23 * h, TRUE, now)); // answered: the hour rule does not apply
        CHECK(SalUpdAutoCheckDue(TRUE, TRUE, now + 1, TRUE, now));       // a time in the future is ignored
        CHECK(SalUpdAutoCheckDue(TRUE, TRUE, now + 8760 * h, FALSE, now));
        CHECK(SalUpdAutoCheckDue(TRUE, TRUE, 0, TRUE, now)); // a zero time is just very old
        CHECK(!SalUpdAutoCheckDue(TRUE, TRUE, 0, TRUE, 0));
    }

    // ---- the start-up notification and the About dialog's state
    {
        CSalUpdVersion v018 = {0, 1, 8}, v020 = {0, 2, 0}, none = {0, 0, 0};
        CHECK(SalUpdStartupNoticeWanted(surNewer, v019, FALSE, none));
        CHECK(!SalUpdStartupNoticeWanted(surNewer, v019, TRUE, v019)); // skipped
        CHECK(SalUpdStartupNoticeWanted(surNewer, v020, TRUE, v019));  // a newer one than the skipped
        CHECK(SalUpdStartupNoticeWanted(surNewer, v019, TRUE, v018));  // an older skipped version does not matter
        CHECK(SalUpdStartupNoticeWanted(surNewer, v019, TRUE, v020));  // only the exact version is skipped
        CHECK(!SalUpdStartupNoticeWanted(surUpToDate, v019, FALSE, none));
        CHECK(!SalUpdStartupNoticeWanted(surUnreachable, v019, FALSE, none));
        CHECK(!SalUpdStartupNoticeWanted(surRefused, v019, FALSE, none));
        CHECK(!SalUpdStartupNoticeWanted(surUnexpected, v019, FALSE, none));
        CHECK(!SalUpdStartupNoticeWanted(surCancelled, v019, FALSE, none));
        CHECK(SalUpdKnownState(FALSE, v019, v018) == suksNotChecked);
        CHECK(SalUpdKnownState(TRUE, v019, v018) == suksNewer);
        CHECK(SalUpdKnownState(TRUE, v018, v018) == suksUpToDate);
        CHECK(SalUpdKnownState(TRUE, v019, v019) == suksUpToDate); // after the user installed the newer version
        CHECK(SalUpdKnownState(TRUE, v019, v020) == suksUpToDate);
    }

    // ---- the Debug-only seam accepts the loopback address and nothing else
    {
        int port = 0;
        WCHAR path[100];
        CHECK(SalUpdParseLoopbackUrl(L"http://127.0.0.1:8123/latest/newer", &port, path, _countof(path)) && port == 8123 &&
              wcscmp(path, L"/latest/newer") == 0);
        CHECK(SalUpdParseLoopbackUrl(L"http://127.0.0.1:1/", &port, path, _countof(path)) && port == 1 && wcscmp(path, L"/") == 0);
        CHECK(SalUpdParseLoopbackUrl(L"http://127.0.0.1:65535/a?b=c", &port, path, _countof(path)) && port == 65535);
        static const WCHAR* badUrls[] = {
            L"", L"https://127.0.0.1:8123/x", L"http://localhost:8123/x", L"http://127.0.0.2:8123/x", L"http://127.0.0.1/x",
            L"http://127.0.0.1:/x", L"http://127.0.0.1:0/x", L"http://127.0.0.1:65536/x", L"http://127.0.0.1:123456/x",
            L"http://127.0.0.1:8123", L"http://127.0.0.1:8123x/y", L"http://127.0.0.1:8123@evil.example/x",
            L"http://127.0.0.1.evil.example:8123/x", L"http://evil.example/http://127.0.0.1:8123/x", L" http://127.0.0.1:8123/x",
            L"HTTP://127.0.0.1:8123/x", L"http://127.0.0.1:8123/a b", L"http://127.0.0.1:8123/a\r\nHost: evil", L"http://127.0.0.1:8123/a#b",
            L"http://127.0.0.1:8123/\x010D", L"http://[::1]:8123/x", L"http://0x7f.0.0.1:8123/x", L"file:///c:/x"};
        for (int i = 0; i < _countof(badUrls); i++)
            CHECK(!SalUpdParseLoopbackUrl(badUrls[i], &port, path, _countof(path)));
        CHECK(!SalUpdParseLoopbackUrl(L"http://127.0.0.1:8123/latest/newer", &port, path, 13)); // the path needs 13 units + zero
        CHECK(SalUpdParseLoopbackUrl(L"http://127.0.0.1:8123/latest/newer", &port, path, 14));
        CHECK(!SalUpdParseLoopbackUrl(NULL, &port, path, _countof(path)));
    }
    CHECK(strcmp(SalUpdResultName(surRefused), "refused") == 0);

    // ---- the long date without the day of the week
    {
        static const WCHAR* const pictures[][2] = {
            {L"dddd, MMMM d, yyyy", L"MMMM d, yyyy"},            // en-US
            {L"dddd d. MMMM yyyy", L"d. MMMM yyyy"},              // cs-CZ
            {L"dddd, d. MMMM yyyy", L"d. MMMM yyyy"},             // de-DE
            {L"dddd d MMMM yyyy", L"d MMMM yyyy"},                // fr-FR, nl-NL
            {L"dddd, d' de 'MMMM' de 'yyyy", L"d' de 'MMMM' de 'yyyy"}, // es-ES
            {L"yyyy. MMMM d., dddd", L"yyyy. MMMM d."},           // hu-HU: the name stands last
            {L"d MMMM yyyy", L"d MMMM yyyy"},                     // nothing to remove
            {L"dd MMMM yyyy", L"dd MMMM yyyy"},
            {L"ddd, d MMM yyyy", L"d MMM yyyy"},                  // the short name too
            {L"d MMMM yyyy 'dddd'", L"d MMMM yyyy 'dddd'"},       // quoted text is literal
            {L"dddd', 'MMMM d'. b. 'yyyy", L"MMMM d'. b. 'yyyy"},  // se-FI: the separator is a quoted literal
            {L"dddd'x'MMMM", L"'x'MMMM"},                           // a literal that is not a separator stays
            {L"dddd", L""},
            {L"dddd, ", L""},
            {L"", L""},
            {L"yyyy'\x5E74'M'\x6708'd'\x65E5' dddd", L"yyyy'\x5E74'M'\x6708'd'\x65E5'"}, // zh-CN shape
        };
        for (int i = 0; i < _countof(pictures); i++)
        {
            WCHAR pic[100];
            lstrcpynW(pic, pictures[i][0], _countof(pic));
            SalUpdStripWeekday(pic);
            CHECK(wcscmp(pic, pictures[i][1]) == 0);
        }
        SalUpdStripWeekday(NULL); // must not fault
    }
}

// feature 125 (GitHub #5): a UNC path with a server and no share - the rules of saluncserver.h
static void TestUncServer125()
{
    char server[40];

    // --- SalUncServerOfPath: "server only" ---
    CHECK(SalUncServerOfPath("\\\\server", server, sizeof(server)) && strcmp(server, "server") == 0);
    CHECK(SalUncServerOfPath("\\\\server\\", server, sizeof(server)) && strcmp(server, "server") == 0);
    CHECK(SalUncServerOfPath("\\\\192.168.1.10\\", server, sizeof(server)) && strcmp(server, "192.168.1.10") == 0);
    CHECK(SalUncServerOfPath("\\\\fs01.corp.example.com", server, sizeof(server)) && strcmp(server, "fs01.corp.example.com") == 0);
    CHECK(SalUncServerOfPath("\\\\a", server, sizeof(server)) && strcmp(server, "a") == 0);
    // a server name with letters outside ASCII (UTF-8: s-caron, e-acute)
    CHECK(SalUncServerOfPath("\\\\\xC5\xA1kola-\xC3\xA9\\", server, sizeof(server)) && strcmp(server, "\xC5\xA1kola-\xC3\xA9") == 0);
    // not "server only"
    CHECK(!SalUncServerOfPath("\\\\", server, sizeof(server)) && server[0] == 0);
    CHECK(!SalUncServerOfPath("\\\\\\", server, sizeof(server)));
    CHECK(!SalUncServerOfPath("\\\\server\\share", server, sizeof(server)) && server[0] == 0);
    CHECK(!SalUncServerOfPath("\\\\server\\share\\", server, sizeof(server)));
    CHECK(!SalUncServerOfPath("\\\\server\\share\\dir", server, sizeof(server)));
    CHECK(!SalUncServerOfPath("\\\\server\\\\", server, sizeof(server))); // an empty share part is not "no share part"
    CHECK(!SalUncServerOfPath("\\\\.", server, sizeof(server)));
    CHECK(!SalUncServerOfPath("\\\\.\\", server, sizeof(server)));
    CHECK(!SalUncServerOfPath("\\\\?", server, sizeof(server)));
    CHECK(!SalUncServerOfPath("\\\\?\\", server, sizeof(server)));
    CHECK(!SalUncServerOfPath("\\\\?\\C:\\", server, sizeof(server)));
    CHECK(!SalUncServerOfPath("\\\\.\\PhysicalDrive0", server, sizeof(server)));
    CHECK(!SalUncServerOfPath("C:\\", server, sizeof(server)));
    CHECK(!SalUncServerOfPath("\\server", server, sizeof(server)));
    CHECK(!SalUncServerOfPath("server", server, sizeof(server)));
    CHECK(!SalUncServerOfPath("", server, sizeof(server)));
    CHECK(!SalUncServerOfPath(NULL, server, sizeof(server)));
    CHECK(!SalUncServerOfPath("//server/", server, sizeof(server))); // the caller normalises slashes first
    // names that only start with a device character are servers
    CHECK(SalUncServerOfPath("\\\\.x", server, sizeof(server)) && strcmp(server, ".x") == 0);
    CHECK(SalUncServerOfPath("\\\\?x\\", server, sizeof(server)) && strcmp(server, "?x") == 0);
    // the buffer: fits exactly / one byte short = refused, never cut
    {
        char tiny[7];
        CHECK(SalUncServerOfPath("\\\\server", tiny, 7) && strcmp(tiny, "server") == 0);
        memset(tiny, 'X', sizeof(tiny));
        CHECK(!SalUncServerOfPath("\\\\server", tiny, 6) && tiny[0] == 0);
        CHECK(!SalUncServerOfPath("\\\\server", NULL, 0));
        CHECK(!SalUncServerOfPath("\\\\server", tiny, 0));
    }

    // --- SalUncShareOffered: folder shares only ---
    CHECK(SalUncShareOffered(0x00000000));  // STYPE_DISKTREE
    CHECK(SalUncShareOffered(0x80000000));  // a special folder share (C$, ADMIN$)
    CHECK(SalUncShareOffered(0x40000000));  // a temporary folder share
    CHECK(!SalUncShareOffered(0x00000001)); // STYPE_PRINTQ
    CHECK(!SalUncShareOffered(0x00000002)); // STYPE_DEVICE
    CHECK(!SalUncShareOffered(0x00000003)); // STYPE_IPC
    CHECK(!SalUncShareOffered(0x80000003)); // IPC$
    CHECK(!SalUncShareOffered(0x80000001));

    // --- SalUncShareHidden ---
    CHECK(SalUncShareHidden("C$", 0x80000000));
    CHECK(SalUncShareHidden("ADMIN$", 0x80000000));
    CHECK(SalUncShareHidden("secret$", 0));
    CHECK(SalUncShareHidden("plain", 0x80000000)); // special without a dollar
    CHECK(!SalUncShareHidden("DATA", 0));
    CHECK(!SalUncShareHidden("pri$ce", 0));
    CHECK(!SalUncShareHidden("$start", 0));
    CHECK(!SalUncShareHidden("", 0));
    CHECK(!SalUncShareHidden(NULL, 0));
    CHECK(SalUncShareHidden("$", 0));

    // --- SalUncShareCompare: visible first, then the file system's order ---
    CHECK(SalUncShareCompare("zzz", FALSE, "AAA$", TRUE) < 0);
    CHECK(SalUncShareCompare("AAA$", TRUE, "zzz", FALSE) > 0);
    CHECK(SalUncShareCompare("apps", FALSE, "DATA", FALSE) < 0);
    CHECK(SalUncShareCompare("DATA", FALSE, "apps", FALSE) > 0);
    CHECK(SalUncShareCompare("Home", FALSE, "HOME", FALSE) == 0);
    CHECK(SalUncShareCompare("C$", TRUE, "D$", TRUE) < 0);
    CHECK(SalUncShareCompare("ADMIN$", TRUE, "C$", TRUE) < 0);
    // c-caron in both cases is one name (the code page tables did not know that)
    CHECK(SalUncShareCompare("\xC4\x8Ctvrt", FALSE, "\xC4\x8Dtvrt", FALSE) == 0);
    CHECK(SalUncShareCompare("abc", FALSE, "abc", TRUE) < 0);
    {
        // a whole list as the worker sorts it
        struct
        {
            const char* Name;
            DWORD Type;
        } in[] = {{"IPC$", 0x80000003}, {"D$", 0x80000000}, {"NETLOGON", 0}, {"apps", 0}, {"ADMIN$", 0x80000000}, {"HP LaserJet", 1}, {"Home", 0}, {"C$", 0x80000000}, {"DATA", 0}, {"archiv$", 0}};
        const char* names[10];
        BOOL hidden[10];
        int n = 0;
        for (int i = 0; i < 10; i++)
        {
            if (!SalUncShareOffered(in[i].Type))
                continue;
            names[n] = in[i].Name;
            hidden[n] = SalUncShareHidden(in[i].Name, in[i].Type);
            n++;
        }
        CHECK(n == 8);
        for (int i = 0; i < n; i++)
            for (int j = i + 1; j < n; j++)
                if (SalUncShareCompare(names[i], hidden[i], names[j], hidden[j]) > 0)
                {
                    std::swap(names[i], names[j]);
                    std::swap(hidden[i], hidden[j]);
                }
        const char* want[8] = {"apps", "DATA", "Home", "NETLOGON", "ADMIN$", "archiv$", "C$", "D$"};
        for (int i = 0; i < 8; i++)
            CHECK(strcmp(names[i], want[i]) == 0);
        CHECK(!hidden[3] && hidden[4]);
    }

    // --- SalUncBuildSharePath: whole or refused ---
    {
        char buf[32];
        CHECK(SalUncBuildSharePath("server", "DATA", buf, sizeof(buf)) && strcmp(buf, "\\\\server\\DATA") == 0);
        CHECK(SalUncBuildSharePath("s", "C$", buf, sizeof(buf)) && strcmp(buf, "\\\\s\\C$") == 0);
        CHECK(SalUncBuildSharePath("server", "My Share & more", buf, sizeof(buf)) && strcmp(buf, "\\\\server\\My Share & more") == 0);
        // "\\server\DATA" is 13 bytes + terminator
        char tight[14];
        CHECK(SalUncBuildSharePath("server", "DATA", tight, 14) && strcmp(tight, "\\\\server\\DATA") == 0);
        memset(tight, 'X', sizeof(tight));
        CHECK(!SalUncBuildSharePath("server", "DATA", tight, 13) && tight[0] == 0);
        CHECK(!SalUncBuildSharePath("server", "DATA", tight, 1) && tight[0] == 0);
        CHECK(!SalUncBuildSharePath("server", "DATA", NULL, 0));
        CHECK(!SalUncBuildSharePath("", "DATA", buf, sizeof(buf)) && buf[0] == 0);
        CHECK(!SalUncBuildSharePath("server", "", buf, sizeof(buf)));
        CHECK(!SalUncBuildSharePath(NULL, "DATA", buf, sizeof(buf)));
        CHECK(!SalUncBuildSharePath("server", NULL, buf, sizeof(buf)));
        CHECK(!SalUncBuildSharePath("ser\\ver", "DATA", buf, sizeof(buf)));
        CHECK(!SalUncBuildSharePath("server", "DA\\TA", buf, sizeof(buf)));
        // a slash is a separator for the path code too: "a/b" would open "\\server\a\b"
        CHECK(!SalUncBuildSharePath("server", "a/b", buf, sizeof(buf)) && buf[0] == 0);
        CHECK(!SalUncBuildSharePath("server", "/", buf, sizeof(buf)) && buf[0] == 0);
        CHECK(!SalUncBuildSharePath("ser/ver", "DATA", buf, sizeof(buf)) && buf[0] == 0);
        // ... and such a name is not offered at all
        CHECK(SalUncShareNameUsable("DATA") && SalUncShareNameUsable("C$") && SalUncShareNameUsable("R&D") && SalUncShareNameUsable(".a"));
        CHECK(!SalUncShareNameUsable(".") && !SalUncShareNameUsable("..")); // the path code resolves them away
        CHECK(SalUncShareNameUsable("\xC3\x9A\xC4\x8D""etnictv\xC3\xAD"));
        CHECK(!SalUncShareNameUsable("a/b") && !SalUncShareNameUsable("a\\b") && !SalUncShareNameUsable("/") && !SalUncShareNameUsable("\\"));
        CHECK(!SalUncShareNameUsable("") && !SalUncShareNameUsable(NULL));
        // 80 three-byte letters (the longest share name Windows allows, in a non-Latin script)
        char share[241];
        for (int i = 0; i < 80; i++)
            memcpy(share + 3 * i, "\xE4\xB8\xAD", 3);
        share[240] = 0;
        char big[260];
        CHECK(SalUncBuildSharePath("server", share, big, sizeof(big)) && strlen(big) == 2 + 6 + 1 + 240 && strcmp(big + 9, share) == 0);
        char notEnough[249];
        CHECK(!SalUncBuildSharePath("server", share, notEnough, sizeof(notEnough)) && notEnough[0] == 0);
        // what it builds is not "server only" any more, and the server of "\\server\" comes back
        CHECK(SalUncBuildSharePath("server", "DATA", buf, sizeof(buf)) && !SalUncServerOfPath(buf, server, sizeof(server)));
    }

    // --- SalUncMenuText: '&' doubled, whole or refused ---
    {
        char buf[16];
        CHECK(SalUncMenuText("DATA", buf, sizeof(buf)) && strcmp(buf, "DATA") == 0);
        CHECK(SalUncMenuText("R&D", buf, sizeof(buf)) && strcmp(buf, "R&&D") == 0);
        CHECK(SalUncMenuText("&&", buf, sizeof(buf)) && strcmp(buf, "&&&&") == 0);
        CHECK(SalUncMenuText("", buf, sizeof(buf)) && buf[0] == 0);
        CHECK(!SalUncMenuText(NULL, buf, sizeof(buf)));
        CHECK(SalUncMenuText("123456789012345", buf, sizeof(buf)) && strlen(buf) == 15);
        memset(buf, 'X', sizeof(buf));
        CHECK(!SalUncMenuText("1234567890123456", buf, sizeof(buf)) && buf[0] == 0);
        CHECK(!SalUncMenuText("12345678901234&", buf, sizeof(buf)) && buf[0] == 0); // the doubled '&' does not fit
        CHECK(SalUncMenuText("1234567890123&", buf, sizeof(buf)) && strcmp(buf, "1234567890123&&") == 0);
        CHECK(!SalUncMenuText("x", buf, 0));
    }
}

// feature 126 (GitHub #6): the package lookup of the command-shell presets takes its two
// kernel32 functions as a table - absent on Windows 7 / 8.0, where the answer is "not found"
namespace Pkg126
{
static int ListCalls, PathCalls;       // how often the fakes were called
static LONG ListSizeAnswer;            // answer of the sizing call (normally ERROR_INSUFFICIENT_BUFFER)
static LONG ListFillAnswer;            // answer of the filling call
static UINT32 ListCount;               // packages reported
static LONG PathSizeAnswer, PathFillAnswer;
static const WCHAR* PkgFullName = L"Vendor.Shell_1.2.3.0_x64__abcdefgh12345";
static const WCHAR* PkgFolder = L"C:\\Program Files\\WindowsApps\\Vendor.Shell_1.2.3.0_x64__abcdefgh12345";
static WCHAR SeenFamily[300];
static WCHAR SeenFullName[300];

static void Reset()
{
    ListCalls = PathCalls = 0;
    ListSizeAnswer = ERROR_INSUFFICIENT_BUFFER;
    ListFillAnswer = ERROR_SUCCESS;
    ListCount = 1;
    PathSizeAnswer = ERROR_INSUFFICIENT_BUFFER;
    PathFillAnswer = ERROR_SUCCESS;
    SeenFamily[0] = SeenFullName[0] = 0;
    PkgFolder = L"C:\\Program Files\\WindowsApps\\Vendor.Shell_1.2.3.0_x64__abcdefgh12345";
}

static LONG WINAPI FakeList(PCWSTR family, UINT32* count, PWSTR* names, UINT32* bufferLength, WCHAR* buffer)
{
    ListCalls++;
    wcsncpy_s(SeenFamily, family, _TRUNCATE);
    UINT32 need = (UINT32)wcslen(PkgFullName) + 1;
    if (names == NULL || buffer == NULL)
    {
        *count = ListCount;
        *bufferLength = ListCount == 0 ? 0 : need;
        return ListSizeAnswer;
    }
    if (ListFillAnswer != ERROR_SUCCESS)
        return ListFillAnswer;
    if (*count < 1 || *bufferLength < need)
        return ERROR_INSUFFICIENT_BUFFER;
    wcscpy_s(buffer, *bufferLength, PkgFullName);
    names[0] = buffer;
    *count = 1;
    return ERROR_SUCCESS;
}

static LONG WINAPI FakePath(PCWSTR fullName, UINT32* pathLength, PWSTR path)
{
    PathCalls++;
    wcsncpy_s(SeenFullName, fullName, _TRUNCATE);
    UINT32 need = (UINT32)wcslen(PkgFolder) + 1;
    if (path == NULL)
    {
        *pathLength = need;
        return PathSizeAnswer;
    }
    if (PathFillAnswer != ERROR_SUCCESS)
        return PathFillAnswer;
    if (*pathLength < need)
        return ERROR_INSUFFICIENT_BUFFER;
    wcscpy_s(path, *pathLength, PkgFolder);
    return ERROR_SUCCESS;
}
} // namespace Pkg126

static void TestPackageApi126()
{
    using namespace Pkg126;
    char buf[600];
    const char* family = "Vendor.Shell_abcdefgh12345";
    const char* folderU8 = "C:\\Program Files\\WindowsApps\\Vendor.Shell_1.2.3.0_x64__abcdefgh12345";

    // --- the functions are absent (Windows 7, Server 2008 R2): "not found", the buffer emptied ---
    {
        memset(buf, 'X', sizeof(buf));
        CHECK(!SalShellPackagePath(NULL, family, buf, sizeof(buf)) && buf[0] == 0);
        CSalShellPackageApi none = {NULL, NULL};
        memset(buf, 'X', sizeof(buf));
        CHECK(!SalShellPackagePath(&none, family, buf, sizeof(buf)) && buf[0] == 0);
        // Windows 8.0: the list function exists, the path function does not - still "not found",
        // and the function that exists is not even called
        Reset();
        CSalShellPackageApi only8 = {FakeList, NULL};
        memset(buf, 'X', sizeof(buf));
        CHECK(!SalShellPackagePath(&only8, family, buf, sizeof(buf)) && buf[0] == 0 && ListCalls == 0);
        CSalShellPackageApi onlyPath = {NULL, FakePath};
        memset(buf, 'X', sizeof(buf));
        CHECK(!SalShellPackagePath(&onlyPath, family, buf, sizeof(buf)) && buf[0] == 0 && PathCalls == 0);
    }

    CSalShellPackageApi api = {FakeList, FakePath};

    // --- the functions are present: the folder of the first package ---
    {
        Reset();
        memset(buf, 'X', sizeof(buf));
        CHECK(SalShellPackagePath(&api, family, buf, sizeof(buf)) && strcmp(buf, folderU8) == 0);
        CHECK(ListCalls == 2 && PathCalls == 2);
        CHECK(wcscmp(SeenFamily, L"Vendor.Shell_abcdefgh12345") == 0);
        CHECK(wcscmp(SeenFullName, PkgFullName) == 0);
        // a folder with letters outside ASCII comes back as UTF-8
        Reset();
        PkgFolder = L"C:\\Aplikace\\\x0160koln\x00ED \x4E2D";
        CHECK(SalShellPackagePath(&api, family, buf, sizeof(buf)) && strcmp(buf, "C:\\Aplikace\\\xC5\xA0koln\xC3\xAD \xE4\xB8\xAD") == 0);
    }

    // --- every way the system can say no ---
    {
        auto fresh = [&buf]() { Reset(); memset(buf, 'X', sizeof(buf)); }; // every row starts from a dirty buffer
        fresh();
        ListCount = 0; // the family has no package
        CHECK(!SalShellPackagePath(&api, family, buf, sizeof(buf)) && buf[0] == 0 && PathCalls == 0);
        fresh();
        ListSizeAnswer = ERROR_SUCCESS; // "no buffer needed" = nothing there
        CHECK(!SalShellPackagePath(&api, family, buf, sizeof(buf)) && buf[0] == 0 && PathCalls == 0);
        fresh();
        ListSizeAnswer = ERROR_INVALID_PARAMETER;
        CHECK(!SalShellPackagePath(&api, family, buf, sizeof(buf)) && buf[0] == 0 && ListCalls == 1);
        fresh();
        ListFillAnswer = ERROR_ACCESS_DENIED;
        CHECK(!SalShellPackagePath(&api, family, buf, sizeof(buf)) && buf[0] == 0 && PathCalls == 0);
        fresh();
        PathSizeAnswer = ERROR_NOT_FOUND;
        CHECK(!SalShellPackagePath(&api, family, buf, sizeof(buf)) && buf[0] == 0 && PathCalls == 1);
        fresh();
        PathFillAnswer = ERROR_ACCESS_DENIED;
        CHECK(!SalShellPackagePath(&api, family, buf, sizeof(buf)) && buf[0] == 0 && PathCalls == 2);
    }

    // --- the caller's buffer: fits exactly / one byte short = refused, never cut ---
    {
        Reset();
        size_t need = strlen(folderU8) + 1;
        char* exact = (char*)malloc(need);
        CHECK(exact != NULL && SalShellPackagePath(&api, family, exact, (int)need) && strcmp(exact, folderU8) == 0);
        memset(exact, 'X', need);
        CHECK(!SalShellPackagePath(&api, family, exact, (int)need - 1) && exact[0] == 0);
        free(exact);
        char one[1] = {'X'};
        CHECK(!SalShellPackagePath(&api, family, one, 1) && one[0] == 0);
        CHECK(!SalShellPackagePath(&api, family, NULL, 100));
        CHECK(!SalShellPackagePath(&api, family, buf, 0));
        CHECK(!SalShellPackagePath(&api, NULL, buf, sizeof(buf)) && buf[0] == 0);
        // a family name that does not fit the lookup's own buffer is refused before any call
        Reset();
        std::string longFamily(300, 'f');
        CHECK(!SalShellPackagePath(&api, longFamily.c_str(), buf, sizeof(buf)) && buf[0] == 0 && ListCalls == 0);
    }

    // --- the real system (the tests run on a supported Windows): both functions resolve, and a
    //     family that cannot exist is "not found" through the real functions and the real probe ---
    {
        CSalShellPackageApi real = {NULL, NULL};
        CHECK(SalShellResolvePackageApi(&real)); // (saltests is a developer tool run on a supported Windows)
        CHECK(real.GetPackagesByPackageFamily != NULL && real.GetPackagePathByFullName != NULL);
        CHECK(!SalShellResolvePackageApi(NULL));
        memset(buf, 'X', sizeof(buf));
        CHECK(!SalShellPackagePath(&real, "TandemCommander.NoSuchFamily126_0000000000000", buf, sizeof(buf)) && buf[0] == 0);
        CSalShellOsProbe os;
        memset(buf, 'X', sizeof(buf));
        CHECK(!os.GetPackagePath("TandemCommander.NoSuchFamily126_0000000000000", buf, sizeof(buf)) && buf[0] == 0);
    }
}

// feature 127 (GitHub #7): the numbered inserts of the archivers' messages (salinserts.h) -
// the expansion FormatMessage did, on bytes, so UTF-8 stays UTF-8 and nothing is cut
static void TestInserts127()
{
    CHECK(SalInsertsCount(NULL) == 0);
    CHECK(SalInsertsCount("") == 0);
    CHECK(SalInsertsCount("no inserts") == 0);
    CHECK(SalInsertsCount("System error: %1") == 1);
    CHECK(SalInsertsCount("(%1) to (%2).") == 2);
    CHECK(SalInsertsCount("%2 only") == 2);
    CHECK(SalInsertsCount("100%% of %1") == 1);
    CHECK(SalInsertsCount("%%1") == 0); // a percent sign and the digit one
    CHECK(SalInsertsCount("%9%3") == 9);
    CHECK(SalInsertsCount("%0") == 0);
    CHECK(SalInsertsCount("ends with %") == 0);

    struct
    {
        const char* tmpl;
        int count;
        const char* a;
        const char* b;
        const char* want;
    } cases[] = {
        {"System error: %1", 1, "x", NULL, "System error: x"},
        {"Unable to start the archiver \"%1\". The error was: %2", 2, "C:\\a\\b.exe", "(2) Not found.", "Unable to start the archiver \"C:\\a\\b.exe\". The error was: (2) Not found."},
        // Czech template and inserts, UTF-8 bytes go through untouched
        {"Nelze spustit archiva\xC4\x8Dn\xC3\xAD program \xE2\x80\x9E%1\xE2\x80\x9C. Chyba: %2", 2, "C:\\N\xC3\xA1stroje\\\xC5\xBElu\xC5\xA5.exe", "(5) P\xC5\x99\xC3\xADstup byl odep\xC5\x99""en.",
         "Nelze spustit archiva\xC4\x8Dn\xC3\xAD program \xE2\x80\x9E""C:\\N\xC3\xA1stroje\\\xC5\xBElu\xC5\xA5.exe\xE2\x80\x9C. Chyba: (5) P\xC5\x99\xC3\xADstup byl odep\xC5\x99""en."},
        {"%2 before %1", 2, "one", "two", "two before one"},
        {"%1 and %1 and %1", 1, "long insert used three times", NULL, "long insert used three times and long insert used three times and long insert used three times"},
        {"100%% of %1%nnext", 1, "it", NULL, "100% of it\nnext"},
        {"%1%2", 2, "", "", ""},
        {"%1", 1, NULL, NULL, ""},              // a missing insert gives nothing
        {"[%2]", 1, "a", "b", "[]"},            // above the count: nothing, the next argument is not read
        {"%x%0%!", 0, NULL, NULL, "x0!"},       // unknown escapes give the character
        {"cut %", 0, NULL, NULL, "cut "},       // a lone percent sign at the end is dropped
        {"an insert may hold %1", 1, "%2 %% %n", "never used", "an insert may hold %2 %% %n"}, // inserts are not expanded again
        {"", 0, NULL, NULL, ""},
    };
    for (int i = 0; i < _countof(cases); i++)
    {
        const char* ins[2] = {cases[i].a, cases[i].b};
        char* got = SalInsertsExpandAlloc(cases[i].tmpl, ins, cases[i].count);
        CHECK(got != NULL && strcmp(got, cases[i].want) == 0);
        // the size asked for is exactly the text and its terminator
        CHECK(got != NULL && SalInsertsExpandTo(NULL, cases[i].tmpl, ins, cases[i].count) == strlen(got) + 1);
        if (got != NULL)
            free(got);
    }
    CHECK(SalInsertsExpandAlloc(NULL, NULL, 0) == NULL);
    {
        // NULL array with a template that has inserts
        char* got = SalInsertsExpandAlloc("a%1b", NULL, 1);
        CHECK(got != NULL && strcmp(got, "ab") == 0);
        if (got != NULL)
            free(got);
    }
    {
        // never cut: an insert far longer than any fixed buffer of the old code (1000 bytes)
        std::string big(70000, 'p');
        const char* ins[1] = {big.c_str()};
        char* got = SalInsertsExpandAlloc("Path to file too long: %1", ins, 1);
        CHECK(got != NULL && strlen(got) == 23 + 70000 && memcmp(got, "Path to file too long: ppp", 26) == 0 && got[23 + 69999] == 'p');
        if (got != NULL)
            free(got);
    }
    {
        // the same answer as FormatMessageW gives for every template form the program uses
        const WCHAR* tmplW[] = {L"System error: %1", L"(%1) to (%2).", L"%2 then %1%nline", L"100%% %1"};
        const char* tmplA[] = {"System error: %1", "(%1) to (%2).", "%2 then %1%nline", "100%% %1"};
        for (int i = 0; i < _countof(tmplW); i++)
        {
            DWORD_PTR args[2] = {(DWORD_PTR)L"first", (DWORD_PTR)L"second"};
            WCHAR wantW[200];
            DWORD n = FormatMessageW(FORMAT_MESSAGE_FROM_STRING | FORMAT_MESSAGE_ARGUMENT_ARRAY, tmplW[i], 0, 0, wantW, _countof(wantW), (va_list*)args);
            char want[200];
            WideCharToMultiByte(CP_UTF8, 0, wantW, -1, want, sizeof(want), NULL, NULL);
            // FormatMessage writes "%n" as CR LF, the program's message boxes take LF
            std::string w(want);
            size_t pos;
            while ((pos = w.find("\r\n")) != std::string::npos)
                w.erase(pos, 1);
            const char* ins[2] = {"first", "second"};
            char* got = SalInsertsExpandAlloc(tmplA[i], ins, SalInsertsCount(tmplA[i]));
            CHECK(n > 0 && got != NULL && w == got);
            if (got != NULL)
                free(got);
        }
    }
}

// feature 130: a plug-in's resource text as UTF-8 (plugins/shared/splloadstru8.h)
struct CFakeGen130
{
    int WideCalls;
    int NarrowCalls;
    BOOL NoWide; // LoadStrW gives NULL
    WCHAR BufW[200];
    char BufA[200];
    CFakeGen130() : WideCalls(0), NarrowCalls(0), NoWide(FALSE) {}
    // like the core's: a buffer that the next call overwrites
    WCHAR* LoadStrW(HINSTANCE module, int resID)
    {
        WideCalls++;
        if (NoWide)
            return NULL;
        if (resID == 1)
            wcscpy_s(BufW, L"Soubor \"%s\" ji\x017E existuje. P\x0159" L"epsat?");
        else if (resID == 2)
            wcscpy_s(BufW, L"\x0391\x03C1\x03C7\x03B5\x03AF\x03BF %s");
        else
            swprintf_s(BufW, L"text %d of %p", resID, (void*)module);
        return BufW;
    }
    char* LoadStr(HINSTANCE module, int resID)
    {
        NarrowCalls++;
        sprintf_s(BufA, "narrow %d", resID);
        return BufA;
    }
};

static DWORD WINAPI LoadStr130Thread(LPVOID param)
{
    CFakeGen130 gen; // each thread its own "interface" (the cache is what is shared)
    const char** out = (const char**)param;
    int i;
    for (i = 0; i < 200; i++)
        out[i] = SplLoadStrU8(&gen, (HINSTANCE)(UINT_PTR)0x70000, 1000 + i);
    return 0;
}

static void TestPluginLoadStr130()
{
    HINSTANCE mod = (HINSTANCE)(UINT_PTR)0x10000;
    HINSTANCE mod2 = (HINSTANCE)(UINT_PTR)0x20000;
    CFakeGen130 gen;

    // the defect: a code-page template with a UTF-8 name is not valid UTF-8 (so the message box
    // shows all of it through the code page); the UTF-8 template with the same name is
    {
        char name[] = "P\xC5\x99\xC3\xADli\xC5\xA1 \xC5\xBElu\xC5\xA5ou\xC4\x8Dk\xC3\xBD.txt";
        char acp[100];
        // "existuje" sentence in code page 1250 bytes: z-caron 9E, r-caron F8
        char templ1250[] = "Soubor \"%s\" ji\x9E existuje. P\xF8" "epsat?";
        _snprintf_s(acp, _TRUNCATE, templ1250, name);
        WCHAR* w = SplU8ToWAlloc(acp);
        CHECK(w == NULL); // not UTF-8: the legacy path of the box
        if (w != NULL)
            free(w);
        char u8[200];
        _snprintf_s(u8, _TRUNCATE, SplLoadStrU8(&gen, mod, 1), name);
        w = SplU8ToWAlloc(u8);
        CHECK(w != NULL && wcscmp(w, L"Soubor \"P\x0159\x00EDli\x0161 \x017Elu\x0165ou\x010Dk\x00FD.txt\" ji\x017E existuje. P\x0159" L"epsat?") == 0);
        if (w != NULL)
            free(w);
    }

    // converted once, the pointer stays the same and valid across other calls
    {
        gen.WideCalls = 0;
        const char* a = SplLoadStrU8(&gen, mod, 2);
        const char* b = SplLoadStrU8(&gen, mod, 3);
        const char* a2 = SplLoadStrU8(&gen, mod, 2);
        CHECK(a != NULL && a == a2 && a != b);
        CHECK(strcmp(a, "\xCE\x91\xCF\x81\xCF\x87\xCE\xB5\xCE\xAF\xCE\xBF %s") == 0);
        CHECK(gen.WideCalls == 2);
        CHECK(gen.NarrowCalls == 0);
        // unlike LoadStr: many texts in one expression
        char all[300];
        _snprintf_s(all, _TRUNCATE, "%s|%s|%s", SplLoadStrU8(&gen, mod, 10), SplLoadStrU8(&gen, mod, 11), SplLoadStrU8(&gen, mod, 12));
        CHECK(strstr(all, "text 10 of") == all && strstr(all, "|text 11 of") != NULL && strstr(all, "|text 12 of") != NULL);
        // the module is part of the key
        const char* m1 = SplLoadStrU8(&gen, mod, 20);
        const char* m2 = SplLoadStrU8(&gen, mod2, 20);
        CHECK(m1 != m2 && strcmp(m1, m2) != 0);
        // many ids: every text is its own and stays
        const char* first = SplLoadStrU8(&gen, mod, 5000);
        char want[60];
        int i;
        BOOL ok = TRUE;
        for (i = 5000; i < 7000; i++)
        {
            const char* t = SplLoadStrU8(&gen, mod, i);
            WCHAR wantW[60];
            swprintf_s(wantW, L"text %d of %p", i, (void*)mod);
            WideCharToMultiByte(CP_UTF8, 0, wantW, -1, want, sizeof(want), NULL, NULL);
            if (t == NULL || strcmp(t, want) != 0)
                ok = FALSE;
        }
        CHECK(ok);
        CHECK(first == SplLoadStrU8(&gen, mod, 5000) && strstr(first, "text 5000 of") == first);
    }

    // no wide text (low memory in the core): the code-page text, as before the change; not kept
    {
        CFakeGen130 none;
        none.NoWide = TRUE;
        const char* t = SplLoadStrU8(&none, mod, 31000);
        CHECK(t != NULL && strcmp(t, "narrow 31000") == 0);
        none.NoWide = FALSE;
        t = SplLoadStrU8(&none, mod, 31000);
        CHECK(t != NULL && strstr(t, "text 31000 of") == t);
    }

    // threads: the same ids from eight threads give the same pointers
    {
        static const char* out[8][200];
        HANDLE threads[8];
        int i;
        for (i = 0; i < 8; i++)
            threads[i] = CreateThread(NULL, 0, LoadStr130Thread, out[i], 0, NULL);
        WaitForMultipleObjects(8, threads, TRUE, 60000);
        BOOL same = TRUE;
        int j;
        for (i = 0; i < 8; i++)
        {
            CloseHandle(threads[i]);
            for (j = 0; j < 200; j++)
            {
                if (out[i][j] == NULL || out[i][j] != out[0][j])
                    same = FALSE;
            }
        }
        CHECK(same);
        CHECK(strstr(out[0][199], "text 1199 of") == out[0][199]);
    }

    // a piece of either encoding as UTF-8
    {
        struct
        {
            const char* in;
            const WCHAR* wantW; // NULL: the same bytes
        } rows[] = {
            {"", NULL},
            {"plain ASCII (5)", NULL},
            {"P\xC5\x99\xC3\xADstup byl odep\xC5\x99" "en.", NULL}, // UTF-8 stays
            {"\xE6\x97\xA5\xE6\x9C\xAC", NULL},
        };
        int i;
        for (i = 0; i < _countof(rows); i++)
        {
            char* got = SplLegacyToU8Alloc(rows[i].in);
            CHECK(got != NULL && strcmp(got, rows[i].in) == 0);
            if (got != NULL)
                free(got);
        }
        CHECK(SplLegacyToU8Alloc(NULL) == NULL);
        // code-page text: what the system's code page says it is
        char acp[] = "caf\xE9 \xFC" "ber"; // not valid UTF-8 in any case
        WCHAR wantW[40];
        MultiByteToWideChar(CP_ACP, 0, acp, -1, wantW, _countof(wantW));
        char want[100];
        WideCharToMultiByte(CP_UTF8, 0, wantW, -1, want, sizeof(want), NULL, NULL);
        char* got = SplLegacyToU8Alloc(acp);
        CHECK(got != NULL && strcmp(got, want) == 0);
        if (got != NULL)
        {
            WCHAR* w = SplU8ToWAlloc(got);
            CHECK(w != NULL); // the result is always valid UTF-8
            if (w != NULL)
                free(w);
            free(got);
        }
        // into a buffer: cut at a whole character, never an invalid tail
        char tiny[8];
        SplLegacyToU8("\xC5\x99\xC5\x99\xC5\x99\xC5\x99\xC5\x99", tiny, sizeof(tiny)); // 10 bytes into 8
        CHECK(strcmp(tiny, "\xC5\x99\xC5\x99\xC5\x99") == 0);
        SplLegacyToU8("abc", tiny, sizeof(tiny));
        CHECK(strcmp(tiny, "abc") == 0);
        SplLegacyToU8(NULL, tiny, sizeof(tiny));
        CHECK(tiny[0] == 0);
    }
}

// feature 129: wide inserts ("%ls") of a UTF-8 template (salwideinserts.h) - what the Registry
// Editor's messages and cache names are composed with; and the defect it replaces
static void TestWideInserts129()
{
    // the defect, as measured: a narrow printf with "%ls" fails at a letter above U+00FF
    {
        char buf[100];
        memset(buf, 'X', sizeof(buf));
        int r = _snprintf_s(buf, _TRUNCATE, "key \"%ls\" end", L"Kl\x00ED\x010D");
        CHECK(r == -1 && strstr(buf, "end") == NULL); // nothing usable; the fix does not go this way
        r = _snprintf_s(buf, _TRUNCATE, "key \"%ls\" end", L"plain");
        CHECK(r > 0 && strcmp(buf, "key \"plain\" end") == 0);
    }

    CHECK(!SalWideInsertsUsed(NULL) && !SalWideInsertsUsed("") && !SalWideInsertsUsed("no inserts %s %d"));
    CHECK(!SalWideInsertsUsed("100%% %%ls")); // a percent sign, then the letters "ls"
    CHECK(SalWideInsertsUsed("\"%ls\"") && SalWideInsertsUsed("%%%ls") && SalWideInsertsUsed("a %s b %ls"));
    CHECK(SalWideInsertsCount(NULL) == 0 && SalWideInsertsCount("x") == 0);
    CHECK(SalWideInsertsCount("\"%ls\\%ls\"") == 2 && SalWideInsertsCount("%ls%ls%ls") == 3);
    CHECK(SalWideInsertsCount("%%ls %ls") == 1 && SalWideInsertsCount("%l %s %ls") == 1);

    struct
    {
        const char* tmpl;
        const WCHAR* a;
        const WCHAR* b;
        const char* want;
    } cases[] = {
        {"Unable to open registry key \"%ls\". ", L"HKEY_CURRENT_USER\\Software\\x", NULL, "Unable to open registry key \"HKEY_CURRENT_USER\\Software\\x\". "},
        // the Czech template of the question with a Czech key name: UTF-8 in, UTF-8 out
        {"C\xC3\xADlov\xC3\xBD kl\xC3\xAD\xC4\x8D \"%ls\\%ls\" neexistuje.", L"HKEY_CURRENT_USER", L"Software\\C\x00EDl \x0159x",
         "C\xC3\xADlov\xC3\xBD kl\xC3\xAD\xC4\x8D \"HKEY_CURRENT_USER\\Software\\C\xC3\xADl \xC5\x99x\" neexistuje."},
        {"Name:\t%ls\n\nError", L"\x039A\x03BB\x03B5\x03B9\x03B4\x03AF", NULL, "Name:\t\xCE\x9A\xCE\xBB\xCE\xB5\xCE\xB9\xCE\xB4\xCE\xAF\n\nError"},
        {"%ls", L"\x65E5\x672C\x8A9E", NULL, "\xE6\x97\xA5\xE6\x9C\xAC\xE8\xAA\x9E"},
        {"[%ls]", L"\xD83D\xDE00", NULL, "[\xF0\x9F\x98\x80]"},                 // a surrogate pair: one 4-byte character
        {"[%ls]", L"a\xD83D", NULL, "[a\xEF\xBF\xBD]"},                          // an unpaired surrogate: U+FFFD
        {"%ls\\%ls", L"HKEY_LOCAL_MACHINE", L"", "HKEY_LOCAL_MACHINE\\"},     // the root: an empty key name
        {"%ls\\%ls", L"A", NULL, "A\\"},                                      // a missing insert gives nothing
        {"100%% of %ls", L"x", NULL, "100% of x"},
        {"%s %d %ls %x", L"w", NULL, "%s %d w %x"},                            // other specifications are copied as they are
        {"ends with %", L"w", NULL, "ends with %"},
        {"%l", L"w", NULL, "%l"},
        {"", L"w", NULL, ""},
    };
    for (int i = 0; i < _countof(cases); i++)
    {
        const WCHAR* ins[2] = {cases[i].a, cases[i].b};
        char* got = SalWideInsertsExpandAlloc(cases[i].tmpl, ins, 2);
        CHECK(got != NULL && strcmp(got, cases[i].want) == 0);
        CHECK(got != NULL && SalWideInsertsExpandTo(NULL, cases[i].tmpl, ins, 2) == strlen(got) + 1);
        if (got != NULL)
            free(got);
    }
    CHECK(SalWideInsertsExpandAlloc(NULL, NULL, 0) == NULL);
    {
        // a NULL array and a count below the template's inserts: nothing is read
        char* got = SalWideInsertsExpandAlloc("a%lsb%lsc", NULL, 2);
        CHECK(got != NULL && strcmp(got, "abc") == 0);
        if (got != NULL)
            free(got);
        const WCHAR* one[1] = {L"1"};
        got = SalWideInsertsExpandAlloc("a%lsb%lsc", one, 1);
        CHECK(got != NULL && strcmp(got, "a1bc") == 0);
        if (got != NULL)
            free(got);
    }
    {
        // never cut: the longest registry path (512 units of a three-byte letter) and far beyond
        std::wstring longName(40000, L'\x65E5');
        const WCHAR* ins[2] = {L"HKEY_CURRENT_USER", longName.c_str()};
        char* got = SalWideInsertsExpandAlloc("\"%ls\\%ls\"", ins, 2);
        CHECK(got != NULL && strlen(got) == 1 + 17 + 1 + 3 * 40000 + 1 && got[strlen(got) - 1] == '"');
        if (got != NULL)
            free(got);
    }
    {
        // lower case is folded on the wide text; a byte table on UTF-8 would not do
        struct
        {
            const WCHAR* in;
            const char* want;
        } low[] = {
            {L"reg:\\HKEY_CURRENT_USER\\Software\\Plain 1\\V", "reg:\\hkey_current_user\\software\\plain 1\\v"},
            {L"KL\x00CD\x010C \x017DLU\x0164", "kl\xC3\xAD\xC4\x8D \xC5\xBElu\xC5\xA5"},
            {L"\x0391\x03A1\x03A7", "\xCE\xB1\xCF\x81\xCF\x87"},
            {L"\x65E5\x672C", "\xE6\x97\xA5\xE6\x9C\xAC"},
            {L"", ""},
        };
        for (int i = 0; i < _countof(low); i++)
        {
            char* got = SalWideLowerToU8Alloc(low[i].in);
            CHECK(got != NULL && strcmp(got, low[i].want) == 0);
            if (got != NULL)
                free(got);
        }
        CHECK(SalWideLowerToU8Alloc(NULL) == NULL);
        // pairs a byte-wise lower-case table of code page 1250 makes equal in UTF-8 (C3 8A / C3 9A ...)
        const WCHAR* pairs[][2] = {{L"\x00EA", L"\x00FA"}, {L"\x00CA", L"\x00DA"}, {L"\x00E3", L"\x00F3"}, {L"\x010A", L"\x011A"}, {L"\x00CA", L"\x00FA"}};
        for (int i = 0; i < _countof(pairs); i++)
        {
            char* a = SalWideLowerToU8Alloc(pairs[i][0]);
            char* b = SalWideLowerToU8Alloc(pairs[i][1]);
            CHECK(a != NULL && b != NULL && strcmp(a, b) != 0);
            free(a);
            free(b);
        }
        // the same letter in two cases is one name
        char* a = SalWideLowerToU8Alloc(L"Software\\KL\x00CD\x010C");
        char* b = SalWideLowerToU8Alloc(L"SOFTWARE\\kl\x00ED\x010D");
        CHECK(a != NULL && b != NULL && strcmp(a, b) == 0);
        free(a);
        free(b);
    }
    {
        // two different keys give two different texts (the disk cache name of a viewed value)
        const WCHAR* k1[2] = {L"HKEY_CURRENT_USER", L"Software\\Kl\x00ED\x010D 1"};
        const WCHAR* k2[2] = {L"HKEY_CURRENT_USER", L"Software\\Kl\x00ED\x010D 2"};
        char* a = SalWideInsertsExpandAlloc("%ls\\%ls", k1, 2);
        char* b = SalWideInsertsExpandAlloc("%ls\\%ls", k2, 2);
        CHECK(a != NULL && b != NULL && strcmp(a, b) != 0);
        // ... and an ASCII path is what the old composition gave
        const WCHAR* k3[2] = {L"HKEY_CURRENT_USER", L"Software\\plain 1"};
        char* c = SalWideInsertsExpandAlloc("%ls\\%ls", k3, 2);
        char old[100];
        _snprintf_s(old, _TRUNCATE, "%ls\\%ls", k3[0], k3[1]);
        CHECK(c != NULL && strcmp(c, old) == 0);
        free(a);
        free(b);
        free(c);
    }
}

// feature 128 (GitHub #8): the target of a shortcut as a UTF-8 path (salshelllink.h), against
// real .lnk files written with the wide interface in the temporary folder
static void TestShellLink128()
{
    WCHAR tempW[MAX_PATH];
    if (GetTempPathW(MAX_PATH, tempW) == 0)
    {
        CHECK(FALSE);
        return;
    }
    HRESULT coInit = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
    // the shell answers with the long form of the path: %TEMP% may be in 8.3 form
    WCHAR tempLongW[1024];
    DWORD longLen = GetLongPathNameW(tempW, tempLongW, _countof(tempLongW));
    std::wstring dir = std::wstring(longLen > 0 && longLen < _countof(tempLongW) ? tempLongW : tempW) +
                       L"saltests128_" + std::to_wstring(GetCurrentProcessId());
    CreateDirectoryW(dir.c_str(), NULL);
    struct
    {
        const WCHAR* Folder; // name of the target folder (created)
        const char* FolderU8;
    } cases[] = {
        {L"t_ascii", "t_ascii"},
        {L"t_\x00DA\x010D" L"etnictv\x00ED", "t_\xC3\x9A\xC4\x8D" "etnictv\xC3\xAD"},                     // Czech letters (the system code page on a Czech Windows)
        {L"t_\x0391\x03C1\x03C7\x03B5\x03AF\x03BF", "t_\xCE\x91\xCF\x81\xCF\x87\xCE\xB5\xCE\xAF\xCE\xBF"}, // Greek
        {L"t_\x4E2D\x6587 \xD83D\xDE00", "t_\xE4\xB8\xAD\xE6\x96\x87 \xF0\x9F\x98\x80"},                     // Chinese and an emoji (a surrogate pair)
    };
    char dirU8[1024];
    CHECK(SalWToU8(dir.c_str(), -1, dirU8, sizeof(dirU8)) != 0);
    for (int i = 0; i < _countof(cases); i++)
    {
        std::wstring target = dir + L"\\" + cases[i].Folder;
        std::wstring lnk = dir + L"\\link" + std::to_wstring(i) + L".lnk";
        CreateDirectoryW(target.c_str(), NULL);
        // write the shortcut
        IShellLinkW* link = NULL;
        BOOL saved = FALSE;
        if (CoCreateInstance(CLSID_ShellLink, NULL, CLSCTX_INPROC_SERVER, IID_IShellLinkW, (LPVOID*)&link) == S_OK)
        {
            IPersistFile* file = NULL;
            if (link->SetPath(target.c_str()) == S_OK && link->QueryInterface(IID_IPersistFile, (LPVOID*)&file) == S_OK)
            {
                saved = file->Save(lnk.c_str(), TRUE) == S_OK;
                file->Release();
            }
            link->Release();
        }
        CHECK(saved);
        // read it back the way the panel does
        link = NULL;
        if (saved && CoCreateInstance(CLSID_ShellLink, NULL, CLSCTX_INPROC_SERVER, IID_IShellLinkW, (LPVOID*)&link) == S_OK)
        {
            IPersistFile* file = NULL;
            if (link->QueryInterface(IID_IPersistFile, (LPVOID*)&file) == S_OK)
            {
                CHECK(file->Load(lnk.c_str(), STGM_READ) == S_OK);
                std::string want = std::string(dirU8) + "\\" + cases[i].FolderU8;
                char path[2048];
                memset(path, 'X', sizeof(path));
                CHECK(SalShellLinkGetPathU8(link, path, sizeof(path), SLGP_UNCPRIORITY) == NOERROR);
                CHECK(SalPathEqualOrdinalCI(path, want.c_str())); // (the shell may answer in another letter case)
                // the path the core gets names the folder that exists
                DWORD attr = SalGetFileAttributes(path);
                CHECK(attr != INVALID_FILE_ATTRIBUTES && (attr & FILE_ATTRIBUTE_DIRECTORY) != 0);
                // exact fit / one byte short: whole or refused, never cut
                int need = (int)want.length() + 1;
                memset(path, 'X', sizeof(path));
                CHECK(SalShellLinkGetPathU8(link, path, need, SLGP_UNCPRIORITY) == NOERROR && SalPathEqualOrdinalCI(path, want.c_str()));
                memset(path, 'X', sizeof(path));
                CHECK(FAILED(SalShellLinkGetPathU8(link, path, need - 1, SLGP_UNCPRIORITY)) && path[0] == 0);
                memset(path, 'X', sizeof(path));
                CHECK(FAILED(SalShellLinkGetPathU8(link, path, 1, SLGP_UNCPRIORITY)) && path[0] == 0);
                // what the A interface gave (the defect): for a non-ASCII target the bytes are not
                // the UTF-8 path - recorded here so the reason for the wide call stays visible
                if (i > 0 && GetACP() != CP_UTF8) // (with a UTF-8 system code page the A interface gives the same bytes)
                {
                    IShellLinkA* linkA = NULL;
                    if (link->QueryInterface(IID_IShellLinkA, (LPVOID*)&linkA) == S_OK)
                    {
                        char pathA[MAX_PATH];
                        pathA[0] = 0;
                        linkA->GetPath(pathA, MAX_PATH, NULL, SLGP_UNCPRIORITY);
                        CHECK(strcmp(pathA, want.c_str()) != 0);
                        linkA->Release();
                    }
                }
                file->Release();
            }
            link->Release();
        }
        DeleteFileW(lnk.c_str());
        RemoveDirectoryW(target.c_str());
    }
    // a shortcut without a target path: not NOERROR, and an empty buffer
    {
        IShellLinkW* link = NULL;
        if (CoCreateInstance(CLSID_ShellLink, NULL, CLSCTX_INPROC_SERVER, IID_IShellLinkW, (LPVOID*)&link) == S_OK)
        {
            char path[100];
            memset(path, 'X', sizeof(path));
            CHECK(SalShellLinkGetPathU8(link, path, sizeof(path), SLGP_UNCPRIORITY) != NOERROR && path[0] == 0);
            link->Release();
        }
        char path[10] = "X";
        CHECK(SalShellLinkGetPathU8(NULL, path, sizeof(path), 0) == E_INVALIDARG && path[0] == 0);
        CHECK(SalShellLinkGetPathU8(NULL, NULL, 0, 0) == E_INVALIDARG);
    }
    RemoveDirectoryW(dir.c_str());
    if (SUCCEEDED(coInit))
        CoUninitialize();
}

// feature 137: a name shortened at a whole character (SplU8WholePrefixLen in splunicode.h)
static void TestU8WholePrefix137()
{
    // "a" + c-caron (2 bytes) + euro (3 bytes) + folder emoji (4 bytes) + "z": 11 bytes
    const char s[] = "a\xC4\x8D\xE2\x82\xAC\xF0\x9F\x93\x81z";
    const int expect[12] = {0, 1, 1, 3, 3, 3, 6, 6, 6, 6, 10, 11};
    for (int n = 0; n <= 11; n++)
        CHECK(SplU8WholePrefixLen(s, n) == expect[n]);
    // every kept prefix is valid UTF-8 and the longest one that fits
    for (int n = 0; n <= 11; n++)
    {
        int k = SplU8WholePrefixLen(s, n);
        char buf[16];
        memcpy(buf, s, k);
        buf[k] = 0;
        WCHAR* w = SplU8ToWAlloc(buf);
        CHECK(w != NULL);
        free(w);
        CHECK(k <= n && (k == n || ((unsigned char)s[n] & 0xC0) == 0x80)); // shorter only when the cut was inside a character
        CHECK(k == 0 || ((unsigned char)s[k] & 0xC0) != 0x80);              // ends at a boundary
        CHECK(n - k <= 3);                                                  // the longest that fits
    }
    CHECK(SplU8WholePrefixLen("plain.txt", 5) == 5);
    CHECK(SplU8WholePrefixLen(NULL, 5) == 0 && SplU8WholePrefixLen("abc", 0) == 0 && SplU8WholePrefixLen("abc", -3) == 0);
    // the case measured on 0.1.9: "prilis zlutoucky.txt" (accented) with room for 8 bytes of name
    const char name[] = "p\xC5\x99\xC3\xADli\xC5\xA1 \xC5\xBElu\xC5\xA5ou\xC4\x8Dk\xC3\xBD.txt";
    CHECK(SplU8WholePrefixLen(name, 8) == 7); // the 8th byte is the first half of the s-caron
    CHECK(SplU8WholePrefixLen(name, 9) == 9);
}

// feature 141: the name an operation mask makes (salmaskname.h) - whole, or refused
static void TestMaskName141()
{
    // the results of the routine before 141 (printed by the old code; ASCII names and masks
    // must not change by a byte)
    static const struct
    {
        const char* Name;
        const char* Mask;
        const char* Result;
    } table[] = {
        {"a.b.c.d", "*.*", "a.b.c.d"},
        {"a.b.c.d", "*", "a.b.c.d"},
        {"a.b.c.d", "*.txt", "a.b.c.txt"},
        {"a.b.c.d", "?.*", "a.d"},
        {"a.b.c.d", "new.*", "new.d"},
        {"a.b.c.d", "*.??", "a.b.c.d"},
        {"a.b.c.d", "*.*.old", "a.b.c.d.old"}, // the example of the routine's comment
        {"a.b.c.d", "??????.*", "a.b.c.d"},
        {"a.b.c.d", "*.", "a.b.c"},
        {"a.b.c.d", "x*y.z", "x.b.cy.z"},
        {"a.b.c.d", "?", "a"},
        {"a.b.c.d", "a?c.*", "a.c.d"},
        {"a.b.c.d", ".*", ".d"},
        {"a.b.c.d", "*.t?t", "a.b.c.tt"},
        {"a.b.c.d", NULL, "a.b.c.d"},
        {"file.txt", "*.*", "file.txt"},
        {"file.txt", "*", "file.txt"},
        {"file.txt", "*.txt", "file.txt"},
        {"file.txt", "?.*", "f.txt"},
        {"file.txt", "new.*", "new.txt"},
        {"file.txt", "*.??", "file.tx"},
        {"file.txt", "*.*.old", "file.txt.old"},
        {"file.txt", "*.", "file"},
        {"file.txt", "x*y.z", "xiley.z"},
        {"file.txt", "a?c.*", "aic.txt"},
        {"file.txt", ".*", ".txt"},
        {"file.txt", "*.t?t", "file.txt"},
        {"file", "*.*", "file"},
        {"file", "*.txt", "file.txt"},
        {"file", "?.*", "f"},
        {"file", "new.*", "new"},
        {"file", "*.*.old", "file..old"},
        {"file", ".*", ""},
        {"file", "*.t?t", "file.tt"},
        {".cvspass", "*.*", ".cvspass"},
        {".cvspass", "*", ".cvspass"},
        {".cvspass", "*.txt", ".txt"},
        {".cvspass", "?.*", ".cvspass"},
        {".cvspass", "new.*", "new.cvspass"},
        {".cvspass", "*.??", ".cv"},
        {".cvspass", "*.", ""},
        {".cvspass", "?", ""},
        {".cvspass", "a?c.*", "ac.cvspass"},
        {".cvspass", NULL, ".cvspass"},
        {"..a", "*.*", "..a"},
        {"..a", "*.txt", "..txt"},
        {"..a", "new.*", "new.a"},
        {"..a", ".*", ".a"},
        {"a..b", "*.*", "a..b"},
        {"a..b", "?.*", "a.b"},
        {"a..b", "x*y.z", "x.y.z"},
        {"a..b", "a?c.*", "a.c.b"},
        {"name.tar.gz", "*.txt", "name.tar.txt"},
        {"name.tar.gz", "?.*", "n.gz"},
        {"name.tar.gz", "??????.*", "name.t.gz"},
        {"name.tar.gz", "x*y.z", "xame.tary.z"},
        {"name.tar.gz", "*.t?t", "name.tar.tzt"},
        {"c   ...", "*.*", "c   "}, // why the callers turn "*.*" into a NULL mask
        {"c   ...", "*.txt", "c   ...txt"},
        {"c   ...", "a?c.*", "a c"},
        {"c   ...", NULL, "c   ..."},
        {"x", "*.*.old", "x..old"},
        {"x", "a?c.*", "ac"},
        {"", "*.*", ""},
        {"", "*.txt", ".txt"},
        {"", "*.*.old", "..old"},
        {"", NULL, ""},
        {"a.", "*.*", "a"},
        {"a.", "*.*.old", "a..old"},
        {"a.", NULL, "a."},
        {"long name.with.dots.txt", "??????.*", "long n.txt"},
        {"long name.with.dots.txt", "x*y.z", "xong name.with.dotsy.z"},
        {"long name.with.dots.txt", "*.??", "long name.with.dots.tx"},
    };
    char buf[2048];
    for (int i = 0; i < (int)_countof(table); i++)
    {
        const char* expect = table[i].Result;
        int len = (int)strlen(expect);
        // whole in a large buffer and in the one that fits exactly
        memset(buf, 'Z', sizeof(buf));
        CHECK(SalMaskNameU8(buf, 100, table[i].Name, table[i].Mask) && strcmp(buf, expect) == 0);
        memset(buf, 'Z', sizeof(buf));
        CHECK(SalMaskNameU8(buf, len + 1, table[i].Name, table[i].Mask) && strcmp(buf, expect) == 0 && buf[len + 1] == 'Z');
        BOOL cut = TRUE;
        memset(buf, 'Z', sizeof(buf));
        CHECK(SalMaskNameLegacyU8(buf, len + 1, table[i].Name, table[i].Mask, &cut) == buf && !cut && strcmp(buf, expect) == 0);
        if (len > 0)
        {
            // one byte less: refused with an empty buffer; the historical form holds the cut text and says so
            memset(buf, 'Z', sizeof(buf));
            CHECK(!SalMaskNameU8(buf, len, table[i].Name, table[i].Mask) && buf[0] == 0 && buf[len] == 'Z');
            cut = FALSE;
            memset(buf, 'Z', sizeof(buf));
            CHECK(SalMaskNameLegacyU8(buf, len, table[i].Name, table[i].Mask, &cut) == buf && cut &&
                  (int)strlen(buf) < len && strncmp(buf, expect, strlen(buf)) == 0 && buf[len] == 'Z');
        }
    }
    // arguments
    CHECK(SalMaskNameLegacyU8(NULL, 10, "a", "*", NULL) == NULL && SalMaskNameLegacyU8(buf, 0, "a", "*", NULL) == NULL &&
          SalMaskNameLegacyU8(buf, 10, NULL, "*", NULL) == NULL);
    strcpy(buf, "old");
    CHECK(!SalMaskNameU8(buf, 10, NULL, "*") && buf[0] == 0);
    CHECK(!SalMaskNameU8(NULL, 10, "a", "*") && !SalMaskNameU8(buf, 0, "a", "*"));
    CHECK(SalMaskNameU8(buf, 1, "", NULL) && buf[0] == 0 && !SalMaskNameU8(buf, 1, "a", NULL) && buf[0] == 0);
    // a result whose trailing dot is dropped fits a buffer the untrimmed text would not
    CHECK(SalMaskNameU8(buf, 4, "abc", "*.") && strcmp(buf, "abc") == 0);
    CHECK(!SalMaskNameU8(buf, 3, "abc", "*.") && buf[0] == 0);

    // names Windows can store: 250 and 255 CJK letters (750 / 765 bytes of UTF-8)
    const char cjk[] = "\xE4\xB8\xAD"; // U+4E2D
    for (int letters = 250; letters <= 255; letters += 5)
    {
        std::string name;
        for (int i = 0; i < letters; i++)
            name += cjk;
        int bytes = letters * 3;
        CHECK(SalNameUtf16UnitsU8(name.c_str()) == letters && !SalNameTooLongForFileSystemU8(name.c_str()));
        // the buffers before 141: 2 * MAX_PATH (rename) and 2 * MAX_PATH + 200 (copy, move) cut it
        CHECK(!SalMaskNameU8(buf, 2 * MAX_PATH, name.c_str(), NULL) && buf[0] == 0);
        CHECK(!SalMaskNameU8(buf, 2 * MAX_PATH + 200, name.c_str(), NULL) && buf[0] == 0);
        BOOL cut = FALSE;
        SalMaskNameLegacyU8(buf, 2 * MAX_PATH + 200, name.c_str(), NULL, &cut);
        CHECK(cut && strlen(buf) == 719 && ((unsigned char)buf[718] & 0xC0) == 0x80 && (unsigned char)buf[717] == 0xE4); // what 0.1.9 used: 239 letters and two bytes of the next
        // the buffer of a name holds it, with every mask that keeps it
        CHECK(SalMaskNameU8(buf, SAL_FIND_NAME_U8, name.c_str(), NULL) && name == buf);
        CHECK(SalMaskNameU8(buf, SAL_FIND_NAME_U8, name.c_str(), "*.*") && name == buf);
        CHECK(SalMaskNameU8(buf, SAL_FIND_NAME_U8, name.c_str(), "*") && name == buf);
        CHECK(SalMaskNameU8(buf, bytes + 1, name.c_str(), "*.*") && name == buf); // exact fit
        CHECK(!SalMaskNameU8(buf, bytes, name.c_str(), "*.*") && buf[0] == 0);    // one byte short
        CHECK(!SalMaskNameU8(buf, bytes, name.c_str(), NULL) && buf[0] == 0);
        // the name typed as the new name (the mask is the name: Quick Rename, F5 with a new name)
        CHECK(SalMaskNameU8(buf, SAL_FIND_NAME_U8, "old.txt", name.c_str()) && name == buf);
        CHECK(!SalMaskNameU8(buf, 2 * MAX_PATH, "old.txt", name.c_str()) && buf[0] == 0);
        // "*.bak": the result is longer than a name; it fits the buffer or not, and is told too long
        std::string bak = name + ".bak";
        BOOL fits = SalMaskNameU8(buf, SAL_FIND_NAME_U8, name.c_str(), "*.bak");
        CHECK(fits == (bytes + 4 < SAL_FIND_NAME_U8) && (fits ? bak == buf : buf[0] == 0));
        CHECK(SalMaskNameU8(buf, sizeof(buf), name.c_str(), "*.bak") && bak == buf);
        CHECK(SalNameTooLongForFileSystemU8(buf) == (letters + 4 > 255));
        // with an extension: "*.bak" replaces it
        std::string withExt = name.substr(0, bytes - 12) + ".txt";
        CHECK(SalMaskNameU8(buf, SAL_FIND_NAME_U8, withExt.c_str(), "*.bak") && name.substr(0, bytes - 12) + ".bak" == buf);
    }
    // whatever does not fit the buffer of a name is longer than a file system's name
    {
        std::string longest;
        for (int i = 0; i < 260; i++)
            longest += cjk; // 780 bytes: the shortest text (in units) that does not fit
        CHECK(!SalMaskNameU8(buf, SAL_FIND_NAME_U8, longest.c_str(), NULL) && SalNameTooLongForFileSystemU8(longest.c_str()));
        std::string emoji; // 4 bytes = 2 units each: 195 of them are 780 bytes and 390 units
        for (int i = 0; i < 128; i++)
            emoji += U8_FOLDER_EMOJI;
        CHECK(SalNameUtf16UnitsU8(emoji.c_str()) == 256 && SalNameTooLongForFileSystemU8(emoji.c_str()));
        emoji.resize(emoji.size() - 4);
        emoji += "a";
        CHECK(SalNameUtf16UnitsU8(emoji.c_str()) == 255 && !SalNameTooLongForFileSystemU8(emoji.c_str()));
        CHECK(SalNameUtf16UnitsU8("") == 0 && SalNameUtf16UnitsU8(NULL) == 0 && SalNameUtf16UnitsU8("a" U8_C_CARON_NFC "\xE2\x82\xAC") == 3);
        CHECK(SalNameUtf16UnitsU8("\xE9t\xE9") == 3 && SalNameUtf16UnitsU8("\xC4") == 1 && SalNameUtf16UnitsU8("\x8D\x8D") == 2); // not UTF-8: a byte is a character
    }

    // '?' and a literal work on whole characters (they took and skipped single bytes: half a letter)
    const char scaron[] = "\xC5\xA1"; // U+0161
    std::string n = std::string(scaron) + "abc.txt";
    CHECK(SalMaskNameU8(buf, 100, n.c_str(), "?*.*") && n == buf);
    CHECK(SalMaskNameU8(buf, 100, n.c_str(), "?.*") && std::string(scaron) + ".txt" == buf);
    CHECK(SalMaskNameU8(buf, 100, n.c_str(), "x*.*") && strcmp(buf, "xabc.txt") == 0);
    CHECK(SalMaskNameU8(buf, 100, "abc.txt", "\xC3\xA9*.*") && strcmp(buf, "\xC3\xA9" "bc.txt") == 0); // one literal replaces one letter
    CHECK(SalMaskNameU8(buf, 100, "ab.txt", U8_FOLDER_EMOJI "?.*") && strcmp(buf, U8_FOLDER_EMOJI "b.txt") == 0);
    CHECK(SalMaskNameU8(buf, 100, "\xE4\xB8\xAD\xE6\x97\xA5.txt", "??.*") && strcmp(buf, "\xE4\xB8\xAD\xE6\x97\xA5.txt") == 0);
    CHECK(SalMaskNameU8(buf, 100, "\xE4\xB8\xAD\xE6\x97\xA5.txt", "?.*") && strcmp(buf, "\xE4\xB8\xAD.txt") == 0);
    CHECK(SalMaskNameU8(buf, 100, "\xE4\xB8\xAD\xE6\x97\xA5.txt", "*.t?t") && strcmp(buf, "\xE4\xB8\xAD\xE6\x97\xA5.txt") == 0);
    // text that is not UTF-8 goes byte by byte, as before
    CHECK(SalMaskNameU8(buf, 100, "\xE9t\xE9.txt", "?.*") && strcmp(buf, "\xE9.txt") == 0);
    CHECK(SalMaskNameU8(buf, 100, "\xE9t\xE9.txt", "x??.*") && strcmp(buf, "xt\xE9.txt") == 0);
    CHECK(SalMaskNameU8(buf, 100, "a\xC5", "??") && strcmp(buf, "a\xC5") == 0); // a lead byte at the end of the text

    // FTP, automatic rename of an upload (salftpautoren.h): the bytes taken from the end of the
    // name part, in front of the extension, are whole characters
    // "a" + s-caron (2 bytes) + U+4E2D (3) + folder emoji (4) + "z": 11 bytes
    const char part[] = "a\xC5\xA1\xE4\xB8\xAD\xF0\x9F\x93\x81z";
    const int expectCut[13] = {0, 1, 5, 5, 5, 5, 8, 8, 8, 10, 10, 11, 11}; // by 'cut' 0..12
    for (int cut = 0; cut <= 12; cut++)
    {
        int c = SalFtpCutBeforeExt(part, 11, cut);
        CHECK(c == expectCut[cut]);
        CHECK(c >= (cut < 11 ? cut : 11) && c <= 11);                      // never less than asked
        CHECK(c == 11 || ((unsigned char)part[11 - c] & 0xC0) != 0x80);     // what stays ends at a boundary
        memcpy(buf, part, 11 - c);
        buf[11 - c] = 0;
        WCHAR* w = SplU8ToWAlloc(buf); // and is valid text
        CHECK(w != NULL);
        free(w);
    }
    CHECK(SalFtpCutBeforeExt("abcdef", 6, 2) == 2 && SalFtpCutBeforeExt("abcdef", 6, 5) == 5); // ASCII: as before
    CHECK(SalFtpCutBeforeExt("abcdef", 6, 6) == 6 && SalFtpCutBeforeExt("abcdef", 6, 9) == 6);
    CHECK(SalFtpCutBeforeExt(NULL, 5, 2) == 0 && SalFtpCutBeforeExt("abc", 0, 2) == 0 && SalFtpCutBeforeExt("abc", 3, -1) == 0);
    CHECK(SalFtpCutBeforeExt(U8_FOLDER_EMOJI "a.txt", 5, 4) == 5); // nothing of the name part would stay: the caller trims the end instead
    // the case of the plug-in: 125 accented letters + "a" (251 bytes) + ".txt", " (2)" needs 4 bytes
    {
        std::string acc;
        for (int i = 0; i < 125; i++)
            acc += scaron;
        acc += "a";
        CHECK(SalFtpCutBeforeExt(acc.c_str(), 251, 4) == 5); // "a" and two letters, not "a", one letter and a half
        CHECK(SalFtpCutBeforeExt(acc.c_str(), 251, 3) == 3 && SalFtpCutBeforeExt(acc.c_str(), 251, 1) == 1);
    }
    // the step back is bounded (review of 141): valid UTF-8 as SplU8WholePrefixLen ...
    const int expectKeep[12] = {0, 1, 1, 3, 3, 3, 6, 6, 6, 6, 10, 11};
    for (int k = 0; k <= 11; k++)
        CHECK(SalFtpWholePrefixLen(part, k) == expectKeep[k] && SalFtpWholePrefixLen(part, k) == SplU8WholePrefixLen(part, k));
    CHECK(SalFtpWholePrefixLen(NULL, 5) == 0 && SalFtpWholePrefixLen("abc", 0) == 0 && SalFtpWholePrefixLen("abc", -1) == 0 && SalFtpWholePrefixLen("abc", 3) == 3);
    // ... text of a code page keeps the plain byte cut unless a lead byte within 3 bytes reaches
    // over it: a name of 267 bytes 0x80-0xAF was emptied by the unbounded step back
    {
        char run[300];
        for (int i = 0; i < 267; i++)
            run[i] = (char)(0x80 + i % 0x30);
        run[267] = 0;
        CHECK(SplU8WholePrefixLen(run, 255) == 0); // why the generator does not use it
        for (int k = 1; k <= 267; k++)
            CHECK(SalFtpWholePrefixLen(run, k) == k);
        for (int cut = 1; cut < 267; cut++)
            CHECK(SalFtpCutBeforeExt(run, 267, cut) == cut);
        CHECK(SalFtpCutBeforeExt(run, 267, 267) == 267);
    }
    CHECK(SalFtpWholePrefixLen("ab\xE9\x80\x80\x80", 5) == 5);     // the sequence of E9 ended before the cut: a stray byte, byte cut
    CHECK(SalFtpWholePrefixLen("ab\xE9\x80\x80\x80", 4) == 2);     // E9 80 | 80: reaches over
    CHECK(SalFtpWholePrefixLen("ab\xC3\x80\x80", 4) == 4);         // C3 80 is complete, the next 0x80 is stray
    CHECK(SalFtpWholePrefixLen("a\x80\x80\x80\x80\x80", 4) == 4);  // no lead byte within 3 bytes
    CHECK(SalFtpWholePrefixLen("\xF0\x90\x80\x80", 3) == 0 && SalFtpWholePrefixLen("x\xF0\x90\x80\x80", 4) == 1);
    {
        // any bytes: never more than 3 back, and a shorter result drops a lead byte's sequence
        unsigned seed = 141;
        for (int it = 0; it < 2000; it++)
        {
            char rnd[40];
            seed = seed * 1103515245u + 12345u;
            int len = 1 + (int)((seed >> 16) % 30);
            for (int i = 0; i < len; i++)
            {
                seed = seed * 1103515245u + 12345u;
                unsigned r = (seed >> 16) & 0x7FFF;
                rnd[i] = (char)(r % 3 == 0 ? 'a' + r % 26 : 0x80 + r % 0x80);
            }
            rnd[len] = 0;
            seed = seed * 1103515245u + 12345u;
            int cutAt = (int)((seed >> 16) % (len + 1));
            int k = SalFtpWholePrefixLen(rnd, cutAt);
            CHECK(k <= cutAt && k >= cutAt - 3 && k >= 0 && (k == cutAt || (unsigned char)rnd[k] >= 0xC0));
        }
    }
}

// feature 135: a small Exif TIFF block: IFD0 (Make, pointer to the Exif IFD), the Exif IFD with a
// MakerNote of 12 bytes, and by 'ifd1': 0 = no IFD1, 1 = IFD1 with a JPEG thumbnail at the very
// end, 2 = an uncompressed thumbnail (strips), 3 = a JPEG thumbnail followed by other data
static std::string J135Tiff(bool le, int ifd1, const std::string& thumb, const std::string& maker = "MAKERNOTE-12")
{
    std::string t;
    auto p16 = [&](unsigned v) { unsigned char b[2]; SalExifPut16(b, le, v); t.append((const char*)b, 2); };
    auto p32 = [&](unsigned long v) { unsigned char b[4]; SalExifPut32(b, le, v); t.append((const char*)b, 4); };
    auto entry = [&](unsigned tag, unsigned type, unsigned long count, unsigned long value) { p16(tag); p16(type); p32(count); if (type == 3 && count == 1) { p16(value); p16(0); } else p32(value); };
    t += le ? "II" : "MM";
    p16(42);
    p32(8);
    // IFD0 at 8: 2 entries -> 8 + 2 + 24 + 4 = 38; "Canon\0" at 38 (6 bytes) -> Exif IFD at 44
    const unsigned long makeAt = 38, exifIfd = 44;
    const unsigned long noteAt = exifIfd + 2 + 12 + 4; // 62
    const unsigned long ifd1At = noteAt + (unsigned long)maker.size() + (maker.size() & 1);
    p16(2);
    entry(0x010F, 2, 6, makeAt);
    entry(0x8769, 4, 1, exifIfd);
    p32(ifd1 != 0 ? ifd1At : 0);
    t.append("Canon\0", 6);
    p16(1);
    entry(0x927C, 7, (unsigned long)maker.size(), noteAt);
    p32(0);
    t += maker;
    if (maker.size() & 1)
        t += '\0';
    if (ifd1 == 0)
        return t;
    const unsigned long dataAt = ifd1At + 2 + 12 * 4 + 4;
    p16(4);
    entry(0x0103, 3, 1, ifd1 == 2 ? 1 : 6);
    entry(0x0112, 3, 1, 1); // Orientation: an entry that is not about the picture's storage
    if (ifd1 == 2)
    {
        entry(0x0111, 4, 1, dataAt);
        entry(0x0117, 4, 1, (unsigned long)thumb.size());
    }
    else
    {
        entry(0x0201, 4, 1, dataAt);
        entry(0x0202, 4, 1, (unsigned long)thumb.size());
    }
    p32(0);
    t += thumb;
    if (ifd1 == 3)
        t += "DATA-BEHIND-THE-THUMBNAIL";
    return t;
}

static std::string J135Replace(const std::string& tiff, const std::string& thumb)
{
    unsigned char* out = NULL;
    size_t outSize = 0;
    std::string r;
    if (SalExifReplaceThumbnail((const unsigned char*)tiff.data(), tiff.size(), (const unsigned char*)thumb.data(), thumb.size(), &out, &outSize))
        r.assign((const char*)out, outSize);
    free(out);
    return r;
}

static int J135Keeps(const std::string& o, const std::string& n)
{
    return SalExifRewriteKeepsData((const unsigned char*)o.data(), o.size(), (const unsigned char*)n.data(), n.size());
}

// feature 135: the thumbnail of an Exif block replaced with no other byte moved (salexifthumb.h)
static void TestExifThumb135()
{
    const std::string newThumb = "\xFF\xD8 a new thumbnail picture, longer than the old one \xFF\xD9";
    for (int e = 0; e < 2; e++)
    {
        const bool le = e == 0;
        // ---- the usual case: a JPEG thumbnail at the very end - cut there, append, correct the length
        {
            const std::string o = J135Tiff(le, 1, "\xFF\xD8OLD-THUMBNAIL");
            const std::string n = J135Replace(o, newThumb);
            CSalExifLayout lo, ln;
            CHECK(SalExifReadLayout((const unsigned char*)o.data(), o.size(), &lo) && lo.LittleEndian == (le ? 1 : 0));
            CHECK(lo.Ifd1 != 0 && lo.Compression == 6 && lo.ThumbLen == 15 && lo.ThumbOff + lo.ThumbLen == o.size());
            CHECK(!n.empty() && SalExifReadLayout((const unsigned char*)n.data(), n.size(), &ln));
            CHECK(ln.Ifd1 == lo.Ifd1 && ln.ThumbOff == lo.ThumbOff && ln.ThumbLen == newThumb.size());
            CHECK(n.size() == lo.ThumbOff + newThumb.size());
            CHECK(n.compare(ln.ThumbOff, ln.ThumbLen, newThumb) == 0);
            // nothing else changed: only the four bytes of the length differ before the picture
            int differ = 0;
            for (size_t i = 0; i < lo.ThumbOff; i++)
                if (o[i] != n[i])
                    differ++;
            CHECK(differ >= 1 && differ <= 4);
            CHECK(n.find("MAKERNOTE-12") == o.find("MAKERNOTE-12") && o.find("MAKERNOTE-12") != std::string::npos);
            CHECK(J135Keeps(o, n) == 1);
            CHECK(J135Keeps(o, o) == 1);
            // a shorter picture too
            const std::string n2 = J135Replace(o, "tiny");
            CHECK(n2.size() == lo.ThumbOff + 4 && J135Keeps(o, n2) == 1);
        }
        // ---- no IFD1, an uncompressed thumbnail, a thumbnail in the middle: a new IFD1 behind everything
        for (int kind = 0; kind <= 3; kind++)
        {
            if (kind == 1)
                continue;
            const std::string o = J135Tiff(le, kind, "OLD-THUMBNAIL");
            const std::string n = J135Replace(o, newThumb);
            CSalExifLayout lo, ln;
            CHECK(SalExifReadLayout((const unsigned char*)o.data(), o.size(), &lo));
            CHECK(!n.empty() && SalExifReadLayout((const unsigned char*)n.data(), n.size(), &ln));
            CHECK(ln.Ifd1 >= o.size() && (ln.Ifd1 & 1) == 0);                 // appended, at an even offset
            CHECK(ln.Compression == 6 && ln.ThumbLen == newThumb.size() && ln.ThumbOff + ln.ThumbLen == n.size());
            CHECK(n.compare(ln.ThumbOff, ln.ThumbLen, newThumb) == 0);
            // the whole original is still there, byte for byte, but IFD0's link
            int differ = 0;
            for (size_t i = 0; i < o.size(); i++)
                if (o[i] != n[i])
                {
                    differ++;
                    CHECK(i >= lo.Ifd0Link && i < lo.Ifd0Link + 4);
                }
            CHECK(differ >= 1);
            // an old IFD1's entry that is not about the picture is carried over; the strip tags are not
            CHECK(ln.Ifd1Count == (kind == 0 ? 3u : 4u));
            if (kind != 0)
            {
                bool orientation = false, strips = false;
                for (size_t i = 0; i < ln.Ifd1Count; i++)
                {
                    unsigned long tag = SalExifGet16((const unsigned char*)n.data() + ln.Ifd1 + 2 + 12 * i, le);
                    orientation = orientation || tag == 0x0112;
                    strips = strips || tag == 0x0111 || tag == 0x0117;
                    if (i > 0)
                        CHECK(tag > SalExifGet16((const unsigned char*)n.data() + ln.Ifd1 + 2 + 12 * (i - 1), le)); // sorted
                }
                CHECK(orientation && !strips);
            }
            CHECK(J135Keeps(o, n) == 1);
            if (kind == 3)
                CHECK(n.find("DATA-BEHIND-THE-THUMBNAIL") == o.find("DATA-BEHIND-THE-THUMBNAIL"));
            // updating the result again takes the usual way and keeps it
            const std::string n3 = J135Replace(n, "third");
            CHECK(!n3.empty() && J135Keeps(n, n3) == 1 && n3.size() < n.size());
        }
    }
    // ---- refused: not a TIFF block, cut structures, a result over a segment, no picture
    {
        const std::string o = J135Tiff(true, 1, "\xFF\xD8OLD-THUMBNAIL");
        CHECK(J135Replace("", newThumb).empty());
        CHECK(J135Replace("garbage, not a TIFF header at all", newThumb).empty());
        CHECK(J135Replace(o.substr(0, 20), newThumb).empty());   // IFD0 leaves the data
        std::string bad = o;
        bad[2] = 43;                                             // not the TIFF number
        CHECK(J135Replace(bad, newThumb).empty());
        bad = o;
        bad[4] = 2;                                              // IFD0 inside the header
        CHECK(J135Replace(bad, newThumb).empty());
        CHECK(J135Replace(o, "").empty());
        CHECK(J135Replace(o, std::string(SALEXIF_MAX_TIFF, 'x')).empty());          // does not fit a segment
        CHECK(!J135Replace(o, std::string(60000, 'x')).empty());
        CHECK(J135Replace(J135Tiff(true, 0, "", std::string(30000, 'm')), std::string(40000, 'x')).empty()); // appended: too big
        unsigned char* out = (unsigned char*)1;
        size_t outSize = 5;
        CHECK(!SalExifReplaceThumbnail(NULL, 100, (const unsigned char*)"x", 1, &out, &outSize) && out == NULL && outSize == 0);
        // an IFD1 whose link leaves the data: not understood
        std::string cut = o;
        CSalExifLayout l;
        CHECK(SalExifReadLayout((const unsigned char*)o.data(), o.size(), &l));
        SalExifPut32((unsigned char*)&cut[l.Ifd0Link], 1, 60000);
        CHECK(J135Replace(cut, newThumb).empty());
        // a thumbnail range that leaves the block is "no thumbnail": a new IFD1 is appended
        std::string wild = o;
        SalExifPut32((unsigned char*)&wild[l.ThumbLenEntry + 8], 1, 50000);
        const std::string w2 = J135Replace(wild, newThumb);
        CHECK(!w2.empty() && w2.size() > wild.size());
    }
    // ---- found by the review: structures that share bytes, entries given twice, the old picture
    {
        auto p32at = [](std::string& t, size_t at, unsigned long v) { SalExifPut32((unsigned char*)&t[at], 1, v); };
        const std::string o = J135Tiff(true, 1, "\xFF\xD8OLD-THUMBNAIL");
        CSalExifLayout l;
        CHECK(SalExifReadLayout((const unsigned char*)o.data(), o.size(), &l) && l.ThumbLen == 15);
        // a thumbnail offset laid over the maker's block: "no thumbnail" - a new IFD1 is appended,
        // nothing is cut and the maker's block is not zeroed
        std::string over = o;
        const size_t note = o.find("MAKERNOTE-12");
        for (size_t i = 0; i < l.Ifd1Count; i++)
            if (SalExifGet16((const unsigned char*)o.data() + l.Ifd1 + 2 + 12 * i, 1) == 0x0201)
                p32at(over, l.Ifd1 + 2 + 12 * i + 8, (unsigned long)note);
        CSalExifLayout lo2;
        CHECK(SalExifReadLayout((const unsigned char*)over.data(), over.size(), &lo2) && lo2.ThumbLen == 0);
        const std::string n = J135Replace(over, newThumb);
        CHECK(!n.empty() && n.size() > over.size() && n.find("MAKERNOTE-12") == note && J135Keeps(over, n) == 1);
        std::string wiped = n;
        memset(&wiped[note], 0, 12);
        CHECK(J135Keeps(over, wiped) == 0); // the check does not take those bytes for thumbnail bytes either
        // IFD0's link into the Exif IFD (IFD1 == the Exif IFD), into IFD0 itself: not understood
        std::string link = o;
        p32at(link, l.Ifd0Link, 44);
        CHECK(J135Replace(link, newThumb).empty() && J135Keeps(link, link) == 0);
        link = o;
        p32at(link, l.Ifd0Link, 8);
        CHECK(J135Replace(link, newThumb).empty());
        // an entry of IFD1 given twice: not understood
        std::string twice = o;
        for (size_t i = 0; i < l.Ifd1Count; i++)
            if (SalExifGet16((const unsigned char*)o.data() + l.Ifd1 + 2 + 12 * i, 1) == 0x0112)
                SalExifPut16((unsigned char*)&twice[l.Ifd1 + 2 + 12 * i], 1, 0x0201);
        CHECK(J135Replace(twice, newThumb).empty());
        // a picture at the end that is not a JPEG picture is not cut away (a new IFD1 is appended)
        const std::string noJpeg = J135Tiff(true, 1, "OLD-THUMBNAIL");
        const std::string n4 = J135Replace(noJpeg, newThumb);
        CHECK(n4.size() > noJpeg.size() && n4.find("OLD-THUMBNAIL") != std::string::npos);
        // a JPEG thumbnail followed by other data: appended, and the old picture is zeroed
        const std::string mid = J135Tiff(true, 3, "\xFF\xD8OLD-PICTURE-TO-FORGET");
        const std::string n5 = J135Replace(mid, newThumb);
        CHECK(!n5.empty() && n5.find("OLD-PICTURE-TO-FORGET") == std::string::npos);
        CHECK(n5.find("DATA-BEHIND-THE-THUMBNAIL") == mid.find("DATA-BEHIND-THE-THUMBNAIL") && J135Keeps(mid, n5) == 1);
        // the usual way for a real JPEG picture at the end: nothing of it stays either
        const std::string n6 = J135Replace(o, newThumb);
        CHECK(n6.find("OLD-THUMBNAIL") == std::string::npos && n6.size() == l.ThumbOff + newThumb.size());
        // offsets near 4 GB (they wrapped the bounds where size_t has 32 bits)
        std::string distant = o;
        p32at(distant, 4, 0xFFFFFFFEul);
        CHECK(J135Replace(distant, newThumb).empty());
        distant = o;
        p32at(distant, l.Ifd0Link, 0xFFFFFFFEul);
        CHECK(J135Replace(distant, newThumb).empty());
    }
    // ---- the check: what the old library did to real files is not "kept"
    {
        const std::string o = J135Tiff(true, 1, "\xFF\xD8OLD-THUMBNAIL");
        const std::string n = J135Replace(o, newThumb);
        std::string x = n;
        x[x.find("MAKERNOTE-12") + 3] ^= 1;                      // one byte of the maker's block
        CHECK(J135Keeps(o, x) == 0);
        x = n;
        x[x.find("Canon") + 1] = 'A';                            // a tag's value
        CHECK(J135Keeps(o, x) == 0);
        x = n;
        x[9] ^= 1;                                               // IFD0's entry count
        CHECK(J135Keeps(o, x) == 0);
        // the block serialised again with a shorter maker's block: everything behind it moved
        const std::string moved = J135Replace(J135Tiff(true, 1, "\xFF\xD8OLD-THUMBNAIL", "MAKERNOTE-"), newThumb);
        CHECK(!moved.empty() && J135Keeps(o, moved) == 0);
        // another byte order, no thumbnail in the new block, a new block that is not understood
        CHECK(J135Keeps(o, J135Replace(J135Tiff(false, 1, "\xFF\xD8OLD-THUMBNAIL"), newThumb)) == 0);
        CHECK(J135Keeps(o, J135Tiff(true, 0, "")) == 0);
        CHECK(J135Keeps(o, "II*") == 0 && J135Keeps("garbage", n) == 0 && J135Keeps("", "") == 0);
        // cut short: a byte of the original outside its thumbnail is missing
        CSalExifLayout l;
        CHECK(SalExifReadLayout((const unsigned char*)o.data(), o.size(), &l));
        // (with the thumbnail at the end the block may be shorter than the original only inside it)
        const std::string tiny = J135Replace(o, "t");
        CHECK(tiny.size() < o.size() && J135Keeps(o, tiny) == 1);
        // the original with data behind its thumbnail: those data must stay
        const std::string o3 = J135Tiff(true, 3, "OLD-THUMBNAIL");
        std::string n3 = J135Replace(o3, newThumb);
        CHECK(J135Keeps(o3, n3) == 1);
        n3[n3.find("DATA-BEHIND") + 2] = 'x';
        CHECK(J135Keeps(o3, n3) == 0);
    }
}

// feature 132: is a rewritten JPEG file still the user's file (saljpegkeep.h) - the check
// PictView's Update Thumbnail makes before the file EXIF.DLL wrote replaces the original
static void J132Seg(std::string& out, unsigned char marker, const std::string& payload)
{
    out += (char)0xFF;
    out += (char)marker;
    out += (char)((payload.size() + 2) >> 8);
    out += (char)((payload.size() + 2) & 0xFF);
    out += payload;
}

static CSalJpegKeepResult J132Check(const std::string& o, const std::string& n)
{
    return SalJpegRewriteKeepsFile((const unsigned char*)o.data(), o.size(), (const unsigned char*)n.data(), n.size());
}

static void TestJpegKeep132()
{
    const std::string soi("\xFF\xD8", 2);
    const std::string eoi("\xFF\xD9", 2);
    // feature 135: real (small) Exif blocks - the rule looks inside a changed one
    const std::string tiffOld = J135Tiff(true, 1, "OLD-THUMBNAIL");
    const std::string exifOld = std::string("Exif\0\0", 6) + tiffOld;
    const std::string exifNew = std::string("Exif\0\0", 6) + J135Replace(tiffOld, "a new, much longer thumbnail picture ..........");
    const std::string jfif = std::string("JFIF\0", 5) + std::string("\x01\x01\x00\x00\x01\x00\x01\x00\x00", 9);
    const std::string jfxx = std::string("JFXX\0", 5) + "\x10thumbnail";
    const std::string xmp = std::string("http://ns.adobe.com/xap/1.0/\0", 29) + "<x:xmpmeta/>";
    const std::string dqt(65, 'q'), sof(15, 'f'), dht(30, 'h');
    std::string sos; // the SOS segment, the picture data (with stuffing and a restart marker) and EOI
    J132Seg(sos, 0xDA, std::string(10, 's'));
    sos += std::string("picture\xFF\x00" "data\xFF\xD0more", 22);
    const std::string scan = sos + eoi;

    std::string tables;
    J132Seg(tables, 0xDB, dqt);
    J132Seg(tables, 0xC0, sof);
    J132Seg(tables, 0xC4, dht);

    std::string app0, app1Old, app1New, appXmp, appJfxx;
    J132Seg(app0, 0xE0, jfif);
    J132Seg(app1Old, 0xE1, exifOld);
    J132Seg(app1New, 0xE1, exifNew);
    J132Seg(appXmp, 0xE1, xmp);
    J132Seg(appJfxx, 0xE0, jfxx);

    // the walker itself
    {
        std::string f = soi + app0 + std::string("\xFF\xFF\xFF", 3) + tables + scan;
        const unsigned char* d = (const unsigned char*)f.data();
        size_t pos = 2;
        CSalJpegSegment seg;
        CHECK(SalJpegNextSegment(d, f.size(), &pos, &seg) == 1 && seg.Marker == 0xE0 && seg.PayloadSize == jfif.size());
        // three fill bytes before the DQT marker are stepped over
        CHECK(SalJpegNextSegment(d, f.size(), &pos, &seg) == 1 && seg.Marker == 0xDB && seg.PayloadSize == 65);
        CHECK(memcmp(d + seg.Payload, dqt.data(), 65) == 0);
        CHECK(SalJpegNextSegment(d, f.size(), &pos, &seg) == 1 && seg.Marker == 0xC0);
        CHECK(SalJpegNextSegment(d, f.size(), &pos, &seg) == 1 && seg.Marker == 0xC4);
        size_t before = pos;
        CHECK(SalJpegNextSegment(d, f.size(), &pos, &seg) == 2 && pos == before); // SOS: nothing consumed
        CHECK(d[pos] == 0xFF && d[pos + 1] == 0xDA);
        // not understood: end of data, a length that leaves the data, a length under 2, markers
        // without a length, a byte that is not 0xFF
        pos = f.size();
        CHECK(SalJpegNextSegment(d, f.size(), &pos, &seg) == 0);
        const unsigned char cut[] = {0xFF, 0xDB, 0x00, 0x43, 1, 2, 3};
        pos = 0;
        CHECK(SalJpegNextSegment(cut, sizeof(cut), &pos, &seg) == 0);
        const unsigned char exact[] = {0xFF, 0xDB, 0x00, 0x05, 1, 2, 3};
        pos = 0;
        CHECK(SalJpegNextSegment(exact, sizeof(exact), &pos, &seg) == 1 && pos == 7 && seg.PayloadSize == 3);
        const unsigned char len1[] = {0xFF, 0xDB, 0x00, 0x01, 1, 2, 3};
        pos = 0;
        CHECK(SalJpegNextSegment(len1, sizeof(len1), &pos, &seg) == 0);
        const unsigned char len2[] = {0xFF, 0xFE, 0x00, 0x02, 0xFF, 0xDA};
        pos = 0;
        CHECK(SalJpegNextSegment(len2, sizeof(len2), &pos, &seg) == 1 && seg.PayloadSize == 0 && pos == 4);
        const unsigned char eoiOnly[] = {0xFF, 0xD9, 0, 0, 0, 0};
        pos = 0;
        CHECK(SalJpegNextSegment(eoiOnly, sizeof(eoiOnly), &pos, &seg) == 0);
        const unsigned char rst[] = {0xFF, 0xD3, 0, 4, 0, 0};
        pos = 0;
        CHECK(SalJpegNextSegment(rst, sizeof(rst), &pos, &seg) == 0);
        const unsigned char stuffed[] = {0xFF, 0x00, 0, 4, 0, 0};
        pos = 0;
        CHECK(SalJpegNextSegment(stuffed, sizeof(stuffed), &pos, &seg) == 0);
        const unsigned char plain[] = {0x12, 0xDB, 0, 4, 0, 0};
        pos = 0;
        CHECK(SalJpegNextSegment(plain, sizeof(plain), &pos, &seg) == 0);
        const unsigned char fillOnly[] = {0xFF, 0xFF, 0xFF};
        pos = 0;
        CHECK(SalJpegNextSegment(fillOnly, sizeof(fillOnly), &pos, &seg) == 0);
        const unsigned char shortSeg[] = {0xFF, 0xDB, 0x00};
        pos = 0;
        CHECK(SalJpegNextSegment(shortSeg, sizeof(shortSeg), &pos, &seg) == 0);
    }
    // thumbnail carriers: an Exif APP1 and a JFXX APP0, nothing else
    {
        std::string f = app1Old + appXmp + appJfxx + app0;
        const unsigned char* d = (const unsigned char*)f.data();
        size_t pos = 0;
        CSalJpegSegment seg;
        int isExif = 7;
        CHECK(SalJpegNextSegment(d, f.size(), &pos, &seg) == 1 && SalJpegIsThumbnailCarrier(d, &seg, &isExif) && isExif == 1);
        CHECK(SalJpegNextSegment(d, f.size(), &pos, &seg) == 1 && !SalJpegIsThumbnailCarrier(d, &seg, &isExif) && isExif == 0); // XMP
        CHECK(SalJpegNextSegment(d, f.size(), &pos, &seg) == 1 && SalJpegIsThumbnailCarrier(d, &seg, &isExif) && isExif == 0);  // JFXX
        CHECK(SalJpegNextSegment(d, f.size(), &pos, &seg) == 1 && !SalJpegIsThumbnailCarrier(d, &seg, &isExif));               // JFIF
        std::string shortExif;
        J132Seg(shortExif, 0xE1, "Exif");
        d = (const unsigned char*)shortExif.data();
        pos = 0;
        CHECK(SalJpegNextSegment(d, shortExif.size(), &pos, &seg) == 1 && !SalJpegIsThumbnailCarrier(d, &seg, &isExif));
        std::string app2;
        J132Seg(app2, 0xE2, std::string("Exif\0\0", 6) + "x"); // "Exif" in another APPn is not the block
        d = (const unsigned char*)app2.data();
        pos = 0;
        CHECK(SalJpegNextSegment(d, app2.size(), &pos, &seg) == 1 && !SalJpegIsThumbnailCarrier(d, &seg, &isExif));
    }

    // ---- the rule: what Update Thumbnail may do
    const std::string plainFile = soi + app0 + tables + scan;
    const std::string exifFile = soi + app0 + app1Old + tables + scan;
    // a new Exif block in place of the old one
    CHECK(J132Check(exifFile, soi + app0 + app1New + tables + scan) == sjkSame);
    // a file without Exif gets a JFXX block behind its JFIF block
    CHECK(J132Check(plainFile, soi + app0 + appJfxx + tables + scan) == sjkSame);
    // an old JFXX block is replaced
    {
        std::string jfxx2;
        J132Seg(jfxx2, 0xE0, std::string("JFXX\0", 5) + "another thumbnail");
        CHECK(J132Check(soi + app0 + appJfxx + tables + scan, soi + app0 + jfxx2 + tables + scan) == sjkSame);
    }
    // nothing changed at all
    CHECK(J132Check(exifFile, exifFile) == sjkSame);
    // the library moves the Exif block (it is written right behind SOI when it was elsewhere)
    CHECK(J132Check(soi + app0 + tables + app1Old + scan, soi + app1New + app0 + tables + scan) == sjkSame);
    // the library does not write fill bytes back
    CHECK(J132Check(soi + app0 + std::string("\xFF\xFF", 2) + tables + scan, soi + app0 + appJfxx + tables + scan) == sjkSame);
    // XMP beside Exif stays: both orders
    CHECK(J132Check(soi + app1Old + appXmp + tables + scan, soi + app1New + appXmp + tables + scan) == sjkSame);
    CHECK(J132Check(soi + appXmp + app1Old + tables + scan, soi + appXmp + app1New + tables + scan) == sjkSame);
    // data behind the picture stay
    CHECK(J132Check(plainFile + "MOTION PHOTO", soi + app0 + appJfxx + tables + scan + "MOTION PHOTO") == sjkSame);
    // a file cut inside the picture (no EOI) written back with all it had
    CHECK(J132Check(soi + app0 + tables + sos, soi + app0 + appJfxx + tables + sos) == sjkSame);

    // ---- the losses EXIF.DLL reported as success (measured on 0.1.9)
    // the XMP block turned into an (empty) Exif block
    {
        std::string emptyExif;
        J132Seg(emptyExif, 0xE1, std::string("Exif\0\0", 6) + "MM");
        CHECK(J132Check(soi + app1Old + appXmp + tables + scan, soi + app1New + emptyExif + tables + scan) == sjkSegmentsDiffer);
        CHECK(J132Check(soi + app0 + appXmp + tables + scan, soi + app0 + appJfxx + emptyExif + tables + scan) == sjkSegmentsDiffer);
        // ... or dropped
        CHECK(J132Check(soi + app0 + appXmp + tables + scan, soi + app0 + appJfxx + tables + scan) == sjkSegmentsDiffer);
    }
    // only the beginning of the file was understood and written (more fill bytes than the
    // library reads): the new file ends behind the JFXX block
    CHECK(J132Check(soi + app0 + std::string(8, (char)0xFF) + tables + scan, soi + app0 + appJfxx) == sjkNewNotUnderstood);
    // ... or it has its tables but no picture
    CHECK(J132Check(plainFile, soi + app0 + appJfxx + tables) == sjkNewNotUnderstood);
    // the Exif block no longer fits 16 bits: its length wrapped, what follows is not a segment
    {
        std::string wrapped = soi;
        wrapped += std::string("\xFF\xE1\x00\x20", 4) + std::string("Exif\0\0", 6) + std::string(70000, 'e');
        wrapped += tables + scan;
        CHECK(J132Check(exifFile, wrapped) != sjkSame);
    }
    // the last two bytes of the data behind the picture were dropped
    CHECK(J132Check(plainFile + "TRAILER\xFF\x01", soi + app0 + appJfxx + tables + scan + "TRAILER") == sjkImageDiffers);
    // one byte of the picture differs; the picture is shorter; the end marker is gone
    {
        std::string scan2 = scan;
        scan2[20] ^= 1;
        CHECK(J132Check(plainFile, soi + app0 + appJfxx + tables + scan2) == sjkImageDiffers);
        CHECK(J132Check(plainFile, soi + app0 + appJfxx + tables + scan.substr(0, scan.size() - 5)) == sjkImageDiffers);
        CHECK(J132Check(plainFile, soi + app0 + appJfxx + tables + sos) == sjkImageDiffers);
        // one byte of the SOS header itself
        scan2 = scan;
        scan2[5] ^= 1;
        CHECK(J132Check(plainFile, soi + app0 + appJfxx + tables + scan2) == sjkImageDiffers);
    }
    // a table changed, is missing, is doubled, tables in another order, another marker
    {
        std::string t2;
        J132Seg(t2, 0xDB, std::string(65, 'Q'));
        J132Seg(t2, 0xC0, sof);
        J132Seg(t2, 0xC4, dht);
        CHECK(J132Check(plainFile, soi + app0 + t2 + scan) == sjkSegmentsDiffer);
        std::string t3;
        J132Seg(t3, 0xDB, dqt);
        J132Seg(t3, 0xC4, dht);
        CHECK(J132Check(plainFile, soi + app0 + t3 + scan) == sjkSegmentsDiffer);
        std::string t4;
        J132Seg(t4, 0xC0, sof);
        J132Seg(t4, 0xDB, dqt);
        J132Seg(t4, 0xC4, dht);
        CHECK(J132Check(plainFile, soi + app0 + t4 + scan) == sjkSegmentsDiffer);
        std::string t5;
        J132Seg(t5, 0xDB, dqt);
        J132Seg(t5, 0xC2, sof);
        J132Seg(t5, 0xC4, dht);
        CHECK(J132Check(plainFile, soi + app0 + t5 + scan) == sjkSegmentsDiffer);
        std::string dht2;
        J132Seg(dht2, 0xC4, dht);
        CHECK(J132Check(plainFile, soi + app0 + tables + dht2 + scan) == sjkSegmentsDiffer);
        CHECK(J132Check(soi + app0 + tables + dht2 + scan, plainFile) == sjkSegmentsDiffer);
        // a shorter segment with the same beginning
        std::string t6;
        J132Seg(t6, 0xDB, std::string(64, 'q'));
        J132Seg(t6, 0xC0, sof);
        J132Seg(t6, 0xC4, dht);
        CHECK(J132Check(plainFile, soi + app0 + t6 + scan) == sjkSegmentsDiffer);
    }
    // the JFIF block, a comment, an ICC profile (APP2) are not thumbnail carriers
    {
        std::string com, icc;
        J132Seg(com, 0xFE, "a comment");
        J132Seg(icc, 0xE2, std::string("ICC_PROFILE\0", 12) + "profile");
        CHECK(J132Check(plainFile, soi + appJfxx + tables + scan) == sjkSegmentsDiffer); // JFIF gone
        CHECK(J132Check(soi + app0 + com + icc + tables + scan, soi + app0 + appJfxx + com + icc + tables + scan) == sjkSame);
        CHECK(J132Check(soi + app0 + com + icc + tables + scan, soi + app0 + appJfxx + icc + tables + scan) == sjkSegmentsDiffer);
        CHECK(J132Check(soi + app0 + com + icc + tables + scan, soi + app0 + appJfxx + com + tables + scan) == sjkSegmentsDiffer);
    }
    // the Exif block is gone (a JFXX block instead)
    CHECK(J132Check(exifFile, soi + app0 + appJfxx + tables + scan) == sjkExifGone);
    CHECK(J132Check(exifFile, soi + app0 + tables + scan) == sjkExifGone);
    // feature 135: a file that had no Exif block gets none (the library adds a JFXX block instead)
    CHECK(J132Check(plainFile, soi + app1New + app0 + tables + scan) == sjkCarriersDiffer);
    // feature 135: a changed Exif block with more changed than its thumbnail
    {
        std::string movedBlock, otherTag;
        J132Seg(movedBlock, 0xE1, std::string("Exif\0\0", 6) + J135Replace(J135Tiff(true, 1, "OLD-THUMBNAIL", "MAKERNOTE-"), "new"));
        std::string t2 = tiffOld;
        t2[t2.find("Canon") + 2] = 'N';
        J132Seg(otherTag, 0xE1, std::string("Exif\0\0", 6) + J135Replace(t2, "new"));
        CHECK(J132Check(exifFile, soi + app0 + movedBlock + tables + scan) == sjkExifDataDiffer);
        CHECK(J132Check(exifFile, soi + app0 + otherTag + tables + scan) == sjkExifDataDiffer);
        std::string fake;
        J132Seg(fake, 0xE1, std::string("Exif\0\0", 6) + "not a TIFF block at all");
        CHECK(J132Check(exifFile, soi + app0 + fake + tables + scan) == sjkExifDataDiffer);
        CHECK(J132Check(soi + app0 + fake + tables + scan, soi + app0 + app1New + tables + scan) == sjkExifDataDiffer); // an original that is not understood
        CHECK(J132Check(soi + app0 + fake + tables + scan, soi + app0 + fake + tables + scan) == sjkSame);              // ... untouched is fine
    }

    // ---- files the walker does not understand: never "the same"
    CHECK(J132Check("", plainFile) == sjkOriginalNotUnderstood);
    CHECK(J132Check(plainFile, "") == sjkNewNotUnderstood);
    CHECK(J132Check("GIF89a....", plainFile) == sjkOriginalNotUnderstood);
    CHECK(J132Check(plainFile, std::string("\xFF\xD8\x00\x00", 4)) == sjkNewNotUnderstood);
    CHECK(J132Check(soi + app0 + tables, soi + app0 + tables) == sjkOriginalNotUnderstood); // no SOS
    CHECK(J132Check(soi + app0 + eoi + tables + scan, soi + app0 + eoi + tables + scan) == sjkOriginalNotUnderstood);
    CHECK(J132Check(soi + soi + app0 + tables + scan, soi + soi + app0 + tables + scan) == sjkOriginalNotUnderstood);
    CHECK(SalJpegRewriteKeepsFile(NULL, 100, (const unsigned char*)plainFile.data(), plainFile.size()) == sjkOriginalNotUnderstood);
    CHECK(SalJpegRewriteKeepsFile((const unsigned char*)plainFile.data(), plainFile.size(), NULL, 100) == sjkNewNotUnderstood);
    // ---- one thing changes: one Exif block, or the JFXX blocks (found by the review: the old
    // library serialised an Exif block again - tags dropped - while it only added a JFXX block)
    {
        std::string exifOther, exifOther2, ducky;
        J132Seg(exifOther, 0xE1, std::string("Exif\0\0", 6) + "a second block, private tags");
        J132Seg(exifOther2, 0xE1, std::string("Exif\0\0", 6) + "a second block, tags dropped");
        J132Seg(ducky, 0xEC, std::string("Ducky\0", 6) + "\x01\x00\x04");
        const std::string o1 = soi + app0 + ducky + app1Old + tables + scan;
        CHECK(J132Check(o1, soi + app0 + appJfxx + ducky + app1New + tables + scan) == sjkCarriersDiffer); // Exif changed AND JFXX added
        CHECK(J132Check(o1, soi + app0 + appJfxx + ducky + app1Old + tables + scan) == sjkSame);          // JFXX added, Exif untouched
        CHECK(J132Check(o1, soi + app0 + ducky + app1New + tables + scan) == sjkSame);                     // the Exif block updated
        CHECK(J132Check(o1, soi + app0 + app1New + tables + scan) == sjkSegmentsDiffer);                   // the unknown block lost
        const std::string o2 = soi + app1Old + exifOther + tables + scan;
        std::string exifSwap;
        J132Seg(exifSwap, 0xE1, std::string("Exif\0\0", 6) + J135Replace(tiffOld, "another picture"));
        CHECK(J132Check(o2, soi + app1New + exifOther + tables + scan) == sjkSame);
        CHECK(J132Check(o2, soi + app1Old + exifOther2 + tables + scan) == sjkExifDataDiffer); // feature 135: changed in its tags
        CHECK(J132Check(o2, soi + app1New + exifOther2 + tables + scan) != sjkSame);          // both changed
        CHECK(J132Check(o2, soi + app1New + tables + scan) == sjkExifGone);
        CHECK(J132Check(o2, soi + app1Old + exifOther + exifOther + tables + scan) == sjkCarriersDiffer); // a block more
        CHECK(J132Check(plainFile, soi + app1New + exifOther + app0 + tables + scan) == sjkCarriersDiffer); // none -> two
        CHECK(J132Check(plainFile, soi + app1New + app0 + appJfxx + tables + scan) == sjkCarriersDiffer);   // none -> Exif and JFXX
        CHECK(J132Check(o2, soi + exifSwap + exifOther + tables + scan) == sjkSame);              // the first block's thumbnail
        // an old JFXX block beside Exif stays when the Exif block is updated
        CHECK(J132Check(soi + app0 + appJfxx + app1Old + tables + scan, soi + app0 + appJfxx + app1New + tables + scan) == sjkSame);
        CHECK(J132Check(soi + app0 + appJfxx + app1Old + tables + scan, soi + app0 + app1New + tables + scan) == sjkCarriersDiffer);
        // more blocks of one kind than the rule tells apart: not understood
        std::string many = soi;
        for (int i = 0; i < SALJPEG_MAX_CARRIERS + 1; i++)
            many += app1Old;
        many += tables + scan;
        CHECK(J132Check(many, many) == sjkOriginalNotUnderstood);
        CHECK(J132Check(exifFile, many) != sjkSame);
        std::string four = soi;
        for (int i = 0; i < SALJPEG_MAX_CARRIERS; i++)
            four += app1Old;
        four += tables + scan;
        CHECK(J132Check(four, four) == sjkSame);
    }

    // ---- has the file an Exif block (the question Update Thumbnail asks)
    {
        auto has = [](const std::string& f) { return SalJpegHasExif((const unsigned char*)f.data(), f.size()); };
        CHECK(has(exifFile) == 1);
        CHECK(has(plainFile) == 0);
        CHECK(has(soi + app0 + appXmp + tables + scan) == 0);          // XMP is not Exif
        CHECK(has(soi + appXmp + app1Old + tables + scan) == 1);       // Exif behind XMP
        CHECK(has(soi + app0 + appJfxx + tables + scan) == 0);
        CHECK(has((soi + app0 + app1Old + tables + scan).substr(0, (soi + app0 + app1Old).size() + 10)) == 1); // only the beginning of the file was read
        CHECK(has((soi + app0 + app1Old).substr(0, 30)) == 0);         // the block itself is cut
        CHECK(has(soi + app0 + tables + sos + app1Old) == 0);          // "Exif" behind the picture data is not a block
        CHECK(has("") == 0 && has("GIF89a") == 0);
        CHECK(SalJpegHasExif(NULL, 100) == 0);
    }
    // the smallest files
    CHECK(J132Check(soi + sos, soi + sos) == sjkSame);
    CHECK(J132Check(soi, soi) == sjkOriginalNotUnderstood);
}

// feature 143: a close request for a window inside one of its own loops (salloopclose.h)
static void TestLoopClose143()
{
    CSalLoopCloseState s;
    SalLoopInit(&s);

    // no loop: close as before, nothing pending, an unbalanced leave reports nothing
    CSalLoopClose c = SalLoopCloseRequest(&s, TRUE);
    CHECK(c.CloseNow && !c.EndMenu && !c.CancelOwnBoxes && !SalLoopClosePending(&s));
    CSalLoopLeave l = SalLoopLeave(&s, slkMenu);
    CHECK(!l.Last && !l.CloseNow && !l.Redeclare && s.Menus == 0);

    // a menu: pending, the menu is ended; leaving it carries the close out once
    CHECK(SalLoopEnter(&s, slkMenu));
    c = SalLoopCloseRequest(&s, TRUE);
    CHECK(!c.CloseNow && c.EndMenu && !c.CancelOwnBoxes && SalLoopClosePending(&s));
    c = SalLoopCloseRequest(&s, TRUE); // a second request inside the same loop
    CHECK(!c.CloseNow && c.EndMenu && SalLoopClosePending(&s));
    l = SalLoopLeave(&s, slkMenu);
    CHECK(l.Last && l.CloseNow && !l.Redeclare && !SalLoopClosePending(&s));
    CHECK(SalLoopCloseRequest(&s, TRUE).CloseNow); // the posted WM_CLOSE: now it closes

    // a menu without a request: the declaration comes back
    SalLoopInit(&s);
    CHECK(SalLoopEnter(&s, slkMenu));
    l = SalLoopLeave(&s, slkMenu);
    CHECK(l.Last && !l.CloseNow && l.Redeclare);

    // an own box: pending, the box is cancelled
    SalLoopInit(&s);
    CHECK(SalLoopEnter(&s, slkOwnBox));
    c = SalLoopCloseRequest(&s, TRUE);
    CHECK(!c.CloseNow && !c.EndMenu && c.CancelOwnBoxes);
    l = SalLoopLeave(&s, slkOwnBox);
    CHECK(l.Last && l.CloseNow);

    // a shell command: pending only - its windows are never answered
    SalLoopInit(&s);
    CHECK(SalLoopEnter(&s, slkShell));
    c = SalLoopCloseRequest(&s, TRUE);
    CHECK(!c.CloseNow && !c.EndMenu && !c.CancelOwnBoxes && SalLoopClosePending(&s));
    l = SalLoopLeave(&s, slkShell);
    CHECK(l.Last && l.CloseNow);

    // nested: a menu's command runs a shell command which opens an own box - no box is cancelled
    // while the shell runs; only the last leave closes
    SalLoopInit(&s);
    CHECK(SalLoopEnter(&s, slkMenu));
    CHECK(!SalLoopEnter(&s, slkShell)); // not the first loop
    CHECK(!SalLoopEnter(&s, slkOwnBox));
    c = SalLoopCloseRequest(&s, TRUE);
    CHECK(!c.CloseNow && c.EndMenu && !c.CancelOwnBoxes);
    l = SalLoopLeave(&s, slkOwnBox);
    CHECK(!l.Last && !l.CloseNow && SalLoopClosePending(&s));
    l = SalLoopLeave(&s, slkShell);
    CHECK(!l.Last && !l.CloseNow && SalLoopClosePending(&s));
    l = SalLoopLeave(&s, slkMenu);
    CHECK(l.Last && l.CloseNow && !l.Redeclare && !SalLoopClosePending(&s));

    // an own box after the shell command ended: cancelled again
    SalLoopInit(&s);
    SalLoopEnter(&s, slkShell);
    SalLoopEnter(&s, slkOwnBox);
    CHECK(!SalLoopCloseRequest(&s, TRUE).CancelOwnBoxes);
    SalLoopLeave(&s, slkShell);
    CHECK(SalLoopCloseRequest(&s, TRUE).CancelOwnBoxes);
    l = SalLoopLeave(&s, slkOwnBox);
    CHECK(l.Last && l.CloseNow);

    // a leave of a kind that is not open never drives a counter below zero and closes nothing early
    SalLoopInit(&s);
    SalLoopEnter(&s, slkOwnBox);
    SalLoopCloseRequest(&s, TRUE);
    l = SalLoopLeave(&s, slkMenu);
    CHECK(!l.Last && !l.CloseNow && s.Menus == 0 && s.OwnBoxes == 1 && SalLoopClosePending(&s));
    l = SalLoopLeave(&s, slkOwnBox);
    CHECK(l.Last && l.CloseNow);

    // a request given up by its sender (Release returned FALSE): the window stays and is declared again
    SalLoopInit(&s);
    SalLoopEnter(&s, slkShell);
    SalLoopCloseRequest(&s, TRUE);
    CHECK(SalLoopCloseAbandon(&s) && !SalLoopClosePending(&s));
    CHECK(!SalLoopCloseAbandon(&s));
    l = SalLoopLeave(&s, slkShell);
    CHECK(l.Last && !l.CloseNow && l.Redeclare);
    // a new request after the abandon closes again
    SalLoopEnter(&s, slkShell);
    SalLoopCloseRequest(&s, TRUE);
    SalLoopCloseAbandon(&s);
    SalLoopCloseRequest(&s, TRUE);
    l = SalLoopLeave(&s, slkShell);
    CHECK(l.Last && l.CloseNow);
    // review of 143: the person's own close (File > Exit, the close button) during a shell command is
    // not given up with Release's request
    SalLoopInit(&s);
    SalLoopEnter(&s, slkShell);
    SalLoopCloseRequest(&s, TRUE);  // Release
    SalLoopCloseRequest(&s, FALSE); // the person
    CHECK(!SalLoopCloseAbandon(&s) && SalLoopClosePending(&s));
    l = SalLoopLeave(&s, slkShell);
    CHECK(l.Last && l.CloseNow && !SalLoopClosePending(&s));
    // only the person's: an abandon does nothing
    SalLoopEnter(&s, slkShell);
    SalLoopCloseRequest(&s, FALSE);
    CHECK(!SalLoopCloseAbandon(&s));
    l = SalLoopLeave(&s, slkShell);
    CHECK(l.Last && l.CloseNow);
}

// feature 148: numbered names that skip the names the list holds (salnumbername.h)
static BOOL Num148(const char* const* names, const BOOL* renumber, int count, const char* const* want)
{
    char* out[16];
    if (!SalPickNumberedNames(count, names, renumber, out))
        return FALSE;
    BOOL ok = TRUE;
    for (int i = 0; i < count; i++)
    {
        if (want[i] == NULL)
            ok = ok && out[i] == NULL;
        else
            ok = ok && out[i] != NULL && strcmp(out[i], want[i]) == 0;
        free(out[i]);
    }
    return ok;
}

static void TestNumberName148()
{
    // the rule of Undelete's AddNumberSuffix: before an extension of exactly three characters
    char* n = SalNumberedNameAlloc("a.txt", 2);
    CHECK(n != NULL && strcmp(n, "a (2).txt") == 0);
    free(n);
    n = SalNumberedNameAlloc("a.tar.gz", 1);
    CHECK(n != NULL && strcmp(n, "a.tar.gz (1)") == 0);
    free(n);
    n = SalNumberedNameAlloc("noext", 3);
    CHECK(n != NULL && strcmp(n, "noext (3)") == 0);
    free(n);
    n = SalNumberedNameAlloc(".cvspass", 1);
    CHECK(n != NULL && strcmp(n, ".cvspass (1)") == 0);
    free(n);

    // the defect: two "a.txt" and an "a (1).txt" that keeps its name -> 2 and 3
    {
        const char* names[] = {"a.txt", "a.txt", "a (1).txt"};
        BOOL ren[] = {TRUE, TRUE, FALSE};
        const char* want[] = {"a (2).txt", "a (3).txt", NULL};
        CHECK(Num148(names, ren, 3, want));
    }
    // as before when nothing is in the way
    {
        const char* names[] = {"a.txt", "a.txt", "b.txt"};
        BOOL ren[] = {TRUE, TRUE, FALSE};
        const char* want[] = {"a (1).txt", "a (2).txt", NULL};
        CHECK(Num148(names, ren, 3, want));
    }
    // the file system's rule: "A (1).TXT" and a non-ASCII case pair are taken names too
    {
        const char* names[] = {"a.txt", "a.txt", "A (1).TXT", "\xC4\x8C.txt", "\xC4\x8C.txt", "\xC4\x8D (1).txt"};
        BOOL ren[] = {TRUE, TRUE, FALSE, TRUE, TRUE, FALSE};
        const char* want[] = {"a (2).txt", "a (3).txt", NULL, "\xC4\x8C (2).txt", "\xC4\x8C (3).txt", NULL};
        CHECK(Num148(names, ren, 6, want));
    }
    // FAT: the existing file keeps "a.txt", the deleted ones are numbered past an existing "a (1).txt"
    {
        const char* names[] = {"a.txt", "a.txt", "a.txt", "a (1).txt"};
        BOOL ren[] = {FALSE, TRUE, TRUE, FALSE};
        const char* want[] = {NULL, "a (2).txt", "a (3).txt", NULL};
        CHECK(Num148(names, ren, 4, want));
    }
    // two groups: "a (1).txt" twice is renumbered away, so the "a.txt" group may take "a (1).txt"
    {
        const char* names[] = {"a (1).txt", "a (1).txt", "a.txt", "a.txt"};
        BOOL ren[] = {TRUE, TRUE, TRUE, TRUE};
        const char* want[] = {"a (1) (1).txt", "a (1) (2).txt", "a (1).txt", "a (2).txt"};
        CHECK(Num148(names, ren, 4, want));
    }
    // a new name never equals another new name ("a (2).txt" chosen for the group, then the group
    // of the other spelling continues at 3)
    {
        const char* names[] = {"a.txt", "a.txt", "A.TXT"};
        BOOL ren[] = {TRUE, TRUE, TRUE};
        const char* want[] = {"a (1).txt", "a (2).txt", "A (3).TXT"};
        CHECK(Num148(names, ren, 3, want));
    }
    // nothing to number
    {
        const char* names[] = {"a.txt"};
        BOOL ren[] = {FALSE};
        const char* want[] = {NULL};
        CHECK(Num148(names, ren, 1, want));
    }
    // a large list (review of 148: the first version was quadratic): 20,000 equal names and 10,000
    // groups of two, sorted as the callers sort - every result unique, the big group numbered 1..20000
    {
        const int big = 20000, groups = 10000, count = big + 2 * groups;
        char** store = (char**)malloc(count * sizeof(char*));
        const char** names = (const char**)malloc(count * sizeof(const char*));
        BOOL* ren = (BOOL*)malloc(count * sizeof(BOOL));
        char** out = (char**)malloc(count * sizeof(char*));
        BOOL ok = store != NULL && names != NULL && ren != NULL && out != NULL;
        for (int i = 0; ok && i < count; i++)
        {
            store[i] = (char*)malloc(32);
            if (store[i] == NULL)
            {
                ok = FALSE;
                break;
            }
            if (i < 2 * groups)
                sprintf(store[i], "g%05d.txt", i / 2);
            else
                strcpy(store[i], "Thumbs.db");
            names[i] = store[i];
            ren[i] = TRUE;
        }
        DWORD t0 = GetTickCount();
        ok = ok && SalPickNumberedNames(count, names, ren, out);
        DWORD ms = GetTickCount() - t0;
        if (ok)
        {
            qsort(out, count, sizeof(out[0]), SalNumberNameDetail::CmpPtr);
            for (int i = 1; ok && i < count; i++)
                ok = SalNameOrderCompareCI(out[i - 1], -1, out[i], -1) != 0;
        }
        CHECK(ok);
        CHECK(ms < 10000); // seconds at most even in a Debug build (the quadratic version: minutes)
        for (int i = 0; out != NULL && i < count; i++)
            free(out[i]);
        for (int i = 0; store != NULL && i < count; i++)
            free(store[i]);
        free(store);
        free(names);
        free(ren);
        free(out);
    }
}

// feature 163: the relative kind of Find's ignore list (src/common/salfindignore.h)
static void TestFindIgnore163()
{
    const char* item = "\\Temp\\";
    int il = (int)strlen(item);
    // ASCII: as StrIStr did (case-insensitive, below the search root only)
    CHECK(SalFindIgnoreRelativeMatch("C:\\Users\\u\\temp\\x\\", item, il, 3));
    CHECK(SalFindIgnoreRelativeMatch("C:\\Users\\u\\TEMP\\", item, il, 3));
    CHECK(!SalFindIgnoreRelativeMatch("C:\\Temp\\x\\", item, il, 8));      // the search root itself: not a subpath
    CHECK(SalFindIgnoreRelativeMatch("C:\\Temp\\x\\Temp\\", item, il, 8)); // a later occurrence below the root
    CHECK(!SalFindIgnoreRelativeMatch("C:\\Temporary\\", item, il, 0));    // the item ends with a backslash
    CHECK(!SalFindIgnoreRelativeMatch("C:\\MyTemp\\", item, il, 0));       // it starts at a backslash
    // UTF-8: names that fold together only on code page 1250 are two folders
    const char* hc = "\\\xC4\xA5\\"; // \U+0125\ (h-circumflex)
    int hl = (int)strlen(hc);
    CHECK(SalFindIgnoreRelativeMatch("C:\\a\\\xC4\xA5\\", hc, hl, 3));
    CHECK(SalFindIgnoreRelativeMatch("C:\\a\\\xC4\xA4\\", hc, hl, 3));  // U+0124, its capital: the same name
    CHECK(!SalFindIgnoreRelativeMatch("C:\\a\\\xC4\xB9\\", hc, hl, 3)); // U+0139 (L-acute): another folder
    const char* cz = "\\\xC4\x8C"
                     "ast\\"; // \U+010Cast\ ("Cast" with C-caron)
    CHECK(SalFindIgnoreRelativeMatch("D:\\x\\\xC4\x8D"
                                     "AST\\y\\",
                                     cz, (int)strlen(cz), 3)); // c-caron lower
    CHECK(!SalFindIgnoreRelativeMatch("D:\\x\\Cast\\", cz, (int)strlen(cz), 3));
    // degenerate input
    CHECK(!SalFindIgnoreRelativeMatch(NULL, item, il, 0));
    CHECK(!SalFindIgnoreRelativeMatch("C:\\Temp\\", "", 0, 0));
    CHECK(!SalFindIgnoreRelativeMatch("C:\\Temp\\", "Temp\\", 5, 0)); // not prepared ("\" first)
}

// feature 164: the ZIP deletion in n log n (src/common/salzipdelete.h) against the per-member
// algorithm of del.cpp it replaces (UpdateCentrDir ported to bytes, SalZipNextMemberOffset)
static unsigned g_lcg164 = 12345;
static unsigned Rnd164(unsigned n)
{
    g_lcg164 = g_lcg164 * 1103515245u + 12345u;
    return (g_lcg164 >> 8) % n;
}
static void Put32At164(std::vector<unsigned char>& v, size_t p, unsigned long x)
{
    for (int i = 0; i < 4; i++)
        v[p + i] = (unsigned char)(x >> (8 * i));
}
// one central record: 32-bit offset, or the marker and the offset in a zip64 block (after an
// optional foreign block when 'foreignFirst')
static void AddRecord164(std::vector<unsigned char>& dir, unsigned long long offs, bool z64, bool foreignFirst)
{
    size_t at = dir.size();
    unsigned nameLen = 1 + Rnd164(12), commentLen = Rnd164(3);
    std::vector<unsigned char> extra;
    if (z64)
    {
        if (foreignFirst)
        {
            unsigned char f[] = {0x0A, 0x00, 0x04, 0x00, 1, 2, 3, 4}; // NTFS-like id 10, 4 bytes
            extra.insert(extra.end(), f, f + sizeof(f));
        }
        unsigned char h[] = {0x01, 0x00, 0x08, 0x00};
        extra.insert(extra.end(), h, h + 4);
        for (int i = 0; i < 8; i++)
            extra.push_back((unsigned char)(offs >> (8 * i)));
    }
    dir.resize(at + 46 + nameLen + extra.size() + commentLen, 0);
    Put32At164(dir, at, 0x02014B50UL);
    dir[at + 28] = (unsigned char)nameLen;
    dir[at + 30] = (unsigned char)extra.size();
    dir[at + 32] = (unsigned char)commentLen;
    Put32At164(dir, at + 20, 100); // sizes not marked
    Put32At164(dir, at + 24, 200);
    Put32At164(dir, at + 42, z64 ? 0xFFFFFFFFUL : (unsigned long)offs);
    for (unsigned i = 0; i < nameLen; i++)
        dir[at + 46 + i] = (unsigned char)('a' + Rnd164(26));
    if (!extra.empty())
        memcpy(&dir[at + 46 + nameLen], extra.data(), extra.size());
}
// UpdateCentrDir of del.cpp on bytes: one deleted member (cur, next or ~0, delta)
static void OldUpdate164(std::vector<unsigned char>& dir, unsigned long long cur, unsigned long long next,
                         unsigned long long delta, size_t* removed)
{
    using namespace salzipmember_detail;
    size_t p = 0;
    while (p < dir.size())
    {
        unsigned char* rec = &dir[p];
        size_t recLen = 46 + (size_t)Get16(rec + 28) + Get16(rec + 30) + Get16(rec + 32);
        unsigned long long v = Get32(rec + 42);
        size_t pos = 0;
        bool noOffset = false;
        if (v == 0xFFFFFFFFULL)
        {
            size_t avail = dir.size() - p;
            size_t q = SalZipCentralRecordOffsetPos(rec, recLen <= avail ? recLen : avail);
            if (q != 0 && q != 42)
            {
                pos = q;
                v = (unsigned long long)Get32(rec + q) | ((unsigned long long)Get32(rec + q + 4) << 32);
            }
            else
                noOffset = true;
        }
        if (v == cur)
        {
            dir.erase(dir.begin() + p, dir.begin() + p + recLen);
            (*removed)++;
            continue;
        }
        if (!noOffset && v > cur && (next == ~0ULL || v < next))
        {
            v -= delta;
            if (pos == 0)
                Put32(rec + 42, (unsigned long)v);
            else
                Put64(rec + pos, v);
        }
        p += recLen;
    }
}
static void TestZipDelete164()
{
    int runs = 0, boundMismatch = 0, dirMismatch = 0, countMismatch = 0;
    for (int run = 0; run < 400; run++)
    {
        // members on disk: ascending offsets with gaps; some above 4 GB (zip64)
        int n = 1 + (int)Rnd164(run < 300 ? 40 : 400);
        std::vector<unsigned long long> offs;
        unsigned long long o = Rnd164(100);
        for (int i = 0; i < n; i++)
        {
            offs.push_back(o);
            o += 30 + Rnd164(500) + (Rnd164(10) == 0 ? 0x100000000ULL : 0);
        }
        unsigned long long dataEnd = o;
        // the directory in a shuffled order (it need not follow the disk)
        std::vector<int> order(n);
        for (int i = 0; i < n; i++)
            order[i] = i;
        for (int i = n - 1; i > 0; i--)
            std::swap(order[i], order[Rnd164(i + 1)]);
        std::vector<unsigned char> dir;
        for (int i = 0; i < n; i++)
        {
            unsigned long long v = offs[order[i]];
            bool z64 = v >= 0xFFFFFFFFULL || Rnd164(6) == 0;
            AddRecord164(dir, v, z64, z64 && Rnd164(2) == 0);
        }
        // the deleted members: a sorted subset; the removed bytes grow along the disk
        std::vector<unsigned long long> del;
        for (int i = 0; i < n; i++)
            if (Rnd164(3) == 0)
                del.push_back(offs[i]);
        if (del.empty())
            del.push_back(offs[Rnd164(n)]);
        size_t d = del.size();
        size_t m = run % 5 == 0 ? Rnd164((unsigned)d + 1) : d; // a break part-way, sometimes
        std::vector<unsigned long long> nxt(d), delta(d);
        unsigned long long removedBytes = 0;
        for (size_t k = 0; k < d; k++)
        {
            nxt[k] = k + 1 < d ? del[k + 1] : ~0ULL;
            removedBytes += 30 + Rnd164(20);
            delta[k] = removedBytes;
        }

        unsigned long long* index = NULL;
        size_t count = 0;
        CHECK(SalZipBuildOffsetIndex(dir.data(), dir.size(), &index, &count) == 1 && count == (size_t)n);
        std::vector<unsigned char> oldDir = dir;
        size_t oldRemoved = 0;
        for (size_t k = 0; k < m; k++)
        {
            unsigned long long a = 0;
            bool okOld = SalZipNextMemberOffset(oldDir.data(), oldDir.size(), del[k], dataEnd, &a);
            unsigned long long b = SalZipNextFromIndex(index, count, del[k], dataEnd);
            if (!okOld || a != b)
                boundMismatch++;
            OldUpdate164(oldDir, del[k], nxt[k], delta[k], &oldRemoved);
        }
        size_t newRemoved = 0;
        size_t newLen = SalZipApplyDeletions(dir.data(), dir.size(), del.data(), nxt.data(), delta.data(), m, &newRemoved);
        if (newLen != oldDir.size() || memcmp(dir.data(), oldDir.data(), newLen) != 0)
            dirMismatch++;
        if (newRemoved != oldRemoved || newRemoved != m)
            countMismatch++;
        free(index);
        runs++;
    }
    CHECK(runs == 400);
    CHECK(boundMismatch == 0);
    CHECK(dirMismatch == 0);
    CHECK(countMismatch == 0);
    printf("TestZipDelete164: %d random directories, bound mismatches %d, directory mismatches %d, count mismatches %d\n",
           runs, boundMismatch, dirMismatch, countMismatch);

    // a record whose zip64 marker has no value: no index (the old path refuses), as SalZipNextMemberOffset
    std::vector<unsigned char> bad;
    AddRecord164(bad, 1000, false, false);
    size_t at = bad.size();
    AddRecord164(bad, 2000, false, false);
    Put32At164(bad, at + 42, 0xFFFFFFFFUL);
    unsigned long long* index = (unsigned long long*)1;
    size_t count = 7;
    unsigned long long next = 0;
    CHECK(SalZipBuildOffsetIndex(bad.data(), bad.size(), &index, &count) == 0 && index == NULL && count == 0);
    CHECK(!SalZipNextMemberOffset(bad.data(), bad.size(), 0, 5000, &next));
    // a truncated directory: no index
    CHECK(SalZipBuildOffsetIndex(bad.data(), at + 10, &index, &count) == 0);
    // empty directory: an empty index, every bound is the limit
    CHECK(SalZipBuildOffsetIndex(bad.data(), 0, &index, &count) == 1 && count == 0);
    CHECK(SalZipNextFromIndex(index, count, 5, 77) == 77);
    free(index);
    // nothing processed: the directory unchanged
    std::vector<unsigned char> keep = bad;
    size_t rem = 9;
    CHECK(SalZipApplyDeletions(bad.data(), bad.size(), NULL, NULL, NULL, 0, &rem) == bad.size() && rem == 0 && keep == bad);
}

// feature 165: the entry counts of a ZIP archive's end records (src/common/salzipcount.h)
static void TestZipCount165()
{
    unsigned short t = 1, d = 1;
    CHECK(!SalZipEndRecordCounts(0, 0, &t, &d) && t == 0 && d == 0);
    CHECK(!SalZipEndRecordCounts(35000, 35000, &t, &d) && t == 35000 && d == 35000);
    CHECK(!SalZipEndRecordCounts(65534, 65534, &t, &d) && t == 65534 && d == 65534); // the largest 16-bit count
    CHECK(SalZipEndRecordCounts(65535, 65535, &t, &d) && t == 0xFFFF && d == 0xFFFF); // 0xFFFF = "see zip64"
    CHECK(SalZipEndRecordCounts(70000, 70000, &t, &d) && t == 0xFFFF && d == 0xFFFF);
    CHECK(SalZipEndRecordCounts(70000, 1200, &t, &d) && t == 0xFFFF && d == 1200); // a multi-volume last disk
    CHECK(SalZipEndRecordCounts(100, 0x100000000ULL, &t, &d) && t == 100 && d == 0xFFFF);
    // what the plug-in wrote before: 100,000 members read (16-bit 0xFFFF kept), 50,000 deleted
    unsigned short old16 = 0xFFFF;
    old16 = (unsigned short)(old16 - 50000);
    CHECK(old16 == 15535);
    unsigned long long n64 = SalZipReadEntryCount(0xFFFF, true, 100000) - 50000;
    CHECK(!SalZipEndRecordCounts(n64, n64, &t, &d) && t == 50000);
    // reading
    CHECK(SalZipReadEntryCount(1234, false, 99) == 1234);
    CHECK(SalZipReadEntryCount(0xFFFF, true, 70000) == 70000);
    CHECK(SalZipReadEntryCount(0xFFFF, false, 0) == 0xFFFF); // no zip64 record: the field is the count
    CHECK(SalZipReadEntryCount(1234, true, 70000) == 1234);   // the field does not point to zip64 (APPNOTE)
    // the records of a loaded directory (the count a changed archive is written with)
    std::vector<unsigned char> dir;
    for (int i = 0; i < 3; i++)
    {
        size_t at = dir.size();
        dir.resize(at + 46 + 2, 0);
        dir[at] = 0x50, dir[at + 1] = 0x4B, dir[at + 2] = 0x01, dir[at + 3] = 0x02;
        dir[at + 28] = 2;
    }
    unsigned long long c = 9;
    CHECK(SalZipCountCentralRecords(dir.data(), dir.size(), &c) && c == 3);
    CHECK(!SalZipCountCentralRecords(dir.data(), dir.size() - 1, &c) && c == 2); // a cut last record
    CHECK(SalZipCountCentralRecords(NULL, 0, &c) && c == 0);
    CHECK(!SalZipCountCentralRecords(NULL, 5, &c));
}

// feature 169: the letter case of a UTF-8 name (src/common/salaltername.h) - the old
// AlterFileName (salamdr2.cpp before 169) ported with ASCII tables, for the equivalence on ASCII
static char Low169(char c) { return (c >= 'A' && c <= 'Z') ? (char)(c - 'A' + 'a') : c; }
static char Up169(char c) { return (c >= 'a' && c <= 'z') ? (char)(c - 'a' + 'A') : c; }
static void OldAlter169(char* tgtName, char* filename, int format, int change, BOOL dir)
{
    if (format == 6)
        format = dir ? 3 : 2;
    if (format == 7 && change != 0)
        format = (change == 1) ? 1 : 2;
    char* ext = NULL;
    if (change != 0 && format != 5 && format != 7)
    {
        char* s = filename;
        while (*s != 0)
            if (*s++ == '.')
                ext = s;
        if (change == 1)
        {
            if (ext != NULL)
                *(ext - 1) = 0;
        }
        else
        {
            if (ext == NULL || *ext == 0)
            {
                strcpy(tgtName, filename);
                return;
            }
            memmove(tgtName, filename, ext - filename);
            tgtName += ext - filename;
            filename = ext;
        }
    }
    switch (format)
    {
    case 5:
    {
        char* s = filename;
        int c = 8;
        while (c-- && *s != 0 && *s == Up169(*s) && *s != '.')
            s++;
        if (*s == '.')
            s++;
        else if (*s != 0)
        {
            strcpy(tgtName, filename);
            break;
        }
        c = 3;
        while (c-- && *s != 0 && *s != '.' && *s == Up169(*s))
            s++;
        if (*s != 0)
        {
            strcpy(tgtName, filename);
            break;
        }
        BOOL capital = TRUE;
        char *tgt = tgtName, *name = filename;
        while (*name != 0)
        {
            if (!capital)
            {
                *tgt++ = Low169(*name);
                if (*name++ == ' ')
                    capital = TRUE;
            }
            else
            {
                *tgt++ = Up169(*name);
                if (*name++ != ' ')
                    capital = FALSE;
            }
        }
        *tgt = 0;
        break;
    }
    case 1:
    {
        BOOL capital = TRUE;
        char *tgt = tgtName, *name = filename;
        while (*name != 0)
        {
            if (!capital)
            {
                *tgt++ = Low169(*name);
                if (*name == ' ' || *name == '.')
                    capital = TRUE;
            }
            else
            {
                *tgt++ = Up169(*name);
                if (*name != ' ' || *name == '.')
                    capital = FALSE;
            }
            name++;
        }
        *tgt = 0;
        break;
    }
    case 2:
    {
        char *tgt = tgtName, *name = filename;
        while (*name != 0)
            *tgt++ = Low169(*name++);
        *tgt = 0;
        break;
    }
    case 3:
    {
        char *tgt = tgtName, *name = filename;
        while (*name != 0)
            *tgt++ = Up169(*name++);
        *tgt = 0;
        break;
    }
    case 7:
    {
        char* s = filename;
        while (*s != 0)
            if (*s++ == '.')
                ext = s;
        if (ext == NULL)
            ext = s;
        BOOL capital = TRUE;
        char *tgt = tgtName, *name = filename;
        while (name < ext)
        {
            if (!capital)
            {
                *tgt++ = Low169(*name);
                if (*name++ == ' ')
                    capital = TRUE;
            }
            else
            {
                *tgt++ = Up169(*name);
                if (*name++ != ' ')
                    capital = FALSE;
            }
        }
        while (*name != 0)
            *tgt++ = Low169(*name++);
        *tgt = 0;
        break;
    }
    default:
        strcpy(tgtName, filename);
        break;
    }
    if (change == 1 && format != 5 && format != 7)
    {
        if (ext != NULL)
        {
            *--ext = '.';
            strcpy(tgtName + (ext - filename), ext);
        }
    }
}
static std::string Alter169(const char* name, int format, int change = 0, BOOL dir = FALSE)
{
    char src[600], tgt[600];
    strcpy(src, name);
    memset(tgt, 'Z', sizeof(tgt));
    SalAlterFileNameU8(tgt, src, -1, format, change, dir);
    return std::string(tgt);
}
static void TestAlterName169()
{
    // ASCII: the same bytes as the old algorithm, every format and mode, random names
    const char alphabet[] = "aAbBzZ09 .-_~!";
    unsigned seed = 169;
    int compared = 0, differ = 0;
    for (int run = 0; run < 4000; run++)
    {
        char name[24];
        seed = seed * 1103515245u + 12345u;
        int len = 1 + (int)((seed >> 8) % 20);
        for (int i = 0; i < len; i++)
        {
            seed = seed * 1103515245u + 12345u;
            name[i] = alphabet[(seed >> 8) % (sizeof(alphabet) - 1)];
        }
        name[len] = 0;
        for (int format = 1; format <= 7; format++)
            for (int change = 0; change <= 2; change++)
                for (int dir = 0; dir <= 1; dir++)
                {
                    char a[64], b[64], n1[24], n2[24];
                    strcpy(n1, name);
                    strcpy(n2, name);
                    OldAlter169(a, n1, format, change, dir);
                    SalAlterFileNameU8(b, n2, -1, format, change, dir);
                    compared++;
                    if (strcmp(a, b) != 0 || strcmp(n1, name) != 0 || strcmp(n2, name) != 0)
                        differ++;
                }
    }
    CHECK(differ == 0);
    printf("TestAlterName169: %d ASCII cases against the old algorithm, %d differ\n", compared, differ);

    // UTF-8: whole letters (the probe's names)
    CHECK(Alter169("\xC5\xA0\xC3\x81RKA.TXT", 2) == "\xC5\xA1\xC3\xA1rka.txt");                       // S-caron A-acute -> lower
    CHECK(Alter169("\xC5\xBElu\xC5\xA5ou\xC4\x8Dk\xC3\xBD k\xC5\xAF\xC5\x88.txt", 3) ==
          "\xC5\xBDLU\xC5\xA4OU\xC4\x8CK\xC3\x9D K\xC5\xAE\xC5\x87.TXT");                              // zlutoucky kun -> upper
    CHECK(Alter169("\xCE\xB5\xCE\xBB\xCE\xBB\xCE\xB7\xCE\xBD\xCE\xB9\xCE\xBA\xCE\xB1.txt", 3) ==
          "\xCE\x95\xCE\x9B\xCE\x9B\xCE\x97\xCE\x9D\xCE\x99\xCE\x9A\xCE\x91.TXT");                      // Greek -> upper
    CHECK(Alter169("\xD0\xBF\xD1\x80\xD0\xB8\xD0\xB2\xD0\xB5\xD1\x82 \xD0\xBC\xD0\xB8\xD1\x80.txt", 1) ==
          "\xD0\x9F\xD1\x80\xD0\xB8\xD0\xB2\xD0\xB5\xD1\x82 \xD0\x9C\xD0\xB8\xD1\x80.Txt");             // Cyrillic, words capitalized
    CHECK(Alter169("\xC4\x8C" "ERN\xC3\x81 KO\xC4\x8C" "KA.TXT", 7) == "\xC4\x8C" "ern\xC3\xA1 Ko\xC4\x8D" "ka.txt"); // name mixed, ext lower
    CHECK(Alter169("\xC5\xA0\xC3\x81RKA.TXT", 2, 1) == "\xC5\xA1\xC3\xA1rka.TXT");                     // only the name
    CHECK(Alter169("\xC5\xA1rka.\xC4\x8D" "ap", 3, 2) == "\xC5\xA1rka.\xC4\x8C" "AP");                   // only the extension
    // the length is kept: a letter whose pair has another UTF-8 length stays
    CHECK(Alter169("\xC4\xB0stanbul", 2) == "\xC4\xB0stanbul");     // U+0130 (lower: i, 1 byte)
    CHECK(Alter169("\xC4\xB1zmir", 3) == "\xC4\xB1ZMIR");             // U+0131 (upper: I, 1 byte)
    CHECK(Alter169("stra\xC3\x9F" "e", 3) == "STRA\xC3\x9F" "E");     // sharp s has no 2-byte capital
    // bytes that are no letter are copied: an emoji, an invalid byte, a WTF-8 lone surrogate
    CHECK(Alter169("a\xF0\x9F\x98\x80" "b.TXT", 2) == "a\xF0\x9F\x98\x80" "b.txt");
    CHECK(Alter169("A\xFF" "B", 2) == "a\xFF" "b");
    CHECK(Alter169("A\xED\xA0\x80" "B", 2) == "a\xED\xA0\x80" "b");
    CHECK(Alter169("A\xC3", 2) == "a\xC3"); // a cut sequence at the end
    // the explorer style: an 8.3 capital ASCII name only
    CHECK(Alter169("README.TXT", 5) == "Readme.txt");
    CHECK(Alter169("\xC4\x8C" "TI.TXT", 5) == "\xC4\x8C" "TI.TXT"); // not ASCII: not a DOS name, unchanged
    // the length guard really works: Windows maps U+023A (2 bytes) to U+2C65 (3 bytes) - kept
    {
        WCHAR in[1] = {0x023A}, out[4] = {0};
        int n = LCMapStringEx(LOCALE_NAME_INVARIANT, LCMAP_LOWERCASE, in, 1, out, 4, NULL, NULL, 0);
        CHECK(n == 1 && out[0] == 0x2C65);
        CHECK(Alter169("\xC8\xBA" "B", 2) == "\xC8\xBA" "b");
    }
    // the cost the panel pays with a name format other than "as is" (RefreshListBox maps every
    // item): 100,000 names of 20 CJK letters and 100,000 of 20 Czech letters
    {
        std::string cjk, cz;
        for (int i = 0; i < 20; i++)
        {
            cjk += "\xE4\xB8\xAD";
            cz += "\xC5\xA1";
        }
        cjk += ".txt";
        cz += ".txt";
        LARGE_INTEGER f, t0, t1, t2;
        QueryPerformanceFrequency(&f);
        QueryPerformanceCounter(&t0);
        char tgt[256], src[256];
        for (int i = 0; i < 100000; i++)
        {
            strcpy(src, cjk.c_str());
            SalAlterFileNameU8(tgt, src, -1, 1, 0, FALSE);
        }
        QueryPerformanceCounter(&t1);
        for (int i = 0; i < 100000; i++)
        {
            strcpy(src, cz.c_str());
            SalAlterFileNameU8(tgt, src, -1, 1, 0, FALSE);
        }
        QueryPerformanceCounter(&t2);
        double msCjk = 1000.0 * (t1.QuadPart - t0.QuadPart) / f.QuadPart;
        double msCz = 1000.0 * (t2.QuadPart - t1.QuadPart) / f.QuadPart;
        printf("TestAlterName169: 100,000 names of 20 CJK letters %.0f ms, of 20 Czech letters %.0f ms\n", msCjk, msCz);
    }
    // the result never outgrows the source
    {
        const char* names[] = {"\xC4\xB0\xC4\xB1\xC3\x9F\xC5\xBF", "\xC8\xBA\xC8\xBE", "\xE1\xBA\x9E"};
        bool same = true;
        for (const char* n : names)
            for (int f = 1; f <= 7; f++)
                if (Alter169(n, f).size() != strlen(n))
                    same = false;
        CHECK(same);
    }
}

// feature 181: the name a shortcut is loaded by (salshelllink.h) - whole, \\?\ from MAX_PATH
// characters on, a code-page name widened as before
static void TestShellLinkLoadName181()
{
    WCHAR* w = SalShellLinkLoadNameAlloc("C:\\a\\go.lnk");
    CHECK(w != NULL && wcscmp(w, L"C:\\a\\go.lnk") == 0);
    free(w);
    // 130 Czech letters: 260 bytes of UTF-8, fewer than MAX_PATH characters - plain, whole
    std::string cz = "C:\\";
    for (int i = 0; i < 130; i++)
        cz += "\xC4\x8D"; // c-caron
    cz += "\\go.lnk";
    w = SalShellLinkLoadNameAlloc(cz.c_str());
    CHECK(w != NULL && wcslen(w) == 3 + 130 + 7 && wcsncmp(w, L"\\\\?\\", 4) != 0 && w[3] == 0x10D);
    free(w);
    // more than MAX_PATH characters: the \\?\ form, whole
    std::string lat = "C:\\" + std::string(300, 'x') + "\\go.lnk";
    w = SalShellLinkLoadNameAlloc(lat.c_str());
    CHECK(w != NULL && wcsncmp(w, L"\\\\?\\C:\\", 7) == 0 && wcslen(w) == 4 + lat.size());
    free(w);
    // not UTF-8 (a code-page byte): widened, not refused
    w = SalShellLinkLoadNameAlloc("C:\\\xE8.lnk");
    CHECK(w != NULL && wcslen(w) == 8);
    free(w);
    CHECK(SalShellLinkLoadNameAlloc(NULL) == NULL);
}

// feature 197: a reparse directory is deleted as a LINK unless it is proven a plain one - the delete
// emptied a junction whose destination could not be read (a path of 780+ characters): the files
// of its target were deleted
static void TestDeleteAsDirLink197()
{
    CHECK(SalDeleteAsDirLinkDecision(TRUE, FALSE, 0));                          // destination read
    CHECK(SalDeleteAsDirLinkDecision(TRUE, TRUE, 0x9000001A));                  // read wins over any tag
    CHECK(SalDeleteAsDirLinkDecision(FALSE, FALSE, 0));                         // nothing known: a link
    CHECK(SalDeleteAsDirLinkDecision(FALSE, TRUE, IO_REPARSE_TAG_MOUNT_POINT)); // a junction not parsed
    CHECK(SalDeleteAsDirLinkDecision(FALSE, TRUE, IO_REPARSE_TAG_SYMLINK));
    CHECK(SalDeleteAsDirLinkDecision(FALSE, TRUE, 0xA000001D));  // LX_SYMLINK: a surrogate
    CHECK(!SalDeleteAsDirLinkDecision(FALSE, TRUE, 0x9000001A)); // CLOUD: a plain directory (062 C3)
    CHECK(!SalDeleteAsDirLinkDecision(FALSE, TRUE, 0x80000021)); // ONEDRIVE
    CHECK(!SalDeleteAsDirLinkDecision(FALSE, TRUE, 0));          // no reparse point (any more)
}

// feature 253: Change Attributes on a directory link changes the link's own compression and times
// (opened with FILE_FLAG_OPEN_REPARSE_POINT) and refuses an encryption change - the target folder
// was compressed, uncompressed and re-timed through the link
static void TestAttrsLink253()
{
    const DWORD dir = FILE_ATTRIBUTE_DIRECTORY;
    const DWORD rp = FILE_ATTRIBUTE_REPARSE_POINT;
    const DWORD enc = FILE_ATTRIBUTE_ENCRYPTED;
    CHECK(SalAttrsEntryIsDirLink(dir | rp, TRUE));                               // a junction
    CHECK(SalAttrsEntryIsDirLink(dir | rp | FILE_ATTRIBUTE_HIDDEN | enc, TRUE)); // other bits do not matter
    CHECK(!SalAttrsEntryIsDirLink(dir | rp, FALSE));                             // a cloud placeholder folder
    CHECK(!SalAttrsEntryIsDirLink(dir, TRUE));                                   // a plain folder
    CHECK(!SalAttrsEntryIsDirLink(rp | FILE_ATTRIBUTE_ARCHIVE, TRUE));           // a file symbolic link: unchanged
    CHECK(!SalAttrsEntryIsDirLink(0, FALSE));

    CHECK(SalAttrsOpenFlags(FALSE, FALSE) == 0);                                                         // a file
    CHECK(SalAttrsOpenFlags(FALSE, TRUE) == 0);                                                          // never for a file
    CHECK(SalAttrsOpenFlags(TRUE, FALSE) == FILE_FLAG_BACKUP_SEMANTICS);                                 // a plain folder: as before
    CHECK(SalAttrsOpenFlags(TRUE, TRUE) == (FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT)); // the link itself

    CHECK(SalAttrsLinkRefusesEncryption(TRUE, TRUE, dir | rp, dir | rp | enc));                    // encrypt a link
    CHECK(SalAttrsLinkRefusesEncryption(TRUE, TRUE, dir | rp | enc, dir | rp));                    // decrypt a link
    CHECK(!SalAttrsLinkRefusesEncryption(TRUE, TRUE, dir | rp | enc, dir | rp | enc));             // already encrypted
    CHECK(!SalAttrsLinkRefusesEncryption(TRUE, TRUE, dir | rp, dir | rp | FILE_ATTRIBUTE_HIDDEN)); // stays unencrypted
    CHECK(!SalAttrsLinkRefusesEncryption(TRUE, FALSE, dir | rp, dir | rp | enc));                  // encryption not changed
    CHECK(!SalAttrsLinkRefusesEncryption(FALSE, TRUE, dir, dir | enc));                            // not a link: encrypted as before
}

// feature 222: a name's whole-character prefix within UTF-16 units and bytes
static void TestNamePrefixBytes222()
{
    CHECK(SalNamePrefixBytesU8("abc", 255, 256) == 3);
    CHECK(SalNamePrefixBytesU8("abc", 2, 256) == 2);                                  // units
    CHECK(SalNamePrefixBytesU8("abc", 255, 1) == 1);                                  // bytes
    CHECK(SalNamePrefixBytesU8("\xC5\xA1\xC5\xA1", 255, 3) == 2);               // never half a letter
    CHECK(SalNamePrefixBytesU8("\xE4\xB8\x80\xE4\xB8\x80", 1, 256) == 3);     // CJK: 1 unit
    CHECK(SalNamePrefixBytesU8("\xF0\x9F\x98\x80x", 1, 256) == 0);              // an emoji: 2 units
    CHECK(SalNamePrefixBytesU8("\xF0\x9F\x98\x80x", 3, 256) == 5);
    CHECK(SalNamePrefixBytesU8("", 255, 256) == 0);
    std::string cjk;
    for (int i = 0; i < 90; i++)
        cjk += "\xE4\xB8\x80"; // 90 letters, 270 bytes, 90 units
    CHECK(SalNamePrefixBytesU8(cjk.c_str(), 255, 256) == 255);  // the byte bound: 85 letters
    CHECK(SalNamePrefixBytesU8(cjk.c_str(), 255, 780) == 270);  // within 255 units: whole
    CHECK(!SalNameTooLongForFileSystemU8(cjk.c_str()));          // a valid name (it was "invalid")
}

// feature 262: the Code Viewer reads a single-byte file through the product's conversion tables;
// the two tables are convert/centeuro/c8521250.tab and iso21250.tab byte for byte
static const char g_tabC852To1250_262[] =
    "\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0B\x0C\x0D\x0E\x0F"
    "\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1A\x1B\x1C\x1D\x1E\x1F"
    "\x20\x21\x22\x23\x24\x25\x26\x27\x28\x29\x2A\x2B\x2C\x2D\x2E\x2F"
    "\x30\x31\x32\x33\x34\x35\x36\x37\x38\x39\x3A\x3B\x3C\x3D\x3E\x3F"
    "\x40\x41\x42\x43\x44\x45\x46\x47\x48\x49\x4A\x4B\x4C\x4D\x4E\x4F"
    "\x50\x51\x52\x53\x54\x55\x56\x57\x58\x59\x5A\x5B\x5C\x5D\x5E\x5F"
    "\x60\x61\x62\x63\x64\x65\x66\x67\x68\x69\x6A\x6B\x6C\x6D\x6E\x6F"
    "\x70\x71\x72\x73\x74\x75\x76\x77\x78\x79\x7A\x7B\x7C\x7D\x7E\x7F"
    "\xC7\xFC\xE9\xE2\xE4\xF9\xE6\xE7\xB3\xEB\xD5\xF5\xEE\x8F\xC4\xC6"
    "\xC9\xC5\xE5\xF4\xF6\xBC\xBE\x8C\x9C\xD6\xDC\x8D\x9D\xA3\xD7\xE8"
    "\xE1\xED\xF3\xFA\xA5\xB9\x8E\x9E\xCA\xEA\xAC\x9F\xC8\xBA\xAB\xBB"
    "\x2D\x2D\x2D\x7C\x2B\xC1\xC2\xCC\xAA\x2B\x7C\x2B\x2B\xAF\xBF\x2B"
    "\x2B\x2B\x2B\x2B\x2D\x2B\xC3\xE3\x2B\x2B\x2B\x2B\x2B\x2D\x2B\xA4"
    "\xF0\xD0\xCF\xCB\xEF\xD2\xCD\xCE\xEC\x2B\x2B\x2D\x2D\xDE\xD9\x2D"
    "\xD3\xDF\xD4\xD1\xF1\xF2\x8A\x9A\xC0\xDA\xE0\xDB\xFD\xDD\xFE\xB4"
    "\xAD\xBD\xB2\xA1\xA2\xA7\xF7\xB8\xB0\xA8\xFF\xFB\xD8\xF8\x2D\xA0";
static const char g_tabIso2To1250_262[] =
    "\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0B\x0C\x0D\x0E\x0F"
    "\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1A\x1B\x1C\x1D\x1E\x1F"
    "\x20\x21\x22\x23\x24\x25\x26\x27\x28\x29\x2A\x2B\x2C\x2D\x2E\x2F"
    "\x30\x31\x32\x33\x34\x35\x36\x37\x38\x39\x3A\x3B\x3C\x3D\x3E\x3F"
    "\x40\x41\x42\x43\x44\x45\x46\x47\x48\x49\x4A\x4B\x4C\x4D\x4E\x4F"
    "\x50\x51\x52\x53\x54\x55\x56\x57\x58\x59\x5A\x5B\x5C\x5D\x5E\x5F"
    "\x60\x61\x62\x63\x64\x65\x66\x67\x68\x69\x6A\x6B\x6C\x6D\x6E\x6F"
    "\x70\x71\x72\x73\x74\x75\x76\x77\x78\x79\x7A\x7B\x7C\x7D\x7E\x7F"
    "\x3F\x3F\x3F\x3F\x3F\x3F\x3F\x3F\x3F\x3F\x3F\x3F\x3F\x3F\x3F\x3F"
    "\x3F\x3F\x3F\x3F\x3F\x3F\x3F\x3F\x3F\x3F\x3F\x3F\x3F\x3F\x3F\x3F"
    "\xA0\xA5\xA2\xA3\xA4\xBC\x8C\xA7\xA8\x8A\xAA\x8D\x8F\xAD\x8E\xAF"
    "\xB0\xB9\xB2\xB3\xB4\xBE\x9C\xA1\xB8\x9A\xBA\x9D\x9F\xBD\x9E\xBF"
    "\xC0\xC1\xC2\xC3\xC4\xC5\xC6\xC7\xC8\xC9\xCA\xCB\xCC\xCD\xCE\xCF"
    "\xD0\xD1\xD2\xD3\xD4\xD5\xD6\xD7\xD8\xD9\xDA\xDB\xDC\xDD\xDE\xDF"
    "\xE0\xE1\xE2\xE3\xE4\xE5\xE6\xE7\xE8\xE9\xEA\xEB\xEC\xED\xEE\xEF"
    "\xF0\xF1\xF2\xF3\xF4\xF5\xF6\xF7\xF8\xF9\xFA\xFB\xFC\xFD\xFE\xFF";

// the bytes through 'table' (NULL = none), read in code page 1250 - what the Code Viewer does
// on a CP1250 machine
static std::wstring CodeTableDecode262(const char* bytes, const char* table)
{
    std::string b(bytes);
    SalCodeTableApply((unsigned char*)&b[0], b.size(), table);
    int n = MultiByteToWideChar(1250, 0, b.data(), (int)b.size(), NULL, 0);
    std::wstring w(n, L'\0');
    MultiByteToWideChar(1250, 0, b.data(), (int)b.size(), &w[0], n);
    return w;
}

static void TestCodeTable262()
{
    CHECK(sizeof(g_tabC852To1250_262) == 257 && sizeof(g_tabIso2To1250_262) == 257);
    const wchar_t* want = L"Příliš žluťoučký kůň úpěl "
                          L"ďábelské ódy";
    // the first lines of the corpus files src/plugins/codeview/test/corpus/encodings/
    const char* cp852 = "P\xFD\xA1li\xE7 \xA7lu\x9Cou\x9Fk\xEC k\x85\xE5 \xA3p\xD8l \xD4\xA0" "belsk\x82 \xA2" "dy";
    const char* iso2 = "P\xF8\xEDli\xB9 \xBElu\xBBou\xE8k\xFD k\xF9\xF2 \xFAp\xECl \xEF\xE1" "belsk\xE9 \xF3" "dy";
    CHECK(CodeTableDecode262(cp852, g_tabC852To1250_262) == want);
    CHECK(CodeTableDecode262(iso2, g_tabIso2To1250_262) == want);
    // negative controls: without the table (the system code page alone) the letters are wrong
    CHECK(CodeTableDecode262(cp852, NULL) != want);
    CHECK(CodeTableDecode262(iso2, NULL) != want);
    // ASCII and the line ends pass unchanged
    std::string ascii = "int main() {\r\n\treturn 0;\n}";
    std::string a = ascii;
    SalCodeTableApply((unsigned char*)&a[0], a.size(), g_tabC852To1250_262);
    CHECK(a == ascii);
    SalCodeTableApply(NULL, 5, g_tabC852To1250_262); // no crash
    a = ascii;
    SalCodeTableApply((unsigned char*)&a[0], a.size(), NULL); // no table = unchanged
    CHECK(a == ascii);

    // display name
    CHECK(SalCodeTableDisplayName("CP852 - CP1250") == "CP852 - CP1250");
    CHECK(SalCodeTableDisplayName("&KOI8-R - CP1251") == "KOI8-R - CP1251");
    CHECK(SalCodeTableDisplayName("A && B") == "A & B");
    CHECK(SalCodeTableDisplayName("Cork - CP1250 ") == "Cork - CP1250");
    CHECK(SalCodeTableDisplayName("x&") == "x");
    CHECK(SalCodeTableDisplayName(NULL).empty());
    CHECK(SalCodeTableDisplayName("Kamenick\xFD") == "Kamenick\xFD"); // code-page bytes kept

    // cycling over 5 fixed positions + 3 tables, and over the five alone (no tables)
    CHECK(SalCodeTableCycle(0, 1, 8) == 1);
    CHECK(SalCodeTableCycle(7, 1, 8) == 0);
    CHECK(SalCodeTableCycle(0, -1, 8) == 7);
    CHECK(SalCodeTableCycle(4, 1, 8) == 5);
    CHECK(SalCodeTableCycle(4, 1, 5) == 0);
    CHECK(SalCodeTableCycle(0, -1, 5) == 4);
    CHECK(SalCodeTableCycle(99, 1, 5) == 1); // out of range counts as 0
    CHECK(SalCodeTableCycle(3, 1, 0) == 0);

    // positions <-> encoding / table
    int enc = -2, tab = -2;
    CHECK(SalCodeTableFromPos(0, 3, &enc, &tab) && enc == 0 && tab == -1);
    CHECK(SalCodeTableFromPos(4, 3, &enc, &tab) && enc == SAL_CODETABLE_ANSI && tab == -1);
    CHECK(SalCodeTableFromPos(5, 3, &enc, &tab) && enc == SAL_CODETABLE_ANSI && tab == 0);
    CHECK(SalCodeTableFromPos(7, 3, &enc, &tab) && enc == SAL_CODETABLE_ANSI && tab == 2);
    CHECK(!SalCodeTableFromPos(8, 3, &enc, &tab));
    CHECK(!SalCodeTableFromPos(-1, 3, &enc, &tab));
    CHECK(!SalCodeTableFromPos(5, 0, &enc, &tab)); // no tables: only the five
    CHECK(SalCodeTableListPos(2, -1) == 2 && SalCodeTableListPos(4, -1) == 4);
    CHECK(SalCodeTableListPos(4, 0) == 5 && SalCodeTableListPos(4, 2) == 7);
    for (int p = 0; p < 8; p++)
        CHECK(SalCodeTableFromPos(p, 3, &enc, &tab) && SalCodeTableListPos(enc, tab) == p);

    // which table a single-byte file gets (data-model.md)
    CHECK(SalCodeTableToUse(-1, -1, -1) == -1); // default: the system code page (as before)
    CHECK(SalCodeTableToUse(-1, -1, 2) == 2);   // detect + remembered
    CHECK(SalCodeTableToUse(-1, 5, -1) == -1);  // a stale forced table is ignored when detecting
    CHECK(SalCodeTableToUse(4, -1, 2) == -1);   // "System code page" chosen
    CHECK(SalCodeTableToUse(4, 1, 2) == 1);     // a table chosen
    CHECK(SalCodeTableToUse(0, 1, 2) == -1);    // UTF-8 forced
    CHECK(SalCodeTableToUse(3, -1, 2) == -1);   // UTF-16 BE forced

    // the remembered name is found byte for byte; separators (NULL) are not counted
    const char* names[] = {NULL, "ISO-8859-2 - CP1250", "CP852 - CP1250", NULL, "Cork - CP1250 ", "Kamenick\xFD"};
    CHECK(SalCodeTableFindName(names, 6, "ISO-8859-2 - CP1250") == 0);
    CHECK(SalCodeTableFindName(names, 6, "CP852 - CP1250") == 1);
    CHECK(SalCodeTableFindName(names, 6, "Cork - CP1250 ") == 2);
    CHECK(SalCodeTableFindName(names, 6, "Kamenick\xFD") == 3);
    CHECK(SalCodeTableFindName(names, 6, "cp852 - cp1250") == -1); // no folding
    CHECK(SalCodeTableFindName(names, 6, "CP852-CP1250") == -1);
    CHECK(SalCodeTableFindName(names, 6, "Cork - CP1250") == -1);
    CHECK(SalCodeTableFindName(names, 6, "") == -1);
    CHECK(SalCodeTableFindName(names, 6, NULL) == -1);
    CHECK(SalCodeTableFindName(names, 2, "CP852 - CP1250") == -1); // beyond 'count'
}

// feature 260: the disk cache's temporary copy - the Windows path limit (UTF-16 units) in the long
// mode, the historical 260 bytes otherwise
static void TestCacheTmpPath260()
{
    const char* folder = "C:\\Users\\pavel\\AppData\\Local\\Temp\\SAL6D8.tmp\\";
    const int f = (int)strlen(folder); // ASCII: units = bytes
    std::string cjk;
    for (int i = 0; i < 90; i++)
        cjk += "\xE4\xB8\x80";
    cjk += ".txt"; // 274 bytes, 94 units
    CHECK(SalCacheTmpPathFitsU8(folder, "short.txt", FALSE));
    CHECK(SalCacheTmpPathFitsU8(folder, "short.txt", TRUE));
    CHECK(!SalCacheTmpPathFitsU8(folder, cjk.c_str(), FALSE)); // over 260 bytes: refused as before
    CHECK(SalCacheTmpPathFitsU8(folder, cjk.c_str(), TRUE));   // about 140 units: fits
    std::string fit(MAX_PATH - 1 - f, 'a'), over(MAX_PATH - f, 'a');
    CHECK(SalCacheTmpPathFitsU8(folder, fit.c_str(), TRUE));    // 259 units
    CHECK(!SalCacheTmpPathFitsU8(folder, over.c_str(), TRUE));  // 260 units
    CHECK(SalCacheTmpPathFitsU8(folder, fit.c_str(), FALSE));   // 259 bytes + the terminator
    CHECK(!SalCacheTmpPathFitsU8(folder, over.c_str(), FALSE)); // 260 bytes + the terminator
    std::string emoji;
    for (int i = 0; i < (MAX_PATH - 1 - f) / 2; i++)
        emoji += "\xF0\x9F\x98\x80"; // 2 units, 4 bytes each
    std::string rest((MAX_PATH - 1 - f) % 2, 'x');
    CHECK(SalCacheTmpPathFitsU8(folder, (emoji + rest).c_str(), TRUE));        // 259 units
    CHECK(!SalCacheTmpPathFitsU8(folder, (emoji + rest + "y").c_str(), TRUE)); // 260 units
    std::string cjkFit;
    for (int i = 0; i < MAX_PATH - 1 - f; i++)
        cjkFit += "\xE4\xB8\x80"; // 1 unit, 3 bytes each: more than 600 bytes
    CHECK(SalCacheTmpPathFitsU8(folder, cjkFit.c_str(), TRUE));
    CHECK(!SalCacheTmpPathFitsU8(folder, (cjkFit + "\xE4\xB8\x80").c_str(), TRUE));
    CHECK(!SalCacheTmpPathFitsU8(folder, cjkFit.c_str(), FALSE));
    CHECK(!SalCacheTmpPathFitsU8(NULL, "x", TRUE));
    CHECK(!SalCacheTmpPathFitsU8(folder, NULL, FALSE));
}

// feature 219: a link's stored name in the long / NT form is the path it names
static void TestReparseNameAsPath219()
{
    struct
    {
        const WCHAR* in;
        const WCHAR* out;
    } cases[] = {
        {L"\\\\?\\C:\\x\\y", L"C:\\x\\y"},
        {L"\\??\\C:\\x", L"C:\\x"},
        {L"\\\\?\\UNC\\srv\\share\\d", L"\\\\srv\\share\\d"},
        {L"\\??\\UNC\\srv\\share", L"\\\\srv\\share"},
        {L"\\\\?\\unc\\srv\\s", L"\\\\srv\\s"},
        {L"C:\\x", L"C:\\x"},                                                                                               // plain: as is
        {L"..\\rel", L"..\\rel"},                                                                                           // relative: as is
        {L"\\??\\Volume{12345678-0000-0000-0000-000000000000}\\", L"\\??\\Volume{12345678-0000-0000-0000-000000000000}\\"}, // a volume
        {L"\\\\?\\GLOBALROOT\\Device\\X", L"\\\\?\\GLOBALROOT\\Device\\X"},
        {L"\\\\?\\C:", L"\\\\?\\C:"},               // no root: as is
        {L"\\\\?\\C:\\dir.", L"\\\\?\\C:\\dir."},   // a trailing dot: kept long
        {L"\\\\?\\C:\\a \\b", L"\\\\?\\C:\\a \\b"}, // a component ending with a space
        {L"\\\\?\\C:\\a.b\\c", L"C:\\a.b\\c"},      // a dot inside: plain
        {L"\\\\?\\UNC\\", L"\\\\?\\UNC\\"},         // no server
        {L"", L""},
    };
    for (int i = 0; i < (int)_countof(cases); i++)
    {
        WCHAR buf[200];
        wcscpy_s(buf, cases[i].in);
        CHECK(wcscmp(SalReparseNameAsPath(buf), cases[i].out) == 0);
    }
}

// feature 189: a REG_MULTI_SZ list as one line (salmultisz.h) - the NULs at the end are the end
// whatever their number (one NUL showed a trailing space), the ones inside are separators
// feature 203: a create whose 8.3 clash could not be moved aside never reports "it exists" (the
// callers took that for the target: the other file offered for overwriting, a folder merged)
static void TestShortNameClashError203()
{
    CHECK(SalShortNameClashError(ERROR_SHARING_VIOLATION) == ERROR_SHARING_VIOLATION); // held open
    CHECK(SalShortNameClashError(ERROR_ACCESS_DENIED) == ERROR_ACCESS_DENIED);
    CHECK(SalShortNameClashError(ERROR_NOT_ENOUGH_MEMORY) == ERROR_NOT_ENOUGH_MEMORY);
    CHECK(SalShortNameClashError(ERROR_FILENAME_EXCED_RANGE) == ERROR_FILENAME_EXCED_RANGE);
    CHECK(SalShortNameClashError(ERROR_FILE_EXISTS) == ERROR_ACCESS_DENIED); // never "exists"
    CHECK(SalShortNameClashError(ERROR_ALREADY_EXISTS) == ERROR_ACCESS_DENIED);
    CHECK(SalShortNameClashError(ERROR_SUCCESS) == ERROR_ACCESS_DENIED); // never success
}

// feature 204: a path component found only as ANOTHER entry's short name is not that entry's own
static void TestNameIsOnlyShortNameOf204()
{
    CHECK(SalNameIsOnlyShortNameOf("LONGDI~1", -1, "longdirname", "LONGDI~1"));
    CHECK(SalNameIsOnlyShortNameOf("longdi~1", -1, "longdirname", "LONGDI~1"));       // the 092 rule
    CHECK(SalNameIsOnlyShortNameOf("LONGDI~1\\a.txt", 8, "longdirname", "LONGDI~1")); // a component
    CHECK(!SalNameIsOnlyShortNameOf("LONGDI~1", -1, "LONGDI~1", ""));                 // the entry's own name
    CHECK(!SalNameIsOnlyShortNameOf("LONGDI~1", -1, "longdi~1", "LONGDI~1"));         // own, other case
    CHECK(!SalNameIsOnlyShortNameOf("Ab.txt", -1, "Ab.txt", "AB.TXT"));               // FAT: short differs by case
    CHECK(!SalNameIsOnlyShortNameOf("longdirname", -1, "longdirname", "LONGDI~1"));
    CHECK(!SalNameIsOnlyShortNameOf("LONGDI~1", -1, "longdirname", "")); // no short name reported
    CHECK(!SalNameIsOnlyShortNameOf("LONGDI~1", -1, "longdirname", NULL));
    CHECK(!SalNameIsOnlyShortNameOf("LONGDI~2", -1, "longdirname", "LONGDI~1"));

    // the components that are never looked up (no false "cannot be a short name")
    CHECK(SalNameCanBeShortName("LONGDI~1", -1));
    CHECK(SalNameCanBeShortName("LONGFI~1.TXT", -1));
    CHECK(SalNameCanBeShortName("A", -1));
    CHECK(SalNameCanBeShortName("ABCDEFGH.XYZ", -1));
    CHECK(SalNameCanBeShortName("\xC4\x8C\xC5\xA0~1.T\xC3\x9D", -1)); // OEM letters: counted as characters
    CHECK(SalNameCanBeShortName("LONGDI~1\\x", 8));                   // a component of a path
    CHECK(SalNameCanBeShortName("AB.", -1));                          // an empty extension
    CHECK(!SalNameCanBeShortName("ABCDEFGHI", -1));                   // a base of 9
    CHECK(!SalNameCanBeShortName("A.XYZW", -1));                      // an extension of 4
    CHECK(!SalNameCanBeShortName("A.B.C", -1));                       // two dots
    CHECK(!SalNameCanBeShortName("longdirname", -1));
    CHECK(!SalNameCanBeShortName(".git", -1));
    CHECK(!SalNameCanBeShortName(".", -1));
    CHECK(!SalNameCanBeShortName("..", -1));
    CHECK(!SalNameCanBeShortName("", -1));
}

// feature 210: the Renamer's case-insensitive search folds characters, not bytes - the code-page
// fold made C-dot (C4 8A) and E-caron (C4 9A) one letter and replaced the wrong one
static std::string Fold210(const char* s, BOOL onlyNonAscii)
{
    std::string r(s);
    SalU8FoldSameLength(s, (int)r.size(), &r[0], onlyNonAscii);
    return r;
}
static void TestU8Fold210()
{
    CHECK(Fold210("\xC5\xBD"
                  "lu\xC5\xA5",
                  FALSE) == "\xC5\xBE"
                            "lu\xC5\xA5");                           // Z-caron -> z-caron
    CHECK(Fold210("\xC4\x8A", FALSE) != Fold210("\xC4\x9A", FALSE)); // C-dot is not E-caron
    CHECK(Fold210("\xC4\x8A", FALSE) == "\xC4\x8B");                 // C-dot -> c-dot
    CHECK(Fold210("ABC", FALSE) == "abc");
    CHECK(Fold210("ABC\xC5\xBD", TRUE) == "ABC\xC5\xBE"); // ASCII left to the engine
    CHECK(Fold210("\xE4\xB8\xAD"
                  "A",
                  FALSE) == "\xE4\xB8\xAD"
                            "a");                            // CJK untouched
    CHECK(Fold210("\xC4\xB0", FALSE) == "\xC4\xB0");         // I-dot: its lower is 1 byte - kept
    CHECK(Fold210("\xC5\xBD\xC5", FALSE) == "\xC5\xBE\xC5"); // a torn tail copied
    CHECK(Fold210("\xED\xA0\x80"
                  "A",
                  FALSE) == "\xED\xA0\x80"
                            "a");                                    // a WTF-8 surrogate copied
    CHECK(Fold210("\xF0\x90\x90\x80", FALSE) == "\xF0\x90\x90\xA8"); // Deseret capital -> small (4 bytes)
    std::string big = "\xC4\x8C"
                      "ERN\xC3\x81"; // C-caron E R N A-acute
    CHECK(Fold210(big.c_str(), FALSE) == "\xC4\x8D"
                                         "ern\xC3\xA1");
    CHECK(Fold210(big.c_str(), FALSE).size() == big.size());

    // whole words by characters
    const char* t = "\xC5\xBElut\xC3\xBD k\xC5\xAF\xC5\x88.txt"; // z-caron lut y-acute k u-ring n-caron .txt
    int len = (int)strlen(t);
    CHECK(SalU8IsAlnumAt(t, len, 0));      // z-caron
    CHECK(SalU8IsAlnumBefore(t, len, 7));  // y-acute ends at 7
    CHECK(!SalU8IsAlnumAt(t, len, 7));     // the space
    CHECK(SalU8IsAlnumBefore(t, len, 13)); // n-caron ends at 13
    CHECK(!SalU8IsAlnumAt(t, len, 13));    // '.'
    CHECK(!SalU8IsAlnumBefore(t, len, 0));
    CHECK(!SalU8IsAlnumAt(t, len, len));

    // cut by characters
    const char* z = "\xC5\xBD"
                    "lu\xC5\xA5"; // Z-caron l u t-caron
    const char* ze = z + strlen(z);
    CHECK(SalU8Advance(z, ze, 1) == z + 2);
    CHECK(SalU8Advance(z, ze, 3) == z + 4);
    CHECK(SalU8Advance(z, ze, 9) == ze);
    CHECK(SalU8Back(ze, z, 1) == ze - 2);
    CHECK(SalU8Back(ze, z, 4) == z);
    CHECK(SalU8Back(ze, z, 9) == z);
    CHECK(SalU8Advance(z, ze, 0) == z);
}

// feature 254: the letters ("units") of a regular expression over UTF-8 names - the Renamer's
// engine stepped and classified single bytes (a split letter refused "(123)", a wrong letter
// replaced by '\b')
static std::vector<int> Units254(const char* s, int len) // the forward boundaries
{
    std::vector<int> b;
    int i = 0;
    while (i < len)
    {
        b.push_back(i);
        unsigned v;
        i += SalU8UnitLen(s + i, s + len, &v);
    }
    b.push_back(len);
    return b;
}
static BOOL BackMatches254(const char* s, int len) // stepping back gives the forward units
{
    std::vector<int> f = Units254(s, len);
    std::vector<int> b;
    const char* q = s + len;
    b.push_back(len);
    while (q > s)
    {
        q = SalU8UnitBack(s, q);
        b.push_back((int)(q - s));
    }
    std::reverse(b.begin(), b.end());
    if (b != f)
        return FALSE;
    for (int i = 0; i <= len; i++) // a boundary is exactly a forward position
        if ((SalU8IsUnitBoundary(s, s + len, s + i) != FALSE) != (std::find(f.begin(), f.end(), i) != f.end()))
            return FALSE;
    return TRUE;
}
static void TestU8Letter254()
{
    unsigned v = 0;
    CHECK(SalU8UnitLen("a", "a" + 1, &v) == 1 && v == 'a');
    const char* zc = "\xC5\xBE"; // z-caron
    CHECK(SalU8UnitLen(zc, zc + 2, &v) == 2 && v == 0x17E);
    const char* zh = "\xE4\xB8\xAD"; // CJK
    CHECK(SalU8UnitLen(zh, zh + 3, &v) == 3 && v == 0x4E2D);
    const char* ext = "\xF0\xA0\x80\x80"; // U+20000
    CHECK(SalU8UnitLen(ext, ext + 4, &v) == 4 && v == 0x20000);
    const char* sur = "\xED\xA0\x80"; // a WTF-8 lone surrogate: one unit
    CHECK(SalU8UnitLen(sur, sur + 3, &v) == 3 && v == 0xD800);
    CHECK(SalU8UnitLen(zc, zc + 1, &v) == 1 && v == SALU8_INVALID_BASE + 0xC5); // a torn letter
    const char* cont = "\xBE";
    CHECK(SalU8UnitLen(cont, cont + 1, &v) == 1 && v == SALU8_INVALID_BASE + 0xBE);
    const char* overlong = "\xC0\x80";
    CHECK(SalU8UnitLen(overlong, overlong + 2, &v) == 1 && v == SALU8_INVALID_BASE + 0xC0);
    CHECK(SalU8UnitLen(zh, zh + 2, &v) == 1); // truncated
    CHECK(SalU8UnitLen(zc, zc, &v) == 0);

    // back == forward, boundaries
    const char* mixed = "a\xC5\xBE\xF0\xA0\x80\x80\xED\xA0\x80\xBEz\xC5\xBE\xBE\xE4\xB8\xC5\xC0\x80\xF5\xD0\x96";
    CHECK(BackMatches254(mixed, (int)strlen(mixed)));
    const char* torn = "\xC5\xBE\xBE";
    CHECK(BackMatches254(torn, 3));
    CHECK(SalU8UnitBack(torn, torn + 3) == torn + 2);
    CHECK(SalU8UnitBack(torn, torn + 2) == torn);
    CHECK(SalU8UnitBack(torn + 1, torn + 2) == torn + 1); // never before 'start'
    CHECK(!SalU8IsUnitBoundary(zc, zc + 2, zc + 1));
    CHECK(!SalU8IsUnitBoundary(ext, ext + 4, ext + 3));
    CHECK(SalU8IsUnitBoundary(zh, zh + 2, zh + 1)); // a truncated sequence is bytes
    const char* cyr = "\xD0\x96\xD0\xB0\xD0\xB1\xD0\xB0.txt"; // Zh a b a .txt
    CHECK(BackMatches254(cyr, (int)strlen(cyr)));

    // classification
    CHECK(SalU8IcuCharType() != NULL); // icu.dll of Windows 10 1903+ / 11
    CHECK((SalU8LetterTypes(0x416) & (C1_ALPHA | C1_UPPER)) == (C1_ALPHA | C1_UPPER));
    CHECK((SalU8LetterTypes(0x430) & (C1_ALPHA | C1_LOWER)) == (C1_ALPHA | C1_LOWER));
    CHECK((SalU8LetterTypes(0x660) & C1_DIGIT) != 0);
    CHECK((SalU8LetterTypes(0x301) & SALU8_TYPE_MARK) != 0 && (SalU8LetterTypes(0x301) & C1_ALPHA) == 0);
    CHECK((SalU8LetterTypes(0x93E) & SALU8_TYPE_MARK) != 0); // a spacing mark (Windows types: none)
    CHECK((SalU8LetterTypes(0x20DD) & SALU8_TYPE_MARK) != 0); // an enclosing mark
    CHECK((SalU8LetterTypes(0xE9) & SALU8_TYPE_MARK) == 0);   // e-acute is a letter, not a mark
    CHECK((SalU8LetterTypes(0x20000) & C1_ALPHA) != 0);       // CJK outside the BMP
    CHECK((SalU8LetterTypes(0x1D400) & (C1_ALPHA | C1_UPPER)) == (C1_ALPHA | C1_UPPER));
    CHECK((SalU8LetterTypes(0x10428) & (C1_ALPHA | C1_LOWER)) == (C1_ALPHA | C1_LOWER)); // Deseret small
    CHECK((SalU8LetterTypes(0x1D7CE) & C1_DIGIT) != 0);
    CHECK((SalU8LetterTypes(0x1F4C1) & (C1_ALPHA | C1_DIGIT | SALU8_TYPE_MARK)) == 0); // an emoji
    CHECK((SalU8LetterTypes(0x3000) & C1_SPACE) != 0);
    CHECK(SalU8LetterTypes(SALU8_INVALID_BASE + 0xC5) == 0);
    CHECK(SalU8LetterTypes(0xD800) == 0);
    CHECK(SalU8IsWordValue('_') && !SalU8IsAlnumValue('_'));
    CHECK(SalU8IsWordValue('a') && SalU8IsWordValue('7') && !SalU8IsWordValue('-') && !SalU8IsWordValue('.'));
    CHECK(SalU8IsWordValue(0x301) && SalU8IsWordValue(0x20000) && SalU8IsWordValue(0x430));
    CHECK(!SalU8IsWordValue(0x1F4C1) && !SalU8IsWordValue(0xD800) && !SalU8IsWordValue(SALU8_INVALID_BASE + 0xB0));

    // plain whole words: a combining mark and a letter outside the BMP belong to the word
    const char* cafe = "Cafe\xCC\x81 x"; // C a f e U+0301 ' ' x
    int cl = (int)strlen(cafe);
    CHECK(SalU8IsAlnumAt(cafe, cl, 4));
    CHECK(SalU8IsAlnumBefore(cafe, cl, 6));
    CHECK(!SalU8IsAlnumAt(cafe, cl, 6));
    CHECK(SalU8IsAlnumAt(ext, 4, 0) && SalU8IsAlnumBefore(ext, 4, 4));
    CHECK(!SalU8IsAlnumBefore(zc, 2, 1)); // inside a letter: no unit ends there

    // the final sigma folds with sigma (plain and regex search)
    CHECK(SalU8FoldCodePoint(0x3C2) == 0x3C3 && SalU8FoldCodePoint(0x3A3) == 0x3C3 && SalU8FoldCodePoint(0x3C3) == 0x3C3);
    CHECK(SalU8FoldCodePoint(0x130) == 0x130); // I-dot: its lower case is 1 byte - kept (210)
    CHECK(Fold210("\xCF\x82", FALSE) == "\xCF\x83");
    CHECK(Fold210("\xCE\xBB\xCF\x8C\xCE\xB3\xCE\xBF\xCF\x82", TRUE) ==
          Fold210("\xCE\x9B\xCE\x8C\xCE\x93\xCE\x9F\xCE\xA3", TRUE)); // logos / LOGOS
}

// feature 226: the encoding of the User Menu's batch file
static std::string Batch226(const char* u8, UINT cp, CSalBatchEncoding* enc)
{
    char* out;
    int outLen;
    BOOL oom;
    *enc = SalBatchChooseEncoding(u8, (int)strlen(u8), cp, &out, &outLen, &oom);
    CHECK(!oom);
    std::string r = out != NULL ? std::string(out, (size_t)outLen) : std::string();
    if (out != NULL)
        CHECK((int)strlen(out) == outLen);
    free(out);
    return r;
}

static void TestBatchText226()
{
    CSalBatchEncoding e;
    CHECK(Batch226("call copy a.txt b.txt\r\n", 852, &e) == "call copy a.txt b.txt\r\n");
    CHECK(e == SALBATCH_OEM);
    // z-caron, r-caron, u-ring: in OEM 852 0xA7 0xFD 0x85 (CharToOem of the UTF-8 bytes gave other letters)
    CHECK(Batch226("\xC5\xBE\xC5\x99\xC5\xAF", 852, &e) == "\xA7\xFD\x85");
    CHECK(e == SALBATCH_OEM);
    // the same letters are not in OEM 437: UTF-8 (no best fit - z-caron is not "z")
    CHECK(Batch226("\xC5\xBE.txt", 437, &e).empty());
    CHECK(e == SALBATCH_UTF8);
    // CJK on a European system: UTF-8; in OEM 936 (Simplified Chinese): its two bytes
    CHECK(Batch226("\xE4\xB8\xAD", 852, &e).empty());
    CHECK(e == SALBATCH_UTF8);
    CHECK(Batch226("\xE4\xB8\xAD", 936, &e) == "\xD6\xD0");
    CHECK(e == SALBATCH_OEM);
    // a WTF-8 surrogate or a broken byte: refused, never written changed
    CHECK(Batch226("a\xED\xA0\x80.txt", 852, &e).empty());
    CHECK(e == SALBATCH_REFUSED);
    CHECK(Batch226("a\xC5.txt", 852, &e).empty());
    CHECK(e == SALBATCH_REFUSED);
    CHECK(Batch226("a\xED\xA0\x80.txt", CP_UTF8, &e).empty());
    CHECK(e == SALBATCH_REFUSED);
    // an OEM code page of 65001: the text as it is
    CHECK(Batch226("\xE4\xB8\xAD", CP_UTF8, &e) == "\xE4\xB8\xAD");
    CHECK(e == SALBATCH_OEM);
    // a character with only a best-fit form in 852 (a-grave): UTF-8
    CHECK(Batch226("\xC3\xA0", 852, &e).empty());
    CHECK(e == SALBATCH_UTF8);
    // empty text
    CHECK(Batch226("", 852, &e).empty());
    CHECK(e == SALBATCH_OEM);

    // the code-page lines run chcp.com by its full path (never a chcp.bat of the current folder)
    char line[SALBATCH_LINE_SIZE];
    // the absolute system folder when it is ASCII (a child environment may lack SystemRoot)
    SalBatchCodePageLine(65001, TRUE, "C:\\WINDOWS\\system32", line, (int)sizeof(line));
    CHECK(strcmp(line, "@\"C:\\WINDOWS\\system32\\chcp.com\" 65001>nul || exit /b 1\r\n") == 0);
    SalBatchCodePageLine(852, FALSE, "C:\\WINDOWS\\system32\\", line, (int)sizeof(line));
    CHECK(strcmp(line, "@\"C:\\WINDOWS\\system32\\chcp.com\" 852>nul\r\n") == 0);
    // otherwise (none, not ASCII, a quote or a percent sign in it) %SystemRoot%
    SalBatchCodePageLine(65001, TRUE, NULL, line, (int)sizeof(line));
    CHECK(strcmp(line, "@\"%SystemRoot%\\System32\\chcp.com\" 65001>nul || exit /b 1\r\n") == 0);
    SalBatchCodePageLine(852, FALSE, "", line, (int)sizeof(line));
    CHECK(strcmp(line, "@\"%SystemRoot%\\System32\\chcp.com\" 852>nul\r\n") == 0);
    SalBatchCodePageLine(852, FALSE, "C:\\W\xC5\xBE\\system32", line, (int)sizeof(line));
    CHECK(strcmp(line, "@\"%SystemRoot%\\System32\\chcp.com\" 852>nul\r\n") == 0);
    SalBatchCodePageLine(852, FALSE, "C:\\100%\\system32", line, (int)sizeof(line));
    CHECK(strcmp(line, "@\"%SystemRoot%\\System32\\chcp.com\" 852>nul\r\n") == 0);
    SalBatchCodePageLine(852, FALSE, "C:\\a\"b", line, (int)sizeof(line));
    CHECK(strcmp(line, "@\"%SystemRoot%\\System32\\chcp.com\" 852>nul\r\n") == 0);
    std::string longDir = "C:\\" + std::string(MAX_PATH - 4, 'd'); // MAX_PATH - 1 bytes: fits the line
    SalBatchCodePageLine(4294967295u, TRUE, longDir.c_str(), line, (int)sizeof(line));
    CHECK(strlen(line) < sizeof(line) - 1 && strstr(line, "|| exit /b 1\r\n") != NULL);
    CHECK(SalBatchIsAscii("call copy a b\r\n", 15));
    CHECK(SalBatchIsAscii("", 0));
    CHECK(!SalBatchIsAscii("a\xC5\xBE", 3));
    CHECK(!SalBatchIsAscii("\x80", 1));

    CSalBatchText t;
    CHECK(t.Text == NULL && t.Len == 0);
    CHECK(t.Append("@C:"));
    CHECK(t.Append("\r\nxyz", 2));
    CHECK(t.Len == 5 && strcmp(t.Text, "@C:\r\n") == 0);
    std::string big(1000, 'x');
    for (int i = 0; i < 100; i++)
        CHECK(t.Append(big.c_str()));
    CHECK(t.Len == 100005 && t.Text[t.Len] == 0 && t.Text[100004] == 'x');
    CHECK(!t.Append("x", -1));
    CHECK(!t.Append("x", 0x40000000));
    CHECK(t.Len == 100005);
}

// feature 229: the values the User Menu inserts into its batch file keep '%' (escaped) and report '^'
static std::string Esc229(const char* v, int rep)
{
    int len = (int)strlen(v);
    int n = SalBatchEscapedLen(v, len, rep);
    std::string out((size_t)n, '?');
    if (n > 0)
        SalBatchCopyEscaped(&out[0], v, len, rep);
    return out;
}

static void TestBatchEscape229()
{
    CHECK(Esc229("50%off.txt", 4) == "50%%%%off.txt"); // a "call" line: two expansions
    CHECK(Esc229("a%OS%b.txt", 4) == "a%%%%OS%%%%b.txt");
    CHECK(Esc229("p%OS%q", 2) == "p%%OS%%q"); // the "cd" line: one expansion
    CHECK(Esc229("plain \xC5\xBE.txt", 4) == "plain \xC5\xBE.txt");
    CHECK(Esc229("", 4).empty());
    CHECK(Esc229("%", 4) == "%%%%");
    CHECK(SalBatchEscapedLen("a%b%", 4, 4) == 10);
    CHECK(SalBatchEscapedLen("a%b%", 4, 1) == 4); // a repeat of 1: unchanged
    // refused: '^' anywhere; '&', '|', '<', '>' outside quotes only
    CHECK(SalBatchValueRefused("a^b.txt", 7, TRUE));
    CHECK(SalBatchValueRefused("a^b.txt", 7, FALSE));
    CHECK(!SalBatchValueRefused("a&b|c<d>e.txt", 13, TRUE));
    CHECK(SalBatchValueRefused("x&calc", 6, FALSE)); // unquoted: another command
    CHECK(SalBatchValueRefused("a|b", 3, FALSE));
    CHECK(SalBatchValueRefused("a>b", 3, FALSE));
    CHECK(SalBatchValueRefused("a<b", 3, FALSE));
    CHECK(!SalBatchValueRefused("a!b(c)d,e;f=g%h.txt", 19, FALSE));
    CHECK(!SalBatchValueRefused("a^b", 1, FALSE)); // only the given bytes
    CHECK(!SalBatchValueRefused("", 0, FALSE));
    // a '"' inside the value (a list's quotes) switches the state as for cmd
    CHECK(SalBatchValueRefused("\"C:\\a b&calc\"", 13, TRUE));   // ""C:\a b&calc"": the '&' outside
    CHECK(!SalBatchValueRefused("\"C:\\a b&calc\"", 13, FALSE)); // "C:\a b&calc": inside
    CHECK(SalBatchValueRefused("\"a b\" x&y", 9, FALSE));
    // a list name goes in quotes for a space and for cmd's delimiters and operators
    CHECK(SalListNameNeedsQuotes("a b.txt", 7));
    CHECK(SalListNameNeedsQuotes("Smith,John.txt", 14));
    CHECK(SalListNameNeedsQuotes("a;b", 3));
    CHECK(SalListNameNeedsQuotes("a=b", 3));
    CHECK(SalListNameNeedsQuotes("x&calc", 6));
    CHECK(SalListNameNeedsQuotes("a(1).txt", 8));
    CHECK(SalListNameNeedsQuotes("a^b", 3));
    CHECK(!SalListNameNeedsQuotes("50%off.txt", 10));
    CHECK(!SalListNameNeedsQuotes("a!b.txt", 7));
    CHECK(!SalListNameNeedsQuotes("\xC5\xBElu\xC5\xA5ou\xC4\x8Dk\xC3\xBD.txt", 17));
    CHECK(!SalListNameNeedsQuotes("a b", 1)); // only the given bytes
    // the quote state of the line before a value
    CHECK(!SalBatchInsideQuotes("copy /y ", 8));
    CHECK(SalBatchInsideQuotes("copy /y \"", 9));
    CHECK(!SalBatchInsideQuotes("copy /y \"a\" ", 12));
    CHECK(SalBatchInsideQuotes("\"x\" \"", 5));
    CHECK(!SalBatchInsideQuotes("\"", 0));
}

// feature 230: a listed name counts only as the byte-equal dragged name (a case-sensitive folder)
static void TestNameExactInCIRun230()
{
    char* names[] = {(char*)"A.txt", (char*)"a.txt", (char*)"b.txt", (char*)"B.TXT", (char*)"c"};
    int n = 5; // sorted case-insensitively: {A.txt, a.txt} {b.txt, B.TXT} {c}
    CHECK(SalNameExactInCIRun(names, n, 0, "a.txt") == 1);
    CHECK(SalNameExactInCIRun(names, n, 1, "a.txt") == 1);
    CHECK(SalNameExactInCIRun(names, n, 1, "A.txt") == 0);
    CHECK(SalNameExactInCIRun(names, n, 0, "A.TXT") == -1); // in the run, not byte-equal: another file
    CHECK(SalNameExactInCIRun(names, n, 2, "B.TXT") == 3);
    CHECK(SalNameExactInCIRun(names, n, 3, "b.txt") == 2);
    CHECK(SalNameExactInCIRun(names, n, 4, "c") == 4);
    CHECK(SalNameExactInCIRun(names, n, 4, "C") == -1);
    CHECK(SalNameExactInCIRun(names, n, -1, "c") == -1);
    CHECK(SalNameExactInCIRun(names, n, 5, "c") == -1);
    char* one[] = {(char*)"\xC5\xBElu\xC5\xA5"}; // z-caron l u t-caron
    CHECK(SalNameExactInCIRun(one, 1, 0, "\xC5\xBElu\xC5\xA5") == 0);
    CHECK(SalNameExactInCIRun(one, 1, 0, "\xC5\xBDlu\xC5\xA5") == -1); // Z-caron: another file
    for (int i = 0; i + 1 < n; i++)
        CHECK(SalNameCompareOrdinalCI(names[i], -1, names[i + 1], -1) <= 0); // the fixture is sorted
    // a run of three, the byte-equal entry last, the search index first
    char* three[] = {(char*)"AB", (char*)"Ab", (char*)"ab"};
    CHECK(SalNameExactInCIRun(three, 3, 0, "ab") == 2);
    CHECK(SalNameExactInCIRun(three, 3, 2, "AB") == 0);
    // the same name twice: the lowest index
    char* twice[] = {(char*)"x", (char*)"x"};
    CHECK(SalNameExactInCIRun(twice, 2, 1, "x") == 0);
    // a WTF-8 lone surrogate is a byte string like any other
    char* lone[] = {(char*)"a\xED\xA0\x80"};
    CHECK(SalNameExactInCIRun(lone, 1, 0, "a\xED\xA0\x80") == 0);
    CHECK(SalNameExactInCIRun(lone, 1, 0, "A\xED\xA0\x80") == -1);
    // the case-insensitive fallback only for a name alone in its run
    CHECK(SalNameCIRunSingle(names, n, 4) == 4);  // "c"
    CHECK(SalNameCIRunSingle(names, n, 0) == -1); // A.txt / a.txt
    CHECK(SalNameCIRunSingle(names, n, 1) == -1);
    CHECK(SalNameCIRunSingle(names, n, 3) == -1); // b.txt / B.TXT
    CHECK(SalNameCIRunSingle(one, 1, 0) == 0);
    CHECK(SalNameCIRunSingle(one, 1, 1) == -1);
    CHECK(SalNameCIRunSingle(one, 1, -1) == -1);
    // the fallback after the listing
    CHECK(SalNameCIFallbackTakes(FALSE, 1, FALSE));
    CHECK(!SalNameCIFallbackTakes(TRUE, 1, FALSE));  // a byte-equal item took the name
    CHECK(!SalNameCIFallbackTakes(FALSE, 2, FALSE)); // two items in other cases: which one?
    CHECK(!SalNameCIFallbackTakes(FALSE, 0, FALSE));
    CHECK(!SalNameCIFallbackTakes(FALSE, 1, TRUE)); // a case-sensitive folder: another file
}

// feature 261: lookups and Compare Directories pairing in folders with case twins (salnamerun.h).
// The merge below models mainwnd5.cpp's CmpDirsNames: the first key ignores a soft hyphen (U+00AD) as
// the product's locale key (RegSetStrICmpEx) does - coarser than the file system's ordinal rule.
struct Twin261List
{
    const char* Names[16];
    int Count;
};

static void Twin261Strip(const char* s, char* out, size_t size) // without soft hyphens (C2 AD)
{
    size_t k = 0;
    for (; *s != 0 && k + 1 < size; s++)
    {
        if ((unsigned char)s[0] == 0xC2 && (unsigned char)s[1] == 0xAD)
        {
            s++;
            continue;
        }
        out[k++] = *s;
    }
    out[k] = 0;
}

static int Twin261Key(const char* a, const char* b)
{
    char x[256], y[256];
    Twin261Strip(a, x, sizeof(x));
    Twin261Strip(b, y, sizeof(y));
    return SalNameCompareOrdinalCI(x, -1, y, -1);
}

// the sort order (CmpNameExt): the key, then the locale order with case (lower case first, as
// CompareString; the soft hyphen still ignored), then the bytes
static int Twin261Exact(const char* a, const char* b)
{
    int r = Twin261Key(a, b);
    if (r != 0)
        return r;
    char x[256], y[256];
    Twin261Strip(a, x, sizeof(x));
    Twin261Strip(b, y, sizeof(y));
    for (int i = 0; x[i] != 0 && y[i] != 0; i++)
    {
        if (x[i] != y[i])
        {
            BOOL xl = x[i] >= 'a' && x[i] <= 'z', yl = y[i] >= 'a' && y[i] <= 'z';
            if (xl != yl && (x[i] | 0x20) == (y[i] | 0x20))
                return xl ? -1 : 1;
            break;
        }
    }
    return strcmp(a, b);
}

static int Twin261Loose(const char* a, const char* b) // CmpNameExtIgnCase: the key, then the ordinal rule
{
    int r = Twin261Key(a, b);
    if (r == 0)
        r = SalNameCompareOrdinalCI(a, -1, b, -1);
    return (r > 0) - (r < 0);
}

static void Twin261Sort(Twin261List& l)
{
    for (int i = 1; i < l.Count; i++)
    {
        for (int k = i; k > 0 && Twin261Exact(l.Names[k - 1], l.Names[k]) > 0; k--)
        {
            const char* t = l.Names[k];
            l.Names[k] = l.Names[k - 1];
            l.Names[k - 1] = t;
        }
    }
}

static BOOL Twin261HasTwin(const Twin261List& l, int i)
{
    return SalHasCaseTwinInRun(
        l.Count, i, [&](int x, int k) { return Twin261Key(l.Names[x], l.Names[k]) == 0; },
        [&](int x, int k) { return SalNameEqualOrdinalCI(l.Names[x], -1, l.Names[k], -1) && strcmp(l.Names[x], l.Names[k]) != 0; });
}

struct Twin261Run
{
    Twin261List* Left;
    Twin261List* Right;
    int L, LEnd, R, REnd, Pairs;
    BOOL Twins;
};

static void Twin261Align(Twin261Run& run)
{
    Twin261List& left = *run.Left;
    Twin261List& right = *run.Right;
    int nL = run.LEnd - run.L, nR = run.REnd - run.R;
    int lp[16], rp[16], ol[16], orr[16];
    BOOL lt[16], rt[16];
    for (int i = 0; i < nL; i++)
        lt[i] = Twin261HasTwin(left, run.L + i);
    for (int j = 0; j < nR; j++)
        rt[j] = Twin261HasTwin(right, run.R + j);
    run.Pairs = SalTwinRunPairs(
        nL, nR, [&](int i, int j) { return strcmp(left.Names[run.L + i], right.Names[run.R + j]) == 0; },
        [&](int i, int j) { return SalNameEqualOrdinalCI(left.Names[run.L + i], -1, right.Names[run.R + j], -1); },
        [&](int i) { return lt[i]; }, [&](int j) { return rt[j]; }, lp, rp);
    SalTwinRunOrder(nL, lp, nR, rp, ol, orr);
    const char* tmp[16];
    for (int k = 0; k < nL; k++)
        tmp[k] = left.Names[run.L + ol[k]];
    for (int k = 0; k < nL; k++)
        left.Names[run.L + k] = tmp[k];
    for (int k = 0; k < nR; k++)
        tmp[k] = right.Names[run.R + orr[k]];
    for (int k = 0; k < nR; k++)
        right.Names[run.R + k] = tmp[k];
}

static int Twin261Cmp(Twin261Run& run, Twin261List& left, int l, Twin261List& right, int r)
{
    if (!(run.Left == &left && run.Right == &right && l >= run.L && l < run.LEnd && r >= run.R && r < run.REnd))
    {
        if (Twin261Key(left.Names[l], right.Names[r]) != 0)
            return Twin261Loose(left.Names[l], right.Names[r]);
        run.Left = &left;
        run.Right = &right;
        run.L = l;
        run.R = r;
        run.Pairs = 0;
        run.Twins = FALSE;
        for (run.LEnd = l + 1; run.LEnd < left.Count && Twin261Key(left.Names[l], left.Names[run.LEnd]) == 0; run.LEnd++)
            ;
        for (run.REnd = r + 1; run.REnd < right.Count && Twin261Key(right.Names[r], right.Names[run.REnd]) == 0; run.REnd++)
            ;
        for (int i = run.L; i < run.LEnd && !run.Twins; i++)
            run.Twins = Twin261HasTwin(left, i);
        for (int j = run.R; j < run.REnd && !run.Twins; j++)
            run.Twins = Twin261HasTwin(right, j);
        if (run.Twins)
            Twin261Align(run);
    }
    if (!run.Twins)
        return Twin261Loose(left.Names[l], right.Names[r]);
    return SalTwinRunSlotCmp(l - run.L, r - run.R, run.Pairs);
}

// a merge as Compare Directories runs it; 'out' gets "L=R" for a pair, "L-" / "-R" for an unpaired name
static void Twin261Merge(Twin261List& left, Twin261List& right, char* out, size_t outSize)
{
    out[0] = 0;
    Twin261Run run = {};
    int l = 0, r = 0;
    while (l < left.Count || r < right.Count)
    {
        char item[96];
        if (l < left.Count && r < right.Count)
        {
            int c = Twin261Cmp(run, left, l, right, r);
            if (c < 0)
                sprintf_s(item, "%s-;", left.Names[l++]);
            else if (c > 0)
                sprintf_s(item, "-%s;", right.Names[r++]);
            else
            {
                sprintf_s(item, "%s=%s;", left.Names[l], right.Names[r]);
                l++;
                r++;
            }
        }
        else if (l < left.Count)
            sprintf_s(item, "%s-;", left.Names[l++]);
        else
            sprintf_s(item, "-%s;", right.Names[r++]);
        strcat_s(out, outSize, item);
    }
}

// sorts both lists as the panels do, merges twice (Compare Directories' two passes) and compares
static BOOL Twin261MergeIs(Twin261List left, Twin261List right, const char* want)
{
    Twin261Sort(left);
    Twin261Sort(right);
    char out[512], again[512];
    Twin261Merge(left, right, out, sizeof(out));
    Twin261Merge(left, right, again, sizeof(again)); // the second pass walks the arranged runs
    if (strcmp(out, again) != 0)
        printf("Twin261: second pass differs: %s / %s\n", out, again);
    if (strcmp(out, want) != 0)
        printf("Twin261: merge %s, want %s\n", out, want);
    return strcmp(out, want) == 0 && strcmp(out, again) == 0;
}

static void TestNameRules261()
{
    // the lookup: byte-identical first, else the only case-insensitive match, never one of two
    const char* twins[] = {"A.txt", "a.txt", "z.txt"};
    auto at = [&](const char* const* list) {
        return [list](int i, const char** n, int* len) { *n = list[i]; *len = -1; };
    };
    CHECK(SalNamePickIndex(3, "a.txt", -1, at(twins)) == 1);
    CHECK(SalNamePickIndex(3, "A.txt", -1, at(twins)) == 0);
    CHECK(SalNamePickIndex(3, "A.TXT", -1, at(twins)) == -1); // two in another case: which one?
    CHECK(SalNamePickIndex(3, "Z.TXT", -1, at(twins)) == 2);  // one in another case: today's fallback
    CHECK(SalNamePickIndex(3, "z.txt", -1, at(twins)) == 2);
    CHECK(SalNamePickIndex(3, "b.txt", -1, at(twins)) == -1);
    CHECK(SalNamePickIndex(0, "a.txt", -1, at(twins)) == -1);
    CHECK(SalNamePickIndex(3, NULL, -1, at(twins)) == -1);
    CHECK(SalNamePickIndex(3, "a.txtX", 5, at(twins)) == 1); // the given bytes only
    const char* lone[] = {"a\xED\xA0\x80", "A\xED\xA0\x80"}; // WTF-8 lone surrogates: bytes like any other
    CHECK(SalNamePickIndex(2, "A\xED\xA0\x80", -1, at(lone)) == 1);
    CHECK(SalNamePickIndex(2, "a\xED\xA0\x80", -1, at(lone)) == 0);
    const char* caron[] = {"\xC5\xBElu\xC5\xA5"}; // z-caron l u t-caron
    CHECK(SalNamePickIndex(1, "\xC5\xBDLU\xC5\xA4", -1, at(caron)) == 0); // Z-caron L U T-caron: the only one
    const char* dup[] = {"x", "X", "x"};
    CHECK(SalNamePickIndex(3, "x", -1, at(dup)) == 0); // the first byte-identical one
    const char* nfd[] = {"e\xCC\x81.txt"};                       // e + combining acute
    CHECK(SalNamePickIndex(1, "\xC3\xA9.txt", -1, at(nfd)) == -1); // NFC is another name (004, FR-009)
    // twin detection in a sorted list
    Twin261List lr = {{"A.txt", "a.txt", "b.txt", "C", "c", "c", "d"}, 7};
    CHECK(Twin261HasTwin(lr, 0) && Twin261HasTwin(lr, 1));
    CHECK(!Twin261HasTwin(lr, 2));
    CHECK(Twin261HasTwin(lr, 3) && Twin261HasTwin(lr, 4) && Twin261HasTwin(lr, 5));
    CHECK(!Twin261HasTwin(lr, 6));
    CHECK(!Twin261HasTwin(lr, -1) && !Twin261HasTwin(lr, 7));
    Twin261List ls = {{"x", "x"}, 2}; // byte-identical neighbours are no twins
    CHECK(!Twin261HasTwin(ls, 0) && !Twin261HasTwin(ls, 1));
    // the run pairing: exact first, a case-only pair only between names without twins
    {
        const char* L[] = {"a", "A", "b"};
        const char* R[] = {"A", "B"};
        BOOL lt[] = {TRUE, TRUE, FALSE};
        BOOL rt[] = {FALSE, FALSE};
        int lp[3], rp[2], ol[3], orr[2];
        int n = SalTwinRunPairs(
            3, 2, [&](int i, int j) { return strcmp(L[i], R[j]) == 0; },
            [&](int i, int j) { return SalNameEqualOrdinalCI(L[i], -1, R[j], -1); }, [&](int i) { return lt[i]; },
            [&](int j) { return rt[j]; }, lp, rp);
        CHECK(n == 2);
        CHECK(lp[0] == -1 && lp[1] == 0 && lp[2] == 1 && rp[0] == 1 && rp[1] == 2);
        SalTwinRunOrder(3, lp, 2, rp, ol, orr);
        CHECK(ol[0] == 1 && ol[1] == 2 && ol[2] == 0 && orr[0] == 0 && orr[1] == 1);
    }
    CHECK(SalTwinRunSlotCmp(0, 0, 1) == 0);
    CHECK(SalTwinRunSlotCmp(1, 0, 2) == 1 && SalTwinRunSlotCmp(0, 1, 2) == -1);
    CHECK(SalTwinRunSlotCmp(0, 2, 1) == -1); // a pair before an unpaired name
    CHECK(SalTwinRunSlotCmp(2, 0, 1) == 1);
    CHECK(SalTwinRunSlotCmp(1, 1, 1) == -1); // both unpaired: the left one first
    CHECK(SalTwinRunSlotCmp(0, 0, 0) == -1);
    // merges (the probe's rows)
    CHECK(Twin261MergeIs({{"a.txt", "A.txt"}, 2}, {{"A.txt"}, 1}, "A.txt=A.txt;a.txt-;")); // CMPTWIN1
    CHECK(Twin261MergeIs({{"A.txt", "a.txt"}, 2}, {{"a.txt"}, 1}, "a.txt=a.txt;A.txt-;")); // CMPTWIN2
    CHECK(Twin261MergeIs({{"A.txt"}, 1}, {{"a.txt", "A.txt"}, 2}, "A.txt=A.txt;-a.txt;")); // CMPTWINR
    CHECK(Twin261MergeIs({{"Readme.txt", "z"}, 2}, {{"README.txt", "z"}, 2}, "Readme.txt=README.txt;z=z;")); // CMPSINGLE (232)
    CHECK(Twin261MergeIs({{"aB.txt", "Ab.txt"}, 2}, {{"ab.txt", "AB.txt"}, 2}, "aB.txt-;Ab.txt-;-ab.txt;-AB.txt;")); // CMPSUB
    // twins against a third case: nothing paired, both ways
    CHECK(Twin261MergeIs({{"a.txt", "A.txt"}, 2}, {{"A.TXT"}, 1}, "a.txt-;A.txt-;-A.TXT;"));
    CHECK(Twin261MergeIs({{"A.TXT"}, 1}, {{"a.txt", "A.txt"}, 2}, "A.TXT-;-a.txt;-A.txt;"));
    CHECK(Twin261MergeIs({{"A.txt", "a.txt", "b"}, 3}, {{"A.txt", "a.txt", "b"}, 3}, "a.txt=a.txt;A.txt=A.txt;b=b;"));
    // the model sorts as the panel: "a.txt" before "A.txt", the soft hyphen ignored before the bytes
    CHECK(Twin261Exact("a.txt", "A.txt") < 0 && Twin261Exact("Ab", "aB") > 0);
    CHECK(Twin261Exact("AB", "A\xC2\xAD"
                             "B") < 0);
    CHECK(Twin261Exact("ab", "A\xC2\xAD"
                             "B") < 0);
    // several runs: the twin run as a set, the next run as feature 232
    CHECK(Twin261MergeIs({{"a", "A", "b", "c"}, 4}, {{"A", "B", "c", "d"}, 4}, "A=A;a-;b=B;c=c;-d;"));
    // review of 261: a case-only pair beside twins of one locale run (a soft hyphen the locale key
    // ignores) - a comparison chosen pair by pair stepped past the partner
    CHECK(Twin261MergeIs({{"a\xC2\xAD"
                           "b.txt"},
                          1},
                         {{"ab.txt", "AB.txt", "A\xC2\xAD"
                                               "B.txt"},
                          3},
                         "a\xC2\xAD"
                         "b.txt=A\xC2\xAD"
                         "B.txt;-ab.txt;-AB.txt;"));
    CHECK(Twin261MergeIs({{"a\xC2\xAD"
                           "b.txt"},
                          1},
                         {{"A\xC2\xAD"
                           "B.txt"},
                          1},
                         "a\xC2\xAD"
                         "b.txt=A\xC2\xAD"
                         "B.txt;")); // control: no twins
    CHECK(Twin261MergeIs({{"ab.txt", "AB.txt", "A\xC2\xAD"
                                               "B.txt"},
                          3},
                         {{"a\xC2\xAD"
                           "b.txt"},
                          1},
                         "A\xC2\xAD"
                         "B.txt=a\xC2\xAD"
                         "b.txt;ab.txt-;AB.txt-;")); // mirrored
}

// feature 236: a menu item's hot key goes before a free ASCII letter only - never inside a UTF-8 letter
static void TestMenuHotKey236()
{
    unsigned char up[256];
    for (int i = 0; i < 256; i++)
        up[i] = (unsigned char)(i >= 'a' && i <= 'z' ? i - 32 : i);
    int assigned[256] = {0};
    CHECK(SalMenuHotKeyPos("Copy", assigned, up) == 0);
    assigned['C'] = 1;
    CHECK(SalMenuHotKeyPos("Copy", assigned, up) == 1);
    CHECK(SalMenuHotKeyPos("1. copy", assigned, up) == 4); // 'c' taken (as 'C'): 'o'
    // z-caron l u t-caron: 'l' (never a byte of the UTF-8 letters)
    CHECK(SalMenuHotKeyPos("\xC5\xBElu\xC5\xA5", assigned, up) == 2);
    // CJK only: no hot key (the old search put '&' before a byte the code page calls a letter)
    CHECK(SalMenuHotKeyPos("\xE4\xB8\xAD\xE6\x96\x87", assigned, up) == -1);
    // z-caron alone: no ASCII letter
    CHECK(SalMenuHotKeyPos("\xC5\xBE", assigned, up) == -1);
    // every ASCII letter of the text taken: none
    assigned['L'] = 1;
    assigned['U'] = 1;
    CHECK(SalMenuHotKeyPos("\xC5\xBElu\xC5\xA5", assigned, up) == -1);
    CHECK(SalMenuHotKeyPos("", assigned, up) == -1);
    CHECK(SalMenuHotKeyPos("123 ()", assigned, up) == -1);
    // 2-byte UTF-8 letters whose bytes a code page calls letters: never
    CHECK(SalMenuHotKeyPos("\xC3\x9F", assigned, up) == -1);
    CHECK(SalMenuHotKeyPos("\xC2\xAA", assigned, up) == -1);
    CHECK(SalMenuHotKeyPos("\xC3\x9F"
                           "Z",
                           assigned, up) == 2);
    // the existing hot key; "&&" is a literal '&'
    CHECK(SalMenuHotKeyOf("&Copy") == 'C');
    CHECK(SalMenuHotKeyOf("Co&py") == 'p');
    CHECK(SalMenuHotKeyOf("R&&D") == 0);
    CHECK(SalMenuHotKeyOf("R&&D &x") == 'x');
    CHECK(SalMenuHotKeyOf("tail&") == 0);
    CHECK(SalMenuHotKeyOf("") == 0);
    CHECK(SalMenuHotKeyOf("&&&a") == 'a');

    // feature 237: a typed character against a popup item, as characters
    CHECK(SalMenuKeyMatch("&Copy", L'c') == 2);
    CHECK(SalMenuKeyMatch("&Copy", L'C') == 2);
    CHECK(SalMenuKeyMatch("&Copy", L'o') == 0); // another mnemonic: not the first letter either
    CHECK(SalMenuKeyMatch("&\xC4\x8C"
                          "esky",
                          0x010C) == 2); // C-caron (UTF-8)
    CHECK(SalMenuKeyMatch("&\xC4\x8C"
                          "esky",
                          0x010D) == 2); // c-caron: case ignored
    CHECK(SalMenuKeyMatch("&\xC4\x8C"
                          "esky",
                          0x00C4) == 0); // A-umlaut (the old byte C4) no more
    CHECK(SalMenuKeyMatch("Zip", L'z') == 1);
    CHECK(SalMenuKeyMatch("Zip", L'i') == 0);
    CHECK(SalMenuKeyMatch("\xC5\xBElu", 0x017D) == 1); // Z-caron: the first character, case ignored
    CHECK(SalMenuKeyMatch("R&&D", L'r') == 1);
    CHECK(SalMenuKeyMatch("R&&D", L'd') == 0);
    CHECK(SalMenuKeyMatch("", L'a') == 0);
    CHECK(SalMenuKeyMatch("a", 0) == 0);
    CHECK(SalMenuKeyMatch("R&&D", L'&') == 0); // "&&" is a literal '&', not a mnemonic
    CHECK(SalMenuKeyMatch("Foo&", L'f') == 1); // a trailing '&': no mnemonic
    CHECK(SalMenuKeyMatch("Ab&&c", L'a') == 1);
    CHECK(SalMenuKeyMatch("\xF0\x9F\x98\x80x", L'x') == 0); // an emoji first: outside the BMP, never
    if (GetACP() == 1250)                                   // a legacy code-page item (C-caron = 0xC8)
    {
        CHECK(SalMenuKeyMatch("&\xC8ten\xED", 0x010C) == 2);
        CHECK(SalMenuKeyMatch("\xC8ten\xED", 0x010D) == 1);
    }

    // feature 256: the owner's answer to WM_MENUCHAR
    int idx = -1;
    CHECK(SalMenuCharAnswer(MAKELONG(2, MNC_SELECT), 5, &idx) == MNC_SELECT && idx == 2);
    idx = -1;
    CHECK(SalMenuCharAnswer(MAKELONG(0, MNC_EXECUTE), 5, &idx) == MNC_EXECUTE && idx == 0);
    idx = -1;
    CHECK(SalMenuCharAnswer(MAKELONG(4, MNC_EXECUTE), 5, &idx) == MNC_EXECUTE && idx == 4);
    idx = -1;
    CHECK(SalMenuCharAnswer(MAKELONG(5, MNC_SELECT), 5, &idx) == 0 && idx == -1); // no such item
    CHECK(SalMenuCharAnswer(MAKELONG(0xFFFF, MNC_EXECUTE), 5, &idx) == 0 && idx == -1);
    CHECK(SalMenuCharAnswer(MAKELONG(0, MNC_SELECT), 0, &idx) == 0 && idx == -1); // an empty popup
    CHECK(SalMenuCharAnswer(MAKELONG(1, MNC_IGNORE), 5, &idx) == 0 && idx == -1);
    CHECK(SalMenuCharAnswer(MAKELONG(1, MNC_CLOSE), 5, &idx) == 0 && idx == -1);
    CHECK(SalMenuCharAnswer(0, 5, &idx) == 0 && idx == -1);          // DefWindowProc's answer
    CHECK(SalMenuCharAnswer(0xCCCCCCCC, 5, &idx) == 0 && idx == -1); // 7-Zip's garbage (menu2.cpp)
    CHECK(SalMenuCharAnswer(MAKELONG(1, 4), 5, &idx) == 0 && idx == -1);

    // feature 256: a dialog control's hot key, as a UTF-16 unit
    CHECK(SalDlgHotKeyW(L"HE&X-mode") == L'X');
    CHECK(SalDlgHotKeyW(L"Gan&ze W\x00F6rter") == L'z');
    CHECK(SalDlgHotKeyW(L"&\x0422\x0435\x043A\x0441\x0442") == 0x0422); // Cyrillic Te
    CHECK(SalDlgHotKeyW(L"\x0160&estn\x00E1\x0063tkov\x00FD") == L'e');
    CHECK(SalDlgHotKeyW(L"&\x0160irok\x00FD") == 0x0160);
    CHECK(SalDlgHotKeyW(L"R&&D") == 0); // before: 'D'
    CHECK(SalDlgHotKeyW(L"R&&D &x") == L'x');
    CHECK(SalDlgHotKeyW(L"&&&a") == L'a');
    CHECK(SalDlgHotKeyW(L"tail&") == 0);
    CHECK(SalDlgHotKeyW(L"none") == 0);
    CHECK(SalDlgHotKeyW(L"") == 0);
    CHECK(SalDlgHotKeyW(NULL) == 0);
    CHECK(SalDlgHotKeyW(L"&\xD83D\xDE00") == 0); // an emoji: never a hot key
    CHECK(SalDlgHotKeyW(L"\x6DFB\x52A0(&A)") == L'A');
    // by virtual key: ASCII letters and digits only (as before for every shipped language)
    CHECK(SalDlgHotKeyVkMatch(L'X', 'X') && SalDlgHotKeyVkMatch(L'x', 'X'));
    CHECK(SalDlgHotKeyVkMatch(L'7', '7'));
    CHECK(!SalDlgHotKeyVkMatch(L'x', 'Y') && !SalDlgHotKeyVkMatch(L'x', 'x'));
    CHECK(!SalDlgHotKeyVkMatch(0x0422, 0x22) && !SalDlgHotKeyVkMatch(0x00C8, 0xC8)); // never a byte or a unit as a VK
    CHECK(!SalDlgHotKeyVkMatch(L'?', 0x3F) && !SalDlgHotKeyVkMatch(0, 0));
    // by character, case ignored
    CHECK(SalDlgHotKeyCharMatch(0x0422, 0x0442) && SalDlgHotKeyCharMatch(0x0442, 0x0422)); // Te / te
    CHECK(SalDlgHotKeyCharMatch(0x0160, 0x0161));                                          // S-caron
    CHECK(SalDlgHotKeyCharMatch(L'X', L'x') && SalDlgHotKeyCharMatch(L'e', L'E'));
    CHECK(!SalDlgHotKeyCharMatch(0x0422, L'?') && !SalDlgHotKeyCharMatch(0x010C, L'c'));
    CHECK(!SalDlgHotKeyCharMatch(0, 0) && !SalDlgHotKeyCharMatch(L'a', 0) && !SalDlgHotKeyCharMatch(0, L'a'));
}

// feature 238: a path with %...% - the part checked as it is, how the path is anchored
static void TestPercentPath238()
{
    CHECK(SalPercentPrefixLen("C:\\x\\p%OS%q") == 11);
    CHECK(SalPercentPrefixLen("C:\\x\\p%OS%q\\a.zip\\inner") == 11);
    CHECK(SalPercentPrefixLen("C:\\a%b\\c%d%\\e") == 11); // the last component holding a '%'
    CHECK(SalPercentPrefixLen("C:\\x\\y") == 0);
    CHECK(SalPercentPrefixLen("%TEMP%\\x") == 6);
    CHECK(SalPercentPrefixLen("C:/x/p%q/y") == 8);
    CHECK(SalPercentPrefixLen("") == 0);
    CHECK(SalPercentPathKind("C:\\x") == 1);
    CHECK(SalPercentPathKind("C:/x") == 1);
    CHECK(SalPercentPathKind("C:x") == 0);
    CHECK(SalPercentPathKind("\\\\srv\\share") == 2);
    CHECK(SalPercentPathKind("//srv/share") == 2);
    CHECK(SalPercentPathKind("p%OS%q") == 3);
    CHECK(SalPercentPathKind("..\\p%OS%q") == 3);
    CHECK(SalPercentPathKind("%TEMP%") == 3);
    CHECK(SalPercentPathKind("\\x") == 4);
    CHECK(SalPercentPathKind("") == 0);
}

static void TestMultiSzToLine189()
{
    struct Case
    {
        const WCHAR* data;
        DWORD units;
        const WCHAR* line;
        DWORD ret;
    };
    const Case cases[] = {
        {L"alpha\0beta\0", 12, L"alpha beta", 11}, // proper: two NULs at the end
        {L"alpha\0beta", 11, L"alpha beta", 11},   // one NUL (the second is the literal's)
        {L"alpha\0beta", 10, L"alpha beta", 10},   // none: no terminator counted
        {L"zeta\0\0\0", 7, L"zeta", 5},            // more NULs than two
        {L"a\0\0b\0", 6, L"a  b", 5},              // an empty string inside stays a gap
        {L"\0", 2, L"", 1},                        // the empty list
        {L"", 1, L"", 1},                          // one NUL
        {L"", 0, L"", 0},                          // no data
    };
    for (const Case& c : cases)
    {
        WCHAR buf[32];
        memcpy(buf, c.data, c.units * sizeof(WCHAR));
        buf[c.units] = 0xFFFF; // a sentinel: the rule does not write past 'units'
        DWORD n = SalMultiSzToLine(buf, c.units);
        CHECK(n == c.ret && buf[c.units] == 0xFFFF);
        size_t len = wcslen(c.line);
        CHECK(n >= len && wcsncmp(buf, c.line, len) == 0 && (n == len || buf[len] == 0));
    }
    CHECK(SalMultiSzToLine(NULL, 4) == 0);
}

// feature 257: the Registry Editor's Find - a whole-word regexp match is judged by its own line
// (the characters around it were read from the start of the value)
static void TestRegFindWholeWord257()
{
    const char list1[] = "abcdefgh\0foo bar"; // "foo bar" on the second line
    const char* line2 = list1 + 9;
    CHECK(SalRegFindWholeWordInLine(line2, 7, 4, 3));       // "bar" at the line's end, a space before
    CHECK(!SalRegFindWholeWordInLine(list1, 7, 4, 3));      // the old reading: 'd' before, 'h' after
    const char list2[] = "a bcdef\0xxbar";                  // "xxbar" on the second line
    CHECK(!SalRegFindWholeWordInLine(list2 + 8, 5, 2, 3));  // a fragment
    CHECK(SalRegFindWholeWordInLine(list2, 5, 2, 3));       // the old reading took it for a word
    CHECK(SalRegFindWholeWordInLine("bar baz", 7, 0, 3));   // the line's start
    CHECK(SalRegFindWholeWordInLine("bar baz", 7, 4, 3));   // the line's end
    CHECK(SalRegFindWholeWordInLine("x\tbar\ty", 7, 2, 3)); // tabs
    CHECK(!SalRegFindWholeWordInLine("bar baz", 7, 4, 2));  // "ba" of "baz"
    CHECK(!SalRegFindWholeWordInLine("x\xE8"
                                     "bar",
                                     5, 2, 3));        // a non-ASCII letter before: no space
    CHECK(!SalRegFindWholeWordInLine("bar", 3, 0, 0)); // an empty match is no word
    CHECK(!SalRegFindWholeWordInLine("bar", 3, 1, 3)); // past the line
    CHECK(!SalRegFindWholeWordInLine(NULL, 3, 0, 3));
}

// feature 257: a HEX pattern's 'text' becomes all its code-page bytes (a letter of 2+ bytes was
// one 0x00 byte), counted the same way before the search
static bool Hex257(const WCHAR* text, UINT cp, BOOL strict, int outSize, int wantRet, const char* want, int wantLen)
{
    char out[64];
    memset(out, 0x5A, sizeof(out));
    int len = -7;
    int ret = SalHexPatternToBytes(text, cp, strict, out, outSize, &len);
    if (ret != wantRet)
        return false;
    for (int i = outSize; i < (int)sizeof(out); i++)
        if (out[i] != 0x5A)
            return false; // nothing written past 'outSize'
    if (ret != SALHEXPAT_OK)
        return true;
    int countLen = -7; // count mode gives the same number
    if (SalHexPatternToBytes(text, cp, strict, NULL, 0, &countLen) != SALHEXPAT_OK || countLen != len)
        return false;
    return len == wantLen && memcmp(out, want, wantLen) == 0;
}

static void TestHexPattern257()
{
    // UTF-8 code page: C-caron is C4 8D
    CHECK(Hex257(L"'\x010D"
                 L"AB'",
                 65001, TRUE, 64, SALHEXPAT_OK, "\xC4\x8D\x41\x42", 4));
    CHECK(Hex257(L"01 '\x010D"
                 L"AB' 02",
                 65001, TRUE, 64, SALHEXPAT_OK, "\x01\xC4\x8D\x41\x42\x02", 6));
    CHECK(Hex257(L"'\xD83D\xDE00'", 65001, TRUE, 64, SALHEXPAT_OK, "\xF0\x9F\x98\x80", 4)); // a surrogate pair: one letter
    CHECK(Hex257(L"'\x010D"
                 L"AB'",
                 65001, TRUE, 4, SALHEXPAT_OK, "\xC4\x8D\x41\x42", 4)); // exact fit
    CHECK(Hex257(L"'\x010D"
                 L"AB'",
                 65001, TRUE, 3, SALHEXPAT_TOOLONG, "", 0)); // never cut
    CHECK(Hex257(L"01 '\x010D'", 65001, TRUE, 2, SALHEXPAT_TOOLONG, "", 0));
    // a DBCS code page: hiragana A is 82 A0
    CHECK(Hex257(L"'\x3042'", 932, TRUE, 64, SALHEXPAT_OK, "\x82\xA0", 2));
    // a single-byte code page: unchanged
    CHECK(Hex257(L"01 '\x010D"
                 L"AB' 02",
                 1250, TRUE, 64, SALHEXPAT_OK, "\x01\xE8\x41\x42\x02", 5));
    {
        // a letter the code page lacks: what the plain-text pattern gets (its replacement)
        char plain[8] = {0};
        int n = WideCharToMultiByte(1250, 0, L"\x0436", 1, plain, sizeof(plain), NULL, NULL);
        CHECK(n == 1 && Hex257(L"'\x0436'", 1250, TRUE, 64, SALHEXPAT_OK, plain, 1));
    }
    // the rest of the grammar is unchanged
    CHECK(Hex257(L"\"ab\"", 1250, TRUE, 64, SALHEXPAT_OK, "a\0b\0", 4));
    CHECK(Hex257(L"\"\x010D\"", 65001, TRUE, 64, SALHEXPAT_OK, "\x0D\x01", 2));
    CHECK(Hex257(L"'ab", 65001, TRUE, 64, SALHEXPAT_OK, "ab", 2)); // an unclosed quote runs to the end
    CHECK(Hex257(L"'a\"b'", 65001, TRUE, 64, SALHEXPAT_OK, "a\"b", 3));
    CHECK(Hex257(L"\"a'b\"", 1250, TRUE, 64, SALHEXPAT_OK, "a\0'\0b\0", 6));
    CHECK(Hex257(L"''", 65001, TRUE, 64, SALHEXPAT_OK, "", 0));
    CHECK(Hex257(L"", 65001, TRUE, 64, SALHEXPAT_OK, "", 0));
    CHECK(Hex257(L"Ff 0a", 65001, TRUE, 64, SALHEXPAT_OK, "\xFF\x0A", 2));
    CHECK(Hex257(L"1", 65001, TRUE, 64, SALHEXPAT_BAD, "", 0));     // strict: two digits a byte
    CHECK(Hex257(L"1", 65001, FALSE, 64, SALHEXPAT_OK, "\x01", 1)); // lenient: a lone digit
    CHECK(Hex257(L"01,02", 65001, TRUE, 64, SALHEXPAT_BAD, "", 0)); // strict: only spaces
    CHECK(Hex257(L"01,02", 65001, FALSE, 64, SALHEXPAT_OK, "\x01\x02", 2));
    CHECK(Hex257(L"0g", 65001, TRUE, 64, SALHEXPAT_BAD, "", 0));
    CHECK(Hex257(L"\xFF21"
                 L"0",
                 65001, TRUE, 64, SALHEXPAT_BAD, "", 0)); // a fullwidth A is no digit
    CHECK(Hex257(L"01 02 03", 65001, TRUE, 2, SALHEXPAT_TOOLONG, "", 0));
    CHECK(Hex257(L"\"ab\"", 65001, TRUE, 3, SALHEXPAT_TOOLONG, "", 0));
    {
        int len = -7;
        CHECK(SalHexPatternToBytes(L"'\x010D'", 65001, TRUE, NULL, 0, &len) == SALHEXPAT_OK && len == 2);
        CHECK(SalHexPatternToBytes(L"'\x010D'", 1250, TRUE, NULL, 0, &len) == SALHEXPAT_OK && len == 1);
        CHECK(SalHexPatternToBytes(L"'x'", 12345, TRUE, NULL, 0, &len) == SALHEXPAT_BAD); // no such code page
        CHECK(SalHexPatternToBytes(NULL, 65001, TRUE, NULL, 0, &len) == SALHEXPAT_BAD && len == 0);
    }
}

// feature 180: system texts with inserts (193 "%1 is not a valid Win32 application.", 216, 34) are
// formatted - before, FormatMessage without arguments failed (87) and the program showed "System
// error N, text description is not available."; the inserts become "..." and no '%' is left
static void TestFormatMessageInserts180()
{
    const DWORD codes[] = {2, 5, 32, 123, 193, 216, 34};
    for (DWORD e : codes)
    {
        WCHAR w[512];
        DWORD n = FormatMessageW(SAL_FM_SYSTEM_FLAGS, NULL, e, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), w, _countof(w), SalFmInsertsW());
        CHECK(n > 0 && wcschr(w, L'%') == NULL);
        char a[512];
        n = FormatMessageA(SAL_FM_SYSTEM_FLAGS, NULL, e, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), a, sizeof(a), SalFmInsertsA());
        CHECK(n > 0 && strchr(a, '%') == NULL);
    }
    // the control: without the arguments a text with an insert fails, as it did
    {
        WCHAR w[512];
        DWORD n = FormatMessageW(FORMAT_MESSAGE_FROM_SYSTEM, NULL, 193, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), w, _countof(w), NULL);
        CHECK(n == 0 && GetLastError() == ERROR_INVALID_PARAMETER);
    }
    // the inserts: "..." where the text had %1
    {
        WCHAR w[512];
        DWORD n = FormatMessageW(SAL_FM_SYSTEM_FLAGS, NULL, 193, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), w, _countof(w), SalFmInsertsW());
        CHECK(n > 0 && wcsstr(w, L"...") != NULL);
    }
}

// feature 244: quick search that matches anywhere in a name (salquickfilter.h)
// The 0.1.10 matcher, copied as the reference: masks.cpp PrepareQSMask / AgreeQSMaskAux (its
// LowerCase table folds ASCII bytes as below) and fileswn0.cpp AgreeQSMaskU8Aux / AgreeQSMaskU8.
namespace Legacy244
{
    static BOOL IsWild(char ch) { return ch == '/' || ch == '\\' || ch == '<'; }
    static void Prepare(char* mask, const char* src)
    {
        char* begMask = mask;
        char lastChar = 0;
        while (*src != 0)
        {
            if (IsWild(*src))
            {
                if (lastChar == '/')
                    src++;
                else
                {
                    src++;
                    *mask++ = (lastChar = '/');
                }
            }
            else
                *mask++ = (lastChar = *src++);
        }
        if (mask > begMask && *(mask - 1) == '/')
            mask--;
        *mask = 0;
    }
    static char Low(char c) { return (c >= 'A' && c <= 'Z') ? (char)(c + 32) : c; }
    static BOOL AsciiAux(const char* filename, BOOL hasExtension, const char* filenameBase, const char* mask, BOOL wholeString, int& offset)
    {
        while (*filename != 0)
        {
            if (!wholeString && *mask == 0)
            {
                offset = (int)(filename - filenameBase);
                return TRUE;
            }
            if (Low(*filename) == Low(*mask))
            {
                filename++;
                mask++;
            }
            else if (*mask == '/')
            {
                mask++;
                while (*filename != 0)
                {
                    if (AsciiAux(filename, hasExtension, filenameBase, mask, wholeString, offset))
                        return TRUE;
                    filename++;
                }
                break;
            }
            else
                return FALSE;
        }
        if (*mask == 0 || !hasExtension && *mask == '.' && *(mask + 1) == 0)
        {
            offset = (int)(filename - filenameBase);
            return TRUE;
        }
        return FALSE;
    }
    static BOOL U8Aux(const char* filename, BOOL hasExtension, const char* filenameBase, const char* mask, BOOL wholeString, int& offset)
    {
        while (*mask != 0)
        {
            if (*mask == '/')
            {
                mask++;
                const char* iter = filename;
                while (1)
                {
                    if (U8Aux(iter, hasExtension, filenameBase, mask, wholeString, offset))
                        return TRUE;
                    if (*iter == 0)
                        return FALSE;
                    iter = SalU8Next(iter);
                }
            }
            const char* segEnd = mask;
            while (*segEnd != 0 && *segEnd != '/')
                segEnd++;
            int segLen = (int)(segEnd - mask);
            int segChars = SalU8CharCount(mask, segLen);
            const char* p = filename;
            const char* matchEnd = NULL;
            int chars = 0;
            while (*p != 0 && chars < 3 * segChars + 3)
            {
                p = SalU8Next(p);
                chars++;
                if (SalNameEqualCI(mask, segLen, filename, (int)(p - filename)))
                {
                    matchEnd = p;
                    break;
                }
            }
            if (matchEnd == NULL)
            {
                if (*segEnd == 0 && !hasExtension && segLen > 0 && mask[segLen - 1] == '.')
                {
                    int rest = (int)strlen(filename);
                    if (segLen == 1 && rest == 0 ||
                        segLen > 1 && SalNameEqualCI(mask, segLen - 1, filename, rest))
                    {
                        offset = (int)(filename - filenameBase) + rest;
                        return TRUE;
                    }
                }
                return FALSE;
            }
            filename = matchEnd;
            mask = segEnd;
        }
        if (wholeString && *filename != 0)
            return FALSE;
        offset = (int)(filename - filenameBase);
        return TRUE;
    }
    static BOOL Agree(const char* filename, BOOL hasExtension, const char* mask, int& offset)
    {
        offset = 0;
        if (SalIsASCII(mask) && SalIsASCII(filename))
            return AsciiAux(filename, hasExtension, filename, mask, FALSE, offset);
        return U8Aux(filename, hasExtension, filename, mask, FALSE, offset);
    }
} // namespace Legacy244

static void TestQuickFilter244()
{
    // names (hasExtension as the panel computes it: a directory has one when its name holds a dot)
    static const struct
    {
        const char* Name;
        BOOL HasExt;
    } names[] = {
        {"2024_chatbot", FALSE},
        {"chat.txt", TRUE},
        {"xchatter.log", TRUE},
        {"Report.PDF", TRUE},
        {"readme", FALSE},
        {"x_readme", FALSE},
        {"a.b.c", TRUE},
        {"aXbXc", FALSE},
        {"\xC3\x9A\xC4\x8D"
         "etnictv\xC3\xAD 2024.xlsx",
         TRUE}, // NFC U-acute c-caron ...
        {"U\xCC\x81"
         "c\xCC\x8C"
         "etnictvi\xCC\x81 2024 d.xlsx",
         TRUE},                                     // the same in NFD
        {"notes \xF0\x9F\x98\x80.txt", TRUE},       // emoji
        {"\xE4\xB8\xAD\xE6\x96\x87 chat.md", TRUE}, // CJK + ASCII
        {"Stra\xC3\x9F"
         "e.doc",
         TRUE}, // sharp s
        {"\x80\x80"
         "abc",
         FALSE},           // stray continuation bytes
        {"ab\xC4", FALSE}, // truncated sequence
        {".hidden", TRUE},
        {"UPPER lower", FALSE},
    };
    // typed texts (before PrepareQSMask)
    static const char* typed[] = {
        "",
        "c",
        "ch",
        "chat",
        "chatb",
        "CHAT",
        "pdf",
        ".pdf",
        "port",
        "readme",
        "readme.",
        "me.",
        "b/c",
        "a/c",
        "/chat",
        "\\chat",
        "<chat",
        "x",
        "2024",
        "4_c",
        "t.",
        "txt",
        "a.b",
        ".b",
        "b.c",
        "q",
        "zz",
        "\xC3\xBA\xC4\x8D",
        "\xC4\x8D"
        "et",
        "u",
        "U\xCC\x81",
        "etnictv\xC3\xAD",
        "2024 d",
        "\xF0\x9F\x98\x80",
        "s \xF0\x9F",
        "\xE6\x96\x87",
        "\xE6\x96\x87 c",
        "stra\xC3\x9F",
        "strasse",
        "abc",
        "bc",
        "b",
        "\xC4",
        "hid",
        "per l",
        "lower",
        "r l",
        "c/t",
        "t/t",
        "/",
        "//",
        "a//c",
        "/x",
    };
    int m1 = 0, m1Diff = 0, m3 = 0, m3Diff = 0;
    for (int n = 0; n < (int)(sizeof(names) / sizeof(names[0])); n++)
    {
        for (int t = 0; t < (int)(sizeof(typed) / sizeof(typed[0])); t++)
        {
            char mask[3 * MAX_PATH];
            Legacy244::Prepare(mask, typed[t]);
            int offset = -1;
            BOOL legacy = Legacy244::Agree(names[n].Name, names[n].HasExt, mask, offset);
            CSalQFMatch r;
            // M1: substring FALSE = the 0.1.10 matcher exactly
            BOOL got = SalQFMatchName(names[n].Name, names[n].HasExt, mask, FALSE, r);
            m1++;
            BOOL same = (got == legacy) && (!got || r.Kind == SALQF_PREFIX && r.MatchStart == 0 && r.MatchEnd == offset) &&
                        (got || r.Kind == SALQF_NONE);
            if (!same)
            {
                m1Diff++;
                printf("FAIL M1 name #%d typed #%d: legacy %d/%d, got %d/%d/%d..%d\n", n, t, legacy, offset, got, r.Kind, r.MatchStart, r.MatchEnd);
            }
            // M2/M3: substring TRUE - a prefix match stays PREFIX; else the leftmost boundary
            got = SalQFMatchName(names[n].Name, names[n].HasExt, mask, TRUE, r);
            int expKind = SALQF_NONE, expStart = 0, expEnd = 0;
            if (legacy)
            {
                expKind = SALQF_PREFIX;
                expEnd = offset;
            }
            else
            {
                BOOL ascii = SalIsASCII(mask) && SalIsASCII(names[n].Name);
                const char* p = names[n].Name;
                while (*p != 0)
                {
                    p = ascii ? p + 1 : SalU8Next(p);
                    if (*p == 0)
                        break;
                    int o = 0;
                    // the prefix rule at p without the dot tolerance: a mask ending with '.' needs the dot
                    BOOL ok = ascii ? Legacy244::AsciiAux(p, TRUE, names[n].Name, mask, FALSE, o)
                                    : Legacy244::U8Aux(p, TRUE, names[n].Name, mask, FALSE, o);
                    if (ok)
                    {
                        expKind = SALQF_SUBSTRING;
                        expStart = (int)(p - names[n].Name);
                        expEnd = o;
                        break;
                    }
                }
            }
            m3++;
            // the one documented difference: the 0.1.10 comparison's linguistic "ss" = "sharp s"
            // belongs to the old rule; the new mode compares canonical decomposition + case only
            if (strstr(names[n].Name, "\xC3\x9F") != NULL && strcmp(typed[t], "strasse") == 0)
            {
                CHECK(expKind == SALQF_PREFIX && r.Kind == SALQF_NONE);
                continue;
            }
            if (r.Kind != expKind || got != (expKind != SALQF_NONE) || expKind != SALQF_NONE && (r.MatchStart != expStart || r.MatchEnd != expEnd))
            {
                m3Diff++;
                printf("FAIL M3 name #%d typed #%d: expected %d/%d..%d, got %d/%d..%d\n", n, t, expKind, expStart, expEnd, r.Kind, r.MatchStart, r.MatchEnd);
            }
            // M6: the match lies inside the name, at character boundaries
            if (got)
            {
                int len = (int)strlen(names[n].Name);
                CHECK(r.MatchStart >= 0 && r.MatchStart <= r.MatchEnd && r.MatchEnd <= len);
            }
        }
    }
    CHECK(m1Diff == 0);
    CHECK(m3Diff == 0);
    printf("TestQuickFilter244: %d prefix cases against the 0.1.10 matcher, %d differ; %d substring cases, %d differ\n", m1, m1Diff, m3, m3Diff);

    // M3/M4/M5 by example
    struct Ex
    {
        const char* Name;
        BOOL HasExt;
        const char* Typed;
        int Kind, Start, End;
    };
    static const Ex ex[] = {
        {"2024_chatbot", FALSE, "chat", SALQF_SUBSTRING, 5, 9},
        {"chat.txt", TRUE, "chat", SALQF_PREFIX, 0, 4},
        {"aXbXc", FALSE, "b/c", SALQF_SUBSTRING, 2, 5},
        {"Report.PDF", TRUE, "pdf", SALQF_SUBSTRING, 7, 10},
        {"readme", FALSE, "readme.", SALQF_PREFIX, 0, 6},
        {"x_readme", FALSE, "readme.", SALQF_NONE, 0, 0},
        {"x_readme", FALSE, "readme", SALQF_SUBSTRING, 2, 8},
        {"2024_chatbot", FALSE, "/chat", SALQF_PREFIX, 0, 9},
        {"abcabc", FALSE, "bc", SALQF_SUBSTRING, 1, 3}, // leftmost
        {"U\xCC\x81"
         "c\xCC\x8C"
         "etnictvi\xCC\x81 2024 d.xlsx",
         TRUE, "\xC3\xBA\xC4\x8D", SALQF_PREFIX, 0, 6},
        {"x \xC3\x9A\xC4\x8D"
         "et",
         FALSE, "\xC3\xBA\xC4\x8D", SALQF_SUBSTRING, 2, 6},
        {"\x80\x80"
         "abc",
         FALSE, "abc", SALQF_SUBSTRING, 2, 5},
        {"chat.txt", TRUE, "q", SALQF_NONE, 0, 0},
    };
    for (int i = 0; i < (int)(sizeof(ex) / sizeof(ex[0])); i++)
    {
        char mask[3 * MAX_PATH];
        Legacy244::Prepare(mask, ex[i].Typed);
        CSalQFMatch r;
        BOOL got = SalQFMatchName(ex[i].Name, ex[i].HasExt, mask, TRUE, r);
        CHECK(got == (ex[i].Kind != SALQF_NONE));
        CHECK(r.Kind == ex[i].Kind);
        if (ex[i].Kind != SALQF_NONE)
        {
            CHECK(r.MatchStart == ex[i].Start);
            CHECK(r.MatchEnd == ex[i].End);
        }
    }
    {
        CSalQFMatch r;
        CHECK(!SalQFMatchName(NULL, FALSE, "a", TRUE, r) && r.Kind == SALQF_NONE);
        CHECK(!SalQFMatchName("a", FALSE, NULL, TRUE, r) && r.Kind == SALQF_NONE);
        // a mask of the longest accepted length against a long name: no read past the end
        static char longMask[3 * MAX_PATH];
        memset(longMask, 'a', sizeof(longMask) - 1);
        longMask[sizeof(longMask) - 1] = 0;
        CHECK(!SalQFMatchName("aaaa", FALSE, longMask, TRUE, r));
        static char longName[3 * MAX_PATH];
        memset(longName, 'b', sizeof(longName) - 1);
        longName[sizeof(longName) - 2] = 'a';
        longName[sizeof(longName) - 1] = 0;
        CHECK(SalQFMatchName(longName, FALSE, "a", TRUE, r) && r.Kind == SALQF_SUBSTRING && r.MatchStart == (int)sizeof(longName) - 2);
    }

    // keys (review 244): character boundaries, decomposition, case, an invalid byte, many names
    {
        CSalQFMatch r;
        // a base letter of a decomposed character matches only a whole character
        CHECK(!SalQFMatchName("x\xC3\xBA", FALSE, "u", TRUE, r));                                           // x + NFC u-acute
        CHECK(SalQFMatchName("xu\xCC\x81", FALSE, "u", TRUE, r) && r.MatchStart == 1 && r.MatchEnd == 2);    // NFD: u is a character there
        CHECK(SalQFMatchName("xu\xCC\x81y", FALSE, "\xC3\xBAy", TRUE, r) && r.MatchStart == 1 && r.MatchEnd == 5); // NFC mask, NFD name
        CHECK(SalQFMatchName("x\xC3\x9Ay", FALSE, "\xC3\xBA", TRUE, r) && r.MatchStart == 1 && r.MatchEnd == 3); // U-acute = u-acute
        CHECK(!SalQFMatchName("ab\x80" "cd", FALSE, "\xC3\xA1" "c", TRUE, r));                              // invalid byte: no crash, no match
        CHECK(SalQFMatchName("\xD0\x9F\xD1\x80\xD0\xB8\xD0\xB2\xD0\xB5\xD1\x82", FALSE, "\xD1\x80\xD0\xB8", TRUE, r) &&
              r.MatchStart == 2 && r.MatchEnd == 6); // Cyrillic
        CHECK(SalQFMatchName("x \xF0\x9F\x98\x80 y", FALSE, "\xF0\x9F\x98\x80", TRUE, r) && r.MatchStart == 2 && r.MatchEnd == 6); // emoji
        CHECK(SalQFMatchName("abc\xC3\xA1" "def", FALSE, "c/e", TRUE, r) && r.MatchStart == 2 && r.MatchEnd == 7); // wildcard, non-ASCII name
        CHECK(!SalQFMatchName("abc\xC3\xA1" "def", FALSE, "e/c", TRUE, r));
        // the new mode's prefix on keys: the dot tolerance, a leading wildcard, the old rule untouched
        CHECK(SalQFMatchName("\xC3\x9A\xC4\x8D" "et", FALSE, "\xC3\xBA\xC4\x8D" "et.", TRUE, r) && r.Kind == SALQF_PREFIX && r.MatchEnd == 6);
        CHECK(!SalQFMatchName("\xC3\x9A\xC4\x8D" "et.x", TRUE, "\xC3\xBA\xC4\x8D" "et.", TRUE, r) || r.Kind == SALQF_PREFIX && r.MatchEnd == 7);
        CHECK(SalQFMatchName("x\xC3\x9A\xC4\x8D" "et", FALSE, "/\xC4\x8D" "e", TRUE, r) && r.Kind == SALQF_PREFIX && r.MatchStart == 0 && r.MatchEnd == 6);
        {
            int legacyOffset = 0; // option off: the 0.1.10 rule, linguistic extras included
            BOOL legacy = Legacy244::Agree("Stra\xC3\x9F" "e.doc", TRUE, "strasse", legacyOffset);
            CHECK(SalQFMatchName("Stra\xC3\x9F" "e.doc", TRUE, "strasse", FALSE, r) == legacy && (!legacy || r.MatchEnd == legacyOffset));
        }
        // review 244 (round 2): a key longer than the 2048-unit scratch area grows on the heap, an ASCII
        // character at the boundary included; offsets stay byte offsets of characters
        {
            static char longText[6004];
            int pos = 0;
            for (int i = 0; i < 1500; i++)
            {
                memcpy(longText + pos, "ab\xC3\xA1", 4); // a b a-acute: 3 characters, 4 units
                pos += 4;
            }
            longText[pos] = 0;
            CSalQFKey lk;
            CHECK(SalQFBuildKey(longText, -1, lk));
            CHECK(lk.Count == 1500 * 4 && lk.Offsets[lk.Count] == pos && lk.Offsets[3] == 2 && lk.Starts[3] == 0 && lk.Starts[4] == 1);
            SalQFFreeKey(lk);
            static char asciiText[5000];
            memset(asciiText, 'x', 4999);
            asciiText[4999] = 0;
            CHECK(SalQFBuildKey(asciiText, -1, lk) && lk.Count == 4999 && lk.Offsets[4999] == 4999);
            SalQFFreeKey(lk);
        }
        // review 244 (round 2): a wildcard before the final dot ("a/.") against a non-ASCII name
        // without an extension - the dot tolerance as in 0.1.10, no uninitialised read
        {
            static const char* dotNames[] = {"a\xC3\xA9", "a\xC3\xA9.x", "\xC3\xA9" "a", "a"};
            for (int i = 0; i < 4; i++)
            {
                BOOL hasExt = strchr(dotNames[i], '.') != NULL;
                char m[16];
                Legacy244::Prepare(m, "a\\.");
                int off = 0;
                BOOL legacy = Legacy244::Agree(dotNames[i], hasExt, m, off);
                CSalQFMatch dr;
                BOOL got = SalQFMatchName(dotNames[i], hasExt, m, TRUE, dr);
                CHECK(legacy ? got && dr.Kind == SALQF_PREFIX && dr.MatchEnd == off : !got || dr.Kind != SALQF_PREFIX);
            }
        }
        // SalQFKeyFind with kept keys gives the same as building them per call
        const char* czech = "Z\xC3\xA1lohy \xC3\xBA\xC4\x8Dt\xC5\xAF 2024.xlsx";
        CSalQFKey key;
        CHECK(SalQFBuildKey(czech, -1, key));
        static CSalQFMaskKeys mk;
        CHECK(SalQFBuildMaskKeys("\xC3\xBA\xC4\x8D", mk));
        CSalQFMatch r1, r2;
        BOOL f1 = SalQFKeyFind(key, mk, 1, r1);
        BOOL f2 = SalQFMatchName(czech, TRUE, "\xC3\xBA\xC4\x8D", TRUE, r2);
        CHECK(f1 && f2 && r1.MatchStart == r2.MatchStart && r1.MatchEnd == r2.MatchEnd && r1.MatchStart == 8);
        SalQFFreeMaskKeys(mk);
        SalQFFreeKey(key);
        // timing: 10,000 Czech names of about 40 characters, keys built once, a mask matching none
        const int N = 10000;
        static char names[N][96];
        static CSalQFKey keys[N];
        for (int i = 0; i < N; i++)
            sprintf(names[i], "\xC3\xBA\xC4\x8D" "etn\xC3\xAD doklad %05d \xC5\x99\xC3\xA1" "dek \xC5\xBElu\xC5\xA5ou\xC4\x8Dk\xC3\xBD k\xC5\xAF\xC5\x88.txt", i);
        DWORD t0 = GetTickCount();
        for (int i = 0; i < N; i++)
            SalQFBuildKey(names[i], -1, keys[i]);
        DWORD t1 = GetTickCount();
        CHECK(SalQFBuildMaskKeys("xy\xC4\x8D", mk));
        int hits = 0;
        for (int i = 0; i < N; i++)
            if (SalQFKeyFind(keys[i], mk, 1, r))
                hits++;
        DWORD t2 = GetTickCount();
        CHECK(hits == 0);
        SalQFFreeMaskKeys(mk);
        CHECK(SalQFBuildMaskKeys("\xC5\x99\xC3\xA1" "d", mk)); // in every name
        hits = 0;
        for (int i = 0; i < N; i++)
            if (SalQFKeyFind(keys[i], mk, 1, r))
                hits++;
        CHECK(hits == N);
        SalQFFreeMaskKeys(mk);
        for (int i = 0; i < N; i++)
            SalQFFreeKey(keys[i]);
        printf("TestQuickFilter244: 10,000 Czech names: keys built in %u ms, a keystroke scans them in %u ms\n", t1 - t0, t2 - t1);
    }

    // M7 (ASCII names and masks): appending a character only narrows
    {
        static const char* asciiNames[] = {"2024_chatbot", "chat.txt", "xchatter.log", "Report.PDF", "readme", "a.b.c", "aXbXc"};
        static const char* asciiTyped[] = {"", "c", "ch", "a", "b/", "x", "r", ".", "t", "2"};
        static const char appended[] = {'a', 'b', 'c', 'h', 't', '.', '/', 'x', 'e', 'd'};
        int bad = 0;
        for (int n = 0; n < (int)(sizeof(asciiNames) / sizeof(asciiNames[0])); n++)
            for (int t = 0; t < (int)(sizeof(asciiTyped) / sizeof(asciiTyped[0])); t++)
                for (int a = 0; a < (int)sizeof(appended); a++)
                {
                    char shorter[64], longer[64], ms[64], ml[64];
                    strcpy(shorter, asciiTyped[t]);
                    sprintf(longer, "%s%c", asciiTyped[t], appended[a]);
                    Legacy244::Prepare(ms, shorter);
                    Legacy244::Prepare(ml, longer);
                    CSalQFMatch rs, rl;
                    BOOL hasExt = strchr(asciiNames[n], '.') != NULL;
                    BOOL gl = SalQFMatchName(asciiNames[n], hasExt, ml, TRUE, rl);
                    BOOL gs = SalQFMatchName(asciiNames[n], hasExt, ms, TRUE, rs);
                    if (gl && !gs)
                        bad++;
                }
        CHECK(bad == 0);
    }

    // F1-F4: the focus
    {
        const BYTE N = SALQF_NONE, S = SALQF_SUBSTRING, P = SALQF_PREFIX;
        BYTE k1[] = {N, S, P, S, P};
        CHECK(SalQFChooseFocus(k1, 5, 2) == 2); // F1 the current prefix match stays
        CHECK(SalQFChooseFocus(k1, 5, 1) == 2); // F2 the first prefix match below
        CHECK(SalQFChooseFocus(k1, 5, 3) == 4);
        BYTE k2[] = {P, S, S, N};
        CHECK(SalQFChooseFocus(k2, 4, 2) == 0); // F2 nearest above when none below
        BYTE k3[] = {N, S, N, S};
        CHECK(SalQFChooseFocus(k3, 4, 3) == 3); // F3 the current substring match
        CHECK(SalQFChooseFocus(k3, 4, 2) == 3); // first substring below
        CHECK(SalQFChooseFocus(k3, 4, 0) == 1);
        BYTE k4[] = {S, N, N};
        CHECK(SalQFChooseFocus(k4, 3, 2) == 0); // nearest substring above
        BYTE k5[] = {N, N};
        CHECK(SalQFChooseFocus(k5, 2, 0) == -1); // nothing matches
        BYTE k6[] = {S};
        CHECK(SalQFChooseFocus(k6, 1, 0) == 0); // F4
        CHECK(SalQFChooseFocus(k6, 1, 7) == 0); // clamped
        CHECK(SalQFChooseFocus(k6, 1, -3) == 0);
        CHECK(SalQFChooseFocus(NULL, 1, 0) == -1);
        BYTE k7[] = {P, N, N, P};
        CHECK(SalQFChooseFocus(k7, 4, 1) == 3); // below wins over above
    }

    // T1-T4: the tint, for the built-in schemes (salamdr1.cpp:519-729; a "default" colour taken as
    // Windows 11 shows it: window white, window text black, active caption 153,180,209 - and as the
    // scheme's own value 0,0,128) and Dark (themes_palette.h)
    {
        struct Scheme
        {
            const char* Name;
            COLORREF Fg, Bk, Selected, Focused, FocSel, Caption;
        };
        COLORREF panel[DP_COUNT];
#define TP_FILL244(name, r, g, b) panel[DP_##name] = RGB(r, g, b);
        THEME_DARK_PANEL_COLORS(TP_FILL244)
#undef TP_FILL244
        const Scheme schemes[] = {
            {"Salamander/caption sys", RGB(0, 0, 0), RGB(255, 255, 255), RGB(255, 255, 255), RGB(232, 232, 232), RGB(232, 232, 232), RGB(153, 180, 209)},
            {"Salamander/caption 0,0,128", RGB(0, 0, 0), RGB(255, 255, 255), RGB(255, 255, 255), RGB(232, 232, 232), RGB(232, 232, 232), RGB(0, 0, 128)},
            {"Explorer/caption sys", RGB(0, 0, 0), RGB(255, 255, 255), RGB(0, 0, 128), RGB(232, 232, 232), RGB(0, 0, 128), RGB(153, 180, 209)},
            {"Explorer/caption 0,0,128", RGB(0, 0, 0), RGB(255, 255, 255), RGB(0, 0, 128), RGB(232, 232, 232), RGB(0, 0, 128), RGB(0, 0, 128)},
            {"Norton/caption sys", RGB(0, 255, 255), RGB(0, 0, 128), RGB(0, 0, 128), RGB(0, 128, 128), RGB(0, 128, 128), RGB(153, 180, 209)},
            {"Norton/caption 0,0,128", RGB(0, 255, 255), RGB(0, 0, 128), RGB(0, 0, 128), RGB(0, 128, 128), RGB(0, 128, 128), RGB(0, 0, 128)},
            {"Navigator/caption sys", RGB(255, 255, 255), RGB(80, 80, 80), RGB(80, 80, 80), RGB(0, 128, 128), RGB(0, 128, 128), RGB(153, 180, 209)},
            {"Navigator/caption 0,0,128", RGB(255, 255, 255), RGB(80, 80, 80), RGB(80, 80, 80), RGB(0, 128, 128), RGB(0, 128, 128), RGB(0, 0, 128)},
            {"Dark", panel[DP_ITEM_FG_NORMAL], panel[DP_ITEM_BK_NORMAL], panel[DP_ITEM_BK_SELECTED], panel[DP_ITEM_BK_FOCUSED], panel[DP_ITEM_BK_FOCSEL], panel[DP_ACTIVE_CAPTION_BK]},
            {"custom: caption = background", RGB(0, 0, 0), RGB(240, 240, 240), RGB(240, 240, 240), RGB(200, 200, 200), RGB(200, 200, 200), RGB(240, 240, 240)},
            {"custom: black", RGB(255, 255, 255), RGB(0, 0, 0), RGB(0, 0, 0), RGB(60, 60, 60), RGB(60, 60, 60), RGB(0, 0, 0)},
        };
        // the last resort (review 244): text that barely contrasts with its background - the tint must
        // still be visible
        {
            COLORREF avoid[1] = {RGB(60, 60, 60)};
            COLORREF t = SalQFTint(RGB(0, 0, 0), RGB(0, 0, 0), RGB(100, 100, 100), avoid, 1);
            CHECK(SalQFDistance(t, RGB(0, 0, 0)) >= SALQF_TINT_MIN_DISTANCE);
            CHECK(SalQFTint(RGB(0, 0, 0), RGB(0, 0, 0), RGB(100, 100, 100), NULL, 0) != RGB(0, 0, 0));
        }
        for (int i = 0; i < (int)(sizeof(schemes) / sizeof(schemes[0])); i++)
        {
            const Scheme& s = schemes[i];
            COLORREF avoid[3] = {s.Selected, s.Focused, s.FocSel};
            COLORREF t = SalQFTint(s.Bk, s.Caption, s.Fg, avoid, 3);
            CHECK(t == SalQFTint(s.Bk, s.Caption, s.Fg, avoid, 3)); // T4
            double own = SalQFContrast(s.Fg, s.Bk);
            BOOL contrastOk = SalQFContrast(s.Fg, t) >= (own < 4.5 ? own : 4.5) - 0.25; // T2
            BOOL distOk = SalQFDistance(t, s.Bk) >= SALQF_TINT_MIN_DISTANCE;            // T3
            for (int a = 0; a < 3; a++)
                if (avoid[a] != s.Bk && SalQFDistance(t, avoid[a]) < SALQF_TINT_MIN_DISTANCE)
                    distOk = FALSE;
            CHECK(contrastOk);
            CHECK(distOk);
            printf("TestQuickFilter244: tint %-30s background %3d,%3d,%3d -> %3d,%3d,%3d (distance %.0f, text contrast %.1f -> %.1f)\n", s.Name,
                   GetRValue(s.Bk), GetGValue(s.Bk), GetBValue(s.Bk), GetRValue(t), GetGValue(t), GetBValue(t), SalQFDistance(t, s.Bk), own,
                   SalQFContrast(s.Fg, t));
        }
    }
}

// feature 245: settings import from Altap Salamander / Open Salamander (salcfgimport.h)
static BOOL Cfg245ExistsIn(void* ctx, const char* name)
{
    const char* const* list = (const char* const*)ctx;
    for (int i = 0; list[i] != NULL; i++)
        if (strcmp(list[i], name) == 0)
            return TRUE;
    return FALSE;
}

static CSalCfgKey* Cfg245HotPathKey(CSalCfgKey* root, const char* slot, const char* name, const char* path, DWORD visible)
{
    CSalCfgKey* hp = (CSalCfgKey*)SalCfgKeyFind(root, "Hot Paths");
    if (hp == NULL)
        hp = SalCfgKeyAddKey(root, "Hot Paths");
    CSalCfgKey* k = SalCfgKeyAddKey(hp, slot);
    if (name != NULL)
        SalCfgKeyAddString(k, "Name", name);
    if (path != NULL)
        SalCfgKeyAddString(k, "Path", path);
    SalCfgKeyAddDword(k, "Visible", visible);
    return k;
}

static CSalCfgKey* Cfg245MenuItem(CSalCfgKey* menu, int index, const char* name, const char* cmd, DWORD type)
{
    char buf[16];
    sprintf(buf, "%d", index);
    CSalCfgKey* k = SalCfgKeyAddKey(menu, buf);
    SalCfgKeyAddString(k, "Item Name", name);
    SalCfgKeyAddString(k, "Command", cmd);
    SalCfgKeyAddDword(k, "Execute Through Shell", 0);
    SalCfgKeyAddDword(k, "Close Shell Window", 1);
    SalCfgKeyAddDword(k, "Type", type);
    return k;
}

static void TestCfgImport245()
{
    // ---- tree
    CSalCfgKey* root = SalCfgKeyNew("root");
    CHECK(root != NULL);
    CSalCfgKey* cfg = SalCfgKeyAddKey(root, "Configuration");
    CSalCfgKey* conf = SalCfgKeyAddKey(cfg, "Confirmation");
    CHECK(SalCfgKeyAddDword(cfg, "Single Click", 1));
    CHECK(SalCfgKeyAddString(cfg, "Info", "a" U8_C_CARON_NFC));
    BYTE bin[3] = {1, 0, 2};
    CHECK(SalCfgKeyAddValue(conf, "Blob", REG_BINARY, bin, 3));
    CHECK(SalCfgKeyAddValue(conf, "Odd", REG_SZ, "abc", 3)); // no terminator in the data
    CHECK(SalCfgKeyFind(root, "configuration\\CONFIRMATION") == conf); // ASCII case-insensitive
    CHECK(SalCfgKeyFind(root, "Configuration\\Missing") == NULL);
    CHECK(SalCfgKeyFind(root, "") == root);
    CHECK(SalCfgKeyFindChild(root, "Configuratio") == NULL); // no prefix match
    CHECK(SalCfgKeyFind(root, "Configuratio") == NULL);
    DWORD dw = 0;
    CHECK(SalCfgGetDword(cfg, "single click", &dw) && dw == 1);
    CHECK(!SalCfgGetDword(cfg, "Info", &dw)); // wrong type
    CHECK(SalCfgGetString(cfg, "Info") != NULL && strcmp(SalCfgGetString(cfg, "Info"), "a" U8_C_CARON_NFC) == 0);
    CHECK(SalCfgGetString(cfg, "Single Click") == NULL); // wrong type
    CHECK(SalCfgGetString(conf, "Odd") != NULL && strcmp(SalCfgGetString(conf, "Odd"), "abc") == 0); // terminated by the tree
    DWORD sz = 0;
    const BYTE* b = SalCfgGetBinary(conf, "Blob", REG_BINARY, &sz);
    CHECK(b != NULL && sz == 3 && b[0] == 1 && b[1] == 0 && b[2] == 2);
    CHECK(SalCfgGetBinary(conf, "Blob", REG_DWORD, &sz) == NULL);
    CHECK(SalCfgValueFind(conf, "Missing") == NULL);
    // many keys and values (growth)
    for (int i = 0; i < 100; i++)
    {
        char n[16];
        sprintf(n, "k%d", i);
        CHECK(SalCfgKeyAddKey(conf, n) != NULL);
        CHECK(SalCfgKeyAddDword(conf, n, (DWORD)i));
    }
    CHECK(SalCfgKeyFind(conf, "k99") != NULL && SalCfgGetDword(conf, "K57", &dw) && dw == 57);
    SalCfgKeyFree(root);

    // ---- sources
    CHECK(SalCfgImpRootCount() == 83);
    CHECK(strcmp(SalCfgImpRoot(0), "Software\\Open Salamander\\5.0") == 0);
    CHECK(strcmp(SalCfgImpRoot(1), "Software\\Altap\\Altap Salamander 4.0") == 0);
    CHECK(strcmp(SalCfgImpRoot(82), "Software\\Salamander") == 0);
    CHECK(SalCfgImpRoot(83) == NULL && SalCfgImpRoot(-1) == NULL);
    int allowedRoots = 0;
    for (int i = 0; i < SalCfgImpRootCount(); i++)
    {
        if (SalCfgImpIsForeignRootAllowed(SalCfgImpRoot(i)))
            allowedRoots++;
        CHECK(strstr(SalCfgImpRoot(i), "Tandem") == NULL && strstr(SalCfgImpRoot(i), "Newt") == NULL);
    }
    CHECK(allowedRoots == 83);
    CHECK(!SalCfgImpIsForeignRootAllowed("Software\\Tandem Commander\\0.1"));
    CHECK(!SalCfgImpIsForeignRootAllowed("software\\newt commander\\0.1"));
    CHECK(!SalCfgImpIsForeignRootAllowed("Software\\Tandem Commander"));
    CHECK(SalCfgImpIsForeignRootAllowed("Software\\Tandem Commander Test 245\\src1")); // fixtures live beside it
    CHECK(!SalCfgImpIsForeignRootAllowed(""));
    CHECK(!SalCfgImpIsForeignRootAllowed(NULL));
    CHECK(SalCfgImpClassify(38, 106) == SALCFGIMP_TOO_OLD);
    CHECK(SalCfgImpClassify(39, 106) == SALCFGIMP_SUPPORTED);
    CHECK(SalCfgImpClassify(103, 106) == SALCFGIMP_SUPPORTED);
    CHECK(SalCfgImpClassify(106, 106) == SALCFGIMP_SUPPORTED);
    CHECK(SalCfgImpClassify(107, 106) == SALCFGIMP_TOO_NEW);
    CHECK(SalCfgImpClassify(1, 106) == SALCFGIMP_TOO_OLD);
    char pn[64];
    CHECK(SalCfgImpProductName("Software\\Altap\\Altap Salamander 4.0", pn, sizeof(pn)) && strcmp(pn, "Altap Salamander 4.0") == 0);
    CHECK(SalCfgImpProductName("Software\\Open Salamander\\5.0", pn, sizeof(pn)) && strcmp(pn, "Open Salamander 5.0") == 0);
    CHECK(SalCfgImpProductName("Software\\Salamander", pn, sizeof(pn)) && strcmp(pn, "Salamander") == 0);
    CHECK(!SalCfgImpProductName("Software\\Open Salamander\\5.0", pn, 10) && pn[0] == 0); // never cut
    CHECK(SalCfgImpCompareSources(104, 0, 103, 1) < 0);
    CHECK(SalCfgImpCompareSources(103, 1, 104, 0) > 0);
    CHECK(SalCfgImpCompareSources(103, 2, 103, 5) < 0);

    // ---- conversions
    char out[64];
    CHECK(SalCfgImpDuplicateDollars("$(SalDir)\\a$b", out, sizeof(out)) && strcmp(out, "$$(SalDir)\\a$$b") == 0);
    CHECK(SalCfgImpDuplicateDollars("", out, sizeof(out)) && out[0] == 0);
    CHECK(!SalCfgImpDuplicateDollars("$$$$", out, 8) && out[0] == 0); // needs 9 bytes: refused, not cut
    CHECK(SalCfgImpDuplicateDollars("$$$", out, 7) && strcmp(out, "$$$$$$") == 0); // exact fit
    CHECK(SalCfgImpUnescapeDollars("$$(SalDir)\\a$$b$", out, sizeof(out)) && strcmp(out, "$(SalDir)\\a$b$") == 0);
    CHECK(SalCfgImpLowerAscii("*.TXT;Read" U8_CAP_C_CARON_NFC ".DOC", out, sizeof(out)) &&
          strcmp(out, "*.txt;read" U8_CAP_C_CARON_NFC ".doc") == 0); // non-ASCII untouched
    CHECK(!SalCfgImpLowerAscii("ABCDEF", out, 6) && out[0] == 0);

    // ---- identities
    char key[128];
    CHECK(SalCfgImpMasksKey("*.TXT; *.doc;*.txt;;  ", key, sizeof(key)) && strcmp(key, "*.doc;*.txt") == 0);
    char key2[128];
    CHECK(SalCfgImpMasksKey("*.doc;*.Txt", key2, sizeof(key2)) && strcmp(key, key2) == 0);
    CHECK(SalCfgImpMasksKey("", key, sizeof(key)) && key[0] == 0);
    CHECK(SalCfgImpMasksKey("*.a;*.b", key, sizeof(key)) && strcmp(key, "*.a;*.b") == 0);
    CHECK(SalCfgImpMasksKey("*.b;*.a", key2, sizeof(key2)) && strcmp(key, key2) == 0);
    CHECK(!SalCfgImpMasksKey("*.aaaa;*.bbbb", key, 8) && key[0] == 0);
    CHECK(SalCfgImpMasksKey("*." U8_C_CARON_NFC, key, sizeof(key)) && strcmp(key, "*." U8_C_CARON_NFC) == 0);

    CHECK(SalCfgImpTrimTrailingSlash("C:\\Data\\", out, sizeof(out)) && strcmp(out, "C:\\Data") == 0);
    CHECK(SalCfgImpTrimTrailingSlash("C:\\Data\\\\", out, sizeof(out)) && strcmp(out, "C:\\Data") == 0);
    CHECK(SalCfgImpTrimTrailingSlash("C:\\", out, sizeof(out)) && strcmp(out, "C:\\") == 0);
    CHECK(SalCfgImpTrimTrailingSlash("\\", out, sizeof(out)) && strcmp(out, "\\") == 0);
    CHECK(SalCfgImpTrimTrailingSlash("\\\\", out, sizeof(out)) && strcmp(out, "\\\\") == 0);
    CHECK(SalCfgImpTrimTrailingSlash("\\\\srv\\share\\", out, sizeof(out)) && strcmp(out, "\\\\srv\\share") == 0);
    CHECK(SalCfgImpTrimTrailingSlash("ftp://host/", out, sizeof(out)) && strcmp(out, "ftp://host/") == 0);
    CHECK(!SalCfgImpTrimTrailingSlash("C:\\very\\long", out, 5));

    const char* names[] = {"Server", "Server (imported)", "Server (imported 2)", NULL};
    char un[64];
    CHECK(SalCfgImpUniqueName("Other", "(imported)", "(imported %d)", Cfg245ExistsIn, (void*)names, un, sizeof(un)) &&
          strcmp(un, "Other") == 0);
    CHECK(SalCfgImpUniqueName("Server", "(imported)", "(imported %d)", Cfg245ExistsIn, (void*)names, un, sizeof(un)) &&
          strcmp(un, "Server (imported 3)") == 0);
    // a hostile translated format falls back to "(%d)"
    CHECK(SalCfgImpUniqueName("Server", "(imported)", "%s %n", Cfg245ExistsIn, (void*)names, un, sizeof(un)) &&
          strcmp(un, "Server (2)") == 0);
    CHECK(SalCfgImpUniqueName("Server", "(imported)", "(%d%%)", Cfg245ExistsIn, (void*)names, un, sizeof(un)) &&
          strcmp(un, "Server (2)") == 0);
    // shortened at a character boundary to fit
    const char* none[] = {"x", NULL};
    const char* longBase = "Abc" U8_C_CARON_NFC U8_C_CARON_NFC "def"; // 3 + 2 + 2 + 3 bytes
    CHECK(SalCfgImpUniqueName(longBase, "(i)", "(i %d)", Cfg245ExistsIn, (void*)none, un, 6) && strcmp(un, "Abc" U8_C_CARON_NFC) == 0);
    CHECK(SalCfgImpUniqueName(longBase, "(i)", "(i %d)", Cfg245ExistsIn, (void*)none, un, 5) && strcmp(un, "Abc") == 0); // never half a character
    const char* taken[] = {"Abc" U8_C_CARON_NFC, NULL};
    CHECK(SalCfgImpUniqueName(longBase, "(i)", "(i %d)", Cfg245ExistsIn, (void*)taken, un, 6) && strcmp(un, "A (i)") == 0);
    CHECK(!SalCfgImpUniqueName("Server", "(imported)", "(imported %d)", Cfg245ExistsIn, (void*)names, un, 1));

    // ---- placement and merge
    BOOL occ[30] = {0};
    occ[0] = occ[1] = TRUE;
    CHECK(SalCfgImpPlaceHotPath(occ, 30, 4) == 4);
    CHECK(SalCfgImpPlaceHotPath(occ, 30, 1) == 2);
    CHECK(SalCfgImpPlaceHotPath(occ, 30, -1) == 2);
    CHECK(SalCfgImpPlaceHotPath(occ, 30, 99) == 2);
    for (int i = 0; i < 30; i++)
        occ[i] = TRUE;
    CHECK(SalCfgImpPlaceHotPath(occ, 30, 3) == -1);
    occ[29] = FALSE;
    CHECK(SalCfgImpPlaceHotPath(occ, 30, 3) == 29);
    CHECK(SalCfgImpPlaceHotPath(NULL, 30, 3) == -1);

    const char* cur[] = {"a", "b", NULL};
    const char* imp[] = {"b", "c", "", "c", "d"};
    const char* merged[8];
    int mn = SalCfgImpMergeHistory(cur, 2, imp, 5, merged, 8);
    CHECK(mn == 4 && strcmp(merged[0], "a") == 0 && strcmp(merged[1], "b") == 0 && strcmp(merged[2], "c") == 0 &&
          strcmp(merged[3], "d") == 0);
    mn = SalCfgImpMergeHistory(cur, 2, imp, 5, merged, 3);
    CHECK(mn == 3 && strcmp(merged[2], "c") == 0); // capacity: current entries never pushed out
    mn = SalCfgImpMergeHistory(cur, 2, imp, 5, merged, 1);
    CHECK(mn == 1 && strcmp(merged[0], "a") == 0);
    mn = SalCfgImpMergeHistory(NULL, 0, imp, 5, merged, 8);
    CHECK(mn == 3);

    CHECK(SalCfgImpDefaultDirValid("C", "C:\\Data", MAX_PATH));
    CHECK(SalCfgImpDefaultDirValid("c", "C:\\", MAX_PATH));
    CHECK(!SalCfgImpDefaultDirValid("C", "D:\\Data", MAX_PATH));
    CHECK(!SalCfgImpDefaultDirValid("CC", "C:\\Data", MAX_PATH));
    CHECK(!SalCfgImpDefaultDirValid("1", "1:\\Data", MAX_PATH));
    CHECK(!SalCfgImpDefaultDirValid("C", "C:", MAX_PATH));
    CHECK(!SalCfgImpDefaultDirValid("C", "C:Data", MAX_PATH));
    CHECK(!SalCfgImpDefaultDirValid("C", "C:\\Data", 7)); // too long for the program's buffer
    CHECK(SalCfgImpDefaultDirValid("C", "C:\\Dat", 7));

    // ---- forbidden options
    CHECK(SalCfgImpIsForbiddenOption("Configuration", "Theme Mode"));
    CHECK(SalCfgImpIsForbiddenOption("configuration", "panel tabs"));
    CHECK(SalCfgImpIsForbiddenOption("Configuration", "Quick Search Filter"));
    CHECK(SalCfgImpIsForbiddenOption("Configuration", "Command Shell Program"));
    CHECK(SalCfgImpIsForbiddenOption("Configuration", "Language"));
    CHECK(SalCfgImpIsForbiddenOption("Configuration", "Plugins.ver Version (x64)"));
    CHECK(SalCfgImpIsForbiddenOption("Configuration", "Top ToolBar"));
    CHECK(SalCfgImpIsForbiddenOption("Configuration", "Save Configuration On Exit"));
    CHECK(SalCfgImpIsForbiddenOption("Viewer", "Left"));
    CHECK(SalCfgImpIsForbiddenOption("Viewer", "Find Text"));
    CHECK(!SalCfgImpIsForbiddenOption("Configuration", "Single Click"));
    CHECK(!SalCfgImpIsForbiddenOption("Viewer", "Wrap Text"));
    CHECK(!SalCfgImpIsForbiddenOption("Configuration\\Confirmation", "Left")); // only in the Viewer key
    CHECK(SalCfgImpIsForbiddenOption(NULL, "x"));

    // ---- DLL matching
    CHECK(SalCfgImpSameDll("ftp\\ftp.spl", "ftp\\ftp.spl"));
    CHECK(SalCfgImpSameDll("FTP\\FTP.SPL", "ftp\\ftp.spl"));
    CHECK(SalCfgImpSameDll("ftp/ftp.spl", "ftp\\ftp.spl"));
    CHECK(SalCfgImpSameDll("C:\\Program Files\\Altap Salamander\\plugins\\ftp\\ftp.spl", "ftp\\ftp.spl"));
    CHECK(SalCfgImpSameDll("\\\\srv\\sal\\plugins\\ftp\\ftp.spl", "ftp\\ftp.spl"));
    CHECK(!SalCfgImpSameDll("ftp\\ftp.spl", "sftp\\sftp.spl"));
    CHECK(!SalCfgImpSameDll("C:\\x\\ieviewer\\ieviewer.spl", "ftp\\ftp.spl"));
    CHECK(!SalCfgImpSameDll("other\\ftp.spl", "ftp\\ftp.spl"));
    CHECK(!SalCfgImpSameDll("", "ftp\\ftp.spl"));
    CHECK(!SalCfgImpSameDll("ftp\\ftp.spl", NULL));

    // ---- hot paths parser
    root = SalCfgKeyNew("src");
    Cfg245HotPathKey(root, "1", "Projects", "C:\\Projects", 1);
    Cfg245HotPathKey(root, "2", "D:\\Data", "D:\\Data", 0);              // name = path text: unnamed (047)
    Cfg245HotPathKey(root, "3", "Sal", "$(SalDir)\\x", 1);               // old version: '$' doubled
    Cfg245HotPathKey(root, "0", "Ten (old)", "C:\\Ten0", 1);             // key 0 = slot 10 ...
    Cfg245HotPathKey(root, "10", "  Ten  ", "C:\\Ten", 1);               // ... key 10 wins (read later), name trimmed
    Cfg245HotPathKey(root, "11", "NoPath", NULL, 1);                      // no path: unused
    Cfg245HotPathKey(root, "12", U8_C_CARON_NFC "es", "E:\\" U8_C_CARON_NFC, 1); // non-ASCII
    Cfg245HotPathKey(root, "31", "Out of range", "C:\\X", 1);              // slot 32 does not exist
    CSalCfgImpHotPath hps[SALCFGIMP_HOTPATHS];
    memset(hps, 0, sizeof(hps));
    int used = SalCfgImpParseHotPaths(SalCfgKeyFind(root, "Hot Paths"), 46, MAX_PATH, 4 * MAX_PATH, hps);
    CHECK(used == 5);
    CHECK(hps[0].Used && strcmp(hps[0].Name, "Projects") == 0 && strcmp(hps[0].Path, "C:\\Projects") == 0 && hps[0].Visible);
    CHECK(hps[1].Used && hps[1].Name[0] == 0 && !hps[1].Visible);
    CHECK(hps[2].Used && strcmp(hps[2].Path, "$$(SalDir)\\x") == 0);
    CHECK(hps[9].Used && strcmp(hps[9].Name, "Ten") == 0 && strcmp(hps[9].Path, "C:\\Ten") == 0);
    CHECK(!hps[10].Used);
    CHECK(hps[11].Used && strcmp(hps[11].Name, U8_C_CARON_NFC "es") == 0 && strcmp(hps[11].Path, "E:\\" U8_C_CARON_NFC) == 0);
    SalCfgImpFreeHotPaths(hps, SALCFGIMP_HOTPATHS);
    memset(hps, 0, sizeof(hps));
    used = SalCfgImpParseHotPaths(SalCfgKeyFind(root, "Hot Paths"), 103, MAX_PATH, 4 * MAX_PATH, hps);
    CHECK(used == 5 && strcmp(hps[2].Path, "$(SalDir)\\x") == 0); // 103: stored as is
    SalCfgImpFreeHotPaths(hps, SALCFGIMP_HOTPATHS);
    // a path longer than the program's limit: the slot is reported, not cut
    memset(hps, 0, sizeof(hps));
    used = SalCfgImpParseHotPaths(SalCfgKeyFind(root, "Hot Paths"), 103, MAX_PATH, 8, hps);
    CHECK(!hps[0].Used && hps[0].TooLong); // "C:\Projects" does not fit 8 bytes
    CHECK(hps[9].Used && !hps[9].TooLong); // "C:\Ten" fits
    SalCfgImpFreeHotPaths(hps, SALCFGIMP_HOTPATHS);
    CHECK(SalCfgImpParseHotPaths(NULL, 103, MAX_PATH, 4 * MAX_PATH, hps) == 0);
    SalCfgKeyFree(root);

    // ---- user menu parser + Add plan
    root = SalCfgKeyNew("src");
    CSalCfgKey* um = SalCfgKeyAddKey(root, "User Menu");
    Cfg245MenuItem(um, 1, "Notepad", "notepad.exe", SALCFGIMP_UM_ITEM);
    Cfg245MenuItem(um, 2, "-", "", SALCFGIMP_UM_SEPARATOR);
    Cfg245MenuItem(um, 3, "Tools", "", SALCFGIMP_UM_SUBMENUBEGIN);
    Cfg245MenuItem(um, 4, "Calc", "calc.exe", SALCFGIMP_UM_ITEM);
    Cfg245MenuItem(um, 5, "", "", SALCFGIMP_UM_SUBMENUEND);
    CSalCfgKey* noType = Cfg245MenuItem(um, 6, "Old", "old.exe", 0);
    // an item without "Type" but with "Separator" (older layout)
    CSalCfgKey* um7 = SalCfgKeyAddKey(um, "7");
    SalCfgKeyAddString(um7, "Item Name", "sep");
    SalCfgKeyAddString(um7, "Command", "");
    SalCfgKeyAddDword(um7, "Execute Through Shell", 0);
    SalCfgKeyAddDword(um7, "Close Shell Window", 0);
    SalCfgKeyAddDword(um7, "Separator", 1);
    // item 8 is invalid (no Command) -> reading stops, item 9 is never read
    CSalCfgKey* um8 = SalCfgKeyAddKey(um, "8");
    SalCfgKeyAddString(um8, "Item Name", "broken");
    Cfg245MenuItem(um, 9, "After", "after.exe", SALCFGIMP_UM_ITEM);
    (void)noType;
    CSalCfgImpMenuItem* src = NULL;
    int stop = -1;
    int srcCount = SalCfgImpParseUserMenu(SalCfgKeyFind(root, "User Menu"), MAX_PATH, 32 * 1024, &src, &stop);
    CHECK(srcCount == 7 && stop == 1);
    CHECK(srcCount == 7 && src[0].Type == SALCFGIMP_UM_ITEM && strcmp(src[0].InitDir, "$(Drive)$(Path)") == 0 &&
          src[0].UseWindow == TRUE && src[0].ShowInToolbar == TRUE && src[0].Arguments[0] == 0);
    CHECK(srcCount == 7 && src[6].Type == SALCFGIMP_UM_SEPARATOR);
    CHECK(SalCfgImpMenuBlockEnd(src, srcCount, 2) == 5);
    CHECK(SalCfgImpMenuBlockEnd(src, srcCount, 0) == 1);
    // current menu: "Notepad" and the same "Tools" submenu exist
    CSalCfgImpMenuItem curMenu[4];
    memset(curMenu, 0, sizeof(curMenu));
    for (int i = 0; i < 4; i++)
    {
        curMenu[i] = src[i == 0 ? 0 : i + 1]; // shallow: Notepad, Tools, Calc, end
    }
    int decision[16];
    SalCfgImpPlanUserMenuAdd(curMenu, 4, src, srcCount, decision);
    CHECK(decision[0] == SALCFGIMP_UMD_PRESENT); // Notepad
    CHECK(decision[1] == SALCFGIMP_UMD_DROPSEP); // separator before nothing appended yet
    CHECK(decision[2] == SALCFGIMP_UMD_PRESENT && decision[3] == SALCFGIMP_UMD_INBLOCK && decision[4] == SALCFGIMP_UMD_INBLOCK);
    CHECK(decision[5] == SALCFGIMP_UMD_APPEND); // Old
    CHECK(decision[6] == SALCFGIMP_UMD_DROPSEP); // trailing separator
    // empty current menu: everything appended, the separator between appended blocks kept
    SalCfgImpPlanUserMenuAdd(NULL, 0, src, srcCount, decision);
    CHECK(decision[0] == SALCFGIMP_UMD_APPEND && decision[1] == SALCFGIMP_UMD_APPEND && decision[2] == SALCFGIMP_UMD_APPEND &&
          decision[5] == SALCFGIMP_UMD_APPEND && decision[6] == SALCFGIMP_UMD_DROPSEP);
    // a submenu with different content is appended whole
    char calc2[] = "calc2.exe";
    curMenu[2].Command = calc2;
    SalCfgImpPlanUserMenuAdd(curMenu, 4, src, srcCount, decision);
    CHECK(decision[2] == SALCFGIMP_UMD_APPEND && decision[1] == SALCFGIMP_UMD_DROPSEP);
    // separators never count as equal items
    CHECK(!SalCfgImpMenuItemEqual(&src[1], &src[1]));
    CHECK(SalCfgImpMenuItemEqual(&src[0], &src[0]));
    SalCfgImpFreeMenu(src, srcCount);
    // a too long value leaves out that entry only (never cut); a submenu goes with all its entries
    int tooLong = -1;
    srcCount = SalCfgImpParseUserMenu(SalCfgKeyFind(root, "User Menu"), 8, 32 * 1024, &src, &stop, &tooLong);
    // every entry has the default initial directory "$(Drive)$(Path)" (15 bytes): 1, 2, 3 (with 4
    // and 5 inside it), 6 and 7 are left out, item 8 still stops reading
    CHECK(srcCount == 0 && stop == 1 && tooLong == 5);
    SalCfgImpFreeMenu(src, srcCount);
    SalCfgKeyFree(root);
    {
        CSalCfgKey* r2 = SalCfgKeyNew("src");
        CSalCfgKey* m2 = SalCfgKeyAddKey(r2, "User Menu");
        Cfg245MenuItem(m2, 1, "A", "a.exe", SALCFGIMP_UM_ITEM);
        Cfg245MenuItem(m2, 2, "A submenu whose name is longer than the limit of this test", "", SALCFGIMP_UM_SUBMENUBEGIN);
        Cfg245MenuItem(m2, 3, "Inner", "in.exe", SALCFGIMP_UM_ITEM);
        Cfg245MenuItem(m2, 4, "Deeper", "", SALCFGIMP_UM_SUBMENUBEGIN);
        Cfg245MenuItem(m2, 5, "", "", SALCFGIMP_UM_SUBMENUEND);
        Cfg245MenuItem(m2, 6, "", "", SALCFGIMP_UM_SUBMENUEND);
        Cfg245MenuItem(m2, 7, "B", "b.exe", SALCFGIMP_UM_ITEM);
        CSalCfgImpMenuItem* m2items = NULL;
        int m2stop = -1, m2long = -1;
        int m2count = SalCfgImpParseUserMenu(SalCfgKeyFind(r2, "User Menu"), 40, 32 * 1024, &m2items, &m2stop, &m2long);
        CHECK(m2count == 2 && m2stop == 0 && m2long == 1); // the submenu (2-6) is left out whole
        CHECK(m2count == 2 && strcmp(m2items[0].Name, "A") == 0 && strcmp(m2items[1].Name, "B") == 0);
        SalCfgImpFreeMenu(m2items, m2count);
        SalCfgKeyFree(r2);
        // the texts of a submenu end are not used: a long one never unbalances the menu
        CSalCfgKey* r4 = SalCfgKeyNew("src");
        CSalCfgKey* m4 = SalCfgKeyAddKey(r4, "User Menu");
        Cfg245MenuItem(m4, 1, "S", "", SALCFGIMP_UM_SUBMENUBEGIN);
        Cfg245MenuItem(m4, 2, "I", "i.exe", SALCFGIMP_UM_ITEM);
        Cfg245MenuItem(m4, 3, "an end entry with a text longer than the limit of this test", "", SALCFGIMP_UM_SUBMENUEND);
        CSalCfgImpMenuItem* m4items = NULL;
        int m4stop = -1, m4long = -1;
        int m4count = SalCfgImpParseUserMenu(SalCfgKeyFind(r4, "User Menu"), 40, 32 * 1024, &m4items, &m4stop, &m4long);
        CHECK(m4count == 3 && m4long == 0 && m4items[2].Type == SALCFGIMP_UM_SUBMENUEND && m4items[2].Name[0] == 0);
        CHECK(SalCfgImpMenuBlockEnd(m4items, m4count, 0) == 3);
        SalCfgImpFreeMenu(m4items, m4count);
        SalCfgKeyFree(r4);
    }

    // ---- viewers parser
    root = SalCfgKeyNew("src");
    CSalCfgKey* vw = SalCfgKeyAddKey(root, "Viewers");
    CSalCfgKey* v1 = SalCfgKeyAddKey(vw, "1");
    SalCfgKeyAddString(v1, "Masks", "*.TXT");
    SalCfgKeyAddDword(v1, "Type", 1);
    CSalCfgKey* v2 = SalCfgKeyAddKey(vw, "2");
    SalCfgKeyAddString(v2, "Masks", "*.jpg;*.png");
    SalCfgKeyAddDword(v2, "Type", (DWORD)-3);
    SalCfgKeyAddString(v2, "Command", "x.exe");
    CSalCfgKey* v3 = SalCfgKeyAddKey(vw, "3");
    SalCfgKeyAddString(v3, "Masks", "*.a|*.b");
    SalCfgKeyAddDword(v3, "Type", 0);
    CSalCfgKey* v4 = SalCfgKeyAddKey(vw, "4");
    SalCfgKeyAddString(v4, "Masks", "*.after");
    SalCfgKeyAddDword(v4, "Type", 0);
    CSalCfgImpViewer* vs = NULL;
    int vstop = -1;
    int vc = SalCfgImpParseViewers(SalCfgKeyFind(root, "Viewers"), FALSE, 43, MAX_PATH, &vs, &vstop);
    CHECK(vc == 2 && vstop == SALCFGIMP_VSTOP_PIPE);
    CHECK(vc == 2 && strcmp(vs[0].Masks, "*.txt") == 0 && vs[0].Type == 1); // < 44: lower case
    CHECK(vc == 2 && vs[1].Type == -3 && strcmp(vs[1].Command, "x.exe") == 0 && vs[1].Arguments[0] == 0);
    SalCfgImpFreeViewers(vs, vc);
    vc = SalCfgImpParseViewers(SalCfgKeyFind(root, "Viewers"), FALSE, 103, MAX_PATH, &vs, &vstop);
    CHECK(vc == 2 && strcmp(vs[0].Masks, "*.TXT") == 0);
    SalCfgImpFreeViewers(vs, vc);
    // editors need no Type and accept '|' as the program's editor loader does
    vc = SalCfgImpParseViewers(SalCfgKeyFind(root, "Viewers"), TRUE, 103, MAX_PATH, &vs, &vstop);
    CHECK(vc == 4 && vstop == SALCFGIMP_VSTOP_NONE && vs[1].Type == 0);
    SalCfgImpFreeViewers(vs, vc);
    // a too long row is left out, the rows after it are read (never cut)
    int vlong = -1;
    vc = SalCfgImpParseViewers(SalCfgKeyFind(root, "Viewers"), TRUE, 103, 8, &vs, &vstop, &vlong);
    CHECK(vc == 3 && vlong == 1 && vstop == SALCFGIMP_VSTOP_NONE); // "*.jpg;*.png" (11 bytes) is left out
    CHECK(vc == 3 && strcmp(vs[2].Masks, "*.after") == 0);
    SalCfgImpFreeViewers(vs, vc);
    SalCfgKeyFree(root);

    // ---- report text: cut only after a whole UTF-8 character
    {
        char t[8];
        SalCfgImpCopyText(t, 7, "abc\xC4\x8D\xC5\xA1x"); // "abcčšx" = 9 bytes, 6 fit
        CHECK(strcmp(t, "abc\xC4\x8D") == 0); // "š" does not fit whole: cut before it
        SalCfgImpCopyText(t, 8, "abc");
        CHECK(strcmp(t, "abc") == 0);
        SalCfgImpFormatText(t, 8, "%s-%s", "\xE2\x82\xAC\xE2\x82\xAC", "x"); // "€€-x" = 8 bytes, 7 fit
        CHECK(strcmp(t, "\xE2\x82\xAC\xE2\x82\xAC-") == 0);
        SalCfgImpFormatText(t, 6, "%s%s", "x", "\xE2\x82\xAC\xE2\x82\xAC"); // "x€€": 5 bytes fit, the 2nd € not
        CHECK(strcmp(t, "x\xE2\x82\xAC") == 0);
        SalCfgImpFormatText(t, 8, "%s", NULL == NULL ? "ok" : "");
        CHECK(strcmp(t, "ok") == 0);
        char big[5000];
        memset(big, 'a', sizeof(big) - 3);
        big[sizeof(big) - 3] = '\xC4'; // a two-byte character beyond the formatting buffer
        big[sizeof(big) - 2] = '\x8D';
        big[sizeof(big) - 1] = 0;
        char out[4200];
        SalCfgImpFormatText(out, (int)sizeof(out), "%s", big);
        CHECK((int)strlen(out) == 4095 && out[4094] == 'a'); // _TRUNCATE at 4095 bytes: a whole ASCII text stays
        big[4094] = '\xC4'; // now the cut splits a character at byte 4095
        big[4095] = '\x8D';
        SalCfgImpFormatText(out, (int)sizeof(out), "%s", big);
        CHECK((int)strlen(out) == 4094 && out[4093] == 'a'); // the split character is dropped
    }

    // ---- truncated subtrees are seen through every level
    {
        CSalCfgKey* r3 = SalCfgKeyNew("");
        CSalCfgKey* a3 = SalCfgKeyAddKey(r3, "a");
        CSalCfgKey* b3 = SalCfgKeyAddKey(a3, "b");
        CHECK(!SalCfgKeySubtreeTruncated(r3) && !SalCfgKeySubtreeTruncated(NULL));
        b3->Truncated = TRUE;
        CHECK(SalCfgKeySubtreeTruncated(r3) && SalCfgKeySubtreeTruncated(a3) && SalCfgKeySubtreeTruncated(b3));
        CHECK(!SalCfgKeySubtreeTruncated(SalCfgKeyAddKey(r3, "c")));
        SalCfgKeyFree(r3);
    }

    // ---- plug-ins parser
    root = SalCfgKeyNew("src");
    CSalCfgKey* pl = SalCfgKeyAddKey(root, "Plugins");
    CSalCfgKey* p1 = SalCfgKeyAddKey(pl, "1");
    SalCfgKeyAddString(p1, "DLL", "ieviewer\\ieviewer.spl");
    SalCfgKeyAddString(p1, "Name", "IE Viewer");
    CSalCfgKey* p2 = SalCfgKeyAddKey(pl, "2");
    SalCfgKeyAddString(p2, "DLL", "ftp\\ftp.spl");
    SalCfgKeyAddString(p2, "Configuration Key", "FTP");
    CSalCfgKey* m = SalCfgKeyAddKey(p2, "Menu");
    CSalCfgKey* m1 = SalCfgKeyAddKey(m, "1");
    SalCfgKeyAddDword(m1, "ID", 7);
    SalCfgKeyAddDword(m1, "HotKey", 0x10000 | 0x0646);
    SalCfgKeyAddString(m1, "Name", "Connect");
    CSalCfgKey* m2 = SalCfgKeyAddKey(m, "2");
    SalCfgKeyAddDword(m2, "ID", 8); // no hot key: not listed
    CSalCfgKey* m3 = SalCfgKeyAddKey(m, "3");
    SalCfgKeyAddDword(m3, "ID", 9);
    SalCfgKeyAddDword(m3, "HotKey", 0x0647); // predefined (not dirty) - listed, the core filters
    CSalCfgImpPlugin* ps = NULL;
    int pc = SalCfgImpParsePlugins(SalCfgKeyFind(root, "Plugins"), &ps);
    CHECK(pc == 2 && ps[0].Index == 0 && ps[1].Index == 1);
    CHECK(pc == 2 && strcmp(ps[1].DLL, "ftp\\ftp.spl") == 0 && strcmp(ps[1].ConfigKey, "FTP") == 0 && ps[0].ConfigKey[0] == 0);
    CHECK(pc == 2 && ps[1].KeyCount == 2 && ps[1].Keys[0].ID == 7 && (ps[1].Keys[0].HotKey & SALCFGIMP_HOTKEY_DIRTY) &&
          strcmp(ps[1].Keys[0].Name, "Connect") == 0 && ps[1].Keys[1].ID == 9);
    SalCfgImpFreePlugins(ps, pc);
    SalCfgKeyFree(root);

    // ---- history parser
    root = SalCfgKeyNew("h");
    SalCfgKeyAddString(root, "1", "C:\\a");
    SalCfgKeyAddString(root, "2", "");
    SalCfgKeyAddValue(root, "3", REG_SZ, "\xC3\x28", 3); // invalid UTF-8
    SalCfgKeyAddDword(root, "4", 5);                     // wrong type
    SalCfgKeyAddString(root, "6", "C:\\b");              // a gap does not stop reading
    SalCfgKeyAddString(root, "9", "C:\\over cap");
    const char* hist[8];
    int hn = SalCfgImpParseHistory(root, hist, 8);
    CHECK(hn == 2 && strcmp(hist[0], "C:\\a") == 0 && strcmp(hist[1], "C:\\b") == 0);
    SalCfgKeyFree(root);

    // the options allow-list of cfgimport.cpp with the companion values (mirrored;
    // contracts/options-table.md): no value
    // Tandem Commander owns is ever on it (FR-016)
    static const char* const optionTable[][2] = {
        {"Configuration\\Confirmation", "Files or Dirs Del"},
        {"Configuration\\Confirmation", "Non-empty Dir Del"},
        {"Configuration\\Confirmation", "File Overwrite"},
        {"Configuration\\Confirmation", "Directory Overwrite"},
        {"Configuration\\Confirmation", "SH File Del"},
        {"Configuration\\Confirmation", "SH Dir Del"},
        {"Configuration\\Confirmation", "SH File Overwrite"},
        {"Configuration\\Confirmation", "NTFS Compress and Uncompress"},
        {"Configuration\\Confirmation", "NTFS Encrypt and Decrypt"},
        {"Configuration\\Confirmation", "Drag and Drop"},
        {"Configuration\\Confirmation", "Close Archive"},
        {"Configuration\\Confirmation", "Close Find"},
        {"Configuration\\Confirmation", "Stop Find"},
        {"Configuration\\Confirmation", "Create Target Path"},
        {"Configuration\\Confirmation", "Always on Top"},
        {"Configuration\\Confirmation", "Close Salamander"},
        {"Configuration\\Confirmation", "Send Email"},
        {"Configuration\\Confirmation", "Add To Archive"},
        {"Configuration\\Confirmation", "Create Dir"},
        {"Configuration\\Confirmation", "Change Dir TC"},
        {"Configuration\\Confirmation", "Show Names To Compare"},
        {"Configuration\\Confirmation", "DST Shifts Ignored"},
        {"Configuration\\Confirmation", "DST Shifts Occured"},
        {"Configuration\\Confirmation", "Copy Move Options Not Supported"},
        {"Configuration", "Select/Deselect Directories"},
        {"Configuration", "Primary Context Menu"},
        {"Configuration", "Hide Hidden and System Files and Directories"},
        {"Configuration", "Single Click"},
        {"Configuration", "Click to Quick Rename"},
        {"Configuration", "Quick Search Enter Alt"},
        {"Configuration", "Use Shift For GoTo HotPath"},
        {"Configuration", "Full Row Select"},
        {"Configuration", "Full Row Highlight"},
        {"Configuration", "Use Icon Tincture"},
        {"Configuration", "Show Panel Caption"},
        {"Configuration", "Show Panel Zoom"},
        {"Configuration", "Sort Uses Locale"},
        {"Configuration", "Sort Detects Numbers"},
        {"Configuration", "Sort Newer On Top"},
        {"Configuration", "Sort Dirs By Name"},
        {"Configuration", "Sort Dirs By Ext"},
        {"Configuration", "Quick Rename Select All"},
        {"Configuration", "Edit New File Select All"},
        {"Configuration", "Use DragDrop Min Time"},
        {"Configuration", "DragDrop Min Time"},
        {"Configuration", "File Name Format"},
        {"Configuration", "Size Format"},
        {"Configuration", "Thumbnail Size"},
        {"Configuration", "Clear Readonly Attribute"},
        {"Configuration", "Close Shell Window"},
        {"Configuration", "Status Area"},
        {"Configuration", "Save History"},
        {"Configuration", "Save Working Dirs"},
        {"Configuration", "Enable CmdLine History"},
        {"Configuration", "Save CmdLine History"},
        {"Configuration", "Show Errors In Find Files"},
        {"Configuration", "Show Full Row In Find Files"},
        {"Configuration", "Use Speeker Beep"},
        {"Configuration", "Copy Find Text"},
        {"Configuration", "Netware Fast Dir Move"},
        {"Configuration", "Async Copy Alg On Network"},
        {"Configuration", "Reload Environment Variables"},
        {"Configuration", "Title bar show path"},
        {"Configuration", "Title bar mode"},
        {"Configuration", "Title bar prefix"},
        {"Configuration", "Title bar prefix text"},
        {"Configuration", "Change Drive Show My Documents"},
        {"Configuration", "Change Drive Show Another"},
        {"Configuration", "Change Drive Show Cloud Storages"},
        {"Configuration", "Change Drive Network"},
        {"Configuration", "Visible Drives"},
        {"Configuration", "Separated Drives"},
        {"Configuration", "Compare By Time"},
        {"Configuration", "Compare By Size"},
        {"Configuration", "Compare By Content"},
        {"Configuration", "Compare By Attr"},
        {"Configuration", "Compare By Subdirs"},
        {"Configuration", "Compare By Subdirs Attr"},
        {"Configuration", "Compare One Panel Dirs"},
        {"Configuration", "Compare More Options"},
        {"Configuration", "Compare Ignore Files"},
        {"Configuration", "Compare Ignore Files Masks"},
        {"Configuration", "Compare Ignore Dirs"},
        {"Configuration", "Compare Ignore Dirs Masks"},
        {"Configuration", "Use Time Resolution"},
        {"Configuration", "Time Resolution"},
        {"Configuration", "Ignore DST Shifts"},
        {"Configuration", "Use Recycle Bin"},
        {"Configuration", "Use Recycle Bin For"},
        {"Configuration\\Drive Special Settings", "Floppy Automatic Refresh"},
        {"Configuration\\Drive Special Settings", "Floppy Simple Icons"},
        {"Configuration\\Drive Special Settings", "Removable Automatic Refresh"},
        {"Configuration\\Drive Special Settings", "Removable Simple Icons"},
        {"Configuration\\Drive Special Settings", "Fixed Automatic Refresh"},
        {"Configuration\\Drive Special Settings", "Fixed Simple Icons"},
        {"Configuration\\Drive Special Settings", "Remote Automatic Refresh"},
        {"Configuration\\Drive Special Settings", "Remote Simple Icons"},
        {"Configuration\\Drive Special Settings", "Remote Do Not Refresh on Activation"},
        {"Configuration\\Drive Special Settings", "CDROM Automatic Refresh"},
        {"Configuration\\Drive Special Settings", "CDROM Simple Icons"},
        {"Viewer", "EOL CRLF"},
        {"Viewer", "EOL CR"},
        {"Viewer", "EOL LF"},
        {"Viewer", "EOL NULL"},
        {"Viewer", "Wrap Text"},
        {"Viewer", "Auto-Select"},
        {"Viewer", "Auto-Copy Selection"},
        {"Viewer", "Go to Offset Is Hex"},
        {"Viewer", "Tabelator Size"},
        {"Viewer", "Default Mode"},
        {"Viewer", "Text Masks"},
        {"Viewer", "Hex Masks"},
    };
    int forbiddenOnTable = 0;
    for (int i = 0; i < (int)(sizeof(optionTable) / sizeof(optionTable[0])); i++)
    {
        const char* sub = optionTable[i][0];
        const char* top = strncmp(sub, "Configuration", 13) == 0 && sub[13] == 0 ? "Configuration" : sub;
        if (SalCfgImpIsForbiddenOption(top, optionTable[i][1]))
            forbiddenOnTable++;
    }
    CHECK(forbiddenOnTable == 0);
    CHECK((int)(sizeof(optionTable) / sizeof(optionTable[0])) == 112);
}

// feature 246: a mapped network drive's Windows name and its disconnected state (salnetdrive.h)
static BOOL NetKey246(const WCHAR* remote, const WCHAR* expected)
{
    WCHAR key[300];
    key[0] = L'X';
    BOOL ok = SalNetDriveNameKey(remote, key, _countof(key));
    if (expected == NULL)
        return !ok && key[0] == 0;
    return ok && wcscmp(key, expected) == 0;
}

static BOOL NetClean246(const WCHAR* raw, const WCHAR* expected)
{
    WCHAR buf[100];
    wcscpy_s(buf, raw);
    int len = SalNetDriveCleanName(buf);
    return len == (int)wcslen(expected) && wcscmp(buf, expected) == 0;
}

static BOOL NetText246(const WCHAR* name, const WCHAR* remote, BOOL amp, const WCHAR* expected)
{
    WCHAR buf[300];
    int needed = SalNetDriveText(name, remote, amp, buf, _countof(buf));
    return needed == (int)wcslen(expected) + 1 && wcscmp(buf, expected) == 0;
}

// feature 248: wide text -> code page, no best-fit, cut at a whole character
static bool CpFit248(const wchar_t* w, int bufSize, UINT cp, int expN, const char* expBytes)
{
    char buf[64];
    memset(buf, 'Z', sizeof(buf));
    int n = SalWToCodePageWhole(w, buf, bufSize, cp);
    if (n != expN)
        return false;
    if (n < 0)
        return true;
    return strcmp(buf, expBytes) == 0 && buf[bufSize] == 'Z'; // terminated, nothing written past the size
}

static void TestCpFit248()
{
    // the names of issue #13 in code page 1250 (z with caron 0x9E, e with caron 0xEC)
    CHECK(CpFit248(L"Typ polo\x017Eky", 30, 1250, 11, "Typ polo\x9Eky"));
    CHECK(CpFit248(L"Datum zm\x011Bny", 30, 1250, 11, "Datum zm\xECny"));
    // no best-fit: a with macron and a CJK character are outside 1250 -> '?', never "a"
    CHECK(CpFit248(L"a\x0101\x4E2D", 30, 1250, 3, "a??"));
    CHECK(CpFit248(L"zm\x011Bny", 30, 1252, 5, "zm?ny")); // e with caron outside 1252: not "zmeny"
    // too long: cut at a whole character, never empty
    CHECK(CpFit248(L"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", 30, 1250, 29, "xxxxxxxxxxxxxxxxxxxxxxxxxxxxx"));
    CHECK(CpFit248(L"\x4E2D\x4E2D\x4E2D\x4E2D\x4E2D\x4E2D\x4E2D\x4E2D\x4E2D\x4E2D\x4E2D\x4E2D\x4E2D\x4E2D\x4E2D",
                   30, 932, 28, "\x92\x86\x92\x86\x92\x86\x92\x86\x92\x86\x92\x86\x92\x86\x92\x86\x92\x86\x92\x86\x92\x86\x92\x86\x92\x86\x92\x86"));
    CHECK(CpFit248(L"a\x4E2D", 3, 932, 1, "a"));          // 3 bytes needed + NUL: the double-byte character goes whole
    CHECK(CpFit248(L"\x4E2D", 2, 932, 0, ""));            // not even one character fits
    // surrogate pairs: a pair torn by an earlier cut is dropped; a cut never splits a pair
    CHECK(CpFit248(L"ab\xD83D", 30, 1250, 2, "ab"));
    CHECK(CpFit248(L"ab\xD83D\xDE00", 3, 1250, 2, "ab"));
    CHECK(CpFit248(L"ab\xD83D\xDE00", 3, CP_UTF8, 2, "ab"));
    CHECK(CpFit248(L"ab\xD83D\xDE00", 7, CP_UTF8, 6, "ab\xF0\x9F\x98\x80"));
    // ... sizes where a one-unit cut would fit: the lone high surrogate would become "?" (1250,
    // 1 byte) or U+FFFD (UTF-8, 3 bytes) - the pair must still go as a whole
    CHECK(CpFit248(L"ab\xD83D\xDE00", 4, 1250, 2, "ab"));
    CHECK(CpFit248(L"ab\xD83D\xDE00", 6, CP_UTF8, 2, "ab"));
    // a code page that rejects the no-best-fit flag (50220, ERROR_INVALID_FLAGS): converted without it
    CHECK(CpFit248(L"abc", 30, 50220, 3, "abc"));
    // the UTF-8 system code page: the flag is not allowed there, the text still converts
    CHECK(CpFit248(L"polo\x017Eky", 30, CP_UTF8, 8, "polo\xC5\xBEky"));
    // edges
    CHECK(CpFit248(L"", 30, 1250, 0, ""));
    CHECK(CpFit248(NULL, 30, 1250, 0, ""));
    CHECK(CpFit248(L"abc", 1, 1250, 0, ""));
    char one[1] = {'Z'};
    CHECK(SalWToCodePageWhole(L"abc", one, 0, 1250) == -1 && one[0] == 'Z');
    CHECK(SalWToCodePageWhole(L"abc", NULL, 30, 1250) == -1);
    // CP_ACP is the system's code page: the same bytes as asking for it by number
    char a1[32], a2[32];
    CHECK(SalWToCodePageWhole(L"Typ polo\x017Eky", a1, 30) == SalWToCodePageWhole(L"Typ polo\x017Eky", a2, 30, GetACP()) &&
          strcmp(a1, a2) == 0);
}

// feature 251: SalWTextFitsU8 - does the whole typed text fit a UTF-8 buffer (a cut is refused)
static void TestTextFits251()
{
    WCHAR w[400];
    // ASCII: 259 characters + NUL fit 260, 260 do not
    for (int i = 0; i < 260; i++)
        w[i] = L'a';
    w[259] = 0;
    CHECK(SalWTextFitsU8(w, 260));
    w[259] = L'a';
    w[260] = 0;
    CHECK(!SalWTextFitsU8(w, 260));
    CHECK(SalWTextFitsU8(w, 261));
    // CJK: three bytes each - 86 letters (258 + 1) fit 259, 87 (261 + 1) do not fit 261
    for (int i = 0; i < 87; i++)
        w[i] = (WCHAR)(0x4E00 + i);
    w[86] = 0;
    CHECK(SalWTextFitsU8(w, 259));
    CHECK(!SalWTextFitsU8(w, 258));
    w[86] = 0x4E56;
    w[87] = 0;
    CHECK(!SalWTextFitsU8(w, 261));
    CHECK(SalWTextFitsU8(w, 262));
    // the 214 / 251 measurement: 90 CJK letters fit the field's 259 units, not 260 bytes
    for (int i = 0; i < 90; i++)
        w[i] = (WCHAR)(0x4E01 + i);
    w[90] = 0;
    CHECK(!SalWTextFitsU8(w, 260));
    // a surrogate pair is 4 bytes, a lone surrogate 3 (WTF-8)
    CHECK(SalWTextFitsU8(L"ab\xD83D\xDE00", 7));
    CHECK(!SalWTextFitsU8(L"ab\xD83D\xDE00", 6));
    CHECK(SalWTextFitsU8(L"ab\xD83D", 6));
    CHECK(!SalWTextFitsU8(L"ab\xD83D", 5));
    CHECK(SalWTextFitsU8(L"\xDE00x", 5));
    CHECK(!SalWTextFitsU8(L"\xDE00x", 4));
    // edges: the empty text and NULL need the terminator only; no buffer is never enough
    CHECK(SalWTextFitsU8(L"", 1));
    CHECK(SalWTextFitsU8(NULL, 1));
    CHECK(!SalWTextFitsU8(L"", 0));
    CHECK(!SalWTextFitsU8(NULL, 0));
    CHECK(!SalWTextFitsU8(L"a", -5));
    CHECK(!SalWTextFitsU8(L"a", 1));
    CHECK(SalWTextFitsU8(L"a", 2));
    // agrees with the converter: whatever fits converts whole, without a cut
    char buf[16];
    CHECK(SalWTextFitsU8(L"\x017E\x011B", 5) && SalWToU8(L"\x017E\x011B", -1, buf, 5) == 5);
    CHECK(!SalWTextFitsU8(L"\x017E\x011B", 4) && SalWToU8(L"\x017E\x011B", -1, buf, 4) == 0);
    // SalU8TextFits: a value already in UTF-8 (a configuration item kept whole)
    CHECK(SalU8TextFits("abc", 4));
    CHECK(!SalU8TextFits("abc", 3));
    CHECK(SalU8TextFits("\xE4\xB8\x80", 4));  // one CJK letter: 3 bytes + NUL
    CHECK(!SalU8TextFits("\xE4\xB8\x80", 3)); // never "fits" by counting letters
    CHECK(SalU8TextFits("", 1));
    CHECK(SalU8TextFits(NULL, 1));
    CHECK(!SalU8TextFits("", 0));
    CHECK(!SalU8TextFits(NULL, -1));
    char big[300];
    memset(big, 'x', 260);
    big[259] = 0;
    CHECK(SalU8TextFits(big, MAX_PATH));
    big[259] = 'x';
    big[260] = 0;
    CHECK(!SalU8TextFits(big, MAX_PATH));
}

// feature 252: case twins of an archive listing (salcasetwins.h)
struct FakeItem252
{
    const char* Name;
    unsigned NameLen;
};
struct FakeDir252
{
    std::vector<FakeItem252> Dirs, Files;
    std::vector<const FakeDir252*> Subs; // one per Dirs entry, NULL allowed
    void AddFile(const char* n) { Files.push_back({n, (unsigned)strlen(n)}); }
    void AddDir(const char* n, const FakeDir252* sub)
    {
        Dirs.push_back({n, (unsigned)strlen(n)});
        Subs.push_back(sub);
    }
    int GetFilesCount() const { return (int)Files.size(); }
    int GetDirsCount() const { return (int)Dirs.size(); }
    const FakeItem252* GetFile(int i) const { return &Files[i]; }
    const FakeItem252* GetDir(int i) const { return &Dirs[i]; }
    const FakeDir252* GetSalDir(int i) const { return Subs[i]; }
};

static BOOL Twins252(std::initializer_list<const char*> list)
{
    std::vector<SalCaseTwinName> v;
    for (const char* n : list)
        v.push_back({n, -1});
    return SalNamesHaveCaseTwins(v.data(), (int)v.size());
}

// feature 259: the Paste copy name - built whole, judged by 255 UTF-16 units (it was dropped at
// 260 bytes and the copy went to its source: "Cannot copy a file to itself.")
static std::string CopyName259(const char* name, BOOL isDir, int attempt, int* res, int outSize = 1000)
{
    std::vector<char> out(outSize > 0 ? outSize : 1, 'x');
    *res = SalMakeCopyNameU8(name, isDir, " - Copy", attempt, out.data(), outSize);
    return std::string(out.data());
}

static void TestCopyName259()
{
    int r;
    // the Explorer patterns (unchanged)
    CHECK(CopyName259("a.txt", FALSE, 1, &r) == "a - Copy.txt" && r == SAL_COPYNAME_OK);
    CHECK(CopyName259("a.txt", FALSE, 2, &r) == "a - Copy (2).txt" && r == SAL_COPYNAME_OK);
    CHECK(CopyName259("a.txt", FALSE, 10, &r) == "a - Copy (10).txt");
    CHECK(CopyName259("a.txt", TRUE, 1, &r) == "a.txt - Copy"); // folders have no extension
    CHECK(CopyName259("a.txt", TRUE, 3, &r) == "a.txt - Copy (3)");
    CHECK(CopyName259("noext", FALSE, 1, &r) == "noext - Copy");
    CHECK(CopyName259("a.my file", FALSE, 1, &r) == "a.my file - Copy"); // an extension with a space is none
    CHECK(CopyName259("x (1).txt", FALSE, 1, &r) == "x (1) - Copy.txt");
    CHECK(CopyName259("x (1).txt", FALSE, 2, &r) == "x (2) - Copy.txt"); // the number is replaced
    CHECK(CopyName259("x (1)", TRUE, 2, &r) == "x (2) - Copy");
    CHECK(CopyName259("x.(7)", FALSE, 2, &r) == "x - Copy.(2)");             // the number inside the extension
    CHECK(CopyName259("x (a).txt", FALSE, 2, &r) == "x (a) - Copy (2).txt"); // "(a)" is no number
    CHECK(CopyName259("x ().txt", FALSE, 2, &r) == "x (2) - Copy.txt");      // "()" counts (as before)
    CHECK(CopyName259(".cvspass", FALSE, 1, &r) == " - Copy.cvspass");       // as before
    CHECK(CopyName259("x (001).txt", FALSE, 2, &r) == "x (2) - Copy.txt");   // leading zeros: a later attempt is shorter (see the header)

    // long names: 84 CJK letters + ".txt" = 256 bytes, the copy 95 units - created (was "to itself")
    std::string cjk84;
    for (int i = 0; i < 84; i++)
        cjk84 += "\xE4\xB8\xAD";
    std::string c = CopyName259((cjk84 + ".txt").c_str(), FALSE, 1, &r);
    CHECK(r == SAL_COPYNAME_OK && c == cjk84 + " - Copy.txt" && c.size() == 263);
    CHECK(CopyName259((cjk84 + ".txt").c_str(), FALSE, 2, &r) == cjk84 + " - Copy (2).txt" && r == SAL_COPYNAME_OK);
    // 250 ASCII letters + ".txt": the copy would have 261 units - too long, never cut
    std::string a250(250, 'a');
    c = CopyName259((a250 + ".txt").c_str(), FALSE, 1, &r);
    CHECK(r == SAL_COPYNAME_TOOLONG && c.empty());
    // exactly 255 units is a name; 256 is not
    std::string a244(244, 'a'); // 244 + " - Copy" (7) + ".txt" (4) = 255
    c = CopyName259((a244 + ".txt").c_str(), FALSE, 1, &r);
    CHECK(r == SAL_COPYNAME_OK && c.size() == 255);
    std::string a245(245, 'a');
    CHECK(CopyName259((a245 + ".txt").c_str(), FALSE, 1, &r).empty() && r == SAL_COPYNAME_TOOLONG);
    CHECK(CopyName259((a244 + ".txt").c_str(), FALSE, 2, &r).empty() && r == SAL_COPYNAME_TOOLONG); // " (2)" more
    // an emoji counts two units: 122 emoji (244 units) + ".txt" -> 255 units OK
    std::string emo;
    for (int i = 0; i < 122; i++)
        emo += "\xF0\x9F\x98\x80";
    c = CopyName259((emo + ".txt").c_str(), FALSE, 1, &r);
    CHECK(r == SAL_COPYNAME_OK && c == emo + " - Copy.txt");
    CHECK(CopyName259((emo + "x.txt").c_str(), FALSE, 1, &r).empty() && r == SAL_COPYNAME_TOOLONG);
    // the buffer: what does not fit is TOOLONG, never a cut name
    CHECK(CopyName259("a.txt", FALSE, 1, &r, 12).empty() && r == SAL_COPYNAME_TOOLONG); // needs 13
    CHECK(CopyName259("a.txt", FALSE, 1, &r, 13) == "a - Copy.txt" && r == SAL_COPYNAME_OK);
    CHECK(CopyName259("x (1).txt", FALSE, 2, &r, 5).empty() && r == SAL_COPYNAME_TOOLONG);
    char one[1] = {'x'};
    CHECK(SalMakeCopyNameU8("a", FALSE, " - Copy", 1, one, 1) == SAL_COPYNAME_TOOLONG && one[0] == 0);
    CHECK(SalMakeCopyNameU8("a", FALSE, " - Copy", 0, one, 1) == SAL_COPYNAME_TOOLONG);
    // a localized word counts in units too (Czech "Kopie" - ASCII; German "Kopie"; a 2-byte word)
    char outW[300];
    CHECK(SalMakeCopyNameU8("a.txt", FALSE, " - Kop\xC3\xADrovat", 1, outW, sizeof(outW)) == SAL_COPYNAME_OK &&
          strcmp(outW, "a - Kop\xC3\xADrovat.txt") == 0);
}

static void TestCaseTwins252()
{
    // the item's case: a.txt and A.txt
    CHECK(Twins252({"a.txt", "A.txt"}));
    CHECK(Twins252({"z.txt", "A.txt", "b.txt", "a.txt"}));
    CHECK(!Twins252({"a.txt", "b.txt", "z.txt"}));
    // byte-identical duplicates (an appended TAR member) are no twins
    CHECK(!Twins252({"a.txt", "a.txt", "b.txt"}));
    CHECK(Twins252({"a.txt", "a.txt", "A.txt"}));
    // edges
    CHECK(!Twins252({}));
    CHECK(!Twins252({"a"}));
    CHECK(!SalNamesHaveCaseTwins(NULL, 5));
    SalCaseTwinName nul[2] = {{NULL, 0}, {"", -1}};
    CHECK(!SalNamesHaveCaseTwins(nul, 2)); // NULL is "": the same bytes
    SalCaseTwinName lens[2] = {{"abcX", 3}, {"ABCY", 3}};
    CHECK(SalNamesHaveCaseTwins(lens, 2)); // lengths are honoured
    SalCaseTwinName lens2[2] = {{"abcX", 4}, {"abcY", 4}};
    CHECK(!SalNamesHaveCaseTwins(lens2, 2));
    // the file system's rule: C-caron / c-caron are one name (Unicode case), K / Kelvin sign are not
    CHECK(Twins252({"\xC4\x8C.txt", "\xC4\x8D.txt"}));
    CHECK(!Twins252({"K", "\xE2\x84\xAA"}));
    // the legacy byte fold of the process code page: a pair of UTF-8 letters C3 xx / C3 yy whose
    // second bytes fold together (cp1250: 8A / 9A = E-circumflex / U-acute) is a twin pair too -
    // the core merges such folders while building the tree
    const BYTE* lower = SalNameOrderDetail::LegacyLowerTable();
    int found = 0;
    for (int b1 = 0x80; b1 <= 0xBF && !found; b1++)
        for (int b2 = 0x80; b2 <= 0xBF && !found; b2++)
            if (b1 != b2 && lower[b1] == lower[b2])
            {
                char n1[4] = {(char)0xC3, (char)b1, 0};
                char n2[4] = {(char)0xC3, (char)b2, 0};
                if (!SalNameOrderEqualCI(n1, -1, n2, -1))
                {
                    CHECK(Twins252({n1, n2}));
                    found = 1;
                }
            }
    if (GetACP() == 1250)
        CHECK(found); // the measured code page has such a pair
    // a tree: twins only in a sub-folder
    FakeDir252 root, sub, deep, empty;
    root.AddFile("z.txt");
    deep.AddFile("x.txt");
    deep.AddFile("X.TXT");
    sub.AddDir("deep", &deep);
    root.AddDir("sub", &sub);
    root.AddDir("e", &empty);
    root.AddDir("n", NULL);
    CHECK(SalDirTreeHasCaseTwins(&root));
    deep.Files.pop_back();
    CHECK(!SalDirTreeHasCaseTwins(&root));
    // folders D and d; a file and a folder that differ only in case
    FakeDir252 r2;
    r2.AddDir("D", NULL);
    r2.AddDir("d", NULL);
    CHECK(SalDirTreeHasCaseTwins(&r2));
    FakeDir252 r3;
    r3.AddDir("Readme", NULL);
    r3.AddFile("README");
    CHECK(SalDirTreeHasCaseTwins(&r3));
    CHECK(!SalDirTreeHasCaseTwins(&empty));
    CHECK(!SalDirTreeHasCaseTwins((const FakeDir252*)NULL));
    // deep and wide: no recursion limit, the heap stack grows
    std::vector<FakeDir252> chain(3000);
    for (int i = 0; i + 1 < (int)chain.size(); i++)
        chain[i].AddDir("d", &chain[i + 1]);
    for (int i = 0; i < 200; i++)
        chain[0].AddDir("w", &empty);
    chain.back().AddFile("q");
    CHECK(!SalDirTreeHasCaseTwins(&chain[0]));
    chain.back().AddFile("Q");
    CHECK(SalDirTreeHasCaseTwins(&chain[0]));
}

static void TestNetDrive246()
{
    // the key Explorer keeps a drive's name under (measured: analysis.md G1)
    CHECK(NetKey246(L"\\\\localhost\\C$\\Users\\pavel\\share", L"##localhost#C$#Users#pavel#share"));
    CHECK(NetKey246(L"\\\\SHARE_SAMBA\\Share\\Storage", L"##SHARE_SAMBA#Share#Storage"));
    CHECK(NetKey246(L"\\\\srv\\share", L"##srv#share"));
    CHECK(NetKey246(L"\\\\srv\\share\\", L"##srv#share"));     // trailing backslash ignored
    CHECK(NetKey246(L"\\\\srv\\share\\\\\\", L"##srv#share")); // several of them
    CHECK(NetKey246(L"\\\\srv\\share\\sub\\", L"##srv#share#sub")); // deeper, trailing backslash
    CHECK(NetKey246(L"\\\\192.168.0.50\\Data", L"##192.168.0.50#Data"));
    CHECK(NetKey246(L"\\\\srv\\sh#\x017E ar", L"##srv#sh#\x017E ar")); // '#', non-ASCII and space copied
    CHECK(NetKey246(L"\\\\srv\\R&D", L"##srv#R&D"));
    CHECK(NetKey246(L"\\\\srv@SSL\\DavWWWRoot\\x", L"##srv@SSL#DavWWWRoot#x")); // WebDAV mapping
    CHECK(NetKey246(L"\\\\\x4E2D\x6587\\\x0416", L"##\x4E2D\x6587#\x0416"));
    CHECK(NetKey246(NULL, NULL));
    CHECK(NetKey246(L"", NULL));
    CHECK(NetKey246(L"\\\\", NULL));
    CHECK(NetKey246(L"\\\\\\x", NULL));             // no server
    CHECK(NetKey246(L"\\\\srv", NULL));             // no share
    CHECK(NetKey246(L"\\\\srv\\", NULL));           // no share (trailing backslash only)
    CHECK(NetKey246(L"\\\\srv\\\\share", NULL));    // empty component
    CHECK(NetKey246(L"\\\\srv\\a\\\\b", NULL));     // empty component deeper
    CHECK(NetKey246(L"\\\\?\\UNC\\srv\\share", NULL)); // device prefixes
    CHECK(NetKey246(L"\\\\.\\pipe\\x", NULL));
    CHECK(NetKey246(L"C:\\x", NULL));
    CHECK(NetKey246(L"\\x\\y", NULL));
    CHECK(NetKey246(L"//srv/share", NULL)); // forward slashes are not what WNet returns
    CHECK(NetKey246(L"\\\\.srv\\share", L"##.srv#share")); // a server name starting with '.' is a name
    {
        // exact fit and one unit short: refused, never cut
        WCHAR key[12]; // "##srv#share" = 11 units + terminator
        CHECK(SalNetDriveNameKey(L"\\\\srv\\share", key, 12) && wcscmp(key, L"##srv#share") == 0);
        key[0] = L'X';
        CHECK(!SalNetDriveNameKey(L"\\\\srv\\share", key, 11) && key[0] == 0);
        CHECK(!SalNetDriveNameKey(L"\\\\srv\\share", NULL, 12));
        CHECK(!SalNetDriveNameKey(L"\\\\srv\\share", key, 0));
    }

    // cleaning a name read from the registry
    CHECK(NetClean246(L"Archiv", L"Archiv"));
    CHECK(NetClean246(L"  Archiv  ", L"Archiv"));
    CHECK(NetClean246(L"Ar\tchiv", L"Ar chiv"));     // a tab would split the menu's columns
    CHECK(NetClean246(L"Ar\r\nchiv", L"Ar  chiv"));
    CHECK(NetClean246(L"A\x007F" L"B", L"A B"));
    CHECK(NetClean246(L"\x0001\x001F", L""));
    CHECK(NetClean246(L"   ", L""));
    CHECK(NetClean246(L"", L""));
    CHECK(NetClean246(L"\tArchiv Test \x017E\t", L"Archiv Test \x017E"));
    CHECK(NetClean246(L"A  B", L"A  B")); // inner spaces kept
    CHECK(NetClean246(L"\x00A0X\x00A0", L"\x00A0X\x00A0")); // no-break space is not a control character
    CHECK(SalNetDriveCleanName(NULL) == 0);

    // the shown text
    CHECK(NetText246(NULL, L"\\\\srv\\share", TRUE, L"\\\\srv\\share"));
    CHECK(NetText246(L"", L"\\\\srv\\share", TRUE, L"\\\\srv\\share"));
    CHECK(NetText246(L"Archiv", L"\\\\SHARE_SAMBA\\Share\\Storage", TRUE, L"Archiv (\\\\SHARE_SAMBA\\Share\\Storage)"));
    CHECK(NetText246(L"Archiv", L"\\\\SHARE_SAMBA\\Share\\Storage", FALSE, L"Archiv (\\\\SHARE_SAMBA\\Share\\Storage)"));
    CHECK(NetText246(L"\\\\SRV\\Share", L"\\\\srv\\share", TRUE, L"\\\\srv\\share")); // the name is the path
    CHECK(NetText246(L"R&D", L"\\\\srv\\R&D x", TRUE, L"R&&D (\\\\srv\\R&&D x)"));
    CHECK(NetText246(L"R&D", L"\\\\srv\\R&D x", FALSE, L"R&D (\\\\srv\\R&D x)"));
    CHECK(NetText246(NULL, L"\\\\srv\\a&&b", TRUE, L"\\\\srv\\a&&&&b"));
    CHECK(NetText246(L"Archiv", NULL, TRUE, L"Archiv"));
    CHECK(NetText246(L"Archiv", L"", TRUE, L"Archiv"));
    CHECK(NetText246(NULL, NULL, TRUE, L""));
    CHECK(NetText246(L"\x0416\x0443\x043A", L"\\\\srv\\x", TRUE, L"\x0416\x0443\x043A (\\\\srv\\x)"));
    CHECK(NetText246(L"\x00C9t\x00E9", L"\\\\srv\\\x00E9T\x00C9", TRUE, L"\x00C9t\x00E9 (\\\\srv\\\x00E9T\x00C9)"));
    CHECK(NetText246(L"\x00E9", L"\x00C9", TRUE, L"\x00C9")); // equal case-insensitively beyond ASCII
    {
        // the size query and exact / short buffers: written whole or not at all
        int needed = SalNetDriveText(L"A&B", L"\\\\s\\h", TRUE, NULL, 0);
        CHECK(needed == (int)wcslen(L"A&&B (\\\\s\\h)") + 1);
        WCHAR buf[64];
        buf[0] = L'X';
        CHECK(SalNetDriveText(L"A&B", L"\\\\s\\h", TRUE, buf, needed - 1) == needed && buf[0] == 0);
        CHECK(SalNetDriveText(L"A&B", L"\\\\s\\h", TRUE, buf, needed) == needed && wcscmp(buf, L"A&&B (\\\\s\\h)") == 0);
        CHECK(SalNetDriveText(L"A", L"\\\\s\\h", FALSE, buf, 0) == (int)wcslen(L"A (\\\\s\\h)") + 1);
        // a long name with a long path is never cut
        std::wstring longName(400, L'n');
        std::wstring longRemote = L"\\\\srv\\" + std::wstring(500, L'p');
        int n = SalNetDriveText(longName.c_str(), longRemote.c_str(), FALSE, NULL, 0);
        CHECK(n == 400 + 2 + (int)longRemote.size() + 1 + 1);
        std::vector<WCHAR> big(n);
        CHECK(SalNetDriveText(longName.c_str(), longRemote.c_str(), FALSE, big.data(), n) == n);
        CHECK(std::wstring(big.data()) == longName + L" (" + longRemote + L")");
    }

    // fitting a name into a byte limit on whole characters (the tooltip shortens the name, never the path)
    CHECK(SalNetDriveFitU8(L"abc", 10) == 3);
    CHECK(SalNetDriveFitU8(L"abc", 2) == 2);
    CHECK(SalNetDriveFitU8(L"abc", 0) == 0);
    CHECK(SalNetDriveFitU8(NULL, 10) == 0);
    CHECK(SalNetDriveFitU8(L"\x017E\x017E", 3) == 1);        // 2 bytes each: the second does not fit
    CHECK(SalNetDriveFitU8(L"\x017E\x017E", 4) == 2);
    CHECK(SalNetDriveFitU8(L"\x6863\x6863\x6863", 8) == 2);  // 3 bytes each
    CHECK(SalNetDriveFitU8(L"\x6863\x6863\x6863", 9) == 3);
    CHECK(SalNetDriveFitU8(L"a\xD83D\xDCC1" L"b", 4) == 1);  // the emoji (4 bytes) is not split
    CHECK(SalNetDriveFitU8(L"a\xD83D\xDCC1" L"b", 5) == 3);  // ... and counts as two units
    CHECK(SalNetDriveFitU8(L"a\xD83D\xDCC1" L"b", 6) == 4);
    CHECK(SalNetDriveFitU8(L"\xD83D" L"a", 3) == 1);         // a lone surrogate: three bytes (WTF-8)
    CHECK(SalNetDriveFitU8(L"\xDCC1\xD83D", 5) == 1);        // reversed pair: two lone surrogates
    {
        // the result is always a valid, whole-character prefix whose UTF-8 form fits
        std::wstring mixed = L"A\x017E\x6863\xD83D\xDCC1" L"B\x00E9\xD83D\xDE00\x0416";
        for (int limit = 0; limit <= 30; limit++)
        {
            int units = SalNetDriveFitU8(mixed.c_str(), limit);
            CHECK(units >= 0 && units <= (int)mixed.size());
            CHECK(units == 0 || !(mixed[units - 1] >= 0xD800 && mixed[units - 1] <= 0xDBFF)); // never ends inside a pair
            int bytes = units == 0 ? 0 : WideCharToMultiByte(CP_UTF8, 0, mixed.c_str(), units, NULL, 0, NULL, NULL);
            CHECK(bytes <= limit);
            if (units < (int)mixed.size()) // the next character would not have fitted
            {
                int nextUnits = (mixed[units] >= 0xD800 && mixed[units] <= 0xDBFF) ? 2 : 1;
                int nextBytes = WideCharToMultiByte(CP_UTF8, 0, mixed.c_str(), units + nextUnits, NULL, 0, NULL, NULL);
                CHECK(nextBytes > limit);
            }
        }
    }

    // is the name shown at all
    CHECK(SalNetDriveNameShown(L"Archiv", L"\\\\srv\\share"));
    CHECK(!SalNetDriveNameShown(NULL, L"\\\\srv\\share"));
    CHECK(!SalNetDriveNameShown(L"", L"\\\\srv\\share"));
    CHECK(!SalNetDriveNameShown(L"\\\\SRV\\Share", L"\\\\srv\\share"));
    CHECK(SalNetDriveNameShown(L"Archiv", NULL));
    CHECK(SalNetDriveNameShown(L"Archiv", L""));

    // UTF-8 length, counted like SalNetDriveFitU8
    CHECK(SalNetDriveU8Len(NULL) == 0);
    CHECK(SalNetDriveU8Len(L"") == 0);
    CHECK(SalNetDriveU8Len(L"ab") == 2);
    CHECK(SalNetDriveU8Len(L"\x017E\x6863\xD83D\xDCC1") == 2 + 3 + 4);
    CHECK(SalNetDriveU8Len(L"\xD83D" L"a") == 3 + 1); // lone surrogate: WTF-8, three bytes

    // the tooltip's limit: shorten the NAME, keep the path whole
    CHECK(SalNetDriveNameUnitsForLimit(L"Archiv", L"\\\\s\\h", 100) == -1);   // fits
    CHECK(SalNetDriveNameUnitsForLimit(NULL, L"\\\\s\\h", 3) == -1);          // no name: nothing to shorten
    CHECK(SalNetDriveNameUnitsForLimit(L"\\\\S\\H", L"\\\\s\\h", 3) == -1);  // the name is the path (review round 2)
    // "Archiv (\\s\h)" = 6 + 2 + 5 + 1 = 14 bytes
    CHECK(SalNetDriveNameUnitsForLimit(L"Archiv", L"\\\\s\\h", 14) == -1);
    CHECK(SalNetDriveNameUnitsForLimit(L"Archiv", L"\\\\s\\h", 13) == 13 - 8 - 3); // 2 units + ellipsis
    CHECK(SalNetDriveNameUnitsForLimit(L"Archiv", L"\\\\s\\h", 11) == 0);  // only the ellipsis fits
    CHECK(SalNetDriveNameUnitsForLimit(L"Archiv", L"\\\\s\\h", 10) == -2); // not even that
    CHECK(SalNetDriveNameUnitsForLimit(L"Archiv", NULL, 4) == 1);          // no path: the name alone, "A" + ellipsis
    {
        // for every limit the shortened text keeps the whole path and fits
        std::wstring name = L"\x6863\xD83D\xDCC1" L"Name \x017E" + std::wstring(40, L'\x6863');
        std::wstring remote = L"\\\\srv\\share \x0416";
        int full = SalNetDriveU8Len(name.c_str()) + 2 + SalNetDriveU8Len(remote.c_str()) + 1;
        for (int limit = 0; limit <= full + 2; limit++)
        {
            int units = SalNetDriveNameUnitsForLimit(name.c_str(), remote.c_str(), limit);
            if (limit >= full)
                CHECK(units == -1);
            else if (limit < 2 + SalNetDriveU8Len(remote.c_str()) + 1 + 3)
                CHECK(units == -2);
            else
            {
                CHECK(units >= 0 && units < (int)name.size());
                std::wstring shortName = name.substr(0, units) + L"\x2026";
                WCHAR buf[400];
                int needed = SalNetDriveText(shortName.c_str(), remote.c_str(), FALSE, buf, _countof(buf));
                CHECK(needed > 0 && SalNetDriveU8Len(buf) <= limit);
                std::wstring text(buf);
                CHECK(text.size() > remote.size() + 1 && text.compare(text.size() - remote.size() - 1, remote.size() + 1, remote + L")") == 0);
                CHECK(units == 0 || !(name[units - 1] >= 0xD800 && name[units - 1] <= 0xDBFF));
            }
        }
    }

    // the state: the full truth table of the answers that matter
    const DWORD conns[] = {0, SALNETDRV_ERROR_CONNECTION_UNAVAIL, 2250 /*ERROR_NOT_CONNECTED*/, 234 /*ERROR_MORE_DATA*/, 1222 /*ERROR_NO_NETWORK*/};
    const DWORD conn3s[] = {0, 2, 50};
    const DWORD states[] = {0, SALNETDRV_WNGC_DISCONNECTED, 2};
    // counted by hand, not by the rule: of the 90 combinations, all 45 unlisted ones are
    // disconnected, of the listed ones the 9 with ERROR_CONNECTION_UNAVAIL and the one
    // connected-but-WNGC_DISCONNECTED combination - 55 in all
    int combos = 0, disconnected = 0, listedDisconnected = 0;
    for (int listed = 0; listed < 2; listed++)
        for (DWORD c : conns)
            for (DWORD c3 : conn3s)
                for (DWORD st : states)
                {
                    combos++;
                    if (SalNetDriveIsDisconnected(listed, c, c3, st))
                    {
                        disconnected++;
                        if (listed)
                            listedDisconnected++;
                    }
                    if (!listed)
                        CHECK(SalNetDriveIsDisconnected(listed, c, c3, st));
                }
    CHECK(combos == 90);
    CHECK(disconnected == 55);
    CHECK(listedDisconnected == 10);
    // the measured states (analysis.md G2) spelled out
    CHECK(!SalNetDriveIsDisconnected(TRUE, 0, 0, 0));                                  // connected (also: mapped folder deleted on the server)
    CHECK(SalNetDriveIsDisconnected(FALSE, SALNETDRV_ERROR_CONNECTION_UNAVAIL, 2, 0)); // remembered, not connected
    CHECK(SalNetDriveIsDisconnected(TRUE, SALNETDRV_ERROR_CONNECTION_UNAVAIL, 0, 0));  // letter listed, unavailable
    CHECK(SalNetDriveIsDisconnected(TRUE, 0, 0, SALNETDRV_WNGC_DISCONNECTED));         // letter listed, disconnected
    CHECK(!SalNetDriveIsDisconnected(TRUE, 0, 2, SALNETDRV_WNGC_DISCONNECTED));        // the level unanswered: state ignored
}

int main(int argc, char** argv)
{
    // feature 126: "saltests --package-path <family>" prints what the program's real package
    // lookup finds on this machine (for specs/126-package-api-late-bind/probe/package_live.ps1,
    // which compares it with what Windows reports); exit code 0 = found
    if (argc == 3 && strcmp(argv[1], "--package-path") == 0)
    {
        char folder[2048];
        CSalShellOsProbe os;
        BOOL found = os.GetPackagePath(argv[2], folder, sizeof(folder));
        printf("%s\n", found ? folder : "(not found)");
        return found ? 0 : 1;
    }

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
    TestPluginFileDlg104();
    TestSafeReplace105();
    TestPackSelf106();
    TestFolderAlias107();
    TestArchiveEdit108();
    TestMemberChanged153();
    TestDiskCacheKey109();
    TestZipName110();
    TestPvSource111();
    TestCacheEdit112();
    TestZipMember113();
    TestUndeleteNames114();
    TestUndeleteLeftovers115();
    TestFtpSecret116();
    TestChecksumList117();
    TestPackLeftovers119();
    TestPvPixel120();
    TestSmallBatch121();
    TestUpdateCheck123();
    TestUncServer125();
    TestPackageApi126();
    TestInserts127();
    TestShellLink128();
    TestWideInserts129();
    TestPluginLoadStr130();
    TestJpegKeep132();
    TestExifThumb135();
    TestU8WholePrefix137();
    TestMaskName141();
    TestLoopClose143();
    TestNumberName148();
    TestFindIgnore163();
    TestZipDelete164();
    TestZipCount165();
    TestAlterName169();
    TestFormatMessageInserts180();
    TestShellLinkLoadName181();
    TestMultiSzToLine189();
    TestRegFindWholeWord257();
    TestHexPattern257();
    TestDeleteAsDirLink197();
    TestAttrsLink253();
    TestReparseNameAsPath219();
    TestNamePrefixBytes222();
    TestShortNameClashError203();
    TestNameIsOnlyShortNameOf204();
    TestU8Fold210();
    TestU8Letter254();
    TestBatchText226();
    TestBatchEscape229();
    TestNameExactInCIRun230();
    TestNameRules261();
    TestMenuHotKey236();
    TestPercentPath238();
    TestQuickFilter244();
    TestCfgImport245();
    TestNetDrive246();
    TestCpFit248();
    TestTextFits251();
    TestCaseTwins252();
    TestCopyName259();
    TestCacheTmpPath260();
    TestCodeTable262();

    printf("saltests: %d checks, %d failed\n", g_checks, g_failures);
    return g_failures;
}
