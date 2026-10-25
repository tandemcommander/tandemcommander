<#
.SYNOPSIS
    Feature 287 probe: the Registry Editor plug-in's Move (F6) of a key with a Czech name, and the
    "class name of the key cannot be copied" question of Copy / Move into a key of the same name.

.DESCRIPTION
    Fixture (created before each row, removed at the end): HKCU\Software\TcProbe287 with
      Zdroj\<K>          class <A>, value v = ALPHA, subkey <P> (no class) with value w = BETA
                         (the key copied or moved)
      <Cil>              empty (the target of MOVE)
      <Jina>\<K>         class <B>, empty  (a key of the same name, another class)
      <Stejna>\<K>       class <A>, empty  (a key of the same name, the same class)
      <Novy>             empty (no key of that name)
      <Hnizdo>\<K>       class <A> (the same), its subkey <P> class <B> (differs one level down)
      <Obe>\<K>          class <B>, its subkey <P> class <B> (both levels differ)
    <K> = "Klic zlutoucky", <P> = "podklic", <Cil> = "Cil rx", <A> / <B> = "TridaA" / "TridaB",
    each with its Czech accents. Class names are set and read through the registry API.

      MOVE        F6 of <K> into <Cil>: no question; <Cil>\<K> holds v and <P>\w; Zdroj\<K> is gone
      MOVESELF    F6 of <K> into its own subkey <P>, Cancel: the message names <K> (template 1067);
                  nothing changed
      CLASSCOPY   F5 into <Jina>, Cancel: one question (template 1068) naming the whole key; nothing
                  changed
      CLASSMOVE   F6 into <Jina>, Cancel: as CLASSCOPY; the source keeps everything
      CLASSYES    F6 into <Jina>, Yes: <Jina>\<K> holds v and <P>\w and keeps class <B>; Zdroj\<K>
                  is gone
      CLASSSAME   F5 into <Stejna>: no question; <Stejna>\<K> holds v
      CLASSNEW    F5 into <Novy>: no question; <Novy>\<K> holds v and has class <A>
      NESTCANCEL  F5 into <Hnizdo>, Cancel: one question naming ...\<K>\<P>; the values of <K> were
                  copied before it (the documented limit), <Hnizdo>\<K>\<P> holds no w; the source
                  is unchanged
      NESTMOVE    F6 into <Hnizdo>, Cancel: as NESTCANCEL; the source <K> keeps v and <P>\w
      NESTALL     F5 into <Obe>, All: one question only (for <K>); v and <P>\w copied
      NESTYES     F5 into <Obe>, Yes: two questions (<K>, then <K>\<P>); v and <P>\w copied
      END         each instance ends with exit code 0, no stray window, no report

    The name in the question is read from its control: the core's CStaticText answers
    WM_GETTEXT with its UTF-8 bytes, which Windows hands to this wide caller through the code
    page - the probe reverses that conversion (exact for the names used here) and compares the
    whole name.

    On a build without the fix (-Expect before) the CLASS* question rows and every NEST* row but
    the state of NESTALL / NESTYES are expected to FAIL (no question; the contents are merged).

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
    [string[]]$Only,
    [string]$Lang = 'czech'
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 3 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')

