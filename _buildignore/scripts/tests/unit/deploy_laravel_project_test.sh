#!/usr/bin/env bash

function oneTimeSetUp() {
  source ./_buildignore/scripts/server/deploy_laravel_project
}


function setUp() {
  :
}

function tearDown() {
  :
}

function oneTimeTearDown() {
  :
}

###############################################################################
# create_backup
###############################################################################

function test_create_backup_with_file_succeeds() {
  local error

  local test_root="/tmp/test_create_backup_with_file_succeeds"
  local original="${test_root}/file.txt"
  local permissions="751"
  local backup="${original}.bak"
  local content="37f]fd';lsdf9d"

  mkdir "${test_root}"
  install -m "${permissions}" <(echo "${content}") "${original}"

  create_backup "${original}"

  [[ -f "${backup}" ]]; error=$?

  assertEquals "Backup file should exist." 0 "${error}"
  assertEquals "Original and backup content should match." \
    "$(cat "${original}")" "$(cat "${backup}")"
  assertEquals "Original and backup permissions should match." \
    "$(stat -c '%A-%G:%U' "${original}")" "$(stat -c '%A-%G:%U' "${backup}")"

  rm -rf "${test_root}"
}

function test_create_backup_with_symlink_succeeds() {
  local error

  local test_root="/tmp/test_create_backup_with_symlink_succeeds"
  local original="${test_root}/symlink"
  local backup="${original}.bak"

  local target_root="${test_root}/target"
  local target_file_name="file.txt"
  local content="43u[09igd;lk]"

  mkdir "${test_root}"
  mkdir "${target_root}"
  echo "${content}" > "${target_root}/${target_file_name}"
  ln -s "${target_root}" "${original}"

  create_backup "${original}"

  [[ -L "${backup}" ]]; error=$?

  assertEquals "Backup file should exist." 0 "${error}"
  assertEquals "Original and backup target should match." \
    "$(ls "${original}")" "$(ls "${backup}")"

  rm -rf "${test_root}"
}

function test_create_backup_with_directory_succeeds() {
  local test_root="/tmp/test_create_backup_with_directory_succeeds"
  local content1="37f]fd';lsdf9d"
  local content2="40g09asdl;lfs/"
  local file_name="file.txt"
  local symlink_name="symlink"

  local original_directory="${test_root}/dir"
  local original_directory_permissions="700"
  local original_file="${original_directory}/${file_name}"
  local original_file_permissions="770"
  local original_symlink="${original_directory}/${symlink_name}"

  local backup_directory="${original_directory}.bak"
  local backup_file="${backup_directory}/${file_name}"
  local backup_symlink="${backup_directory}/${symlink_name}"

  local target_root="${test_root}/target1"
  local target_file_name="file1.txt"

  mkdir "${test_root}"
  mkdir "${target_root}"
  echo "${content2}" > "${target_root}/${target_file_name}"

  install -m "${original_directory_permissions}" -d "${original_directory}"
  install -m "${original_file_permissions}" <(echo "${content1}") "${original_file}"
  ln -s "${target_root}" "${original_symlink}"

  create_backup "${original_directory}"

  [[ -d "${backup_directory}" ]]; directory_error=$?
  [[ -f "${backup_file}" ]]; file_error=$?
  [[ -L "${backup_symlink}" ]]; symlink_error=$?

  assertEquals "Backup directory should exist." 0 "${directory_error}"
  assertEquals "Backup directory's file should exist." 0 "${file_error}"
  assertEquals "Backup directory's symlink should exist." 0 "${symlink_error}"
  assertEquals "Original and backup file content should match." \
    "$(cat "${original_file}")" "$(cat "${backup_file}")"
  assertEquals "Original and backup symlink target should match." \
    "$(ls "${original_symlink}")" "$(ls "${backup_symlink}")"
  assertEquals "Original and backup directory permissions should match." \
    "$(stat -c '%A-%G:%U' "${original_directory}")" \
    "$(stat -c '%A-%G:%U' "${backup_directory}")"
  assertEquals "Original and backup file permissions should match." \
    "$(stat -c '%A-%G:%U' "${original_file}")" \
    "$(stat -c '%A-%G:%U' "${backup_file}")"
  assertEquals "Original and backup symlink permissions should match." \
    "$(stat -c '%A-%G:%U' "${original_symlink}")" \
    "$(stat -c '%A-%G:%U' "${backup_symlink}")"

  rm -rf "${test_root}"
}

