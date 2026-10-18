state: not-sent

Ďakujeme za nahlásenie aj za snímku obrazovky – práve podľa nej sme našli príčinu.

**Čo sa stalo:** chyba nesúvisí s výkričníkom v ceste. Na snímke vkladáte súbor do **toho istého priečinka**, z ktorého bol skopírovaný, takže program pre kópiu vytvorí nové meno `zsu-1191327 - Kópia.zip`. Vo verzii 0.1.9 sa slovo „Kópia“ zo slovenského prekladu vkladalo do mena súboru v nesprávnom kódovaní (kódová stránka namiesto UTF-8). Windows také meno odmietol, preto hlásenie *(123) The filename, directory name, or volume label syntax is incorrect*. To isté by sa stalo v ktoromkoľvek priečinku pri slovenskom (alebo českom, maďarskom …) rozhraní – v priečinkoch s „!“ ste zrejme len vkladali do toho istého priečinka.

**Oprava:** je súčasťou verzie **0.1.10** (zmena 127 – texty prekladov sa do mien súborov a hlásení skladajú v UTF-8). Overili sme, že kopírovanie v priečinku `!!temp` pod menom s „ó“ funguje.

Prosíme, vyskúšajte to po aktualizácii na 0.1.10. Ak by vkladanie stále zlyhávalo – napríklad pri vkladaní z **iného** priečinka do priečinka s „!“ – napíšte, prosím, odkiaľ súbory kopírujete (panel Tandem Commandera alebo Prieskumník) a aké hlásenie sa zobrazí.

---

*English:* Thanks for the report and the screenshot, which showed the cause. The exclamation mark is not involved: the screenshot shows a file pasted into **its own folder**, so the program named the copy `zsu-1191327 - Kópia.zip`. In 0.1.9 the translated word "Kópia" was put into the file name in the wrong encoding (code page instead of UTF-8), and Windows refused the name with error 123 – in any folder, with a Slovak (Czech, Hungarian, …) user interface. Version **0.1.10** fixes it (feature 127); copying within a folder named `!!temp` under a name with "ó" works. Please try 0.1.10; if paste still fails (for example from another folder into a folder with "!"), tell us where the files were copied from (a Tandem Commander panel or Explorer) and which message appears.
