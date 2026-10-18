"""DeepL translation backend.

Used offline by :mod:`translate.merge` to fill entries no human translation
covers. The build never imports this module and never touches the network
(spec FR-023).

Two things make DeepL a good fit for resource strings specifically:

* **``tag_handling=xml`` + ``ignore_tags``** lets the placeholders be protected
  *by the API* rather than by hoping the engine leaves them alone. Every
  ``%s``, ``\\n``, ``&`` and ``\\tCtrl+C`` is wrapped in ``<x>…</x>`` before
  sending and unwrapped afterwards, so DeepL moves them but never rewrites
  them.
* **``preserve_formatting``** stops it from "fixing" leading/trailing spacing
  and punctuation, which in a UI string is deliberate (``"Copying: "``).

Quota: the free tier bills **characters sent**. Callers should deduplicate
before calling -- ``translate_batch`` does not, because it cannot know which
duplicates span modules.
"""

from __future__ import annotations

import html
import json
import re
import time
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path

from . import REPO_ROOT
from .validate import reinsert_accel, split_accel

#: Our language folder -> DeepL target code.
TARGET_CODES = {
    "czech": "CS",
    "german": "DE",
    "french": "FR",
    "dutch": "NL",
    "hungarian": "HU",
    "romanian": "RO",
    "russian": "RU",
    "slovak": "SK",
    "chinesesimplified": "ZH",
    "spanish": "ES",
    "ukrainian": "UK",
}

#: DeepL accepts up to 50 texts per request.
BATCH_SIZE = 50

#: Everything that must survive translation untouched. Order matters: the
#: escape for a literal backslash is matched before the shorter sequences, and
#: the shortcut tail is handled separately by :func:`_protect`.
_PROTECT = re.compile(
    r"(\\\\|\\n|\\r|\\t|\\\"|%(?:\d+\$)?[-+ #0]*\d*(?:\.\d+)?(?:hh|h|ll|l|L|z|j|t)?[diouxXeEfgGaAcspn%]|&&|&)"
)


class DeepLError(RuntimeError):
    pass


def load_key(path: Path | None = None) -> str:
    """Read the API key. Never logged or echoed by this module."""
    path = Path(path) if path else REPO_ROOT / "temp" / "deepl_key.txt"
    if not path.is_file():
        raise DeepLError(
            f"DeepL key not found at {path}. Put the key there, or pass --key-file."
        )
    key = path.read_text(encoding="utf-8").strip()
    if not key:
        raise DeepLError(f"{path} is empty")
    return key


def api_host(key: str) -> str:
    # DeepL routes free-tier keys to a separate host; they carry a ":fx" suffix.
    return "https://api-free.deepl.com" if key.endswith(":fx") else "https://api.deepl.com"


#: The shortcut separator as it appears in a .slt: a literal backslash followed
#: by "t", NOT a tab character. The format is line-based and contains no real
#: control characters, so matching "\t" (a tab) would never fire.
SHORTCUT_SEP = "\\" + "t"


def _split_tail(text: str) -> tuple[str, str]:
    """Split off the shortcut label: ``&Copy\\tCtrl+C`` -> ``(&Copy, \\tCtrl+C)``."""
    i = text.find(SHORTCUT_SEP)
    return (text[:i], text[i:]) if i >= 0 else (text, "")



def _protect(text: str) -> str:
    """Wrap non-translatable fragments in ignore tags.

    The shortcut label (everything from ``\\t``) is protected as one unit -- key
    names like ``Ctrl+C`` are not words and must not be translated.

    Each segment is escaped exactly once. Escaping the whole string first and
    then running the token regex over the result would be wrong: ``&`` has
    already become ``&amp;`` by then, the regex matches the ``&`` inside that
    entity, and the text comes back as ``& amp;CRC`` -- a destroyed accelerator.
    """
    out: list[str] = []
    pos = 0
    for m in _PROTECT.finditer(text):
        out.append(html.escape(text[pos : m.start()]))
        out.append(f"<x>{html.escape(m.group(0))}</x>")
        pos = m.end()
    out.append(html.escape(text[pos:]))
    return "".join(out)


def _unprotect(text: str) -> str:
    return html.unescape(re.sub(r"</?x>", "", text))


@dataclass
class Usage:
    count: int = 0
    limit: int = 0

    @property
    def remaining(self) -> int:
        return max(0, self.limit - self.count)


