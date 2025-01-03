#!/usr/bin/env bash

# Check the settings and resources on all environment servers and/or jenkins

###############################################################################
# Constants and Defaults
###############################################################################

# Required by boilerplate
readonly _script_version="1.0.0"

# Script-specific
server="all"

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
Usage: ${__file:?} [OPTIONS] <SERVER>
  SERVER: all / <server-name> / jenkins (default: all)
  
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
  if [[ "${#@}" -gt 1 ]]; then
    _usage
    _exit_1 echo "Error: Needs <= 1 argument. ${#@} given" >&2
  fi

  readonly server="${1:?}"

  # Validate server
  if ! is_alphanumeric_underscore_dot_dash "${server}"; then
    _exit_1 echo "Error: SERVER must be alphanumeric or _ . -" >&2
  fi
  
}

###############################################################################
# Functions
###############################################################################

verify_server_setup() {
  local user=${1}
  local ip=${2}
  local environment_name=${3}

  local project_root="${__web_root}/${__project_name}"
  local project_environment_root="${project_root}/${environment_name}"
  local releases_root="${project_environment_root}/releases"

  local project_logs_root="${__log_root}/${__project_name}"
  local project_environment_logs_root="${project_logs_root}/${environment_name}"

  # local temp_build_root="${releases_root}/0"
  # local temp_build_public_root="${temp_build_root}/public"
  # local temp_build_index_file_path="${temp_build_public_root}/index.php"

  # shellcheck disable=SC2087
  ssh "${user}@${ip}" << EOF
    exit_code=0

    function check_directory_exists() {
      local target="\${1}"
      if ! [[ -d "\${target}" ]]; then
        echo "Directory missing: \${target}"
        exit_code=1
      fi
    }

    function check_file_exists() {
      local target="\${1}"
      if ! [[ -f "\${target}" ]]; then
        echo "File missing: \${target}"
        exit_code=1
      fi
    }

    function check_symlink_exists() {
      local target="\${1}"
      if ! [[ -L "\${target}" ]]; then
        echo "Symlink missing or broken: \${target}"
        exit_code=1
      fi
    }

    function check_command() {
      local error_message="\${@:-1}"
      if ! "\${@:1:\$#-1}" &>/dev/null; then
        echo "\${error_message}"
        exit_code=1
      fi
    }

    ###########################################################################
    # Check results of initialize_new_project.sh
    ###########################################################################

    # Check project group, 'jenkins' user, SSH directory and file
    check_command getent group "${__project_name}" \
      "Group missing: ${__project_name}"
    check_command getent passwd jenkins \
      "User missing: jenkins"

    check_directory_exists "/home/jenkins/"
    check_directory_exists "/home/jenkins/.ssh"
    check_file_exists "/home/jenkins/.ssh/authorized_keys"

    # Check project directories
    check_directory_exists "${project_root}"
    check_directory_exists "${project_environment_root}"
    check_directory_exists "${project_environment_root}/deploy"
    check_directory_exists "${releases_root}"

    # Check log directories
    check_directory_exists "${project_logs_root}"
    check_directory_exists "${project_environment_logs_root}"

    # Don't check temporary build

    # Check 'current' symlink
    check_directory_exists "${project_environment_root}/current"

    # Check Nginx include directories
    check_directory_exists "${__nginx_root_directories}"
    check_file_exists "${__nginx_root_directories}/${__project_name}-${environment_name}"
    check_symlink_exists "${__nginx_sites_enabled}/${__project_name}-${environment_name}"

    ###########################################################################
    # Check results of transfer.sh
    ###########################################################################

    check_file_exists "/var/spool/cron/crontabs/root"                                     # cron-root
    check_file_exists "${__web_root}/${__project_name}/${environment_name}/deploy/.env"   # env
    check_file_exists "${__nginx_sites_available}/${__project_name}-${environment_name}"  # nginx
    check_file_exists "/etc/sudoers.d/jenkins"                                            # sudoers
    check_file_exists "/etc/supervisor/conf.d/${__project_name}-${environment_name}.conf" # supervisor

    # TODO(ianflanagan): Check transfer.sh server-scripts multiple files
    # TODO(ianflanagan): Check transfer.sh starting-images multiple files

    ###########################################################################
    # Final checks
    ###########################################################################

    # Verify nginx config
    check_command nginx -t \
      "Nginx config test failed"

    exit \${exit_code}
EOF
}

# Create protected directory on jenkins server to hold .env's, dependency caches etc.
verify_jenkins_setup() {
  local environment_name user ip

  IFS="," read -r environment_name user ip < "${__jenkins_config_file}"

  # shellcheck disable=SC2087
  ssh "${user}@${ip}" << EOF
    exit_code=0

    function check_directory_exists() {
      local target="\${1}"
      if ! [[ -d "\${target}" ]]; then
        echo "Directory missing: \${target}"
        exit_code=1
      fi
    }

    function check_file_exists() {
      local target="\${1}"
      if ! [[ -f "\${target}" ]]; then
        echo "File missing: \${target}"
        exit_code=1
      fi
    }

    ###########################################################################
    # Check results of initialize_new_project.sh
    ###########################################################################

    check_directory_exists "/var/lib/jenkins/project-files"
    check_directory_exists "/var/lib/jenkins/project-files/${__project_name}"
    check_directory_exists "/var/lib/jenkins/project-files/${__project_name}/env-files"

    ###########################################################################
    # Check results of transfer.sh
    ###########################################################################

    check_file_exists "${__nginx_sites_available}/jenkins"      # env

    # TODO(ianflanagan): Check env multiple files
EOF
}

###############################################################################
# Main
###############################################################################

# Usage: _main [<options>] [<arguments>]
# Entry point for the program, handling basic option parsing and dispatching
function _main() {
  _enable_strict_mode
  _validate_commands "/usr/bin/ssh"
  _split_options "${@}"
  _parse_common_options "${_args[@]}"
  _parse_script_specific_options "${_args[@]}"
  _validate_positional_arguments "${_args[@]}"

  case "${server}" in
    # Only jenkins
    jenkins)
      verify_jenkins_setup
      ;;

    # Jenkins and all servers
    all)
      verify_jenkins_setup
      while IFS="," read -r environment_name user ip; do
        verify_server_setup "${user}" "${ip}" "${environment_name}"
      done < "${__environments_config_file}"
      ;;

    # One specific server
    *)
      local found_server=0
      while IFS="," read -r environment_name user ip; do
        if [[ "${server}" == "${environment_name}" ]]; then
          verify_server_setup "${user}" "${ip}" "${environment_name}"
          found_server=1
          break
        fi
      done < "${__environments_config_file}"

      if ! ((found_server)); then
        _exit_1 echo "Invalid SERVER: '${server}'"
      fi
      ;;
  esac
}

# Only execute if not sourced in another script (e.g. unit testing)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  _main "${@}"
fi
