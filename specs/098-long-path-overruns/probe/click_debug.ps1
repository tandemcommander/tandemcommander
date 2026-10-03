<#
    Feature 098 helper: how a posted click on the directory line behaves.
    Starts -Exe in a folder chain of about -Units UTF-16 units, lists the
    panel's child windows (class, rect), posts clicks at the given x positions
    (one fresh Change Directory to the deep folder before each) and reads the
    location back. Hidden desktop only; registry exported/restored; scratch
    %TEMP%\tc098_clk removed. Pure ASCII.
#>
param([Parameter(Mandatory = $true)][string]$Exe, [int]$Units = 2000, [switch]$FixShape, [string]$Xs = '5,30,70,200,600', [string]$OutFile)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$XList = @($Xs -split ',' | ForEach-Object { [int]$_.Trim() })
. (Join-Path $PSScriptRoot 'fix_probe_lib.ps1')
$Root = $TempRoot + '\tc098_clk'
$backup = Join-Path $env:TEMP 'tc098_clk_backup.reg'
$existed = Backup-Reg $backup
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    $StartDir = $Root + '\start'; NewDir $StartDir
    Set-Config
    $base = $Root + '\c'
    $deep = $base; $i = 0
    if ($FixShape) {
        # the chain of fix_probe.ps1: 200-character components, then six of 20 characters
        while ($deep.Length + 201 + 126 -le $Units) { $i++; $deep += '\' + ('p' * 200) }
        $rest = $Units - 126 - $deep.Length - 1
        if ($rest -gt 0) { $i++; $deep += '\' + ('p' * [Math]::Min($rest, 200)) }
        foreach ($k in 1..6) { $i++; $deep += '\' + ([string]$k) + ('p' * 19) }
    }
    else { while ($deep.Length + 41 -le $Units) { $i++; $deep += '\' + ('{0:D3}' -f $i) + ('p' * 36) } }
    NewDir $deep
    Out ("Program {0}; deep {1} units, {2} components" -f $Exe, $deep.Length, $i)
    $id = Start-Tc $StartDir
    foreach ($x in $XList) {
        [void](Do-ChangeDir $id $deep); $r = Serve $id 20
        $list = Get-LeftList $id; $panel = [Drv098f]::GetParent($list)
        if ($x -eq $XList[0]) {
            foreach ($h in [Drv098f]::Kids($panel)) {
                if ([Drv098f]::GetParent($h) -ne $panel) { continue }
                $wr = New-Object Drv098f+RECT; [void][Drv098f]::GetWindowRect($h, [ref]$wr)
                Out ("  child {0} '{1}' visible {2} rect {3},{4}-{5},{6}" -f [Drv098f]::Cls($h), (Tail ([Drv098f]::Txt($h)) 30), [Drv098f]::IsWindowVisible($h), $wr.Left, $wr.Top, $wr.Right, $wr.Bottom)
                foreach ($k in [Drv098f]::Kids($h)) { $kr = New-Object Drv098f+RECT; [void][Drv098f]::GetWindowRect($k, [ref]$kr); Out ("     grandchild {0} rect {1},{2}-{3},{4}" -f [Drv098f]::Cls($k), $kr.Left, $kr.Top, $kr.Right, $kr.Bottom) }
            }
        }
        $line = Find-DirLine $id
        $cr = New-Object Drv098f+RECT; [void][Drv098f]::GetClientRect($line, [ref]$cr)
        $y = [int](($cr.Bottom - $cr.Top) / 2)
        Post-Click $line $x $y
        Start-Sleep -Milliseconds 800
        $r = Serve $id 20
        $loc = Get-Loc $id
        $up = '-'; if ($deep.StartsWith($loc, [StringComparison]::Ordinal)) { $up = $deep.Substring($loc.Length).Split('\').Count - 1 }
        Out ("  x={0}: windows: {1}; location {2} units ({3} components above the deepest): {4}" -f $x, (Msgs $r), $loc.Length, $up, (Tail $loc 60))
    }
    Stop-Tc $id
}
catch { Out ('ERROR ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 500
    [void](Restore-Reg $backup $existed); if (Test-Path $backup) { Remove-Item $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ('fixture: ' + $_.Exception.Message) }
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
