<#
.SYNOPSIS
    Feature 296 probe: the Registry Editor plug-in's Move (F6) / Copy (F5) of a key into a target
    whose tree holds a registry link (a key made with REG_OPTION_CREATE_LINK) pointing into the source.

.DESCRIPTION
    Fixture (created before each row, removed at the end): HKCU\Software\TcProbe296 with
      Zdroj\<K>            a = 1     (the moved key)
      Zdroj\<K>\Z          z = 9     (its subkey - the only copy of z)
      Cil\<K>              empty     (a real target key) holding the LINK Z -> Zdroj\<K>
      Hore\<K>             a = 1     (the moved key of LINKUP)
      Hore\<K>\U           u = 2
      Hore\<K>\U\<K>       w = 7     (the only copy of w)
      Cil2\<K>             holding the LINK U -> Hore (the parent of the moved key)
      Plochy\<K>           a = 1;  Plochy\<K>\U  u = 2   (no chain below U)
      Cil3\<K>             holding the LINK U -> Plochy
      Jinde                empty     (an unrelated key)
      Cil4\<K>             holding the LINK Z -> Jinde
      Cil5\<K>             holding the LINK Z -> Zdroj\<K>\Nove (does not exist: a dangling link)
      Cil6                 holding the LINK <K> -> Zdroj\<K>\Nove (dangling, the moved key's own name)
      Prazdny              empty     (a real other target)
      G\H\<K>              a = 1;  G\H\<K>\U  u = 2;  G\H\<K>\U\H\<K>  w = 7
      CilG\<K>             holding the LINK U -> G (two levels above the moved key G\H\<K>)
      D\<K>                a = 1;  D\<K>\A\B  b = 3
      CilD\<K>\A           holding the LINK B -> D\<K> (at the second level of the recursion)
      L2                   the LINK -> Zdroj\<K>;  CilC\<K> holding the LINK Z -> L2 (a chain)
      Q\<K>                a = 1;  Q\<K>\Z  z = 9;  Q\R  the LINK -> Q\<K>\X (dangling sibling)
    and HKCU\Software\Classes\TcProbe296c (= HKEY_CLASSES_ROOT\TcProbe296c, the user's classes hive):
      Zdroj\<K> a = 1, Zdroj\<K>\Z z = 9; Cil\<K> holding the LINK Z -> Zdroj\<K>
    <K> = "Klic" with its Czech accents. <U> = \HKEY_USERS\<the user's own SID> = \HKEY_CURRENT_USER.

      LINKMOVE    F6 of Zdroj\<K> into HKCU\...\Cil\, Cancel: refused with "Name: <the source key
                  Zdroj\<K>\Z> ... Can't move a key to itself." (1067); the source tree unchanged
      LINKALIAS   the same with the target written as <U>\...\Cil\: refused (1067); source unchanged
      LINKCOPY    F5 of the same into HKCU\...\Cil\: refused (1065); the source tree unchanged (the
                  copy wrote z into the source before)
      LINKOK      F6 as LINKMOVE with OK in the box (skip the key): the source tree unchanged (Move
                  keeps a source with a skipped key), the link unchanged
      LINKUP      F6 of Hore\<K> into HKCU\...\Cil2\ (the link points at the source's parent, and the
                  source holds U\<K> - the copy through the link reaches the source): refused (1067)
                  naming Hore\<K>\U; Hore and its tree unchanged
      LINKDANGLE  F6 of Zdroj\<K> into HKCU\...\Cil5\ (a dangling link below the target): refused with
                  the open-error box (1055); the source tree unchanged (the copy created a key
                  inside the source before)
      LINKTOP     F6 of Zdroj\<K> into HKCU\...\Cil6\ (the target key itself is a dangling link into
                  the source): refused with the open-error box (1055); the whole fixture unchanged
      LINKUPOK    (control) F6 of Plochy\<K> into HKCU\...\Cil3\: no box; the link is followed as
                  before (Plochy holds u = 2), Plochy\<K> is gone, Cil3\<K> holds a = 1
      LINKOTHER   (control) F6 of Zdroj\<K> into HKCU\...\Cil4\: no box; the link to the unrelated
                  key is followed as before (Jinde holds z = 9), Zdroj\<K> is gone
      MOVE        (regression) F6 of Zdroj\<K> into HKCU\...\Prazdny\: moved whole, no box
      LINKGRAND   F6 of G\H\<K> into HKCU\...\CilG\ (the link points two levels above the source, the
                  source holds the path H\<K> back): refused (1067) naming G\H\<K>\U; G unchanged
      LINKDEEP    F6 of D\<K> into HKCU\...\CilD\ (the link at the second level): refused (1067) naming
                  D\<K>\A\B; D unchanged
      LINKCHAIN   F6 of Zdroj\<K> into HKCU\...\CilC\ (a link to a link to the source): refused (1067)
      RENAMEDANGLE Quick Rename (754) of Q\<K> to R (a dangling link into the source): the open-error
                  box (1055); the whole fixture unchanged (the copy recursed into itself before)
      RENAME      (regression) Quick Rename of Q\<K> to Nove3: renamed whole, no box
      HKCRMOVE    F6 of HKEY_CLASSES_ROOT\TcProbe296c\Zdroj\<K> into \HKEY_CLASSES_ROOT\TcProbe296c\Cil\
                  (the merged view; the link in the user's classes hive): refused (1067); unchanged
      END         each instance ends with exit code 0, no stray window, no report

    On a build without the fix (-Expect before) LINKMOVE / LINKALIAS lose z = 9 without a box,
    LINKUP loses w = 7 without a box, LINKCOPY writes z into the source, LINKDANGLE and LINKTOP
    create keys inside the source.

    Links are created and removed with REG_OPTION_CREATE_LINK / REG_OPTION_OPEN_LINK + NtDeleteKey,
    each before the fixture tree is removed (a recursive delete would follow them). The snapshot
    never follows a link (it records the link and its target).

    MUST run through tools\run_on_hidden_desktop.ps1; refuses while tandemcommander.exe runs;
    the product's registry key is exported, restored and SHA-256-verified. Exit code = FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Written in the style of
    specs\294-regedt-move-above-parent\probe\above294_probe.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lang = 'english'
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 3 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')

if (-not ('RegLink296' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class RegLink296
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

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..')).Path
$Root = $TempRoot + '\tc296'
$StartDir = $Root + '\start'
function Chars([int[]]$Codes) { return (-join ($Codes | ForEach-Object { [char]$_ })) }
# Czech names (pure ASCII source); no variable may share a name with another ignoring case
$K = 'Kl' + (Chars @(0x00ED, 0x010D))
$Sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$RegName = 'TcProbe296'
$RegSub = 'Software\' + $RegName
$RegPs = 'HKCU:\' + $RegSub
$RegFs = 'reg:\HKEY_CURRENT_USER\' + $RegSub
$RegFull = 'HKEY_CURRENT_USER\' + $RegSub
$RegUsers = 'HKEY_USERS\' + $Sid + '\' + $RegSub                 # the same key under another root
$RegInt = '\REGISTRY\USER\' + $Sid + '\' + $RegSub               # the registry's internal name
# link key (relative to the fixture) -> its target (relative to the fixture)
$Links = [ordered]@{}
$Links['Cil\' + $K + '\Z'] = 'Zdroj\' + $K
$Links['Cil2\' + $K + '\U'] = 'Hore'
$Links['Cil3\' + $K + '\U'] = 'Plochy'
$Links['Cil4\' + $K + '\Z'] = 'Jinde'
$Links['Cil5\' + $K + '\Z'] = 'Zdroj\' + $K + '\Nove'
$Links['Cil6\' + $K] = 'Zdroj\' + $K + '\Nove'
$Links['CilG\' + $K + '\U'] = 'G'                       # two levels above the source G\H\<K>
$Links['CilD\' + $K + '\A\B'] = 'D\' + $K               # at the second level of the recursion
$Links['L2'] = 'Zdroj\' + $K                            # a link to a link to the source
$Links['CilC\' + $K + '\Z'] = 'L2'
$Links['Q\R'] = 'Q\' + $K + '\X'                        # a dangling sibling for Quick Rename
$MainLinks = $Links
$MainName = $RegName
# the merged HKEY_CLASSES_ROOT view: HKCU\Software\Classes is a link to the hive <SID>_Classes
$ClsName = 'TcProbe296c'
$ClsLinks = [ordered]@{}
$ClsLinks['Cil\' + $K + '\Z'] = 'Zdroj\' + $K
$script:Fixture = 'main'
# switch the fixture the helper functions work on: 'main' (HKCU\Software\TcProbe296) or 'classes'
# (HKCU\Software\Classes\TcProbe296c, seen as HKEY_CLASSES_ROOT\TcProbe296c)
function Use-Fixture([string]$Which) {
    $script:Fixture = $Which
    if ($Which -eq 'classes') {
        $script:RegName = $ClsName; $script:RegSub = 'Software\Classes\' + $ClsName
        $script:RegInt = '\REGISTRY\USER\' + $Sid + '_Classes\' + $ClsName; $script:Links = $ClsLinks
    }
    else {
        $script:RegName = $MainName; $script:RegSub = 'Software\' + $MainName
        $script:RegInt = '\REGISTRY\USER\' + $Sid + '\' + $script:RegSub; $script:Links = $MainLinks
    }
    $script:RegPs = 'HKCU:\' + $script:RegSub
}

function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Kid([IntPtr]$Dlg, [int]$CtlId) { return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }) | Select-Object -First 1 }
function Start-P {
    $a = @('-t', 'T296', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
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

# every link key below the fixture (found without following any link), deepest first
function Find-Links([string]$Rel) {
    $out = @()
    $item = Get-Item -LiteralPath ($RegPs + $(if ($Rel) { '\' + $Rel } else { '' })) -ErrorAction SilentlyContinue
    if (-not $item) { return @() }
    foreach ($n in @($item.GetSubKeyNames())) {
        $r = $(if ($Rel) { $Rel + '\' + $n } else { $n })
        if ($null -ne [RegLink296]::Target($RegSub + '\' + $r)) { $out += $r } else { $out += @(Find-Links $r) }
    }
    return $out
}
function Remove-Fixture {
    if ($null -ne [RegLink296]::Target($RegSub)) { throw 'the fixture key itself is a link' }
    foreach ($l in @(Find-Links '')) {
        $e = [RegLink296]::Delete($RegSub + '\' + $l)
        if ($e -ne 0) { throw ('cannot remove the link ' + $l + ': ' + $e) }
    }
    Remove-Item -LiteralPath $RegPs -Recurse -Force -ErrorAction SilentlyContinue
}
function New-Key([string]$Rel) { [void](New-Item -Path ($RegPs + '\' + $Rel) -Force) }
function Set-Val([string]$Rel, [string]$Name, [string]$Value) { [void](New-ItemProperty -LiteralPath ($RegPs + '\' + $Rel) -Name $Name -Value $Value -PropertyType String -Force) }
function Make-Fixture {
    NewDir $StartDir
    Remove-Fixture
    New-Key ('Zdroj\' + $K + '\Z')
    Set-Val ('Zdroj\' + $K) 'a' '1'
    Set-Val ('Zdroj\' + $K + '\Z') 'z' '9'
    if ($script:Fixture -eq 'classes') {
        New-Key ('Cil\' + $K)
        foreach ($l in $Links.Keys) {
            $e = [RegLink296]::Make($RegSub + '\' + $l, $RegInt + '\' + $Links[$l])
            if ($e -ne 0) { throw ('cannot create the link ' + $l + ': ' + $e) }
        }
        return
    }
    New-Key ('G\H\' + $K + '\U\H\' + $K)
    Set-Val ('G\H\' + $K) 'a' '1'
    Set-Val ('G\H\' + $K + '\U') 'u' '2'
    Set-Val ('G\H\' + $K + '\U\H\' + $K) 'w' '7'
    New-Key ('D\' + $K + '\A\B')
    Set-Val ('D\' + $K) 'a' '1'
    Set-Val ('D\' + $K + '\A\B') 'b' '3'
    New-Key ('CilD\' + $K + '\A')
    New-Key ('Q\' + $K + '\Z')
    Set-Val ('Q\' + $K) 'a' '1'
    Set-Val ('Q\' + $K + '\Z') 'z' '9'
    foreach ($c in @('CilG', 'CilC')) { New-Key ($c + '\' + $K) }
    New-Key ('Hore\' + $K + '\U\' + $K)
    Set-Val ('Hore\' + $K) 'a' '1'
    Set-Val ('Hore\' + $K + '\U') 'u' '2'
    Set-Val ('Hore\' + $K + '\U\' + $K) 'w' '7'
    New-Key ('Plochy\' + $K + '\U')
    Set-Val ('Plochy\' + $K) 'a' '1'
    Set-Val ('Plochy\' + $K + '\U') 'u' '2'
    foreach ($c in @('Cil', 'Cil2', 'Cil3', 'Cil4', 'Cil5')) { New-Key ($c + '\' + $K) }
    foreach ($c in @('Cil6', 'Jinde', 'Prazdny')) { New-Key $c }
    foreach ($l in $Links.Keys) {
        $e = [RegLink296]::Make($RegSub + '\' + $l, $RegInt + '\' + $Links[$l])
        if ($e -ne 0) { throw ('cannot create the link ' + $l + ': ' + $e) }
    }
}
# every key under the fixture key, never following a link: 'rel|n=v;...' or 'rel|-> target'
function Snap-Keys([string]$Rel) {
    $out = @()
    $item = Get-Item -LiteralPath ($RegPs + '\' + $Rel) -ErrorAction SilentlyContinue
    if (-not $item) { return @() }
    $vals = @($item.GetValueNames() | Sort-Object | ForEach-Object { $_ + '=' + $item.GetValue($_) }) -join ';'
    $out += ('{0}|{1}' -f $Rel, $vals)
    foreach ($n in @($item.GetSubKeyNames())) {
        $r = $Rel + '\' + $n
        $t = [RegLink296]::Target($RegSub + '\' + $r)
        if ($null -ne $t) {
            if ($t.StartsWith($RegInt + '\', [StringComparison]::OrdinalIgnoreCase)) { $t = $t.Substring($RegInt.Length + 1) }
            $out += ('{0}|-> {1}' -f $r, $t)
        }
        else { $out += @(Snap-Keys $r) }
    }
    return $out
}
function Snapshot {
    if (-not (Test-Path -LiteralPath $RegPs)) { return @('(missing)') }
    $item = Get-Item -LiteralPath $RegPs
    $out = @()
    foreach ($n in @($item.GetSubKeyNames())) {
        if ($null -ne [RegLink296]::Target($RegSub + '\' + $n)) { $out += ('{0}|-> (link)' -f $n) } else { $out += @(Snap-Keys $n) }
    }
    return @($out | Sort-Object)
}
# the snapshot lines of one subtree ($Top itself and everything below it)
function Sub-Snap($Snap, [string]$Top) { return @($Snap | Where-Object { $_.StartsWith($Top + '|') -or $_.StartsWith($Top + '\') }) }
function Has-Key([string]$Rel) { return @(Snapshot | Where-Object { $_.StartsWith($Rel + '|') -and -not $_.StartsWith($Rel + '|->') }).Count -gt 0 }
# the values of one key, sorted, as 'n=v;n=v' ($null when the key is missing or a link)
function ValsOf([string]$Rel) {
    $line = @(Snapshot | Where-Object { $_.StartsWith($Rel + '|') }) | Select-Object -First 1
    if (-not $line -or $line.StartsWith($Rel + '|->')) { return $null }
    return $line.Substring($Rel.Length + 1)
}
# the number of keys holding the value $Name = $Value (never through a link)
function Count-Val([string]$Name, [string]$Value) { return @(Snapshot | Where-Object { -not $_.Contains('|->') -and (';' + $_.Split('|')[1] + ';').Contains(';' + $Name + '=' + $Value + ';') }).Count }

# one Copy (727) or Move (728) from the panel path $From, the item focused by $Keys, to the typed
# target $Target; every box that comes is recorded and answered with $Answer (Cancel when none)
function Run-Op([int]$Cmd, [string]$From, [int[]]$Keys, [string]$Target, [int[]]$Answer) {
    $res = @{ Boxes = @(); Pre = $null }
    $id = Start-P
    $res.Id = $id
    Go $id $From
    foreach ($vk in $Keys) { Key $id $vk }
    $known = Get-Tops $id
    Post-Cmd (Get-Main $id) $Cmd
    $dlg = Wait-NewWin $id $known 10
    if ($dlg -eq [IntPtr]::Zero) { throw 'Copy / Move opened no dialog' }
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
# the first box is exactly $Text / holds $Part
function First-Is($r, [string]$Text) { return ($r.Boxes.Count -ge 1) -and ($null -ne $r.Boxes[0].Text) -and ($r.Boxes[0].Text.Trim() -ceq $Text.Trim()) }
function First-Has($r, [string]$Part) { return ($r.Boxes.Count -ge 1) -and ($null -ne $r.Boxes[0].Text) -and $r.Boxes[0].Text.Contains($Part.Trim()) }
# the subtree $Top is the same after the operation
function Same-Sub($r, [string]$Top) { return ((Sub-Snap $r.Snap0 $Top) -join "`n") -ceq ((Sub-Snap $r.Snap1 $Top) -join "`n") }
function Into-Text([int]$Id, [string]$English, [string]$Rel) { return (Template $Id $English).Replace('%ls', ($RegFull + '\' + $Rel)) }
$MoveTmpl = "Name:`t%ls`n`nError:`tCan't move a key to itself."
$CopyTmpl = "Name:`t%ls`n`nError:`tCan't copy a key to itself."
$OpenErr = Template 1055 'Unable to open a registry key. '
$FocusK = @(0x24, 0x28)                                            # "..", then <K> (the only key)

function Kept-Row([string]$Case, [string]$Top, $r, [bool]$TextOk, [string]$Want) {
    Row $Case 'TEXT' (V $TextOk) ("expected the first box {0}; {1}" -f (Esc $Want), (Box-Facts $r))
    $kept = Same-Sub $r $Top
    Row $Case 'STATE' (V $kept) ("source tree {0} unchanged: {1}; keys: {2}" -f (Esc $Top), $kept, $r.State)
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc296_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    Make-Fixture
    Set-Config
    Set-Lang ($Lang + '.slg')
    Out ("link296_probe (feature 296), expect: {0}, language: {1}" -f $Expect, $Lang)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; registry key existed {3}; export SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), $existed, $regHash)
    Out ("Alias   : \{0} = \{1}" -f $RegUsers, $RegFull)
    Out ("Fixture : {0}" -f ((Snapshot | ForEach-Object { Esc $_ }) -join ' , '))
    Out ''

    $ZF = $RegFs + '\Zdroj'
    $ZK = 'Zdroj\' + $K
    $t = Into-Text 1067 $MoveTmpl ($ZK + '\Z')
    Row-Op 'LINKMOVE' 728 $ZF $FocusK ('\' + $RegFull + '\Cil\') @(2) { param($r); Kept-Row 'LINKMOVE' $ZK $r (First-Is $r $t) $t }
    Row-Op 'LINKALIAS' 728 $ZF $FocusK ('\' + $RegUsers + '\Cil\') @(2) { param($r); Kept-Row 'LINKALIAS' $ZK $r (First-Is $r $t) $t }
    $tc = Into-Text 1065 $CopyTmpl ($ZK + '\Z')
    Row-Op 'LINKCOPY' 727 $ZF $FocusK ('\' + $RegFull + '\Cil\') @(2) { param($r); Kept-Row 'LINKCOPY' $ZK $r (First-Is $r $tc) $tc }
    Row-Op 'LINKOK' 728 $ZF $FocusK ('\' + $RegFull + '\Cil\') @(1) {
        param($r)
        Kept-Row 'LINKOK' $ZK $r (First-Is $r $t) $t
        $link = (ValsOf ('Cil\' + $K)) -ceq 'a=1' -and @($r.Snap1 | Where-Object { $_ -ceq ('Cil\' + $K + '\Z|-> ' + $ZK) }).Count -eq 1
        Row 'LINKOK' 'TARGET' (V ($link -and $r.Boxes.Count -eq 1)) ("Cil\<K> holds a = 1 and the link to the source unchanged: {0}; {1}" -f $link, (Box-Facts $r))
    }
    $tu = Into-Text 1067 $MoveTmpl ('Hore\' + $K + '\U')
    Row-Op 'LINKUP' 728 ($RegFs + '\Hore') $FocusK ('\' + $RegFull + '\Cil2\') @(2) { param($r); Kept-Row 'LINKUP' 'Hore' $r (First-Is $r $tu) $tu }
    Row-Op 'LINKDANGLE' 728 $ZF $FocusK ('\' + $RegFull + '\Cil5\') @(2) { param($r); Kept-Row 'LINKDANGLE' $ZK $r (First-Has $r $OpenErr) $OpenErr }
    Row-Op 'LINKTOP' 728 $ZF $FocusK ('\' + $RegFull + '\Cil6\') @(2) {
        param($r)
        Kept-Row 'LINKTOP' $ZK $r (First-Has $r $OpenErr) $OpenErr
        Row 'LINKTOP' 'ALL' (V $r.Unchanged) ("the whole fixture unchanged: {0}" -f $r.Unchanged)
    }
    Row-Op 'LINKUPOK' 728 ($RegFs + '\Plochy') $FocusK ('\' + $RegFull + '\Cil3\') $null {
        param($r)
        $followed = (ValsOf 'Plochy') -ceq 'u=2' -and (ValsOf ('Cil3\' + $K)) -ceq 'a=1'
        $gone = -not (Has-Key ('Plochy\' + $K))
        Row 'LINKUPOK' 'STATE' (V ($followed -and $gone -and $r.Boxes.Count -eq 0)) ("followed as before: {0}; source gone: {1}; {2}; keys: {3}" -f $followed, $gone, (Box-Facts $r), $r.State)
    }
    Row-Op 'LINKOTHER' 728 $ZF $FocusK ('\' + $RegFull + '\Cil4\') $null {
        param($r)
        $followed = (ValsOf 'Jinde') -ceq 'z=9' -and (ValsOf ('Cil4\' + $K)) -ceq 'a=1'
        $gone = -not (Has-Key $ZK)
        Row 'LINKOTHER' 'STATE' (V ($followed -and $gone -and $r.Boxes.Count -eq 0)) ("followed as before: {0}; source gone: {1}; {2}; keys: {3}" -f $followed, $gone, (Box-Facts $r), $r.State)
    }
    Row-Op 'MOVE' 728 $ZF $FocusK ('\' + $RegFull + '\Prazdny\') $null {
        param($r)
        $moved = (ValsOf ('Prazdny\' + $K)) -ceq 'a=1' -and (ValsOf ('Prazdny\' + $K + '\Z')) -ceq 'z=9'
        $gone = -not (Has-Key $ZK)
        Row 'MOVE' 'STATE' (V ($moved -and $gone -and $r.Boxes.Count -eq 0)) ("moved whole: {0}; source gone: {1}; {2}; keys: {3}" -f $moved, $gone, (Box-Facts $r), $r.State)
    }
    # rows of the review of 296 (its scratch probe, moved here)
    $tg = Into-Text 1067 $MoveTmpl ('G\H\' + $K + '\U')
    Row-Op 'LINKGRAND' 728 ($RegFs + '\G\H') $FocusK ('\' + $RegFull + '\CilG\') @(2) { param($r); Kept-Row 'LINKGRAND' 'G' $r (First-Is $r $tg) $tg }
    $td = Into-Text 1067 $MoveTmpl ('D\' + $K + '\A\B')
    Row-Op 'LINKDEEP' 728 ($RegFs + '\D') $FocusK ('\' + $RegFull + '\CilD\') @(2) { param($r); Kept-Row 'LINKDEEP' 'D' $r (First-Is $r $td) $td }
    Row-Op 'LINKCHAIN' 728 $ZF $FocusK ('\' + $RegFull + '\CilC\') @(2) { param($r); Kept-Row 'LINKCHAIN' $ZK $r (First-Is $r $t) $t }
    Row-Op 'RENAMEDANGLE' 754 ($RegFs + '\Q') $FocusK 'R' @(2) {
        param($r)
        Kept-Row 'RENAMEDANGLE' 'Q' $r (First-Has $r $OpenErr) $OpenErr
        Row 'RENAMEDANGLE' 'ALL' (V $r.Unchanged) ("the whole fixture unchanged: {0}; pre '{1}'" -f $r.Unchanged, (Esc $r.Pre))
    }
    Row-Op 'RENAME' 754 ($RegFs + '\Q') $FocusK 'Nove3' $null {
        param($r)
        $moved = (ValsOf 'Q\Nove3') -ceq 'a=1' -and (ValsOf 'Q\Nove3\Z') -ceq 'z=9'
        $gone = -not (Has-Key ('Q\' + $K))
        Row 'RENAME' 'STATE' (V ($moved -and $gone -and $r.Boxes.Count -eq 0)) ("renamed whole: {0}; old gone: {1}; {2}; keys: {3}" -f $moved, $gone, (Box-Facts $r), $r.State)
    }
    # the merged HKEY_CLASSES_ROOT view (review of 296, SHOULD 1)
    Use-Fixture 'classes'
    $tk = (Template 1067 $MoveTmpl).Replace('%ls', ('HKEY_CLASSES_ROOT\' + $ClsName + '\' + $ZK + '\Z'))
    Row-Op 'HKCRMOVE' 728 ('reg:\HKEY_CLASSES_ROOT\' + $ClsName + '\Zdroj') $FocusK ('\HKEY_CLASSES_ROOT\' + $ClsName + '\Cil\') @(2) { param($r); Kept-Row 'HKCRMOVE' $ZK $r (First-Is $r $tk) $tk }
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
