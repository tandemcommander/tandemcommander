<#
.SYNOPSIS
    Feature 292 probe: the Registry Editor plug-in's Move (F6) / Copy (F5) of a key or a value onto
    itself (or into itself) through another root name of the same key.

.DESCRIPTION
    Fixture (created before each row, removed at the end): HKCU\Software\TcProbe292 with
      Zdroj\<K>          value v = ALPHA, subkey <P> with value w = BETA (the key copied or moved)
      <Cil>              empty (a real other target)
    and HKCU\Software\Classes\TcProbe292\Zdroj\<K> with value v = ALPHA, subkey <P> w = BETA (seen
    as HKEY_CLASSES_ROOT\TcProbe292\... through the merged view).
    <K> = "Klic zlutoucky", <P> = "podklic", <Cil> = "Cil rx", each with its Czech accents.
    <U> = \HKEY_USERS\<the user's own SID> - the same keys as \HKEY_CURRENT_USER.

      ALIASMOVE   F6 of <K> into <U>\Software\TcProbe292\Zdroj\ (its own parent), overwrite answered
                  All: refused with "Can't move key or value to itself." (1066); nothing changed
      ALIASCOPY   F5 of the same: refused with "Can't copy key or value to itself." (1053); unchanged
      ALIASINTO   F6 of <K> into <U>\...\Zdroj\<K>\<P>\ (inside itself), Cancel: the message names
                  <K> (1067); nothing changed
      ALIASVALUE  F6 of the value v of Zdroj\<K> into <U>\...\Zdroj\<K>\, answered All: refused (1066);
                  v keeps ALPHA
      HKCRMOVE    F6 of HKCU\Software\Classes\TcProbe292\Zdroj\<K> into
                  \HKEY_CLASSES_ROOT\TcProbe292\Zdroj\, answered All: refused (1066); unchanged
      HKCRROOT    F6 of HKEY_CLASSES_ROOT\TcProbe292 (only in the user's half; focused by Backspace
                  from it) into \HKEY_CURRENT_USER\Software\Classes\, Cancel: the key is refused by its
                  own identity (1067 naming TcProbe292); unchanged
      HKCRBOTH    F6 of a real extension key held by both halves (HKCU and HKLM Software\Classes; only
                  read) at the HKCR root into \HKEY_LOCAL_MACHINE\Software\Classes\, Cancel: refused
                  by its machine identity (1067); its user half unchanged. Not run elevated
      ALIASRENAME (control) F6 of <K> into <U>\...\Zdroj\<N> (no such key, no trailing backslash):
                  no box; Zdroj\<N> holds v and <P>\w; Zdroj\<K> is gone (a rename stays allowed)
      ALIASOTHER  (control) F6 of <K> into <U>\...\<Cil>\: no box; moved whole; the source is gone
      MOVE        (regression, same root) F6 of <K> into HKCU\...\<Cil>\: moved whole, no box
      MOVESELF    (regression, same root) F6 of <K> into HKCU\...\Zdroj\<K>\<P>\, Cancel: 1067
      SAMEMOVE    (regression, same root) F6 of <K> into HKCU\...\Zdroj\: refused (1066); unchanged
      END         each instance ends with exit code 0, no stray window, no report

    On a build without the fix (-Expect before) ALIASMOVE / ALIASVALUE / HKCRMOVE delete the data
    (the measured defect), ALIASCOPY / ALIASINTO show no refusal.

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
$Root = $TempRoot + '\tc292'
$StartDir = $Root + '\start'
function Chars([int[]]$Codes) { return (-join ($Codes | ForEach-Object { [char]$_ })) }
# Czech names (pure ASCII source); no variable may share a name with another ignoring case
$K = 'Kl' + (Chars @(0x00ED, 0x010D)) + ' ' + [char]0x017E + 'lu' + [char]0x0165 + 'ou' + [char]0x010D + 'k' + [char]0x00FD
$Sub = 'podkl' + (Chars @(0x00ED, 0x010D))
$Cil = 'C' + [char]0x00ED + 'l ' + [char]0x0159 + 'x'
$NewName = 'Nov' + [char]0x00FD + ' n' + [char]0x00E1 + 'zev'
$Sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$RegName = 'TcProbe292'
$RegSub = 'Software\' + $RegName
$RegPs = 'HKCU:\' + $RegSub
$RegFs = 'reg:\HKEY_CURRENT_USER\' + $RegSub
$RegFull = 'HKEY_CURRENT_USER\' + $RegSub
$RegUsers = 'HKEY_USERS\' + $Sid + '\' + $RegSub                 # the same key under another root
$ClsSub = 'Software\Classes\' + $RegName
$ClsPs = 'HKCU:\' + $ClsSub
$ClsFs = 'reg:\HKEY_CURRENT_USER\' + $ClsSub
$ClsRoot = 'HKEY_CLASSES_ROOT\' + $RegName                        # ... and through the merged view

