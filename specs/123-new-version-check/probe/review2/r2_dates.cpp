// Review 2 probe (feature 123): SalUpdStripWeekday over the long-date picture of every locale
// Windows knows. Prints pictures whose stripped form looks wrong: still holds a day name, starts or
// ends with a separator, holds a doubled separator, or is empty.
#include <windows.h>
#include <stdio.h>
#include <wchar.h>
#include "../../../../src/common/salupdcheck.h"

static int Total = 0, Changed = 0, Suspicious = 0;

static BOOL HasDayName(const WCHAR* p)
{
    BOOL quoted = FALSE;
    for (int i = 0; p[i] != 0; i++)
    {
        if (p[i] == L'\'')
        {
            quoted = !quoted;
            continue;
        }
        if (!quoted && p[i] == L'd' && p[i + 1] == L'd' && p[i + 2] == L'd')
            return TRUE;
    }
    return FALSE;
}

static BOOL IsSep(WCHAR c) { return c == L' ' || c == L',' || c == 0x00A0; }

static BOOL CALLBACK Proc(LPWSTR name, DWORD flags, LPARAM lParam)
{
    WCHAR pic[200], orig[200];
    if (GetLocaleInfoEx(name, LOCALE_SLONGDATE, pic, 200) <= 0)
        return TRUE;
    Total++;
    wcscpy_s(orig, pic);
    SalUpdStripWeekday(pic);
    if (wcscmp(orig, pic) != 0)
        Changed++;
    size_t n = wcslen(pic);
    const char* why = NULL;
    if (n == 0)
        why = "empty";
    else if (HasDayName(pic))
        why = "day name left";
    else if (IsSep(pic[0]) || IsSep(pic[n - 1]))
        why = "separator at an end";
    else if (wcsstr(pic, L", ,") || wcsstr(pic, L",,") || wcsstr(pic, L"  "))
        why = "doubled separator";
    else if (n >= 2 && pic[n - 1] == L'\'' && IsSep(pic[n - 2]) && wcscmp(orig, pic) != 0)
        why = "quoted separator left at the end";
    else if (pic[0] == L'\'' && IsSep(pic[1]) && wcscmp(orig, pic) != 0)
        why = "quoted separator left at the start";
    SYSTEMTIME st = {2026, 10, 3, 14, 8, 0, 0, 0};
    WCHAR out[200] = L"";
    GetDateFormatEx(name, 0, &st, pic, out, 200, NULL);
    if (why != NULL)
    {
        Suspicious++;
        char a[200], b[200], c[400], d[100];
        WideCharToMultiByte(CP_UTF8, 0, orig, -1, a, 200, NULL, NULL);
        WideCharToMultiByte(CP_UTF8, 0, pic, -1, b, 200, NULL, NULL);
        WideCharToMultiByte(CP_UTF8, 0, out, -1, c, 400, NULL, NULL);
        WideCharToMultiByte(CP_UTF8, 0, name, -1, d, 100, NULL, NULL);
        printf("%-14s %-22s [%s] -> [%s] = [%s]\n", d, why, a, b, c);
    }
    return TRUE;
}

int main()
{
    EnumSystemLocalesEx(Proc, LOCALE_ALL, 0, NULL);
    printf("locales %d, pictures changed %d, suspicious %d\n", Total, Changed, Suspicious);
    return 0;
}
