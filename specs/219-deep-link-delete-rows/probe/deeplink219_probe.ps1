<#
.SYNOPSIS
    Feature 219: the rows 197 left not driven - F8 Delete of a DIRECTORY SYMBOLIC LINK (mklink /D)
    in a folder past MAX_PATH and past 3 * MAX_PATH, and the delete by Recycle Bin masks of a
    folder that holds a junction: only the link is removed, the target's file kept.

.DESCRIPTION
      SYM-SHALLOW   the control: a directory symbolic link L in a short folder
      SYM-DEEP      L in a folder of about 300 characters
      SYM-DEEP2     L in a folder of about 870 characters
      SYM-TREE      F8 on the deep folder that holds L (the recursion meets it)
      SYM-FOCUS     Go to Shortcut Target (838) on the deep L: the panel goes to its target (the
                    link's target stored in the long form \\?\C:\..., as every row but the next)
      SYM-FOCUS-PLAIN  the same with the target stored plain (C:\...)
      SYM-FOCUS-UNC    a short folder's link stored as \\?\UNC\localhost\C$\...: the panel goes to
                    \\localhost\C$\...
      MASK-SHALLOW  Recycle Bin by masks (*.txt): F8 on a junction J in a short folder
      MASK-TREE     Recycle Bin by masks (*.txt): F8 on a short folder holding J
      MASK-DEEPTREE Recycle Bin by masks (*.txt): F8 on the deep folder holding J
    Every box is answered Yes/OK (6, 1). PASS = the target's file is still there and the link is
    gone (or the delete refused with a message). Driver of 197's deepjunc_probe.ps1.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
    [string]$OutFile
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path 'E:\Projects\tandemcommander\specs\098-long-path-overruns\probe' 'fix_probe_lib.ps1')
$Root = $TempRoot + '\tc219'
$StartDir = $Root + '\start'
$ConfKey = 'HKCU:\Software\Tandem Commander\0.1\Configuration'

function Cmd([string]$c) {
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $o = & cmd.exe /c $c 2>&1; $rc = $LASTEXITCODE; $ErrorActionPreference = $old
    return [pscustomobject]@{ Rc = $rc; Text = (($o | ForEach-Object { "$_" }) -join ' ') }
}
function Put([string]$p, [string]$text) { [IO.File]::WriteAllText($LP + $p, $text, (New-Object Text.ASCIIEncoding)) }

