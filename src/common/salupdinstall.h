// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// salupdinstall.h
//
// Automatic update - the pure part (feature 420). After the check of feature
// 123 finds a newer release, the program downloads that release's installer,
// proves that it is the published file, signed by the project and of the
// announced version, and installs it - on the user's click, at the program's
// exit, or at the next start when the exit did not do it. Every decision of
// that feature that can be made without Windows state lives here: the update
// level, the redirect allow-list of the download, the signer pin, the rule for
// the installer's version resource, the installer's command line, and the
// decisions about an armed update at start-up and at exit.
//
// Header-only and free of core dependencies, so that saltests compiles it as
// it is. No allocation, no I/O, no globals.
//
// Contracts: specs/420-auto-update-install/contracts/*.md
// Data model: specs/420-auto-update-install/data-model.md
//
//*****************************************************************************

#include "salupdcheck.h"

#define SALUPD_MAX_INSTALLER_BYTES (64ULL * 1024 * 1024) // a larger asset is not downloaded
#define SALUPD_MAX_REDIRECTS 3                          // hops after the API address
#define SALUPD_MAX_LAUNCHES 3                           // installer launches for one armed version
#define SALUPD_LOCATION_MAX 4096                        // characters of a redirect target
#define SALUPD_ARGS_MAX 1200                            // characters of the installer's arguments

// the fixed identification of the download request (the check keeps its own, 123)
#define SALUPD_DOWNLOAD_USER_AGENT_W L"TandemCommander-update"
#define SALUPD_DOWNLOAD_HEADERS_W L"Accept: application/octet-stream\r\nX-GitHub-Api-Version: 2022-11-28\r\n"

//
// ****************************************************************************
// The update level (stored value "Update Level")
//

enum CSalUpdLevel
{
    sulNotify = 0,   // tell the user only (feature 123)
    sulOffer = 1,    // download, verify, offer Install Now / Install When I Close - the default
    sulAutomatic = 2 // download, verify, install when the program closes
};

// a missing or unknown stored value is the default
inline CSalUpdLevel SalUpdLevelFromStored(BOOL present, DWORD value)
{
    if (!present || value > (DWORD)sulAutomatic)
        return sulOffer;
    return (CSalUpdLevel)value;
}

//
// ****************************************************************************
// After a check: download or only notify?
//

enum CSalUpdAfterCheck
{
    suacNotify,  // feature 123's notification (Download in the browser)
    suacDownload // download, verify, then offer or arm
};

// 'checkOnOrTest': the check option is on, or the session runs in test mode
inline CSalUpdAfterCheck SalUpdAfterCheck(CSalUpdLevel level, BOOL checkOnOrTest, BOOL eligible, BOOL metered,
                                          const CSalUpdRelease& release)
{
    if (level == sulNotify || !checkOnOrTest || !eligible || metered)
        return suacNotify;
    if (!release.HasAsset || !release.HasDigest || release.AssetSize == 0 ||
        release.AssetSize > SALUPD_MAX_INSTALLER_BYTES)
        return suacNotify;
    return suacDownload;
}

//
// ****************************************************************************
// The redirect allow-list of the download (contracts/download-and-verification.md D2)
//

inline WCHAR SalUpdLowerAscii(WCHAR c) { return (c >= L'A' && c <= L'Z') ? (WCHAR)(c - L'A' + L'a') : c; }

// 'n' characters of 'a' equal to the zero-terminated lowercase ASCII 'b', ignoring ASCII case
inline BOOL SalUpdEqualHost(const WCHAR* a, int n, const char* b)
{
    int i = 0;
    for (; i < n; i++)
    {
        if (b[i] == 0 || SalUpdLowerAscii(a[i]) != (WCHAR)(unsigned char)b[i])
            return FALSE;
    }
    return b[i] == 0;
}

