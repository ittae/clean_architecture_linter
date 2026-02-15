# Recommended Setup

## Team default
- Local development: `lint_profile_balanced.yaml`
- CI pipeline: `lint_profile_strict.yaml`

## Why
- Balanced keeps signal high and noise low while coding.
- Strict blocks policy regressions in PR/merge.

## analysis_options.yaml (local)
```yaml
include: docs/config/lint_profile_balanced.yaml
```

## CI analysis_options override
Use strict profile in CI jobs:
```yaml
include: docs/config/lint_profile_strict.yaml
```

## Repository catch whitelist
Allowed in Repository catch blocks:
- logging only (`logger`, `log`, `debugPrint`, `print`)
- Sentry capture (`Sentry.captureException`, `Sentry.captureMessage`)
- followed by `rethrow`

Disallowed:
- wrapping/replacing exceptions
- returning fallback values from catch