function Run-Case([string]$Case, [string]$Folder, [string]$Target, [string]$Mode = 'link', [int]$Recycle = 0, [string]$Kind = 'J', [switch]$PlainTarget, [switch]$UncTarget) {
    $id = 0; $before = Reports
    try {
        NewDir $Folder; NewDir $Target; Put "$Target\precious.txt" 'PRECIOUS'
        # mklink cannot take a path over MAX_PATH: the junction is made in a short folder and the
        # deep folder is reached by renaming the parents (or by the \\?\ form)
        $j = "$Folder\$Kind"
        [void]$script:Links.Add($j)
        $tgtText = $(if ($UncTarget) { '\\?\UNC\localhost\' + $Target.Replace(':', '$') } elseif ($PlainTarget) { $Target } else { '\\?\' + $Target })   # the link's stored target: plain or the long form
        $r = Cmd ("mklink /{2} `"\\?\{0}`" `"{1}`"" -f $j, $tgtText, $Kind)
        if (-not [IO.Directory]::Exists($LP + $j)) { Row $Case 'RUN' 'NOT DRIVEN' ('mklink /' + $Kind + ' refused: ' + $r.Text); return }
        $attr = [IO.File]::GetAttributes($LP + $j)
        Set-ItemProperty -Path $ConfKey -Name 'Use Recycle Bin' -Value $Recycle -Type DWord
        $id = Start-Tc $StartDir                # (a start with an 870-character -l path showed no main window)
        $item = $(if ($Mode -eq 'tree') { $Folder } else { $j })
        [void](Do-ChangeDir $id $item)       # focus it (Change Directory to a folder enters it: go up)
        Start-Sleep -Milliseconds 300
        $loc = Get-Loc $id
        if ($loc -like ('*\' + [IO.Path]::GetFileName($item))) { Key $id 0x08; Start-Sleep -Milliseconds 500 }   # Backspace: up, the item focused
        if ($Mode -eq 'focus') {
            Post-Cmd (Get-Main $id) 838      # Go to Shortcut Target (CM_AFOCUSSHORTCUT)
            $res = Serve $id 10 @(1)
            Start-Sleep -Milliseconds 800
            $loc2 = Get-Loc $id
            $want = $(if ($UncTarget) { '\\localhost\' + $Target.Replace(':', '$') } else { $Target })
            $ok = $loc2 -ieq $want -or $loc2 -ieq ($want + '\')
            Row $Case 'RUN' (V $ok) ("folder {0} chars; the panel went to '{1}' (expected the target '{2}'); windows: {3}" -f $Folder.Length, (Tail $loc2 80), (Tail $want 60), (Tail (Msgs $res) 300))
        }
        else {
            Post-Cmd (Get-Main $id) 729      # F8 Delete
            $res = Serve $id 30 @(6, 1)
            $m = Msgs $res
            Start-Sleep -Milliseconds 800
            $kept = [IO.File]::Exists($LP + "$Target\precious.txt")
            $gone = -not [IO.Directory]::Exists($LP + $item)
            # the Recycle Bin (the shell) may refuse a path this long - with a message, nothing deleted
            $refused = $Recycle -ne 0 -and $m -match 'too long'
            Row $Case 'RUN' (V ($kept -and ($gone -or $refused))) ("folder {0} chars; J attributes {1}; recycle bin {2}; target's file kept {3}; deleted item gone {4}; location '{5}'; windows: {6}" -f $Folder.Length, $attr, $Recycle, $kept, $gone, (Tail $loc 60), (Tail $m 500))
        }
        End-Row $Case $id $null $before; $id = 0
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$script:Links = New-Object System.Collections.ArrayList
$backup = Join-Path $env:TEMP 'tc219_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Set-ItemProperty -Path $ConfKey -Name 'Use Recycle Bin' -Value 0 -Type DWord
    Set-ItemProperty -Path $ConfKey -Name 'Use Recycle Bin For' -Value '*.txt' -Type String
    Out ("deepjunc219_probe (feature 219), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''
    Run-Case 'SYM-SHALLOW' ($Root + '\s') ($Root + '\t1') 'link' 0 'D'
    Run-Case 'SYM-DEEP' ($Root + '\d\' + ('x' * 120) + '\' + ('y' * 120)) ($Root + '\t2') 'link' 0 'D'
    Run-Case 'SYM-DEEP2' ($Root + '\e\' + ((1..7 | ForEach-Object { 'z' * 118 }) -join '\')) ($Root + '\t3') 'link' 0 'D'
    Run-Case 'SYM-TREE' ($Root + '\f\' + ((1..7 | ForEach-Object { 'w' * 118 }) -join '\')) ($Root + '\t4') 'tree' 0 'D'
    Run-Case 'SYM-FOCUS' ($Root + '\h\' + ((1..7 | ForEach-Object { 'u' * 118 }) -join '\')) ($Root + '\t6') 'focus' 0 'D'
    Run-Case 'SYM-FOCUS-UNC' ($Root + '\k') ($Root + '\t11') 'focus' 0 'D' -UncTarget
    Run-Case 'SYM-FOCUS-PLAIN' ($Root + '\i\' + ((1..7 | ForEach-Object { 'r' * 118 }) -join '\')) ($Root + '\t10') 'focus' 0 'D' -PlainTarget
    Run-Case 'MASK-SHALLOW' ($Root + '\m') ($Root + '\t7') 'link' 2 'J'
    Run-Case 'MASK-TREE' ($Root + '\n\o') ($Root + '\t8') 'tree' 2 'J'
    Run-Case 'MASK-DEEPTREE' ($Root + '\p\' + ((1..7 | ForEach-Object { 'q' * 118 }) -join '\')) ($Root + '\t9') 'tree' 2 'J'
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    # junctions first (a recursive delete must not follow them), then the fixture
    foreach ($j in @($script:Links)) { if ([IO.Directory]::Exists($LP + $j)) { [void](Cmd ("rmdir `"\\?\{0}`"" -f $j)) } }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ('Fixture: ' + $_.Exception.Message) }
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, @($Started | Where-Object { Test-Alive $_ }).Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
if ($Expect -eq 'before') { exit 0 }
exit $nf
