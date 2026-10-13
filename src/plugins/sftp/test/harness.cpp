// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later
//
// Dev-only unit test harness for the SFTP plugin's pure-logic helpers.
// Not shipped, not part of salamand.sln / plugins.cfg. Build & run:
//   see test\build_and_run.cmd  (compiles sftputils.cpp standalone).
// Exits non-zero on the first failed assertion.

#include <winsock2.h>
#include <windows.h>
#include <stdio.h>
#include "sftputils.h"
#include "keyload.h"

static int g_fail = 0;
static int g_pass = 0;

#define CHECK(cond) \
    do \
    { \
        if (cond) \
        { \
            g_pass++; \
        } \
        else \
        { \
            g_fail++; \
            printf("FAIL: %s (line %d)\n", #cond, __LINE__); \
        } \
    } while (0)

#define CHECK_STR(a, b) \
    do \
    { \
        if (strcmp((a), (b)) == 0) \
        { \
            g_pass++; \
        } \
        else \
        { \
            g_fail++; \
            printf("FAIL: \"%s\" != \"%s\" (line %d)\n", (a), (b), __LINE__); \
        } \
    } while (0)

static void TestRights()
{
    char buf[16];
    CHECK_STR(FormatUnixRights(SFTP_S_IFDIR | 0755, buf), "drwxr-xr-x");
    CHECK_STR(FormatUnixRights(SFTP_S_IFREG | 0644, buf), "-rw-r--r--");
    CHECK_STR(FormatUnixRights(SFTP_S_IFLNK | 0777, buf), "lrwxrwxrwx");
    CHECK_STR(FormatUnixRights(SFTP_S_IFREG | SFTP_S_ISUID | 0755, buf), "-rwsr-xr-x");
    CHECK_STR(FormatUnixRights(SFTP_S_IFDIR | SFTP_S_ISVTX | 0777, buf), "drwxrwxrwt");
    // setgid without group-execute -> capital S
    CHECK_STR(FormatUnixRights(SFTP_S_IFREG | SFTP_S_ISGID | 0644, buf), "-rw-r-Sr--");
    // sticky without other-execute -> capital T
    CHECK_STR(FormatUnixRights(SFTP_S_IFDIR | SFTP_S_ISVTX | 0770, buf), "drwxrwx--T");
    // block/char/fifo/socket type chars
    CHECK_STR(FormatUnixRights(SFTP_S_IFBLK | 0660, buf), "brw-rw----");
    CHECK_STR(FormatUnixRights(SFTP_S_IFCHR | 0666, buf), "crw-rw-rw-");
    // permission-only mode (server omitted the type bits) -> regular-file dash
    CHECK_STR(FormatUnixRights(0644, buf), "-rw-r--r--");
}

static void TestOctal()
{
    char buf[8];
    CHECK_STR(FormatOctalMode(0755, buf), "0755");
    CHECK_STR(FormatOctalMode(SFTP_S_ISUID | 0755, buf), "4755");
    CHECK_STR(FormatOctalMode(SFTP_S_IFREG | 0644, buf), "0644"); // type bits masked off

    unsigned long m = 0;
    CHECK(ParseOctalMode("755", &m) && m == 0755);
    CHECK(ParseOctalMode("0644", &m) && m == 0644);
    CHECK(ParseOctalMode("4755", &m) && m == (unsigned long)(SFTP_S_ISUID | 0755));
    CHECK(ParseOctalMode("  700  ", &m) && m == 0700);
    CHECK(!ParseOctalMode("abc", &m));
    CHECK(!ParseOctalMode("789", &m)); // 8,9 not octal
    CHECK(!ParseOctalMode("", &m));
}

static void TestUtf8()
{
    CHECK(IsValidUTF8("hello", 5));
    CHECK(IsValidUTF8("\xC3\xA9", 2));     // e-acute
    CHECK(IsValidUTF8("\xE6\x97\xA5", 3)); // CJK
    CHECK(!IsValidUTF8("\xFF", 1));        // invalid lead byte
    CHECK(!IsValidUTF8("\xC3", 1));        // truncated 2-byte
    CHECK(!IsValidUTF8("\xC0\x80", 2));    // overlong NUL

    char buf[64];
    CHECK_STR(SanitizeUTF8("clean", buf, sizeof(buf)), "clean");
    CHECK_STR(SanitizeUTF8("\xC3\xA9.txt", buf, sizeof(buf)), "\xC3\xA9.txt"); // valid preserved
    // invalid byte becomes a single '?'
    SanitizeUTF8("a\xFF"
                 "b",
                 buf, sizeof(buf));
    CHECK_STR(buf, "a?b");
}

static void TestPaths()
{
    char buf[256];
    CHECK_STR(PosixPathAppend("/home/user", "file.txt", buf, sizeof(buf)), "/home/user/file.txt");
    CHECK_STR(PosixPathAppend("/", "etc", buf, sizeof(buf)), "/etc");
    CHECK_STR(PosixPathAppend("/a/", "b", buf, sizeof(buf)), "/a/b");
    CHECK_STR(PosixPathAppend("", "x", buf, sizeof(buf)), "/x");

    // feature 131: a result that does not fit is refused (NULL, empty buffer), never cut
    char tiny[8];
    CHECK(PosixPathAppend("/abc", "de", tiny, sizeof(tiny)) != NULL && strcmp(tiny, "/abc/de") == 0); // 7 + NUL: fits exactly
    tiny[0] = 'z';
    CHECK(PosixPathAppend("/abc", "def", tiny, sizeof(tiny)) == NULL && tiny[0] == 0); // one byte too long
    CHECK(PosixPathAppend("/", "1234567", tiny, sizeof(tiny)) == NULL && tiny[0] == 0);
    CHECK(PosixPathAppend("/", "123456", tiny, sizeof(tiny)) != NULL && strcmp(tiny, "/123456") == 0);
    CHECK(PosixPathAppend("/abcde/", "f", tiny, sizeof(tiny)) == NULL); // the slash is not doubled, still too long
    CHECK(PosixPathAppend("/abcd/", "f", tiny, sizeof(tiny)) != NULL && strcmp(tiny, "/abcd/f") == 0);
    CHECK(PosixPathAppend("/a", "b", tiny, 0) == NULL);

    CHECK(LocalPathAppend("C:\\a", "b", tiny, sizeof(tiny)) && strcmp(tiny, "C:\\a\\b") == 0);
    CHECK(LocalPathAppend("C:\\", "abcd", tiny, sizeof(tiny)) && strcmp(tiny, "C:\\abcd") == 0); // no doubled backslash
    CHECK(LocalPathAppend("C:\\ab", "*", tiny, sizeof(tiny)) && strcmp(tiny, "C:\\ab\\*") == 0);
    tiny[0] = 'z';
    CHECK(!LocalPathAppend("C:\\abc", "*", tiny, sizeof(tiny)) && tiny[0] == 0); // the mask would be cut off
    CHECK(!LocalPathAppend("C:\\a", "bcd", tiny, sizeof(tiny)) && tiny[0] == 0);
    CHECK(!LocalPathAppend("C:\\a", "b", tiny, 0));

    CHECK_STR(SftpStatusName(2), "No such file");
    CHECK_STR(SftpStatusName(3), "Permission denied");
    CHECK_STR(SftpStatusName(4), "Failure");
    CHECK_STR(SftpStatusName(21), "Link loop");
    CHECK_STR(SftpStatusName(22), "Unknown status");
    CHECK_STR(SftpStatusName(0xFFFFFFFFUL), "Unknown status");

    // feature 138: the source of a moved file is removed only on facts
    CHECK(SftpMoveMayRemove(TRUE, TRUE, 1234, TRUE, 1234));
    CHECK(SftpMoveMayRemove(TRUE, TRUE, 0, TRUE, 0)); // an empty file is complete
    CHECK(!SftpMoveMayRemove(FALSE, TRUE, 1234, TRUE, 1234)); // the transfer failed or was skipped
    CHECK(!SftpMoveMayRemove(TRUE, FALSE, 1234, TRUE, 1234)); // the local file cannot be read
    CHECK(!SftpMoveMayRemove(TRUE, TRUE, 1234, FALSE, 1234)); // the server does not say the size
    CHECK(!SftpMoveMayRemove(TRUE, TRUE, 1233, TRUE, 1234));  // the copy is shorter
    CHECK(!SftpMoveMayRemove(TRUE, TRUE, 1235, TRUE, 1234));  // ... or longer (the source changed)
    CHECK(!SftpMoveMayRemove(TRUE, TRUE, 0x100000000ull, TRUE, 0)); // no 32-bit comparison
    CHECK(SftpMoveMayRemove(TRUE, TRUE, 0x1FFFFFFFFull, TRUE, 0x1FFFFFFFFull));
    CHECK(!SftpMoveMayRemove(TRUE, FALSE, 0, FALSE, 0));

    // feature 139: the temporary name of an upload - in the target's own directory, never cut
    {
        char t[64];
        CHECK(SftpTempPath("/a/b.txt", 0x1A2B3C4DUL, t, sizeof(t)));
        CHECK_STR(t, "/a/.tcpart-1a2b3c4d");
        CHECK(SftpTempPath("/b.txt", 0UL, t, sizeof(t))); // the root
        CHECK_STR(t, "/.tcpart-00000000");
        CHECK(SftpTempPath("b.txt", 0xFFFFFFFFUL, t, sizeof(t))); // no directory part
        CHECK_STR(t, ".tcpart-ffffffff");
        CHECK(SftpTempPath("/a/", 0xABCDEF01UL, t, sizeof(t))); // an empty last component
        CHECK_STR(t, "/a/.tcpart-abcdef01");
        CHECK(SftpTempPath("/dir.with.dots/x", 7UL, t, sizeof(t)));
        CHECK_STR(t, "/dir.with.dots/.tcpart-00000007");
        // the name does not depend on the target's name (a 255-byte name stays within the limit)
        char longName[3 + 255 + 1];
        memcpy(longName, "/d/", 3);
        memset(longName + 3, 'n', 255);
        longName[sizeof(longName) - 1] = 0;
        CHECK(SftpTempPath(longName, 0x12345678UL, t, sizeof(t)));
        CHECK_STR(t, "/d/.tcpart-12345678");
        char fit[20]; // "/a/" + 16 + NUL = 20: fits exactly
        CHECK(SftpTempPath("/a/b.txt", 0x00C0FFEEUL, fit, sizeof(fit)));
        CHECK_STR(fit, "/a/.tcpart-00c0ffee");
        fit[0] = 'z';
        CHECK(!SftpTempPath("/ab/b.txt", 1UL, fit, sizeof(fit)) && fit[0] == 0); // one byte over
        fit[0] = 'z';
        CHECK(!SftpTempPath("/a/b.txt", 1UL, fit, 19) && fit[0] == 0);
        CHECK(!SftpTempPath("b", 1UL, fit, 16) && fit[0] == 0); // no room for the terminator
        CHECK(SftpTempPath("b", 1UL, fit, 17) && strcmp(fit, ".tcpart-00000001") == 0);
        CHECK(!SftpTempPath("/a/b", 1UL, fit, 0));
        CHECK(!SftpTempPath("/a/b", 1UL, NULL, 20));
        fit[0] = 'z';
        CHECK(!SftpTempPath(NULL, 1UL, fit, sizeof(fit)) && fit[0] == 0);
    }
    // feature 139: an upload is complete only on facts
    CHECK(SftpUploadConfirmed(TRUE, 1234, 1234, 1234));
    CHECK(SftpUploadConfirmed(TRUE, 0, 0, 0)); // an empty file is complete
    CHECK(!SftpUploadConfirmed(FALSE, 1234, 1234, 1234)); // the server does not say the size
    CHECK(!SftpUploadConfirmed(TRUE, 1233, 1234, 1234));  // the server holds less than was sent
    CHECK(!SftpUploadConfirmed(TRUE, 1235, 1234, 1234));  // ... or more
    CHECK(!SftpUploadConfirmed(TRUE, 1000, 1000, 1234));  // not the whole local file was sent
    CHECK(!SftpUploadConfirmed(TRUE, 1234, 1234, 1000));  // the local file changed
    CHECK(!SftpUploadConfirmed(TRUE, 0, 0x100000000ull, 0x100000000ull)); // no 32-bit comparison
    CHECK(SftpUploadConfirmed(TRUE, 0x1FFFFFFFFull, 0x1FFFFFFFFull, 0x1FFFFFFFFull));
    CHECK(!SftpUploadConfirmed(FALSE, 0, 0, 0));
    // feature 139 (review): only "no such file / path" frees a name
    CHECK(SftpStatusIsNotFound(2) && SftpStatusIsNotFound(10));
    CHECK(!SftpStatusIsNotFound(0) && !SftpStatusIsNotFound(3) && !SftpStatusIsNotFound(4) && !SftpStatusIsNotFound(7) &&
          !SftpStatusIsNotFound(11));
    CHECK(SftpStatusIsPermission(3) && SftpStatusIsPermission(12));
    CHECK(!SftpStatusIsPermission(0) && !SftpStatusIsPermission(4) && !SftpStatusIsPermission(8) && !SftpStatusIsPermission(14));
    // feature 139 (review): in place only when the server said "no right" on a live session
    CHECK(SftpTempOpenFailureNext(TRUE, 3) == tonInPlace);  // permission denied
    CHECK(SftpTempOpenFailureNext(TRUE, 12) == tonInPlace); // write protected
    CHECK(SftpTempOpenFailureNext(TRUE, 8) == tonInPlace);  // no exclusive create
    CHECK(SftpTempOpenFailureNext(TRUE, 4) == tonRetryName);
    CHECK(SftpTempOpenFailureNext(TRUE, 11) == tonRetryName);
    CHECK(SftpTempOpenFailureNext(TRUE, 0) == tonFail);  // no status: timeout, transport
    CHECK(SftpTempOpenFailureNext(TRUE, 14) == tonFail); // no space
    CHECK(SftpTempOpenFailureNext(TRUE, 15) == tonFail); // quota
    CHECK(SftpTempOpenFailureNext(TRUE, 7) == tonFail);  // connection lost
    CHECK(SftpTempOpenFailureNext(TRUE, 2) == tonFail);  // the directory is gone
    CHECK(SftpTempOpenFailureNext(FALSE, 3) == tonFail && SftpTempOpenFailureNext(FALSE, 4) == tonFail &&
          SftpTempOpenFailureNext(FALSE, 8) == tonFail && SftpTempOpenFailureNext(FALSE, 0) == tonFail);
    // feature 139 (review): the replaced file's owner and group
    CHECK(!SftpOwnerDiffers(TRUE, 1000, 100, TRUE, 1000, 100));
    CHECK(SftpOwnerDiffers(TRUE, 1000, 100, TRUE, 1001, 100));
    CHECK(SftpOwnerDiffers(TRUE, 1000, 100, TRUE, 1000, 33));
    CHECK(SftpOwnerDiffers(TRUE, 0, 0, TRUE, 1000, 1000));
    CHECK(!SftpOwnerDiffers(FALSE, 1, 2, TRUE, 3, 4) && !SftpOwnerDiffers(TRUE, 1, 2, FALSE, 3, 4) &&
          !SftpOwnerDiffers(FALSE, 1, 2, FALSE, 3, 4)); // not reported: not a difference
    // feature 139 (second review): a chmod is sent only when the bits differ
    CHECK(!SftpModeDiffers(TRUE, SFTP_S_IFREG | 0640, TRUE, SFTP_S_IFREG | 0640));
    CHECK(!SftpModeDiffers(TRUE, SFTP_S_IFREG | 0640, TRUE, 0640)); // the type bits do not count
    CHECK(SftpModeDiffers(TRUE, SFTP_S_IFREG | 0640, TRUE, SFTP_S_IFREG | 0600)); // the umask took a bit
    CHECK(SftpModeDiffers(TRUE, SFTP_S_IFREG | SFTP_S_ISVTX | 0644, TRUE, SFTP_S_IFREG | 0644)); // a special bit
    CHECK(SftpModeDiffers(TRUE, 0644, FALSE, 0644));  // not reported for the new file: set them
    CHECK(!SftpModeDiffers(FALSE, 0600, TRUE, 0644)); // nothing known to keep
    CHECK(!SftpModeDiffers(FALSE, 0600, FALSE, 0));
    // feature 139: only links to another place are skipped by an upload
    CHECK(SftpLocalDirIsLink(FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT, IO_REPARSE_TAG_MOUNT_POINT)); // junction, mounted volume
    CHECK(SftpLocalDirIsLink(FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT, IO_REPARSE_TAG_SYMLINK));
    CHECK(SftpLocalDirIsLink(FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT, 0xA000001DUL));  // a WSL symbolic link
    CHECK(!SftpLocalDirIsLink(FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT, 0x9000001AUL)); // cloud files (OneDrive)
    CHECK(!SftpLocalDirIsLink(FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT, 0x9000701AUL)); // cloud files, another variant
    CHECK(!SftpLocalDirIsLink(FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT, 0x80000013UL)); // deduplication
    CHECK(!SftpLocalDirIsLink(FILE_ATTRIBUTE_DIRECTORY, IO_REPARSE_TAG_MOUNT_POINT)); // no reparse point: the tag field means nothing
    CHECK(!SftpLocalDirIsLink(FILE_ATTRIBUTE_DIRECTORY, 0));
    CHECK(!SftpLocalDirIsLink(INVALID_FILE_ATTRIBUTES, IO_REPARSE_TAG_SYMLINK)); // attributes not read
    CHECK((SftpLocalDirIsLink(FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT, IO_REPARSE_TAG_SYMLINK) != FALSE) ==
          (IsReparseTagNameSurrogate(IO_REPARSE_TAG_SYMLINK) != 0)); // the system's own test agrees

    // feature 133: only "end" completes a listing
    CHECK(SftpReadDirStep(1) == rdsEntry && SftpReadDirStep(255) == rdsEntry && SftpReadDirStep(2047) == rdsEntry);
    CHECK(SftpReadDirStep(0) == rdsEnd);
    CHECK(SftpReadDirStep(-38) == rdsError); // LIBSSH2_ERROR_BUFFER_TOO_SMALL: a name over the buffer
    CHECK(SftpReadDirStep(-30) == rdsError); // LIBSSH2_ERROR_SOCKET_TIMEOUT
    CHECK(SftpReadDirStep(-31) == rdsError); // LIBSSH2_ERROR_SFTP_PROTOCOL
    CHECK(SftpReadDirStep(-37) == rdsError); // LIBSSH2_ERROR_EAGAIN is not an end either
    CHECK(SftpReadDirStep(-2147483647 - 1) == rdsError);
    // feature 133: a message is never cut - the reason behind a long path stays
    {
        char* m = SftpFormatMsgAlloc("Cannot remove directory \"%s\": %s", "/a/b", "Permission denied.");
        CHECK(m != NULL);
        CHECK_STR(m, "Cannot remove directory \"/a/b\": Permission denied.");
        free(m);
        char longPath[4096];
        memset(longPath, 'e', sizeof(longPath) - 1);
        longPath[0] = '/';
        longPath[sizeof(longPath) - 1] = 0;
        m = SftpFormatMsgAlloc("Cannot remove directory \"%s\": %s", longPath, "SFTP error 4: Failure");
        CHECK(m != NULL && strlen(m) == strlen("Cannot remove directory \"\": ") + 4095 + strlen("SFTP error 4: Failure"));
        CHECK(m != NULL && strcmp(m + strlen(m) - 21, "SFTP error 4: Failure") == 0);
        CHECK(m != NULL && strncmp(m, "Cannot remove directory \"/eee", 29) == 0);
        free(m);
        m = SftpFormatMsgAlloc("Cannot open \"%s\".", "C:\\x", NULL); // one insert, no second text
        CHECK(m != NULL);
        CHECK_STR(m, "Cannot open \"C:\\x\".");
        free(m);
        m = SftpFormatMsgAlloc("%s%s", NULL, NULL);
        CHECK(m != NULL && m[0] == 0);
        free(m);
        CHECK(SftpFormatMsgAlloc(NULL, "a", "b") == NULL);
    }

    CHECK_STR(PosixBaseName("/home/user/file.txt"), "file.txt");
    CHECK_STR(PosixBaseName("/"), "");
    CHECK_STR(PosixBaseName("noslash"), "noslash");
    CHECK(IsDotOrDotDot(".") && IsDotOrDotDot("..") && !IsDotOrDotDot(".hidden"));
}

static void TestTime()
{
    // round-trip a known instant
    __int64 t = 1700000000; // 2023-11-14T22:13:20Z
    FILETIME ft;
    UnixTimeToFileTime(t, &ft);
    __int64 back = FileTimeToUnixTime(&ft);
    CHECK(back == t);

    CHECK(UnixTypeChar(SFTP_S_IFDIR | 0755) == 'd');
    CHECK(UnixTypeChar(SFTP_S_IFLNK) == 'l');
    CHECK(UnixTypeChar(SFTP_S_IFREG) == '-');
}

static void TestAttrs()
{
    // read-only synthesized when owner lacks write
    DWORD a = SynthesizeWinAttributes(SFTP_S_IFREG | 0444, "file");
    CHECK((a & FILE_ATTRIBUTE_READONLY) != 0);
    a = SynthesizeWinAttributes(SFTP_S_IFREG | 0644, "file");
    CHECK((a & FILE_ATTRIBUTE_READONLY) == 0);
    // dotfile hidden
    a = SynthesizeWinAttributes(SFTP_S_IFREG | 0644, ".bashrc");
    CHECK((a & FILE_ATTRIBUTE_HIDDEN) != 0);
    // directory bit
    a = SynthesizeWinAttributes(SFTP_S_IFDIR | 0755, "d");
    CHECK((a & FILE_ATTRIBUTE_DIRECTORY) != 0);
}

// feature 051: key-format detection and the capability gate. These fixtures are
// the cheap half of the regression net around the freeze - key_auth.c covers the
// live half. A wrong verdict here is what routed an OpenSSH-container key into
// libssh2's classic-PEM parser in the first place.
static const char* WriteFixture(const char* leaf, const char* content)
{
    static char path[MAX_PATH];
    char tmp[MAX_PATH];
    GetTempPathA(sizeof(tmp), tmp);
    _snprintf_s(path, sizeof(path), _TRUNCATE, "%s%s", tmp, leaf);
    HANDLE h = CreateFileA(path, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (h == INVALID_HANDLE_VALUE)
        return path;
    DWORD w = 0;
    WriteFile(h, content, (DWORD)strlen(content), &w, NULL);
    CloseHandle(h);
    return path;
}

static void TestKeyFormats()
{
    const char* p;
    int reason = 0;

    p = WriteFixture("tc_fx_rsa.pem",
                     "-----BEGIN RSA PRIVATE KEY-----\nMIIB\n-----END RSA PRIVATE KEY-----\n");
    CHECK(DetectKeyFormat(p) == kfPEM);
    CHECK(KeyFormatSupported(kfPEM, &reason));
    CHECK(!KeyFileLooksEncrypted(p));
    DeleteFileA(p);

    p = WriteFixture("tc_fx_rsa_enc.pem",
                     "-----BEGIN RSA PRIVATE KEY-----\nProc-Type: 4,ENCRYPTED\n"
                     "DEK-Info: AES-128-CBC,0102030405060708090A0B0C0D0E0F10\n\nMIIB\n"
                     "-----END RSA PRIVATE KEY-----\n");
    CHECK(DetectKeyFormat(p) == kfPEM);
    CHECK(KeyFileLooksEncrypted(p)); // classic PEM markers
    DeleteFileA(p);

    p = WriteFixture("tc_fx_pkcs8.pem",
                     "-----BEGIN PRIVATE KEY-----\nMIIB\n-----END PRIVATE KEY-----\n");
    CHECK(DetectKeyFormat(p) == kfPKCS8);
    reason = 0;
    CHECK(!KeyFormatSupported(kfPKCS8, &reason)); // no PKCS#8 path in WinCNG
    CHECK(reason != 0);
    DeleteFileA(p);

    p = WriteFixture("tc_fx.ppk", "PuTTY-User-Key-File-3: ssh-rsa\nEncryption: none\n");
    CHECK(DetectKeyFormat(p) == kfPuTTY);
    reason = 0;
    CHECK(!KeyFormatSupported(kfPuTTY, &reason));
    CHECK(reason != 0);
    DeleteFileA(p);

    p = WriteFixture("tc_fx_unknown.txt", "hello, not a key at all\n");
    CHECK(DetectKeyFormat(p) == kfUnknown);
    CHECK(!KeyFormatSupported(kfUnknown, &reason));
    DeleteFileA(p);

    CHECK(DetectKeyFormat("Z:\\no\\such\\file.key") == kfUnknown);

    // OpenSSH container: base64 of "openssh-key-v1\0" + string "none" (cipher) +
    // string "none" (kdf) + string "" (kdfoptions) + u32 1 + pubkey blob whose
    // first field is the algorithm name. Built here for "ssh-ed25519", the type
    // that must be rejected up front (WinCNG has no ed25519).
    {
        unsigned char raw[128];
        int n = 0;
        memcpy(raw + n, "openssh-key-v1", 15);
        n += 15; // includes the NUL
        const char* fields[] = {"none", "none", ""};
        for (int i = 0; i < 3; i++)
        {
            int len = (int)strlen(fields[i]);
            raw[n++] = 0;
            raw[n++] = 0;
            raw[n++] = 0;
            raw[n++] = (unsigned char)len;
            memcpy(raw + n, fields[i], len);
            n += len;
        }
        raw[n++] = 0;
        raw[n++] = 0;
        raw[n++] = 0;
        raw[n++] = 1; // one key
        const char* type = "ssh-ed25519";
        int tlen = (int)strlen(type);
        int blobLen = 4 + tlen;
        raw[n++] = 0;
        raw[n++] = 0;
        raw[n++] = 0;
        raw[n++] = (unsigned char)blobLen;
        raw[n++] = 0;
        raw[n++] = 0;
        raw[n++] = 0;
        raw[n++] = (unsigned char)tlen;
        memcpy(raw + n, type, tlen);
        n += tlen;

        DWORD b64len = 0;
        CryptBinaryToStringA(raw, n, CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF, NULL, &b64len);
        char* b64 = (char*)malloc(b64len + 1);
        char body[1024];
        if (b64 != NULL &&
            CryptBinaryToStringA(raw, n, CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF, b64, &b64len))
        {
            b64[b64len] = 0;
            _snprintf_s(body, sizeof(body), _TRUNCATE,
                        "-----BEGIN OPENSSH PRIVATE KEY-----\n%s\n"
                        "-----END OPENSSH PRIVATE KEY-----\n",
                        b64);
            p = WriteFixture("tc_fx_ed25519.key", body);
            CHECK(DetectKeyFormat(p) == kfOpenSSH);
            CHECK(!KeyFileLooksEncrypted(p)); // ciphername is "none"
            char type2[64] = "";
            CHECK(ReadOpenSSHKeyType(p, type2, sizeof(type2)));
            CHECK_STR(type2, "ssh-ed25519");
            reason = 0;
            char offending[64] = "";
            // format alone is acceptable, the algorithm is not
            CHECK(KeyFormatSupported(kfOpenSSH, &reason));
            CHECK(!KeyFileSupported(p, &reason, offending, sizeof(offending)));
            CHECK_STR(offending, "ssh-ed25519");
            DeleteFileA(p);
        }
        if (b64 != NULL)
            free(b64);
    }
}

int main()
{
    TestRights();
    TestOctal();
    TestUtf8();
    TestPaths();
    TestTime();
    TestAttrs();
    TestKeyFormats();

    printf("\n%d passed, %d failed\n", g_pass, g_fail);
    return g_fail == 0 ? 0 : 1;
}
