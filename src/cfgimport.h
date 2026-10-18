// SPDX-FileCopyrightText: 2026 Pavel Stupka
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

//*****************************************************************************
//
// cfgimport.h
//
// Feature 245: importing settings from Altap Salamander 2.5-4.0 and Open
// Salamander 5.0 (Options > Import Settings from Salamander, and a one-time
// offer at the first start of a fresh configuration). The source registry key
// is read once, read-only, into a snapshot (salcfgimport.h); the plan, the
// preview and the apply work on that snapshot and on the running program's
// in-memory configuration. See specs/245-settings-import-salamander/.
//
//*****************************************************************************

#include "salcfgimport.h"

// group identifiers (the order is the order of the wizard's list and of applying)
enum CCfgImpGroupId
{
    cigHotPaths,
    cigUserMenu,
    cigFTP,
    cigPluginKeys,
    cigViewers,
    cigFindSets,
    cigHistories,
    cigConfirmations,
    cigPanelOpts,
    cigGeneral,
    cigViewerOpts,
    cigColors,
    cigTemplates,
    cigDefaultDirs,
    cigPluginSettings, // one group per plug-in (CCfgImpGroup::PluginIndex)
};

#define CFGIMP_MODE_ADD 1      // keep everything current, add what is new
#define CFGIMP_MODE_REPLACE 2  // the group becomes the source's
#define CFGIMP_MODE_TAKEOVER 3 // option groups: the source's values replace the current ones

#define CFGIMP_LINE_ADDED 1    // == SALIMPORT_REPORT_ADDED ...
#define CFGIMP_LINE_PRESENT 2
#define CFGIMP_LINE_REPLACED 3
#define CFGIMP_LINE_REMOVED 4
#define CFGIMP_LINE_SKIPPED 5
#define CFGIMP_LINE_FLAGGED 6
#define CFGIMP_LINE_NOTE 7

#define CFGIMP_AVAIL_YES 0
#define CFGIMP_AVAIL_EMPTY 1 // nothing to import in this source
#define CFGIMP_AVAIL_NO 2    // not transferable (reason)

struct CCfgImpSource
{
    char KeyPath[300];     // HKCU-relative root
    char ProductName[100]; // label
    DWORD ConfigVersion;
    int Support;          // SALCFGIMP_SUPPORTED / _TOO_OLD / _TOO_NEW
    BOOL SaveInProgress;  // the root carries "Save In Progress"
    int TableOrder;
};

struct CCfgImpLine
{
    int Kind;
    char* Text; // UTF-8, allocated
};

class CCfgImpGroupData; // per group plan data (cfgimport.cpp)

struct CCfgImpGroup
{
    CCfgImpGroupId Id;
    int PluginIndex;      // cigFTP / cigPluginSettings: the program's plug-in index
    char PluginKey[100];  // cigPluginSettings: "Configuration Key"
    char Title[200];      // UTF-8 row text
    BOOL ListKind;        // list group (Add/Replace) or option group (take over)
    BOOL CanReplace;      // list group offering Replace too
    BOOL Selected;
    int Mode;             // CFGIMP_MODE_*
    int ItemCount;        // items in the source
    int Availability;     // CFGIMP_AVAIL_*
    char Reason[300];     // UTF-8, for CFGIMP_AVAIL_EMPTY/NO
    TDirectArray<CCfgImpLine> Lines;
    BOOL NeedsConsent;    // the plan overwrites or removes something
    BOOL Applied;         // after apply
    char ApplyError[300]; // UTF-8, when apply failed
    CCfgImpGroupData* Data;

    CCfgImpGroup();
    ~CCfgImpGroup();
    void ClearLines();
    void AddLine(int kind, const char* text);
};

// the passwords of the FTP group (research R10)
struct CCfgImpPasswords
{
    BOOL SourceUsesMasterPassword;
    BYTE SourceVerifier[42];
    BOOL SourceVerifierValid;
    char* SourceMasterPassword; // code-page bytes as the old program used them; wiped at the end
    int Policy;                 // SALIMPORT_PWD_*
    BOOL AllowWeakerStorage;    // consent: protected passwords stored without a master password
    int ScrambledCount;         // blobs stored without a master password
    int ProtectedCount;         // blobs stored under the source's master password
    BOOL AskedTCMasterPassword; // the program's master password was asked for in this run
    BOOL TCMasterPasswordGiven;
};

class CCfgImpRun
{
public:
    TDirectArray<CCfgImpSource> Sources;
    int Chosen; // index into Sources, -1 = none
    CSalCfgKey* Snapshot;
    BOOL SnapshotTruncated;
    TIndirectArray<CCfgImpGroup> Groups;
    CCfgImpPasswords Passwords;
    char BackupFile[2 * MAX_PATH]; // UTF-8, after apply
    BOOL Automation;               // _DEBUG seam: no UI, no questions
    BOOL ApplyDone;
    BOOL SourceProgramRuns; // salamand.exe found

    CCfgImpRun();
    ~CCfgImpRun();

    // fills Sources (newest first); FALSE on low memory
    BOOL FindSources();
    // reads the chosen source into the snapshot and builds the groups with their availability
    BOOL OpenSource(int index, char* err, int errSize);
    void FreeSource();

    // computes every selected group's plan (lines); FALSE = a group could not be planned
    BOOL Plan(HWND parent);
    BOOL NeedsConsent();

    // guard, backup, apply, refresh, save; FALSE when nothing was applied (err tells why)
    BOOL Apply(HWND parent, char* err, int errSize);

    // the preview (before apply) / the result (after apply), UTF-8, allocated
    char* BuildText(BOOL result);

    // plan support for the password page
    void CountFTPPasswords();
    BOOL CheckSourceMasterPassword(const char* password);
    BOOL IsGroupSelected(CCfgImpGroupId id);
    CCfgImpGroup* FindGroup(CCfgImpGroupId id, int pluginIndex = -1);
};

// another Tandem Commander instance runs (it would overwrite the import when it closes)
BOOL CfgImpOtherInstanceRuns();

// at least one supported source exists (only checks existence and the configuration version)
BOOL CfgImpAnySupportedSourceExists();

// the whole wizard (cfgimpdlg.cpp); 'fromOffer': started from the first-start offer
void CfgImpRunWizard(HWND parent, BOOL fromOffer);

// the first-start offer (FR-002): asks once, then saves the configuration
void CfgImpShowFirstStartOffer(HWND parent);

// TRUE when the program's configuration root has no "Configuration" subkey (fresh start)
BOOL CfgImpIsFreshConfiguration();

#ifdef _DEBUG
// research R18: TC_CFGIMPORT_AUTORUN=<script> runs the import without UI and closes the program
BOOL CfgImpAutorunRequested();
void CfgImpRunAutomation(HWND parent);
#endif

// set by WinMainBody (salamdr1.cpp): the configuration was fresh at this start
extern BOOL CfgImpFreshConfigAtStart;
