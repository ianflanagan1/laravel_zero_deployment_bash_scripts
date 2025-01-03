#!/usr/bin/env bash

###############################################################################
# Features
###############################################################################

# Enable/disable strict mode
# Check required commands are available and abort if missing
# Parses any combination of 
#   - short options: -a
#   - grouped short options: -abc
#   - long options: --help
#   - options with values joined by space or =:
#         --option value --option=value -abc=zone=14,region=4
#   - positional arguments
# Separate parsing of boilerplate options and script-specific options
# Boilerplate options:
#   - timeout
#   - help (print usage)
#   - version (print version)
#   - debug
#   - verbose
# Cleanup after execution regardless of error/success

###############################################################################``
# Improvements to consider
###############################################################################

# - Common options:
#     quiet option    -q|--quiet
#     log option      --log <file>
#     dry run option  --dry-run
# - Allow empty string for arguments?
#     see '_split_options' and '_parse_common_options'

###############################################################################
# Local References
###############################################################################

__project_config_file="$(dirname "${BASH_SOURCE[0]}")/../../../_gitignore/config/project"
__jenkins_config_file="$(dirname "${BASH_SOURCE[0]}")/../../../_gitignore/config/jenkins"
__environments_config_file="$(dirname "${BASH_SOURCE[0]}")/../../../_gitignore/config/environments"
readonly __config_project_file __config_jenkins_file __config_environments_file

###############################################################################
# Boilerplate Constants and Defaults
###############################################################################

__boilerplate_version="1.0.0"
__file="$(basename "${0}")"
readonly __boilerplate_version __file

###############################################################################
# Cleanup
###############################################################################

# Usage: _general_cleanup
# Triggered after execution when success or error. Call the script-specific
# cleanup then stop the timeout process if enabled
function _general_cleanup() {
  script_specific_cleanup
  _stop_timeout_process
}

###############################################################################
# Strict Mode
###############################################################################

# Usage: _enable_strict_mode
function _enable_strict_mode() {
  set -o errexit  # set -e
  set -o nounset  # set -u
  set -o pipefail
  set -o errtrace # set -E
  IFS=$'\n\t'
  trap 'echo "Error occurred on line $LINENO. Exit code: $?" >&2' ERR
  trap _general_cleanup EXIT
}

# Usage: _disable_strict_mode
function _disable_strict_mode() {
  set +o errexit
  set +o nounset
  set +o pipefail
  set +o errtrace
  IFS=$' \t\n'
  trap - ERR EXIT
}

###############################################################################
# Validate Environment
###############################################################################

# Usage: _validate_commands <commands>
# Example: _validate_commands php git
# Check important commands are available
function _validate_commands() {
  local __cmd
  for __cmd in "${@}"; do
    if ! command -v "${__cmd:?}" &>/dev/null; then
      _exit_1 echo "'${__cmd}' command not found."
    fi
  done
}

###############################################################################
# Messages
###############################################################################

# Usage: _exit_1 <command>
# Exit with status 1 after executing the specified command with output
# redirected to standard error. The command is expected to print a message
# and should typically be either `echo`, `printf`, or `cat`.
function _exit_1() {
  {
    printf "%s " "$(tput setaf 1)!$(tput sgr0)"
    "${@}"
  } 1>&2
  exit 1
}

# Usage: _warn <command>
# Print the specified command with output redirected to standard error.
# The command is expected to print a message and should typically be either
# `echo`, `printf`, or `cat`.
function _warn() {
  {
    printf "%s " "$(tput setaf 1)!$(tput sgr0)"
    "${@}"
  } 1>&2
}

# Usage: _verbose <command>
# Print the specified command with output redirected to standard error.
# The command is expected to print a message and should typically be either
# `echo`, `printf`, or `cat`.
function _verbose() {
  if ((${__verbose_option:-0})); then
    {
      "${@}"
    } 1>&2
  fi
}

# Usage: _debug <command> <options>...
# Execute a command and print to standard error. The command is expected to
# print a message and should typically be either `echo`, `printf`, or `cat`
__debug_counter=0
function _debug() {
  if ((${__debug_option:-0})); then
    __debug_counter=$((__debug_counter+1))
    {
      # Prefix debug message with "bug (U+1F41B)"
      printf "🐛  %s " "${__debug_counter}"
      "${@}"
      printf "―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――\\n"
    } 1>&2
  fi
}

