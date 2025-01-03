#!/usr/bin/env bash

# Updates 'develop' and creates new local and remote branches from 'develop'
# with the prefix 'feature/'

###############################################################################
# Constants and Defaults
###############################################################################

# Required by boilerplate
readonly _script_version="1.0.0"

###############################################################################
# Sources
###############################################################################

# shellcheck source=_buildignore/scripts/lib/boilerplate.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/boilerplate.sh"

# shellcheck source=_gitignore/config/project
# source "${__project_config_file}"

###############################################################################
# Help
###############################################################################

function _usage() {
  cat << EOF
Usage: ${__file:?} [OPTIONS] <FEATURE_BRANCH_NAME>
  
Options:
  ${_usage_standard_options}
EOF
}

###############################################################################
# Script-Specific Cleanup
###############################################################################

function script_specific_cleanup() {
  :
}

###############################################################################
# Script-Specific Options
###############################################################################

function _parse_script_specific_options() {
  _args=()

  while ((${#@})); do
    local __argument="${1:-}"
    local __value="${2:-}"

    if [[ -z ${__argument} ]]; then
      shift
      continue
    fi

    case "${__argument}" in
    -*)
      _exit_1 echo "Invalid option: ${__argument}"
      ;;
    *)
      _args+=("${__argument}")
      ;;
    esac
    shift
  done
}

###############################################################################
# Arguments
###############################################################################

function _validate_positional_arguments() {
  # Validate number of arguments
  if [[ "${#@}" -ne 1 ]]; then
    _usage
    _exit_1 echo "Error: Needs 1 argument. ${#@} given" >&2
  fi

  readonly feature_branch_name="${1:?}"

  # Validate feature_branch_name
  if ! is_alphanumeric_underscore_dot_dash "${feature_branch_name}"; then
    _exit_1 echo "Error: FEATURE_BRANCH_NAME must be alphanumeric or _ . -" >&2
  fi
}

###############################################################################
# Functions
###############################################################################

function _simple() {
  git checkout develop
  git pull
  git checkout -b "feature/${feature_branch_name:?}"
  git push -u origin "feature/${feature_branch_name:?}"
}

###############################################################################
# Main
###############################################################################

# Usage: _main [<options>] [<arguments>]
# Entry point for the program, handling basic option parsing and dispatching
function _main() {
  _enable_strict_mode
  _validate_commands "/usr/bin/git"
  _split_options "${@}"
  _parse_common_options "${_args[@]}"
  _parse_script_specific_options "${_args[@]}"
  _validate_positional_arguments "${_args[@]}"

  _simple
}

# Only execute if not sourced in another script (e.g. unit testing)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  _main "${@}"
fi
