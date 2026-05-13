#!/usr/bin/env bash
# Compatibility wrapper. Prefer:
#   cd /home/ic/project
#   source open_rv

_rv32m_env_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/home/ic/project/open_rv
source "$_rv32m_env_root/open_rv"
unset _rv32m_env_root
