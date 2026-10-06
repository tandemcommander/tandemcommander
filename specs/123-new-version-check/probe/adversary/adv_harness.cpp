// Adversarial harness for src/common/salupdcheck.h (feature 123).
// Independent of saltests. No STL (so that /RTCc builds without _ALLOW_RTCc_IN_STL).
//
//   adv_harness batch <cases.bin> <verdicts.txt>   differential run (verdicts are compared by adv.py)
//   adv_harness unit                               direct tests of the small functions (C5) and buffers
//   adv_harness perf                               worst-case time and stack use (C1)
//   adv_harness locales                            SalUpdStripWeekday on every installed locale's long date
//
// Every input is placed so that its last byte is followed by a PAGE_NOACCESS page (an over-read
// faults in every build) and is also run from an exact-size malloc block (AddressSanitizer build
// sees over- and under-reads).

#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef ADV_MUTANT
#include "salupdcheck.h" // a deliberately broken copy on the include path (mutants.py): the tests must notice it
#else
#include "../../../../src/common/salupdcheck.h"
#endif

static int Failures = 0;
static int Checks = 0;

#define CHECK(cond) \
    do \
    { \
        Checks++; \
        if (!(cond)) \
        { \
            Failures++; \
            printf("CHECK FAILED line %d: %s\n", __LINE__, #cond); \
        } \
    } while (0)

//
// guard-page buffers
//

struct CGuard
{
    unsigned char* Base;
    unsigned char* End; // first byte of the trailing no-access page
    size_t Cap;
};

static void GuardInit(CGuard* g, size_t cap)
{
    const size_t page = 4096;
    cap = (cap + page - 1) / page * page;
    g->Base = (unsigned char*)VirtualAlloc(NULL, cap + 2 * page, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE);
    if (g->Base == NULL)
    {
        printf("VirtualAlloc failed\n");
        exit(3);
    }
    DWORD old;
    VirtualProtect(g->Base, page, PAGE_NOACCESS, &old);
    VirtualProtect(g->Base + page + cap, page, PAGE_NOACCESS, &old);
    g->End = g->Base + page + cap;
    g->Cap = cap;
}

// returns a pointer to 'len' bytes whose end touches the no-access page
static unsigned char* GuardTail(CGuard* g, size_t len)
{
    if (len > g->Cap)
    {
        printf("guard buffer too small (%u)\n", (unsigned)len);
        exit(3);
    }
    return g->End - len;
}

static char* GuardCopy(CGuard* g, const void* src, size_t len)
{
    unsigned char* p = GuardTail(g, len);
    if (len > 0)
        memcpy(p, src, len);
    return (char*)p;
}

static CGuard GIn, GOut;

static double QpcFreq;

static double NowUs()
{
    LARGE_INTEGER t;
    QueryPerformanceCounter(&t);
    return (double)t.QuadPart * 1000000.0 / QpcFreq;
}

static BOOL UrlLooksOfficial(const char* url)
{
    static const char prefix[] = "https://github.com/tandemcommander/tandemcommander/releases/";
    if (strncmp(url, prefix, sizeof(prefix) - 1) != 0)
        return FALSE;
    for (const char* p = url; *p != 0; p++)
    {
        char c = *p;
        if (!((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == ':' || c == '/' || c == '.' || c == '-'))
            return FALSE;
    }
    return TRUE;
}

static void PrintHex(FILE* out, const unsigned char* p, size_t n)
{
    static const char hex[] = "0123456789abcdef";
    if (n == 0)
        fputc('-', out);
    for (size_t i = 0; i < n; i++)
    {
        fputc(hex[p[i] >> 4], out);
        fputc(hex[p[i] & 15], out);
    }
}

//
// batch mode
//

static double MaxUs = 0;
static long MaxUsCase = -1;
static size_t MaxUsLen = 0;

static void RunRecord(long idx, const unsigned char* data, size_t len, FILE* out)
{
    char* g = GuardCopy(&GIn, data, len);
    CSalUpdRelease rel;
    memset(&rel, 0x5A, sizeof(rel));
    CSalUpdParseError err = (CSalUpdParseError)99;
    double t0 = NowUs();
    BOOL ok = SalUpdParseLatestRelease(g, len, &rel, &err);
    double us = NowUs() - t0;
    if (us > MaxUs)
    {
        MaxUs = us;
        MaxUsCase = idx;
        MaxUsLen = len;
    }

    // the same from an exact-size heap block, without the error out-parameter
    char* m = (char*)malloc(len);
    if (len > 0)
        memcpy(m, data, len);
    CSalUpdRelease rel2;
    memset(&rel2, 0xA5, sizeof(rel2));
    BOOL ok2 = SalUpdParseLatestRelease(m, len, &rel2, NULL);
    const char* inv = "";
    if (ok != ok2 || memcmp(&rel, &rel2, sizeof(rel)) != 0)
        inv = "INV_NONDETERMINISTIC";

    // the grammar alone: any value, nothing after it
    CSalUpdJsonReader r(m, len);
    BOOL gr = r.SkipValue(1) && !r.IsFailed() && r.AtEnd();
    free(m);

    if (ok)
    {
        char a[SALUPD_URL_MAX], b[SALUPD_URL_MAX];
        ULONGLONG ft = 0;
        if (err != supeNone)
            inv = "INV_ERR_ON_SUCCESS";
        else if (!SalUpdInstallerUrl(rel.Version, a, sizeof(a)) || !SalUpdReleaseNotesUrl(rel.Version, b, sizeof(b)))
            inv = "INV_URL_BUILD";
        else if (!UrlLooksOfficial(a) || !UrlLooksOfficial(b))
            inv = "INV_URL_CHARSET";
        else if (strlen(rel.PublishedText) != 20 || !SalUpdParseUtcTime(rel.PublishedText, -1, &ft) || ft != rel.PublishedUtc)
            inv = "INV_TIME_TEXT";
        else if (rel.Version.Major > 99999 || rel.Version.Minor > 99999 || rel.Version.Patch > 99999)
            inv = "INV_VERSION_RANGE";
        else if (!gr)
            inv = "INV_ACCEPTED_BUT_GRAMMAR_FAILS";
    }
    else
    {
        static const CSalUpdRelease zero = {};
        if (err == supeNone || (int)err < 0 || (int)err > (int)supeNoInstaller)
            inv = "INV_ERR_ON_FAILURE";
        else if (memcmp(&rel, &zero, sizeof(rel)) != 0)
            inv = "INV_RELEASE_NOT_ZERO";
    }
    fprintf(out, "R %d %d %d %u %u %u %llu %s %s\n", gr ? 1 : 0, ok ? 1 : 0, (int)err,
            rel.Version.Major, rel.Version.Minor, rel.Version.Patch, rel.PublishedUtc,
            ok ? rel.PublishedText : "-", inv[0] != 0 ? inv : "ok");
}

// payload: u16 outSize, then the literal
static void RunString(const unsigned char* data, size_t len, FILE* out)
{
    if (len < 2)
    {
        fprintf(out, "S short\n");
        return;
    }
    int outSize = data[0] | (data[1] << 8);
    const unsigned char* lit = data + 2;
    size_t n = len - 2;
    char* g = GuardCopy(&GIn, lit, n);
    char* o = (char*)GuardTail(&GOut, (size_t)outSize);
    if (outSize > 0)
        memset(o, 0xAA, (size_t)outSize);
    CSalUpdJsonReader r(g, n);
    BOOL bad = 77;
    BOOL ok = r.ReadString(o, outSize, &bad);
    BOOL atEnd = ok && r.AtEnd();
    // skipping must agree with reading about the grammar
    CSalUpdJsonReader r2(g, n);
    BOOL ok2 = r2.ReadString(NULL, 0, NULL);
    BOOL atEnd2 = ok2 && r2.AtEnd();
    const char* inv = "ok";
    if (ok != ok2 || atEnd != atEnd2)
        inv = "INV_SKIP_DISAGREES";
    else if (ok && bad != TRUE && bad != FALSE)
        inv = "INV_BAD_NOT_SET";
    else if (ok && bad && outSize > 0 && o[0] != 0)
        inv = "INV_BAD_NOT_EMPTY";
    size_t outLen = 0;
    if (ok && !bad)
    {
        if (outSize <= 0)
            inv = "ok"; // NIT-1: only the empty string gets here (nothing was stored, nothing was terminated)
        else
        {
            while (outLen < (size_t)outSize && o[outLen] != 0)
                outLen++;
            if (outLen >= (size_t)outSize)
            {
                inv = "INV_NOT_TERMINATED";
                outLen = 0;
            }
        }
    }
    fprintf(out, "S %d %d %d ", ok ? 1 : 0, ok ? (bad ? 1 : 0) : 0, atEnd ? 1 : 0);
    PrintHex(out, (const unsigned char*)o, outLen);
    fprintf(out, " %s\n", inv);
}

// payload: u8 tagForm, u8 explicitLen, then the text
static void RunVersion(const unsigned char* data, size_t len, FILE* out)
{
    if (len < 2)
    {
        fprintf(out, "V short\n");
        return;
    }
    BOOL tagForm = data[0] != 0;
    BOOL explicitLen = data[1] != 0;
    const unsigned char* txt = data + 2;
    size_t n = len - 2;
    char* g;
    int l;
    if (explicitLen)
    {
        g = GuardCopy(&GIn, txt, n);
        l = (int)n;
    }
    else
    {
        unsigned char* p = GuardTail(&GIn, n + 1);
        memcpy(p, txt, n);
        p[n] = 0;
        g = (char*)p;
        l = -1;
    }
    CSalUpdVersion v = {7777777, 7777777, 7777777};
    BOOL ok = SalUpdParseVersion(g, l, tagForm, &v);
    const char* inv = "ok";
    if (!ok && (v.Major != 7777777 || v.Minor != 7777777 || v.Patch != 7777777))
        inv = "INV_OUTPUT_TOUCHED_ON_FAILURE";
    fprintf(out, "V %d %u %u %u %s\n", ok ? 1 : 0, ok ? v.Major : 0, ok ? v.Minor : 0, ok ? v.Patch : 0, inv);
}

// payload: u8 explicitLen, then the text
static void RunTime(const unsigned char* data, size_t len, FILE* out)
{
    if (len < 1)
    {
        fprintf(out, "D short\n");
        return;
    }
    BOOL explicitLen = data[0] != 0;
    const unsigned char* txt = data + 1;
    size_t n = len - 1;
    char* g;
    int l;
    if (explicitLen)
    {
        g = GuardCopy(&GIn, txt, n);
        l = (int)n;
    }
    else
    {
        unsigned char* p = GuardTail(&GIn, n + 1);
        memcpy(p, txt, n);
        p[n] = 0;
        g = (char*)p;
        l = -1;
    }
    ULONGLONG ft = 0x1234567812345678ULL;
    BOOL ok = SalUpdParseUtcTime(g, l, &ft);
    const char* inv = "ok";
    if (!ok && ft != 0x1234567812345678ULL)
        inv = "INV_OUTPUT_TOUCHED_ON_FAILURE";
    if (ok)
    {
        // round trip through Windows: the FILETIME is the time that was written
        FILETIME f;
        SYSTEMTIME st;
        f.dwLowDateTime = (DWORD)(ft & 0xFFFFFFFFULL);
        f.dwHighDateTime = (DWORD)(ft >> 32);
        char back[40];
        if (!FileTimeToSystemTime(&f, &st))
            inv = "INV_ROUNDTRIP";
        else
        {
            sprintf_s(back, sizeof(back), "%04u-%02u-%02uT%02u:%02u:%02uZ", (unsigned)st.wYear, (unsigned)st.wMonth,
                      (unsigned)st.wDay, (unsigned)st.wHour, (unsigned)st.wMinute, (unsigned)st.wSecond);
            if (n < 20 || (explicitLen && n != 20) || memcmp(back, txt, 20) != 0)
                inv = "INV_ROUNDTRIP";
        }
    }
    fprintf(out, "D %d %llu %s\n", ok ? 1 : 0, ok ? ft : 0ULL, inv);
}

// payload: i16 pathSize, then UTF-16LE text (no terminator)
static void RunLoopback(const unsigned char* data, size_t len, FILE* out)
{
    if (len < 2 || ((len - 2) & 1) != 0)
    {
        fprintf(out, "L short\n");
        return;
    }
    int pathSize = (short)(data[0] | (data[1] << 8));
    size_t units = (len - 2) / 2;
    WCHAR* url = (WCHAR*)GuardTail(&GIn, (units + 1) * sizeof(WCHAR));
    memcpy(url, data + 2, units * sizeof(WCHAR));
    url[units] = 0;
    int cap = pathSize > 0 ? pathSize : 0;
    WCHAR* path = (WCHAR*)GuardTail(&GOut, (size_t)cap * sizeof(WCHAR));
    for (int i = 0; i < cap; i++)
        path[i] = 0xAAAA;
    int port = -12345;
    BOOL ok = SalUpdParseLoopbackUrl(url, &port, path, pathSize);
    const char* inv = "ok";
    size_t pl = 0;
    if (ok)
    {
        while (pl < (size_t)cap && path[pl] != 0)
            pl++;
        if (pl >= (size_t)cap)
        {
            inv = "INV_NOT_TERMINATED";
            pl = 0;
        }
    }
    else
    {
        if (port != -12345)
            inv = "INV_PORT_TOUCHED_ON_FAILURE";
        for (int i = 0; i < cap; i++)
        {
            if (path[i] != 0xAAAA)
                inv = "INV_PATH_TOUCHED_ON_FAILURE";
        }
    }
    fprintf(out, "L %d %d ", ok ? 1 : 0, ok ? port : 0);
    PrintHex(out, (const unsigned char*)path, pl * sizeof(WCHAR));
    fprintf(out, " %s\n", inv);
}

static int Batch(const char* inName, const char* outName)
{
    FILE* in = NULL;
    FILE* out = NULL;
    if (fopen_s(&in, inName, "rb") != 0 || in == NULL)
    {
        printf("cannot open %s\n", inName);
        return 3;
    }
    if (fopen_s(&out, outName, "wb") != 0 || out == NULL)
    {
        printf("cannot create %s\n", outName);
        return 3;
    }
    size_t cap = 1024 * 1024;
    unsigned char* buf = (unsigned char*)malloc(cap);
    long idx = 0;
    for (;;)
    {
        unsigned char head[5];
        if (fread(head, 1, 5, in) != 5)
            break;
        size_t len = (size_t)head[1] | ((size_t)head[2] << 8) | ((size_t)head[3] << 16) | ((size_t)head[4] << 24);
        if (len > cap)
        {
            cap = len;
            buf = (unsigned char*)realloc(buf, cap);
        }
        if (len > 0 && fread(buf, 1, len, in) != len)
        {
            printf("truncated case file\n");
            return 3;
        }
        switch (head[0])
        {
        case 'R':
            RunRecord(idx, buf, len, out);
            break;
        case 'S':
            RunString(buf, len, out);
            break;
        case 'V':
            RunVersion(buf, len, out);
            break;
        case 'D':
            RunTime(buf, len, out);
            break;
        case 'L':
            RunLoopback(buf, len, out);
            break;
        default:
            printf("unknown case kind %d\n", (int)head[0]);
            return 3;
        }
        idx++;
    }
    fprintf(out, "# cases %ld maxus %.1f case %ld len %u\n", idx, MaxUs, MaxUsCase, (unsigned)MaxUsLen);
    fclose(out);
    fclose(in);
    free(buf);
    return 0;
}

//
// unit mode
//

static unsigned Rng = 0x12345678;
static unsigned Rnd()
{
    Rng ^= Rng << 13;
    Rng ^= Rng >> 17;
    Rng ^= Rng << 5;
    return Rng;
}

static BOOL IsUrlSafeText(const char* s)
{
    for (; *s != 0; s++)
    {
        char c = *s;
        if (!((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == ':' || c == '/' || c == '.' || c == '-'))
            return FALSE;
    }
    return TRUE;
}

typedef BOOL (*FBuild)(const CSalUpdVersion&, char*, int);

// every buffer size from 0 to need+3: fits exactly at need, never writes past the size given
static void TestBuilderSizes(FBuild f, const CSalUpdVersion& v, const char* expect)
{
    int need = (int)strlen(expect) + 1;
    for (int size = 0; size <= need + 3; size++)
    {
        char* b = (char*)GuardTail(&GOut, (size_t)size);
        if (size > 0)
            memset(b, 0x55, (size_t)size);
        BOOL ok = f(v, b, size);
        CHECK(ok == (size >= need));
        if (ok)
            CHECK(strcmp(b, expect) == 0);
        else if (size > 0)
            CHECK(b[0] == 0);
    }
    CHECK(!f(v, NULL, 100));
    char one[4] = "xyz";
    CHECK(!f(v, one, -1) && one[0] == 'x');
    CHECK(!f(v, one, -2147483647 - 1) && one[0] == 'x');
}

static void UnitVersions()
{
    static const unsigned vals[] = {0, 1, 9, 10, 99, 100, 99999, 100000, 2147483647u, 2147483648u, 4294967295u};
    char expect[300];
    for (int a = 0; a < _countof(vals); a++)
    {
        for (int b = 0; b < _countof(vals); b++)
        {
            for (int c = 0; c < _countof(vals); c++)
            {
                CSalUpdVersion v = {vals[a], vals[b], vals[c]};
                sprintf_s(expect, sizeof(expect), "%u.%u.%u", v.Major, v.Minor, v.Patch);
                TestBuilderSizes(SalUpdFormatVersion, v, expect);
                sprintf_s(expect, sizeof(expect), "tandemcommander-%u.%u.%u-x64-setup.exe", v.Major, v.Minor, v.Patch);
                TestBuilderSizes(SalUpdInstallerName, v, expect);
                sprintf_s(expect, sizeof(expect), "https://github.com/tandemcommander/tandemcommander/releases/tag/v%u.%u.%u", v.Major, v.Minor, v.Patch);
                TestBuilderSizes(SalUpdReleaseNotesUrl, v, expect);
                CHECK(IsUrlSafeText(expect));
                sprintf_s(expect, sizeof(expect),
                          "https://github.com/tandemcommander/tandemcommander/releases/download/v%u.%u.%u/tandemcommander-%u.%u.%u-x64-setup.exe",
                          v.Major, v.Minor, v.Patch, v.Major, v.Minor, v.Patch);
                TestBuilderSizes(SalUpdInstallerUrl, v, expect);
                CHECK(IsUrlSafeText(expect));
            }
        }
    }
    // the buffer sizes the header names are enough for every version that can be parsed
    CSalUpdVersion big = {99999, 99999, 99999};
    char t[SALUPD_VERSION_TEXT_MAX], u[SALUPD_URL_MAX];
    CHECK(SalUpdFormatVersion(big, t, sizeof(t)));
    CHECK(SalUpdInstallerUrl(big, u, sizeof(u)) && SalUpdReleaseNotesUrl(big, u, sizeof(u)) && SalUpdInstallerName(big, u, sizeof(u)));

    // random versions: print, parse back, compare; the order agrees with a 64-bit-wide reference
    for (int i = 0; i < 300000; i++)
    {
        CSalUpdVersion x = {Rnd() % 100000, Rnd() % 100000, Rnd() % 100000};
        CSalUpdVersion y = {Rnd() % 100000, Rnd() % 100000, Rnd() % 100000};
        if ((i & 3) == 0)
            y = x;
        if ((i & 7) == 1)
            y.Patch = x.Patch + 1, y.Major = x.Major, y.Minor = x.Minor;
        if ((i & 15) == 2)
        {
            x.Major = Rnd();
            x.Minor = Rnd();
            x.Patch = Rnd();
            y.Major = (Rnd() & 1) ? x.Major : Rnd();
            y.Minor = (Rnd() & 1) ? x.Minor : Rnd();
            y.Patch = Rnd();
        }
        int c = SalUpdVersionCompare(x, y);
        int ref = x.Major != y.Major ? (x.Major < y.Major ? -1 : 1) : x.Minor != y.Minor ? (x.Minor < y.Minor ? -1 : 1)
                                                                  : x.Patch != y.Patch   ? (x.Patch < y.Patch ? -1 : 1)
                                                                                         : 0;
        CHECK((c < 0) == (ref < 0) && (c > 0) == (ref > 0));
        int c2 = SalUpdVersionCompare(y, x);
        CHECK((c < 0) == (c2 > 0) && (c == 0) == (c2 == 0));
        if (x.Major < 100000 && x.Minor < 100000 && x.Patch < 100000)
        {
            char txt[40], tag[40];
            CHECK(SalUpdFormatVersion(x, txt, sizeof(txt)));
            CSalUpdVersion p;
            CHECK(SalUpdParseVersion(txt, -1, FALSE, &p) && SalUpdVersionCompare(p, x) == 0);
            sprintf_s(tag, sizeof(tag), "v%s", txt);
            CHECK(SalUpdParseVersion(tag, -1, TRUE, &p) && SalUpdVersionCompare(p, x) == 0);
            CHECK(SalUpdParseVersion(tag, (int)strlen(tag), TRUE, &p) && SalUpdVersionCompare(p, x) == 0);
            CHECK(!SalUpdParseVersion(tag, (int)strlen(tag) + 1, TRUE, &p)); // the terminating zero is not part of a version
            CHECK(!SalUpdParseVersion(tag, (int)strlen(tag) - 1, TRUE, &p) || strlen(tag) >= 7);
        }
    }
    CSalUpdVersion p;
    CHECK(!SalUpdParseVersion(NULL, 0, TRUE, &p));
    CHECK(!SalUpdParseVersion("", 0, TRUE, &p) && !SalUpdParseVersion("", 0, FALSE, &p));
    CHECK(!SalUpdParseVersion("v1.2.3", 0, TRUE, &p));
    CHECK(SalUpdParseVersion("v1.2.3", -5, TRUE, &p)); // every negative length means zero-terminated
    CHECK(SalUpdParseVersion("v1.2.3", -2147483647 - 1, TRUE, &p));
}

static void UnitDecisions()
{
    // HTTP status
    for (unsigned s = 0; s < 70000; s++)
    {
        CSalUpdResult res = surCancelled;
        BOOL body = SalUpdStatusWantsBody(s, &res);
        CHECK(body == (s == 200));
        if (s == 200)
            CHECK(res == surCancelled);
        else
            CHECK(res == ((s == 403 || s == 429) ? surRefused : surUnexpected));
        CHECK(SalUpdStatusWantsBody(s, NULL) == (s == 200)); // NULL result is allowed
    }
    static const DWORD odd[] = {0xFFFFFFFF, 0x80000000, 65536 + 200, 0x100000C8, 200 + 256, 0x000100C8};
    for (int i = 0; i < _countof(odd); i++)
    {
        CSalUpdResult res = surCancelled;
        CHECK(!SalUpdStatusWantsBody(odd[i], &res) && res == surUnexpected);
    }

    // due rule against the sentence in data-model.md, incl. the ends of the 64-bit range
    static const ULONGLONG pts[] = {0, 1, SALUPD_HOUR - 1, SALUPD_HOUR, SALUPD_HOUR + 1, 24 * SALUPD_HOUR - 1, 24 * SALUPD_HOUR,
                                    24 * SALUPD_HOUR + 1, 134000000000000000ULL, 0x7FFFFFFFFFFFFFFFULL, 0x8000000000000000ULL,
                                    0xFFFFFFFFFFFFFFFFULL - 24 * SALUPD_HOUR, 0xFFFFFFFFFFFFFFFEULL, 0xFFFFFFFFFFFFFFFFULL};
    for (int a = 0; a < _countof(pts); a++)
    {
        for (int b = 0; b < _countof(pts); b++)
        {
            for (int flags = 0; flags < 8; flags++)
            {
                BOOL opt = (flags & 1) != 0, has = (flags & 2) != 0, answered = (flags & 4) != 0;
                ULONGLONG last = pts[a], now = pts[b];
                BOOL ref;
                if (!opt)
                    ref = FALSE;
                else if (!has || last > now)
                    ref = TRUE;
                else
                    ref = (now - last) >= (answered ? 864000000000ULL : 36000000000ULL);
                CHECK(SalUpdAutoCheckDue(opt, has, last, answered, now) == ref);
                // any non-zero BOOL is TRUE
                CHECK(SalUpdAutoCheckDue(opt ? 2 : 0, has ? -1 : 0, last, answered ? 0x100 : 0, now) == ref);
            }
        }
    }

    // notification and the About state for every result and relation
    static const CSalUpdVersion vs[] = {{0, 0, 0}, {0, 1, 8}, {0, 1, 9}, {1, 0, 0}, {4294967295u, 4294967295u, 4294967295u}};
    for (int r = 0; r <= (int)surCancelled; r++)
    {
        for (int a = 0; a < _countof(vs); a++)
        {
            for (int b = 0; b < _countof(vs); b++)
            {
                for (int has = 0; has < 2; has++)
                {
                    BOOL ref = r == (int)surNewer && (!has || a != b);
                    CHECK(SalUpdStartupNoticeWanted((CSalUpdResult)r, vs[a], has, vs[b]) == ref);
                    CSalUpdKnownState k = SalUpdKnownState(has, vs[a], vs[b]);
                    CHECK(k == (!has ? suksNotChecked : a > b ? suksNewer : suksUpToDate));
                }
            }
        }
        CHECK(SalUpdResultName((CSalUpdResult)r)[0] != 0);
        CHECK(SalUpdResultIsKnowledge((CSalUpdResult)r) == (r == surNewer || r == surUpToDate));
    }
    CHECK(strcmp(SalUpdResultName((CSalUpdResult)77), "unknown") == 0);
}

// ReadString with every buffer size around the need, for texts whose last character has 1 to 4 bytes
static void UnitReadStringSizes()
{
    static const char* lits[] = {"\"\"", "\"a\"", "\"abc\\u00e9\"", "\"abc\\u20ac\"", "\"abc\\ud83d\\udcc1\"", "\"\\u00e9\"", "\"\\ud83d\\udcc1\"",
                                 "\"abc\xC3\xA9\"", "\"\\n\"", "\"0123456789012345678901234567890123456789\""};
    static const char* outs[] = {"", "a", "abc\xC3\xA9", "abc\xE2\x82\xAC", "abc\xF0\x9F\x93\x81", "\xC3\xA9", "\xF0\x9F\x93\x81",
                                 "abc\xC3\xA9", "\n", "0123456789012345678901234567890123456789"};
    for (int i = 0; i < _countof(lits); i++)
    {
        size_t n = strlen(lits[i]);
        int need = (int)strlen(outs[i]) + 1;
        for (int size = 0; size <= need + 2; size++)
        {
            char* in = GuardCopy(&GIn, lits[i], n);
            char* o = (char*)GuardTail(&GOut, (size_t)size);
            if (size > 0)
                memset(o, 0x55, (size_t)size);
            CSalUpdJsonReader r(in, n);
            BOOL bad = 9;
            CHECK(r.ReadString(o, size, &bad) && r.AtEnd());
            if (i == 0 && size == 0)
            {
                // NIT-1 (README): the empty string "fits" a buffer of 0 bytes - 'bad' stays FALSE although
                // no terminator can be written. No caller passes outSize 0 with a buffer.
                if (!bad)
                    printf("NIT-1 confirmed: ReadString(out, 0, &bad) on \"\" reports bad == FALSE\n");
            }
            else
                CHECK(bad == (size < need));
            if (size >= need)
                CHECK(strcmp(o, outs[i]) == 0);
            else if (size > 0)
                CHECK(o[0] == 0);
            // 'bad' may be NULL
            CSalUpdJsonReader r2(in, n);
            CHECK(r2.ReadString(o, size, NULL) && r2.AtEnd());
        }
    }
    // the documented limit: 511 bytes fit SALUPD_MAX_STRING, 512 do not
    for (int len = 509; len <= 514; len++)
    {
        char lit[600];
        lit[0] = '"';
        memset(lit + 1, 'x', (size_t)len);
        lit[len + 1] = '"';
        char* in = GuardCopy(&GIn, lit, (size_t)len + 2);
        char* o = (char*)GuardTail(&GOut, SALUPD_MAX_STRING);
        CSalUpdJsonReader r(in, (size_t)len + 2);
        BOOL bad = 9;
        CHECK(r.ReadString(o, SALUPD_MAX_STRING, &bad) && r.AtEnd());
        CHECK(bad == (len > SALUPD_MAX_STRING - 1));
        if (!bad)
            CHECK(strlen(o) == (size_t)len);
    }
    // NIT-2 (README): after a FAILED ReadString the caller's buffer holds the bytes stored so far
    // without a terminating zero (the header's own callers never look at it)
    {
        char o[8];
        memset(o, 0x55, sizeof(o));
        CSalUpdJsonReader r("\"abc", 4);
        BOOL bad = FALSE;
        CHECK(!r.ReadString(o, sizeof(o), &bad));
        if (o[0] == 'a' && o[1] == 'b' && o[2] == 'c' && o[3] == 0x55)
            printf("NIT-2 confirmed: a failed ReadString leaves \"abc\" + old bytes in 'out', not terminated\n");
    }
    // a reader over nothing
    CSalUpdJsonReader n1(NULL, 100);
    CHECK(n1.IsFailed() && !n1.SkipValue(1) && !n1.Expect('{') && !n1.ReadLiteral(NULL) && !n1.SkipNumber());
    char dummy = 'x';
    CSalUpdJsonReader n2(&dummy, 0);
    CHECK(!n2.IsFailed() && n2.AtEnd() && n2.Peek() == 0 && !n2.SkipValue(1) && n2.IsFailed());
}

static void UnitLoopback()
{
    int port = -1;
    WCHAR path[300];
    CHECK(!SalUpdParseLoopbackUrl(NULL, &port, path, 300));
    CHECK(!SalUpdParseLoopbackUrl(L"http://127.0.0.1:80/x", NULL, path, 300));
    CHECK(!SalUpdParseLoopbackUrl(L"http://127.0.0.1:80/x", &port, NULL, 300));
    CHECK(!SalUpdParseLoopbackUrl(L"http://127.0.0.1:80/x", &port, path, 0));
    CHECK(!SalUpdParseLoopbackUrl(L"http://127.0.0.1:80/x", &port, path, 1));
    CHECK(!SalUpdParseLoopbackUrl(L"http://127.0.0.1:80/x", &port, path, -1));
    CHECK(!SalUpdParseLoopbackUrl(L"http://127.0.0.1:80/x", &port, path, 2));
    CHECK(SalUpdParseLoopbackUrl(L"http://127.0.0.1:80/x", &port, path, 3) && port == 80 && wcscmp(path, L"/x") == 0);
    CHECK(SalUpdParseLoopbackUrl(L"http://127.0.0.1:80/", &port, path, 2) && wcscmp(path, L"/") == 0);
    // every proper prefix of a good URL is refused and is not read past its terminator (guard page)
    static const WCHAR good[] = L"http://127.0.0.1:65535/a/b?c=d&e=%20";
    size_t n = wcslen(good);
    for (size_t cut = 0; cut <= n; cut++)
    {
        WCHAR* u = (WCHAR*)GuardTail(&GIn, (cut + 1) * sizeof(WCHAR));
        memcpy(u, good, cut * sizeof(WCHAR));
        u[cut] = 0;
        BOOL ok = SalUpdParseLoopbackUrl(u, &port, path, 300);
        CHECK(ok == (cut >= 23)); // "http://127.0.0.1:65535/" is the shortest accepted prefix
    }
}

static void UnitTime()
{
    ULONGLONG ft = 0;
    CHECK(SalUpdParseUtcTime("1601-01-01T00:00:00Z", -1, &ft) && ft == 0);
    CHECK(SalUpdParseUtcTime("1601-01-01T00:00:01Z", -1, &ft) && ft == 10000000ULL);
    CHECK(!SalUpdParseUtcTime("1600-12-31T23:59:59Z", -1, &ft));
    CHECK(SalUpdParseUtcTime("9999-12-31T23:59:59Z", -1, &ft) && ft == 2650467743990000000ULL);
    CHECK(SalUpdParseUtcTime("2026-09-20T14:34:53Z", 20, &ft));
    CHECK(!SalUpdParseUtcTime("2026-09-20T14:34:53Z", 19, &ft));
    CHECK(!SalUpdParseUtcTime("2026-09-20T14:34:53Z", 21, &ft));
    CHECK(!SalUpdParseUtcTime("2026-09-20T14:34:53Z", 0, &ft));
    CHECK(SalUpdParseUtcTime("2026-09-20T14:34:53Z", -7, &ft));
    CHECK(SalUpdParseUtcTime("2026-09-20T14:34:53Zgarbage", 20, &ft)); // the length is honoured
    // every day the function can accept (1601..9999), and day numbers 0 and 32, against
    // FileTimeToSystemTime counting forward
    ULONGLONG day = 864000000000ULL;
    ULONGLONG t = 0;
    int accepted = 0;
    for (int y = 1601; y <= 9999; y++)
    {
        for (int m = 1; m <= 12; m++)
        {
            for (int d = 0; d <= 32; d++)
            {
                char s[40];
                sprintf_s(s, sizeof(s), "%04d-%02d-%02dT12:34:56Z", y, m, d);
                ULONGLONG got = 0;
                BOOL ok = SalUpdParseUtcTime(s, -1, &got);
                // reference: is (y, m, d) the calendar date of 't'?
                FILETIME f;
                SYSTEMTIME st;
                f.dwLowDateTime = (DWORD)(t & 0xFFFFFFFFULL);
                f.dwHighDateTime = (DWORD)(t >> 32);
                FileTimeToSystemTime(&f, &st);
                BOOL ref = st.wYear == y && st.wMonth == m && st.wDay == d;
                CHECK(ok == ref);
                if (ok)
                {
                    CHECK(got == t + 12 * SALUPD_HOUR + 34 * 600000000ULL + 56 * 10000000ULL);
                    accepted++;
                    t += day;
                }
            }
        }
    }
    CHECK(accepted == 3067671); // days from 1601-01-01 to 9999-12-31
}

static void StripCheck(const WCHAR* in, const WCHAR* expect)
{
    size_t n = wcslen(in);
    WCHAR* b = (WCHAR*)GuardTail(&GIn, (n + 1) * sizeof(WCHAR));
    memcpy(b, in, (n + 1) * sizeof(WCHAR));
    SalUpdStripWeekday(b);
    Checks++;
    if (wcscmp(b, expect) != 0)
    {
        Failures++;
        wprintf(L"STRIP: \"%s\" -> \"%s\", expected \"%s\"\n", in, b, expect);
    }
}

static void UnitStrip()
{
    SalUpdStripWeekday(NULL);
    StripCheck(L"", L"");
    StripCheck(L"d", L"d");
    StripCheck(L"dd", L"dd");
    StripCheck(L"ddd", L"");
    StripCheck(L"dddd", L"");
    StripCheck(L"dddd, MMMM d, yyyy", L"MMMM d, yyyy");
    StripCheck(L"d MMMM yyyy, dddd", L"d MMMM yyyy");
    StripCheck(L"dddd d MMMM yyyy", L"d MMMM yyyy");
    StripCheck(L"ddd, d MMM", L"d MMM");
    StripCheck(L"'dddd' d", L"'dddd' d");
    StripCheck(L"'day: 'dddd', 'd", L"'day: '', 'd");
    StripCheck(L"d 'de' MMMM, dddd", L"d 'de' MMMM");
    StripCheck(L"dddd,\x00A0" L"d", L"d");
    StripCheck(L"yyyy'x'dddd", L"yyyy'x'");
    StripCheck(L"dddd dddd d", L"d");
    StripCheck(L"d dddd dddd", L"d");
    StripCheck(L"'unterminated dddd", L"'unterminated dddd");
    // random pictures over a small alphabet: never longer, no weekday left outside quotes, quoted text kept
    static const WCHAR alpha[] = L"ddddddMy ,'x.\x00A0";
    for (int it = 0; it < 400000; it++)
    {
        WCHAR src[40];
        int n = (int)(Rnd() % 30);
        for (int i = 0; i < n; i++)
            src[i] = alpha[Rnd() % (_countof(alpha) - 1)];
        src[n] = 0;
        WCHAR* b = (WCHAR*)GuardTail(&GIn, ((size_t)n + 1) * sizeof(WCHAR));
        memcpy(b, src, ((size_t)n + 1) * sizeof(WCHAR));
        SalUpdStripWeekday(b);
        int m = (int)wcslen(b);
        BOOL bad = m > n;
        // no run of 3+ 'd' outside quotes in the result
        BOOL q = FALSE;
        int run = 0;
        for (int i = 0; i < m && !bad; i++)
        {
            if (b[i] == L'\'')
            {
                q = !q;
                run = 0;
                continue;
            }
            if (!q && b[i] == L'd')
            {
                if (++run >= 3)
                    bad = TRUE;
            }
            else
                run = 0;
        }
        // quoted text (with its quotes) and every character other than d, separators survive in order
        WCHAR ka[40], kb[40];
        int na = 0, nb = 0;
        q = FALSE;
        for (int i = 0; i < n; i++)
        {
            if (src[i] == L'\'')
                q = !q;
            if (q || src[i] == L'\'' || (src[i] != L'd' && src[i] != L' ' && src[i] != L',' && src[i] != 0x00A0))
                ka[na++] = src[i];
        }
        q = FALSE;
        for (int i = 0; i < m; i++)
        {
            if (b[i] == L'\'')
                q = !q;
            if (q || b[i] == L'\'' || (b[i] != L'd' && b[i] != L' ' && b[i] != L',' && b[i] != 0x00A0))
                kb[nb++] = b[i];
        }
        if (na != nb || memcmp(ka, kb, (size_t)na * sizeof(WCHAR)) != 0)
            bad = TRUE;
        Checks++;
        if (bad)
        {
            Failures++;
            if (Failures < 30)
                wprintf(L"STRIP property: \"%s\" -> \"%s\"\n", src, b);
        }
    }
}

static int Unit()
{
    UnitVersions();
    UnitDecisions();
    UnitReadStringSizes();
    UnitLoopback();
    UnitTime();
    UnitStrip();
    printf("unit: %d checks, %d failures\n", Checks, Failures);
    return Failures == 0 ? 0 : 1;
}

//
// perf mode: time and stack of the worst inputs, each on a fresh thread
//

struct CPerfJob
{
    const char* Name;
    char* Data;
    size_t Len;
    double Us;
    size_t StackBytes;
    BOOL Ok;
    int Err;
};

static DWORD WINAPI PerfThread(void* param)
{
    CPerfJob* job = (CPerfJob*)param;
    CSalUpdRelease rel;
    CSalUpdParseError err = supeNone;
    double best = 1e30;
    BOOL ok = FALSE;
    for (int i = 0; i < 5; i++)
    {
        double t0 = NowUs();
        ok = SalUpdParseLatestRelease(job->Data, job->Len, &rel, &err);
        double us = NowUs() - t0;
        if (us < best)
            best = us;
    }
    // the grammar alone as well (SkipValue is the recursive part)
    CSalUpdJsonReader r(job->Data, job->Len);
    r.SkipValue(1);
    job->Us = best;
    job->Ok = ok;
    job->Err = (int)err;
    // committed stack = from the base down to the guard page
    ULONG_PTR lo, hi;
    GetCurrentThreadStackLimits(&lo, &hi);
    MEMORY_BASIC_INFORMATION mbi;
    ULONG_PTR p = hi - 1;
    ULONG_PTR lowestCommitted = hi;
    while (p >= lo && VirtualQuery((void*)p, &mbi, sizeof(mbi)) != 0)
    {
        if (mbi.State != MEM_COMMIT || (mbi.Protect & PAGE_GUARD) != 0)
            break;
        lowestCommitted = (ULONG_PTR)mbi.BaseAddress;
        if ((ULONG_PTR)mbi.BaseAddress <= lo)
            break;
        p = (ULONG_PTR)mbi.BaseAddress - 1;
    }
    job->StackBytes = (size_t)(hi - lowestCommitted);
    return 0;
}

static char* Repeat(const char* unit, size_t total, size_t* len)
{
    size_t u = strlen(unit);
    size_t n = total / u;
    char* p = (char*)GuardTail(&GIn, n * u);
    for (size_t i = 0; i < n; i++)
        memcpy(p + i * u, unit, u);
    *len = n * u;
    char* copy = (char*)malloc(n * u);
    memcpy(copy, p, n * u);
    return copy;
}

static char* Build(const char* head, const char* unit, const char* tail, size_t total, size_t* len)
{
    size_t h = strlen(head), u = strlen(unit), t = strlen(tail);
    size_t n = (total - h - t) / u;
    char* p = (char*)malloc(h + n * u + t);
    memcpy(p, head, h);
    for (size_t i = 0; i < n; i++)
        memcpy(p + h + i * u, unit, u);
    memcpy(p + h + n * u, tail, t);
    *len = h + n * u + t;
    return p;
}

static int Perf()
{
    const size_t M = SALUPD_MAX_ANSWER;
    static const char goodHead[] =
        "{\"tag_name\":\"v0.1.9\",\"draft\":false,\"prerelease\":false,\"published_at\":\"2026-10-14T08:00:00Z\","
        "\"html_url\":\"https://github.com/tandemcommander/tandemcommander/releases/tag/v0.1.9\",";
    static const char goodAsset[] =
        "{\"name\":\"tandemcommander-0.1.9-x64-setup.exe\",\"state\":\"uploaded\",\"browser_download_url\":"
        "\"https://github.com/tandemcommander/tandemcommander/releases/download/v0.1.9/tandemcommander-0.1.9-x64-setup.exe\"}";
    CPerfJob jobs[40];
    int n = 0;
    char head[2000], tail[2000];
#define ADD(name, ptr) \
    jobs[n].Name = name; \
    jobs[n].Data = ptr; \
    jobs[n].Len = len; \
    n++;
    size_t len;
    char* p;
    p = Repeat("[", M, &len);
    ADD("256K of [", p);
    p = Repeat("{\"a\":", M, &len);
    ADD("256K of {\"a\":", p);
    p = Build("{\"a\":", "[", "", M, &len);
    ADD("{\"a\": then [ to 256K", p);
    p = Build("{\"a\":\"", "\\ud83d", "\"}", M, &len);
    ADD("string of lone high surrogates", p);
    p = Build("{\"a\":\"", "\\ud83d\\u0041", "\"}", M, &len);
    ADD("string of high surrogate + ordinary escape (re-read path)", p);
    p = Build("{\"a\":\"", "\\ud83d\\udcc1", "\"}", M, &len);
    ADD("string of surrogate pairs", p);
    p = Build("{\"tag_name\":\"", "\\ud83d\\u0041", "\"}", M, &len);
    ADD("the same as tag_name (stored member)", p);
    p = Build("{\"", "\\ud83d\\u0041", "\":1}", M, &len);
    ADD("the same as a member name", p);
    p = Build("", " ", "{}", M, &len);
    ADD("256K of spaces then {}", p);
    p = Build("{", " ", "}", M, &len);
    ADD("{ 256K of spaces }", p);
    p = Build("{\"a\":", "1", "}", M, &len);
    ADD("a 256K-digit number", p);
    p = Build("{\"a\":[", "0,", "0]}", M, &len);
    ADD("array of 131K numbers", p);
    p = Build("{\"a\":[", "[],", "[]]}", M, &len);
    ADD("array of 87K empty arrays", p);
    p = Build("{", "\"a\":0,", "\"a\":0}", M, &len);
    ADD("43K members", p);
    p = Build("{", "\"tag_name\":0,", "\"a\":0}", M, &len);
    ADD("20K duplicate tag_name members", p);
    p = Build("{", "\"assets\":[],", "\"a\":0}", M, &len);
    ADD("23K duplicate assets members", p);
    sprintf_s(head, sizeof(head), "%s\"assets\":[", goodHead);
    sprintf_s(tail, sizeof(tail), "%s]}", goodAsset);
    p = Build(head, "{\"name\":\"x\"},", tail, M, &len);
    ADD("valid record, 20K assets before the installer", p);
    sprintf_s(tail, sizeof(tail), "%s]}", goodAsset);
    {
        char unit[400];
        sprintf_s(unit, sizeof(unit), "%s,", goodAsset);
        p = Build(head, unit, tail, M, &len);
        ADD("valid record, 1.1K copies of the installer asset", p);
    }
    sprintf_s(head, sizeof(head), "%s\"assets\":[%s],\"body\":\"", goodHead, goodAsset);
    p = Build(head, "x", "\"}", M, &len);
    ADD("valid record with a 255K body", p);
    p = Build(head, "\\\"", "\"}", M, &len);
    ADD("valid record, body of escaped quotes", p);
    // depth exactly at the limit, repeated: {"a":[[[...31...]]],"a":[[[...]]],...}
    {
        char unit[200];
        int k = 0;
        unit[k++] = '"';
        unit[k++] = 'a';
        unit[k++] = '"';
        unit[k++] = ':';
        for (int i = 0; i < 31; i++)
            unit[k++] = '[';
        for (int i = 0; i < 31; i++)
            unit[k++] = ']';
        unit[k++] = ',';
        unit[k] = 0;
        p = Build("{", unit, "\"b\":0}", M, &len);
        ADD("3.9K values nested to the limit (32)", p);
    }
#undef ADD
    double worst = 0;
    size_t worstStack = 0;
    for (int i = 0; i < n; i++)
    {
        HANDLE h = CreateThread(NULL, 0, PerfThread, &jobs[i], 0, NULL);
        WaitForSingleObject(h, INFINITE);
        DWORD code = 0;
        GetExitCodeThread(h, &code);
        CloseHandle(h);
        printf("%-58s len %6u  %9.1f us  stack %6u B  ok %d err %d%s\n", jobs[i].Name, (unsigned)jobs[i].Len, jobs[i].Us,
               (unsigned)jobs[i].StackBytes, jobs[i].Ok, jobs[i].Err, code != 0 ? "  THREAD DIED" : "");
        if (jobs[i].Us > worst)
            worst = jobs[i].Us;
        if (jobs[i].StackBytes > worstStack)
            worstStack = jobs[i].StackBytes;
        if (code != 0)
            Failures++;
    }
    printf("perf: worst time %.1f us, worst committed stack %u bytes (thread start included), failures %d\n", worst,
           (unsigned)worstStack, Failures);
    return Failures == 0 ? 0 : 1;
}

//
// locales mode: the real long-date pictures of this Windows
//

static int LocaleCount = 0, LocaleOdd = 0;

static BOOL CALLBACK LocaleProc(LPWSTR name, DWORD, LPARAM)
{
    WCHAR pic[200], orig[200];
    if (GetLocaleInfoEx(name, LOCALE_SLONGDATE, pic, _countof(pic)) == 0)
        return TRUE;
    wcscpy_s(orig, _countof(orig), pic);
    SalUpdStripWeekday(pic);
    LocaleCount++;
    SYSTEMTIME st;
    memset(&st, 0, sizeof(st));
    st.wYear = 2026;
    st.wMonth = 10;
    st.wDay = 14; // a Wednesday
    WCHAR text[300], full[300], dayName[100], dayAbbr[100];
    text[0] = 0;
    full[0] = 0;
    int ok = GetDateFormatEx(name, 0, &st, pic, text, _countof(text), NULL);
    GetDateFormatEx(name, 0, &st, orig, full, _countof(full), NULL);
    GetDateFormatEx(name, 0, &st, L"dddd", dayName, _countof(dayName), NULL);
    GetDateFormatEx(name, 0, &st, L"ddd", dayAbbr, _countof(dayAbbr), NULL);
    const WCHAR* why = NULL;
    size_t n = wcslen(text);
    if (ok == 0 || n == 0)
        why = L"empty result";
    else if (text[0] == L' ' || text[0] == L',' || text[0] == 0x00A0 || text[n - 1] == L' ' || text[n - 1] == L',' || text[n - 1] == 0x00A0)
        why = L"separator left hanging";
    else if (wcsstr(orig, L"ddd") != NULL && dayName[0] != 0 && wcsstr(text, dayName) != NULL)
        why = L"weekday name still shown";
    else if (wcsstr(pic, L"ddd") != NULL)
        why = L"ddd left in the picture";
    if (why != NULL)
    {
        LocaleOdd++;
        wprintf(L"ODD %-14s %s: \"%s\" -> \"%s\" => \"%s\" (full \"%s\")\n", name, why, orig, pic, text, full);
    }
    return TRUE;
}

static int Locales()
{
    EnumSystemLocalesEx(LocaleProc, LOCALE_ALL, 0, NULL);
    printf("locales: %d pictures, %d odd results\n", LocaleCount, LocaleOdd);
    return 0;
}

int main(int argc, char** argv)
{
    LARGE_INTEGER f;
    QueryPerformanceFrequency(&f);
    QpcFreq = (double)f.QuadPart;
    GuardInit(&GIn, 2 * 1024 * 1024);
    GuardInit(&GOut, 64 * 1024);
    if (argc == 4 && strcmp(argv[1], "batch") == 0)
        return Batch(argv[2], argv[3]);
    if (argc == 2 && strcmp(argv[1], "unit") == 0)
        return Unit();
    if (argc == 2 && strcmp(argv[1], "perf") == 0)
        return Perf();
    if (argc == 2 && strcmp(argv[1], "locales") == 0)
        return Locales();
    printf("usage: adv_harness batch <cases.bin> <verdicts.txt> | unit | perf | locales\n");
    return 2;
}
