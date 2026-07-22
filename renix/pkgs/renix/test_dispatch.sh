#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/functions.sh"

[ "$(custom_build_update_handler pypi)" = "pypi" ]
[ "$(custom_build_update_handler manual)" = "manual" ]
if custom_build_update_handler unsupported >/dev/null 2>&1; then
  echo "unsupported update handler was accepted" >&2
  exit 1
fi

CUSTOM_BUILD_SKIP_INDEXES=" 2 4 "
should_skip_custom_build_update 2
should_skip_custom_build_update 4
if should_skip_custom_build_update 1; then
  echo "unselected update was skipped" >&2
  exit 1
fi
