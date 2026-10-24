<#
.SYNOPSIS
    Feature 337: Unpack with "Delete archive after unpacking" keeps a disc image whose Mode 2 Form 2 stream
    track (feature 335) a listed file starts in but does not cover - before, any file that started in the
    stream covered it (feature 336), however few of its sectors it read. A stream counts as covered only
    when every sector no listed file reads is an empty Form 2 sector (2324 zero bytes; at most 300 of them):
    a fully covered stream and a stream followed by empty gap sectors (a real Video CD) are still deleted.

.DESCRIPTION
    Built on specs\336-uniso-form2-uncovered\probe\iso336_probe.ps1 (same seeds: 334's mkimg334.sh, 336's
    mkimg336.sh in WSL Ubuntu; 335's img335.py / ccd335.py). img337.py writes the stream images (64-sector
    streams; see its docstring). Rows of 337:
      S-VCDPART  PASS = a.txt and avseq01.dat (1 of 64 sectors) extracted, the image KEPT - before: deleted
      S-VCDCOV, C-VCDCOV  PASS = a.txt and avseq01.dat (8 of 64 sectors) extracted, the image KEPT - before
                 (336's controls): deleted
      M-FORM2COV PASS = Session 01/a.txt and Session 01/avseq01.dat (8 of 64) extracted, KEPT - before: deleted
      S-VCDTAIL  PASS = a.txt and avseq01.dat (48 of 64; the other 16 hold data) extracted, KEPT - before: deleted
      S-VCDFULL, C-VCDFULL  (control) PASS = a.txt and avseq01.dat (all 64 sectors) extracted, the image deleted
      M-FORM2FULL (control) PASS = Session 01/a.txt and Session 01/avseq01.dat (64) extracted, deleted
      S-VCDGAP, C-VCDGAP  (control) PASS = a.txt and avseq01.dat (48 of 64; the other 16 empty Form 2
                 sectors, as vcdimager's gaps) extracted, the image deleted
      S-VCDCOV2, S-VCDZERO (336) PASS = the image KEPT
      (review 1) S-VCDBYTE PASS = a.txt and avseq01.dat (63 * 2048 + 1 bytes: the 64th data sector extracted
                 in part) extracted, the image KEPT; C-VCDTRUNC PASS = a.txt and avseq01.dat (48 sectors; 16
                 empty after it, then 1200 bytes of a 65th data sector end the image) extracted, KEPT
    With -FoldersOff ("Show Session As Directory" = 0 in the UnISO settings) only these run:
      MF-FORM2   PASS = a.txt extracted, KEPT; MF-FORM2COV PASS = a.txt and avseq01.dat (8 of 64), KEPT
      (before: deleted); MF-FORM2FULL (control) a.txt and avseq01.dat (64), deleted; MF-NOFS PASS = KEPT
    Feature 335's rows run again with 336's expectations (see 336's probe).
    The avseq01.dat content check 'stream:13:<n>' compares the file with the first 2048 bytes of each of the
    stream's first n sectors (the 2048-byte cut of Form 2 payloads is backlog item
    iso-plug-in-video-cd-mpeg-files-in-form-2-sectors-may).
    Every row also fails on a program exit, a bug report, a fatal window, or a main window that does not
    answer within 30 s (End-Row). Without WSL Ubuntu every row is NOT DRIVEN.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lib,
    [string]$MkImg,
    [switch]$FoldersOff
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -eq $_ }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Lib) { $Lib = Join-Path $Here '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1' }
if (-not $MkImg) { $MkImg = Join-Path $Here '..\..\334-uniso-session-missing\probe\mkimg334.sh' }
. $Lib
$Root = $TempRoot + '\tc337'
$P335 = Join-Path $Here '..\..\335-uniso-raw-track-lost\probe'
$P336 = Join-Path $Here '..\..\336-uniso-form2-uncovered\probe'
$StartDir = $Root + '\start'
# the plug-in's own box when a session's track does not open (IDS_ERROR_OPENING_MULTISESSION)
$MultiBox = 'Some error\(s\) occured while reading multisession image'

