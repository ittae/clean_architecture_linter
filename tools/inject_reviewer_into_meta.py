#!/usr/bin/env python3
"""Inject producer-side reviewer identity into ittae-ai-review-meta.

LLM output must not be the sole source of reviewer_engine / reviewer_model.
Workflows overwrite those fields from steps.review_engine before publish (full)
or via post-hoc comment patch (light). Invalid engines fail closed.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from typing import Any, Mapping

ALLOWED_ENGINES = frozenset({"grok", "codex", "claude"})
MODEL_RE = re.compile(r"^[A-Za-z0-9._:-]+$")

META_BLOCK_RE = re.compile(
    r"(<!--\s*ittae-ai-review-meta\s*\n)(.*?)(\n\s*-->)",
    re.DOTALL,
)


class InjectError(ValueError):
    """Raised when meta inject inputs or body shape are invalid."""


def _normalize_engine(value: Any) -> str:
    if not isinstance(value, str):
        raise InjectError("reviewer_engine must be a non-empty string")
    engine = value.strip().lower()
    if engine not in ALLOWED_ENGINES:
        raise InjectError(
            f"reviewer_engine must be one of {sorted(ALLOWED_ENGINES)}; got {value!r}"
        )
    return engine


def _normalize_model(value: Any) -> str:
    if not isinstance(value, str) or not value.strip():
        raise InjectError("reviewer_model must be a non-empty string")
    model = value.strip()
    if not MODEL_RE.fullmatch(model):
        raise InjectError(
            f"reviewer_model must match {MODEL_RE.pattern}; got {model!r}"
        )
    return model


def inject_reviewer_fields(
    meta: Mapping[str, Any],
    *,
    reviewer_engine: str,
    reviewer_model: str,
    run_id: str | None = None,
    run_attempt: int | str | None = None,
    job: str | None = None,
) -> dict[str, Any]:
    """Return a copy of meta with producer reviewer fields overwritten."""
    if not isinstance(meta, Mapping):
        raise InjectError("meta must be a mapping")
    out: dict[str, Any] = dict(meta)
    out["reviewer_engine"] = _normalize_engine(reviewer_engine)
    out["reviewer_model"] = _normalize_model(reviewer_model)
    if run_id is not None:
        if not isinstance(run_id, str) or not run_id.strip():
            raise InjectError("run_id must be a non-empty string when provided")
        out["run_id"] = run_id.strip()
    if run_attempt is not None:
        if isinstance(run_attempt, bool):
            raise InjectError("run_attempt must be an integer")
        if isinstance(run_attempt, int):
            attempt = run_attempt
        elif isinstance(run_attempt, str) and run_attempt.strip().isdigit():
            attempt = int(run_attempt.strip())
        else:
            raise InjectError("run_attempt must be an integer")
        out["run_attempt"] = attempt
    if job is not None:
        if not isinstance(job, str) or not job.strip():
            raise InjectError("job must be a non-empty string when provided")
        out["job"] = job.strip()
    return out


def require_reviewer_engine(meta: Mapping[str, Any]) -> None:
    """Fail closed when reviewer_engine/model missing or outside allowlist/charset."""
    if not isinstance(meta, Mapping):
        raise InjectError("meta must be a mapping")
    _normalize_engine(meta.get("reviewer_engine"))
    _normalize_model(meta.get("reviewer_model"))


def extract_meta_json(body: str) -> dict[str, Any]:
    """Parse the first ittae-ai-review-meta HTML comment block as JSON."""
    if not isinstance(body, str) or not body:
        raise InjectError("body must be a non-empty string")
    match = META_BLOCK_RE.search(body)
    if match is None:
        raise InjectError("ittae-ai-review-meta block not found")
    raw = match.group(2).strip()
    try:
        value = json.loads(raw)
    except json.JSONDecodeError as error:
        raise InjectError(f"meta JSON parse failed: {error}") from error
    if not isinstance(value, dict):
        raise InjectError("meta JSON must be an object")
    return value


def rewrite_meta_block_in_body(body: str, meta: Mapping[str, Any]) -> str:
    """Replace the first ittae-ai-review-meta block with compact JSON from meta."""
    if not isinstance(body, str) or not body:
        raise InjectError("body must be a non-empty string")
    if not isinstance(meta, Mapping):
        raise InjectError("meta must be a mapping")
    # Compact single-line JSON keeps sed 'tr -d \\n' consumers stable.
    payload = json.dumps(dict(meta), ensure_ascii=False, separators=(",", ":"))

    def _repl(match: re.Match[str]) -> str:
        return f"{match.group(1)}{payload}{match.group(3)}"

    new_body, count = META_BLOCK_RE.subn(_repl, body, count=1)
    if count != 1:
        raise InjectError("ittae-ai-review-meta block not found")
    return new_body


def inject_into_body(
    body: str,
    *,
    reviewer_engine: str,
    reviewer_model: str,
    run_id: str | None = None,
    run_attempt: int | str | None = None,
    job: str | None = None,
) -> str:
    """Extract meta, inject reviewer fields, rewrite the HTML comment block."""
    meta = extract_meta_json(body)
    updated = inject_reviewer_fields(
        meta,
        reviewer_engine=reviewer_engine,
        reviewer_model=reviewer_model,
        run_id=run_id,
        run_attempt=run_attempt,
        job=job,
    )
    return rewrite_meta_block_in_body(body, updated)


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Inject reviewer_engine/model into ittae-ai-review-meta body or JSON."
    )
    parser.add_argument(
        "--body-file",
        help="Path to review body markdown containing <!-- ittae-ai-review-meta -->",
    )
    parser.add_argument(
        "--meta-json",
        help="Inline meta JSON object (mutually exclusive with --body-file for write modes)",
    )
    parser.add_argument("--engine", default=None, help="reviewer_engine (grok|codex|claude)")
    parser.add_argument("--model", default=None, help="reviewer_model id")
    parser.add_argument("--run-id", default=None)
    parser.add_argument("--run-attempt", default=None)
    parser.add_argument("--job", default=None)
    parser.add_argument(
        "--in-place",
        action="store_true",
        help="Rewrite --body-file in place (default: print body to stdout)",
    )
    parser.add_argument(
        "--require-only",
        action="store_true",
        help="Only validate existing meta has allowlisted reviewer_engine (no inject)",
    )
    parser.add_argument(
        "--print-meta",
        action="store_true",
        help="Print resulting meta JSON to stdout instead of body",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _build_parser().parse_args(argv)
    try:
        if args.body_file and args.meta_json:
            raise InjectError("--body-file and --meta-json are mutually exclusive")
        if not args.require_only and (not args.engine or not args.model):
            raise InjectError("--engine and --model are required unless --require-only")
        if args.require_only:
            if args.body_file:
                with open(args.body_file, encoding="utf-8") as handle:
                    body = handle.read()
                meta = extract_meta_json(body)
            elif args.meta_json:
                meta = json.loads(args.meta_json)
                if not isinstance(meta, dict):
                    raise InjectError("meta JSON must be an object")
            else:
                raise InjectError("--require-only needs --body-file or --meta-json")
            # Validate reviewer_engine/model already present in the parsed meta.
            require_reviewer_engine(meta)
            if args.print_meta:
                sys.stdout.write(json.dumps(meta, ensure_ascii=False, separators=(",", ":")))
                sys.stdout.write("\n")
            return 0

        if not args.body_file and not args.meta_json:
            raise InjectError("provide --body-file or --meta-json")

        if args.body_file:
            with open(args.body_file, encoding="utf-8") as handle:
                body = handle.read()
            new_body = inject_into_body(
                body,
                reviewer_engine=args.engine,
                reviewer_model=args.model,
                run_id=args.run_id,
                run_attempt=args.run_attempt,
                job=args.job,
            )
            meta = extract_meta_json(new_body)
            if args.in_place:
                with open(args.body_file, "w", encoding="utf-8") as handle:
                    handle.write(new_body)
            if args.print_meta:
                sys.stdout.write(json.dumps(meta, ensure_ascii=False, separators=(",", ":")))
                sys.stdout.write("\n")
            elif not args.in_place:
                sys.stdout.write(new_body)
            return 0

        meta_in = json.loads(args.meta_json)
        if not isinstance(meta_in, dict):
            raise InjectError("meta JSON must be an object")
        meta = inject_reviewer_fields(
            meta_in,
            reviewer_engine=args.engine,
            reviewer_model=args.model,
            run_id=args.run_id,
            run_attempt=args.run_attempt,
            job=args.job,
        )
        require_reviewer_engine(meta)
        sys.stdout.write(json.dumps(meta, ensure_ascii=False, separators=(",", ":")))
        sys.stdout.write("\n")
        return 0
    except (InjectError, json.JSONDecodeError, OSError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
