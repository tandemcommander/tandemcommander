<#
.SYNOPSIS
    Feature 128 probe (GitHub issue #8): Enter on a shortcut (.lnk) to a folder must open the
    folder, as Windows Explorer does - whatever letters the folder's path holds.

.DESCRIPTION
    Fixture under %TEMP%\tc128: target folders and a folder "links" with shortcuts to them
    (made with the shell's own wide link interface):

      1_ascii.lnk      -> t_ascii                      plain ASCII path
      2_accent.lnk     -> t_<Czech accents>            letters of the system code page
      3_greek.lnk      -> t_<Greek>                    letters outside the system code page
      4_deep.lnk       -> t_<Czech>\<Greek>\sub        both, deeper
      5_<accents>.lnk  -> t_ascii                      the SHORTCUT's own name is accented
      6_unc.lnk        -> \\localhost\<drive>$\...\t_<Czech accents>   a network path
      7_file.lnk       -> t_<Czech accents>\note.txt   a shortcut to a FILE (not followed by Enter;
                                                        used by "Go to Shortcut Target")

    Rows, one program instance per shortcut:
      ENTER n   the shortcut is focused, Enter: the panel's location must be the target folder
                and no error window may appear
      GOTO n    command "Go to Shortcut Target" (838): the panel's location must be the target
                folder (for the shortcut to a file: the folder that holds the file), no error window
      END       exit code 0, no stray window, no report

    Verdicts are exact (the location is read from the Change Directory field). With
    -Expect before the same rows run on the old build as the control.

    MUST run through tools\run_on_hidden_desktop.ps1; refuses while tandemcommander.exe runs;
    the product's registry key is exported, restored and SHA-256-verified. Exit code = FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
    [string]$OutFile,
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 3 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')

# shortcuts are written and read back with the wide shell-link interface (WScript.Shell refuses a
# target outside the code page)
if (-not ('Lnk128' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using System.Text;
public static class Lnk128
{
    [ComImport, Guid("00021401-0000-0000-C000-000000000046")] class ShellLink { }
    [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("000214F9-0000-0000-C000-000000000046")]
    interface IShellLinkW
    {
        void GetPath([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszFile, int cch, IntPtr pfd, int fFlags);
        void GetIDList(out IntPtr ppidl);
        void SetIDList(IntPtr pidl);
        void GetDescription([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszName, int cch);
        void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string pszName);
        void GetWorkingDirectory([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszDir, int cch);
        void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string pszDir);
        void GetArguments([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszArgs, int cch);
        void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string pszArgs);
        void GetHotkey(out short pwHotkey);
        void SetHotkey(short wHotkey);
        void GetShowCmd(out int piShowCmd);
        void SetShowCmd(int iShowCmd);
        void GetIconLocation([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszIconPath, int cch, out int piIcon);
        void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string pszIconPath, int iIcon);
        void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string pszPathRel, int dwReserved);
        void Resolve(IntPtr hwnd, int fFlags);
        void SetPath([MarshalAs(UnmanagedType.LPWStr)] string pszFile);
    }
    public static void Create(string lnk, string target)
    {
        var l = (IShellLinkW)new ShellLink();
        l.SetPath(target);
        ((IPersistFile)l).Save(lnk, true);
        Marshal.ReleaseComObject(l);
    }
    public static string Target(string lnk)
    {
        var l = (IShellLinkW)new ShellLink();
        ((IPersistFile)l).Load(lnk, 0);
        var sb = new StringBuilder(1024);
        l.GetPath(sb, sb.Capacity, IntPtr.Zero, 0);
        Marshal.ReleaseComObject(l);
        return sb.ToString();
    }
}
'@
}

$Root = $TempRoot + '\tc128'
$StartDir = $Root + '\start'
$LinkDir = $Root + '\links'
function Chars([int[]]$Codes) { return (-join ($Codes | ForEach-Object { [char]$_ })) }
$Cz = (Chars @(0x00DA, 0x010D)) + 'etnictv' + [char]0x00ED                 # "Ucetnictvi" with accents
$Gr = Chars @(0x0391, 0x03C1, 0x03C7, 0x03B5, 0x03AF, 0x03BF)               # "Archeio" in Greek letters
$TAscii = $Root + '\t_ascii'
$TCz = $Root + '\t_' + $Cz
$TGr = $Root + '\t_' + $Gr
$TDeep = $TCz + '\' + $Gr + '\sub'
$TUnc = '\\localhost\' + $Root.Substring(0, 1) + '$' + $TCz.Substring(2)
$TFile = $TCz + '\note.txt'
$Links = @(
    @{ N = 1; Name = '1_ascii'; Target = $TAscii; What = 'ASCII path' },
    @{ N = 2; Name = '2_accent'; Target = $TCz; What = 'letters of the system code page' },
    @{ N = 3; Name = '3_greek'; Target = $TGr; What = 'letters outside the system code page' },
    @{ N = 4; Name = '4_deep'; Target = $TDeep; What = 'both, deeper' },
    @{ N = 5; Name = ('5_' + (Chars @(0x017E, 0x0159)) + 'x'); Target = $TAscii; What = 'the shortcut itself has an accented name' },
    @{ N = 6; Name = '6_unc'; Target = $TUnc; What = 'a network path' },
    @{ N = 7; Name = '7_file'; Target = $TFile; What = 'a shortcut to a file' }
)

function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Start-P([string]$Left) {
    $a = @('-t', 'T128', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $StartDir), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    if ((Get-Process -Id $p.Id).Path -ine $Exe) { throw "pid $($p.Id) is not $Exe" }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    Sync $p.Id
    Start-Sleep -Milliseconds 1500
    return $p.Id
}
function Make-Fixture {
    foreach ($d in @($StartDir, $LinkDir, $TAscii, $TCz, $TGr, $TDeep)) { NewDir $d }
    [IO.File]::WriteAllText($TFile, 'x')
    $made = @()
    foreach ($l in $Links) {
        [Lnk128]::Create($LinkDir + '\' + $l.Name + '.lnk', $l.Target)
        $back = [Lnk128]::Target($LinkDir + '\' + $l.Name + '.lnk')     # what Windows itself reads back from the file
        $made += ("{0} -> {1}{2}" -f (Esc $l.Name), (Esc $l.Target), $(if ($back -ceq $l.Target) { '' } else { ' (READ BACK AS ' + (Esc $back) + ')' }))
    }
    return ($made -join '; ')
}
function Row-Link($L, [string]$Action) {
    $case = $Action + ' ' + $L.N
    if (-not (Want $Action)) { return }
    if ($Only -and (@($Only | Where-Object { $_ -match '^\d+$' }).Count) -and ($Only -notcontains ('' + $L.N))) { return }
    $before = Reports; $id = 0; $fatal = $null
    try {
        $id = Start-P $LinkDir
        $loc0 = Get-Loc $id
        Key $id 0x24                                                # Home ("..")
        for ($i = 0; $i -lt $L.N; $i++) { Key $id 0x28 }            # Down to the n-th shortcut
        Sync $id; Start-Sleep -Milliseconds 300
        if ($Action -eq 'ENTER') { Key $id 0x0D } else { Post-Cmd (Get-Main $id) 838 }
        $r = Serve $id 40
        $fatal = $r.Fatal
        Sync $id; Start-Sleep -Milliseconds 1200
        $loc = Get-Loc $id
        if ($Action -eq 'ENTER' -or $L.N -ne 7) { $want = $L.Target } else { $want = [IO.Path]::GetDirectoryName($L.Target) }   # a folder target is entered; for a file target the panel goes to its folder
        $ok = ($r.Messages.Count -eq 0) -and ($loc -ieq $want) -and (-not $fatal)
        Row $case 'LOC' (V $ok) ("{0}: '{1}.lnk' -> '{2}'; windows: {3}; location '{4}' (expected '{5}')" -f $L.What, (Esc $L.Name), (Esc $L.Target), (Msgs $r), (Esc $loc), (Esc $want))
    }
    catch { Row $case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $case $id $fatal $before } }
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc128_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    $fx = Make-Fixture
    Set-Config
    Out ("lnk_probe (feature 128, issue #8), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; registry key existed {3}; export SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), $existed, $regHash)
    Out ("Fixture : {0}" -f $fx)
    Out ''
    foreach ($l in $Links) { if ($l.N -ne 7) { Row-Link $l 'ENTER' } }
    foreach ($l in $Links) { if (@(2, 3, 7) -contains $l.N) { Row-Link $l 'GOTO' } }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ("Fixture: could not delete $Root : " + $_.Exception.Message) }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, $leftover.Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
