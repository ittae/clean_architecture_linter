# Release Please (pilot)

This package uses [release-please](https://github.com/googleapis/release-please) to open/update a **Release PR** from Conventional Commits on `main`.

## Human gate
Merging the Release PR is the explicit "ship this version" signal. Tag + changelog then flow to existing `publish.yml` on `v*` tags if configured that way — today publish is tag-push based; after first release-please tag, confirm tag format matches `publish.yml`.

## Commit convention
Use `feat:`, `fix:`, `perf:`, `chore:` etc. (not `feature:`).

## Files
- `release-please-config.json`
- `.release-please-manifest.json` (current version seed: pubspec 2.1.1)
- `.github/workflows/release-please.yml`
