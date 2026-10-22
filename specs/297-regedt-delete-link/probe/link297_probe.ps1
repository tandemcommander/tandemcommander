<#
.SYNOPSIS
    Feature 297 probe: the Registry Editor plug-in's Delete (F8), Move (F6) and Quick Rename of a
    key whose tree holds a registry link (a key made with REG_OPTION_CREATE_LINK).

.DESCRIPTION
    Fixture (created before each row, removed at the end): HKCU\Software\TcProbe297 with
      Jinde                j = 5;  Jinde\Sub  s = 6   (the key every link points at - never selected)
      Del\<K>              a = 1   holding the LINK L -> Jinde
      Top                  holding the LINK <K> -> Jinde (the focused key is the link itself)
      Dang\<K>             a = 1   holding the LINK L -> Nikde (does not exist: a dangling link)
      Mov\<K>              a = 1;  Mov\<K>\Z  z = 9;  holding the LINK L -> Jinde
      Cil                  empty   (a real target key)
      Plain\<K>            a = 1;  Plain\<K>\Z  z = 9   (no link)
    and HKCU\Software\Classes\TcProbe297c (= HKEY_CLASSES_ROOT\TcProbe297c, the user's classes hive):
      Jinde j = 5, Jinde\Sub s = 6; Del\<K> a = 1 holding the LINK L -> Jinde
    <K> = "Klic" with its Czech accents.

      DELTREE     F8 of Del\<K>, every question answered Yes: Del\<K> and its link gone; Jinde and
                  Jinde\Sub unchanged; no error box (before: Jinde deleted through the link, the link
                  left, "Unable to delete a registry key" for Del\<K>)
      DELTOP      F8 of the link Top\<K> itself: the link gone, Jinde unchanged, no error box (before:
                  Jinde deleted, the link left dangling)
      DELDANGLE   F8 of Dang\<K> (a dangling link inside): Dang\<K> and the link gone, no error box
                  (before: the open-error box, nothing deleted)
      DELHKCR     F8 of HKEY_CLASSES_ROOT\TcProbe297c\Del\<K> (the merged view): as DELTREE
      MOVETREE    F6 of Mov\<K> into HKCU\...\Cil\, Cancel: the first box is "Unable to remove the
                  original registry key." naming Mov\<K>\L; Mov and Jinde unchanged; nothing was
                  written below Cil\<K>\L (before: Jinde copied into Cil\<K>\L and deleted)
      MOVESKIP    the same with Skip: Z moved into Cil\<K>, Mov\<K> kept with a = 1 and its link,
                  Jinde unchanged, no Cil\<K>\L
      MOVETOP     F6 of the link Top\<K> itself into HKCU\...\Cil\, Cancel: the refusal box; the whole
                  fixture unchanged (before: Jinde copied into Cil\<K> and deleted, no box)
      RENAMETOP   Quick Rename (754) of the link Top\<K> to Nove, Cancel: the refusal box; the whole
                  fixture unchanged (before: Jinde copied into Top\Nove and deleted)
      COPYTREE    (control, unchanged behaviour) F5 of Mov\<K> into HKCU\...\Cil\: no box; Cil\<K>\L is
                  a plain key with j = 5 and Sub s = 6 (the link's target copied, as before); Mov and
                  Jinde unchanged
      DEL         (regression) F8 of Plain\<K>: gone, no error box
      MOVE        (regression) F6 of Plain\<K> into HKCU\...\Cil\: moved whole, no box
      END         each instance ends with exit code 0, no stray window, no report

    Links are created and removed with REG_OPTION_CREATE_LINK / REG_OPTION_OPEN_LINK + NtDeleteKey,
    each before the fixture tree is removed (a recursive delete would follow them). The snapshot
    never follows a link (it records the link and its target).

    MUST run through tools\run_on_hidden_desktop.ps1; refuses while tandemcommander.exe runs;
    the product's registry key is exported, restored and SHA-256-verified. Exit code = FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Written in the style of
    specs\296-regedt-link-target-tree\probe\link296_probe.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lang = 'english',
    [string]$Repo
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 3 }

$RepoRoot = $(if ($Repo) { (Resolve-Path -LiteralPath $Repo).Path } else { (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..')).Path })
. (Join-Path $RepoRoot 'specs\098-long-path-overruns\probe\fix_probe_lib.ps1')

if (-not ('RegLink297' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class RegLink297
{
    static readonly UIntPtr HKCU = new UIntPtr(0x80000001u);
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
    static extern int RegCreateKeyExW(UIntPtr h, string sub, int res, string cls, int opt, int sam, IntPtr sa, out UIntPtr r, out int disp);
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
    static extern int RegOpenKeyExW(UIntPtr h, string sub, int opt, int sam, out UIntPtr r);
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
    static extern int RegSetValueExW(UIntPtr h, string name, int res, int type, byte[] data, int size);
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
    static extern int RegQueryValueExW(UIntPtr h, string name, IntPtr res, out int type, byte[] data, ref int size);
    [DllImport("advapi32.dll")] static extern int RegCloseKey(UIntPtr h);
    [DllImport("ntdll.dll")] static extern int NtDeleteKey(UIntPtr h);
    const int REG_OPTION_CREATE_LINK = 2, REG_OPTION_OPEN_LINK = 8, REG_LINK = 6;
    const int KEY_QUERY_VALUE = 1, KEY_SET_VALUE = 2, KEY_CREATE_LINK = 0x20, DELETE = 0x10000;
    // a new link key 'sub' (below HKCU) pointing at the internal name 'target' (\REGISTRY\USER\...)
    public static int Make(string sub, string target)
    {
        UIntPtr h; int d;
        int e = RegCreateKeyExW(HKCU, sub, 0, null, REG_OPTION_CREATE_LINK, KEY_SET_VALUE | KEY_CREATE_LINK | KEY_QUERY_VALUE, IntPtr.Zero, out h, out d);
        if (e != 0) return e;
        if (d != 1) { RegCloseKey(h); return 183; } // ERROR_ALREADY_EXISTS: never retarget an existing key
        byte[] b = System.Text.Encoding.Unicode.GetBytes(target); // no terminator
        e = RegSetValueExW(h, "SymbolicLinkValue", 0, REG_LINK, b, b.Length);
        RegCloseKey(h);
        return e;
    }
    // the target of the link key 'sub', or null when 'sub' is no link (or does not exist)
    public static string Target(string sub)
    {
        UIntPtr h;
        if (RegOpenKeyExW(HKCU, sub, REG_OPTION_OPEN_LINK, KEY_QUERY_VALUE, out h) != 0) return null;
        int type, size = 0;
        string ret = null;
        if (RegQueryValueExW(h, "SymbolicLinkValue", IntPtr.Zero, out type, null, ref size) == 0 && type == REG_LINK)
        {
            byte[] b = new byte[size];
            if (RegQueryValueExW(h, "SymbolicLinkValue", IntPtr.Zero, out type, b, ref size) == 0)
                ret = System.Text.Encoding.Unicode.GetString(b, 0, size).TrimEnd('\0');
        }
        RegCloseKey(h);
        return ret;
    }
    // removes the link key 'sub' itself (never what it points at); 0 = removed, 2 = no such key
    public static int Delete(string sub)
    {
        if (Target(sub) == null) return 2;
        UIntPtr h;
        int e = RegOpenKeyExW(HKCU, sub, REG_OPTION_OPEN_LINK, DELETE | KEY_QUERY_VALUE, out h);
        if (e != 0) return e;
        int s = NtDeleteKey(h);
        RegCloseKey(h);
        return s;
    }
}
'@
}

$Root = $TempRoot + '\tc297'
$StartDir = $Root + '\start'
function Chars([int[]]$Codes) { return (-join ($Codes | ForEach-Object { [char]$_ })) }
# Czech names (pure ASCII source); no variable may share a name with another ignoring case
$K = 'Kl' + (Chars @(0x00ED, 0x010D))
$Sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$RegName = 'TcProbe297'
$RegSub = 'Software\' + $RegName
$RegPs = 'HKCU:\' + $RegSub
$RegFs = 'reg:\HKEY_CURRENT_USER\' + $RegSub
$RegFull = 'HKEY_CURRENT_USER\' + $RegSub
$RegInt = '\REGISTRY\USER\' + $Sid + '\' + $RegSub               # the registry's internal name
# link key (relative to the fixture) -> its target (relative to the fixture)
$Links = [ordered]@{}
$Links['Del\' + $K + '\L'] = 'Jinde'
$Links['Top\' + $K] = 'Jinde'
$Links['Dang\' + $K + '\L'] = 'Nikde'
$Links['Mov\' + $K + '\L'] = 'Jinde'
$MainLinks = $Links
$MainName = $RegName
# the merged HKEY_CLASSES_ROOT view: HKCU\Software\Classes is a link to the hive <SID>_Classes
$ClsName = 'TcProbe297c'
$ClsLinks = [ordered]@{}
$ClsLinks['Del\' + $K + '\L'] = 'Jinde'
$script:Fixture = 'main'
function Use-Fixture([string]$Which) {
    $script:Fixture = $Which
    if ($Which -eq 'classes') {
        $script:RegName = $ClsName; $script:RegSub = 'Software\Classes\' + $ClsName
        $script:RegInt = '\REGISTRY\USER\' + $Sid + '_Classes\' + $ClsName; $script:Links = $ClsLinks
        $script:RegFull = 'HKEY_CLASSES_ROOT\' + $ClsName
    }
    else {
        $script:RegName = $MainName; $script:RegSub = 'Software\' + $MainName
        $script:RegInt = '\REGISTRY\USER\' + $Sid + '\' + $script:RegSub; $script:Links = $MainLinks
        $script:RegFull = 'HKEY_CURRENT_USER\' + $script:RegSub
    }
    $script:RegPs = 'HKCU:\' + $script:RegSub
}

function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Kid([IntPtr]$Dlg, [int]$CtlId) { return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }) | Select-Object -First 1 }
function Start-P {
    $a = @('-t', 'T297', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
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
function Set-Lang([string]$Slg) { & reg.exe add "$RegKey\0.1\Configuration" /v 'Language' /t REG_SZ /d $Slg /f | Out-Null }
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

# every link key below the fixture (found without following any link), deepest first
function Find-Links([string]$Rel) {
    $out = @()
    $item = Get-Item -LiteralPath ($RegPs + $(if ($Rel) { '\' + $Rel } else { '' })) -ErrorAction SilentlyContinue
    if (-not $item) { return @() }
    foreach ($n in @($item.GetSubKeyNames())) {
        $r = $(if ($Rel) { $Rel + '\' + $n } else { $n })
        if ($null -ne [RegLink297]::Target($RegSub + '\' + $r)) { $out += $r } else { $out += @(Find-Links $r) }
    }
    return $out
}
function Remove-Fixture {
    if ($null -ne [RegLink297]::Target($RegSub)) { throw 'the fixture key itself is a link' }
    foreach ($l in @(Find-Links '')) {
        $e = [RegLink297]::Delete($RegSub + '\' + $l)
        if ($e -ne 0) { throw ('cannot remove the link ' + $l + ': ' + $e) }
    }
    Remove-Item -LiteralPath $RegPs -Recurse -Force -ErrorAction SilentlyContinue
}
function New-Key([string]$Rel) { [void](New-Item -Path ($RegPs + '\' + $Rel) -Force) }
function Set-Val([string]$Rel, [string]$Name, [string]$Value) { [void](New-ItemProperty -LiteralPath ($RegPs + '\' + $Rel) -Name $Name -Value $Value -PropertyType String -Force) }
function Make-Fixture {
    NewDir $StartDir
    Remove-Fixture
    New-Key 'Jinde\Sub'
    Set-Val 'Jinde' 'j' '5'
    Set-Val 'Jinde\Sub' 's' '6'
    New-Key ('Del\' + $K)
    Set-Val ('Del\' + $K) 'a' '1'
    if ($script:Fixture -ne 'classes') {
        New-Key 'Top'
        New-Key ('Dang\' + $K)
        Set-Val ('Dang\' + $K) 'a' '1'
        New-Key ('Mov\' + $K + '\Z')
        Set-Val ('Mov\' + $K) 'a' '1'
        Set-Val ('Mov\' + $K + '\Z') 'z' '9'
        New-Key 'Cil'
        New-Key ('Plain\' + $K + '\Z')
        Set-Val ('Plain\' + $K) 'a' '1'
        Set-Val ('Plain\' + $K + '\Z') 'z' '9'
    }
    foreach ($l in $Links.Keys) {
        $e = [RegLink297]::Make($RegSub + '\' + $l, $RegInt + '\' + $Links[$l])
        if ($e -ne 0) { throw ('cannot create the link ' + $l + ': ' + $e) }
    }
}
# every key under the fixture key, never following a link: 'rel|n=v;...' or 'rel|-> target'
function Snap-Keys([string]$Rel) {
    $out = @()
    $t = [RegLink297]::Target($RegSub + '\' + $Rel)
    if ($null -ne $t) {
        if ($t.StartsWith($RegInt + '\', [StringComparison]::OrdinalIgnoreCase)) { $t = $t.Substring($RegInt.Length + 1) }
        return @(('{0}|-> {1}' -f $Rel, $t))
    }
    $item = Get-Item -LiteralPath ($RegPs + '\' + $Rel) -ErrorAction SilentlyContinue
    if (-not $item) { return @() }
    $vals = @($item.GetValueNames() | Sort-Object | ForEach-Object { $_ + '=' + $item.GetValue($_) }) -join ';'
    $out += ('{0}|{1}' -f $Rel, $vals)
    foreach ($n in @($item.GetSubKeyNames())) { $out += @(Snap-Keys ($Rel + '\' + $n)) }
    return $out
}
function Snapshot {
    if (-not (Test-Path -LiteralPath $RegPs)) { return @('(missing)') }
    $item = Get-Item -LiteralPath $RegPs
    $out = @()
    foreach ($n in @($item.GetSubKeyNames())) { $out += @(Snap-Keys $n) }
    return @($out | Sort-Object)
}
function Sub-Snap($Snap, [string]$Top) { return @($Snap | Where-Object { $_.StartsWith($Top + '|') -or $_.StartsWith($Top + '\') }) }
function Has-Line($Snap, [string]$Line) { return @($Snap | Where-Object { $_ -ceq $Line }).Count -eq 1 }
function Has-Key($Snap, [string]$Rel) { return @($Snap | Where-Object { $_.StartsWith($Rel + '|') }).Count -gt 0 }
# the target 'Jinde' (j = 5, Sub s = 6) exactly as made
function Jinde-Ok($Snap) { return (((Sub-Snap $Snap 'Jinde') -join "`n") -ceq ("Jinde\Sub|s=6`nJinde|j=5")) }   # sorted: '\' before '|'
# the program's error box answers WM_GETTEXT of its name field with UTF-8 bytes read through the code
# page (trap of 287): the box text with that reversed, to look for a name with letters outside ASCII
function U8-Back([string]$s) { if ($null -eq $s) { return '' }; return $Utf8.GetString([Text.Encoding]::Default.GetBytes($s)) }

# one command from the panel path $From, the item focused by $Keys; for Copy / Move (727 / 728) the
# typed target $Target, for Quick Rename (754) the new name $Target, for Delete (729) none; every box
# that comes is recorded and answered with the first of $Answer it has (Cancel when none)
function Run-Op([int]$Cmd, [string]$From, [int[]]$Keys, [string]$Target, [int[]]$Answer) {
    $res = @{ Boxes = @(); Pre = $null }
    $id = Start-P
    $res.Id = $id
    Go $id $From
    foreach ($vk in $Keys) { Key $id $vk }
    $known2 = Get-Tops $id
    Post-Cmd (Get-Main $id) $Cmd
    if ($Cmd -ne 729) {
        $dlg = Wait-NewWin $id $known2 10
        if ($dlg -eq [IntPtr]::Zero) { throw 'the command opened no dialog' }
        $edit = @([Drv098f]::Kids($dlg) | Where-Object { @('Edit', 'ComboBox') -contains [Drv098f]::Cls($_) }) | Select-Object -First 1
        if (-not $edit) { throw ('no edit field in the dialog: ' + (WinDesc $dlg)) }
        $res.Pre = [Drv098f]::GetText($edit, 5000)
        [void][Drv098f]::SetText($edit, $Target, 5000)
        $known2 = Get-Tops $id
        Click-Ok $dlg
    }
    for ($i = 0; $i -lt 6; $i++) {
        $boxes = New-Boxes $id $known2 $(if ($i -eq 0) { 8 } else { 4 })
        if (-not $boxes.Count) { break }
        $h = $boxes[0]
        $res.Boxes += @{ Desc = (WinDesc $h); Text = (Box-Text $h) }
        Press $h $(if ($Answer) { $Answer } else { @(2) })
        $known2 = @($known2) + $h
    }
    Sync $id
    Start-Sleep -Milliseconds 1500
    Close-Boxes $id
    return $res
}

function Row-Op([string]$Case, [int]$Cmd, [string]$From, [int[]]$Keys, [string]$Target, [int[]]$Answer, [scriptblock]$Judge) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0
    try {
        Make-Fixture
        $snap0 = Snapshot
        $r = Run-Op $Cmd $From $Keys $Target $Answer
        $id = $r.Id
        $snap1 = Snapshot
        $r.Snap0 = $snap0
        $r.Snap1 = $snap1
        $r.Unchanged = (($snap0 -join "`n") -ceq ($snap1 -join "`n"))
        $r.State = (($snap1 | ForEach-Object { Esc $_ }) -join ' , ')
        & $Judge $r
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { Close-Boxes $id; End-P $Case $id $before } }
}

function Box-Facts($r) {
    if (-not $r.Boxes.Count) { return 'boxes: none' }
    return ('boxes: ' + (($r.Boxes | ForEach-Object { "{0}; text '{1}'" -f $_.Desc, (Esc $_.Text) }) -join ' || '))
}
# the boxes holding $Part (the error boxes); the questions of a Delete are not counted
function Boxes-With($r, [string]$Part) { return @($r.Boxes | Where-Object { $null -ne $_.Text -and $_.Text.Contains($Part.Trim()) }) }
function Err-Boxes($r) { return @($r.Boxes | Where-Object { $null -ne $_.Text -and $_.Text.Contains($UnablePart) }) }
$UnablePart = (Template 1055 'Unable to open a registry key. ').Split(' ')[0]    # "Unable" - every error text of the plug-in starts with it
$Removesrc = Template 1061 'Unable to remove the original registry key. '
$FocusK = @(0x24, 0x28)                                            # "..", then <K> (the only key)

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc297_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    Make-Fixture
    Set-Config
    Set-Lang ($Lang + '.slg')
    Out ("link297_probe (feature 297), expect: {0}, language: {1}" -f $Expect, $Lang)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; registry key existed {3}; export SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), $existed, $regHash)
    Out ("Fixture : {0}" -f ((Snapshot | ForEach-Object { Esc $_ }) -join ' , '))
    Out ''

    $Yes = @(6, 2)                                                 # Yes to the questions, Cancel to an error box
    foreach ($c in @(@{ N = 'DELTREE'; F = 'Del' }, @{ N = 'DELDANGLE'; F = 'Dang' })) {
        $top = $c.F + '\' + $K
        Row-Op $c.N 729 ($RegFs + '\' + $c.F) $FocusK $null $Yes {
            param($r)
            $gone = -not (Has-Key $r.Snap1 $top)
            $jok = Jinde-Ok $r.Snap1
            $errs = @(Err-Boxes $r).Count
            Row $c.N 'STATE' (V ($gone -and $jok)) ("{0} and its link gone: {1}; Jinde unchanged: {2}; keys: {3}" -f (Esc $top), $gone, $jok, $r.State)
            Row $c.N 'BOX' (V ($errs -eq 0)) ("no error box: {0}; {1}" -f ($errs -eq 0), (Box-Facts $r))
        }
    }
    Row-Op 'DELTOP' 729 ($RegFs + '\Top') $FocusK $null $Yes {
        param($r)
        $gone = -not (Has-Key $r.Snap1 ('Top\' + $K))
        $jok = Jinde-Ok $r.Snap1
        $errs = @(Err-Boxes $r).Count
        Row 'DELTOP' 'STATE' (V ($gone -and $jok)) ("the link Top\<K> gone: {0}; Jinde unchanged: {1}; keys: {2}" -f $gone, $jok, $r.State)
        Row 'DELTOP' 'BOX' (V ($errs -eq 0)) ("no error box: {0}; {1}" -f ($errs -eq 0), (Box-Facts $r))
    }
    $MT = 'Mov\' + $K
    Row-Op 'MOVETREE' 728 ($RegFs + '\Mov') $FocusK ('\' + $RegFull + '\Cil\') @(2) {
        param($r)
        $first = ($r.Boxes.Count -ge 1) -and $r.Boxes[0].Text.Contains($Removesrc.Trim()) -and (U8-Back $r.Boxes[0].Text).Contains($RegFull + '\' + $MT + '\L' + "`n")
        Row 'MOVETREE' 'TEXT' (V $first) ("the first box names {0}\L with the remove-source error; {1}" -f (Esc $MT), (Box-Facts $r))
        $kept = (((Sub-Snap $r.Snap0 'Mov') -join "`n") -ceq ((Sub-Snap $r.Snap1 'Mov') -join "`n"))
        $jok = Jinde-Ok $r.Snap1
        $nolink = -not (Has-Key $r.Snap1 ('Cil\' + $K + '\L'))
        Row 'MOVETREE' 'STATE' (V ($kept -and $jok -and $nolink)) ("Mov unchanged: {0}; Jinde unchanged: {1}; nothing below Cil\<K>\L: {2}; keys: {3}" -f $kept, $jok, $nolink, $r.State)
    }
    Row-Op 'MOVESKIP' 728 ($RegFs + '\Mov') $FocusK ('\' + $RegFull + '\Cil\') @(173) {
        param($r)
        $first = ($r.Boxes.Count -eq 1) -and $r.Boxes[0].Text.Contains($Removesrc.Trim())
        Row 'MOVESKIP' 'TEXT' (V $first) ("exactly one box, the remove-source error; {0}" -f (Box-Facts $r))
        $s = $r.Snap1
        $ok = (Has-Line $s ('Cil\' + $K + '|a=1')) -and (Has-Line $s ('Cil\' + $K + '\Z|z=9')) -and -not (Has-Key $s ('Cil\' + $K + '\L')) -and
              (Has-Line $s ($MT + '|a=1')) -and (Has-Line $s ($MT + '\L|-> Jinde')) -and -not (Has-Key $s ($MT + '\Z')) -and (Jinde-Ok $s)
        Row 'MOVESKIP' 'STATE' (V $ok) ("Z moved, the link and Mov\<K> kept, Jinde unchanged: {0}; keys: {1}" -f $ok, $r.State)
    }
    Row-Op 'MOVETOP' 728 ($RegFs + '\Top') $FocusK ('\' + $RegFull + '\Cil\') @(2) {
        param($r)
        $first = ($r.Boxes.Count -ge 1) -and $r.Boxes[0].Text.Contains($Removesrc.Trim()) -and (U8-Back $r.Boxes[0].Text).Contains($RegFull + '\Top\' + $K + "`n")
        Row 'MOVETOP' 'TEXT' (V $first) ("the first box is the remove-source error naming Top\<K>; {0}" -f (Box-Facts $r))
        Row 'MOVETOP' 'ALL' (V $r.Unchanged) ("the whole fixture unchanged: {0}; keys: {1}" -f $r.Unchanged, $r.State)
    }
    Row-Op 'RENAMETOP' 754 ($RegFs + '\Top') $FocusK 'Nove' @(2) {
        param($r)
        $first = ($r.Boxes.Count -ge 1) -and $r.Boxes[0].Text.Contains($Removesrc.Trim()) -and (U8-Back $r.Boxes[0].Text).Contains($RegFull + '\Top\' + $K + "`n")
        Row 'RENAMETOP' 'TEXT' (V $first) ("the first box is the remove-source error naming Top\<K>; {0}" -f (Box-Facts $r))
        Row 'RENAMETOP' 'ALL' (V $r.Unchanged) ("the whole fixture unchanged: {0}; pre '{1}'; keys: {2}" -f $r.Unchanged, (Esc $r.Pre), $r.State)
    }
    Row-Op 'COPYTREE' 727 ($RegFs + '\Mov') $FocusK ('\' + $RegFull + '\Cil\') $null {
        param($r)
        $s = $r.Snap1
        $kept = (((Sub-Snap $r.Snap0 'Mov') -join "`n") -ceq ((Sub-Snap $s 'Mov') -join "`n"))
        $copied = (Has-Line $s ('Cil\' + $K + '|a=1')) -and (Has-Line $s ('Cil\' + $K + '\Z|z=9')) -and (Has-Line $s ('Cil\' + $K + '\L|j=5')) -and (Has-Line $s ('Cil\' + $K + '\L\Sub|s=6'))
        $ok = $kept -and $copied -and (Jinde-Ok $s) -and $r.Boxes.Count -eq 0
        Row 'COPYTREE' 'STATE' (V $ok) ("copied as before (the link's target as a plain key): {0}; source kept: {1}; {2}; keys: {3}" -f $copied, $kept, (Box-Facts $r), $r.State)
    }
    Row-Op 'DEL' 729 ($RegFs + '\Plain') $FocusK $null $Yes {
        param($r)
        $gone = -not (Has-Key $r.Snap1 ('Plain\' + $K))
        $errs = @(Err-Boxes $r).Count
        Row 'DEL' 'STATE' (V ($gone -and $errs -eq 0)) ("Plain\<K> gone: {0}; no error box: {1}; {2}" -f $gone, ($errs -eq 0), (Box-Facts $r))
    }
    Row-Op 'MOVE' 728 ($RegFs + '\Plain') $FocusK ('\' + $RegFull + '\Cil\') $null {
        param($r)
        $s = $r.Snap1
        $moved = (Has-Line $s ('Cil\' + $K + '|a=1')) -and (Has-Line $s ('Cil\' + $K + '\Z|z=9')) -and -not (Has-Key $s ('Plain\' + $K))
        Row 'MOVE' 'STATE' (V ($moved -and $r.Boxes.Count -eq 0)) ("moved whole: {0}; {1}; keys: {2}" -f $moved, (Box-Facts $r), $r.State)
    }
    # the merged HKEY_CLASSES_ROOT view
    Use-Fixture 'classes'
    Row-Op 'DELHKCR' 729 ('reg:\HKEY_CLASSES_ROOT\' + $ClsName + '\Del') $FocusK $null $Yes {
        param($r)
        $gone = -not (Has-Key $r.Snap1 ('Del\' + $K))
        $jok = Jinde-Ok $r.Snap1
        $errs = @(Err-Boxes $r).Count
        Row 'DELHKCR' 'STATE' (V ($gone -and $jok)) ("Del\<K> and its link gone: {0}; Jinde unchanged: {1}; keys: {2}" -f $gone, $jok, $r.State)
        Row 'DELHKCR' 'BOX' (V ($errs -eq 0)) ("no error box: {0}; {1}" -f ($errs -eq 0), (Box-Facts $r))
    }
    Use-Fixture 'main'
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($sp in @($Started)) { if (Test-Alive $sp) { Stop-Process -Id $sp -Force } }
    Start-Sleep -Milliseconds 600
    try { Use-Fixture 'classes'; Remove-Fixture } catch { Out ('CLEANUP ERROR: ' + $_.Exception.Message) }
    Use-Fixture 'main'
    try { Remove-Fixture } catch { Out ('CLEANUP ERROR: ' + $_.Exception.Message) }
    $clsGone = -not (Test-Path -LiteralPath ('HKCU:\Software\Classes\' + $ClsName))
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture keys removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, $leftover.Count, ((-not (Test-Path -LiteralPath $RegPs)) -and $clsGone), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
