<#
.SYNOPSIS
    Feature 328: an entry of an ISO 9660 volume the panel listing refuses (a folder part over its
    MAX_PATH - 5 bytes) no longer ends the listing with "Error" and a wiped listing - it is left out
    and reported (the system's "(206)" text with its path), Unpack with "Delete archive after
    unpacking" keeps an image whose listing left something out, and a Rock Ridge tree keeps its
    names where they fit (the deep part under its ISO 9660 names).

.DESCRIPTION
    Seed images made in WSL Ubuntu by mkimg328.sh (next to this script; genisoimage and xorriso fetched
    without root) from one tree: a<59 x>/b<59 x>/c<59 x>/d<59 x>/e<59 x>/deep.txt (Rock Ridge / Joliet
    folder part 305 bytes), a<59 x>/side.txt, top.txt, zlast/z.txt.
      gdeep.iso  genisoimage -R (ISO 9660 level 1 + Rock Ridge; every record starts with 'RR', the
                 root carries 'SP')
      xdeep.iso  xorriso (Rock Ridge 1.12: 'SP', no 'RR'; ISO 9660 names of 31 letters)
      ldeep.iso  gdeep.iso patched by the probe: the root's SP check bytes cleared (an 'RR' volume
                 without SUSP 'SP')
      jdeep.iso  genisoimage -J (ISO 9660 + Joliet; the plug-in lists Joliet - no other name)
    Copy rows: the left panel opens the image, the right shows <row>\tgt; Select All (842), Copy (727),
    every box answered OK / Yes.
      G-COPY, X-COPY, L-COPY  PASS = no message at the open; all four files extracted with their
                 content; top.txt, zlast\z.txt and a<59 x>\side.txt under their Rock Ridge names
                 (exact case); deep.txt below a<59 x>\b<59 x>\c<59 x> (Rock Ridge names kept where
                 they fit) - before 328: "Error" and folders lost (G, L), or the whole volume under ISO
                 9660 names (X, feature 326)
      J-COPY     PASS = a "(206)" box at the open naming deep.txt; side.txt, top.txt, z.txt extracted;
                 no "Error" box - before 328: "Error", the listing cleared
    Unpack rows: the left panel shows <row>\src, Home, End focuses the image, Alt+F9 (851), the target
    field (210) set to <row>\tgt, "Delete archive after unpacking" (6210) checked, OK.
      J-UNP-DEL  PASS = the three listed files, a "(206)" box, the image KEPT
      G-UNP-DEL  PASS = all four files, nothing asked, the image deleted (nothing was left out)
    Every row also fails on a program exit, a bug report, a fatal window, or a main window that does
    not answer within 30 s (End-Row). Without WSL Ubuntu every row is NOT DRIVEN.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Built on specs\326-uniso-rrip-without-rr\probe\iso326_probe.ps1
    and specs\321-tar-long-component\probe\unp321_probe.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lib
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -eq $_ }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Lib) { $Lib = Join-Path $Here '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1' }
. $Lib
$Root = $TempRoot + '\tc328'
$StartDir = $Root + '\start'
$Seg = 'x' * 59
$SegA = 'a' + $Seg; $SegB = 'b' + $Seg; $SegC = 'c' + $Seg # (not $a / $b / $c: PowerShell names ignore case, rows use $b and $c)

