<#
.SYNOPSIS
    Feature 259 probe: Edit New File (Shift+F4, command 744) with paths over 259 bytes - created
    whole, or refused for a reason that is true; never a cut name.

.DESCRIPTION
    Rows (names for -Only); every row starts its own instance in English and ends it:

      SHORT   the control: the panel in a short folder, "n.txt" typed - created
      REL     the panel in a folder whose path is 288+ bytes, "n.txt" typed (relative) - created
      ABS     the panel in a short folder, the full 290+ byte path of a file in the deep folder typed
      CJK     the panel in a short folder, a name of 100 CJK letters + ".txt" typed (304 bytes)
      OVER    the panel in a short folder, 256 CJK letters + ".txt" typed (more than a file system
              takes): nothing created, a refusal shown

    The editor of the run is rundll32.exe without arguments (it ends at once, no window); the
    file is created before the editor starts, so the verdict reads the folder.

    MUST run through tools\run_on_hidden_desktop.ps1; refuses while tandemcommander.exe runs;
    the product's registry key is exported, restored and SHA-256-verified. Exit code = FAIL rows.
.NOTES
    Windows PowerShell 5.1 compatible; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')

$Root = $TempRoot + '\tc259'
$StartDir = $Root + '\start'
$Cjk = [string][char]0x4E2D
$Seg = 'd' * 60
$Deep = $Root + '\deep\' + $Seg + '\' + $Seg + '\' + $Seg + '\' + $Seg
$Deep2 = $Root + '\deep2\' + $Seg + '\' + $Seg + '\' + $Seg + '\' + $Seg   # ABS: its own folder (REL leaves n.txt in $Deep)

function Start-P([string]$Left) {
    $a = @('-t', 'T259', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $StartDir), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    if ((Get-Process -Id $p.Id).Path -ine $Exe) { throw "pid $($p.Id) is not $Exe" }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    [void][Drv098f]::Send((Get-Main $p.Id), 0, 0, 0, 20000)
    Start-Sleep -Milliseconds 1500
    return $p.Id
}
function Dialogs([int]$Id) { return @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and [Drv098f]::IsWindowEnabled($_) -and [Drv098f]::IsWindowVisible($_) }) }
function Short([string]$t) { $e = [regex]::Replace((Esc $t), '(?:\\u4E2D){8,}', '<CJK letters>'); $e = [regex]::Replace($e, '(?:d){20,}', '<d...>'); if ($e.Length -le 420) { return $e }; return ($e.Substring(0, 420) + ' ...') }

# answers every dialog until none shows for $Quiet seconds: OK / Yes by id, else Close / Cancel.
# The text is typed into the first dialog with an edit; an edit dialog that comes back is cancelled.
function Answer([int]$Id, [string]$Type, [double]$Seconds = 60, [double]$Quiet = 4) {
    $texts = @(); $sw = [Diagnostics.Stopwatch]::StartNew(); $last = [Diagnostics.Stopwatch]::StartNew(); $typed = $false
    while ($sw.Elapsed.TotalSeconds -lt $Seconds -and $last.Elapsed.TotalSeconds -lt $Quiet -and (Test-Alive $Id)) {
        $acted = $false
        foreach ($h in (Dialogs $Id)) {
            $bs = Buttons $h
            if ($bs.Count -eq 0) { continue }
            Start-Sleep -Milliseconds 500
            $desc = WinDesc $h
            if ($desc -match $FatalRx) { $texts += ('FATAL ' + (Tail $desc 300)); return $texts }
            $edits = @([Drv098f]::Kids($h) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' -and [Drv098f]::IsWindowVisible($_) })
            $isMsg = (@([Drv098f]::Kids($h) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 2477 }).Count -gt 0)
            if (-not $isMsg -and $edits.Count -and -not $typed) {
                [void][Drv098f]::SetText($edits[0], $Type, 5000); $typed = $true
                $texts += ('typed into [' + (Tail ([Drv098f]::Txt($h)) 40) + ']'); Click-Ok $h; $acted = $true; break
            }
            if (-not $isMsg -and $edits.Count) { $texts += ('[' + (Tail ([Drv098f]::Txt($h)) 40) + '] came back - cancelled'); Close-Win $h; $acted = $true; break }
            $b = $null
            foreach ($w in @(1, 6)) { if (-not $b) { $b = $bs | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $w } | Select-Object -First 1 } }
            $texts += (Short $desc)
            if ($b) { Click $b } else { Close-Win $h }
            $acted = $true
            break
        }
        if ($acted) { $last.Restart(); Start-Sleep -Milliseconds 900 } else { Start-Sleep -Milliseconds 250 }
    }
    return $texts
}
function Names([string]$Dir) {
    if (-not [IO.Directory]::Exists($LP + $Dir)) { return @() }
    return @([IO.Directory]::GetFileSystemEntries($LP + $Dir) | Where-Object { [IO.File]::Exists($_) } | ForEach-Object { $_.Substring(($LP + $Dir).Length + 1) })
}
function Describe([string[]]$Names, [string]$Want) {
    if (-not $Names.Count) { return 'no file' }
    return (($Names | ForEach-Object { if ($_ -ceq $Want) { 'the expected name (' + (U8Len $_) + ' bytes)' } else { "'" + (Short $_) + "' (" + $_.Length + ' letters, ' + (U8Len $_) + ' bytes)' } }) -join ', ')
}

