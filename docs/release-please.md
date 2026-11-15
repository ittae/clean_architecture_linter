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

## Changelog language

`CHANGELOG.md` is public: pub.dev renders it on the package page. Release Please copies the subject of each changelog-visible commit into it verbatim, and PRs are squash-merged, so the PR title is the changelog line.

- `changelog-sections` in `release-please-config.json` renders `feat`, `fix`, `perf`, `revert`, and `deps`. `docs`, `chore`, `ci`, `refactor`, `test`, `build`, and `style` are hidden. A breaking change (`!`) is rendered whatever its type. Commits of hidden types alone do not open a Release PR.
- Titles of the rendered types are written in English and carry no private issue key. `.github/workflows/pr-title-lint.yml` runs `.github/scripts/pr_title_lint.sh` on every PR title to enforce this.
- CI, tooling, and agent-document changes do not change package behavior. Use `ci`, `chore`, or `docs` for them so they stay out of the changelog.
- To reword a line after merge, add a `BEGIN_COMMIT_OVERRIDE` … `END_COMMIT_OVERRIDE` block to the merged PR's body; Release Please uses it in place of the commit message on its next run. A released entry can be edited on `main`, but pub.dev shows the change only after the next version is published.

## Human gate

Merging the Release PR is the ship signal. Releases are `manual`.

## Files

- `release-please-config.json`
- `.release-please-manifest.json`
- `.github/workflows/release-please.yml`
- `.github/workflows/publish.yml`
