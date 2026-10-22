<#
  Review 2 of 301 (written by the reviewer, kept as the regression row of its S1): Drive
  Information's mount point / volume for a folder that is a symbolic link to a UNC share, on a
  subst drive with a SHORT target and on the plain path - PASS = never the local C:\ volume.
  Needs the right to create a symbolic link (mklink /D). Branch before the review-2 fix: SUBST
  FAIL (C:\ and C:'s GUID); installed 0.1.10 and after the fix: 4 / 0.
  Run only through tools\run_on_hidden_desktop.ps1.
#>
param([Parameter(Mandatory = $true)][string]$Exe, [string]$Label)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if (@(Get-Process tandemcommander -ErrorAction SilentlyContinue).Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }
. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
if (-not ('SubstR2' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class SubstR2
{
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern bool DefineDosDeviceW(uint flags, string dev, string target);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern uint QueryDosDeviceW(string dev, StringBuilder buf, uint max);
}
'@
}
$Root = $TempRoot + '\tc301r2'
$StartDir = $Root + '\start'
$Fold = $Root + '\s'
$Link = $Fold + '\SLunc'
$Unc = '\\localhost\D$\'
$script:drv = $null

function Info([string]$Case, [string]$Where) {
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $Where
        $loc = Get-Loc $id
        $dlg = Open-ByCmd $id 752
        if ($dlg -eq [IntPtr]::Zero) { Row $Case 'INFO' 'FAIL' 'Drive Information opened no window'; return }
        $t = '<no control>'; $c = Find-Ctl $dlg 551; if ($c -ne [IntPtr]::Zero) { $t = [Drv098f]::GetText($c, 5000) }
        $mp = '<no control>'; $c = Find-Ctl $dlg 571; if ($c -ne [IntPtr]::Zero) { $mp = [Drv098f]::GetText($c, 5000) }
        $gu = '<no control>'; $c = Find-Ctl $dlg 572; if ($c -ne [IntPtr]::Zero) { $gu = [Drv098f]::GetText($c, 5000) }
        Close-Win $dlg; Start-Sleep -Milliseconds 400
        # the link leads to D: over the network; the folder holding the link is on C:
        $wrong = $mp -ieq 'C:\'
        Row $Case 'VOL' (V (-not $wrong)) ("location '{0}'; type '{1}'; mount point '{2}'; volume '{3}'" -f (Tail $loc 40), (Tail $t 80), $mp, $gu)
        End-Row $Case $id $null $before; $id = 0
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc301r2_backup.reg'
$existed = Backup-Reg $backup
$restored = $false
try {
    if ([IO.Directory]::Exists($LP + $Root)) { throw "fixture exists: $Root" }
    NewDir $StartDir; NewDir $Fold
    $o = & cmd.exe /c ("mklink /D `"{0}`" `"{1}`"" -f $Link, $Unc) 2>&1
    if (-not [IO.Directory]::Exists($Link)) { throw ('mklink /D failed: ' + ($o -join ' ')) }
    Set-Config
    Out ("unc_probe (review 2 of 301) {0}; program {1}; {2}" -f $Label, $Exe, (Get-Date -Format 'yyyy-MM-dd HH:mm'))
    foreach ($c in 'ZYXWVUTSRQP'.ToCharArray()) { $sb = New-Object Text.StringBuilder 1100; if ([SubstR2]::QueryDosDeviceW("${c}:", $sb, 1024) -eq 0) { $script:drv = [string]$c; break } }
    if (-not [SubstR2]::DefineDosDeviceW(0, "$($script:drv):", $Fold)) { throw 'DefineDosDeviceW failed' }
    Out ("{0}: -> {1}" -f $script:drv, $Fold)
    Info 'PLAIN' $Link
    Info 'SUBST' ("{0}:\SLunc" -f $script:drv)
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    if ($script:drv) { [void][SubstR2]::DefineDosDeviceW(6, "$($script:drv):", $Fold) }
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    if ([IO.Directory]::Exists($Link)) { [void](& cmd.exe /c ("rmdir `"{0}`"" -f $Link)) }
    if (-not [IO.Directory]::Exists($Link) -and [IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    Out ("Rows: PASS {0}, FAIL {1}; fixture removed {2}; registry restored+identical {3}" -f $np, $nf, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
}
