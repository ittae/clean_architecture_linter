# Release Please (pilot)

Automates Release PR + changelog from Conventional Commits on `main`, then publishes to pub.dev when a release is actually cut.

## Pipeline

```text
main push
  → Release Please (opens/updates Release PR, or merges release commit)
  → if release_created:
       workflow_call → Publish to pub.dev (test + OIDC)
```

### Why `workflow_call` (not only tag push)

Release Please creates tags/releases with `GITHUB_TOKEN`. GitHub does **not** re-trigger other workflows from `GITHUB_TOKEN` tag pushes, so `publish.yml`'s `on.push.tags` alone never runs after a bot-cut release.

`release-please.yml` therefore calls `publish.yml` directly when `release_created == true`.

Tag push trigger remains for:

- human-created tags
- PAT-created tags
- recovery / tooling that still pushes tags outside Release Please

`workflow_dispatch` on `publish.yml` is for backfill (e.g. tag/Release already exist but pub.dev was missed).

## Tag convention (must match existing + publish.yml)

- Existing / required: `vX.Y.Z` (e.g. `v2.1.1`)
- Config: `include-component-in-tag: false`, `include-v-in-tag: true`
- `publish.yml` also accepts `push` tags matching `v[0-9]+.[0-9]+.[0-9]+*`

Do **not** use component-prefixed tags like `clean_architecture_linter-v2.1.1` — that caused a false 3.0.0 Release PR (#90) by rescanning historical `feat!` commits already shipped in 2.0.0.

## Human gate

Merging the Release PR is the ship signal. Multica Version Goal (**ITT-1521**) is `manual` release — never treat Release PR open as approval to publish.

After merge, publish should start automatically via `workflow_call`. If it does not:

1. Actions → **Publish to pub.dev** → Run workflow (`workflow_dispatch`)
2. Confirm pub.dev version matches `pubspec.yaml` / GitHub Release tag

## Expected bumps after 2.1.1

- `fix:` → 2.1.2
- `feat:` (non-breaking) → 2.2.0
- only real new `BREAKING CHANGE` / `feat!` after 2.1.1 → 3.0.0

## Files

- `release-please-config.json`
- `.release-please-manifest.json` (last released: see manifest)
- `.github/workflows/release-please.yml` — release + conditional publish call
- `.github/workflows/publish.yml` — test + pub.dev OIDC (`push` tags / `workflow_call` / `workflow_dispatch`)
