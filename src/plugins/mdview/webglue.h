// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later
//
// webglue.h - mdview's side of the product's shared WebView2 host.
//
// Feature 081 finished the lift feature 070 began: the host itself -- engine
// start-up, the canonical user data folder, the availability gate, the whole
// settings lockdown, resource interception with default-deny, the CSP header,
// accelerator routing, zoom and background colour -- lives in
// src/common/webhost/ (CTcWebHost, CTcWebKeeper) and is shared with the Code
// Viewer. Before 081 this plugin carried its own copy of all of it
// (webview.cpp, CMdWebHost), which is exactly the duplication
// architecture/11-webview2-integration.md exists to prevent.
//
// What is left here is what is genuinely mdview's own: the document and image
// server, the key map, the pre-065 cache-folder janitor and the keeper
// wrappers. Contract:
// specs/081-mdview-shared-webhost/contracts/mdview-host-config.md.
//
// COM-free on purpose, and this is now a rule rather than a convenience: no
// <wrl.h> and no WebView2 header is included anywhere in this plugin.

#pragma once

#include <string>
#include "webhost.h"
#include "htmlgen.h"

// Fills in everything the shared host needs for an mdview controller: the
// private origin https://mdview.invalid/, scripts and web messages OFF (the
// feature 021 lockdown), the document/image server and the key map.
//
// 'doc' is the viewer window's own MdHtmlResult member. Its ADDRESS is what
// the interceptor keeps -- the contents may be regenerated as often as the
// window likes -- so it must outlive the host (CViewerWindow destroys the host
// before its members go away).
void MdConfigureHost(TcWebHostConfig& cfg, const MdHtmlResult* doc);

// Best-effort removal of the pre-065 mdview.WebView2 cache folder (cache only,
// nothing is migrated -- the canonical folder is TcWebUserDataFolder()). Once
// per session; main-thread-only; failures are silent and retried next session.
void MdCleanupOldUserDataFolder();

// Session keeper (feature 065; the implementation is the shared CTcWebKeeper
// since 081): a hidden environment + controller that keeps the shared browser
// tree alive so every view after the first attaches warm. Both are
// MAIN-THREAD-ONLY and idempotent; every failure path is silent (the next view
// may arm again). Disarm restores the pre-065 lifecycle.
//
// The wrappers exist so the keeper's identity -- its window class name, which
// must stay unique per plugin -- is written down once.
void MdKeeperArm();
void MdKeeperDisarm();
