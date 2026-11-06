<#
.SYNOPSIS
    Backlog item registry-editor-hkcr-move-both-halves-leaves-machine-half: the Registry Editor
    plug-in's Move (F6) of a key that HKEY_CLASSES_ROOT shows from BOTH halves (the machine's
    HKLM\Software\Classes\<X> and the user's HKCU\Software\Classes\<X>).

.DESCRIPTION
    A real extension key of this machine held only by the machine's half (one value at least,
    exactly one subkey <S> without subkeys) is only read: the probe never runs elevated, so the
    machine's half cannot be written or deleted. For each row the probe gives the key a user's half
    of the same shape (HKCU\Software\Classes\<X> with value TcProbeU = USER and an empty subkey <S>),
    so every level of the moved tree is held by both halves, and removes that user's half after the
    row (the probe refuses to run when the user's half exists before).

      BOTHMOVE   F6 of HKCR\<X> into \HKEY_CURRENT_USER\Software\TcProbeBoth\Cil\, every box
                 answered Cancel. Expected: the copy equals the merged view; then the source's halves
                 are deleted by their real paths, the machine's first - without elevation the first
                 box is "Unable to remove the original registry key." naming
                 HKEY_LOCAL_MACHINE\Software\Classes\<X>\<S> with the access-denied error (5); both
                 halves unchanged (nothing of the source deleted). Before the fix: no box at all,
                 the user's half deleted through HKCR, the machine's half left - a partial Move
                 reported as success
      BOTHSKIP   the same, every box answered Skip: one box (the machine's half of <S>), the parent
                 <X> is not deleted (a skipped subkey keeps its parents); both halves unchanged
      BOTHSHADOW the user's <S> holds its own (default) value (it hides the machine's (default) in the
                 merged view, so the copy does not hold the machine's value): the first box names
                 HKEY_LOCAL_MACHINE\Software\Classes\<X>\<S> with "the request is not supported" (50)
                 - the machine's half is never deleted while it holds a value the copy did not take;
                 both halves unchanged
      BOTHEQUAL  (control of BOTHSHADOW) the user's <S> holds a (default) equal to the machine's: not
                 hidden, so the machine's delete is tried - the first box has (5), not (50)
      BOTHTOP    (review of 406) a machine-only key <Y> without subkeys gets a user's half whose
                 value of the name of <Y>'s first value hides it: the first box names
                 HKEY_LOCAL_MACHINE\Software\Classes\<Y> with (50) - the top key's own check
      BOTHCLASS  (review of 406) the user's half of <Y> is created with the class TcProbeClass (the
                 machine's class empty): not a reason to refuse - (5)
      BOTHSELF   (guard, feature 292) F6 of HKCR\<X> into \HKEY_CURRENT_USER\Software\Classes\ (its
                 own user's half): refused "Can't move a key to itself."; both halves unchanged
      END        each instance ends with exit code 0, no stray window, no report

    MUST run through tools\run_on_hidden_desktop.ps1; refuses while tandemcommander.exe runs;
    the product's registry key is exported, restored and SHA-256-verified. Exit code = FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. In the style of specs/390-regedt-hkcr-move-user/probe.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lang = 'english',
    [string]$RepoRoot
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 3 }

if (-not $RepoRoot) { $RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..')).Path }
. (Join-Path $RepoRoot 'specs\098-long-path-overruns\probe\fix_probe_lib.ps1')

$Root = $TempRoot + '\tcboth'
$StartDir = $Root + '\start'
$RegName = 'TcProbeBoth'
$PlainPs = 'HKCU:\Software\' + $RegName
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Kid([IntPtr]$Dlg, [int]$CtlId) { return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }) | Select-Object -First 1 }
function Start-P {
    $a = @('-t', 'TBOTH', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
    $proc = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($proc.Id); [void]$proc.Handle; $script:Procs[$proc.Id] = $proc
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $proc.Id) -and (Get-Main $proc.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $proc.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    if ((Get-Process -Id $proc.Id).Path -ine $Exe) { throw "pid $($proc.Id) is not $Exe" }
    try { [void]$proc.WaitForInputIdle(30000) } catch { }
    Sync $proc.Id
    Start-Sleep -Milliseconds 1500
    return $proc.Id
}
function Set-Lang([string]$Slg) { & reg.exe add "$RegKey\Settings\Configuration" /v 'Language' /t REG_SZ /d $Slg /f | Out-Null }
function Template([int]$Id, [string]$English) {
    if ($Lang -eq 'english') { return $English }
    foreach ($line in [IO.File]::ReadAllLines((Join-Path $RepoRoot ("translations\{0}\regedt.slt" -f $Lang)), $Utf8)) {
        if ($line -match ('^' + $Id + ',\d+,"(.*)"\s*$')) { return $Matches[1].Replace('""', '"').Replace('\n', "`n").Replace('\t', "`t").Replace('\\', '\') }
    }
    throw "id $Id not found in the $Lang translation"
}
function End-P([string]$Case, [int]$Id, $Before) { $fatal = Fatal-Win $Id; End-Row $Case $Id $fatal $Before }
function Box-Text([IntPtr]$H) {
    $st = Kid $H 2477                                            # the program's message box
    if ($st) { return [Drv098f]::GetText($st, 5000).Replace("`r", '') }
    return (@([Drv098f]::Kids($H) | Where-Object { [Drv098f]::Cls($_) -ne 'Button' } | ForEach-Object { [Drv098f]::GetText($_, 5000).Replace("`r", '') } | Where-Object { $_ }) -join "`n")
}
function New-Boxes([int]$Id, $Known, [double]$Seconds = 8) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        $n = @(Get-Tops $Id | Where-Object { $Known -notcontains $_ -and [Drv098f]::Cls($_) -eq '#32770' })
        if ($n.Count) { Start-Sleep -Milliseconds 700; return $n }
        Start-Sleep -Milliseconds 150
    }
    return @()
}
function Press([IntPtr]$H, [int[]]$Ids) {
    if ($H -eq [IntPtr]::Zero -or -not [Drv098f]::IsWindow($H)) { return }
    $b = $null
    foreach ($want in $Ids) { $b = Buttons $H | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $want } | Select-Object -First 1; if ($b) { break } }
    if ($b) { Click $b } else { Close-Win $H }
    Start-Sleep -Milliseconds 600
}
function Close-Boxes([int]$Id) {
    for ($i = 0; $i -lt 6; $i++) {
        $b = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' })
        if (-not $b.Count) { return }
        foreach ($h in $b) { Press $h @(2, 7, 1) }
    }
}
function Go([int]$Id, [string]$Path) { [void](Do-ChangeDir $Id $Path); Sync $Id; Start-Sleep -Milliseconds 1200 }
# the Skip button of the program's error box (DialogError BUTTONS_RETRYSKIPCANCEL): the button whose
# text is the translated "Skip"; ids differ between the box kinds, so it is found by its text
function Press-Skip([IntPtr]$H) {
    if ($H -eq [IntPtr]::Zero -or -not [Drv098f]::IsWindow($H)) { return $false }
    $b = Buttons $H | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 173 } | Select-Object -First 1   # Skip (measured: Retry 4, Skip 173, Skip All 174, Cancel 2)
    if (-not $b) { return $false }
    Click $b; Start-Sleep -Milliseconds 600
    return $true
}

