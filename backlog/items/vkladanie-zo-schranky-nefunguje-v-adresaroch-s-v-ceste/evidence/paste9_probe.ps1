<#
.SYNOPSIS
    GitHub #9 probe: Paste (Ctrl+V / Edit > Paste, command 775) into a folder whose path contains '!'.

.DESCRIPTION
    Fixture per row under %TEMP%\tc9\<row>: a source folder holding x.txt and a target folder. The
    program starts with the source in the left panel (active).
      TC-*   the program's own clipboard: Home, Down focuses x.txt; Copy (773); Change Directory of
             the same panel to the target; Paste (775)
      EX-*   a file list put on the clipboard by the probe (CF_HDROP, as Explorer copies); the left
             panel shows the target; Paste (775)
      *-TGT  the target has '!' in its name ("t!x"); *-SRC  the source has it ("s!rc");
      *-CTL  neither (the control)
    PASS = x.txt exists in the target after the paste, with its content. The user's clipboard text is
    saved and restored (098's helpers); when the clipboard holds anything else the rows are NOT DRIVEN.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
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

. 'E:\Projects\tandemcommander\specs\098-long-path-overruns\probe\fix_probe_lib.ps1'
$Root = $TempRoot + '\tc9'
$StartDir = $Root + '\start'

# F5 into the same folder under a new name typed into the Copy dialog: the copy engine opens a
# target "<dir>\x - K<o-acute>pia.txt" in a folder named $Dir - what the paste of GitHub #9 did
function Run-F5([string]$Case, [string]$Dir) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case + '\' + $Dir
    NewDir $d
    [IO.File]::WriteAllText($LP + $d + '\x.txt', 'X9')
    $newName = 'x - K' + [char]0x00F3 + 'pia.txt'
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $d
        [void](Serve $id 5)
        Key $id 0x24; Key $id 0x28
        Start-Sleep -Milliseconds 500
        $dlg = Open-ByCmd $id 727 15
        if ($dlg -eq [IntPtr]::Zero) { throw 'the Copy dialog did not open' }
        $fld = Find-Ctl $dlg 210; if ($fld -eq [IntPtr]::Zero) { throw 'the target field was not found' }
        [void][Drv098f]::SetText($fld, ($d + '\' + $newName), 5000)
        Click-Ok $dlg
        Start-Sleep -Milliseconds 800
        $r = Serve $id 30 @(1, 6)
        End-Row $Case $id $null $before; $id = 0
        $f = $d + '\' + $newName
        $there = [IO.File]::Exists($LP + $f)
        $ok = $there -and ([IO.File]::ReadAllText($LP + $f) -eq 'X9')
        Row $Case 'RUN' (V $ok) ("copy named x - K(o-acute)pia.txt exists: {0}; windows: {1}" -f $there, (Msgs $r))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

function Run-Case([string]$Case, [string]$Route, [string]$SrcName, [string]$TgtName) {
    if (-not (Want $Case)) { return }
    if (-not $script:ClipOk) { Row $Case 'RUN' 'NOT DRIVEN' 'the clipboard cannot be opened from this session (hidden desktop)'; return }
    $d = $Root + '\' + $Case
    $src = $d + '\' + $SrcName
    $tgt = $d + '\' + $TgtName
    NewDir $src; NewDir $tgt
    [IO.File]::WriteAllText($LP + $src + '\x.txt', 'X9')
    $id = 0; $before = Reports
    try {
        if ($Route -eq 'EX') {
            $list = New-Object System.Collections.Specialized.StringCollection
            [void]$list.Add($src + '\x.txt')
            [Windows.Forms.Clipboard]::SetFileDropList($list)
            $id = Start-Tc $tgt
            [void](Serve $id 5)
            Post-Cmd (Get-Main $id) 775
        }
        else {
            $id = Start-Tc $src
            [void](Serve $id 5)
            Key $id 0x24; Key $id 0x28
            Start-Sleep -Milliseconds 500
            Post-Cmd (Get-Main $id) 773
            Start-Sleep -Milliseconds 1200
            $held = Do-ChangeDir $id $tgt
            if (-not $held) { throw 'Change Directory did not take the target path' }
            Start-Sleep -Milliseconds 800
            Post-Cmd (Get-Main $id) 775
        }
        Start-Sleep -Milliseconds 800
        $r = Serve $id 30 @(1, 6)
        Start-Sleep -Milliseconds 1500
        $loc = Get-Loc $id
        End-Row $Case $id $null $before; $id = 0
        $f = $tgt + '\x.txt'
        $there = [IO.File]::Exists($LP + $f)
        $ok = $there -and ([IO.File]::ReadAllText($LP + $f) -eq 'X9')
        Row $Case 'RUN' (V $ok) ("target holds x.txt: {0}; panel at {1}; windows: {2}" -f $there, $loc, (Msgs $r))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc9_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Save-Clip
    Out ("paste9_probe (GitHub #9) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; ACP {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [Drv098f]::GetACP())
    Out ''
    Run-F5 'F5-BANG' '!!temp'
    Run-F5 'F5-CTL' 'temp'
    Run-Case 'TC-CTL' 'TC' 'src' 'tgt'
    Run-Case 'TC-TGT' 'TC' 'src' 't!x'
    Run-Case 'TC-SRC' 'TC' 's!rc' 'tgt'
    Run-Case 'EX-CTL' 'EX' 'src' 'tgt'
    Run-Case 'EX-TGT' 'EX' 'src' 't!x'
    Run-Case 'EX-SRC' 'EX' 's!rc' 'tgt'
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    Restore-Clip
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ('Fixture: ' + $_.Exception.Message) }
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, @($Started | Where-Object { Test-Alive $_ }).Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
