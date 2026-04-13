#!/bin/sh
# ci_post_clone.sh — Xcode Cloud post-clone hook
#
# The LH2GPXWrapper.xcodeproj references the Core Swift Package (Package.swift)
# via XCLocalSwiftPackageReference at relativePath = ".." (repo root).
# Both the xcodeproj and the Package.swift are in the same git repository,
# so Xcode Cloud resolves the local reference automatically after clone.
# No additional dependency resolution steps are needed here.
#
# This script intentionally does nothing but can be extended for:
# - Installing additional tools (e.g. swiftlint via brew)
# - Decrypting secrets
# - Setting up additional environment

set -e

echo "ci_post_clone: repo cloned, local SPM package available at \$(dirname \$0)/../.."
