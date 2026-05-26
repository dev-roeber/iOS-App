#!/usr/bin/env bash
# lint_widget_data_store_mirror.sh
#
# Guards against silent drift between the two parallel WidgetDataStore files:
#
#   Sources/LocationHistoryConsumerAppSupport/WidgetDataStore.swift   (library copy)
#   wrapper/LH2GPXWidget/WidgetDataStore.swift                        (widget-extension copy)
#
# The widget-extension target can't link AppSupport directly, so the type
# must exist in both places. Both files reference `WidgetSharedKeys.*` to
# keep the *constants* in one source-of-truth — but the **public API
# surface** (function signatures, stored properties, struct shape) must also
# stay identical, otherwise the widget reads/writes a stale schema.
#
# This script normalizes both files (drop blank lines, leading comments,
# `#if canImport(...)` / `#endif` guards, the AppSupport `import` line,
# access modifiers, and any custom-init body the library copy carries for
# external callers) and diffs the remaining "API surface" lines.
#
# Exit codes:
#   0  identical
#   1  drift detected (diff printed to stderr)
#   2  one or both files missing
#
# Optional pre-commit hint:
#   #!/usr/bin/env bash
#   exec ./scripts/lint_widget_data_store_mirror.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$REPO_ROOT/Sources/LocationHistoryConsumerAppSupport/WidgetDataStore.swift"
EXT="$REPO_ROOT/wrapper/LH2GPXWidget/WidgetDataStore.swift"

if [[ ! -f "$LIB" ]] || [[ ! -f "$EXT" ]]; then
  echo "lint_widget_data_store_mirror: one or both files missing" >&2
  echo "  $LIB" >&2
  echo "  $EXT" >&2
  exit 2
fi

# Normalize a Swift mirror file to its comparable surface:
#   - strip leading/trailing whitespace
#   - drop empty lines
#   - drop // line-comments (whole-line and trailing)
#   - drop /// doc comments
#   - drop #if canImport(...) / #endif / #else guard scaffolding
#   - drop the cross-target `import LocationHistoryConsumerAppSupport`
#   - drop access modifiers (public/internal/private/fileprivate) so the
#     library `public` vs. widget-side default access doesn't trigger drift
#   - collapse runs of whitespace inside lines
#   - drop free-standing init bodies (the library exposes `public init(...)`
#     so external SwiftPM consumers can synthesize values; the extension
#     copy uses the memberwise init and intentionally omits it)
normalize() {
  python3 - "$1" <<'PY'
import re, sys
src = open(sys.argv[1]).read()
# Strip /* ... */ block comments first.
src = re.sub(r"/\*.*?\*/", "", src, flags=re.S)
out = []
skip_init = 0
for raw in src.splitlines():
    line = raw.strip()
    if not line:
        continue
    # Drop doc + line comments.
    if line.startswith("///") or line.startswith("//"):
        continue
    # Drop trailing // ... comments.
    line = re.sub(r"\s*//.*$", "", line).strip()
    if not line:
        continue
    # Drop conditional-compilation scaffolding and the cross-target import.
    if line.startswith("#if ") or line == "#endif" or line.startswith("#else"):
        continue
    if line == "import LocationHistoryConsumerAppSupport":
        continue
    # Strip access modifiers so e.g. `public static var foo` == `static var foo`.
    line = re.sub(r"\b(public|internal|private|fileprivate|open)\s+", "", line)
    # Collapse internal whitespace.
    line = re.sub(r"\s+", " ", line)
    # Skip the library-only `init(...) { self.x = x ... }` body: a single-line
    # `init(...)` signature is fine — it's the multi-line stored assignments
    # that the extension copy intentionally omits. We detect the start of an
    # `init(` block and skip until the matching closing brace at indent 0
    # within the block.
    if line.startswith("init(") and line.endswith("{"):
        skip_init = 1
        continue
    if skip_init:
        # Naive brace counter — enough for the simple init we have.
        skip_init += line.count("{") - line.count("}")
        if skip_init <= 0:
            skip_init = 0
        continue
    out.append(line)
print("\n".join(out))
PY
}

LIB_NORM="$(normalize "$LIB")"
EXT_NORM="$(normalize "$EXT")"

if [[ "$LIB_NORM" == "$EXT_NORM" ]]; then
  echo "lint_widget_data_store_mirror: OK (API surface identical)"
  exit 0
fi

{
  echo "lint_widget_data_store_mirror: DRIFT detected between"
  echo "  $LIB"
  echo "  $EXT"
  echo
  diff <(printf "%s\n" "$LIB_NORM") <(printf "%s\n" "$EXT_NORM") || true
} >&2
exit 1
