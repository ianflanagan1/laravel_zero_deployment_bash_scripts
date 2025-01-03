#!/usr/bin/env bash

# Run standard checks before running `git commit`
# To run automatically on `git commit`, add to .git/hooks/pre-commit

# CURRENT ACTIONS
# - Pint (PHP lint)
# - PHPUnit (Unit and Feature tests)
# - Dusk (Browser tests)
# - Shellcheck (shell script lint)

# IMPROVEMENTS TO CONSIDER
# - check for large files (don't want to commit)

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
source "${__project_config_file}"

###############################################################################
# Help
###############################################################################

function _usage() {
  cat << EOF
Usage: ${__file:?} [OPTIONS]
  
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
  if [[ "${#@}" -ne 0 ]]; then
    _usage
    _exit_1 echo "Error: Needs 0 arguments. ${#@} given" >&2
  fi
}

###############################################################################
# Functions
###############################################################################

function _simple() {
  # Lint shell scripts
  find _buildignore/scripts/ -type f -print0 | xargs -0 shellcheck -x

  # Test shell scripts
  while IFS= read -r -d '' script; do
    bash "${script}"
  done < <(find ./_buildignore/scripts/tests -type f -name "*.sh" -print0)

  # Lint PHP
  ./vendor/bin/pint --dirty -v

  # Test PHP
  php artisan test --coverage --min="${__test_coverage_threshold}"
  php artisan dusk
}

###############################################################################
# Main
###############################################################################

# Usage: _main [<options>] [<arguments>]
# Entry point for the program, handling basic option parsing and dispatching
function _main() {
  _enable_strict_mode
  _validate_commands "/usr/bin/php"
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
