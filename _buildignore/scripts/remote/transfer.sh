#!/usr/bin/env bash

# Transfer .env files to jenkins and/or servers

###############################################################################
# Constants and Defaults
###############################################################################

# Required by boilerplate
readonly _script_version="1.0.0"

# Script-specific
server="all"

__cron_root_root="$(dirname "${BASH_SOURCE[0]}")/../../config/cron-root"
__envs_root="$(dirname "${BASH_SOURCE[0]}")/../../../_gitignore/env-files"
__nginx_root="$(dirname "${BASH_SOURCE[0]}")/../../config/nginx"
__server_scripts_root="$(dirname "${BASH_SOURCE[0]}")/../server"
__starting_images_root="$(dirname "${BASH_SOURCE[0]}")/../../config/starting-images"
__sudoers_root="$(dirname "${BASH_SOURCE[0]}")/../../config/sudoers.d"
__supervisor_root="$(dirname "${BASH_SOURCE[0]}")/../../config/supervisor"

readonly __envs_root

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
Usage: ${__file:?} [OPTIONS] <TYPE> <SERVER>
  TYPE: file(s) to be transferred
    cron-root, env, nginx, server-scripts, sudoers, supervisor
  SERVER: all / <server-name> / jenkins (default: all)
  
Options:
  ${_usage_standard_options}
  --dry-run
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
  dry_run_option=0

  _args=()

  while ((${#@})); do
    local __argument="${1:-}"
    local __value="${2:-}"

    if [[ -z ${__argument} ]]; then
      shift
      continue
    fi

    case "${__argument}" in
    --dry-run)
      dry_run_option=1
      ;;
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
  if [[ "${#@}" -ne 2 ]]; then
    _usage
    _exit_1 echo "Error: Needs 2 arguments. ${#@} given" >&2
  fi

  readonly type="${1:?}"
  readonly server="${2:?}"

  # Validate type
  if ! is_alphanumeric_underscore_dot_dash "${type}"; then
    _exit_1 echo "Error: TYPE must be alphanumeric or _ . -" >&2
  fi

  # Validate server
  if ! is_alphanumeric_underscore_dot_dash "${server}"; then
    _exit_1 echo "Error: SERVER must be alphanumeric or _ . -" >&2
  fi
}

###############################################################################
# Functions
###############################################################################

transfer() {
    local user="${1}"
    local ip="${2}"
    local mode="${3}"
    local ownership="${4}"
    local source="${5}"
    local destination="${6}"

    local options=()
    options+=("--chmod=${mode}")
    options+=("--chown=${ownership}")

    if ((dry_run_option)); then
      options+=("--dry-run")
    fi

    rsync -rvzhogpe "ssh -o StrictHostKeyChecking=no" "${options[@]}" \
      "${source}" "${user}@${ip}:${destination}"
}

transfer_to_server() {
  local user="${1}"
  local ip="${2}"
  local environment_name="${3}"
  local mode source destination

  case "${type}" in
    cron-root)
      source="${__cron_root_root}/${environment_name}"
      destination="/var/spool/cron/crontabs/root"
      mode="0400"
      ownership="root:root"
      ;;
    env)
      source="${__envs_root}/.env.${environment_name}"
      destination="${__web_root}/${__project_name}/${environment_name}/deploy/.env"
      mode="0400"
      ownership="www-data:${__project_name}"
      ;;
    nginx)
      source="${__nginx_root}/${environment_name}.ssl"
      destination="${__nginx_sites_available}/${__project_name}-${environment_name}"
      mode="0640"
      ownership="www-data:${__project_name}"
      ;;
    server-scripts)
      # 'dir/' to 'dir' and 'dir/' to 'dir/'
      # - copy transfer all files in source directory;
      # - doesn't delete other files in the destination directory;
      # - overwrites destination directory ownership and mode
      source="${__server_scripts_root}/"
      destination="/usr/local/bin"
      mode="0500"
      ownership="root:root"
      ;;
    starting-images)
      source="${__starting_images_root}"
      destination="${__web_root}/${__project_name}/${environment_name}/deploy"
      mode="0550"
      ownership="www-data:${__project_name}"
      ;;
    sudoers)
      source="${__sudoers_root}/jenkins"
      destination="/etc/sudoers.d/jenkins"
      mode="0400"
      ownership="root:root"
      ;;
    supervisor)
      source="${__supervisor_root}/${environment_name}"
      destination="/etc/supervisor/conf.d/${__project_name}-${environment_name}.conf"
      mode="0400"
      ownership="root:root"
      ;;
  esac

  transfer "${user}" "${ip}" "${mode}" "${ownership}" \
    "${source}" "${destination}"
}

transfer_to_jenkins() {
  local user ip environment_name mode source destination

  IFS="," read -r environment_name user ip < "${__jenkins_config_file}"

  case "${type}" in
    cron-root)
      ;;
    env)
      # 'dir/' to 'dir' and 'dir/' to 'dir/'
      # - copy transfer all files in source directory;
      # - doesn't delete other files in the destination directory;
      # - overwrites destination directory ownership and mode
      source="${__envs_root}/"
      destination="/var/lib/jenkins/project-files/${__project_name}/env-files"
      mode="0500"
      ownership="jenkins:jenkins"
      ;;
    nginx)
      source="${__nginx_root}/${environment_name}.ssl"
      destination="${__nginx_sites_available}/jenkins"
      mode="0640"
      ownership="www-data:jenkins"
      ;;
    server-scripts)
      ;;
    starting-images)
      ;;
    sudoers)
      ;;
    supervisor)
      ;;
  esac

  transfer "${user}" "${ip}" "${mode}" "${ownership}" \
    "${source}" "${destination}"
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

  local environment_name user ip

  case "${server}" in
    # Only jenkins
    jenkins)
      transfer_to_jenkins
      ;;

    # Jenkins and all servers
    all)
      transfer_to_jenkins
      while IFS="," read -r environment_name user ip; do
        transfer_to_server "${user}" "${ip}" "${environment_name}"
      done < "${__environments_config_file}"
      ;;

    # One specific server
    *)
      local found_server=0
      while IFS="," read -r environment_name user ip; do
        if [[ "${server}" == "${environment_name}" ]]; then
          transfer_to_server "${user}" "${ip}" "${environment_name}"
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
