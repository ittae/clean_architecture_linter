#!/usr/bin/env python3
"""Resolve AI PR review engine try-order from local Mac mini config.

Preferred SoT (ITT-2477):
  ~/.config/ittae/ai-review-engines
  First data line: engine[:model] CSV (models ignored here; see resolve_ai_review_model).

Legacy fallback:
  ~/.config/ittae/ai-review-engine-order — CSV of {grok,codex,claude}

Default when missing/unreadable/invalid: grok,codex,claude

Config errors fail open to default (do not kill the review job).
Engine execution failures remain fail-closed in the workflow Require step.

Emits either GitHub Actions outputs (default) or JSON (--json).
source: unified | file | text | default
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

try:
    from ai_review_sot import (  # type: ignore
        ALLOWED,
        DEFAULT_ORDER,
        default_order_path,
        default_unified_path,
        load_unified,
        parse_unified_text,
    )
except ImportError:  # pragma: no cover - flat embed without sibling module
    from pathlib import Path as _P
    import os as _os
    import re as _re

    ALLOWED = ("grok", "codex", "claude")
    DEFAULT_ORDER = ("grok", "codex", "claude")
    _MODEL_RE = _re.compile(r"^[A-Za-z0-9._:-]+$")

    def default_order_path() -> _P:
        home = _os.environ.get("HOME") or str(_P.home())
        return _P(home).expanduser() / ".config" / "ittae" / "ai-review-engine-order"

    def default_unified_path() -> _P:
        home = _os.environ.get("HOME") or str(_P.home())
        return _P(home).expanduser() / ".config" / "ittae" / "ai-review-engines"

    def parse_unified_text(text: str):
        # minimal fallback: order-only tokens (strip :model)
        if text is None:
            return None, {}, "empty"
        line = None
        for raw in text.splitlines():
            s = raw.strip()
            if s and not s.startswith("#"):
                line = s
                break
        if not line:
            return None, {}, "empty"
        order, models = [], {}
        seen = set()
        for tok in [t.strip() for t in line.split(",") if t.strip()]:
            eng, _, model = tok.partition(":")
            eng = eng.strip().lower()
            model = model.strip()
            if eng not in ALLOWED or eng in seen:
                return None, {}, "bad"
            if ":" in tok and (not model or not _MODEL_RE.match(model)):
                return None, {}, f"bad-model:{eng}"
            seen.add(eng)
            order.append(eng)
            if model:
                models[eng] = model
        rank = {n: i for i, n in enumerate(DEFAULT_ORDER)}
        if any(rank[order[i]] > rank[order[i + 1]] for i in range(len(order) - 1)):
            return None, {}, "non-monotonic-order"
        return order, models, None

    def load_unified(path=None):
        cfg = path if path is not None else default_unified_path()
        try:
            if not cfg.is_file():
                return None
            raw = cfg.read_text(encoding="utf-8")
        except (OSError, UnicodeError) as exc:
            return {"order": None, "models_partial": {}, "path": str(cfg), "error": f"unreadable:{exc}"}
        order, models, err = parse_unified_text(raw)
        if err or not order:
            return {"order": None, "models_partial": {}, "path": str(cfg), "error": f"invalid-unified:{err or 'empty'}"}
        return {"order": order, "models_partial": models, "path": str(cfg), "error": None}

DEFAULT_PATH = "~/.config/ittae/ai-review-engine-order"
UNIFIED_PATH = "~/.config/ittae/ai-review-engines"


def default_config_path() -> Path:
    """Legacy order file path (tests / --path default target for legacy)."""
    return default_order_path()


def parse_order_text(text: str) -> tuple[list[str] | None, str | None]:
    """Return (order, error). error set ⇒ caller should use default."""
    if text is None:
        return None, "empty"
    lines: list[str] = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        lines.append(line)
    if not lines:
        return None, "empty"
    # First non-comment line is the order; additional non-comment lines are ignored.
    tokens = [t.strip().lower() for t in lines[0].replace(" ", "").split(",") if t.strip()]
    if not tokens:
        return None, "empty"
    if len(tokens) > len(ALLOWED):
        return None, "too-many"
    seen: set[str] = set()
    order: list[str] = []
    for t in tokens:
        if t not in ALLOWED:
            return None, f"unknown:{t}"
        if t in seen:
            return None, f"duplicate:{t}"
        seen.add(t)
        order.append(t)
    # GHA engine steps are fixed grok→codex→claude; only DEFAULT_ORDER
    # subsequences support true fallthrough without dual-run / stage wipe.
    rank = {name: i for i, name in enumerate(DEFAULT_ORDER)}
    if any(rank[order[i]] > rank[order[i + 1]] for i in range(len(order) - 1)):
        return None, "non-monotonic-order"
    return order, None


def load_order(
    path: Path | None = None,
    *,
    text: str | None = None,
    unified_path: Path | None = None,
    skip_unified: bool = False,
) -> dict:
    """Resolve order from explicit text, unified SoT, or legacy order file.

    Returns dict with keys:
      order (list[str]), order_csv (str), source (unified|file|text|default),
      warning (str|None), path (str)
    """
    # Explicit --text / stdin: accept order-only CSV or unified engine[:model] CSV.
    if text is not None:
        order, err = parse_order_text(text)
        path_s = str(path) if path is not None else DEFAULT_PATH
        if err or not order:
            u_order, _models, u_err = parse_unified_text(text)
            if u_err or not u_order:
                return {
                    "order": list(DEFAULT_ORDER),
                    "order_csv": ",".join(DEFAULT_ORDER),
                    "source": "default",
                    "warning": f"invalid-text:{err or u_err or 'empty'}",
                    "path": path_s,
                }
            order = u_order
        return {
            "order": order,
            "order_csv": ",".join(order),
            "source": "text",
            "warning": None,
            "path": path_s,
        }

    # Explicit --path: treat as legacy order file only (unit tests / ops).
    if path is not None:
        cfg_path = path
        path_s = str(cfg_path)
        try:
            if not cfg_path.is_file():
                return {
                    "order": list(DEFAULT_ORDER),
                    "order_csv": ",".join(DEFAULT_ORDER),
                    "source": "default",
                    "warning": None,
                    "path": path_s,
                }
            raw = cfg_path.read_text(encoding="utf-8")
        except (OSError, UnicodeError) as exc:
            return {
                "order": list(DEFAULT_ORDER),
                "order_csv": ",".join(DEFAULT_ORDER),
                "source": "default",
                "warning": f"unreadable:{exc}",
                "path": path_s,
            }
        order, err = parse_order_text(raw)
        if err or not order:
            return {
                "order": list(DEFAULT_ORDER),
                "order_csv": ",".join(DEFAULT_ORDER),
                "source": "default",
                "warning": f"invalid-file:{err or 'empty'}",
                "path": path_s,
            }
        return {
            "order": order,
            "order_csv": ",".join(order),
            "source": "file",
            "warning": None,
            "path": path_s,
        }

    # Default host resolution: unified → legacy order → default
    if not skip_unified:
        u = load_unified(unified_path)
        if u is not None and u.get("order"):
            return {
                "order": u["order"],
                "order_csv": ",".join(u["order"]),
                "source": "unified",
                "warning": None,
                "path": u["path"],
            }
        if u is not None and u.get("error") and u.get("error") != "missing":
            # invalid unified present: fall through to legacy, keep warning
            unified_warn = u["error"]
        else:
            unified_warn = None
    else:
        unified_warn = None

    cfg_path = default_order_path()
    path_s = str(cfg_path)
    try:
        if not cfg_path.is_file():
            return {
                "order": list(DEFAULT_ORDER),
                "order_csv": ",".join(DEFAULT_ORDER),
                "source": "default",
                "warning": unified_warn,
                "path": path_s if not unified_warn else (
                    str(unified_path or default_unified_path())
                ),
            }
        raw = cfg_path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        return {
            "order": list(DEFAULT_ORDER),
            "order_csv": ",".join(DEFAULT_ORDER),
            "source": "default",
            "warning": f"unreadable:{exc}",
            "path": path_s,
        }

    order, err = parse_order_text(raw)
    if err or not order:
        return {
            "order": list(DEFAULT_ORDER),
            "order_csv": ",".join(DEFAULT_ORDER),
            "source": "default",
            "warning": f"invalid-file:{err or 'empty'}",
            "path": path_s,
        }
    return {
        "order": order,
        "order_csv": ",".join(order),
        "source": "file",  # legacy-split order half
        "warning": unified_warn,
        "path": path_s,
    }


def precedence_flags(order: list[str]) -> dict[str, str]:
    """Boolean matrix for GHA step if: need_X_before_Y."""
    out: dict[str, str] = {}
    for eng in ALLOWED:
        out[f"want_{eng}"] = "1" if eng in order else "0"
    for later in ALLOWED:
        for earlier in ALLOWED:
            if earlier == later:
                continue
            key = f"need_{earlier}_before_{later}"
            if later not in order or earlier not in order:
                out[key] = "0"
            else:
                out[key] = "1" if order.index(earlier) < order.index(later) else "0"
    return out


def pick_primary(order: list[str], live: dict[str, bool]) -> str:
    """First engine in order that is live; else none."""
    for eng in order:
        if live.get(eng):
            return eng
    return "none"


def emit_gha(result: dict, live: dict[str, bool] | None = None) -> None:
    order: list[str] = result["order"]
    primary = pick_primary(order, live or {})
    lines = [
        f"order_csv={result['order_csv']}",
        f"source={result['source']}",
        f"path={result['path']}",
        f"primary={primary}",
        f"engine={primary}",
    ]
    if result.get("warning"):
        # single-line for GITHUB_OUTPUT
        w = str(result["warning"]).replace("\n", " ").replace("\r", " ")
        lines.append(f"warning={w}")
    else:
        lines.append("warning=")
    flags = precedence_flags(order)
    for k in sorted(flags):
        lines.append(f"{k}={flags[k]}")
    text = "\n".join(lines) + "\n"
    out_path = os.environ.get("GITHUB_OUTPUT")
    if out_path:
        with open(out_path, "a", encoding="utf-8") as fh:
            fh.write(text)
    sys.stdout.write(text)


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument(
        "--path",
        default=None,
        help=f"legacy order file only; omit to resolve unified SoT then {DEFAULT_PATH}",
    )
    p.add_argument(
        "--text",
        default=None,
        help="parse this text instead of reading the file",
    )
    p.add_argument(
        "--stdin",
        action="store_true",
        help="read order text from stdin",
    )
    p.add_argument(
        "--json",
        action="store_true",
        help="print JSON instead of GHA outputs",
    )
    p.add_argument(
        "--live-grok",
        default=None,
        help="1/0 for primary selection",
    )
    p.add_argument("--live-codex", default=None)
    p.add_argument("--live-claude", default=None)
    args = p.parse_args(argv)

    text = args.text
    if args.stdin:
        text = sys.stdin.read()

    path = Path(args.path).expanduser() if args.path else None
    result = load_order(path, text=text)

    live = {
        "grok": str(args.live_grok or "0") in ("1", "true", "yes"),
        "codex": str(args.live_codex or "0") in ("1", "true", "yes"),
        "claude": str(args.live_claude or "0") in ("1", "true", "yes"),
    }

    if args.json:
        payload = {
            **result,
            "primary": pick_primary(result["order"], live),
            "flags": precedence_flags(result["order"]),
        }
        json.dump(payload, sys.stdout, ensure_ascii=False, indent=2)
        sys.stdout.write("\n")
        return 0

    warn = str(result.get("warning") or "").replace("\n", " ").replace("\r", " ")
    if warn and result["source"] == "default":
        print(f"::warning::ai-review engine order: {warn} — using default {result['order_csv']}", file=sys.stderr)
    elif warn:
        print(f"::warning::ai-review engine order: {warn}", file=sys.stderr)
        print(f"::notice::ai-review engine order={result['order_csv']} source={result['source']} path={result['path']}", file=sys.stderr)
    elif result["source"] in ("file", "unified"):
        print(f"::notice::ai-review engine order={result['order_csv']} source={result['source']} path={result['path']}", file=sys.stderr)
    else:
        print(f"::notice::ai-review engine order={result['order_csv']} source={result['source']}", file=sys.stderr)

    emit_gha(result, live=live)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
