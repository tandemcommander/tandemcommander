<#
.SYNOPSIS
    Feature 154 probe: a character that arrives while one of the core's "drain" message loops runs
    reaches a Unicode field as it was typed (NEXT-WORK item 9, the B-1 leftovers of 093).

.DESCRIPTION
    The command line (ComboBox 955 and its inner Edit, Unicode since 093) gets WM_CHAR posted per
    UTF-16 unit and is read back (WM_GETTEXT, wide). Rows, each with Cyrillic (outside every
    Western code page and outside the hidden desktop's layout code page), an accented Latin letter
    of the layout's code page (a neutrality control) and ASCII:

      main   posted while the program idles: the main message loop (wide since 093) dispatches it -
             the channel works on every build
      susp   the application is deactivated and activated again (WM_ACTIVATEAPP sent FALSE, TRUE):
             the activation posts WM_USER_END_SUSPMODE, whose handler drains the queue before the
             panels refresh (mainwnd3.cpp); the characters are posted right after, so they are in
             the queue when that loop runs. Before 154 the loop was a code-page loop: the Cyrillic
             text arrived as '?'.

    MUST run through tools\run_on_hidden_desktop.ps1. Messages go only to the windows of the process
    started here. HKCU\Software\Tandem Commander exported before, restored and verified after.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$OutFile
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('REFUSED: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
if (-not ('Uni154' -as [type])) { Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public static class Uni154 { [DllImport("user32.dll")] public static extern bool IsWindowUnicode(IntPtr h); }' }

function Hex([string]$s) { return (($s.ToCharArray() | ForEach-Object { '{0:X4}' -f [int]$_ }) -join ' ') }
function S([int[]]$codes) { return -join ($codes | ForEach-Object { [char]$_ }) }
$Texts = [ordered]@{
    cyrillic = (S 0x0416, 0x0443, 0x043A)   # Zh u k
    latin1   = (S 0x00E9, 0x00FC)           # e-acute u-umlaut (code page 1252, the hidden desktop's layout)
    ascii    = 'abc'
}

$Root = $TempRoot + '\tc154'
$StartDir = $Root
$backup = Join-Path $env:TEMP 'tc154_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $Root
    Set-Config
    & cmd.exe /c "reg query `"$RegKey\0.1\Configuration`" >nul 2>&1"
    if ($LASTEXITCODE -eq 0) { & reg.exe add "$RegKey\0.1\Configuration" /v 'Command Line' /t REG_DWORD /d 1 /f | Out-Null }
    Out ("drain_loop_probe (feature 154)")
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; desktop '{2}'" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), [DeskLib098]::Name())
    Out ''
    $id = Start-Tc $Root
    $before = Reports
    $main = Get-Main $id
    $findCombo = { @([Drv098f]::Kids($main) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 955 -and [Drv098f]::Cls($_) -eq 'ComboBox' }) | Select-Object -First 1 }
    $cb = & $findCombo
    if (-not $cb) { Post-Cmd $main 745; Start-Sleep -Milliseconds 800; $cb = & $findCombo }   # CM_TOGGLEEDITLINE
    if (-not $cb) { throw 'no command line (ComboBox 955)' }
    $ed = @([Drv098f]::Kids($cb) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' }) | Select-Object -First 1
    if (-not $ed) { throw 'the command line has no inner Edit' }
    Out ("Command line: combo Unicode {0}, edit Unicode {1}" -f [Uni154]::IsWindowUnicode($cb), [Uni154]::IsWindowUnicode($ed))

    foreach ($row in 'main', 'susp') {
        foreach ($k in $Texts.Keys) {
            $t = $Texts[$k]
            [void][Drv098f]::SetText($cb, '', 5000)
            if ($row -eq 'susp') {
                [void][Drv098f]::Send($main, 0x001C, 0, 0, 10000)   # WM_ACTIVATEAPP FALSE: suspend mode
                [void][Drv098f]::Send($main, 0x001C, 1, 0, 10000)   # TRUE: posts WM_USER_END_SUSPMODE
            }
            foreach ($u in $t.ToCharArray()) { [void][Drv098f]::PostMessageW($ed, 0x0102, [IntPtr][int]$u, [IntPtr]1) }
            Start-Sleep -Milliseconds 600
            [void][Drv098f]::Send($main, 0, 0, 0, 10000)
            Start-Sleep -Milliseconds 300
            $a = [Drv098f]::GetText($ed, 5000)
            Row ("{0}-{1}" -f $row, $k) 'TYPED' (V ($a -ceq $t)) ("posted {0}; the field holds {1}" -f (Hex $t), (Hex $a))
        }
    }
    [void][Drv098f]::SetText($cb, '', 5000)
    End-Row 'end' $id $null $before
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}. Left running: {2}; registry restored+identical: {3}" -f $np, $nf, $leftover.Count, $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