function test_create_backup_with_no_parameter_or_empty_string_returns_error() {
  local unset_error empty_string_error

  #shellcheck disable=SC2091
  $(create_backup &>/dev/null); unset_error=$?
  #shellcheck disable=SC2091
  $(create_backup "" &>/dev/null); empty_string_error=$?

  assertEquals "Should return error with no parameter." 1 "${unset_error}"
  assertEquals "Should return error with empty string." 1 "${empty_string_error}"
}

###############################################################################
# restore_from_backup
###############################################################################

function test_restore_from_backup_with_file_succeeds() {
  local test_root="/tmp/test_restore_from_backup_with_file_succeeds"
  local original="${test_root}/file.txt"
  local backup="${original}.bak"
  local content1="3[095[oyttjh]]"
  local content2="'sasffghwe43dd"
  local permissions1="751"
  local permissions2="774"

  # Create original and backup
  mkdir "${test_root}"
  install -m "${permissions1}" <(echo "${content1}") "${original}"
  create_backup "${original}"

  # Modify original
  echo "${content2}" > "${original}"
  chmod "${permissions2}" "${original}"

  # Act
  restore_from_backup "${original}"

  assertEquals "Original should have original content restored." \
    "${content1}" "$(cat "${original}")"
  assertEquals "Original should have original permissions restored." \
    "${permissions1}" "$(stat -c '%a' "${original}")"

  rm -rf "${test_root}"
}

function test_restore_from_backup_with_symlink_succeeds() {
  local test_root="/tmp/test_restore_from_backup_with_symlink_succeeds"
  local original="${test_root}/symlink"
  local backup="${original}.bak"

  local target_root1="${test_root}/target1"
  local target_file_name1="file1.txt"
  local content1="P;dgkwj3fsdf'"


  local target_root2="${test_root}/target2"
  local target_file_name2="file2.txt"
  local content2="34t09dfglkjfdg"

  # Create original and backup
  mkdir "${test_root}"
  mkdir "${target_root1}"
  echo "${content1}" > "${target_root1}/${target_file_name1}"
  mkdir "${target_root2}"
  echo "${content2}" > "${target_root2}/${target_file_name2}"
  ln -s "${target_root1}" "${original}"
  create_backup "${original}"

  # Modify original
  ln -snf "${target_root2}" "${original}"

  # Act
  restore_from_backup "${original}"

  assertEquals "Original should have original target restored." \
    "${target_root1}" "$(readlink "${original}")"

  rm -rf "${test_root}"
}

