# Release Please (pilot)

Automates Release PR + changelog from Conventional Commits on `main`.

## Tag convention (must match existing + publish.yml)

- Existing / required: `vX.Y.Z` (e.g. `v2.1.1`)
- Config: `include-component-in-tag: false`, `include-v-in-tag: true`
- `publish.yml` triggers on `v[0-9]+.[0-9]+.[0-9]+*`

Do **not** use component-prefixed tags like `clean_architecture_linter-v2.1.1` — that caused a false 3.0.0 Release PR (#90) by rescanning historical `feat!` commits already shipped in 2.0.0.

## Human gate

Merging the Release PR is the ship signal. Multica Version Goal (**ITT-1521**) is `manual` release — never treat Release PR open as approval to publish.

## Expected bumps after 2.1.1

- `fix:` → 2.1.2
- `feat:` (non-breaking) → 2.2.0
- only real new `BREAKING CHANGE` / `feat!` after 2.1.1 → 3.0.0

## Files

- `release-please-config.json`
- `.release-please-manifest.json` (last released: 2.1.1)
- `.github/workflows/release-please.yml`