function WslPath([string]$p) { return ('/mnt/' + $p.Substring(0, 1).ToLower() + $p.Substring(2).Replace('\', '/')) }
function Le32($b, [long]$o) { return [long]$b[$o] -bor ([long]$b[$o + 1] -shl 8) -bor ([long]$b[$o + 2] -shl 16) -bor ([long]$b[$o + 3] -shl 24) }
function Ascii($b, [long]$o, [int]$n) { return [Text.Encoding]::ASCII.GetString($b, $o, $n) }
function Tgt-Files([string]$Tgt) {
    if (-not [IO.Directory]::Exists($LP + $Tgt)) { return @() }
    $base = ($LP + $Tgt + '\')
    return @([IO.Directory]::GetFiles($LP + $Tgt, '*', [IO.SearchOption]::AllDirectories) | ForEach-Object { $_.Substring($base.Length).Replace('\', '/') } | Sort-Object)
}
function Content([string]$Tgt, [string]$Rel) { try { return [IO.File]::ReadAllText($LP + $Tgt + '\' + $Rel.Replace('/', '\')) } catch { return '<none>' } }
function Short([string]$s) { return ($s -replace ('x{59}'), '<59x>' -replace ('X{30}'), '<30X>' -replace ('X{7}'), '<7X>') }
function Find-Btn([IntPtr]$Dlg, [int]$CtlId) {
    return (@([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'Button' -and [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }) | Select-Object -First 1)
}
function Set-Field([IntPtr]$Dlg, [int]$CtlId, [string]$Text) {
    $f = Find-Ctl $Dlg $CtlId
    if ($f -eq [IntPtr]::Zero) { throw "field $CtlId not found" }
    [void][Drv098f]::SetText($f, $Text, 5000)
    if ([Drv098f]::GetText($f, 5000) -cne $Text) { throw "field $CtlId did not take the text" }
}

# the expected result of a whole copy: @(ok, facts). $Left = deep.txt must be missing (left out)
function Check-All([string]$Tgt, [switch]$Left) {
    $files = @(Tgt-Files $Tgt)
    $want = [ordered]@{ ($SegA + '/side.txt') = 'SIDE'; 'top.txt' = 'TOP'; 'zlast/z.txt' = 'Z' }
    $missing = @($want.Keys | Where-Object { $files -cnotcontains $_ })
    $bad = @($want.Keys | Where-Object { $files -ccontains $_ -and (Content $Tgt $_) -cne $want[$_] })
    $deep = @($files | Where-Object { $_ -like '*/deep.txt' })
    $ok = ($missing.Count -eq 0 -and $bad.Count -eq 0)
    if ($Left) { $ok = $ok -and $deep.Count -eq 0 -and $files.Count -eq 3 }
    else {
        $ok = $ok -and $files.Count -eq 4 -and $deep.Count -eq 1 -and $deep[0].StartsWith($SegA + '/' + $SegB + '/' + $SegC + '/') -and (Content $Tgt $deep[0]) -ceq 'DEEP'
    }
    $f = ('files {0}: {1}' -f $files.Count, ((@($files | ForEach-Object { Esc (Short $_) })) -join ', '))
    if ($deep.Count -eq 1) { $f += ("; deep.txt content '{0}'" -f (Content $Tgt $deep[0])) }
    if ($missing.Count) { $f += ('; missing: ' + ((@($missing | ForEach-Object { Esc (Short $_) })) -join ', ')) }
    if ($bad.Count) { $f += ('; wrong content: ' + ((@($bad | ForEach-Object { Esc (Short $_) })) -join ', ')) }
    return @($ok, $f)
}

# opens $Iso in the left panel (the right one shows tgt), Select All, Copy
function Copy-Row([string]$Case, [string]$Iso, [switch]$Left) {
    if (-not (Want $Case)) { return }
    if (-not [IO.File]::Exists($Iso)) { Row $Case 'RUN' 'NOT DRIVEN' ('no image ' + $Iso); return }
    $d = $Root + '\' + $Case; $tgt = $d + '\tgt'; NewDir $tgt
    $img = $d + '\' + [IO.Path]::GetFileName($Iso); [IO.File]::Copy($Iso, $LP + $img)
    $id = 0; $before = Reports
    try {
        if (-not $img.StartsWith($Root + '\') -or -not $tgt.StartsWith($Root + '\')) { throw ('path outside the fixture: ' + $tgt) }
        $p = Start-Process -FilePath $Exe -ArgumentList @('-t', 'T328', '-l', ('"{0}"' -f $img), '-r', ('"{0}"' -f $tgt), '-p', '1') -PassThru
        [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p; $id = $p.Id
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $id) -and (Get-Main $id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
        if ((Get-Main $id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
        try { [void]$p.WaitForInputIdle(30000) } catch { }
        Start-Sleep -Milliseconds 2000
        $openMsgs = Msgs (Serve $id 10)
        $loc = Get-Loc $id
        if (-not $loc.StartsWith($img, [StringComparison]::OrdinalIgnoreCase)) { throw ('the image did not open; panel at: ' + (Tail $loc 80) + '; at the open: ' + (Tail $openMsgs 200)) }
        Post-Cmd (Get-Main $id) 842; Start-Sleep -Milliseconds 800
        Post-Cmd (Get-Main $id) 727
        $msgs = Msgs (Serve $id 60 @(1, 6))
        End-Row $Case $id $null $before; $id = 0
        $c = Check-All $tgt -Left:$Left
        $ok = $c[0]
        $has206 = ($openMsgs -match '\(206\)') -and ($openMsgs -match 'deep\.txt')
        $errBox = ($openMsgs -cmatch '\] Error( \||$)')
        if ($Left) { $ok = $ok -and $has206 -and -not $errBox }
        else { $ok = $ok -and ($openMsgs -eq 'no window') }
        Row $Case 'RUN' (V $ok) ('{0}; "(206)" naming deep.txt at the open: {1}; "Error": {2}; at the open: {3}; copy: {4}' -f $c[1], $has206, $errBox, (Tail $openMsgs 400), (Tail $msgs 700))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

# Unpack (Alt+F9) of the whole image into tgt with "Delete archive after unpacking"
function Unpack-Row([string]$Case, [string]$Iso, [switch]$Left) {
    if (-not (Want $Case)) { return }
    if (-not [IO.File]::Exists($Iso)) { Row $Case 'RUN' 'NOT DRIVEN' ('no image ' + $Iso); return }
    $d = $Root + '\' + $Case; $tgt = $d + '\tgt'; NewDir ($d + '\src'); NewDir $tgt
    $img = $d + '\src\' + [IO.Path]::GetFileName($Iso); [IO.File]::Copy($Iso, $LP + $img)
    $id = 0; $fatal = $null; $before = Reports
    try {
        if (-not $img.StartsWith($Root + '\') -or -not $tgt.StartsWith($Root + '\')) { throw ('path outside the fixture: ' + $tgt) }
        $id = Start-Tc ($d + '\src')
        Key $id 0x24; Key $id 0x23
        Start-Sleep -Milliseconds 500
        $dlg = Open-ByCmd $id 851 15
        if ($dlg -eq [IntPtr]::Zero) { throw 'Unpack (851) opened no window' }
        if ([Drv098f]::Txt($dlg) -ne 'Unpack') { throw ("851 opened '{0}', not the Unpack dialog" -f [Drv098f]::Txt($dlg)) }
        Start-Sleep -Milliseconds 400
        Set-Field $dlg 210 $tgt
        $b = Find-Btn $dlg 6210
        if (-not $b -or -not [Drv098f]::IsWindowEnabled($b)) { throw 'the box "Delete archive after unpacking" (6210) is missing or disabled' }
        [void][Drv098f]::Send($b, 0x00F1, 1, 0, 5000)   # BM_SETCHECK BST_CHECKED
        Click-Ok $dlg
        Start-Sleep -Milliseconds 800
        $r = Serve $id 90 @(1, 6)
        $msgs = Msgs $r
        $fatal = Fatal-Win $id
        End-Row $Case $id $fatal $before; $id = 0
        $c = Check-All $tgt -Left:$Left
        $kept = [IO.File]::Exists($LP + $img)
        $has206 = ($msgs -match '\(206\)') -and ($msgs -match 'deep\.txt')
        $ok = $c[0] -and (-not $fatal)
        if ($Left) { $ok = $ok -and $kept -and $has206 } else { $ok = $ok -and (-not $kept) -and ($msgs -eq 'no window') }
        Row $Case 'RUN' (V $ok) ('{0}; files ok: {1}; image kept: {2} (want {3}); "(206)" naming deep.txt: {4}; fatal: {5}; windows: {6}' -f $c[1], $c[0], $kept, [bool]$Left, $has206, (Tail ([string]$fatal) 200), (Tail $msgs 400))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

# a copy of gdeep.iso without SUSP: the root '.' record's SP check bytes cleared; $null when the
# layout is not the measured one
function Make-NoSp([string]$Src, [string]$Dst) {
    $b = [IO.File]::ReadAllBytes($Src)
    $pvd = 16 * 2048
    if ($b[$pvd] -ne 1 -or (Ascii $b ($pvd + 1) 5) -cne 'CD001') { return $null }
    $dir = (Le32 $b ($pvd + 156 + 2)) * 2048
    if ($b[$dir + 32] -ne 1 -or (Ascii $b ($dir + 34) 2) -cne 'SP' -or $b[$dir + 38] -ne 0xBE -or $b[$dir + 39] -ne 0xEF) { return $null }
    $b[$dir + 38] = 0; $b[$dir + 39] = 0
    [IO.File]::WriteAllBytes($Dst, $b)
    return ("root directory at {0}: SP check bytes cleared" -f $dir)
}

$backup = Join-Path $env:TEMP 'tc328_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("iso328_probe (feature 328) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''

    $s = $Root + '\seeds'; NewDir $s
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $mk = & wsl -d Ubuntu -- sh (WslPath (Join-Path $Here 'mkimg328.sh')) (WslPath $s) 2>&1
    $ErrorActionPreference = $old
    if (-not [IO.File]::Exists("$s\gdeep.iso")) {
        foreach ($c in @('G-COPY', 'X-COPY', 'L-COPY', 'J-COPY', 'J-UNP-DEL', 'G-UNP-DEL')) { Row $c 'RUN' 'NOT DRIVEN' ('no seed image: ' + (($mk | ForEach-Object { "$_" }) -join ' ')) }
    }
    else {
        $nosp = Make-NoSp "$s\gdeep.iso" "$s\ldeep.iso"
        Out ("seeds: {0}; ldeep.iso: {1}" -f ((@([IO.Directory]::GetFiles($s, '*.iso') | ForEach-Object { [IO.Path]::GetFileName($_) }) | Sort-Object) -join ','), $nosp)
        Copy-Row 'G-COPY' "$s\gdeep.iso"
        Copy-Row 'X-COPY' "$s\xdeep.iso"
        Copy-Row 'L-COPY' "$s\ldeep.iso"
        Copy-Row 'J-COPY' "$s\jdeep.iso" -Left
        Unpack-Row 'J-UNP-DEL' "$s\jdeep.iso" -Left
        Unpack-Row 'G-UNP-DEL' "$s\gdeep.iso"
    }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
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
