#!/usr/bin/env python3
"""Resolve AI PR review engine model ids from local Mac mini config.

Preferred SoT (ITT-2477):
  ~/.config/ittae/ai-review-engines — engine[:model] CSV (order + optional pins)

Legacy fallback:
  ~/.config/ittae/ai-review-model — engine=model lines

Missing file/keys keep workflow defaults (config fail-open).

Emits either GitHub Actions outputs (default) or JSON (--json).
source: unified | file | mixed | text | default
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

try:
    from ai_review_sot import (  # type: ignore
        ALLOWED,
        DEFAULT_MODELS,
        MODEL_RE,
        default_model_path,
        default_unified_path,
        load_unified,
    )
except ImportError:  # pragma: no cover
    ALLOWED = ("grok", "codex", "claude")
    DEFAULT_MODELS = {
        "grok": "grok-4.5-build",
        "codex": "gpt-5.5",
        "claude": "claude-opus-4-8",
    }
    MODEL_RE = re.compile(r"^[A-Za-z0-9._:-]+$")

    def default_model_path() -> Path:
        home = os.environ.get("HOME") or str(Path.home())
        return Path(home).expanduser() / ".config" / "ittae" / "ai-review-model"

    def default_unified_path() -> Path:
        home = os.environ.get("HOME") or str(Path.home())
        return Path(home).expanduser() / ".config" / "ittae" / "ai-review-engines"

    def load_unified(path=None):
        return None

DEFAULT_PATH = "~/.config/ittae/ai-review-model"
UNIFIED_PATH = "~/.config/ittae/ai-review-engines"


def default_config_path() -> Path:
    return default_model_path()


def parse_model_text(text: str) -> tuple[dict[str, str], list[str]]:
    """Return (partial_models, warnings). Keys only for valid lines."""
    models: dict[str, str] = {}
    warnings: list[str] = []
    if text is None:
        return models, ["empty"]
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            warnings.append(f"bad-line:{line[:40]}")
            continue
        key, _, value = line.partition("=")
        eng = key.strip().lower()
        model = value.strip()
        if eng not in ALLOWED:
            warnings.append(f"unknown-engine:{eng}")
            continue
        if not model or not MODEL_RE.match(model):
            warnings.append(f"bad-model:{eng}")
            continue
        if eng in models:
            warnings.append(f"duplicate:{eng}")
        models[eng] = model
    return models, warnings


def load_models(
    path: Path | None = None,
    *,
    text: str | None = None,
    unified_path: Path | None = None,
    skip_unified: bool = False,
) -> dict:
    """Resolve models from text, unified SoT, or legacy model file.

    Returns dict:
      models (dict all three engines), source (unified|file|mixed|text|default),
      warning (str|None), path (str), from_file (list[str])
    """

    def _finalize(partial: dict[str, str], source_kind: str, path_s: str, warnings: list[str]) -> dict:
        models = dict(DEFAULT_MODELS)
        from_file: list[str] = []
        for eng, model in partial.items():
            models[eng] = model
            from_file.append(eng)
        if not from_file:
            source = "default" if source_kind != "unified" else "unified"
        elif source_kind == "unified":
            source = "unified"
        elif len(from_file) == 3:
            source = source_kind if source_kind in ("file", "text") else "file"
        else:
            source = "mixed"
        warning = None
        if warnings:
            warning = ";".join(warnings)[:200]
        return {
            "models": models,
            "source": source,
            "warning": warning,
            "path": path_s,
            "from_file": sorted(from_file),
        }

    if text is not None:
        partial, warnings = parse_model_text(text)
        path_s = str(path) if path is not None else DEFAULT_PATH
        return _finalize(partial, "text", path_s, warnings)

    # Explicit --path: legacy model file only
    if path is not None:
        cfg_path = path
        path_s = str(cfg_path)
        try:
            if not cfg_path.is_file():
                return {
                    "models": dict(DEFAULT_MODELS),
                    "source": "default",
                    "warning": None,
                    "path": path_s,
                    "from_file": [],
                }
            raw = cfg_path.read_text(encoding="utf-8")
        except (OSError, UnicodeError) as exc:
            return {
                "models": dict(DEFAULT_MODELS),
                "source": "default",
                "warning": f"unreadable:{exc}",
                "path": path_s,
                "from_file": [],
            }
        partial, warnings = parse_model_text(raw)
        return _finalize(partial, "file", path_s, warnings)

    # Default: unified → legacy model file → default
    if not skip_unified:
        u = load_unified(unified_path)
        if u is not None and u.get("order") is not None and not u.get("error"):
            partial = dict(u.get("models_partial") or {})
            return _finalize(partial, "unified", u["path"], [])
        if u is not None and u.get("error") and "missing" not in str(u.get("error")):
            # invalid unified: fall through
            pass

    cfg_path = default_model_path()
    path_s = str(cfg_path)
    try:
        if not cfg_path.is_file():
            return {
                "models": dict(DEFAULT_MODELS),
                "source": "default",
                "warning": None,
                "path": path_s,
                "from_file": [],
            }
        raw = cfg_path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        return {
            "models": dict(DEFAULT_MODELS),
            "source": "default",
            "warning": f"unreadable:{exc}",
            "path": path_s,
            "from_file": [],
        }
    partial, warnings = parse_model_text(raw)
    return _finalize(partial, "file", path_s, warnings)


def emit_gha(result: dict) -> None:
    models = result["models"]
    lines = [
        f"grok_model={models['grok']}",
        f"codex_model={models['codex']}",
        f"claude_model={models['claude']}",
        f"source={result['source']}",
        f"path={result['path']}",
        f"from_file={','.join(result.get('from_file') or [])}",
    ]
    if result.get("warning"):
        w = str(result["warning"]).replace("\n", " ").replace("\r", " ")
        lines.append(f"warning={w}")
    else:
        lines.append("warning=")
    text = "\n".join(lines) + "\n"
    out_path = os.environ.get("GITHUB_OUTPUT")
    if out_path:
        with open(out_path, "a", encoding="utf-8") as fh:
            fh.write(text)
    sys.stdout.write(text)


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--path", default=None, help=f"config path (default: {DEFAULT_PATH})")
    p.add_argument("--text", default=None, help="parse this text instead of reading the file")
    p.add_argument("--stdin", action="store_true", help="read model text from stdin")
    p.add_argument("--json", action="store_true", help="print JSON instead of GHA outputs")
    args = p.parse_args(argv)

    text = args.text
    if args.stdin:
        text = sys.stdin.read()

    path = Path(args.path).expanduser() if args.path else None
    result = load_models(path, text=text)

    if result.get("warning"):
        print(
            f"::warning::ai-review model: {result['warning']} — partial/default models applied",
            file=sys.stderr,
        )
    if result["source"] in ("file", "mixed", "unified"):
        print(
            f"::notice::ai-review models source={result['source']} path={result['path']} "
            f"from_file={','.join(result['from_file'])}",
            file=sys.stderr,
        )
    elif result["source"] == "text":
        print(
            f"::notice::ai-review models source=text from_file={','.join(result['from_file'])}",
            file=sys.stderr,
        )
    else:
        print(
            f"::notice::ai-review models source={result['source']} (defaults)",
            file=sys.stderr,
        )

    if args.json:
        json.dump(result, sys.stdout, ensure_ascii=False, indent=2)
        sys.stdout.write("\n")
        return 0

    emit_gha(result)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
