<#
.SYNOPSIS
    Feature 164 probe: the time to delete half of the members of a large ZIP archive (NEXT-WORK item
    15: the ZIP plug-in walked its central directory once per deleted member, twice - n x d).

.DESCRIPTION
    probe\bigzip.py makes big.zip with N members d/a000000.txt ... (every second one *.del). The
    program enters big.zip\d, selects *.del (Select, command 841, mask field 101), deletes them (F8,
    command 729; the question answered Yes) and the time from the question's Yes to the end of the
    operation (no window but the main one, the panel answering) is measured. Afterwards bigzip.py
    checks the archive: exactly the *.txt members, each with its own content, the archive tests
    clean (PASS = BAD 0). Rows: n<N> for each -Sizes value.

    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$OutFile,
    [int[]]$Sizes = @(2000, 10000, 30000)
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('REFUSED: tandemcommander.exe already runs'); exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
$Root = $TempRoot + '\tc164'
$StartDir = $Root
$Py = 'python'
$Big = Join-Path $PSScriptRoot 'bigzip.py'

function Run-Size([int]$N) {
    $case = 'n' + $N
    $d = $Root + '\' + $case; NewDir $d
    $arc = $d + '\big.zip'
    $o = & $Py $Big make ($LP + $arc) $N 2>&1
    if ("$o" -notmatch 'ok') { Row $case 'TIME' 'FAIL' ('fixture: ' + "$o"); return }
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $d
        [void](Do-ChangeDir $id ($arc + '\d')); [void](Serve $id 60)
        $dlg = Open-ByCmd $id 841 10                     # Select
        if ($dlg -eq [IntPtr]::Zero) { Row $case 'TIME' 'NOT DRIVEN' 'no Select dialog'; return }
        [void][Drv098f]::SetText((Find-Ctl $dlg 101), '*.del', 5000); Click-Ok $dlg
        Start-Sleep -Milliseconds 800
        $known = Get-Tops $id
        Post-Cmd (Get-Main $id) 729                      # Delete
        $q = Wait-NewWin $id $known 15
        if ($q -eq [IntPtr]::Zero) { Row $case 'TIME' 'NOT DRIVEN' 'no question'; return }
        $text = FullText $q
        $yes = Buttons $q | Where-Object { @(6, 1) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1
        $sw = [Diagnostics.Stopwatch]::StartNew()
        Click $yes
        Start-Sleep -Milliseconds 500
        while ($sw.Elapsed.TotalSeconds -lt 1200) {
            $w = @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })
            if (-not $w.Count -and [Drv098f]::Send((Get-Main $id), 0, 0, 0, 1000)) { break }
            Start-Sleep -Milliseconds 200
        }
        $secs = $sw.Elapsed.TotalSeconds
        $r = Serve $id 10
        End-Row $case $id $null $before; $id = 0
        $chk = (& $Py $Big check ($LP + $arc) $N 2>&1) -join ' '
        $ok = $chk -match 'BAD 0$' -and $chk -match ('DEL ' + [int]($N / 2))
        Row $case 'TIME' (V $ok) ("{0} members, {1} deleted: {2:N1} s; archive: {3}; question: {4}; after: {5}" -f $N, [int]($N / 2), $secs, $chk, (Tail $text 80), (Msgs $r))
    }
    catch { Row $case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc164_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $Root
    Set-Config
    Out ("zip_delete_cost_probe (feature 164)")
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'))
    Out ''
    foreach ($n in $Sizes) { Run-Size $n }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { }
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}. Registry restored+identical: {2}" -f $np, $nf, $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
