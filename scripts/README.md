# scripts/

Repo-local helper scripts. Make new entries executable (`chmod +x`) after
checkout — the executable bit travels through git, but a fresh worktree on a
locked-down system may strip it.

## Index

### `run_app_shell_macos.sh`
Drives a macOS-side `swift run` of the app shell — see comments at the top
of the script for the supported flags.

### `update_contract_fixtures.sh`
Regenerates the JSON contract fixtures used by the SwiftPM test suite. Run
after touching anything in `Sources/.../Contracts/`.

### `lint_widget_data_store_mirror.sh`
Guards against silent drift between the two parallel `WidgetDataStore.swift`
files:

* `Sources/LocationHistoryConsumerAppSupport/WidgetDataStore.swift` — library copy
* `wrapper/LH2GPXWidget/WidgetDataStore.swift` — widget-extension copy

The widget-extension target can't link `LocationHistoryConsumerAppSupport`
directly, so the type must exist in both places. Both files reference
`WidgetSharedKeys.*` to keep the *constants* in one source-of-truth — but the
**public API surface** (function signatures, stored properties, struct
shape) must also stay identical, otherwise the widget reads/writes a stale
schema.

The script normalizes both files (drops comments, `#if canImport(...)`
guards, access modifiers, the cross-target `import`, and the library-only
custom `init` body) and diffs the remaining lines.

Usage:

```sh
./scripts/lint_widget_data_store_mirror.sh
```

Exit codes:

* `0` — API surface identical
* `1` — drift detected (diff printed to stderr)
* `2` — one or both files missing

**Pre-commit hook hint** (optional, not auto-installed):

```sh
# .git/hooks/pre-commit
#!/usr/bin/env bash
exec ./scripts/lint_widget_data_store_mirror.sh
```

If a CI workflow is added later, wire this script into the lint stage so a
PR that diverges the two mirrors fails fast instead of blowing up at
widget-runtime.
