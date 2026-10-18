"""Rewrites the predecessors' product identity out of translated text.

The legacy translations were written for Altap/Open Salamander and carry its
product name, its vendor's name, and links to that vendor's sites. None of that
may reach a Tandem Commander user (spec FR-018, FR-019, FR-020, FR-021).
Feature 046 added a second predecessor: the committed translations were
rebranded to Newt Commander in feature 038, so its name, binary and URLs are
rewritten to Tandem Commander by the same suffix-preserving mechanism.

What the real data contains (1,361 brand occurrences in 14 forms across the ten
committed languages, plus four distinct URLs):

* prose mentions -- ``Open Salamander``, ``Altap Salamander``, ``Altap Sal.``
* the old binary in command-line help -- ``SALAMAND.EXE``
* the vendor alone -- ``Altap`` / ``altap`` / ``ALTAP``
* **inflected forms** -- ``Salamandera`` (cs gen.), ``Salamanderu`` (cs dat.),
  ``Salamanderů`` (cs pl. gen.), ``Salamanderov`` (sk), ``Salamanders`` (de/nl
  gen.), ``Salamandert`` (hu acc.)
* URLs -- ``www.altap.cz``, ``www.altap.cz/salamander/downloads/beta``,
  ``www.pictview.com/salamander``

**Inflection is handled by keeping the suffix.** ``Salamander`` and
``Commander`` are both masculine nouns ending in *-er*, so they take the same
declension in the Slavic languages here, and the Germanic/Hungarian endings
carry over too: ``Salamandera -> Tandem Commandera``, ``Salamanders -> Tandem
Commanders``, ``Salamandert -> Tandem Commandert``. That keeps the grammar of the
surrounding sentence intact, which a bare replacement would break.

It is not perfect -- a few sentences will still read stiffly, and a preposition
may occasionally want changing. Those are flagged for human review rather than
guessed at (spec T049).
"""

from __future__ import annotations

import re

from .validate import reinsert_accel, split_accel

PRODUCT = "Tandem Commander"
PROJECT = "Tandem Commander Project"
WEB = "www.tandemcommander.org"

#: Applied in order. Longest and most specific first, so that "Open Salamander"
#: is consumed before the bare "Salamander" rule can see it.
_RULES: list[tuple[re.Pattern, object]] = [
    # --- the previous identity (feature 046): Newt Commander -> Tandem
    # Commander. URLs first so the name rules cannot mangle them, then the old
    # binary, then the name keeping any inflectional suffix ("Newt Commanderu"
    # -> "Tandem Commanderu" -- both are masculine *-er* nouns, the declension
    # carries over exactly as it did for Salamander -> Commander). -----------
    (re.compile(r"github\.com/newtcommander/newtcommander"), "github.com/tandemcommander/tandemcommander"),
    (re.compile(r"(?:https?://)?www\.newtcommander\.org(?:/[\w\-./?=&#%]*)?", re.I), WEB),
    (re.compile(r"(?:https?://)?newtcommander\.org(?:/[\w\-./?=&#%]*)?", re.I), WEB),
    (re.compile(r"NEWTCOMMANDER\.EXE\b"), "TANDEMCOMMANDER.EXE"),
    (re.compile(r"newtcommander\.exe\b"), "tandemcommander.exe"),
    (re.compile(r"NewtCommander\.exe\b"), "TandemCommander.exe"),
    (re.compile(r"\bNEWT COMMANDER(\w*)"), lambda m: PRODUCT.upper() + m.group(1)),
    (re.compile(r"\bNewt Commander(\w*)"), lambda m: PRODUCT + m.group(1)),
    (re.compile(r"\bnewt commander(\w*)"), lambda m: PRODUCT.lower() + m.group(1)),
    # --- e-mail addresses before URLs: the domain rules below would otherwise
    # rewrite only the host part and leave a broken "support@..." behind. -----
    (re.compile(r"\b[\w.+\-]+@(?:altap\.cz|pictview\.com)\b", re.I), WEB),
    # --- URLs: they embed the product name and would be mangled by the name
    # rules below. ------------------------------------------------------------
    (re.compile(r"(?:https?://)?www\.altap\.cz(?:/[\w\-./?=&#%]*)?", re.I), WEB),
    (re.compile(r"(?:https?://)?altap\.cz(?:/[\w\-./?=&#%]*)?", re.I), WEB),
    # PictView's own site, whose /salamander path documented an integration this
    # product no longer has (feature 006 moved pictview onto Windows WIC).
    (re.compile(r"(?:https?://)?(?:www\.)?pictview\.com(?:/[\w\-./?=&#%]*)?", re.I), WEB),
    # --- the old binary, as it appears in command-line usage text ------------
    # No leading \b: the usage text starts with the escape "\n", so the
    # character before "SALAMAND" is the letter "n" and a word boundary would
    # never match there.
    (re.compile(r"SALAMAND\.EXE\b"), "TANDEMCOMMANDER.EXE"),
    (re.compile(r"salamand\.exe\b"), "tandemcommander.exe"),
    (re.compile(r"Salamand\.exe\b"), "TandemCommander.exe"),
    # --- full product names, including the French abbreviation ---------------
    (re.compile(r"\bAltap\s+Sal\."), PRODUCT),
    (re.compile(r"\b(?:Open|Altap)\s+SALAMANDER\b"), PRODUCT.upper()),
    (re.compile(r"\b(?:Open|Altap)\s+Salamander(\w*)"), lambda m: PRODUCT + m.group(1)),
    (re.compile(r"\b(?:open|altap)\s+salamander(\w*)", re.I), lambda m: PRODUCT + m.group(1)),
    # --- bare product name, keeping any inflectional suffix ------------------
    (re.compile(r"\bSALAMANDER(\w*)"), lambda m: PRODUCT.upper() + m.group(1)),
    (re.compile(r"\bSalamander(\w*)"), lambda m: PRODUCT + m.group(1)),
    (re.compile(r"\bsalamander(\w*)"), lambda m: PRODUCT + m.group(1)),
    # --- vendor on its own, once the product forms are gone ------------------
    (re.compile(r"\bALTAP\b"), PROJECT.upper()),
    (re.compile(r"\bAltap\b"), PROJECT),
    (re.compile(r"\baltap\b"), PROJECT),
]


