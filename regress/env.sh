#!/usr/bin/env bash
# Same environment as scripts/env.sh (sources that file). Use from bash.

if [[ -z "${BASH_VERSION:-}" ]]; then
  echo "regress/env.sh: source from bash." >&2
  return 2 2>/dev/null || exit 2
fi

_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$_repo_root/scripts/env.sh"
unset _repo_root
