#!/bin/sh
# Feature 333: the seed images of iso333_probe.ps1, made by xorriso in WSL Ubuntu (fetched without root
# into ~/tc-xorriso once, as features 322 / 329 / 330 / 332). Tree: a/side.txt (SIDE), top.txt (TOP),
# zlast/z.txt (Z).
# $1 = the output folder (a /mnt/... path inside the probe's fixture)
# Writes: hdh.iso (xorriso -hfsplus on, no Rock Ridge / Joliet: ISO 9660 + HFS+, a/side.txt hidden from
#         the ISO 9660 part - it is only in the HFS+ part; volume id TC333),
#         apm.iso (the layout of Ubuntu's / Debian's install images: -isohybrid-mbr with
#         -isohybrid-apm-hfsplus and an EFI boot image - an Apple partition map whose "Apple_HFS"
#         partition holds the EFI image, no HFS+ volume; Rock Ridge + Joliet; a/side.txt, top.txt;
#         volume id TC333APM). Its MBR template is 432 bytes starting with 33 ED and 30 NOPs (what
#         libisofs requires for an Apple partition map), the boot images are zeros.
set -e
D="$HOME/tc-xorriso"
X="$D/root"
if [ ! -x "$X/usr/bin/xorriso" ]; then
    mkdir -p "$D"
    cd "$D"
    apt-get download xorriso libisoburn1t64 libisofs6t64 libburn4t64 >/dev/null 2>&1
    mkdir -p root
    for f in ./*.deb; do dpkg -x "$f" root; done
    cd - >/dev/null
fi
XO="env LD_LIBRARY_PATH=$X/usr/lib/x86_64-linux-gnu $X/usr/bin/xorriso"
out="$1"
src="$out/src333"
rm -rf "$src"
mkdir -p "$src/a" "$src/zlast"
printf 'SIDE' > "$src/a/side.txt"
printf 'TOP' > "$src/top.txt"
printf 'Z' > "$src/zlast/z.txt"
rm -f "$out/hdh.iso" "$out/apm.iso"
$XO -outdev "$out/hdh.iso" -volid TC333 -rockridge off -joliet off -hfsplus on -map "$src" / -hide iso_rr /a/side.txt >/dev/null 2>&1
rm -rf "$src"
mkdir -p "$src/a" "$src/boot" "$src/isolinux"
printf 'SIDE' > "$src/a/side.txt"
printf 'TOP' > "$src/top.txt"
dd if=/dev/zero of="$src/boot/efi.img" bs=1024 count=256 2>/dev/null
dd if=/dev/zero of="$src/isolinux/isolinux.bin" bs=1024 count=4 2>/dev/null
mbr="$out/mbr333.bin"
dd if=/dev/zero of="$mbr" bs=432 count=1 2>/dev/null
printf '\063\355\220\220\220\220\220\220\220\220\220\220\220\220\220\220\220\220\220\220\220\220\220\220\220\220\220\220\220\220\220\220' | dd of="$mbr" conv=notrunc 2>/dev/null
$XO -as mkisofs -r -J -l -V TC333APM -o "$out/apm.iso" -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e boot/efi.img -no-emul-boot -isohybrid-gpt-basdat -isohybrid-apm-hfsplus -isohybrid-mbr "$mbr" "$src" >/dev/null 2>&1
rm -rf "$src" "$mbr"
ls "$out"
