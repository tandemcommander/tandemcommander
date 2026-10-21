# Probe rows of `probe/move287_probe.ps1` (feature 287)

Each row: the panel shows `reg:\HKEY_CURRENT_USER\Software\TcProbe287\Zdroj`, the key `<K>` is
focused, F5 (727) or F6 (728) opens the plug-in's dialog, the target path is typed, OK.

| Row | Command, target | Answer | PASS when |
|---|---|---|---|
| MOVE | F6 into `Cíl řx` | - | `Cíl řx\<K>` holds `v` = ALPHA and `podklíč\w` = BETA; `Zdroj\<K>` is gone; no question box |
| MOVESELF | F6 into `Zdroj\<K>\podklíč` | Cancel | the box text is the "cannot move into itself" template (id 1066) with `<K>`; fixture unchanged |
| CLASSCOPY | F5 into `Jiná` | Cancel | a question box: its texts hold `HKEY_CURRENT_USER\Software\TcProbe287\Zdroj\<K>` and the question template (id 1068); `Jiná\<K>` has no `v`; fixture unchanged |
| CLASSMOVE | F6 into `Jiná` | Cancel | as CLASSCOPY; `Zdroj\<K>` still holds `v` and `podklíč` |
| CLASSYES | F6 into `Jiná` | Yes | the question was asked; `Jiná\<K>` holds `v` and `podklíč\w`, keeps class `TřídaB`; `Zdroj\<K>` is gone |
| CLASSSAME | F5 into `Stejná` | - | no question; `Stejná\<K>` holds `v` |
| CLASSNEW | F5 into `Nový` | - | no question; `Nový\<K>` holds `v` and has class `TřídaA` |
| END (each row) | - | - | exit code 0, no stray window, no crash report |

Expectation on the build before the fix (`-Expect before`): CLASSCOPY, CLASSMOVE, CLASSYES FAIL
(no question; the values are merged). Every other row PASSes on both builds.
Languages: `-Lang czech` and `-Lang english`.
