# Contract - the tar member name rule (`SalTarNormalizeNameU8`, `src/common/saltarlink.h`)

Internal to the tar plug-in and saltests (not a plug-in interface).

```text
void SalTarNormalizeNameU8(const char* src, char* dst)
  dst: at least strlen(src) + 1 bytes; written and terminated; never longer than src
```

| src | dst |
|---|---|
| `a.txt`, `./a.txt` | `a.txt` |
| `sub/b.txt`, `sub//b.txt`, `/sub/b.txt`, `sub\b.txt` | `sub\b.txt` |
| `dir/` | `dir\` |
| `sub/../a.txt`, `x/../a.txt` | `a.txt` |
| `x/y/../b.txt` | `x\b.txt` |
| `a/b/../../c` | `c` |
| `../../empty`, `q/../../f.txt` (for `f.txt`) | `empty`, `f.txt` |
| `a/..`, `a/../`, `..`, `.`, `` | `` |
| `x/y/../` | `x\` |
| `..a/b..`, `.../a` | `..a\b..`, `...\a` |

Every name without a `..` component: the same result as before feature 396.
