// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later
//
// webenvopts.h - INTERNAL to src/common/webhost (feature 085). The single
// builder of the WebView2 environment options, shared by the host
// (webhost.cpp) and the keeper (webkeeper.cpp). It is a WRL type, so it cannot
// live in the COM-free webhost.h; include this only after <wrl.h> and
// "WebView2EnvironmentOptions.h" (both files already suspend the leak-tracking
// "new" macro around those headers). Plugins never include it.

#pragma once

// AdditionalBrowserArguments = TcWebBrowserArguments(), IsCustomCrashReportingEnabled = TRUE.
// See webhost.cpp for why each is set and why there is only one builder.
Microsoft::WRL::ComPtr<CoreWebView2EnvironmentOptions> TcWebBuildEnvOptions();
