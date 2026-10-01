// perf_probe.cpp - feature 092: what the name comparison costs as a sort and search
// comparator. OLD = the byte fold (the x64 StrICmp of src/common/str.cpp over the
// CharLowerA table), NEW = SalNameCompareOrdinalCI. Built /O2 by run_perf.cmd; prints
// times, always exits 0 - the numbers go to the fix log, nothing is asserted.
#include "precomp.h"
#include <algorithm>
#include <string>
#include <vector>
#include "salunicode.h"

static BYTE Lower[256];

static int OldCmp(const char* a, const char* b)
{
    while (1)
    {
        int res = (int)Lower[(BYTE)*a] - (int)Lower[(BYTE)*b++];
        if (res != 0)
            return res < 0 ? -1 : 1;
        if (*a++ == 0)
            return 0;
    }
}
static int NewCmp(const char* a, const char* b) { return SalNameCompareOrdinalCI(a, -1, b, -1); }

typedef int (*FCmp)(const char*, const char*);

static double Ms(LARGE_INTEGER a, LARGE_INTEGER b)
{
    LARGE_INTEGER f;
    QueryPerformanceFrequency(&f);
    return (double)(b.QuadPart - a.QuadPart) * 1000.0 / (double)f.QuadPart;
}

static unsigned Seed = 92;
static unsigned Rnd()
{
    Seed = Seed * 1103515245u + 12345u;
    return Seed >> 16;
}

// kind 0 = ASCII, 1 = half of the names accented (random first character),
// 2 = every name accented behind a shared prefix
static std::vector<std::string> MakeNames(int kind, int count)
{
    static const char* acc[] = {"\xC4\x8C", "\xC4\x8D", "\xC5\x99", "\xC3\xA1", "\xC5\xBD", "\xC3\xA9", "\xC5\xA1", "\xC3\x9A"};
    std::vector<std::string> v;
    for (int i = 0; i < count; i++)
    {
        std::string s;
        if (kind == 2)
            s = "\xC4\x8Cl\xC3\xA1nek ";
        int len = 20 + Rnd() % 16;
        BOOL accented = kind == 2 || kind == 1 && (i & 1);
        for (int k = 0; k < len; k++)
        {
            if (accented && Rnd() % 4 == 0)
                s += acc[Rnd() % 8];
            else
                s += (char)((Rnd() % 2 ? 'a' : 'A') + Rnd() % 26);
        }
        s += ".txt";
        v.push_back(s);
    }
    return v;
}

static void Run(const char* title, int kind)
{
    const int N = 100000;
    std::vector<std::string> names = MakeNames(kind, N);
    FCmp cmps[2] = {OldCmp, NewCmp};
    const char* labels[2] = {"OLD", "NEW"};
    printf("%s\n", title);
    for (int c = 0; c < 2; c++)
    {
        double bestSort = 1e30, bestFind = 1e30;
        int found = 0;
        for (int round = 0; round < 5; round++)
        {
            std::vector<const char*> p;
            for (int i = 0; i < N; i++)
                p.push_back(names[i].c_str());
            FCmp cmp = cmps[c];
            LARGE_INTEGER t0, t1, t2;
            QueryPerformanceCounter(&t0);
            std::sort(p.begin(), p.end(), [cmp](const char* a, const char* b) { return cmp(a, b) < 0; });
            QueryPerformanceCounter(&t1);
            found = 0;
            for (int i = 0; i < N; i++)
            {
                const char* key = names[i].c_str();
                auto it = std::lower_bound(p.begin(), p.end(), key, [cmp](const char* a, const char* b) { return cmp(a, b) < 0; });
                if (it != p.end() && cmp(*it, key) == 0)
                    found++;
            }
            QueryPerformanceCounter(&t2);
            bestSort = min(bestSort, Ms(t0, t1));
            bestFind = min(bestFind, Ms(t1, t2));
        }
        printf("  %s  sort %7.1f ms   100000 searches %7.1f ms   found %d\n", labels[c], bestSort, bestFind, found);
    }
}

int main()
{
    for (int i = 0; i < 256; i++)
        Lower[i] = (BYTE)(UINT_PTR)CharLowerA((LPSTR)(UINT_PTR)i);
    printf("perf_probe: 100000 names of 24-40 characters, best of 5, code page %u\n", GetACP());
    Run("ASCII names", 0);
    Run("half of the names accented", 1);
    Run("every name accented, shared accented prefix", 2);
    return 0;
}
