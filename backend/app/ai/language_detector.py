"""Detect primary language of user queries."""

import re

_CEBUANO_MARKERS = [
  "unsa", "asa", "pila", "sakyan", "padulong", "jeep", "plete", "moagi",
  "naa", "duol", "gikan", "adto", "tricycle", "kaayo", "unsay",
]
_TAGALOG_MARKERS = [
  "paano", "magkano", "saan", "papunta", "sakay", "jeepney", "magkano",
  "malapit", "pumunta", "ba", "opo", "po", "saan", "gaano",
]


def detect_language(text: str) -> str:
  """Return language code: en, ceb, tl, or mixed."""
  lowered = text.lower()
  ceb = sum(1 for marker in _CEBUANO_MARKERS if marker in lowered)
  tl = sum(1 for marker in _TAGALOG_MARKERS if marker in lowered)

  has_ceb = bool(re.search(r"\b(unsa|asa|pila|padulong|sakyan|plete)\b", lowered))
  has_tl = bool(re.search(r"\b(paano|magkano|saan|papunta)\b", lowered))
  has_en = bool(re.search(r"\b(how|where|what|which|fare|route|nearest)\b", lowered))

  lang_count = sum([has_ceb, has_tl, has_en])
  if lang_count >= 2:
    return "mixed"
  if ceb > tl and ceb > 0:
    return "ceb"
  if tl > ceb and tl > 0:
    return "tl"
  if has_ceb:
    return "ceb"
  if has_tl:
    return "tl"
  return "en"
