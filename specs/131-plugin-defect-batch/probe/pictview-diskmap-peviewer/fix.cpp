// feature 131: checks of the changed pure parts. The class CZStringBuffer and the function
// ThumbsMakeFullName are EXCERPTS of the edited repository files (cut out by mkexcerpt.sh into
// zbuf_excerpt.h / thumbs_excerpt.h), so the text compiled here is the text in the tree.
#include <windows.h>
#include <tchar.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <crtdbg.h>
#include "E:/Projects/tandemcommander/src/plugins/shared/splunicode.h"

class CStringFormatter;
class CZString
{
protected:
    TCHAR* _s;
    size_t _l;

public:
    explicit CZString(TCHAR const* s)
    {
        this->_l = _tcslen(s);
        this->_s = (TCHAR*)malloc((this->_l + 1) * sizeof TCHAR);
        _tcscpy(this->_s, s);
    }
    ~CZString() { free(this->_s); }
    TCHAR const* GetString() const { return this->_s; }
    size_t GetLength() const { return this->_l; }
};
#include "zbuf_excerpt.h"
#include "thumbs_excerpt.h"

static int Fails = 0;
#define CHECK(c) \
    do \
    { \
        if (!(c)) \
        { \
            Fails++; \
            printf("FAILED line %d: %s\n", __LINE__, #c); \
        } \
    } while (0)

int main()
{
    _CrtSetReportMode(_CRT_ERROR, _CRTDBG_MODE_FILE);
    _CrtSetReportFile(_CRT_ERROR, _CRTDBG_FILE_STDOUT);
    char text[2000];

    // ---- CZStringBuffer
    {
        CZStringBuffer b((size_t)264);
        memset(text, 'a', 264);
        text[264] = 0;
        CHECK(!b.CanAppendAt(264, 0)); // fills the buffer exactly: no room for the terminator
        b.AppendAt(text, 264, 0);
        CHECK(b.GetLength() == 0 && b.GetString()[0] == 0);
        CHECK(b.CanAppendAt(263, 0));
        b.AppendAt(text, 263, 0);
        CHECK(b.GetLength() == 263 && strlen(b.GetString()) == 263);
        CHECK(!b.CanAppendAt(1, 263));
        b.AppendAt('\\', 263);
        CHECK(b.GetLength() == 263);
        b.Left(262);
        CHECK(b.CanAppendAt(1, 262));
        b.AppendAt('\\', 262);
        CHECK(b.GetLength() == 263 && b.GetString()[262] == '\\');
        CHECK(_CrtCheckMemory());
        // a position behind the text means "at the end"
        b.Left(3);
        CHECK(b.CanAppendAt(2, 1000) && !b.CanAppendAt(261, 1000));
        b.AppendAt("xy", 2, 1000);
        CHECK(strcmp(b.GetString(), "aaaxy") == 0);
        // only 'len' characters of the source
        b.AppendAt("0123456789", 4, 0);
        CHECK(strcmp(b.GetString(), "0123") == 0 && b.GetLength() == 4);
        // Append(CZString) / Append(s)
        CZString s("-tail");
        b.Append(&s);
        b.Append("!");
        CHECK(strcmp(b.GetString(), "0123-tail!") == 0);
        CHECK(_CrtCheckMemory());
    }
    {
        CZStringBuffer b("copied"); // the unused constructor: the text is copied now
        CHECK(strcmp(b.GetString(), "copied") == 0 && b.GetLength() == 6 && b.GetBuffSize() == 7);
        CHECK(!b.CanAppendAt(1, 6));
    }
    {
        // the title of GUI.MainWindow.h: prefix + path into prefixLen + pathLen + 1
        CZString path("C:\\x");
        CZStringBuffer t((size_t)(10 + path.GetLength() + 1));
        t.Append("DiskMap - ", 10);
        t.Append(&path);
        CHECK(strcmp(t.GetString(), "DiskMap - C:\\x") == 0);
        CHECK(_CrtCheckMemory());
    }

    // ---- ThumbsMakeFullName
    {
        char buf[20];
        CHECK(ThumbsMakeFullName(buf, sizeof(buf), "C:\\dir", "a.jpg") && strcmp(buf, "C:\\dir\\a.jpg") == 0);
        CHECK(ThumbsMakeFullName(buf, sizeof(buf), "C:\\", "a.jpg") && strcmp(buf, "C:\\a.jpg") == 0);
        CHECK(ThumbsMakeFullName(buf, sizeof(buf), "C:\\dir", "0123456789ab") && strlen(buf) == 19); // exactly fits
        strcpy(buf, "old");
        CHECK(!ThumbsMakeFullName(buf, sizeof(buf), "C:\\dir", "0123456789abc") && buf[0] == 0); // one more: refused, empty
        CHECK(!ThumbsMakeFullName(buf, sizeof(buf), "C:\\", "0123456789abcdefg") && buf[0] == 0);
        CHECK(ThumbsMakeFullName(buf, sizeof(buf), "C:\\", "0123456789abcdef"));
        CHECK(!ThumbsMakeFullName(NULL, 10, "C:\\", "a") && !ThumbsMakeFullName(buf, 0, "C:\\", "a"));
        CHECK(!ThumbsMakeFullName(buf, sizeof(buf), NULL, "a") && buf[0] == 0);
        CHECK(ThumbsMakeFullName(buf, sizeof(buf), "", "a.jpg") && strcmp(buf, "a.jpg") == 0);
    }

    // ---- the composition of InitEXIF (pictview.cpp), copied: wide, bounded
    {
        WCHAR pathW[MAX_PATH] = L"C:\\";
        int i = 3;
        for (; i < 200; i++)
            pathW[i] = 0x65E5;
        wcscpy(pathW + i, L"\\plugins\\pictview\\exif.dll");
        char name[32] = "en.po";
        WCHAR nameW[32];
        WCHAR translW[MAX_PATH + 64];
        WCHAR* dirEndW = wcsrchr(pathW, L'\\');
        BOOL ok = dirEndW != NULL &&
                  MultiByteToWideChar(CP_ACP, 0, name, -1, nameW, _countof(nameW)) > 0 &&
                  _snwprintf_s(translW, _TRUNCATE, L"%.*slang\\exif\\%s", (int)(dirEndW + 1 - pathW), pathW, nameW) > 0;
        CHECK(ok);
        CHECK(wcslen(translW) == wcslen(pathW) - 8 + 15);
        CHECK(wcscmp(translW + wcslen(translW) - 33, L"\\plugins\\pictview\\lang\\exif\\en.po") == 0);
        CHECK(translW[3] == 0x65E5);
        // the longest possible: 259 characters of exif.dll's name, a 31-character file name
        for (i = 0; i < 250; i++)
            pathW[i] = L'd';
        wcscpy(pathW + 250, L"\\exif.dll");
        WCHAR longName[32] = L"0123456789012345678901234567890";
        ok = _snwprintf_s(translW, _TRUNCATE, L"%.*slang\\exif\\%s", (int)(wcsrchr(pathW, L'\\') + 1 - pathW), pathW, longName) > 0;
        CHECK(ok && wcslen(translW) == 251 + 10 + 31);
    }
    printf(Fails == 0 ? "ALL CHECKS PASSED\n" : "%d CHECK(S) FAILED\n", Fails);
    return Fails;
}
