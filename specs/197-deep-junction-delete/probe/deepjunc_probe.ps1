<#
.SYNOPSIS
    Measure: F8 Delete (Recycle Bin off) of a junction that sits in a folder whose path is longer
    than MAX_PATH - is only the link removed, or is the target's content deleted?

.DESCRIPTION
      SHALLOW   the control: junction J in %TEMP%\tc197\s, target %TEMP%\tc197\t1 (precious.txt)
      DEEP      the same junction in a folder of about 300 characters, target %TEMP%\tc197\t2
      DEEP2     in a folder of about 870 characters (past 3 * MAX_PATH), target %TEMP%\tc197\t3
      DEEPTREE  F8 on the deep folder that holds the junction (the recursion meets it)
      DEEP2-RB  DEEP2 with the Recycle Bin on
      FOCUS     Go to Shortcut Target (838) on a deep junction: the panel goes to its target
    Every box is answered Yes/OK (6, 1). PASS = the target's file is still there and J is gone.
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
$Root = $TempRoot + '\tc197'
$StartDir = $Root + '\start'
$ConfKey = 'HKCU:\Software\Tandem Commander\Settings\Configuration'

function Cmd([string]$c) {
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $o = & cmd.exe /c $c 2>&1; $rc = $LASTEXITCODE; $ErrorActionPreference = $old
    return [pscustomobject]@{ Rc = $rc; Text = (($o | ForEach-Object { "$_" }) -join ' ') }
}
function Put([string]$p, [string]$text) { [IO.File]::WriteAllText($LP + $p, $text, (New-Object Text.ASCIIEncoding)) }

function Run-Case([string]$Case, [string]$Folder, [string]$Target, [string]$Mode = 'link', [int]$Recycle = 0) {
    $id = 0; $before = Reports
    try {
        NewDir $Folder; NewDir $Target; Put "$Target\precious.txt" 'PRECIOUS'
        # mklink cannot take a path over MAX_PATH: the junction is made in a short folder and the
        # deep folder is reached by renaming the parents (or by the \\?\ form)
        $j = "$Folder\J"
        $r = Cmd ("mklink /J `"\\?\{0}`" `"{1}`"" -f $j, $Target)
        if (-not [IO.Directory]::Exists($LP + $j)) { Row $Case 'RUN' 'NOT DRIVEN' ('mklink /J refused: ' + $r.Text); return }
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
            $ok = $loc2 -ieq $Target -or $loc2 -ieq ($Target + '\')
            Row $Case 'RUN' (V $ok) ("folder {0} chars; the panel went to '{1}' (expected the target '{2}'); windows: {3}" -f $Folder.Length, (Tail $loc2 80), (Tail $Target 60), (Tail (Msgs $res) 300))
        }
        else {
            Post-Cmd (Get-Main $id) 729      # F8 Delete
            $res = Serve $id 30 @(6, 1)
            $m = Msgs $res
            Start-Sleep -Milliseconds 800
            $kept = [IO.File]::Exists($LP + "$Target\precious.txt")
            $gone = -not [IO.Directory]::Exists($LP + $item)
            # the Recycle Bin (the shell) may refuse a path this long - with a message, nothing deleted
            $refused = $Recycle -eq 1 -and $m -match 'too long'
            Row $Case 'RUN' (V ($kept -and ($gone -or $refused))) ("folder {0} chars; J attributes {1}; recycle bin {2}; target's file kept {3}; deleted item gone {4}; location '{5}'; windows: {6}" -f $Folder.Length, $attr, $Recycle, $kept, $gone, (Tail $loc 60), (Tail $m 500))
        }
        End-Row $Case $id $null $before; $id = 0
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc197_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Set-ItemProperty -Path $ConfKey -Name 'Use Recycle Bin' -Value 0 -Type DWord
    Out ("deepjunc_probe (feature 197), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''
    Run-Case 'SHALLOW' ($Root + '\s') ($Root + '\t1')
    $deep = $Root + '\d\' + ('x' * 120) + '\' + ('y' * 120)
    Run-Case 'DEEP' $deep ($Root + '\t2')
    # past the 3 * MAX_PATH (780) units GetReparsePointDestination converts into
    $deep2 = $Root + '\e\' + ((1..7 | ForEach-Object { 'z' * 118 }) -join '\')
    Run-Case 'DEEP2' $deep2 ($Root + '\t3')
    # the folder holding the junction deleted: the junction is met by the recursion
    Run-Case 'DEEPTREE' ($Root + '\f\' + ((1..7 | ForEach-Object { 'w' * 118 }) -join '\')) ($Root + '\t4') 'tree'
    Run-Case 'DEEP2-RB' ($Root + '\g\' + ((1..7 | ForEach-Object { 'v' * 118 }) -join '\')) ($Root + '\t5') 'link' 1
    Run-Case 'FOCUS' ($Root + '\h\' + ((1..7 | ForEach-Object { 'u' * 118 }) -join '\')) ($Root + '\t6') 'focus'
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    # junctions first (a recursive delete must not follow them), then the fixture
    foreach ($j in @(($Root + '\s\J'), ($Root + '\d\' + ('x' * 120) + '\' + ('y' * 120) + '\J'), ($Root + '\e\' + ((1..7 | ForEach-Object { 'z' * 118 }) -join '\') + '\J'), ($Root + '\f\' + ((1..7 | ForEach-Object { 'w' * 118 }) -join '\') + '\J'), ($Root + '\g\' + ((1..7 | ForEach-Object { 'v' * 118 }) -join '\') + '\J'), ($Root + '\h\' + ((1..7 | ForEach-Object { 'u' * 118 }) -join '\') + '\J'))) { if ([IO.Directory]::Exists($LP + $j)) { [void](Cmd ("rmdir `"\\?\{0}`"" -f $j)) } }
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
