// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later
//
// remotefetch.h - the Markdown Viewer's one network request: fetching a
// remote image the user consented to (View > Load Remote Images).
//
// Moved out of webglue.cpp in feature 085 so that it can be compiled and tested
// alone against a local server (specs/085-privacy-defect-fixes/probe/): it
// uses nothing but WinHTTP, no plugin global and no precompiled header.

#pragma once

#include <windows.h>

#include <string>
#include <vector>

// The identification every remote-image request carries (User-Agent). Quoted
// in PRIVACY.md - change both together.
#define MD_REMOTE_USER_AGENT L"TandemCommander-mdview"

// GET 'url' (http or https) into 'out'. Returns true only for a 2xx answer
// with a non-empty body of at most 32 MB. No cookies are stored or sent, no
// automatic authentication is attempted, redirects follow WinHTTP's default
// (never from HTTPS to HTTP).
bool MdFetchRemote(const std::wstring& url, std::vector<BYTE>& out);
