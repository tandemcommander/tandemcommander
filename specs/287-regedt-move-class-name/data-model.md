# Data model: the probe's fixture (feature 287)

Everything lives under `HKCU\Software\TcProbe287` and is rebuilt before each row.

| Key | Class | Contents | Used by |
|---|---|---|---|
| `Zdroj\<K>` (`<K>` = `Klíč žluťoučký`) | `TřídaA` | value `v` = `ALPHA`, subkey `podklíč` (value `w` = `BETA`) | every row: the key copied or moved |
| `Cíl řx` | - | empty | MOVE (target folder) |
| `Jiná\<K>` | `TřídaB` | empty | CLASSCOPY, CLASSMOVE, CLASSYES |
| `Stejná\<K>` | `TřídaA` | empty | CLASSSAME |
| `Nový` | - | empty | CLASSNEW |
| `Hnízdo\<K>` | `TřídaA` | empty; subkey `podklíč` with class `TřídaB` | NESTCANCEL, NESTMOVE |
| `Obě\<K>` | `TřídaB` | empty; subkey `podklíč` with class `TřídaB` | NESTALL, NESTYES |

Parents (`Zdroj`, `Jiná`, ...) are created first without a class: `RegCreateKeyEx` gives the
class also to the parents it creates.

Rows with Move select `<K>` in `Zdroj`; the state after the answer is read through the registry
API (keys, values, class names).
