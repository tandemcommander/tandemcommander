Děkuji za nahlášení, chybu se podařilo najít a opravit.

**Verdikt: chyba je platná.** Oprava vyjde v příští verzi **0.1.10** (feature 128, větev `128-shortcut-target-unicode`).

### Co se děje

Hlášení neuvádí, kam zástupce vede, takže jsem příčinu hledal měřením na vydané verzi 0.1.9. Přesně tu hlášku ze screenshotu - `(123) Název souboru či adresáře nebo jmenovka svazku je nesprávná.` - dostanu u **každého zástupce, jehož cílová cesta obsahuje jiné písmeno než z prosté ASCII**, tedy i obyčejnou českou diakritiku kdekoli v cestě:

| Zástupce vede na | Enter v 0.1.9 |
|---|---|
| složku s cestou bez diakritiky | otevře složku |
| složku `...\Účetnictví` | hláška (123) ze screenshotu |
| složku s řeckým názvem | stejná hláška |
| hlouběji zanořenou složku s oběma | stejná hláška |
| síťovou cestu `\\server\share\...\Účetnictví` | stejná hláška |
| složku bez diakritiky, zástupce sám má diakritiku v názvu | otevře složku |

Na písmenech v názvu samotného zástupce (`ARCHIV.lnk`) tedy nezáleží, rozhoduje cesta, na kterou ukazuje. Stejně selhával i příkaz *Přejít na cíl zástupce* (hláškou „Nelze získat cíl zástupce...").

**Příčina:** program četl cíl zástupce přes starší rozhraní Windows, které vrací cestu v kódové stránce systému, ale uvnitř pracuje s cestami v UTF-8. Cesta s diakritikou tak nebyla platná a kontrola cesty ji odmítla jako „nesprávný název". Průzkumník Windows čte cíl v Unicode, proto v něm stejný zástupce funguje. Při přetažení souborů na zástupce už to bylo opraveno dříve, na Enter / dvojklik a na *Přejít na cíl zástupce* se zapomnělo.

### Oprava

Obě místa teď čtou cíl zástupce v Unicode jedním společným pravidlem. Cesta se použije vždy celá; kdyby se do programu nevešla, je odmítnuta, nikdy se nezkrátí na jinou cestu.

### Testy

- Automatický test nad skutečnými zástupci (7 zástupců: bez diakritiky, s českou diakritikou, s řečtinou, zanořená kombinace, síťová cesta, zástupce s diakritikou ve vlastním názvu, zástupce na soubor), Enter i *Přejít na cíl zástupce*, kontroluje se přesně složka, ve které panel skončí:

  | Verze | Výsledek |
  |---|---|
  | 0.1.9 | 11 v pořádku, **7 selhání** (všechny cíle s diakritikou nebo jiným písmem) |
  | s opravou | **18 v pořádku, 0 selhání** |

- 39 nových jednotkových testů: zástupci na složky pojmenované česky, řecky, čínsky a s emoji se přečtou přesně; cesta se buď vrátí celá, nebo vůbec.
- Nezávislá revize kódu se zaměřením na dlouhé cílové cesty (žádné přetečení ani zkrácení nenašla).
- Druhé, nezávislé ověření hotové opravy vlastním testem: 28 skutečných zástupců (česky, řecky, čínsky, emoji, síťové cesty, kořen disku, systémové složky, neexistující cíl, relativní cesta, proměnná prostředí), 617 kontrol bez nálezu. Jinou příčinu stejné hlášky, na kterou by fungující zástupce mohl narazit, nenašlo.
- Dvojklik skutečnou myší automatický test neumí; spouští ale stejný kód jako Enter.

### Prosba

Předpokládám, že Váš zástupce `ARCHIV` vede na složku, která má v cestě diakritiku (nebo na síťovou či OneDrive cestu s diakritikou). Pokud by po aktualizaci na 0.1.10 problém přetrval, napište prosím přesný cíl zástupce (pravé tlačítko > Vlastnosti > pole *Cíl*) - šlo by pak o jinou příčinu se stejnou hláškou.

Jedno známé omezení zůstává a je zapsané k dořešení: zástupce, který sám leží ve složce s velmi dlouhou cestou (přes 260 bajtů v UTF-8, tedy zhruba 130 písmen s diakritikou), program odmítne jako „příliš dlouhý název".

Oprava bude součástí **Tandem Commanderu 0.1.10**.
