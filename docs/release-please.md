# Release Please (pilot)

Automates Release PR + changelog from Conventional Commits on `main`, then publishes to pub.dev when a release is actually cut.

## Pipeline

```text
main push
  → Release Please (opens/updates Release PR, or cuts tag + GitHub Release)
  → if release_created:
       gh workflow run "Publish to pub.dev" --ref <tag>   # workflow_dispatch on tag ref
         → test + pub.dev OIDC (ref_type=tag)
```

### Why not `workflow_call` / plain tag push

1. **Tag push from `GITHUB_TOKEN`**  
   Release Please creates tags with `GITHUB_TOKEN`. GitHub does **not** re-trigger other workflows from those tag pushes, so `publish.yml`'s `on.push.tags` alone never runs after a bot-cut release.

2. **`workflow_call` from Release Please (branch push)**  
   Nested reusable workflows keep the **caller** OIDC context (`event_name=push`, `ref_type=branch`).  
   [pub.dev automated publishing](https://dart.dev/tools/pub/automated-publishing) only accepts OIDC from **git tag push** or **`workflow_dispatch` with `ref_type=tag`** — not branch push.  
   So `uses: ./publish.yml` under Release Please would run tests but fail (or be rejected) at OIDC publish.

3. **Chosen fix: `gh workflow run --ref <tag>`**  
   After `release_created`, Release Please dispatches Publish as a **new**
   `workflow_dispatch` run **on the release tag ref** (`--ref vX.Y.Z`).  
   pub.dev accepts `workflow_dispatch` **only when OIDC `ref_type=tag`**
   (branch dispatch is rejected the same way as branch `push`).  
   Also enable **workflow_dispatch** under the package Admin → Automated publishing
   (tag-push-only config still rejects dispatch events).

   The dispatch job watches the publish run (`gh run watch --exit-status`) so a
   failed publish fails the Release Please workflow, not only the separate run.

Tag push trigger remains for human/PAT-created tags.  
`workflow_dispatch` with `--ref vX.Y.Z` is also the backfill path when tag/Release already exist but pub.dev was missed.

### OIDC contract (pub.dev)

All of the following must hold (see pub.dev `PackageBackend._checkGitHubActionAllowed`):

| Requirement | Detail |
|-------------|--------|
| `event_name` | `push` or `workflow_dispatch` **and** that event enabled in package Admin → Automated publishing |
| `ref_type` | **Always `tag`** (dispatch on a branch ref is rejected) |
| `ref` | Matches the configured tag pattern (e.g. `v{{version}}` → `refs/tags/vX.Y.Z`) |

`event_name=workflow_dispatch` alone is **not** enough.

## Tag convention (must match existing + publish.yml)

- Existing / required: `vX.Y.Z` (e.g. `v2.1.1`)
- Config: `include-component-in-tag: false`, `include-v-in-tag: true`
- `publish.yml` accepts `push` tags matching `v[0-9]+.[0-9]+.[0-9]+*` and `workflow_dispatch`

Do **not** use component-prefixed tags like `clean_architecture_linter-v2.1.1` — that caused a false 3.0.0 Release PR (#90) by rescanning historical `feat!` commits already shipped in 2.0.0.

## Human gate

Merging the Release PR is the ship signal. Multica Version Goal (**ITT-1521**) is `manual` release — never treat Release PR open as approval to publish.

After merge, publish should start automatically via `workflow_dispatch` on the release tag. If it does not:

```bash
gh workflow run "Publish to pub.dev" -R ittae/clean_architecture_linter --ref vX.Y.Z
```

Confirm pub.dev version matches `pubspec.yaml` / GitHub Release tag.

## Expected bumps after 2.1.1

- `fix:` → 2.1.2
- `feat:` (non-breaking) → 2.2.0
- only real new `BREAKING CHANGE` / `feat!` after 2.1.1 → 3.0.0

## Files

- `release-please-config.json`
- `.release-please-manifest.json` (last released: see manifest)
- `.github/workflows/release-please.yml` — release + conditional publish dispatch (tag ref + watch)
- `.github/workflows/publish.yml` — test + pub.dev OIDC (`push` tags / `workflow_dispatch` on tag)