// The target of a redirect the download may follow: "https://" + exactly one of GitHub's
// release download hosts, optionally ":443", then a path (with its query). Refused: another
// scheme or host, user info, another port, a fragment, a character outside printable ASCII,
// more than SALUPD_LOCATION_MAX characters. On success 'host' gets the host as written and
// 'path' the path with the query ("/" when the address has none).
inline BOOL SalUpdRedirectAllowed(const WCHAR* location, WCHAR* host, int hostSize, WCHAR* path, int pathSize)
{
    static const char* const hosts[] = {"release-assets.githubusercontent.com", "objects.githubusercontent.com"};
    if (location == NULL || host == NULL || path == NULL || hostSize <= 0 || pathSize <= 0)
        return FALSE;
    host[0] = 0;
    path[0] = 0;
    int len = 0;
    while (location[len] != 0)
    {
        WCHAR c = location[len];
        if (c <= 0x20 || c >= 0x7F || c == L'#' || c == L'\\')
            return FALSE;
        if (++len > SALUPD_LOCATION_MAX)
            return FALSE;
    }
    static const char scheme[] = "https://";
    for (int i = 0; i < 8; i++)
    {
        if (i >= len || SalUpdLowerAscii(location[i]) != (WCHAR)scheme[i])
            return FALSE;
    }
    const WCHAR* h = location + 8;
    int hostLen = 0;
    while (h[hostLen] != 0 && h[hostLen] != L'/' && h[hostLen] != L':' && h[hostLen] != L'?')
    {
        if (h[hostLen] == L'@')
            return FALSE; // user info
        hostLen++;
    }
    BOOL known = FALSE;
    for (int k = 0; k < (int)(sizeof(hosts) / sizeof(hosts[0])); k++)
    {
        if (SalUpdEqualHost(h, hostLen, hosts[k]))
            known = TRUE;
    }
    if (!known)
        return FALSE;
    const WCHAR* p = h + hostLen;
    if (*p == L':')
    {
        if (p[1] != L'4' || p[2] != L'4' || p[3] != L'3' || (p[4] != 0 && p[4] != L'/' && p[4] != L'?'))
            return FALSE;
        p += 4;
    }
    if (hostLen + 1 > hostSize)
        return FALSE;
    memcpy(host, h, hostLen * sizeof(WCHAR));
    host[hostLen] = 0;
    int pathLen = (int)wcslen(p);
    if (*p == 0)
    {
        if (pathSize < 2)
            return FALSE;
        path[0] = L'/';
        path[1] = 0;
        return TRUE;
    }
    if (*p == L'?') // "https://host?query" - the path is "/"
    {
        if (pathLen + 2 > pathSize)
            return FALSE;
        path[0] = L'/';
        memcpy(path + 1, p, (pathLen + 1) * sizeof(WCHAR));
        return TRUE;
    }
    if (pathLen + 1 > pathSize)
        return FALSE;
    memcpy(path, p, (pathLen + 1) * sizeof(WCHAR));
    return TRUE;
}

// An HTTP status the download treats as a redirect (with a Location header)
inline BOOL SalUpdIsRedirectStatus(DWORD status)
{
    return status == 301 || status == 302 || status == 303 || status == 307 || status == 308;
}

//
// ****************************************************************************
// The signer pin and the version resource (contracts/download-and-verification.md D4)
//

// SHA-1 thumbprints of the project's code-signing certificates - the one releases are signed with
// now ('thumbprint' in tools/codesign/codesign.cfg, which tools/check_update_pin.py requires to be
// in this list on every build) and, around a certificate renewal, the next or the previous one.
// Review 2: a single pin made a renewal impossible without one release that every installed copy
// refuses; the procedure is in architecture/12-project-reference.md ("Automatic update").
static const char* const SalUpdSignerThumbprints[] = {
    "a3d05ccf5ca13eaff49cc7f64d1832f0e6ef6733", // Certum, valid to 2027-03-08 (feature 050)
};

inline int SalUpdHexValue(char c)
{
    if (c >= '0' && c <= '9')
        return c - '0';
    if (c >= 'a' && c <= 'f')
        return c - 'a' + 10;
    if (c >= 'A' && c <= 'F')
        return c - 'A' + 10;
    return -1;
}

// TRUE when the 'len' bytes are the 40 hex digits of 'pin'
inline BOOL SalUpdThumbprintIs(const unsigned char* sha1, DWORD len, const char* pin)
{
    if (sha1 == NULL || len != 20 || pin == NULL || strlen(pin) != 40)
        return FALSE;
    for (int i = 0; i < 20; i++)
    {
        int hi = SalUpdHexValue(pin[2 * i]);
        int lo = SalUpdHexValue(pin[2 * i + 1]);
        if (hi < 0 || lo < 0 || sha1[i] != (unsigned char)((hi << 4) | lo))
            return FALSE;
    }
    return TRUE;
}

// TRUE when the 'len' bytes are one of the pinned thumbprints
inline BOOL SalUpdSignerPinned(const unsigned char* sha1, DWORD len)
{
    for (int i = 0; i < (int)(sizeof(SalUpdSignerThumbprints) / sizeof(SalUpdSignerThumbprints[0])); i++)
    {
        if (SalUpdThumbprintIs(sha1, len, SalUpdSignerThumbprints[i]))
            return TRUE;
    }
    return FALSE;
}