# one row: the panel in $Panel, $Type typed; $Dir is the folder the verdict reads, $Want the name
# expected there ($null: no file may appear and a refusal must be shown)
function Row-Do([string]$Case, [string]$Panel, [string]$Type, [string]$Dir, [string]$Want) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0
    try {
        if (-not $Panel.StartsWith($Root + '\') -or -not $Dir.StartsWith($Root + '\')) { throw 'a path outside the fixture' }
        if ([IO.Path]::IsPathRooted($Type) -and -not $Type.StartsWith($Root + '\')) { throw 'a typed path outside the fixture' }
        NewDir $Panel; NewDir $Dir
        $id = Start-P $Panel
        Post-Cmd (Get-Main $id) 744; Start-Sleep -Milliseconds 700
        $texts = @(Answer $id $Type)
        [void][Drv098f]::Send((Get-Main $id), 0, 0, 0, 20000)
        $names = [string[]]@(Names $Dir)
        if ($Want) {
            $ok = ($names.Count -eq 1 -and $names[0] -ceq $Want)
            $facts = ("typed {0} bytes ({1}); the folder ({2} bytes) holds {3}" -f (U8Len $Type), (Short $Type), (U8Len $Dir), (Describe $names $Want))
        }
        else {
            $said = [bool](@($texts | Where-Object { $_ -match 'too long|Too long' }).Count)   # the refusal must say why
            $ok = ($names.Count -eq 0 -and $said)
            $facts = ("typed {0} bytes; the folder holds {1}; a refusal shown {2}" -f (U8Len $Type), (Describe $names ''), $said)
        }
        Row $Case 'ROW' (V $ok) ("{0}; dialogs: {1}" -f $facts, $(if ($texts.Count) { $texts -join ' || ' } else { 'none' }))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { $fatal = Fatal-Win $id; End-Row $Case $id $fatal $before } }
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc259_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("editnew259_probe (feature 259) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; registry key existed {3}; export SHA-256 {4}; deep folder {5} bytes" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), $existed, $regHash, (U8Len $Deep))
    Out ''
    & cmd.exe /c "reg query `"$RegKey\0.1\Configuration`" >nul 2>&1"
    if ($LASTEXITCODE -ne 0) {
        # without a configuration the program would start its default editor (notepad.exe)
        foreach ($c in @('SHORT', 'REL', 'ABS', 'CJK', 'OVER')) { if (Want $c) { Row $c 'ROW' 'NOT DRIVEN' 'no configuration in the registry - the editor of the run cannot be set' } }
    }
    else {
        $ed = "$RegKey\0.1\Editors\1"
        & reg.exe delete "$RegKey\0.1\Editors" /f 2>$null | Out-Null
        & reg.exe add $ed /v 'Masks' /t REG_SZ /d '*.*' /f | Out-Null
        & reg.exe add $ed /v 'Command' /t REG_SZ /d ($env:SystemRoot + '\System32\rundll32.exe') /f | Out-Null
        & reg.exe add $ed /v 'Arguments' /t REG_SZ /d '' /f | Out-Null
        & reg.exe add $ed /v 'Initial Directory' /t REG_SZ /d $env:SystemRoot /f | Out-Null
        $cjk100 = ($Cjk * 100) + '.txt'
        $cjk256 = ($Cjk * 256) + '.txt'
        Row-Do 'SHORT' ($Root + '\short') 'n.txt' ($Root + '\short') 'n.txt'
        Row-Do 'REL' $Deep 'n.txt' $Deep 'n.txt'
        Row-Do 'ABS' ($Root + '\abs') ($Deep2 + '\a.txt') $Deep2 'a.txt'
        Row-Do 'CJK' ($Root + '\cjk') $cjk100 ($Root + '\cjk') $cjk100
        Row-Do 'OVER' ($Root + '\over') $cjk256 ($Root + '\over') $null
    }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } }
    catch { Out ("Fixture: could not delete $Root : " + $_.Exception.Message) }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, $leftover.Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