function WslPath([string]$p) { return ('/mnt/' + $p.Substring(0, 1).ToLower() + $p.Substring(2).Replace('\', '/')) }
function Tgt-Files([string]$Tgt) {
    if (-not [IO.Directory]::Exists($LP + $Tgt)) { return @() }
    $base = ($LP + $Tgt + '\')
    return @([IO.Directory]::GetFiles($LP + $Tgt, '*', [IO.SearchOption]::AllDirectories) | ForEach-Object { $_.Substring($base.Length).Replace('\', '/') } | Sort-Object)
}
function Content([string]$Tgt, [string]$Rel) { try { return [IO.File]::ReadAllText($LP + $Tgt + '\' + $Rel.Replace('/', '\')) } catch { return '<none>' } }
# 'size:<n>' compares the length; 'stream:<fill>:<sectors>' compares the bytes with the first 2048 user bytes
# of each of the stream track's first <sectors> sectors as img337.py writes them (((s + i) * fill) & 0xFF) -
# the file is read from the stream's sectors (review 1; the 2048-byte cut of each 2324-byte Form 2 payload
# is backlog item iso-plug-in-video-cd-mpeg-files-in-form-2-sectors-may)
function Matches-Want([string]$Tgt, [string]$Rel, [string]$Want) {
    $p = $LP + $Tgt + '\' + $Rel.Replace('/', '\')
    if ($Want.StartsWith('size:')) { try { return ((New-Object IO.FileInfo($p)).Length -eq [long]$Want.Substring(5)) } catch { return $false } }
    if ($Want.StartsWith('stream:')) {
        $w = $Want.Split(':'); $fill = [int]$w[1]; $n = [int]$w[2]
        try { $got = [IO.File]::ReadAllBytes($p) } catch { return $false }
        if ($got.Length -ne $n * 2048) { return $false }
        for ($s = 0; $s -lt $n; $s++) { for ($i = 0; $i -lt 2048; $i++) { if ($got[$s * 2048 + $i] -ne ((($s + $i) * $fill) -band 0xFF)) { return $false } } }
        return $true
    }
    return ((Content $Tgt $Rel) -ceq $Want)
}
function Find-Btn([IntPtr]$Dlg, [int]$CtlId) {
    return (@([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'Button' -and [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }) | Select-Object -First 1)
}
function Set-Field([IntPtr]$Dlg, [int]$CtlId, [string]$Text) {
    $f = Find-Ctl $Dlg $CtlId
    if ($f -eq [IntPtr]::Zero) { throw "field $CtlId not found" }
    [void][Drv098f]::SetText($f, $Text, 5000)
    if ([Drv098f]::GetText($f, 5000) -cne $Text) { throw "field $CtlId did not take the text" }
}

# the files of $Want (relative path -> content; compared without case) in tgt - exactly these; @(ok, facts)
function Check-Files([string]$Tgt, $Want) {
    $files = @(Tgt-Files $Tgt)
    $low = @($files | ForEach-Object { $_.ToLowerInvariant() })
    $missing = @($Want.Keys | Where-Object { $low -notcontains $_.ToLowerInvariant() })
    $bad = @($Want.Keys | Where-Object { $low -contains $_.ToLowerInvariant() } | Where-Object {
            $k = $_.ToLowerInvariant(); $real = @($files | Where-Object { $_.ToLowerInvariant() -eq $k })[0]
            -not (Matches-Want $Tgt $real $Want[$_]) })
    $ok = ($files.Count -eq $Want.Count -and $missing.Count -eq 0 -and $bad.Count -eq 0)
    $f = ('files {0}: {1}' -f $files.Count, ((@($files | ForEach-Object { Esc $_ })) -join ', '))
    if ($missing.Count) { $f += ('; missing: ' + ($missing -join ', ')) }
    if ($bad.Count) { $f += ('; wrong content: ' + ($bad -join ', ')) }
    return @($ok, $f)
}

# Unpack (Alt+F9) of the whole image into tgt with "Delete archive after unpacking"; $Kept = the listing
# is incomplete (the image kept), else the image deleted; $MultiErr = the plug-in's multi-session box must
# show (and is the only window), else no window at all
function Unpack-Row([string]$Case, [string]$Img0, $Want, [switch]$Kept, [switch]$MultiErr) {
    if (-not (Want $Case)) { return }
    if (-not [IO.File]::Exists($Img0)) { Row $Case 'RUN' 'NOT DRIVEN' ('no image ' + $Img0); return }
    $d = $Root + '\' + $Case; $tgt = $d + '\tgt'; NewDir ($d + '\src'); NewDir $tgt
    $img = $d + '\src\' + [IO.Path]::GetFileName($Img0); [IO.File]::Copy($Img0, $LP + $img)
    # a CloneCD image: its .ccd goes along (the plug-in reads the track table from it)
    $ccd0 = [IO.Path]::ChangeExtension($Img0, '.ccd'); if ($Img0.EndsWith('.img') -and [IO.File]::Exists($ccd0)) { [IO.File]::Copy($ccd0, $LP + [IO.Path]::ChangeExtension($img, '.ccd')) }
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
        $btn = Find-Btn $dlg 6210
        if (-not $btn -or -not [Drv098f]::IsWindowEnabled($btn)) { throw 'the box "Delete archive after unpacking" (6210) is missing or disabled' }
        [void][Drv098f]::Send($btn, 0x00F1, 1, 0, 5000)   # BM_SETCHECK BST_CHECKED
        Click-Ok $dlg
        Start-Sleep -Milliseconds 800
        $r = Serve $id 90 @(1, 6)
        $msgs = Msgs $r
        $fatal = Fatal-Win $id
        End-Row $Case $id $fatal $before; $id = 0
        $c = Check-Files $tgt $Want
        $isKept = [IO.File]::Exists($LP + $img)
        $all = @(($msgs -split ' \|\| ') | Where-Object { $_ -ne 'no window' })
        $multi = @($all | Where-Object { $_ -match $MultiBox })
        $other = @($all | Where-Object { $_ -notmatch $MultiBox })
        $winOk = ($other.Count -eq 0) -and (($multi.Count -gt 0) -eq [bool]$MultiErr)
        $ok = $c[0] -and (-not $fatal) -and $winOk -and ($isKept -eq [bool]$Kept)
        Row $Case 'RUN' (V $ok) ('{0}; files ok: {1}; image kept: {2} (want {3}); windows as expected: {4} (multi-session box {5}, want {6}); fatal: {7}; windows: {8}' -f $c[1], $c[0], $isKept, [bool]$Kept, $winOk, ($multi.Count -gt 0), [bool]$MultiErr, (Tail ([string]$fatal) 200), (Tail $msgs 400))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

$backup = Join-Path $env:TEMP 'tc337_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    # review 2: the listing without "Session NN" folders (the UnISO setting; the registry backup restores it)
    if ($FoldersOff) { & reg.exe add "$RegKey\0.1\Plugins Configuration\UnISO" /v 'Show Session As Directory' /t REG_DWORD /d 0 /f | Out-Null }
    Out ("iso337_probe (feature 337) {0}{1}" -f $Label, $(if ($FoldersOff) { ' (Session NN folders off)' } else { '' }))
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''

    $s = $Root + '\seeds'; NewDir $s
    $py = Join-Path $P335 'img335.py'
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $mk = & wsl -d Ubuntu -- sh (WslPath $MkImg) (WslPath $s) 2>&1
    $mk2 = & wsl -d Ubuntu -- sh (WslPath (Join-Path $P336 'mkimg336.sh')) (WslPath $s) 2>&1
    $made = @()
    if ([IO.File]::Exists("$s\s1.iso") -and [IO.File]::Exists("$s\s2.iso")) {
        foreach ($k in @('multi_nofs', 'multi_ok_2336', 'multi_nofs_f1', 'multi_form2', 'single_vcd', 'single_nofs', 'single_raw', 'multi_ff_f1', 'multi_txt_f1', 'multi_u16_f1', 'multi_u16s_f1', 'single_short')) { $made += & python -I $py $k "$s\s1.iso" "$s\s2.iso" "$s\s2.lba" "$s\$k.nrg" 2>&1 }
        $py2 = Join-Path $P335 'ccd335.py'
        foreach ($k in @('ccd_vcd', 'ccd_nofs_m1', 'ccd_nofs_f1', 'ccd_vcdreal')) { $made += & python -I $py2 $k "$s\s1.iso" "$s\s2.iso" "$s\$k.img" 2>&1 }
    }
    if ([IO.File]::Exists("$s\s1c.iso")) {
        $py3 = Join-Path $Here 'img337.py'
        foreach ($k in @('single_vcdcov', 'single_vcdcov2', 'single_vcdzero', 'multi_form2cov', 'single_vcdpart', 'single_vcdfull', 'multi_form2full', 'single_vcdgap', 'single_vcdtail', 'single_vcdbyte')) { $made += & python -I $py3 $k "$s\s1c.iso" "$s\$k.nrg" 2>&1 }
        foreach ($k in @('ccd_vcdcov', 'ccd_vcdfull', 'ccd_vcdgap', 'ccd_vcdtrunc')) { $made += & python -I $py3 $k "$s\s1c.iso" "$s\$k.img" 2>&1 }
    }
    $ErrorActionPreference = $old
    Out ("seeds: {0}" -f ((@([IO.Directory]::GetFiles($s, '*.*') | ForEach-Object { [IO.Path]::GetFileName($_) }) | Sort-Object) -join ','))
    foreach ($m in $made) { Out ('img: ' + "$m") }
    if (-not [IO.File]::Exists("$s\s1.iso")) { Out ('mkimg334.sh: ' + (($mk | ForEach-Object { "$_" }) -join ' ')) }
    if (-not [IO.File]::Exists("$s\s1c.iso")) { Out ('mkimg336.sh: ' + (($mk2 | ForEach-Object { "$_" }) -join ' ')) }
    Out ''

    $both = [ordered]@{ 'Session 01/a.txt' = 'A1'; 'Session 02/b.txt' = 'B2' }
    $first = [ordered]@{ 'Session 01/a.txt' = 'A1' }
    $a = [ordered]@{ 'a.txt' = 'A1' }
    $cov = [ordered]@{ 'a.txt' = 'A1'; 'avseq01.dat' = 'stream:13:8' }
    $zero = [ordered]@{ 'a.txt' = 'A1'; 'avseq01.dat' = 'size:0' }
    $mcov = [ordered]@{ 'Session 01/a.txt' = 'A1'; 'Session 01/avseq01.dat' = 'stream:13:8' }
    $part = [ordered]@{ 'a.txt' = 'A1'; 'avseq01.dat' = 'stream:13:1' }
    $full = [ordered]@{ 'a.txt' = 'A1'; 'avseq01.dat' = 'stream:13:64' }
    $mfull = [ordered]@{ 'Session 01/a.txt' = 'A1'; 'Session 01/avseq01.dat' = 'stream:13:64' }
    $gap = [ordered]@{ 'a.txt' = 'A1'; 'avseq01.dat' = 'stream:13:48' }
    $byte = [ordered]@{ 'a.txt' = 'A1'; 'avseq01.dat' = 'size:129025' }
    if ($FoldersOff) {
        # review 2: one listing of the last data track - the same rule
        Unpack-Row 'MF-FORM2' "$s\multi_form2.nrg" $a -Kept
        Unpack-Row 'MF-FORM2COV' "$s\multi_form2cov.nrg" $cov -Kept
        Unpack-Row 'MF-FORM2FULL' "$s\multi_form2full.nrg" $full
        Unpack-Row 'MF-NOFS' "$s\multi_nofs.nrg" $a -Kept
    }
    else {
    # feature 337: a stream covered only in part keeps the image
    Unpack-Row 'S-VCDPART' "$s\single_vcdpart.nrg" $part -Kept
    Unpack-Row 'S-VCDCOV' "$s\single_vcdcov.nrg" $cov -Kept
    Unpack-Row 'C-VCDCOV' "$s\ccd_vcdcov.img" $cov -Kept
    Unpack-Row 'M-FORM2COV' "$s\multi_form2cov.nrg" $mcov -Kept
    Unpack-Row 'S-VCDTAIL' "$s\single_vcdtail.nrg" $gap -Kept
    # (review 1) the last sector extracted in part; a sector the image stores in part
    Unpack-Row 'S-VCDBYTE' "$s\single_vcdbyte.nrg" $byte -Kept
    Unpack-Row 'C-VCDTRUNC' "$s\ccd_vcdtrunc.img" $gap -Kept
    # (controls) covered wholly, or up to empty gap sectors: deleted
    Unpack-Row 'S-VCDFULL' "$s\single_vcdfull.nrg" $full
    Unpack-Row 'C-VCDFULL' "$s\ccd_vcdfull.img" $full
    Unpack-Row 'M-FORM2FULL' "$s\multi_form2full.nrg" $mfull
    Unpack-Row 'S-VCDGAP' "$s\single_vcdgap.nrg" $gap
    Unpack-Row 'C-VCDGAP' "$s\ccd_vcdgap.img" $gap
    # feature 336
    Unpack-Row 'S-VCDCOV2' "$s\single_vcdcov2.nrg" $cov -Kept
    Unpack-Row 'S-VCDZERO' "$s\single_vcdzero.nrg" $zero -Kept
    # feature 335's rows (S-VCD, M-FORM2, C-VCD, C-VCDREAL turned by 336)
    Unpack-Row 'M-NOFS' "$s\multi_nofs.nrg" $first -Kept
    Unpack-Row 'M-OK-2336' "$s\multi_ok_2336.nrg" $both
    Unpack-Row 'M-NOFS-F1' "$s\multi_nofs_f1.nrg" $first -Kept
    Unpack-Row 'M-FORM2' "$s\multi_form2.nrg" $first -Kept
    Unpack-Row 'S-VCD' "$s\single_vcd.nrg" $a -Kept
    Unpack-Row 'S-NOFS' "$s\single_nofs.nrg" $a -Kept
    Unpack-Row 'S-RAW' "$s\single_raw.nrg" $a -Kept
    Unpack-Row 'M-FF-F1' "$s\multi_ff_f1.nrg" $first -Kept
    Unpack-Row 'M-TXT-F1' "$s\multi_txt_f1.nrg" $first -Kept
    Unpack-Row 'C-VCD' "$s\ccd_vcd.img" $a -Kept
    Unpack-Row 'C-NOFS-M1' "$s\ccd_nofs_m1.img" $a -Kept
    Unpack-Row 'C-NOFS-F1' "$s\ccd_nofs_f1.img" $a -Kept
    Unpack-Row 'M-U16-F1' "$s\multi_u16_f1.nrg" $first -Kept
    Unpack-Row 'M-U16S-F1' "$s\multi_u16s_f1.nrg" $first -Kept
    Unpack-Row 'C-VCDREAL' "$s\ccd_vcdreal.img" $a -Kept
    Unpack-Row 'S-SHORT' "$s\single_short.nrg" $a -Kept
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