function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Kid([IntPtr]$Dlg, [int]$CtlId) { return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }) | Select-Object -First 1 }
function Start-P {
    $a = @('-t', 'T292', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
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
function Make-Fixture {
    NewDir $StartDir
    foreach ($top in @($RegPs, $ClsPs)) { Remove-Item -LiteralPath $top -Recurse -Force -ErrorAction SilentlyContinue }
    foreach ($top in @($RegPs, $ClsPs)) {
        New-Key ($top + '\Zdroj\' + $K + '\' + $Sub)
        [void](New-ItemProperty -LiteralPath ($top + '\Zdroj\' + $K) -Name 'v' -Value 'ALPHA' -PropertyType String -Force)
        [void](New-ItemProperty -LiteralPath ($top + '\Zdroj\' + $K + '\' + $Sub) -Name 'w' -Value 'BETA' -PropertyType String -Force)
    }
    New-Key ($RegPs + '\' + $Cil)
}
# every key under both fixture keys: relative path, values (sorted)
function Snapshot {
    $out = @()
    foreach ($top in @($RegPs, $ClsPs)) {
        $tag = $(if ($top -eq $RegPs) { 'S' } else { 'C' })
        if (-not (Test-Path -LiteralPath $top)) { $out += ($tag + ':(missing)'); continue }
        foreach ($item in @(Get-ChildItem -LiteralPath $top -Recurse -ErrorAction SilentlyContinue)) {
            $rel = $item.Name.Substring($item.Name.IndexOf($RegName) + $RegName.Length + 1)
            $vals = @($item.GetValueNames() | Sort-Object | ForEach-Object { $_ + '=' + $item.GetValue($_) }) -join ';'
            $out += ('{0}:{1}|{2}' -f $tag, $rel, $vals)
        }
    }
    return @($out | Sort-Object)
}
function Has-Key([string]$Rel) { return Test-Path -LiteralPath ($RegPs + '\' + $Rel) }
function ValueOf([string]$Rel, [string]$Name) {
    try { return (Get-ItemProperty -LiteralPath ($RegPs + '\' + $Rel) -Name $Name -ErrorAction Stop).$Name } catch { return $null }
}

# one Copy (727) or Move (728) from the panel path $From, the item focused by $Keys, to the typed
# target $Target; every box that comes is recorded and answered with $Answer (Cancel when none)
function Run-Op([int]$Cmd, [string]$From, [int[]]$Keys, [string]$Target, [int[]]$Answer) {
    $res = @{ Boxes = @(); Pre = $null }
    $id = Start-P
    $res.Id = $id
    if ($script:GoUpFrom) {
        Go $id $script:GoUpFrom
        Key $id 0x08                                               # Backspace: the parent, the key focused
        Sync $id; Start-Sleep -Milliseconds 1500
        $res.Loc = Get-Loc $id
    }
    else { Go $id $From }
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
        $extra0 = $(if ($script:ExtraSnap) { & $script:ExtraSnap } else { '' })
        $r = Run-Op $Cmd $From $Keys $Target $Answer
        $id = $r.Id
        $snap1 = Snapshot
        $r.ExtraKept = (($(if ($script:ExtraSnap) { & $script:ExtraSnap } else { '' })) -ceq $extra0)
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
# the first box is exactly $Text
function First-Is($r, [string]$Text) { return ($r.Boxes.Count -ge 1) -and ($null -ne $r.Boxes[0].Text) -and ($r.Boxes[0].Text.Trim() -ceq $Text.Trim()) }
$MoveSelf = Template 1066 "Can't move key or value to itself."
$CopySelf = Template 1053 "Can't copy key or value to itself."
$MoveInto = (Template 1067 "Name:`t%ls`n`nError:`tCan't move a key to itself.").Replace('%ls', $K)
$MoveIntoRoot = (Template 1067 "Name:`t%ls`n`nError:`tCan't move a key to itself.").Replace('%ls', $RegName)
$script:GoUpFrom = $null
$script:ExtraSnap = $null
$All =@(185, 6, 1)                                              # All, else Yes, else OK
$FocusK = @(0x24, 0x28)                                            # "..", then <K> (the only key)
$FocusV = @(0x23)                                                  # the last item: the value v

function Refused-Row([string]$Case, [string]$Text, $r) {
    Row $Case 'TEXT' (V (First-Is $r $Text)) ("expected the first box '{0}'; {1}" -f (Esc $Text), (Box-Facts $r))
    Row $Case 'STATE' (V $r.Unchanged) ("fixture unchanged: {0}; keys: {1}" -f $r.Unchanged, $r.State)
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc292_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    Make-Fixture
    Set-Config
    Set-Lang ($Lang + '.slg')
    Out ("alias292_probe (feature 292), expect: {0}, language: {1}" -f $Expect, $Lang)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; registry key existed {3}; export SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), $existed, $regHash)
    Out ("Alias   : \{0} = \{1}" -f $RegUsers, $RegFull)
    Out ("Fixture : {0}" -f ((Snapshot | ForEach-Object { Esc $_ }) -join ' , '))
    Out ''

    Row-Op 'ALIASMOVE' 728 ($RegFs + '\Zdroj') $FocusK ('\' + $RegUsers + '\Zdroj\') $All { param($r); Refused-Row 'ALIASMOVE' $MoveSelf $r }
    Row-Op 'ALIASCOPY' 727 ($RegFs + '\Zdroj') $FocusK ('\' + $RegUsers + '\Zdroj\') $All { param($r); Refused-Row 'ALIASCOPY' $CopySelf $r }
    Row-Op 'ALIASINTO' 728 ($RegFs + '\Zdroj') $FocusK ('\' + $RegUsers + '\Zdroj\' + $K + '\' + $Sub + '\') @(2) { param($r); Refused-Row 'ALIASINTO' $MoveInto $r }
    Row-Op 'ALIASVALUE' 728 ($RegFs + '\Zdroj\' + $K) $FocusV ('\' + $RegUsers + '\Zdroj\' + $K + '\') $All { param($r); Refused-Row 'ALIASVALUE' $MoveSelf $r }
    Row-Op 'HKCRMOVE' 728 ($ClsFs + '\Zdroj') $FocusK ('\' + $ClsRoot + '\Zdroj\') $All { param($r); Refused-Row 'HKCRMOVE' $MoveSelf $r }
    # the HKCR root lists both halves: TcProbe292 (only in the user's half) focused by going up from it
    $script:GoUpFrom = 'reg:\' + $ClsRoot
    Row-Op 'HKCRROOT' 728 'reg:\HKEY_CLASSES_ROOT' $null ('\HKEY_CURRENT_USER\Software\Classes\') @(2) { param($r); Refused-Row 'HKCRROOT' $MoveIntoRoot $r }
    # a real HKCR key held by both halves (an extension of this machine), focused at the HKCR root,
    # moved into \HKEY_LOCAL_MACHINE\Software\Classes\: refused by its machine identity (1067). Only
    # read: without elevation the machine half cannot be written (an unfixed build gets "access
    # denied" at its first write, answered Cancel), and the row refuses to run elevated
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $both = @(Get-ChildItem -LiteralPath 'HKCU:\Software\Classes' -ErrorAction SilentlyContinue | ForEach-Object { $_.PSChildName } |
              Where-Object { $_ -cmatch '^\.[a-z0-9]{2,5}$' -and (Test-Path -LiteralPath ('HKLM:\Software\Classes\' + $_)) } | Select-Object -First 1)
    if ($isAdmin) { if (Want 'HKCRBOTH') { Row 'HKCRBOTH' 'RUN' 'NOT DRIVEN' 'the probe runs elevated: the row would let an unfixed build write the machine half' } }
    elseif (-not $both.Count) { if (Want 'HKCRBOTH') { Row 'HKCRBOTH' 'RUN' 'NOT DRIVEN' 'no extension key held by both halves on this machine' } }
    else {
        $BothName = $both[0]
        $script:GoUpFrom = 'reg:\HKEY_CLASSES_ROOT\' + $BothName
        $script:ExtraSnap = { (@(Get-ChildItem -LiteralPath ('HKCU:\Software\Classes\' + $BothName) -Recurse -ErrorAction SilentlyContinue | ForEach-Object { $_.Name + '|' + (@($_.GetValueNames() | Sort-Object) -join ';') }) + @((Get-Item -LiteralPath ('HKCU:\Software\Classes\' + $BothName)).GetValueNames() | Sort-Object)) -join "`n" }
        $MoveBoth = (Template 1067 "Name:`t%ls`n`nError:`tCan't move a key to itself.").Replace('%ls', $BothName)
        Row-Op 'HKCRBOTH' 728 'reg:\HKEY_CLASSES_ROOT' $null ('\HKEY_LOCAL_MACHINE\Software\Classes\') @(2) {
            param($r)
            Row 'HKCRBOTH' 'TEXT' (V (First-Is $r $MoveBoth)) ("key '{0}' (in both halves); expected the first box '{1}'; {2}" -f $BothName, (Esc $MoveBoth), (Box-Facts $r))
            Row 'HKCRBOTH' 'STATE' (V ($r.Unchanged -and $r.ExtraKept)) ("fixture unchanged: {0}; the user's half of '{1}' unchanged: {2}" -f $r.Unchanged, $BothName, $r.ExtraKept)
        }
        $script:ExtraSnap = $null
    }
    $script:GoUpFrom = $null
    Row-Op 'ALIASRENAME' 728 ($RegFs + '\Zdroj') $FocusK ('\' + $RegUsers + '\Zdroj\' + $NewName) $null {
        param($r)
        $moved = (ValueOf ('Zdroj\' + $NewName) 'v') -ceq 'ALPHA' -and (ValueOf ('Zdroj\' + $NewName + '\' + $Sub) 'w') -ceq 'BETA'
        $gone = -not (Has-Key ('Zdroj\' + $K))
        Row 'ALIASRENAME' 'STATE' (V ($moved -and $gone -and $r.Boxes.Count -eq 0)) ("renamed whole: {0}; source gone: {1}; {2}; keys: {3}" -f $moved, $gone, (Box-Facts $r), $r.State)
    }
    Row-Op 'ALIASOTHER' 728 ($RegFs + '\Zdroj') $FocusK ('\' + $RegUsers + '\' + $Cil + '\') $null {
        param($r)
        $moved = (ValueOf ($Cil + '\' + $K) 'v') -ceq 'ALPHA' -and (ValueOf ($Cil + '\' + $K + '\' + $Sub) 'w') -ceq 'BETA'
        $gone = -not (Has-Key ('Zdroj\' + $K))
        Row 'ALIASOTHER' 'STATE' (V ($moved -and $gone -and $r.Boxes.Count -eq 0)) ("moved whole: {0}; source gone: {1}; {2}; keys: {3}" -f $moved, $gone, (Box-Facts $r), $r.State)
    }
    Row-Op 'MOVE' 728 ($RegFs + '\Zdroj') $FocusK ('\' + $RegFull + '\' + $Cil + '\') $null {
        param($r)
        $moved = (ValueOf ($Cil + '\' + $K) 'v') -ceq 'ALPHA' -and (ValueOf ($Cil + '\' + $K + '\' + $Sub) 'w') -ceq 'BETA'
        $gone = -not (Has-Key ('Zdroj\' + $K))
        Row 'MOVE' 'STATE' (V ($moved -and $gone -and $r.Boxes.Count -eq 0)) ("the dialog offered '{0}'; moved whole: {1}; source gone: {2}; {3}; keys: {4}" -f (Esc $r.Pre), $moved, $gone, (Box-Facts $r), $r.State)
    }
    Row-Op 'MOVESELF' 728 ($RegFs + '\Zdroj') $FocusK ('\' + $RegFull + '\Zdroj\' + $K + '\' + $Sub + '\') @(2) { param($r); Refused-Row 'MOVESELF' $MoveInto $r }
    Row-Op 'SAMEMOVE' 728 ($RegFs + '\Zdroj') $FocusK ('\' + $RegFull + '\Zdroj\') $All { param($r); Refused-Row 'SAMEMOVE' $MoveSelf $r }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($sp in @($Started)) { if (Test-Alive $sp) { Stop-Process -Id $sp -Force } }
    Start-Sleep -Milliseconds 600
    foreach ($top in @($RegPs, $ClsPs)) { Remove-Item -LiteralPath $top -Recurse -Force -ErrorAction SilentlyContinue }
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture keys removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, $leftover.Count, (-not ((Test-Path -LiteralPath $RegPs) -or (Test-Path -LiteralPath $ClsPs))), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
