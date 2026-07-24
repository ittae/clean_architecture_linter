# Release Please (pilot)

Automates Release PR + changelog from Conventional Commits on `main`, then publishes to pub.dev when a release tag is pushed in a way GitHub Actions can see.

## Pipeline (correct)

```text
main push
  → Release Please (with RELEASE_PLEASE_TOKEN PAT/App)
  → creates tag vX.Y.Z (user/app push event)
  → Publish to pub.dev (on.push.tags) → test + OIDC → pub.dev
```

## Why automation broke for 2.2.0

1. Release Please defaulted to `GITHUB_TOKEN`.
2. GitHub does **not** re-trigger other workflows from `GITHUB_TOKEN` tag pushes.
3. This package's pub.dev publishing config allows **tag push only** — `workflow_dispatch` is rejected (`not allowed from workflow_dispatch` events).
4. Nested `workflow_call` from a branch-push Release Please run also fails OIDC (inherits `push` + branch).

So the only reliable auto path is: **Release Please creates the tag with a non-GITHUB_TOKEN credential** so `publish.yml`'s `on.push.tags` runs.

## Required secret

| Secret | Purpose |
|--------|---------|
| `RELEASE_PLEASE_TOKEN` | PAT or GitHub App installation token with `contents: write` (+ `pull-requests: write`). Used by release-please-action instead of `github.token`. |

Without it, Release PR / tag / GitHub Release may still be created, but **pub.dev will not publish** until someone re-pushes the tag with human/PAT credentials.

### Backfill if publish was missed

```bash
# tag already points at the release commit
git push origin :refs/tags/vX.Y.Z   # delete remote tag
git push origin vX.Y.Z              # re-create with user credentials → triggers publish
```

## Tag convention

- Required: `vX.Y.Z` (e.g. `v2.1.1`)
- Config: `include-component-in-tag: false`, `include-v-in-tag: true`
- `publish.yml` triggers on `v[0-9]+.[0-9]+.[0-9]+*`

Do **not** use component-prefixed tags like `clean_architecture_linter-v2.1.1`.

## Human gate

Merging the Release PR is the ship signal. Multica Version Goal (**ITT-1521**) is `manual` release.

## Files

- `release-please-config.json`
- `.release-please-manifest.json`
- `.github/workflows/release-please.yml`
- `.github/workflows/publish.yml`