@dataclass
class Client:
    key: str
    timeout: int = 60
    max_retries: int = 4
    #: Characters actually sent this run (what DeepL bills).
    sent_chars: int = 0
    sent_texts: int = 0
    #: DeepL's formality for the languages that have one (de, fr, nl, es, ...).
    #: The default keeps the behaviour of every earlier run; feature 245 runs
    #: with "prefer_more" because the committed corpus is formal (Sie/vous/u/usted).
    formality: str = "prefer_less"
    _host: str = field(default="", init=False)

    def __post_init__(self) -> None:
        self._host = api_host(self.key)

    def _post(self, path: str, payload: dict) -> dict:
        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            self._host + path,
            data=data,
            headers={
                "Authorization": "DeepL-Auth-Key " + self.key,
                "Content-Type": "application/json",
                "User-Agent": "TandemCommander-translate/0.1",
            },
        )
        delay = 2.0
        last: Exception | None = None
        for attempt in range(self.max_retries):
            try:
                with urllib.request.urlopen(req, timeout=self.timeout) as r:
                    return json.load(r)
            except urllib.error.HTTPError as e:
                body = e.read().decode("utf-8", "replace")[:300]
                # 429 = too many requests, 456 = quota exhausted, 5xx = transient
                if e.code == 456:
                    raise DeepLError(
                        "DeepL quota exhausted (HTTP 456). Remaining work needs "
                        "a larger plan or a smaller scope."
                    ) from None
                if e.code in (429, 500, 502, 503, 529):
                    last = e
                    time.sleep(delay)
                    delay *= 2
                    continue
                raise DeepLError(f"DeepL HTTP {e.code}: {body}") from None
            except (urllib.error.URLError, TimeoutError) as e:
                last = e
                time.sleep(delay)
                delay *= 2
        raise DeepLError(f"DeepL unreachable after {self.max_retries} attempts: {last}")

    def usage(self) -> Usage:
        req = urllib.request.Request(
            self._host + "/v2/usage",
            headers={"Authorization": "DeepL-Auth-Key " + self.key},
        )
        with urllib.request.urlopen(req, timeout=self.timeout) as r:
            u = json.load(r)
        return Usage(count=u.get("character_count", 0), limit=u.get("character_limit", 0))

    def translate(self, texts: list[str], target: str, context: str = "") -> list[str]:
        """Translate up to :data:`BATCH_SIZE` texts into ``target``.

        Placeholders are protected via XML ignore tags, so DeepL may reposition
        them (word order differs per language) but cannot rewrite them.

        ``context`` describes where the strings are used (see
        :mod:`translate.uicontext`). DeepL uses it to disambiguate and never
        translates or returns it; without it a bare ``Host:`` came back as the
        Czech word for a talk-show host.
        """
        if not texts:
            return []

        # The shortcut label is split off and never sent. Protecting it with an
        # ignore tag is not enough: DeepL honours the tag's *content* but may
        # reposition it, so "&Close\\tEsc" comes back as "\\tEsc schliessen" --
        # the key name intact but now in front of the translated verb, which
        # makes the whole row invalid. Translating only the body and
        # reattaching the tail locally removes the failure mode entirely (and
        # costs less quota).
        split = [_split_tail(t) for t in texts]
        # Strip the accelerator too, so whole words reach the engine.
        stripped = [split_accel(b) for b, _ in split]
        bodies = [b for b, _ in stripped]

        protected = [_protect(b) for b in bodies]
        self.sent_chars += sum(len(p) for p in protected)
        self.sent_texts += len(protected)

        payload = {
            "text": protected,
            "target_lang": target,
            "source_lang": "EN",
            "tag_handling": "xml",
            "ignore_tags": ["x"],
            "preserve_formatting": True,
            # UI labels are instructions to the user, not prose; "prefer_less"
            # was the original choice, "prefer_more" matches the formal corpus
            # (merge.py --formality).
            "formality": self.formality,
        }
        if context:
            # The request is parsed with tag_handling=xml, so the context has to
            # be XML-clean too - a stray "&" or "<" rejects the whole batch.
            payload["context"] = (
                context.replace("&", "and").replace("<", "(").replace(">", ")")
            )
        out = self._post("/v2/translate", payload)
        got = [t["text"] for t in out.get("translations", [])]
        if len(got) != len(texts):
            raise DeepLError(f"DeepL returned {len(got)} results for {len(texts)} texts")
        return [
            reinsert_accel(_unprotect(g), letter) + tail
            for g, (_, letter), (_, tail) in zip(got, stripped, split)
        ]

    def translate_all(
        self,
        items: list[tuple[str, str]],
        target: str,
        progress=None,
    ) -> dict[tuple[str, str], str]:
        """Translate ``(context, english)`` pairs.

        Returns ``{(context, english): translated}``. Requests are grouped by
        context, because DeepL takes one context per request -- so a dialog
        costs one request, not one per control. The same English text can
        legitimately get different translations in different contexts, which is
        the whole point of keying on the pair.
        """
        by_context: dict[str, list[str]] = {}
        for context, text in items:
            bucket = by_context.setdefault(context, [])
            if text not in bucket:
                bucket.append(text)

        result: dict[tuple[str, str], str] = {}
        done = 0
        for context, texts in by_context.items():
            for i in range(0, len(texts), BATCH_SIZE):
                chunk = texts[i : i + BATCH_SIZE]
                for src, dst in zip(chunk, self.translate(chunk, target, context)):
                    result[(context, src)] = dst
                done += len(chunk)
                if progress:
                    progress(done, len(items))
        return result
