#!/usr/bin/env bash

# Create necessary resources for a new Laravel project
# On servers, create a group, directories, files
# On jenkins server, create directories for .env files and dependency caches

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
  if [[ "${#@}" -ne 1 ]]; then
    _usage
    _exit_1 echo "Error: Needs 1 argument. ${#@} given" >&2
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

initialize_on_server() {
  local user=${1}
  local ip=${2}
  local environment_name=${3}

  local project_root="${__web_root}/${__project_name}"
  local project_environment_root="${project_root}/${environment_name}"
  local releases_root="${project_environment_root}/releases"

  local project_logs_root="${__log_root}/${__project_name}"
  local project_environment_logs_root="${project_logs_root}/${environment_name}"

  local temp_build_root="${releases_root}/0"
  local temp_build_public_root="${temp_build_root}/public"
  local temp_build_index_file_path="${temp_build_public_root}/index.php"

  # shellcheck disable=SC2087
  ssh "${user}@${ip}" << EOF
    # Abort if project root already exists
    if [[ -d "${project_environment_root}" ]]; then
      echo "Error: Project environment directory already exists: ${project_environment_root}"
      exit 1
    fi

    # Create a group for jenkins and human admins to manage this project
    if ! getent group "${__project_name}" &>/dev/null; then
      groupadd "${__project_name}"
    fi

    # Create 'jenkins' user or add to <project> group
    if ! getent passwd jenkins &>/dev/null; then
      useradd -m -s /bin/bash -G "${__project_name}" jenkins
    else
      usermod -aG "${__project_name}" jenkins
    fi

    # Ensure /home/jenkins/.ssh/authorized_keys file exists
    if ! [[ -f /home/jenkins/.ssh/authorized_keys ]]; then
      # install -d does not overwrite existing directory or contained files
      # but does set mode, owner, and group
      install -m 0700 -o jenkins -g jenkins -d /home/jenkins/.ssh
      install -m 0600 -o jenkins -g jenkins \
        /dev/null /home/jenkins/.ssh/authorized_keys
    fi

    # Create project directories
    install -m 0550 -o www-data -g "${__project_name}" \
      -d "${project_root}" "${project_environment_root}" \
      "${project_environment_root}/deploy"
    install -m 0570 -o www-data -g "${__project_name}" -d "${releases_root}"

    # Ensure log directories exist
    install -m 0555 -o root -g "${__project_name}" -d "${project_logs_root}" \
      "${project_environment_logs_root}"

    # Create temporary build for testing
    install -m 0570 -o www-data -g "${__project_name}" \
      -d "${temp_build_root}" "${temp_build_public_root}"
    install -m 0640 -o www-data -g "${__project_name}" \
      <(echo "<?php echo 'hello!! "${__project_name}"';") \
      "${temp_build_index_file_path}"

    # Create 'current' symlink for supervisor config references
    ln -snf "${temp_build_root}" "${project_environment_root}/current"

    # Ensure Nginx config include directories exist and create reference file
    install -m 0755 -o root -g root -d "${__nginx_includes}" \
      "${__nginx_root_directories}"
    echo "root ${temp_build_public_root};" > \
      "${__nginx_root_directories}/${__project_name}-${environment_name}"

    # Create Nginx sites-enabled symlink
    ln -snf "${__nginx_sites_available}/${__project_name}-${environment_name}" \
      "${__nginx_sites_enabled}/${__project_name}-${environment_name}"

    service nginx reload
    service php8.3-fpm reload
EOF
}

# Create protected directory on jenkins server to hold .env's, dependency caches etc.
initialize_on_jenkins() {
  local environment_name user ip

  IFS="," read -r environment_name user ip < "${__jenkins_config_file}"

  # shellcheck disable=SC2087
  ssh "${user}@${ip}" << EOF
    install -m 0755 -o jenkins -g jenkins -d /var/lib/jenkins/project-files

    install -m 0700 -o jenkins -g jenkins \
      -d "/var/lib/jenkins/project-files/${__project_name}"

    install -m 0500 -o jenkins -g jenkins \
      -d "/var/lib/jenkins/project-files/${__project_name}/env-files"
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
      initialize_on_jenkins
      ;;

    # Jenkins and all servers
    all)
      initialize_on_jenkins
      while IFS="," read -r environment_name user ip; do
        initialize_on_server "${user}" "${ip}" "${environment_name}"
      done < "${__environments_config_file}"
      ;;

    # One specific server
    *)
      local found_server=0
      while IFS="," read -r environment_name user ip; do
        if [[ "${server}" == "${environment_name}" ]]; then
          initialize_on_server "${user}" "${ip}" "${environment_name}"
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
