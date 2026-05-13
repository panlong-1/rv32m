#!/usr/bin/env bash
# Compatibility wrapper. Prefer:
#   cd /home/ic/project
#   source rv

_rv32m_env_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/home/ic/project/rv
source "$_rv32m_env_root/rv"
unset _rv32m_env_root