###############################################################################
# Timeout
###############################################################################

# Usage: _start_timeout_process <timeout_duration>
# Kill the script process after a given number of seconds
function _start_timeout_process() {
  local timeout_duration="${1:?}"

  if ((timeout_duration)); then
    {
      sleep "${timeout_duration}"
      echo "Script timed out after ${timeout_duration} seconds." >&2
      kill -SIGTERM "$$"
    } &
    __timeout_pid=$!
  fi
}

# Usage: _stop_timeout_process
function _stop_timeout_process() {
  if ((${__timeout_pid:--1} > 0)); then
    kill "${__timeout_pid}" 2>/dev/null || true
    wait "${__timeout_pid}" 2>/dev/null || true
    __timeout_pid=-1
  fi
}

###############################################################################
# Input Validation Functions
###############################################################################

# Usage: is_unsigned_integer <argument-to-check>
function is_unsigned_integer() {
  if [[ "${1}" =~ ^[0-9]+$ ]]; then
    return 0
  fi
  return 1
}

# Usage: is_unsigned_decimal <argument-to-check>
function is_unsigned_decimal() {
  if [[ "${1}" =~ ^[0-9]+\.[0-9]+$ ]]; then
    return 0
  fi
  return 1
}

# Usage: is_semantic_version <argument-to-check>
function is_semantic_version() {
  if [[ "${1}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    return 0
  fi
  return 1
}

# Usage: is_alphanumeric_underscore_dot_dash <argument-to-check>
function is_alphanumeric_underscore_dot_dash() {
  if [[ "${1}" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
    return 0
  fi
  return 1
}

###############################################################################
# Process Options
###############################################################################

# Usage: _split_short_options <short_option>
# Split grouped short options and split off any trailing value
# -abc=123  =>  -a -b -c 123
function _split_short_options() {
  local __short_option="${1:?}"
  local __index __character

  # Split off each letter into a separate short option
  # Skip the first character (-)
  for ((__index=1; __index < ${#__short_option}; __index++)); do
    __character="${__short_option:$__index:1}"

    # TODO(ianflanagan): consider checking that option characters are alphanumeric

    # If the final short option has a trailing value connected by =
    # then split it and stop parsing short options
    if [[ "${__character}" == "=" ]]; then
      printf "%s\\n" "${__short_option:$__index+1}"
      break
    fi

    printf "%s\\n" "-${__character}"
  done
}

# Usage: _split_long_options <long_option>
# If a long option has a trailing value (connected by =), then split them
# --option=123  =>  --option 123
function _split_long_options() {
  local __long_option="${1:?}"

  if [[ "$__long_option" == --*=* ]]; then
    printf "%s\\n" "${__long_option%%=*}" # the string before the first equals sign
    printf "%s\\n" "${__long_option#*=}"  # the string after the first equals sign
  else
    printf "%s\\n" "${__long_option}"
  fi
}

# Usage: _split_options <arguments>
# Pass short options to `_split_short_options` and pass long options to
# `_split_long_options`
function _split_options() {
  local __processed_option __argument
  _args=()

  while ((${#@})); do
    __argument="${1:?}" # error on empty string arguments

    # Send short options to `_split_short_options`
    if [[ "${__argument}" =~ ^-[^-] ]]; then

      # Use mapfile to read the output into the _args array
      # https://www.shellcheck.net/wiki/SC2207
      mapfile -t __processed_option < <(_split_short_options "${__argument}")
      _args+=("${__processed_option[@]}")

    # Send long options to `_split_long_options`
    elif [[ "${__argument}" =~ ^--[^=]+ ]]; then
      mapfile -t __processed_option < <(_split_long_options "${__argument}")
      _args+=("${__processed_option[@]}")

    # Otherwise leave the argument as it is
    else
      _args+=("${__argument}")
    fi
    shift
  done
}

###############################################################################
# Option-Parsing Functions
###############################################################################

# Usage: __get_option_value <option> <value>
# Check that the argument after the option is not empty
function __get_option_value() {
  local __option="${1:?}" 
  local __value="${2:-}"

  if [[ -n "${__value}" ]]; then
    printf "%s\\n" "${__value}"
  else
    _exit_1 printf "%s requires an argument.\\n" "${__option}"
  fi
}

# Text added to script-specific help/usage function
readonly _usage_standard_options="-h, --help      Display this help message
  -V, --version   Show version information
  -v, --verbose   Enable verbose output
  --debug         Enable debug output
  --endopts       Stop reading options and arguments
  --timeout <0>   Stop execution after a given number of seconds"

# Usage: _parse_common_options <arguments>
# Parse the arguments the boilerplate's options common to all script
function _parse_common_options() {
  _args=()

  while ((${#@})); do
    local __argument="${1:?}" # error on empty string arguments
    local __value="${2:-}"

    # Make sure to replace common options with empty strings to avoid script
    # specific options being incorrectly paired with following arguments
    case "${__argument}" in
      # Options that don't require values
      -h|--help)
        # _help_option=1
        # _args+=("")
        _usage
        exit 0
        ;;
      -V|--version)
        echo "${__file:?} version: ${_script_version:?}, with boilerplate version: ${__boilerplate_version:?}"
        exit 0
        ;;
      -v|--verbose)
        __verbose_option=1
        _args+=("")
        ;;
      --debug)
        __debug_option=1
        _args+=("")
        ;;
      --endopts)
        break # Terminate option parsing
        ;;

      # Options that require values
      --timeout)
        local timeout_duration
        timeout_duration="$(__get_option_value "${__argument}" "${__value}")"

        if ! is_unsigned_integer "${timeout_duration}"; then
          _exit_1 echo "--timeout must be an unsigned integer. '${timeout_duration}' given" >&2
        fi

        _start_timeout_process "${timeout_duration}"

        _args+=("")
        shift
        ;;

      # Pass remaining argument to `_parse_script_specific_options`
      *)
        _args+=("${__argument}")
        ;;
    esac
    shift
  done
}



# Implement in individual scripts:
###############################################################################
###############################################################################
###############################################################################

# #!/usr/bin/env bash

# # Description

# ###############################################################################
# # Constants and Defaults
# ###############################################################################

# # Required by boilerplate
# readonly _script_version="1.0.0"

# ###############################################################################
# # Sources
# ###############################################################################

# # shellcheck source=_buildignore/scripts/lib/boilerplate.sh
# source "$(dirname "${BASH_SOURCE[0]}")/../lib/boilerplate.sh"

# # shellcheck source=_gitignore/config/project
# source "${__project_config_file}"

# ###############################################################################
# # Help
# ###############################################################################

# function _usage() {
#   cat << EOF
# Usage: ${__file:?} [OPTIONS]
  
# Options:
#   ${_usage_standard_options}
# EOF
# }

# ###############################################################################
# # Script-Specific Cleanup
# ###############################################################################

# function script_specific_cleanup() {
#   :
# }

# ###############################################################################
# # Script-Specific Options
# ###############################################################################

# function _parse_script_specific_options() {
#   _args=()

#   while ((${#@})); do
#     local __argument="${1:-}"
#     local __value="${2:-}"

#     if [[ -z ${__argument} ]]; then
#       shift
#       continue
#     fi

#     case "${__argument}" in
#     -*)
#       _exit_1 echo "Invalid option: ${__argument}"
#       ;;
#     *)
#       _args+=("${__argument}")
#       ;;
#     esac
#     shift
#   done
# }

# ###############################################################################
# # Arguments
# ###############################################################################

# function _validate_positional_arguments() {
#   # Validate number of arguments
#   if [[ "${#@}" -ne 0 ]]; then
#     _usage
#     _exit_1 echo "Needs 0 arguments. ${#@} given" >&2
#   fi
# }

# ###############################################################################
# # Functions
# ###############################################################################

# function _simple() {
#   :
# }

# ###############################################################################
# # Main
# ###############################################################################

# # Usage: _main [<options>] [<arguments>]
# # Entry point for the program, handling basic option parsing and dispatching
# function _main() {
#   _enable_strict_mode
#   _validate_commands "/usr/bin/php"
#   _split_options "${@}"
#   _parse_common_options "${_args[@]}"
#   _parse_script_specific_options "${_args[@]}"
#   _validate_positional_arguments "${_args[@]}"

#   _simple
# }

# # Only execute if not sourced in another script (e.g. unit testing)
# if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
#   _main "${@}"
# fi
