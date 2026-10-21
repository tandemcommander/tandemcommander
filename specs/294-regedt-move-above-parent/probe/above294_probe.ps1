<#
.SYNOPSIS
    Feature 294 probe: the Registry Editor plug-in's Move (F6) / Copy (F5) of a key into the key that
    holds its own parent, the moved key holding a subkey of its own name.

.DESCRIPTION
    Fixture (created before each row, removed at the end): HKCU\Software\TcProbe294 with
      Zdroj\<K>                 a = 1     (the target key: the parent of the moved key)
      Zdroj\<K>\<K>             b = 2     (the moved key)
      Zdroj\<K>\<K>\<K>         x = 3     (its subkey of its own name - the only copy of x)
      Hloub\<K>\<M>\<K>         b = 2     (the moved key, two elements below the target Hloub\<K>)
      Hloub\<K>\<M>\<K>\<M>\<K> x = 3     (the chain <M>\<K> repeated below it)
      Plochy\<K>                a = 1
      Plochy\<K>\<K>            b = 2     (the moved key, no subkey of its own name)
      Plochy\<K>\<K>\Q          q = 4
      <Cil>                     empty     (a real other target)
    <K> = "Klic", <M> = "Mezi", <Cil> = "Cil rx", each with its Czech accents.
    <U> = \HKEY_USERS\<the user's own SID> - the same keys as \HKEY_CURRENT_USER.

      ABOVEMOVE   F6 of Zdroj\<K>\<K> into HKCU\...\Zdroj\ (target Zdroj\<K> = the source's parent),
                  Cancel: refused with "Name: <K> ... Can't move a key to itself." (1067); unchanged
      ABOVEALIAS  the same with the target written as <U>\...\Zdroj\: refused (1067); unchanged
      ABOVECOPY   F5 of the same into HKCU\...\Zdroj\: refused with 1065 naming <K>; unchanged (the
                  copy wrote into the source tree before)
      ABOVEDEEP   F6 of Hloub\<K>\<M>\<K> into HKCU\...\Hloub\ (target Hloub\<K>, the source two
                  elements below it, the chain <M>\<K> repeated): refused (1067); unchanged
      ABOVEOK     F6 of the same with OK in the box (skip the key): nothing written, unchanged
      FLATTEN     (control) F6 of Plochy\<K>\<K> into HKCU\...\Plochy\: no box; Plochy\<K> holds
                  a = 1, b = 2 and Q (q = 4); Plochy\<K>\<K> is gone (the merge stays allowed)
      FLATCOPY    (control) F5 of the same: no box; Plochy\<K> holds a, b and Q; the source keeps b, Q
      MOVE        (regression) F6 of Zdroj\<K>\<K> into HKCU\...\<Cil>\: moved whole (with x), no box
      MOVESELF    (regression) F6 of Zdroj\<K>\<K> into HKCU\...\Zdroj\<K>\<K>\<K>\, Cancel: 1067
      END         each instance ends with exit code 0, no stray window, no report

    On a build without the fix (-Expect before) ABOVEMOVE / ABOVEALIAS / ABOVEDEEP lose x = 3 without
    a box (the measured defect), ABOVECOPY writes into the source without a box.

    MUST run through tools\run_on_hidden_desktop.ps1; refuses while tandemcommander.exe runs;
    the product's registry key is exported, restored and SHA-256-verified. Exit code = FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Written in the style of
    specs\292-regedt-alias-move-self\probe\alias292_probe.ps1.
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

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..')).Path
$Root = $TempRoot + '\tc294'
$StartDir = $Root + '\start'
function Chars([int[]]$Codes) { return (-join ($Codes | ForEach-Object { [char]$_ })) }
# Czech names (pure ASCII source); no variable may share a name with another ignoring case
$K = 'Kl' + (Chars @(0x00ED, 0x010D))
$Mid = 'Mez' + [char]0x00ED
$Cil = 'C' + [char]0x00ED + 'l ' + [char]0x0159 + 'x'
$Sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$RegName = 'TcProbe294'
$RegSub = 'Software\' + $RegName
$RegPs = 'HKCU:\' + $RegSub
$RegFs = 'reg:\HKEY_CURRENT_USER\' + $RegSub
$RegFull = 'HKEY_CURRENT_USER\' + $RegSub
$RegUsers = 'HKEY_USERS\' + $Sid + '\' + $RegSub                 # the same key under another root

function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Kid([IntPtr]$Dlg, [int]$CtlId) { return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }) | Select-Object -First 1 }
function Start-P {
    $a = @('-t', 'T294', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
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
    $st = Kid $H 172                                             # IDS_ERROR of the question dialog
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

function New-Key([string]$PsPath) { [void](New-Item -Path $PsPath -Force) }
function Set-Val([string]$Rel, [string]$Name, [string]$Value) { [void](New-ItemProperty -LiteralPath ($RegPs + '\' + $Rel) -Name $Name -Value $Value -PropertyType String -Force) }
function Make-Fixture {
    NewDir $StartDir
    Remove-Item -LiteralPath $RegPs -Recurse -Force -ErrorAction SilentlyContinue
    New-Key ($RegPs + '\Zdroj\' + $K + '\' + $K + '\' + $K)
    Set-Val ('Zdroj\' + $K) 'a' '1'
    Set-Val ('Zdroj\' + $K + '\' + $K) 'b' '2'
    Set-Val ('Zdroj\' + $K + '\' + $K + '\' + $K) 'x' '3'
    New-Key ($RegPs + '\Hloub\' + $K + '\' + $Mid + '\' + $K + '\' + $Mid + '\' + $K)
    Set-Val ('Hloub\' + $K + '\' + $Mid + '\' + $K) 'b' '2'
    Set-Val ('Hloub\' + $K + '\' + $Mid + '\' + $K + '\' + $Mid + '\' + $K) 'x' '3'
    New-Key ($RegPs + '\Plochy\' + $K + '\' + $K + '\Q')
    Set-Val ('Plochy\' + $K) 'a' '1'
    Set-Val ('Plochy\' + $K + '\' + $K) 'b' '2'
    Set-Val ('Plochy\' + $K + '\' + $K + '\Q') 'q' '4'
    New-Key ($RegPs + '\' + $Cil)
}
# every key under the fixture key: relative path, values (sorted)
function Snapshot {
    $out = @()
    if (-not (Test-Path -LiteralPath $RegPs)) { return @('(missing)') }
    foreach ($item in @(Get-ChildItem -LiteralPath $RegPs -Recurse -ErrorAction SilentlyContinue)) {
        $rel = $item.Name.Substring($item.Name.IndexOf($RegName) + $RegName.Length + 1)
        $vals = @($item.GetValueNames() | Sort-Object | ForEach-Object { $_ + '=' + $item.GetValue($_) }) -join ';'
        $out += ('{0}|{1}' -f $rel, $vals)
    }
    return @($out | Sort-Object)
}
function Has-Key([string]$Rel) { return Test-Path -LiteralPath ($RegPs + '\' + $Rel) }
function ValueOf([string]$Rel, [string]$Name) {
    try { return (Get-ItemProperty -LiteralPath ($RegPs + '\' + $Rel) -Name $Name -ErrorAction Stop).$Name } catch { return $null }
}
# the values of one key, sorted, as 'n=v;n=v' ($null when the key is missing)
function ValsOf([string]$Rel) {
    $p = $RegPs + '\' + $Rel
    if (-not (Test-Path -LiteralPath $p)) { return $null }
    $item = Get-Item -LiteralPath $p
    return (@($item.GetValueNames() | Sort-Object | ForEach-Object { $_ + '=' + $item.GetValue($_) }) -join ';')
}
# the number of keys holding the value x = 3 (the only copy in the fixture)
function Count-X {
    return @(Get-ChildItem -LiteralPath $RegPs -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.GetValue('x') -ceq '3' }).Count
}

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
        $r.Unchanged = (($snap0 -join "`n") -ceq ($snap1 -join "`n"))
        $r.State = (($snap1 | ForEach-Object { Esc $_ }) -join ' , ')
        $r.X = Count-X
        & $Judge $r
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { Close-Boxes $id; End-P $Case $id $before } }
}

function Box-Facts($r) {
    if (-not $r.Boxes.Count) { return 'boxes: none' }
    return ('boxes: ' + (($r.Boxes | ForEach-Object { "{0}; text '{1}'" -f $_.Desc, (Esc $_.Text) }) -join ' || '))
}
# the first box is exactly $Text
function First-Is($r, [string]$Text) { return ($r.Boxes.Count -ge 1) -and ($null -ne $r.Boxes[0].Text) -and ($r.Boxes[0].Text.Trim() -ceq $Text.Trim()) }
$MoveInto = (Template 1067 "Name:`t%ls`n`nError:`tCan't move a key to itself.").Replace('%ls', $K)
$CopyInto = (Template 1065 "Name:`t%ls`n`nError:`tCan't copy a key to itself.").Replace('%ls', $K)
$FocusK = @(0x24, 0x28)                                            # "..", then <K> (the only key)

function Refused-Row([string]$Case, [string]$Text, $r) {
    Row $Case 'TEXT' (V (First-Is $r $Text)) ("expected the first box '{0}'; {1}" -f (Esc $Text), (Box-Facts $r))
    Row $Case 'STATE' (V $r.Unchanged) ("fixture unchanged: {0}; keys holding x=3: {1}; keys: {2}" -f $r.Unchanged, $r.X, $r.State)
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc294_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    Make-Fixture
    Set-Config
    Set-Lang ($Lang + '.slg')
    Out ("above294_probe (feature 294), expect: {0}, language: {1}" -f $Expect, $Lang)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; registry key existed {3}; export SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), $existed, $regHash)
    Out ("Alias   : \{0} = \{1}" -f $RegUsers, $RegFull)
    Out ("Fixture : {0}" -f ((Snapshot | ForEach-Object { Esc $_ }) -join ' , '))
    Out ''

    $ZK = $RegFs + '\Zdroj\' + $K
    Row-Op 'ABOVEMOVE' 728 $ZK $FocusK ('\' + $RegFull + '\Zdroj\') @(2) { param($r); Refused-Row 'ABOVEMOVE' $MoveInto $r }
    Row-Op 'ABOVEALIAS' 728 $ZK $FocusK ('\' + $RegUsers + '\Zdroj\') @(2) { param($r); Refused-Row 'ABOVEALIAS' $MoveInto $r }
    Row-Op 'ABOVECOPY' 727 $ZK $FocusK ('\' + $RegFull + '\Zdroj\') @(2) { param($r); Refused-Row 'ABOVECOPY' $CopyInto $r }
    $HKM = $RegFs + '\Hloub\' + $K + '\' + $Mid
    Row-Op 'ABOVEDEEP' 728 $HKM $FocusK ('\' + $RegFull + '\Hloub\') @(2) { param($r); Refused-Row 'ABOVEDEEP' $MoveInto $r }
    Row-Op 'ABOVEOK' 728 $HKM $FocusK ('\' + $RegFull + '\Hloub\') @(1) { param($r); Refused-Row 'ABOVEOK' $MoveInto $r }
    $PK = $RegFs + '\Plochy\' + $K
    Row-Op 'FLATTEN' 728 $PK $FocusK ('\' + $RegFull + '\Plochy\') $null {
        param($r)
        $merged = (ValsOf ('Plochy\' + $K)) -ceq 'a=1;b=2' -and (ValsOf ('Plochy\' + $K + '\Q')) -ceq 'q=4'
        $gone = -not (Has-Key ('Plochy\' + $K + '\' + $K))
        Row 'FLATTEN' 'STATE' (V ($merged -and $gone -and $r.Boxes.Count -eq 0)) ("merged: {0}; source gone: {1}; {2}; keys: {3}" -f $merged, $gone, (Box-Facts $r), $r.State)
    }
    Row-Op 'FLATCOPY' 727 $PK $FocusK ('\' + $RegFull + '\Plochy\') $null {
        param($r)
        $merged = (ValsOf ('Plochy\' + $K)) -ceq 'a=1;b=2' -and (ValsOf ('Plochy\' + $K + '\Q')) -ceq 'q=4'
        $kept = (ValsOf ('Plochy\' + $K + '\' + $K)) -ceq 'b=2' -and (ValsOf ('Plochy\' + $K + '\' + $K + '\Q')) -ceq 'q=4'
        Row 'FLATCOPY' 'STATE' (V ($merged -and $kept -and $r.Boxes.Count -eq 0)) ("merged: {0}; source kept: {1}; {2}; keys: {3}" -f $merged, $kept, (Box-Facts $r), $r.State)
    }
    Row-Op 'MOVE' 728 $ZK $FocusK ('\' + $RegFull + '\' + $Cil + '\') $null {
        param($r)
        $moved = (ValsOf ($Cil + '\' + $K)) -ceq 'b=2' -and (ValsOf ($Cil + '\' + $K + '\' + $K)) -ceq 'x=3'
        $gone = -not (Has-Key ('Zdroj\' + $K + '\' + $K))
        Row 'MOVE' 'STATE' (V ($moved -and $gone -and $r.Boxes.Count -eq 0)) ("moved whole: {0}; source gone: {1}; {2}; keys: {3}" -f $moved, $gone, (Box-Facts $r), $r.State)
    }
    Row-Op 'MOVESELF' 728 $ZK $FocusK ('\' + $RegFull + '\Zdroj\' + $K + '\' + $K + '\' + $K + '\') @(2) { param($r); Refused-Row 'MOVESELF' $MoveInto $r }
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
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture keys removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, $leftover.Count, (-not (Test-Path -LiteralPath $RegPs)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
