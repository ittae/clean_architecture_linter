#!/usr/bin/env python3
"""Shared AI PR review host SoT helpers (ITT-2477).

Unified file (preferred):
  ~/.config/ittae/ai-review-engines
  First non-comment line: engine[:model][,engine[:model]...]
  Examples:
    codex:gpt-5.5,claude:claude-opus-4-8
    codex,claude

Legacy (fallback):
  ~/.config/ittae/ai-review-engine-order  — CSV engines only
  ~/.config/ittae/ai-review-model         — engine=model lines

Config errors fail open (do not kill the review job).
"""
from __future__ import annotations

import os
import re
from pathlib import Path

ALLOWED = ("grok", "codex", "claude")
DEFAULT_ORDER = ("grok", "codex", "claude")
DEFAULT_MODELS = {
    "grok": "grok-4.5-build",
    "codex": "gpt-5.5",
    "claude": "claude-opus-4-8",
}
MODEL_RE = re.compile(r"^[A-Za-z0-9._:-]+$")

UNIFIED_NAME = "ai-review-engines"
ORDER_NAME = "ai-review-engine-order"
MODEL_NAME = "ai-review-model"


def ittae_config_dir() -> Path:
    home = os.environ.get("HOME") or str(Path.home())
    return Path(home).expanduser() / ".config" / "ittae"


def default_unified_path() -> Path:
    return ittae_config_dir() / UNIFIED_NAME


def default_order_path() -> Path:
    return ittae_config_dir() / ORDER_NAME


def default_model_path() -> Path:
    return ittae_config_dir() / MODEL_NAME


def first_data_line(text: str) -> str | None:
    if text is None:
        return None
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        return line
    return None


def parse_unified_line(line: str) -> tuple[list[str] | None, dict[str, str], str | None]:
    """Parse one CSV of engine[:model] tokens.

    Returns (order, models_partial, error).
    error set ⇒ caller should not use this as unified SoT.
    """
    if not line or not line.strip():
        return None, {}, "empty"
    # Split CSV first; strip only token edges. Do NOT remove spaces inside model IDs
    # (ITT-2477 M1: "codex:gpt 5.5" must fail MODEL_RE, not become "gpt5.5").
    tokens = [t.strip() for t in line.split(",") if t.strip()]
    if not tokens:
        return None, {}, "empty"
    if len(tokens) > len(ALLOWED):
        return None, {}, "too-many"

    order: list[str] = []
    models: dict[str, str] = {}
    seen: set[str] = set()
    for tok in tokens:
        if ":" in tok:
            eng, _, model = tok.partition(":")
            eng = eng.strip().lower()
            model = model.strip()
            if eng not in ALLOWED:
                return None, {}, f"unknown:{eng}"
            if eng in seen:
                return None, {}, f"duplicate:{eng}"
            if not model or not MODEL_RE.match(model):
                return None, {}, f"bad-model:{eng}"
            seen.add(eng)
            order.append(eng)
            models[eng] = model
        else:
            eng = tok.strip().lower()
            if eng not in ALLOWED:
                return None, {}, f"unknown:{eng}"
            if eng in seen:
                return None, {}, f"duplicate:{eng}"
            seen.add(eng)
            order.append(eng)

    rank = {name: i for i, name in enumerate(DEFAULT_ORDER)}
    if any(rank[order[i]] > rank[order[i + 1]] for i in range(len(order) - 1)):
        return None, {}, "non-monotonic-order"
    return order, models, None


def parse_unified_text(text: str) -> tuple[list[str] | None, dict[str, str], str | None]:
    line = first_data_line(text)
    if line is None:
        return None, {}, "empty"
    return parse_unified_line(line)


def read_text_file(path: Path) -> tuple[str | None, str | None]:
    """Return (text, error). error set if unreadable/missing."""
    try:
        if not path.is_file():
            return None, "missing"
        return path.read_text(encoding="utf-8"), None
    except (OSError, UnicodeError) as exc:
        return None, f"unreadable:{exc}"


def load_unified(
    path: Path | None = None,
) -> dict | None:
    """Load unified file. None if missing/invalid (caller falls back).

    Returns dict: order, models_partial, path, warning(optional)
    """
    cfg = path if path is not None else default_unified_path()
    text, err = read_text_file(cfg)
    if err == "missing":
        return None
    if err:
        return {
            "order": None,
            "models_partial": {},
            "path": str(cfg),
            "error": err,
        }
    order, models, perr = parse_unified_text(text or "")
    if perr or not order:
        return {
            "order": None,
            "models_partial": {},
            "path": str(cfg),
            "error": f"invalid-unified:{perr or 'empty'}",
        }
    return {
        "order": order,
        "models_partial": models,
        "path": str(cfg),
        "error": None,
    }
