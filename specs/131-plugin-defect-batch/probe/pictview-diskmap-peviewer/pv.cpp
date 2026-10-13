// feature 131 measurement for PictView (thumbs.cpp):
// 1. _sntprintf(fileName, _MAX_PATH, "%s%s%s", ...) with a full name over 259 bytes
// 2. a code-page path (U8ToDLLPathAlloc) handed to a reader of UTF-8 (SplU8ToWExtAlloc, as
//    OpenFromFileU8 of wicengine.cpp does)
// 3. InitEXIF: WideCharToMultiByte into path[MAX_PATH] for a folder that needs more bytes
#include <windows.h>
#include <tchar.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "E:/Projects/tandemcommander/src/plugins/shared/splunicode.h"

static void Hex(const char* s)
{
    for (; *s; s++)
        if ((unsigned char)*s >= 0x80)
            printf("<%02X>", (unsigned char)*s);
        else
            printf("%c", *s);
}

int main()
{
    // ---- 1
    char guard[_MAX_PATH + 16];
    memset(guard, '#', sizeof(guard));
    char path[300] = "C:\\Fotky\\2024";
    char name[400];
    memset(name, 'n', 300);
    strcpy(name + 300, ".jpg");
    int r = _sntprintf(guard, _MAX_PATH, _T("%s%s%s"), path, "\\", name);
    printf("1. _sntprintf ret %d; byte[259] '%c' byte[260] '%c' (the caller's memory); terminator inside the buffer: %s\n",
           r, guard[259], guard[260], memchr(guard, 0, _MAX_PATH) != NULL ? "yes" : "NO");
    char fixedBuf[_MAX_PATH];
    r = _snprintf_s(fixedBuf, _MAX_PATH, _TRUNCATE, "%s%s%s", path, "\\", name);
    printf("   _snprintf_s(_TRUNCATE) ret %d (the sign of a name that does not fit)\n", r);

    // ---- 2
    const WCHAR* wPath = L"C:\\Fotky\\P\x0159\x00EDli\x0161 \x017Elu\x0165ou\x010Dk\x00FD k\x016F\x0148.jpg";
    char u8[300], cp[300];
    WideCharToMultiByte(CP_UTF8, 0, wPath, -1, u8, sizeof(u8), NULL, NULL);
    WideCharToMultiByte(1250, 0, wPath, -1, cp, sizeof(cp), NULL, NULL); // what U8ToDLLPathAlloc gives on a 1250 system
    WCHAR* w1 = SplU8ToWExtAlloc(u8);
    WCHAR* w2 = SplU8ToWExtAlloc(cp);
    printf("2. UTF-8 path -> %s\n", w1 != NULL && wcscmp(w1 + 4, wPath) == 0 ? "the same wide path (with \\\\?\\)" : "DIFFERENT");
    printf("   code-page path \"");
    Hex(cp);
    printf("\" -> %s\n", w2 == NULL ? "NULL (OpenFromFileU8 returns PVC_CANNOT_OPEN_FILE)" : "a wide path");
    const WCHAR* wPath2 = L"C:\\Fotky\\caf\x00E9.jpg"; // one accented letter (1250 and 1252: E9)
    WideCharToMultiByte(1250, 0, wPath2, -1, cp, sizeof(cp), NULL, NULL);
    WCHAR* w3 = SplU8ToWExtAlloc(cp);
    printf("   code-page path \"");
    Hex(cp);
    printf("\" -> %s\n", w3 == NULL ? "NULL (cannot open)" : "a wide path");
    free(w1);
    free(w2);
    free(w3);

    // ---- 3 (code page 932 stands for a system with a double-byte code page)
    WCHAR pathW[MAX_PATH] = L"C:\\";
    int i = 3;
    for (; i < 200; i++)
        pathW[i] = 0x65E5; // a kanji, two bytes in code page 932
    wcscpy(pathW + i, L"\\plugins\\pictview\\exif.dll");
    char pathA[MAX_PATH] = "x";
    int conv = WideCharToMultiByte(932, 0, pathW, -1, pathA, sizeof(pathA), NULL, NULL);
    if (conv == 0)
        pathA[0] = 0;
    printf("3. %u wide characters -> WideCharToMultiByte ret %d, error %lu; _tcsrchr(path, '\\\\') = %p, + 1 = %p\n",
           (unsigned)wcslen(pathW), conv, conv == 0 ? GetLastError() : 0, (void*)_tcsrchr(pathA, '\\'),
           (void*)(_tcsrchr(pathA, '\\') + 1));
    return 0;
}
