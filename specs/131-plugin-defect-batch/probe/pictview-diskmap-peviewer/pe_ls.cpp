// feature 131 measurement: what does a narrow fprintf("%ls") write with the UCRT, a text-mode
// stream opened by _wfopen(L"w") and no setlocale call (the PE Viewer's situation)?
#include <windows.h>
#include <stdio.h>
#include <stdarg.h>
#include <errno.h>
#include <locale.h>
#include <string.h>

static FILE* Stream;

static int my_fprintf(const char* format, ...) // CFileStream::fprintf of pefile.h
{
    va_list args;
    va_start(args, format);
    int r = vfprintf(Stream, format, args);
    va_end(args);
    return r;
}

static void DumpFile(const wchar_t* name)
{
    FILE* f = _wfopen(name, L"rb");
    unsigned char buf[4096];
    size_t n = fread(buf, 1, sizeof(buf), f);
    fclose(f);
    for (size_t i = 0; i < n; i++)
    {
        if (buf[i] >= 0x20 && buf[i] < 0x7F)
            printf("%c", buf[i]);
        else
            printf("<%02X>", buf[i]);
        if (buf[i] == '\n')
            printf("\n");
    }
    printf("\n");
}

// the fix: the same conversion the neighbouring value gets (W2A of pefile.cpp)
static const char* W2A(const wchar_t* s, char* buf, int size)
{
    if (WideCharToMultiByte(CP_ACP, 0, s, -1, buf, size, NULL, NULL) == 0)
        buf[0] = 0;
    return buf;
}

int main()
{
    printf("locale: %s, ACP: %u\n", setlocale(LC_ALL, NULL), GetACP());
    const wchar_t* name = L"pe_ls_out.txt";

    const wchar_t* ascii = L"CompanyName";
    const wchar_t* latin1 = L"Soci\x00E9t\x00E9";                 // e acute: U+00E9 (in 1250 and 1252: E9)
    const wchar_t* latin1b = L"Na\x00EFve\x00A9\x00D8";           // U+00EF, U+00A9 (c), U+00D8 (O slash; 1250 has R caron at D8)
    const wchar_t* czech = L"N\x00E1zev\x0159" L"et\x011B" L"zce"; // a acute U+00E1, r caron U+0159, e caron U+011B
    const wchar_t* japan = L"\x4F1A\x793E\x540D";                 // kanji

    Stream = _wfopen(name, L"w");
    int r;
    errno = 0;
    r = my_fprintf("    %ls", ascii);
    printf("ascii:   ret %d errno %d\n", r, errno);
    my_fprintf(":   value\n");
    errno = 0;
    r = my_fprintf("    %ls", latin1);
    printf("latin1:  ret %d errno %d\n", r, errno);
    my_fprintf(":   value\n");
    errno = 0;
    r = my_fprintf("    %ls", latin1b);
    printf("latin1b: ret %d errno %d\n", r, errno);
    my_fprintf(":   value\n");
    errno = 0;
    r = my_fprintf("    %ls", czech);
    printf("czech:   ret %d errno %d ferror %d\n", r, errno, ferror(Stream));
    my_fprintf(":   value\n");
    errno = 0;
    r = my_fprintf("    %ls", japan);
    printf("japan:   ret %d errno %d ferror %d\n", r, errno, ferror(Stream));
    my_fprintf(":   value\n");
    // pefile.cpp:2317 and 2499: the line end is in the same call
    errno = 0;
    r = my_fprintf("  %-*s%ls\n", 31, "Runtime Version:", L"v4.0.30319");
    printf("rtver ascii: ret %d errno %d\n", r, errno);
    errno = 0;
    r = my_fprintf("  %-*s%ls\n", 31, "Runtime Version:", L"v4.0-\x0159-tail");
    printf("rtver czech: ret %d errno %d ferror %d\n", r, errno, ferror(Stream));
    errno = 0;
    r = my_fprintf("    %ls\n", L"Knihovna\x010C, Version=1.0.0.0");
    printf("asm czech:   ret %d errno %d ferror %d\n", r, errno, ferror(Stream));
    r = my_fprintf("    %ls\n", L"NextAssembly, Version=1.0.0.0");
    printf("asm next:    ret %d\n", r);
    my_fprintf("--- fixed (W2A, CP_ACP) ---\n");
    char b[200];
    r = my_fprintf("    %s", W2A(czech, b, sizeof(b)));
    printf("fixed czech: ret %d\n", r);
    my_fprintf(":   value\n");
    r = my_fprintf("    %s", W2A(latin1b, b, sizeof(b)));
    my_fprintf(":   value\n");
    r = my_fprintf("    %s", W2A(japan, b, sizeof(b)));
    my_fprintf(":   value\n");
    r = my_fprintf("    %s\n", W2A(L"Knihovna\x010C, Version=1.0.0.0", b, sizeof(b)));
    r = my_fprintf("    %s\n", W2A(L"NextAssembly, Version=1.0.0.0", b, sizeof(b)));
    fclose(Stream);
    DumpFile(name);
    return 0;
}
