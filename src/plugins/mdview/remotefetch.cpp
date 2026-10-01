// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later
//
// remotefetch.cpp - see remotefetch.h. Compiled without the precompiled header
// (mdview.vcxproj) so the feature-085 probe can build this file on its own.

#include <windows.h>
#include <winhttp.h>

#include "remotefetch.h"

// Minimal WinHTTP GET (capped size). Only reached for a remote image the user
// explicitly consented to: the generator puts a Remote entry in the image table
// only after View > Load Remote Images.
//
// Feature 085 (privacy defect F2) changed three things in the function that
// came from webglue.cpp: the identification (it still said
// "OpenSalamander-mdview"), cookies and automatic authentication are switched
// off on the request (the old comment claimed "no cookies", but WinHTTP keeps
// a session cookie jar by default, and it answered a server's Negotiate/NTLM
// challenge with the user's Windows logon - measured by the 085 probe), and
// only a 2xx answer counts - an error page used to be handed to the engine as
// image data.
bool MdFetchRemote(const std::wstring& url, std::vector<BYTE>& out)
{
    URL_COMPONENTS uc;
    ZeroMemory(&uc, sizeof(uc));
    uc.dwStructSize = sizeof(uc);
    wchar_t host[256] = {0}, path[2048] = {0};
    uc.lpszHostName = host;
    uc.dwHostNameLength = _countof(host);
    uc.lpszUrlPath = path;
    uc.dwUrlPathLength = _countof(path);
    if (!WinHttpCrackUrl(url.c_str(), (DWORD)url.size(), 0, &uc))
        return false;
    bool https = (uc.nScheme == INTERNET_SCHEME_HTTPS);

    HINTERNET hs = WinHttpOpen(MD_REMOTE_USER_AGENT, WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY,
                               WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
    if (!hs)
        return false;
    bool ok = false;
    HINTERNET hc = WinHttpConnect(hs, host, uc.nPort, 0);
    if (hc)
    {
        HINTERNET hr = WinHttpOpenRequest(hc, L"GET", path, NULL, WINHTTP_NO_REFERER,
                                          WINHTTP_DEFAULT_ACCEPT_TYPES,
                                          https ? WINHTTP_FLAG_SECURE : 0);
        // no cookie jar, no Negotiate/NTLM logon with the user's credentials;
        // a request that cannot be configured so is not sent
        DWORD disable = WINHTTP_DISABLE_COOKIES | WINHTTP_DISABLE_AUTHENTICATION;
        if (hr && !WinHttpSetOption(hr, WINHTTP_OPTION_DISABLE_FEATURE, &disable, sizeof(disable)))
        {
            WinHttpCloseHandle(hr);
            hr = NULL;
        }
        if (hr)
        {
            DWORD status = 0;
            DWORD statusSize = sizeof(status);
            if (WinHttpSendRequest(hr, WINHTTP_NO_ADDITIONAL_HEADERS, 0,
                                   WINHTTP_NO_REQUEST_DATA, 0, 0, 0) &&
                WinHttpReceiveResponse(hr, NULL) &&
                WinHttpQueryHeaders(hr, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
                                    WINHTTP_HEADER_NAME_BY_INDEX, &status, &statusSize,
                                    WINHTTP_NO_HEADER_INDEX) &&
                status >= 200 && status <= 299) // anything else is a broken image; its body is not read
            {
                out.clear();
                DWORD avail = 0;
                ok = true;
                do
                {
                    avail = 0;
                    if (!WinHttpQueryDataAvailable(hr, &avail))
                    {
                        ok = false;
                        break;
                    }
                    if (avail == 0)
                        break;
                    size_t base = out.size();
                    out.resize(base + avail);
                    DWORD rd = 0;
                    if (!WinHttpReadData(hr, &out[base], avail, &rd))
                    {
                        ok = false;
                        break;
                    }
                    out.resize(base + rd);
                    if (out.size() > 32u * 1024 * 1024)
                    {
                        ok = false;
                        break;
                    } // cap
                } while (avail > 0);
            }
            WinHttpCloseHandle(hr);
        }
        WinHttpCloseHandle(hc);
    }
    WinHttpCloseHandle(hs);
    return ok && !out.empty();
}
