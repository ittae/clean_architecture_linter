# Releases

Where this package stands on versions: what is shipped, what changed since, and what could come next. Read it before choosing the next version.

Checked on 2026-11-23 against `main` at `5ef0a08`.

## Current version

- Last git tag: `v2.8.4` (commit date 2026-11-14), from `git tag --sort=-creatordate`.
- Last GitHub Release: `v2.8.4` (Latest, 2026-11-14), from `gh release list -R ittae/clean_architecture_linter`.
- `pubspec.yaml` and `.release-please-manifest.json` both say `2.8.4`.

Published to [pub.dev](https://pub.dev/packages/clean_architecture_linter). Versions are cut by Release Please; see [release-please.md](release-please.md).

## Changes since the last release

`git log v2.8.4..main` has 10 commits. None is a `feat` or `fix`, so no package behavior has changed since `v2.8.4`:

| Type | Change |
| --- | --- |
| docs | README install example aligned to 2.8.x (#216) |
| docs | agent rules managed block re-synced (#215, #209) |
| docs | CLAUDE.md reduced to an `@AGENTS.md` shim (#208); enforced-pattern guide split into `doc/RIVERPOD_ARCHITECTURE_GUIDE.md` (#207) |
| ci | gitleaks secret scan for the public repo (#211); gitleaks check name comment (#214); title lint Hangul range (#213) |
| chore | public changelog kept in English (#212); PR body lint synced with the org copy (#210) |

Release history and the `feat`/`fix` entries of every shipped version live in [CHANGELOG.md](../CHANGELOG.md), which Release Please maintains. Hidden types (`docs`, `ci`, `chore`, ...) do not open a Release PR, so nothing is pending until a `feat`, `fix`, `perf`, `revert`, `deps` or breaking change lands on `main`.

## Next candidates

No version number is set here; it is decided in conversation with the owner.

- Open GitHub issues: none (`gh issue list -R ittae/clean_architecture_linter --state open`).
- Open pull requests: none.
- Bug candidates: none recorded.
- Unchecked items in the README roadmap (not scheduled): configurable naming patterns, support for more state management solutions, CI/CD integration, a custom rule creation guide, performance work.