function test_restore_from_backup_with_directory_succeeds() {
  local test_root="/tmp/test_restore_from_backup_with_directory_succeeds"
  local content1="40dflkj4 4toje34"
  local content2=";h0jjj3jwkdddbd"
  local content3="hkhkhj58dfkjhsd"
  local content4="ghdfh445dfhd"
  local file_name="file.txt"
  local symlink_name="symlink"

  local original_directory="${test_root}/dir"
  local original_directory_permissions1="700"
  local original_directory_permissions2="741"
  local original_file="${original_directory}/${file_name}"
  local original_file_permissions1="770"
  local original_file_permissions2="754"
  local original_symlink="${original_directory}/${symlink_name}"

  local backup_directory="${original_directory}.bak"
  local backup_file="${backup_directory}/${file_name}"
  local backup_symlink="${backup_directory}/${symlink_name}"

  local target_root1="${test_root}/target1"
  local target_file_name1="file1.txt"
  local target_root2="${test_root}/target2"
  local target_file_name2="file2.txt"

  mkdir "${test_root}"
  mkdir "${target_root1}"
  echo "${content2}" > "${target_root1}/${target_file_name1}"
  mkdir "${target_root2}"
  echo "${content3}" > "${target_root2}/${target_file_name2}"

  install -m "${original_directory_permissions1}" -d "${original_directory}"
  install -m "${original_file_permissions1}" <(echo "${content1}") "${original_file}"
  ln -s "${target_root1}" "${original_symlink}"

  create_backup "${original_directory}"

  # Modify original
  chmod "${original_directory_permissions2}" "${original_directory}"
  chmod "${original_file_permissions2}" "${original_file}"
  echo "${content4}" > "${original_file}"
  ln -snf "${target_root2}" "${original_symlink}"

  # Act
  restore_from_backup "${original_directory}"

  assertEquals "Original directory should have original permissions restored." \
    "${original_directory_permissions1}" "$(stat -c '%a' "${original_directory}")"
  assertEquals "Original file should have original permissions restored." \
    "${original_file_permissions1}" "$(stat -c '%a' "${original_file}")"
  assertEquals "Original file should have original content restored." \
    "${content1}" "$(cat "${original_file}")"
  assertEquals "Original symlink should have original target restored." \
    "${target_root1}" "$(readlink "${original_symlink}")"

  rm -rf "${test_root}"
}

function test_restore_from_backup_with_no_parameter_or_empty_string_returns_error() {
  local unset_error empty_string_error

  #shellcheck disable=SC2091
  $(restore_from_backup &>/dev/null); unset_error=$?
  #shellcheck disable=SC2091
  $(restore_from_backup "" &>/dev/null); empty_string_error=$?

  assertEquals "Should return error with no parameter." 1 "${unset_error}"
  assertEquals "Should return error with empty string." 1 "${empty_string_error}"
}

function test_restore_from_backup_does_not_delete_original_if_backup_missing() {
  local command_error file_error

  local test_root="/tmp/test_restore_from_backup_does_not_delete_original_if_backup_missing"
  local original="${test_root}/file.txt"
  local content="sdfkjlj44456h"

  mkdir "${test_root}"
  echo "${content}" > "${original}"

  #shellcheck disable=SC2091
  $(restore_from_backup "${original}" &>/dev/null); command_error=$?
  [[ -f "${original}" ]]; file_error=$?

  assertEquals "Should return error." 1 "${command_error}"
  assertEquals "Original should still exist." 0 "${file_error}"

  rm -rf "${test_root}"
}

###############################################################################
# delete_failed_releases
###############################################################################

function test_delete_failed_releases() {
  test_root="/tmp/test_delete_failed_releases"

  success_directory1="${test_root}/1"
  fail_directory1="${test_root}/2"
  success_directory2="${test_root}/3"
  fail_directory2="${test_root}/4"

  mkdir "${test_root}"
  mkdir "${success_directory1}"
  mkdir "${fail_directory1}"
  mkdir "${success_directory2}"
  mkdir "${fail_directory2}"

  echo "1" > "${success_directory1}/.success"
  echo "3" > "${success_directory2}/.success"

  delete_failed_releases "${test_root}" &>/dev/null

  [[ -d "${success_directory1}" ]]; success1_error=$?
  [[ -d "${success_directory2}" ]]; success2_error=$?
  [[ -d "${fail_directory1}" ]]; fail1_error=$?
  [[ -d "${fail_directory2}" ]]; fail2_error=$?

  assertEquals "Success 1 directory should exist." 0 "${success1_error}"
  assertEquals "Success 2 directory should exist." 0 "${success2_error}"
  assertEquals "Fail 1 directory should not exist." 1 "${fail1_error}"
  assertEquals "Fail 2 directory should not exist." 1 "${fail2_error}"

  rm -rf "${test_root}"
}


###############################################################################
# delete_excess_releases
###############################################################################