// Inno Setup pads the strings of its version resource with spaces (measured, fix-log M7):
// the value without its trailing spaces, as ASCII; FALSE for a non-ASCII or too long value.
inline BOOL SalUpdResourceText(const WCHAR* value, char* buf, int bufSize)
{
    if (value == NULL || buf == NULL || bufSize <= 0)
        return FALSE;
    int len = (int)wcslen(value);
    while (len > 0 && value[len - 1] == L' ')
        len--;
    if (len >= bufSize)
        return FALSE;
    for (int i = 0; i < len; i++)
    {
        if (value[i] < 0x20 || value[i] >= 0x7F)
            return FALSE;
        buf[i] = (char)value[i];
    }
    buf[len] = 0;
    return TRUE;
}

// The installer's ProductName must be "Tandem Commander" and its ProductVersion the announced version
inline BOOL SalUpdInstallerVersionOk(const WCHAR* productName, const WCHAR* productVersion,
                                     const CSalUpdVersion& expected)
{
    char name[40];
    char version[SALUPD_VERSION_TEXT_MAX];
    CSalUpdVersion v;
    return SalUpdResourceText(productName, name, sizeof(name)) && strcmp(name, "Tandem Commander") == 0 &&
           SalUpdResourceText(productVersion, version, sizeof(version)) &&
           SalUpdParseVersion(version, -1, FALSE, &v) && SalUpdVersionCompare(v, expected) == 0;
}

//
// ****************************************************************************
// Digest as stored text (64 lowercase hex digits, no prefix)
//

inline BOOL SalUpdFormatDigestHex(const unsigned char* digest, char* buf, int bufSize)
{
    static const char hex[] = "0123456789abcdef";
    if (digest == NULL || buf == NULL || bufSize < 2 * SALUPD_DIGEST_BYTES + 1)
        return FALSE;
    for (int i = 0; i < SALUPD_DIGEST_BYTES; i++)
    {
        buf[2 * i] = hex[digest[i] >> 4];
        buf[2 * i + 1] = hex[digest[i] & 15];
    }
    buf[2 * SALUPD_DIGEST_BYTES] = 0;
    return TRUE;
}

inline BOOL SalUpdParseDigestHex(const char* text, unsigned char* digest)
{
    char prefixed[8 + 2 * SALUPD_DIGEST_BYTES + 1];
    if (text == NULL || strlen(text) != 2 * SALUPD_DIGEST_BYTES)
        return FALSE;
    memcpy(prefixed, "sha256:", 7);
    memcpy(prefixed + 7, text, 2 * SALUPD_DIGEST_BYTES + 1);
    return SalUpdParseDigest(prefixed, digest);
}

//
// ****************************************************************************
// The files of the updates folder
//

enum CSalUpdFileKind
{
    sufkInstaller, // tandemcommander-<ver>-x64-setup.exe
    sufkPart,      // tandemcommander-<ver>-x64-setup.exe.part
    sufkLog        // setup-<ver>.log
};

// setup-<ver>.log
inline BOOL SalUpdLogName(const CSalUpdVersion& v, char* buf, int bufSize)
{
    if (buf == NULL || bufSize <= 0)
        return FALSE;
    char* end = buf + bufSize;
    buf[0] = 0;
    char* p = SalUpdAppendText(buf, end, "setup-");
    p = SalUpdAppendVersion(p, end, v);
    p = SalUpdAppendText(p, end, ".log");
    if (p == NULL)
        buf[0] = 0;
    return p != NULL;
}

