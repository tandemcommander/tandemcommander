// Feature 117: an offline model of the Checksum plug-in's Verify read path, built on the
// product's own rules (src/common/salcsumlist.h) - decode the list, parse each line the way
// the plug-in does (hash first with an optional '*', the BSD tag form, SFV; GNU escape), build
// the path, look it up without wildcards, hash the file (BCrypt / CRC-32) and print one verdict
// per line. It is NOT the plug-in (that needs the GUI probe) - it checks the fixtures'
// expectations against the helper on real files. Build: build_model.cmd; run: m117_model.exe <list>...
#define WIN32_LEAN_AND_MEAN
#define _CRT_SECURE_NO_WARNINGS
#include <windows.h>
#include <bcrypt.h>
#include <stdio.h>
#include <string>
#include <vector>
#include "../../../src/plugins/shared/splunicode.h"
#include "../../../src/common/salcsumlist.h"
#pragma comment(lib, "bcrypt.lib")

static bool IsHexRun(const char* s, size_t n)
{
    for (size_t i = 0; i < n; i++)
        if (!isxdigit((unsigned char)s[i]))
            return false;
    return true;
}

static std::string HashFile(const wchar_t* path, int kind) // kind: 0 crc, 1 md5, 2 sha1, 3 sha256
{
    HANDLE h = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
    if (h == INVALID_HANDLE_VALUE)
        return "<open failed>";
    std::vector<unsigned char> buf;
    unsigned char tmp[65536];
    DWORD n;
    while (ReadFile(h, tmp, sizeof(tmp), &n, NULL) && n > 0)
        buf.insert(buf.end(), tmp, tmp + n);
    CloseHandle(h);
    char hex[200];
    hex[0] = 0;
    if (kind == 0)
    {
        DWORD crc = 0xFFFFFFFF;
        for (unsigned char c : buf)
        {
            crc ^= c;
            for (int k = 0; k < 8; k++)
                crc = (crc >> 1) ^ (0xEDB88320 & (0 - (crc & 1)));
        }
        sprintf_s(hex, "%08x", ~crc);
        return hex;
    }
    const wchar_t* alg = kind == 1 ? BCRYPT_MD5_ALGORITHM : kind == 2 ? BCRYPT_SHA1_ALGORITHM : BCRYPT_SHA256_ALGORITHM;
    BCRYPT_ALG_HANDLE a;
    BCryptOpenAlgorithmProvider(&a, alg, NULL, 0);
    DWORD len = 0, got;
    BCryptGetProperty(a, BCRYPT_HASH_LENGTH, (PUCHAR)&len, sizeof(len), &got, 0);
    unsigned char d[64];
    BCryptHash(a, NULL, 0, buf.empty() ? NULL : buf.data(), (ULONG)buf.size(), d, len);
    BCryptCloseAlgorithmProvider(a, 0);
    for (DWORD i = 0; i < len; i++)
        sprintf_s(hex + 2 * i, sizeof(hex) - 2 * i, "%02x", d[i]);
    return hex;
}

int wmain(int argc, wchar_t** argv)
{
    for (int a = 1; a < argc; a++)
    {
        HANDLE h = CreateFileW(argv[a], GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
        if (h == INVALID_HANDLE_VALUE)
            continue;
        std::vector<unsigned char> raw(GetFileSize(h, NULL));
        DWORD n = 0;
        if (!raw.empty())
            ReadFile(h, raw.data(), (DWORD)raw.size(), &n, NULL);
        CloseHandle(h);
        SalCslEncoding enc;
        size_t bad;
        char* text = SalCslDecode(raw.data(), raw.size(), CP_ACP, &enc, &bad);
        // the list's folder, as UTF-8
        wchar_t full[2048];
        GetFullPathNameW(argv[a], 2048, full, NULL);
        wchar_t* slash = wcsrchr(full, L'\\');
        *slash = 0;
        char dir[4096];
        WideCharToMultiByte(CP_UTF8, 0, full, -1, dir, sizeof(dir), NULL, NULL);
        const wchar_t* ext = wcsrchr(argv[a], L'.');
        int kind = !_wcsicmp(ext, L".sfv") ? 0 : !_wcsicmp(ext, L".md5") ? 1 : !_wcsicmp(ext, L".sha1") ? 2 : 3;
        size_t hlen = kind == 1 ? 32 : kind == 2 ? 40 : 64;
        printf("LIST %ls enc=%d bad=%d\n", slash + 1, (int)enc, (int)bad);
        for (char* line = strtok(text, "\r\n"); line != NULL; line = strtok(NULL, "\r\n"))
        {
            while (*line != 0 && (unsigned char)*line <= ' ')
                line++;
            if (*line == 0 || *line == ';' || *line == '#')
                continue;
            std::string name, want;
            if (kind == 0)
            {
                std::string l = line;
                while (!l.empty() && (unsigned char)l.back() <= ' ')
                    l.pop_back();
                size_t sp = l.find_last_of(" \t");
                want = l.substr(sp + 1);
                name = l.substr(0, sp);
                while (!name.empty() && (name.back() == ' ' || name.back() == '\t'))
                    name.pop_back();
            }
            else
            {
                bool esc = (*line == '\\');
                const char* g = esc ? line + 1 : line;
                if (strlen(g) > hlen && IsHexRun(g, hlen))
                {
                    want.assign(g, hlen);
                    const char* p = g + hlen;
                    while (*p == ' ' || *p == '\t')
                        p++;
                    if (*p == '*')
                        p++;
                    name = p;
                }
                else // "ALG (name) = hash"
                {
                    const char* o = strchr(g, '(');
                    const char* c = strrchr(g, ')');
                    const char* e = strrchr(g, '=');
                    name.assign(o + 1, c - o - 1);
                    want = e + 1;
                    want.erase(0, want.find_first_not_of(" \t"));
                }
                if (esc)
                {
                    std::vector<char> b(name.begin(), name.end());
                    b.push_back(0);
                    SalCslUnescapeName(b.data());
                    name = b.data();
                }
            }
            for (char& c : name)
                if (c == '/')
                    c = '\\';
            for (char& c : want)
                c = (char)tolower((unsigned char)c);
            char path[3 * MAX_PATH];
            const char* verdict = "MISSING";
            std::string got;
            if (SalCslBuildPath(dir, name.c_str(), path, sizeof(path)) == SAL_CSL_PATH_OK && SalCslNameUsable(name.c_str()))
            {
                WCHAR* w = SplU8ToWExtAlloc(path);
                WIN32_FILE_ATTRIBUTE_DATA fad;
                if (w != NULL && GetFileAttributesExW(w, GetFileExInfoStandard, &fad) && !(fad.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY))
                {
                    got = HashFile(w, kind);
                    verdict = got == want ? "OK" : "CORRUPT";
                }
                free(w);
            }
            // the name as UTF-16 code units in hex (stdout stays ASCII)
            printf("ROW %s ", verdict);
            WCHAR wn[1024];
            std::string shown = name;
            for (size_t i = 0; i < shown.size(); i++)
                if ((unsigned char)shown[i] == SAL_CSL_BADCHAR)
                    shown.replace(i, 1, "\xEF\xBF\xBD");
            int wl = SplU8ToW(shown.c_str(), wn, 1024);
            for (int i = 0; i + 1 < wl; i++)
                printf("%04X", wn[i]);
            printf("\n");
        }
        free(text);
    }
    return 0;
}