if (-not ('Reg287' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class Reg287
{
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
    static extern int RegCreateKeyExW(IntPtr hKey, string sub, int reserved, string cls, int options, int sam, IntPtr sa, out IntPtr result, out int disposition);
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
    static extern int RegOpenKeyExW(IntPtr hKey, string sub, int options, int sam, out IntPtr result);
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
    static extern int RegQueryInfoKeyW(IntPtr hKey, StringBuilder cls, ref int clsLen, IntPtr reserved, IntPtr subKeys, IntPtr maxSubKeyLen,
                                       IntPtr maxClassLen, IntPtr values, IntPtr maxValueNameLen, IntPtr maxValueLen, IntPtr secDesc, IntPtr lastWrite);
    [DllImport("advapi32.dll")]
    static extern int RegCloseKey(IntPtr hKey);
    static readonly IntPtr HKCU = new IntPtr(unchecked((int)0x80000001));
    // creates the key with the class name (a new key only; an existing key keeps its class)
    public static int Create(string sub, string cls)
    {
        IntPtr h; int disp;
        int r = RegCreateKeyExW(HKCU, sub, 0, cls, 0, 0xF003F, IntPtr.Zero, out h, out disp);
        if (r == 0) RegCloseKey(h);
        return r;
    }
    // the class name, or null when the key cannot be opened / queried
    public static string ClassOf(string sub)
    {
        IntPtr h;
        if (RegOpenKeyExW(HKCU, sub, 0, 0x20019, out h) != 0) return null;
        StringBuilder sb = new StringBuilder(1024);
        int n = 1024;
        int r = RegQueryInfoKeyW(h, sb, ref n, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero);
        RegCloseKey(h);
        return r == 0 ? sb.ToString() : null;
    }
}
'@
}

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..')).Path
$Root = $TempRoot + '\tc287'
$StartDir = $Root + '\start'
function Chars([int[]]$Codes) { return (-join ($Codes | ForEach-Object { [char]$_ })) }
# Czech names (pure ASCII source). No variable may be called $k, $p, ... : PowerShell names ignore
# case, a loop variable $k inside a function hides $K
$K = 'Kl' + (Chars @(0x00ED, 0x010D)) + ' ' + [char]0x017E + 'lu' + [char]0x0165 + 'ou' + [char]0x010D + 'k' + [char]0x00FD
$Sub = 'podkl' + (Chars @(0x00ED, 0x010D))
$Cil = 'C' + [char]0x00ED + 'l ' + [char]0x0159 + 'x'
$Jina = 'Jin' + [char]0x00E1
$Stejna = 'Stejn' + [char]0x00E1
$Novy = 'Nov' + [char]0x00FD
$Hnizdo = 'Hn' + [char]0x00ED + 'zdo'
$Obe = 'Ob' + [char]0x011B
$ClsA = 'T' + [char]0x0159 + [char]0x00ED + 'daA'
$ClsB = 'T' + [char]0x0159 + [char]0x00ED + 'daB'
$RegName = 'TcProbe287'
$RegSub = 'Software\' + $RegName
$RegPs = 'HKCU:\' + $RegSub
$RegFs = 'reg:\HKEY_CURRENT_USER\' + $RegSub
$RegFull = 'HKEY_CURRENT_USER\' + $RegSub
$NameK = $RegFull + '\Zdroj\' + $K                 # the name the question shows for <K>
$NameSub = $NameK + '\' + $Sub                      # ... and for its subkey

function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Kid([IntPtr]$Dlg, [int]$CtlId) { return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }) | Select-Object -First 1 }
function Start-P {
    $a = @('-t', 'T287', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
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
    $st = Kid $H 172                                             # IDS_ERROR of the question dialog
    if ($st) { return [Drv098f]::GetText($st, 5000).Replace("`r", '') }
    return (@([Drv098f]::Kids($H) | Where-Object { [Drv098f]::Cls($_) -ne 'Button' } | ForEach-Object { [Drv098f]::GetText($_, 5000).Replace("`r", '') } | Where-Object { $_ }) -join "`n")
}
# the text of a core CStaticText: it answers WM_GETTEXT with its UTF-8 bytes, and Windows converts
# them for this wide caller with the code page - back to the bytes, then read as UTF-8
function Painted-Text([IntPtr]$Ctl) {
    $w = [Drv098f]::GetText($Ctl, 5000)
    $bytes = [Text.Encoding]::GetEncoding([int][Drv098f]::GetACP()).GetBytes($w)
    return [Text.Encoding]::UTF8.GetString($bytes)
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

function Make-Fixture {
    NewDir $StartDir
    Remove-Item -LiteralPath $RegPs -Recurse -Force -ErrorAction SilentlyContinue
    # the parents first: RegCreateKeyEx gives the class also to the parents it creates
    foreach ($fx in @(@('Zdroj', $null), @($Jina, $null), @($Stejna, $null), @($Hnizdo, $null), @($Obe, $null),
                      @(('Zdroj\' + $K), $ClsA), @(('Zdroj\' + $K + '\' + $Sub), $null), @($Cil, $null),
                      @(($Jina + '\' + $K), $ClsB), @(($Stejna + '\' + $K), $ClsA), @($Novy, $null),
                      @(($Hnizdo + '\' + $K), $ClsA), @(($Hnizdo + '\' + $K + '\' + $Sub), $ClsB),
                      @(($Obe + '\' + $K), $ClsB), @(($Obe + '\' + $K + '\' + $Sub), $ClsB))) {
        $r = [Reg287]::Create(($RegSub + '\' + $fx[0]), $fx[1])
        if ($r -ne 0) { throw ("cannot create the fixture key {0}: {1}" -f (Esc $fx[0]), $r) }
    }
    [void](New-ItemProperty -LiteralPath ($RegPs + '\Zdroj\' + $K) -Name 'v' -Value 'ALPHA' -PropertyType String -Force)
    [void](New-ItemProperty -LiteralPath ($RegPs + '\Zdroj\' + $K + '\' + $Sub) -Name 'w' -Value 'BETA' -PropertyType String -Force)
}
# every key under the fixture (or under one of its keys): relative path, class, values (sorted)
function Snapshot([string]$Under = '') {
    $out = @()
    $top = $(if ($Under) { $RegPs + '\' + $Under } else { $RegPs })
    foreach ($item in @(Get-ChildItem -LiteralPath $top -Recurse -ErrorAction SilentlyContinue)) {
        $rel = $item.Name.Substring($item.Name.IndexOf($RegName) + $RegName.Length + 1)
        $vals = @($item.GetValueNames() | Sort-Object | ForEach-Object { $_ + '=' + $item.GetValue($_) }) -join ';'
        $out += ('{0}|{1}|{2}' -f $rel, [Reg287]::ClassOf($RegSub + '\' + $rel), $vals)
    }
    return @($out | Sort-Object)
}
function Has-Key([string]$Rel) { return Test-Path -LiteralPath ($RegPs + '\' + $Rel) }
function ValueOf([string]$Rel, [string]$Name) {
    try { return (Get-ItemProperty -LiteralPath ($RegPs + '\' + $Rel) -Name $Name -ErrorAction Stop).$Name } catch { return $null }
}

# one Copy (727) or Move (728) of <K> from Zdroj into $TargetRel; every box that comes is recorded
# (its text, the name shown, the window) and answered with $Answer (Cancel when none is given)
function Run-Op([string]$Case, [int]$Cmd, [string]$TargetRel, [int[]]$Answer) {
    $res = @{ Boxes = @(); Pre = $null }
    $id = Start-P
    $res.Id = $id
    Go $id ($RegFs + '\Zdroj')
    Key $id 0x24; Key $id 0x28                                    # "..", then <K> (the only key)
    $known = Get-Tops $id
    Post-Cmd (Get-Main $id) $Cmd
    $dlg = Wait-NewWin $id $known 10
    if ($dlg -eq [IntPtr]::Zero) { throw 'Copy / Move opened no dialog' }
    $edit = @([Drv098f]::Kids($dlg) | Where-Object { @('Edit', 'ComboBox') -contains [Drv098f]::Cls($_) }) | Select-Object -First 1
    if (-not $edit) { throw ('no edit field in the dialog: ' + (WinDesc $dlg)) }
    $res.Pre = [Drv098f]::GetText($edit, 5000)
    [void][Drv098f]::SetText($edit, ('\' + $RegFull + '\' + $TargetRel + '\'), 5000)
    $known2 = Get-Tops $id
    Click-Ok $dlg
    for ($i = 0; $i -lt 4; $i++) {
        $boxes = New-Boxes $id $known2 $(if ($i -eq 0) { 8 } else { 4 })
        if (-not $boxes.Count) { break }
        $h = $boxes[0]
        $nameCtl = Kid $h 171                                     # IDS_FILENAME of the question dialog
        $res.Boxes += @{ Desc = (WinDesc $h); Text = (Box-Text $h); Name = $(if ($nameCtl) { Painted-Text $nameCtl } else { $null }) }
        Press $h $(if ($Answer) { $Answer } else { @(2) })
        # (not a fresh window list: the next question may already be open after the answer's pause)
        $known2 = @($known2) + $h
    }
    Sync $id
    Start-Sleep -Milliseconds 1500
    Close-Boxes $id
    return $res
}

function Row-Op([string]$Case, [int]$Cmd, [string]$TargetRel, [int[]]$Answer, [scriptblock]$Judge) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0
    try {
        Make-Fixture
        $snap0 = Snapshot
        $src0 = Snapshot 'Zdroj'
        $r = Run-Op $Case $Cmd $TargetRel $Answer
        $id = $r.Id
        $snap1 = Snapshot
        $r.Unchanged = (($snap0 -join "`n") -ceq ($snap1 -join "`n"))
        $r.SourceKept = (($src0 -join "`n") -ceq ((Snapshot 'Zdroj') -join "`n"))
        $r.State = (($snap1 | ForEach-Object { Esc $_ }) -join ' , ')
        & $Judge $r
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { Close-Boxes $id; End-P $Case $id $before } }
}

function Box-Facts($r) {
    if (-not $r.Boxes.Count) { return 'boxes: none' }
    return ('boxes: ' + (($r.Boxes | ForEach-Object { "{0}; text '{1}'; name '{2}'" -f $_.Desc, (Esc $_.Text), (Esc $_.Name) }) -join ' || '))
}
$QClass = Template 1068 "Class name of the key cannot be copied to the target key.`nDo you wish to continue?"
$QSelf = (Template 1067 "Name:`t%ls`n`nError:`tCan't move a key to itself.").Replace('%ls', $K)
# the boxes are exactly the class-name questions for the given names, in this order
function Asked($r, [string[]]$Names) {
    if ($r.Boxes.Count -ne $Names.Count) { return $false }
    for ($i = 0; $i -lt $Names.Count; $i++) {
        $b = $r.Boxes[$i]
        if ($null -eq $b.Text -or $b.Text.Trim() -cne $QClass.Trim() -or $b.Name -cne $Names[$i]) { return $false }
    }
    return $true
}
function Expect-Asked([string[]]$Names) { return ("expected {0} question(s) '{1}' naming {2}" -f $Names.Count, (Esc $QClass), (($Names | ForEach-Object { "'" + (Esc $_) + "'" }) -join ', ')) }

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc287_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    Make-Fixture
    Set-Config
    Set-Lang ($Lang + '.slg')
    Out ("move287_probe (feature 287), expect: {0}, language: {1}" -f $Expect, $Lang)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; registry key existed {3}; export SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), $existed, $regHash)
    Out ("Fixture : {0}: {1}" -f $RegPs, ((Snapshot | ForEach-Object { Esc $_ }) -join ' , '))
    Out ''

    Row-Op 'MOVE' 728 $Cil $null {
        param($r)
        $moved = (ValueOf ($Cil + '\' + $K) 'v') -ceq 'ALPHA' -and (ValueOf ($Cil + '\' + $K + '\' + $Sub) 'w') -ceq 'BETA'
        $gone = -not (Has-Key ('Zdroj\' + $K))
        Row 'MOVE' 'STATE' (V ($moved -and $gone -and $r.Boxes.Count -eq 0)) ("the dialog offered '{0}'; moved whole: {1}; source gone: {2}; {3}; keys: {4}" -f (Esc $r.Pre), $moved, $gone, (Box-Facts $r), $r.State)
    }
    Row-Op 'MOVESELF' 728 ('Zdroj\' + $K + '\' + $Sub) @(2) {
        param($r)
        $ok = ($r.Boxes.Count -eq 1) -and ($null -ne $r.Boxes[0].Text) -and ($r.Boxes[0].Text.Trim() -ceq $QSelf.Trim())
        Row 'MOVESELF' 'TEXT' (V $ok) ("expected one box '{0}'; {1}" -f (Esc $QSelf), (Box-Facts $r))
        Row 'MOVESELF' 'STATE' (V $r.Unchanged) ("fixture unchanged after Cancel: {0}; keys: {1}" -f $r.Unchanged, $r.State)
    }
    Row-Op 'CLASSCOPY' 727 $Jina @(2) {
        param($r)
        Row 'CLASSCOPY' 'ASK' (V (Asked $r @($NameK))) ("{0}; {1}" -f (Expect-Asked @($NameK)), (Box-Facts $r))
        Row 'CLASSCOPY' 'STATE' (V $r.Unchanged) ("fixture unchanged after Cancel: {0}; keys: {1}" -f $r.Unchanged, $r.State)
    }
    Row-Op 'CLASSMOVE' 728 $Jina @(2) {
        param($r)
        Row 'CLASSMOVE' 'ASK' (V (Asked $r @($NameK))) ("{0}; {1}" -f (Expect-Asked @($NameK)), (Box-Facts $r))
        Row 'CLASSMOVE' 'STATE' (V $r.Unchanged) ("fixture unchanged after Cancel (the source keeps v and its subkey): {0}; keys: {1}" -f $r.Unchanged, $r.State)
    }
    Row-Op 'CLASSYES' 728 $Jina @(6) {
        param($r)
        Row 'CLASSYES' 'ASK' (V (Asked $r @($NameK))) ("{0}; {1}" -f (Expect-Asked @($NameK)), (Box-Facts $r))
        $moved = (ValueOf ($Jina + '\' + $K) 'v') -ceq 'ALPHA' -and (ValueOf ($Jina + '\' + $K + '\' + $Sub) 'w') -ceq 'BETA'
        $cls = [Reg287]::ClassOf($RegSub + '\' + $Jina + '\' + $K)
        $gone = -not (Has-Key ('Zdroj\' + $K))
        Row 'CLASSYES' 'STATE' (V ($moved -and $gone -and $cls -ceq $ClsB)) ("after Yes: moved whole {0}; source gone {1}; target class '{2}' (expected '{3}'); keys: {4}" -f $moved, $gone, (Esc $cls), (Esc $ClsB), $r.State)
    }
    Row-Op 'CLASSSAME' 727 $Stejna $null {
        param($r)
        $copied = (ValueOf ($Stejna + '\' + $K) 'v') -ceq 'ALPHA'
        Row 'CLASSSAME' 'STATE' (V ($copied -and $r.Boxes.Count -eq 0)) ("no question: {0}; copied: {1}; {2}; keys: {3}" -f ($r.Boxes.Count -eq 0), $copied, (Box-Facts $r), $r.State)
    }
    Row-Op 'CLASSNEW' 727 $Novy $null {
        param($r)
        $copied = (ValueOf ($Novy + '\' + $K) 'v') -ceq 'ALPHA'
        $cls = [Reg287]::ClassOf($RegSub + '\' + $Novy + '\' + $K)
        Row 'CLASSNEW' 'STATE' (V ($copied -and $r.Boxes.Count -eq 0 -and $cls -ceq $ClsA)) ("no question: {0}; copied: {1}; new key's class '{2}' (expected '{3}'); {4}; keys: {5}" -f ($r.Boxes.Count -eq 0), $copied, (Esc $cls), (Esc $ClsA), (Box-Facts $r), $r.State)
    }
    foreach ($nest in @(@('NESTCANCEL', 727), @('NESTMOVE', 728))) {
        Row-Op $nest[0] $nest[1] $Hnizdo @(2) {
            param($r)
            $case = $nest[0]
            Row $case 'ASK' (V (Asked $r @($NameSub))) ("{0}; {1}" -f (Expect-Asked @($NameSub)), (Box-Facts $r))
            # Cancel at the subkey: what was copied above it stays copied (the documented limit), the
            # subkey gets nothing, and the source loses nothing (Move deletes no key above a Cancel)
            $parentCopied = (ValueOf ($Hnizdo + '\' + $K) 'v') -ceq 'ALPHA'
            $subEmpty = $null -eq (ValueOf ($Hnizdo + '\' + $K + '\' + $Sub) 'w')
            Row $case 'STATE' (V ($r.SourceKept -and $subEmpty)) ("source unchanged: {0}; target subkey without w: {1}; values of the key above copied: {2}; keys: {3}" -f $r.SourceKept, $subEmpty, $parentCopied, $r.State)
        }
    }
    Row-Op 'NESTALL' 727 $Obe @(185) {
        param($r)
        Row 'NESTALL' 'ASK' (V (Asked $r @($NameK))) ("{0} (All: not again for the subkey); {1}" -f (Expect-Asked @($NameK)), (Box-Facts $r))
        $copied = (ValueOf ($Obe + '\' + $K) 'v') -ceq 'ALPHA' -and (ValueOf ($Obe + '\' + $K + '\' + $Sub) 'w') -ceq 'BETA'
        Row 'NESTALL' 'STATE' (V ($copied -and $r.SourceKept)) ("copied whole: {0}; source unchanged: {1}; keys: {2}" -f $copied, $r.SourceKept, $r.State)
    }
    Row-Op 'NESTYES' 727 $Obe @(6) {
        param($r)
        Row 'NESTYES' 'ASK' (V (Asked $r @($NameK, $NameSub))) ("{0}; {1}" -f (Expect-Asked @($NameK, $NameSub)), (Box-Facts $r))
        $copied = (ValueOf ($Obe + '\' + $K) 'v') -ceq 'ALPHA' -and (ValueOf ($Obe + '\' + $K + '\' + $Sub) 'w') -ceq 'BETA'
        Row 'NESTYES' 'STATE' (V ($copied -and $r.SourceKept)) ("copied whole: {0}; source unchanged: {1}; keys: {2}" -f $copied, $r.SourceKept, $r.State)
    }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($sp in @($Started)) { if (Test-Alive $sp) { Stop-Process -Id $sp -Force } }
    Start-Sleep -Milliseconds 600
    Remove-Item -LiteralPath $RegPs -Recurse -Force -ErrorAction SilentlyContinue
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture key removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, $leftover.Count, (-not (Test-Path -LiteralPath $RegPs)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
