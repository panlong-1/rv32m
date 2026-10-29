#!/usr/bin/env bash
# Deprecated: renamed to scripts/env.sh in v0.8.0 (rv32m -> TORV). Remove in v0.9.0.
echo "torv: scripts/open_rv.sh is deprecated, use: source scripts/env.sh" >&2
# shellcheck source=/dev/null
source "$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"