# ---- the machine-only key (only read) -------------------------------------------------------
function Pick-MachineOnly {
    foreach ($k in @(Get-ChildItem -LiteralPath 'HKLM:\Software\Classes' -ErrorAction SilentlyContinue | Sort-Object PSChildName)) {
        $n = $k.PSChildName
        if ($n -cnotmatch '^\.[a-z0-9]{2,5}$') { continue }
        if ($k.ValueCount -lt 1 -or $k.SubKeyCount -ne 1) { continue }
        if (Test-Path -LiteralPath ('HKCU:\Software\Classes\' + $n)) { continue }
        $all = @(Get-ChildItem -LiteralPath $k.PSPath -Recurse -ErrorAction SilentlyContinue)
        if ($all.Count -ne 1 -or $all[0].SubKeyCount -ne 0) { continue }
        if ($all[0].ValueCount -lt 1) { continue }                   # BOTHSHADOW hides its (default)
        if (@($all[0].GetValueNames()) -notcontains '') { continue }
        return $n
    }
    return $null
}
# review of 406: a machine-only extension key with values and no subkeys (only read)
function Pick-MachineFlat {
    foreach ($k in @(Get-ChildItem -LiteralPath 'HKLM:\Software\Classes' -ErrorAction SilentlyContinue | Sort-Object PSChildName)) {
        $n = $k.PSChildName
        if ($n -cnotmatch '^\.[a-z0-9]{2,5}$' -or $n -ieq $script:MachName) { continue }
        if ($k.ValueCount -lt 1 -or $k.SubKeyCount -ne 0) { continue }
        if (Test-Path -LiteralPath ('HKCU:\Software\Classes\' + $n)) { continue }
        if ([Reg406]::ClassOf('Software\Classes\' + $n, $true) -ne '') { continue }  # the machine's class empty
        return $n
    }
    return $null
}
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class Reg406 {
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
    static extern int RegCreateKeyExW(UIntPtr hKey, string subKey, int reserved, string cls, int options, int sam, IntPtr sa, out UIntPtr result, out int disposition);
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
    static extern int RegOpenKeyExW(UIntPtr hKey, string subKey, int options, int sam, out UIntPtr result);
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
    static extern int RegQueryInfoKeyW(UIntPtr hKey, StringBuilder cls, ref int clsLen, IntPtr r, IntPtr a, IntPtr b, IntPtr c, IntPtr d, IntPtr e, IntPtr f, IntPtr g, IntPtr h);
    [DllImport("advapi32.dll")]
    static extern int RegCloseKey(UIntPtr hKey);
    static readonly UIntPtr HKCU = new UIntPtr(0x80000001u), HKLM = new UIntPtr(0x80000002u);
    // a new key of the user's half with a class name (refuses an existing key: its class cannot change)
    public static void CreateWithClass(string path, string cls) {
        UIntPtr h; int disp;
        int err = RegCreateKeyExW(HKCU, path, 0, cls, 0, 0x20006, IntPtr.Zero, out h, out disp);
        if (err != 0) throw new Exception("RegCreateKeyExW " + err);
        RegCloseKey(h);
        if (disp != 1) throw new Exception("the key existed already: " + path);
    }
    public static string ClassOf(string path) { return ClassOf(path, false); }
    public static string ClassOf(string path, bool machine) {
        UIntPtr h;
        if (RegOpenKeyExW(machine ? HKLM : HKCU, path, 0, 0x20019, out h) != 0) return "(open failed)";
        StringBuilder sb = new StringBuilder(260); int len = 260;
        int err = RegQueryInfoKeyW(h, sb, ref len, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero);
        RegCloseKey(h);
        return err == 0 ? sb.ToString() : "(query failed)";
    }
}
'@

# every key of a tree: relative path, values (sorted); '(missing)' when absent
function Snap-Tree([string]$PsTop) {
    if (-not (Test-Path -LiteralPath $PsTop)) { return '(missing)' }
    $top = Get-Item -LiteralPath $PsTop
    $out = @()
    foreach ($item in @(@($top) + @(Get-ChildItem -LiteralPath $PsTop -Recurse -ErrorAction SilentlyContinue))) {
        $rel = $(if ($item.Name.Length -gt $top.Name.Length) { $item.Name.Substring($top.Name.Length + 1) } else { '.' })
        $vals = @($item.GetValueNames() | Sort-Object | ForEach-Object { $_ + '=' + $item.GetValueKind($_) + ':' + (@($item.GetValue($_, $null, 'DoNotExpandEnvironmentNames')) -join ',') }) -join ';'
        $out += ('{0}|{1}' -f $rel, $vals)
    }
    return (@($out | Sort-Object) -join "`n")
}
function MachPs { return 'HKLM:\Software\Classes\' + $script:MachName }
function UserPs { return 'HKCU:\Software\Classes\' + $script:MachName }
function ViewPs { return 'Registry::HKEY_CLASSES_ROOT\' + $script:MachName }

# ---- the fixture ---------------------------------------------------------------------------
function New-Key([string]$PsPath) { [void](New-Item -Path $PsPath -Force) }
function Remove-UserHalf { if ($script:MachName) { Remove-Item -LiteralPath (UserPs) -Recurse -Force -ErrorAction SilentlyContinue } }
function Remove-Fixture { Remove-Item -LiteralPath $PlainPs -Recurse -Force -ErrorAction SilentlyContinue; Remove-UserHalf }
function Make-Fixture([string]$Shadow) {
    NewDir $StartDir
    Remove-Fixture
    New-Key ($PlainPs + '\Cil')
    if ($Shadow -like 'flat*') {
        # review of 406: a machine-only key without subkeys - the top key's own check is the first box
        if ($Shadow -eq 'flat-class') { [Reg406]::CreateWithClass('Software\Classes\' + $script:MachName, 'TcProbeClass') }
        else { New-Key (UserPs) }
        [void](New-ItemProperty -LiteralPath (UserPs) -Name 'TcProbeU' -Value 'USER' -PropertyType String -Force)
        if ($Shadow -eq 'flat-diff') {
            if ($script:FlatValue -eq '') { Set-Item -LiteralPath (UserPs) -Value 'TCPROBE-SHADOW' }
            else { [void](New-ItemProperty -LiteralPath (UserPs) -Name $script:FlatValue -Value 'TCPROBE-SHADOW' -PropertyType String -Force) }
        }
        return
    }
    New-Key ((UserPs) + '\' + $script:SubName)
    [void](New-ItemProperty -LiteralPath (UserPs) -Name 'TcProbeU' -Value 'USER' -PropertyType String -Force)
    if ($Shadow -eq 'diff') { Set-Item -LiteralPath ((UserPs) + '\' + $script:SubName) -Value 'TCPROBE-SHADOW' }
    if ($Shadow -eq 'same') { Set-Item -LiteralPath ((UserPs) + '\' + $script:SubName) -Value ((Get-Item -LiteralPath ((MachPs) + '\' + $script:SubName)).GetValue('', $null, 'DoNotExpandEnvironmentNames')) }
}

# one Move (728) of HKCR\<X> (focused at the HKCR root by Backspace from it) to the typed target
# $Target; every box is recorded and answered by $Answer ('cancel' or 'skip')
function Run-Op([string]$Target, [string]$Answer) {
    $res = @{ Boxes = @(); Pre = $null }
    $id = Start-P
    $res.Id = $id
    Go $id ('reg:\HKEY_CLASSES_ROOT\' + $script:MachName)
    Key $id 0x08                                                   # Backspace: the parent, the key focused
    Sync $id; Start-Sleep -Milliseconds 1500
    $known = Get-Tops $id
    Post-Cmd (Get-Main $id) 728
    $dlg = Wait-NewWin $id $known 10
    if ($dlg -eq [IntPtr]::Zero) { throw 'Move opened no dialog' }
    $edit = @([Drv098f]::Kids($dlg) | Where-Object { @('Edit', 'ComboBox') -contains [Drv098f]::Cls($_) }) | Select-Object -First 1
    if (-not $edit) { throw ('no edit field in the dialog: ' + (WinDesc $dlg)) }
    $res.Pre = [Drv098f]::GetText($edit, 5000)
    [void][Drv098f]::SetText($edit, $Target, 5000)
    $known2 = Get-Tops $id
    Click-Ok $dlg
    for ($i = 0; $i -lt 5; $i++) {
        $boxes = New-Boxes $id $known2 $(if ($i -eq 0) { 8 } else { 4 })
        if (-not $boxes.Count) { break }
        $h = $boxes[0]
        $res.Boxes += @{ Desc = (WinDesc $h); Text = (Box-Text $h) }
        if ($Answer -eq 'skip') { if (-not (Press-Skip $h)) { $res.NoSkip = $true; Press $h @(2) } }
        else { Press $h @(2) }
        $known2 = @($known2) + $h
    }
    Sync $id
    Start-Sleep -Milliseconds 1500
    Close-Boxes $id
    return $res
}

function Row-Both([string]$Case, [string]$Shadow, [string]$Target, [string]$Answer, [scriptblock]$Judge) {
    if (-not (Want $Case)) { return }
    if ($IsAdmin) { Row $Case 'RUN' 'NOT DRIVEN' 'the probe runs elevated: a fixed build would really delete the machine key'; return }
    if (-not $script:MachName) { Row $Case 'RUN' 'NOT DRIVEN' 'no machine-only extension key with values and one subkey with a (default) value on this machine'; return }
    $before = Reports; $id = 0
    try {
        Make-Fixture $Shadow
        $r = Run-Op $Target $Answer
        $id = $r.Id
        $r.Mach0 = $script:Mach0; $r.Mach1 = Snap-Tree (MachPs)
        $r.User0 = $script:User0; $r.User1 = Snap-Tree (UserPs)
        $r.Copy = Snap-Tree ($PlainPs + '\Cil\' + $script:MachName)
        & $Judge $r
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        if ($id) { Close-Boxes $id; End-P $Case $id $before }
        Remove-Fixture
    }
}

function Box-Facts($r) {
    if (-not $r.Boxes.Count) { return 'boxes: none' }
    return ('boxes: ' + (($r.Boxes | ForEach-Object { "{0}; text '{1}'" -f $_.Desc, (Esc $_.Text) }) -join ' || '))
}
function Halves-Facts($r) {
    $mk = $r.Mach0 -ceq $r.Mach1
    $uk = $r.User0 -ceq $r.User1
    return @{ Ok = ($mk -and $uk); Text = ("machine's half unchanged: {0}; user's half unchanged: {1} (now '{2}')" -f $mk, $uk, (Esc $r.User1)) }
}
$Removesrc = (Template 1061 'Unable to remove the original registry key. ').Trim()
$script:MachName = $null
$script:SubName = $null

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tcboth_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    NewDir $StartDir
    Set-Config
    Set-Lang ($Lang + '.slg')
    $script:MachName = Pick-MachineOnly
    if ($script:MachName) { $script:SubName = @(Get-ChildItem -LiteralPath (MachPs))[0].PSChildName }
    $script:FlatName = Pick-MachineFlat
    if ($script:FlatName) { $script:FlatValue = @((Get-Item -LiteralPath ('HKLM:\Software\Classes\' + $script:FlatName)).GetValueNames())[0] }
    Out ("hkcr406_probe (feature 406), language: {0}" -f $Lang)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; elevated {3}; registry key existed {4}; export SHA-256 {5}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), $IsAdmin, $existed, $regHash)
    Out ("Machine : {0} = {1}" -f $script:MachName, $(if ($script:MachName) { Esc (Snap-Tree (MachPs)) } else { '-' }))
    Out ''

    if ($script:MachName) {
        $wantSub = 'HKEY_LOCAL_MACHINE\Software\Classes\' + $script:MachName + '\' + $script:SubName
        # the merged view the copy must equal (built from both halves as Windows shows them)
        $plainTarget = '\HKEY_CURRENT_USER\Software\' + $RegName + '\Cil\'
        foreach ($case in @(@{ N = 'BOTHMOVE'; S = ''; A = 'cancel' }, @{ N = 'BOTHSKIP'; S = ''; A = 'skip' }, @{ N = 'BOTHSHADOW'; S = 'diff'; A = 'cancel' }, @{ N = 'BOTHEQUAL'; S = 'same'; A = 'cancel' })) {
            if (-not (Want $case.N)) { continue }
            Make-Fixture $case.S
            $script:Mach0 = Snap-Tree (MachPs); $script:User0 = Snap-Tree (UserPs); $script:View0 = Snap-Tree (ViewPs)
            Out ("{0} fixture: user's half '{1}'; merged view '{2}'" -f $case.N, (Esc $script:User0), (Esc $script:View0))
            $cn = $case.N; $shadow = $case.S
            Row-Both $cn $shadow $plainTarget $case.A {
                param($r)
                $first = $(if ($r.Boxes.Count -ge 1) { $r.Boxes[0].Text } else { '' })
                $code = $(if ($shadow -eq 'diff') { '(50)' } else { '(5)' })
                $named = ($null -ne $first) -and $first.Contains($Removesrc) -and $first.Contains($wantSub) -and $first.Contains($code)
                Row $cn 'TEXT' (V $named) ("expected the first box '{0}' naming '{1}' with {2}; {3}" -f (Esc $Removesrc), $wantSub, $code, (Box-Facts $r))
                if ($cn -eq 'BOTHSKIP') { Row $cn 'ONEBOX' (V ($r.Boxes.Count -eq 1 -and -not $r.NoSkip)) ("expected exactly one box (the parent kept after Skip), Skip pressed: {0}; {1} box(es)" -f (-not $r.NoSkip), $r.Boxes.Count) }
                $h = Halves-Facts $r
                $copy = $r.Copy -ceq $script:View0
                Row $cn 'STATE' (V ($h.Ok -and $copy)) ("{0}; the copy equals the merged view: {1} (copy '{2}')" -f $h.Text, $copy, (Esc $r.Copy))
            }
        }
        # review of 406: the top key's own check (a machine-only key without subkeys) - a hidden value
        # refuses with (50); a class name only in the user's half (the machine's class empty) is not
        # a reason to refuse - the machine's delete is tried, (5)
        $mainName = $script:MachName
        $script:MachName = $script:FlatName
        if ($script:FlatName) {
            Out ("Flat    : {0} = {1}; hidden value '{2}'" -f $script:FlatName, (Esc (Snap-Tree (MachPs))), $script:FlatValue)
            foreach ($case in @(@{ N = 'BOTHTOP'; S = 'flat-diff'; C = '(50)' }, @{ N = 'BOTHCLASS'; S = 'flat-class'; C = '(5)' })) {
                if (-not (Want $case.N)) { continue }
                Make-Fixture $case.S
                $script:Mach0 = Snap-Tree (MachPs); $script:User0 = Snap-Tree (UserPs); $script:View0 = Snap-Tree (ViewPs)
                $cls = [Reg406]::ClassOf('Software\Classes\' + $script:FlatName)
                Out ("{0} fixture: user's half '{1}' (class '{2}'); merged view '{3}'" -f $case.N, (Esc $script:User0), $cls, (Esc $script:View0))
                $cn = $case.N; $code = $case.C
                $wantTop = 'HKEY_LOCAL_MACHINE\Software\Classes\' + $script:FlatName
                Row-Both $cn $case.S $plainTarget 'cancel' {
                    param($r)
                    $first = $(if ($r.Boxes.Count -ge 1) { $r.Boxes[0].Text } else { '' })
                    $named = ($null -ne $first) -and $first.Contains($Removesrc) -and $first.Contains($wantTop + "`n") -and $first.Contains($code)
                    Row $cn 'TEXT' (V $named) ("expected the first box '{0}' naming '{1}' with {2}; {3}" -f (Esc $Removesrc), $wantTop, $code, (Box-Facts $r))
                    $h = Halves-Facts $r
                    $copy = $r.Copy -ceq $script:View0
                    Row $cn 'STATE' (V ($h.Ok -and $copy)) ("{0}; the copy equals the merged view: {1} (copy '{2}')" -f $h.Text, $copy, (Esc $r.Copy))
                }
                if ($case.S -eq 'flat-class') { $cn2 = $case.N; Row $cn2 'CLASS' (V ($cls -ceq 'TcProbeClass')) ("the user's half had the class 'TcProbeClass': '{0}'" -f $cls) }
            }
        }
        else { Row 'BOTHTOP' 'RUN' 'NOT DRIVEN' 'no machine-only extension key with values and no subkeys on this machine' }
        $script:MachName = $mainName
        if (Want 'BOTHSELF') {
            Make-Fixture ''
            $script:Mach0 = Snap-Tree (MachPs); $script:User0 = Snap-Tree (UserPs); $script:View0 = Snap-Tree (ViewPs)
            $self = (Template 1066 "Can't move a key to itself.").Trim()
            Row-Both 'BOTHSELF' '' '\HKEY_CURRENT_USER\Software\Classes\' 'cancel' {
                param($r)
                $first = $(if ($r.Boxes.Count -ge 1) { $r.Boxes[0].Text } else { '' })
                $self2 = ((Template 1067 "Name:`t%ls`n`nError:`tCan't move a key to itself.") -split "`t")[-1].Trim()
                $refused = $r.Boxes.Count -ge 1 -and ($r.Boxes[0].Text.Contains($self) -or $r.Boxes[0].Text.Contains($self2))
                Row 'BOTHSELF' 'TEXT' (V $refused) ("expected the first box '{0}' (292); {1}" -f (Esc $self), (Box-Facts $r))
                $h = Halves-Facts $r
                Row 'BOTHSELF' 'STATE' (V $h.Ok) $h.Text
            }
        }
    }
    else { Row 'ALL' 'RUN' 'NOT DRIVEN' 'no suitable machine-only extension key on this machine' }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($sp in @($Started)) { if (Test-Alive $sp) { Stop-Process -Id $sp -Force } }
    Start-Sleep -Milliseconds 600
    Remove-Fixture
    $userLeft = $false
    if ($script:MachName) { $userLeft = Test-Path -LiteralPath (UserPs) }
    if ($script:FlatName) {
        $fp = 'HKCU:\Software\Classes\' + $script:FlatName
        Remove-Item -LiteralPath $fp -Recurse -Force -ErrorAction SilentlyContinue
        $userLeft = $userLeft -or (Test-Path -LiteralPath $fp)
    }
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture keys removed: {4}; user's half of the machine key left: {5}; registry restored+identical: {6}" -f $np, $nf, $nn, $leftover.Count, (-not (Test-Path -LiteralPath $PlainPs)), $userLeft, $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
