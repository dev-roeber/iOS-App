#!/bin/sh
# ci_post_xcodebuild.sh — Xcode Cloud post-xcodebuild hook
#
# Runs after every xcodebuild invocation (build AND test).
# CI_XCODEBUILD_EXIT_CODE is set by Xcode Cloud:
#   0 = success, non-zero = failure
#
# Use this hook for:
# - Collecting test results / coverage
# - Sending build status notifications
# - Archiving additional artifacts

set -e

echo "ci_post_xcodebuild: exit_code=${CI_XCODEBUILD_EXIT_CODE:-unknown}, action=${CI_XCODEBUILD_ACTION:-unknown}"

if [ "${CI_XCODEBUILD_EXIT_CODE}" != "0" ]; then
    echo "ci_post_xcodebuild: build/test FAILED"
    # Do not exit non-zero here; Xcode Cloud already handles the failure.
fi

echo "ci_post_xcodebuild: done"