// Recognises the names the feature writes (ASCII, exact case as written; any other name is
// not ours and is left alone).
inline BOOL SalUpdParseUpdateFileName(const char* name, CSalUpdVersion* v, CSalUpdFileKind* kind)
{
    if (name == NULL || v == NULL || kind == NULL)
        return FALSE;
    size_t len = strlen(name);
    static const char instPrefix[] = "tandemcommander-";
    static const char instSuffix[] = "-x64-setup.exe";
    static const char partSuffix[] = "-x64-setup.exe.part";
    static const char logPrefix[] = "setup-";
    static const char logSuffix[] = ".log";
    if (len > 16 && strncmp(name, instPrefix, 16) == 0)
    {
        if (len > 16 + 19 && strcmp(name + len - 19, partSuffix) == 0 &&
            SalUpdParseVersion(name + 16, (int)(len - 16 - 19), FALSE, v))
        {
            *kind = sufkPart;
            return TRUE;
        }
        if (len > 16 + 14 && strcmp(name + len - 14, instSuffix) == 0 &&
            SalUpdParseVersion(name + 16, (int)(len - 16 - 14), FALSE, v))
        {
            *kind = sufkInstaller;
            return TRUE;
        }
        return FALSE;
    }
    if (len > 6 + 4 && strncmp(name, logPrefix, 6) == 0 && strcmp(name + len - 4, logSuffix) == 0 &&
        SalUpdParseVersion(name + 6, (int)(len - 6 - 4), FALSE, v))
    {
        *kind = sufkLog;
        return TRUE;
    }
    return FALSE;
}

// Start-up clean-up of one of our files: a '.part' never survives a start; an installer or
// a log stays only when it belongs to the arm being completed, or (outside test mode) when
// its version is newer than the running one. A test-mode start downloads afresh.
inline BOOL SalUpdKeepUpdateFile(CSalUpdFileKind kind, const CSalUpdVersion& fileVersion,
                                 const CSalUpdVersion& running, BOOL testMode, BOOL hasKeptArm,
                                 const CSalUpdVersion& keptArm)
{
    if (kind == sufkPart)
        return FALSE;
    if (hasKeptArm && SalUpdVersionCompare(fileVersion, keptArm) == 0)
        return TRUE;
    if (testMode)
        return FALSE;
    return SalUpdVersionCompare(fileVersion, running) > 0;
}

//
// ****************************************************************************
// The installer's command line (contracts/installer-launch.md)
//

// Feature 420 review M1: the name of a running installer of the product - the Inno Setup loader
// "tandemcommander-<ver>-x64-setup.exe" or its extracted "tandemcommander-<ver>-x64-setup.tmp"
// (ASCII case ignored, as Windows compares names). While one runs, no other is started: two setups
// replacing the same files at once could leave a mixed installation.
// Review 2: also a copy the user downloaded under another name ("... -setup (1).exe") - any
// "tandemcommander-...setup....exe/.tmp" counts (a false positive only postpones an update).
inline BOOL SalUpdIsInstallerProcessName(const WCHAR* name)
{
    static const char prefix[] = "tandemcommander-";
    static const char setup[] = "setup";
    if (name == NULL)
        return FALSE;
    int len = (int)wcslen(name);
    if (len <= 16 + 5 + 4)
        return FALSE;
    for (int i = 0; i < 16; i++)
    {
        if (SalUpdLowerAscii(name[i]) != (WCHAR)prefix[i])
            return FALSE;
    }
    const WCHAR* ext = name + len - 4;
    BOOL exe = SalUpdLowerAscii(ext[0]) == L'.' && SalUpdLowerAscii(ext[1]) == L'e' &&
               SalUpdLowerAscii(ext[2]) == L'x' && SalUpdLowerAscii(ext[3]) == L'e';
    BOOL tmp = SalUpdLowerAscii(ext[0]) == L'.' && SalUpdLowerAscii(ext[1]) == L't' &&
               SalUpdLowerAscii(ext[2]) == L'm' && SalUpdLowerAscii(ext[3]) == L'p';
    if (!exe && !tmp)
        return FALSE;
    for (int i = 16; i + 5 <= len - 4; i++) // "setup" somewhere between the prefix and the extension
    {
        int k = 0;
        while (k < 5 && SalUpdLowerAscii(name[i + k]) == (WCHAR)setup[k])
            k++;
        if (k == 5)
            return TRUE;
    }
    return FALSE;
}

enum CSalUpdLaunchKind
{
    sulkNow, // Install Now and the completion at start-up: progress window, close, restart
    sulkExit // the program's exit: very silent, no restart
};

inline const char* SalUpdLaunchKindName(CSalUpdLaunchKind k) { return k == sulkNow ? "now" : "exit"; }