function setup_directories_for_test_delete_excess_releases() {
  local test_root="${1}"
  local releases_total"${2}"
  local build="${3}"
  local min=1
  local max=4
  local __index

  for ((__index=0; __index < releases_total; __index++)); do
    mkdir "${test_root}/${build}"
    # Note: randomness can lead to flaky tests, but this limited usage
    # simulates reality safely
    ((build+=RANDOM%(max-min+1)+min))
  done
}

function test_delete_excess_releases_keep_5_of_20_across_border_of_1000() {
  local expected_keep_count expected_delete_count error directories directory
  local test_root="/tmp/test_delete_excess_releases_keep_5_of_20_across_border_of_1000"

  # Arrange
  local releases_to_keep=5
  local releases_total=25
  local starting_build=980

  local expected_keep_count=5
  local expected_delete_count=20

  mkdir "${test_root}"
  setup_directories_for_test_delete_excess_releases \
    "${test_root}" "${releases_total}" "${starting_build}"

  # Verify setup
  # shellcheck disable=SC2012
  directories=$(ls "${test_root}" | sort --version-sort)
  assertEquals "Should create ${releases_total} releases." \
    "${releases_total}" "$(echo "${directories}" | wc -l)"

  # Act
  delete_excess_releases "${test_root}" "${releases_to_keep}" &>/dev/null

  # Assert
  local __index=0
  for directory in ${directories}; do
    [[ -d "${test_root}/${directory}" ]]
    #shellcheck disable=SC2319
    error=$?

    if ((__index < expected_delete_count)); then
      assertEquals "${test_root}/${directory} should not exist." 1 "${error}"
    else
      assertEquals "${test_root}/${directory} should exist." 0 "${error}"
    fi

    ((__index++))
  done

  # shellcheck disable=SC2012
  assertEquals "Should keep ${expected_keep_count} releases." \
    "${expected_keep_count}" "$(ls "${test_root}" | wc -l)"

  # Clear up
  rm -rf "${test_root}"
}

function test_delete_excess_releases_keep_1_of_125_from_1() {
  local expected_keep_count expected_delete_count error directories directory
  local test_root="/tmp/test_delete_excess_releases_keep_1_of_125_from_1"

  # Arrange
  local releases_to_keep=1
  local releases_total=125
  local starting_build=1

  local expected_keep_count=1
  local expected_delete_count=124

  mkdir "${test_root}"
  setup_directories_for_test_delete_excess_releases \
    "${test_root}" "${releases_total}" "${starting_build}"

  # Verify setup
  # shellcheck disable=SC2012
  directories=$(ls "${test_root}" | sort --version-sort)
  assertEquals "Should create ${releases_total} releases." \
    "${releases_total}" "$(echo "${directories}" | wc -l)"

  # Act
  delete_excess_releases "${test_root}" "${releases_to_keep}" &>/dev/null

  # Assert
  local __index=0
  for directory in ${directories}; do
    [[ -d "${test_root}/${directory}" ]]
    #shellcheck disable=SC2319
    error=$?

    if ((__index < expected_delete_count)); then
      assertEquals "${test_root}/${directory} should not exist." 1 "${error}"
    else
      assertEquals "${test_root}/${directory} should exist." 0 "${error}"
    fi

    ((__index++))
  done

  # shellcheck disable=SC2012
  assertEquals "Should keep ${expected_keep_count} releases." \
    "${expected_keep_count}" "$(ls "${test_root}" | wc -l)"

  # Clear up
  rm -rf "${test_root}"
}