def _apply_rules(text: str) -> str:
    for pattern, repl in _RULES:
        text = pattern.sub(repl, text)
    return text


def rebrand(text: str) -> str:
    """Rewrite one string. Safe to call on text with no brand mentions.

    Two passes, and the order matters. The straightforward pass runs first and
    is returned as-is whenever it changes anything, so text that has no brand
    mention comes back **byte-identical**.

    Only when nothing matched is the accelerator lifted out and the rules
    retried. That covers ``"Position am Salamand&er Hauptfenster"``, where the
    marker sits inside the product name and splits the word that every
    ``\\bSalamander\\b`` rule is looking for.

    Doing the strip unconditionally would be wrong: re-applying the marker puts
    it at the first occurrence of its letter, which is not necessarily where a
    human translator put it. That silently relocated the accelerator in 1,145
    already-translated entries -- ``"Porovnat a&tributy"`` became
    ``"Porovna&t atributy"`` -- none of which had anything to do with branding.
    """
    out = _apply_rules(text)
    if out != text:
        return out

    clean, letter = split_accel(text)
    if letter is None:
        return text
    cleaned = _apply_rules(clean)
    if cleaned == clean:
        return text  # nothing to rebrand; leave the accelerator exactly as it was
    return reinsert_accel(cleaned, letter)


def find_residue(text: str) -> list[str]:
    """Return any predecessor identity still present after rewriting.

    Used as the SC-007 gate: shipped text must contain none of this.
    """
    hits = re.findall(
        r"\b\w*(?:[Ss]alamand|SALAMAND|[Aa]ltap|ALTAP)\w*|\baltap\.cz\S*|\bpictview\.com\S*"
        r"|\b(?:Newt|NEWT|newt)\s+(?:Commander|COMMANDER|commander)\w*"
        r"|\b(?:NewtCommander|NEWTCOMMANDER|newtcommander)\S*",
        text,
    )
    return hits


def main(argv: list[str] | None = None) -> int:
    """Report what rebranding would change across the committed translations."""
    import argparse
    import sys
    from collections import Counter

    import fnmatch

    from .config import load_enabled_modules, load_languages
    from .merge import load_brand_exempt
    from .slt import load
    from .uicontext import load_symbols

    ap = argparse.ArgumentParser(prog="translate-rebrand")
    ap.add_argument("--samples", type=int, default=12)
    ap.add_argument(
        "--apply",
        action="store_true",
        help="rewrite the committed .slt files in place (no API, no re-translation)",
    )
    args = ap.parse_args(argv)

    changed = 0
    scanned = 0
    residue: Counter = Counter()
    samples: list[tuple[str, str]] = []

    # DELIBERATELY include disabled languages (feature 039, FR-013 opt-in used
    # from code rather than a command line). Rebranding translates nothing and
    # spends no budget -- it is a correctness sweep over committed source. If it
    # skipped disabled languages, brand residue would quietly accumulate in
    # their .slt files and surface the moment one is re-enabled, which would
    # make FR-005 ("re-enabling requires no re-translation") false in practice.
    for lang in load_languages(include_disabled=True):
        for module in load_enabled_modules():
            path = lang.directory / f"{module.name}.slt"
            if not path.is_file():
                continue
            slt = load(path)
            dirty = False
            # texts that name a predecessor on purpose (translations/brand-exempt.json, 245)
            exempt = load_brand_exempt(module)
            symbols = load_symbols(module) if exempt else {}
            for section, row in slt.iter_entries():
                scanned += 1
                rid = row.entry_id if row.entry_id is not None else (section.number if section.kind == "DIALOG" else None)
                sym = symbols.get(rid) if rid is not None else None
                if sym is not None and any(fnmatch.fnmatchcase(sym, p) for p in exempt):
                    continue
                new = rebrand(row.text)
                if new != row.text:
                    changed += 1
                    dirty = True
                    if len(samples) < args.samples:
                        samples.append((row.text, new))
                    row.text = new
                for r in find_residue(row.text):
                    residue[r] += 1
            if dirty and args.apply:
                slt.write(path)

    print(f"scanned {scanned} entries, {changed} would change")
    print()
    for before, after in samples:
        print(f"  - {before[:100]}")
        print(f"  + {after[:100]}")
        print()
    if residue:
        print("REMAINING predecessor identity after rewrite:")
        for word, n in residue.most_common(20):
            print(f"  {n:>5}x  {word}")
        return 1
    print("no predecessor identity remains in rewritten text")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