// The arguments after the program path. 'noRestart' (a Debug probe seam only) turns the
// restart of Install Now off. A log path with a quote cannot be passed and is refused.
inline BOOL SalUpdBuildInstallerArgs(CSalUpdLaunchKind kind, BOOL allUsers, BOOL noRestart, const WCHAR* logPath,
                                     WCHAR* buf, int bufSize)
{
    if (buf == NULL || bufSize <= 0)
        return FALSE;
    buf[0] = 0;
    if (logPath == NULL || logPath[0] == 0 || wcschr(logPath, L'"') != NULL)
        return FALSE;
    const WCHAR* fixed = kind == sulkNow
                             ? (noRestart ? L"/SP- /SILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS /NORESTARTAPPLICATIONS "
                                          : L"/SP- /SILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS ")
                             : L"/SP- /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS /NORESTARTAPPLICATIONS ";
    const WCHAR* mode = allUsers ? L"/ALLUSERS " : L"/CURRENTUSER ";
    size_t need = wcslen(fixed) + wcslen(mode) + 7 /* /LOG=" */ + wcslen(logPath) + 1 /* " */ + 1;
    if (need > (size_t)bufSize)
        return FALSE;
    wcscpy_s(buf, bufSize, fixed);
    wcscat_s(buf, bufSize, mode);
    wcscat_s(buf, bufSize, L"/LOG=\"");
    wcscat_s(buf, bufSize, logPath);
    wcscat_s(buf, bufSize, L"\"");
    return TRUE;
}

//
// ****************************************************************************
// The armed update (contracts/stored-state.md)
//

#define SALUPD_ARM_USER 1      // armed by a click (Install When I Close, Install Now)
#define SALUPD_ARM_AUTOMATIC 2 // armed by the level "install automatically"
// Round 3 M1: an installer started for it did not install it (cancelled, elevation declined, the
// program was closed by it and it failed) - the update is only OFFERED: nothing installs it on its
// own (not the exit, not the automatic level) until the user clicks Install Now / Install When I
// Close; its launch count and digest are kept
#define SALUPD_ARM_OFFERED 3

struct CSalUpdArm
{
    BOOL Present;
    CSalUpdVersion Version;
    unsigned char Digest[SALUPD_DIGEST_BYTES];
    DWORD Source; // SALUPD_ARM_USER / SALUPD_ARM_AUTOMATIC / SALUPD_ARM_OFFERED (never honoured)
    BOOL Test;    // armed in test mode
    DWORD Launches;
};

// An arm counts only while what armed it still holds: a click always; the automatic level
// while the check is on (or the session is in test mode) and the level is still automatic.
inline BOOL SalUpdArmHonoured(const CSalUpdArm& arm, BOOL checkOn, CSalUpdLevel level, BOOL testMode)
{
    if (!arm.Present)
        return FALSE;
    if (arm.Source == SALUPD_ARM_USER)
        return TRUE;
    return arm.Source == SALUPD_ARM_AUTOMATIC && (checkOn || testMode) && level == sulAutomatic;
}

enum CSalUpdStartupArm
{
    susaNone,      // nothing armed
    susaDropAll,   // forget the arm and delete its installer
    susaDropState, // forget the arm, keep the file (it may be offered again)
    susaDone,      // the running version reached it: forget the arm and delete its installer
    susaGiveUp,    // SALUPD_MAX_LAUNCHES did not get there: nothing is started on its own any more; the
                   // arm is KEPT (review S1: a new arm of the same version keeps the count), so the
                   // update is only offered (Install Now) until a newer version or the version is reached
    susaComplete,  // install it now (Install Now route) - the exit did not start the installer at all
    susaOffer      // review 2 S1: the installer WAS started and the version is still the old one (it
                   // was cancelled, the elevation declined, it failed) - offer it now, never force it
                   // at the start; the arm stays (the exit tries again within SALUPD_MAX_LAUNCHES)
};

inline const char* SalUpdStartupArmName(CSalUpdStartupArm d)
{
    switch (d)
    {
    case susaNone:
        return "none";
    case susaDropAll:
        return "drop-all";
    case susaDropState:
        return "drop-state";
    case susaDone:
        return "done";
    case susaGiveUp:
        return "give-up";
    case susaComplete:
        return "complete";
    case susaOffer:
        return "offer";
    }
    return "unknown";
}