function test_delete_excess_releases_keep_50_of_15_across_border_of_100() {
  local expected_keep_count expected_delete_count error directories directory
  local test_root="/tmp/test_delete_excess_releases_keep_50_of_15_across_border_of_100"

  # Arrange
  local releases_to_keep=50
  local releases_total=15
  local starting_build=80

  local expected_keep_count=15
  local expected_delete_count=0

  mkdir "${test_root}"
  setup_directories_for_test_delete_excess_releases \
    "${test_root}" "${releases_total}" "${starting_build}"

  # Verify setup
  # shellcheck disable=SC2012
  directories=$(ls "${test_root}" | sort --version-sort)
  assertEquals "Should create ${releases_total} releases." \
    "${releases_total}" "$(echo "${directories}" | wc -l)"

  # Act
  delete_excess_releases "${test_root}" "${releases_to_keep}" &>/dev/null

  # Assert
  local __index=0
  for directory in ${directories}; do
    [[ -d "${test_root}/${directory}" ]]
    #shellcheck disable=SC2319
    error=$?

    if ((__index < expected_delete_count)); then
      assertEquals "${test_root}/${directory} should not exist." 1 "${error}"
    else
      assertEquals "${test_root}/${directory} should exist." 0 "${error}"
    fi

    ((__index++))
  done

  # shellcheck disable=SC2012
  assertEquals "Should keep ${expected_keep_count} releases." \
    "${expected_keep_count}" "$(ls "${test_root}" | wc -l)"

  # Clear up
  rm -rf "${test_root}"
}

function test_delete_excess_releases_keep_1_of_1_from_1() {
  local expected_keep_count expected_delete_count error directories directory
  local test_root="/tmp/test_delete_excess_releases_keep_1_of_1_from_1"

  # Arrange
  local releases_to_keep=1
  local releases_total=1
  local starting_build=1

  local expected_keep_count=1
  local expected_delete_count=0

  mkdir "${test_root}"
  setup_directories_for_test_delete_excess_releases \
    "${test_root}" "${releases_total}" "${starting_build}"

  # Verify setup
  # shellcheck disable=SC2012
  directories=$(ls "${test_root}" | sort --version-sort)
  assertEquals "Should create ${releases_total} releases." \
    "${releases_total}" "$(echo "${directories}" | wc -l)"

  # Act
  delete_excess_releases "${test_root}" "${releases_to_keep}" &>/dev/null

  # Assert
  local __index=0
  for directory in ${directories}; do
    [[ -d "${test_root}/${directory}" ]]
    #shellcheck disable=SC2319
    error=$?

    if ((__index < expected_delete_count)); then
      assertEquals "${test_root}/${directory} should not exist." 1 "${error}"
    else
      assertEquals "${test_root}/${directory} should exist." 0 "${error}"
    fi

    ((__index++))
  done

  # shellcheck disable=SC2012
  assertEquals "Should keep ${expected_keep_count} releases." \
    "${expected_keep_count}" "$(ls "${test_root}" | wc -l)"

  # Clear up
  rm -rf "${test_root}"
}

function test_delete_excess_releases_keep_0_keeps_all() {
  local expected_keep_count expected_delete_count error directories directory
  local test_root="/tmp/test_delete_excess_releases_keep_0_keeps_all"

  # Arrange
  local releases_to_keep=0
  local releases_total=10
  local starting_build=1

  local expected_keep_count=10
  local expected_delete_count=0

  mkdir "${test_root}"
  setup_directories_for_test_delete_excess_releases \
    "${test_root}" "${releases_total}" "${starting_build}"

  # Verify setup
  # shellcheck disable=SC2012
  directories=$(ls "${test_root}" | sort --version-sort)
  assertEquals "Should create ${releases_total} releases." \
    "${releases_total}" "$(echo "${directories}" | wc -l)"

  # Act
  delete_excess_releases "${test_root}" "${releases_to_keep}" &>/dev/null

  # Assert
  local __index=0
  for directory in ${directories}; do
    [[ -d "${test_root}/${directory}" ]]
    #shellcheck disable=SC2319
    error=$?

    if ((__index < expected_delete_count)); then
      assertEquals "${test_root}/${directory} should not exist." 1 "${error}"
    else
      assertEquals "${test_root}/${directory} should exist." 0 "${error}"
    fi

    ((__index++))
  done

  # shellcheck disable=SC2012
  assertEquals "Should keep ${expected_keep_count} releases." \
    "${expected_keep_count}" "$(ls "${test_root}" | wc -l)"

  # Clear up
  rm -rf "${test_root}"
}

# shellcheck disable=SC1091
source shunit2