// data-model.md, "Start-up decision". The caller verifies the installer before it completes.
inline CSalUpdStartupArm SalUpdStartupArmDecision(const CSalUpdArm& arm, BOOL honoured, BOOL testMode,
                                                  const CSalUpdVersion& running, BOOL eligible)
{
    if (!arm.Present)
        return susaNone;
    if (!eligible)
        return susaNone; // a copy not installed by the installer leaves the installed copy's arm alone (review)
    if (arm.Test && !testMode)
        return susaDropAll; // a test never installs in a normal session
    if (arm.Source == SALUPD_ARM_OFFERED) // round 3: only offered - the check offers it again
        return (!arm.Test && SalUpdVersionCompare(running, arm.Version) >= 0) ? susaDone : susaNone;
    if (!honoured)
        return susaDropState;
    if (!arm.Test && SalUpdVersionCompare(running, arm.Version) >= 0)
        return susaDone;
    if (arm.Test && arm.Launches > 0)
        return susaDone; // a launched same-version install cannot be told from a failed one
    if (arm.Launches >= SALUPD_MAX_LAUNCHES)
        return susaGiveUp;
    if (arm.Launches > 0)
        return susaOffer; // started before and not installed: the user decides (item, Expected 5)
    return susaComplete;
}

// Review S1: the form a downloaded and verified installer is shown in at the automatic level - an arm
// of the same version whose launches are used up is not promised for the exit any more (offered only)
inline BOOL SalUpdAutomaticArmUsable(BOOL hasArm, const CSalUpdArm& arm, const CSalUpdVersion& version)
{
    if (!hasArm || SalUpdVersionCompare(arm.Version, version) != 0)
        return TRUE;
    // round 3 M1: an update that is only offered is not armed by the automatic level again
    return arm.Source != SALUPD_ARM_OFFERED && arm.Launches < SALUPD_MAX_LAUNCHES;
}

// Round 4 MUST: Install Now makes its own (user) arm to count the launch; when that launch fails -
// the installer could not be started, or it ended without installing while the program runs - the
// arm that existed before the click comes back with the new launch count (an offered update stays
// only offered, an automatic one stays subject to the settings); a click on nothing armed leaves
// nothing armed ('*keep' FALSE).
inline CSalUpdArm SalUpdArmAfterFailedNow(BOOL hadArm, const CSalUpdArm& before, const CSalUpdArm& now, BOOL* keep)
{
    CSalUpdArm result = before;
    *keep = hadArm && before.Present && now.Present && SalUpdVersionCompare(before.Version, now.Version) == 0;
    // round 5 NOTE: a launch of the other mode (a test session over a normal arm) is not counted
    if (*keep && (before.Test != 0) == (now.Test != 0))
        result.Launches = now.Launches > before.Launches ? now.Launches : before.Launches;
    return result;
}

// Round 4 NOTE: an update that can only be offered is not kept where no offer can come - with the
// check at start-up off nothing shows the offer, so the arm and its installer (~8 MB) go - also one
// whose launches are used up (the exit refuses it, only an offer could bring it back). A copy not
// installed by the installer ('eligible' FALSE) touches nothing; a test session keeps its test arm.
inline CSalUpdStartupArm SalUpdStartupOfferReachable(CSalUpdStartupArm decision, const CSalUpdArm& arm, BOOL checkOn,
                                                     BOOL testMode, BOOL eligible)
{
    if (checkOn || testMode || !eligible || !arm.Present)
        return decision;
    if (decision == susaOffer || decision == susaGiveUp || (decision == susaNone && arm.Source == SALUPD_ARM_OFFERED))
        return susaDropAll;
    return decision;
}

// Round 4 SHOULD: can "Install When I Close" still plan 'version' for the exit? Not when its arm used
// up its launches (the exit decision refuses it, the click would promise what never happens). An arm
// of another version, or of the other mode (a test arm in a normal session, ...), starts afresh.
inline BOOL SalUpdExitArmAvailable(BOOL hasArm, const CSalUpdArm& arm, const CSalUpdVersion& version, BOOL testMode)
{
    if (!hasArm || !arm.Present || SalUpdVersionCompare(arm.Version, version) != 0 || (arm.Test != 0) != (testMode != 0))
        return TRUE;
    return arm.Launches < SALUPD_MAX_LAUNCHES;
}

// data-model.md, "Exit decision". 'normalExit': not an installer's close, not a critical
// shutdown, Windows not shutting down or signing out. 'lastInstance': no other instance of
// this executable runs in the session (an exit must not close the user's other windows).
inline BOOL SalUpdExitDecision(const CSalUpdArm& arm, BOOL honoured, BOOL normalExit, BOOL lastInstance,
                               BOOL eligible, BOOL testMode, const CSalUpdVersion& running)
{
    if (!arm.Present || !honoured || !normalExit || !lastInstance || !eligible)
        return FALSE;
    if (arm.Launches >= SALUPD_MAX_LAUNCHES)
        return FALSE;
    if (arm.Test)
        return testMode;
    return SalUpdVersionCompare(running, arm.Version) < 0;
}
