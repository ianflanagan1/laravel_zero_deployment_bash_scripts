#!/usr/bin/env bash

function oneTimeSetUp() {
  source ./_buildignore/scripts/lib/boilerplate.sh
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
# Stubs for Script-Specific Functions
###############################################################################

readonly _script_version="212g0-gt3dgl;kgd;lkg45fgo"
readonly __usage_stub_string="dfgdfg4tdksdf2323rjhjdsfj"

function _usage() {
  echo "${__usage_stub_string}"
}

function script_specific_cleanup() {
  __script_specific_cleanup_triggered=1
}

###############################################################################
# _general_cleanup
###############################################################################

function test_general_cleanup_calls_script_specific_cleanup() {
  local stdout error

  __script_specific_cleanup_triggered=0

  _general_cleanup; error=$?

  assertEquals "Should succeed." 0 "${error}"
  assertEquals "Should call script_specific_cleanup." 1 "${__script_specific_cleanup_triggered}"
}

###############################################################################
# _enable_strict_mode
###############################################################################

function test_enable_strict_mode() {
  local trap_original ifs_original set_store trap_store ifs_store
  local error_errexit error_nounset error_pipefail error_errtrace
  local error_trap_err error_trap_exit

  # store original settings to verify they're restored correctly at the end
  trap_original=$(trap)
  ifs_original=$IFS

  _enable_strict_mode

  set_store=$(set -o)
  trap_store=$(trap)
  ifs_store=$IFS

  _disable_strict_mode

  # echo "${set_store}" | grep 'errexit.*on' &>/dev/null; error_errexit=$?
  echo "${set_store}" | grep 'nounset.*on' &>/dev/null; error_nounset=$?
  echo "${set_store}" | grep 'pipefail.*on' &>/dev/null; error_pipefail=$?
  echo "${set_store}" | grep 'errtrace.*on' &>/dev/null; error_errtrace=$?
  echo "${trap_store}" | grep 'ERR' &>/dev/null; error_trap_err=$?
  echo "${trap_store}" | grep 'EXIT' &>/dev/null; error_trap_exit=$?

  # assertEquals 0 "${error_errexit}"
  assertEquals "Should enable nounset." 0 "${error_nounset}"
  assertEquals "Should enable pipefail." 0 "${error_pipefail}"
  assertEquals "Should enable errtrace." 0 "${error_errtrace}"
  assertEquals "Should enable trap ERR." 0 "${error_trap_err}"
  assertEquals "Should enable trap EXIT." 0 "${error_trap_exit}"
  assertEquals "Should set IFS" $'\n\t' "${ifs_store}"

  # restore and check Shunit2's trap and IFS
  trap '_shunit_cleanup EXIT' EXIT
  trap '_shunit_cleanup INT' SIGINT
  trap '_shunit_cleanup TERM' SIGTERM

  assertEquals "Should restore shunit2 trap." "${trap_original}" "$(trap)"
  assertEquals "Should restore shunit2 IFS." "${ifs_original}" "${IFS}"
}

###############################################################################
# _disable_strict_mode
###############################################################################

function test_disable_strict_mode() {
  local trap_original ifs_original
  local error_errexit error_nounset error_pipefail error_errtrace
  local error_trap_err error_trap_exit

  # store settings to verify they're restored correctly at the end
  trap_original=$(trap)
  ifs_original=$IFS

  # clear Shunit2 traps
  trap - EXIT
  trap - SIGINT
  trap - SIGTERM

  _enable_strict_mode
  _disable_strict_mode

  set -o | grep 'errexit.*on' &>/dev/null; error_errexit=$?
  set -o | grep 'nounset.*on' &>/dev/null; error_nounset=$?
  set -o | grep 'pipefail.*on' &>/dev/null; error_pipefail=$?
  set -o | grep 'errtrace.*on' &>/dev/null; error_errtrace=$?
  trap | grep 'ERR' &>/dev/null; error_trap_err=$?
  trap | grep 'EXIT' &>/dev/null; error_trap_exit=$?

  assertEquals "Should enable errexit." 1 "${error_errexit}"
  assertEquals "Should enable nounset." 1 "${error_nounset}"
  assertEquals "Should enable pipefail." 1 "${error_pipefail}"
  assertEquals "Should enable errtrace." 1 "${error_errtrace}"
  assertEquals "Should enable trap ERR." 1 "${error_trap_err}"
  assertEquals "Should enable trap EXIT." 1 "${error_trap_exit}"
  assertEquals "Should unset IFS." $' \t\n' "${IFS}"

  # restore Shunit2's trap settings
  trap '_shunit_cleanup EXIT' EXIT
  trap '_shunit_cleanup INT' SIGINT
  trap '_shunit_cleanup TERM' SIGTERM

  assertEquals "Should restore shunit2 trap." "${trap_original}" "$(trap)"
  assertEquals "Should restore shunit2 IFS." "${ifs_original}" "${IFS}"
}

###############################################################################
# _validate_commands
###############################################################################

function test_validate_commands_with_valid_commands_succeeds() {
  local output error
  output=$(_validate_commands "ls" "cd" 2>&1); error=$?

  assertEquals "Should succeed." 0 "${error}"
  assertEquals "Should have no output." "" "${output}"
}

function test_validate_commands_with_valid_commands_absolute_paths_succeeds() {
  local output error
  output=$(_validate_commands "/usr/bin/wc" "/usr/bin/sudo" 2>&1); error=$?

  assertEquals "Should succeed." 0 "${error}"
  assertEquals "Should have no output." "" "${output}"
}

function test_validate_commands_with_non_existent_command_returns_error_and_reports_failing_command() {
  local stderr error
  local command="non_existent_command_df3498jsdf"
  stderr=$(_validate_commands "${command}" 2>&1); error=$?

  assertEquals "Should fail." 1 "${error}"
  assertContains "Should output failing command's name." "${stderr}" "${command}"
}

###############################################################################
# _exit_1
###############################################################################

function test_exit_1_returns_error_with_echo() {
  local stderr error
  local error_message1="An error message"
  local error_message2="Another error message"

  # no message
  stderr=$(_exit_1 echo 2>&1); error=$?
  assertEquals "Should fail." 1 "${error}"

  # one message
  stderr=$(_exit_1 echo "${error_message1}" 2>&1); error=$?
  assertEquals "Should fail." 1 "${error}"
  assertContains "Should print single message." "${stderr}" "${error_message1}"

  # two messages
  stderr=$(_exit_1 echo "${error_message1}" "${error_message2}" 2>&1); error=$?
  assertEquals "Should fail." 1 "${error}"
  assertContains "Should print first message." "${stderr}" "${error_message1}"
  assertContains "Should print second message." "${stderr}" "${error_message2}"
}

function test_exit_1_returns_error_with_printf() {
  local stderr error
  local error_message1="An error message"
  local error_message2="Another error message"

  # no message
  stderr=$(_exit_1 printf "" 2>&1); error=$?
  assertEquals "Should fail." 1 "${error}"

  # one message
  stderr=$(_exit_1 printf "%s" "${error_message1}" 2>&1); error=$?
  assertEquals "Should fail." 1 "${error}"
  assertContains "Should print single message." "${stderr}" "${error_message1}"

  # two messages
  stderr=$(_exit_1 printf "%s %s" "${error_message1}" "${error_message2}" 2>&1); error=$?
  assertEquals "Should fail." 1 "${error}"
  assertContains "Should print first message." "${stderr}" "${error_message1}"
  assertContains "Should print second message." "${stderr}" "${error_message2}"
}

function test_exit_1_returns_error_with_cat() {
  local stderr error
  local error_message1="An error message"
  local error_message2="Another error message"

  # one file
  stderr=$(_exit_1 cat <(echo "${error_message1}") 2>&1); error=$?
  assertEquals "Should fail." 1 "${error}"
  assertContains "Should print single message." "${stderr}" "${error_message1}"

  # two files
  stderr=$(_exit_1 cat <(echo "${error_message1}") <(echo "${error_message2}") 2>&1); error=$?
  assertEquals "Should fail." 1 "${error}"
  assertContains "Should print first message." "${stderr}" "${error_message1}"
  assertContains "Should print second message." "${stderr}" "${error_message2}"
}

function test_exit_1_returns_error_with_no_command() {
  local stderr error

  stderr=$(_exit_1 2>&1); error=$?
  assertEquals "Should fail." 1 "${error}"
}

###############################################################################
# _start_timeout_process
###############################################################################

function test_start_timeout_process_with_positive_integer_creates_new_process() {
  local error timeout_duration ps_error
  timeout_duration=1

  __timeout_pid=-1

  _start_timeout_process "${timeout_duration}"; error=$?

  ps -p "${__timeout_pid}" &>/dev/null; ps_error=$?

  assertEquals "Should succeed." 0 "${error}"
  assertNotEquals "Should set __timeout_pid." -1 "${__timeout_pid}"
  assertEquals "Timeout process should be running." 0 "${ps_error}"

  _stop_timeout_process
}

function test_start_timeout_process_with_zero_does_not_create_new_process() {
  local error timeout_duration
  timeout_duration=0

  __timeout_pid=-1

  _start_timeout_process "${timeout_duration}"; error=$?

  assertEquals "Should succeed." 0 "${error}"
  assertEquals "Should not set __timeout_pid." -1 "${__timeout_pid}"
}

###############################################################################
# _stop_timeout_process
###############################################################################

function test_stop_timeout_process_kills_the_timeout_process() {
  local error timeout_duration ps_error __timeout_pid_store
  timeout_duration=1

  __timeout_pid=-1

  _start_timeout_process "${timeout_duration}"; error=$?

  ps -p "${__timeout_pid}" &>/dev/null; ps_error=$?

  # verify setup
  assertEquals "Should succeed." 0 "${error}"
  assertNotEquals "Should set __timeout_pid." -1 "${__timeout_pid}"
  assertEquals "Timeout process should be running." 0 "${ps_error}"

  # prepare the test
  __timeout_pid_store="${__timeout_pid}"
  _stop_timeout_process; error=$?

  ps -p "${__timeout_pid}" &>/dev/null; ps_error=$?

  # run the test
  assertEquals "Should succeed." 0 "${error}"
  assertEquals "Should reset __timeout_pid." -1 "${__timeout_pid}"
  assertEquals "Timeout process should not be running." 1 "${ps_error}"
}

###############################################################################
# is_unsigned_integer
###############################################################################

function test_is_unsigned_integer() {
  local error value

  # expect success
  value=0
  is_unsigned_integer "${value}"; error=$?
  assertEquals "${value} should succeed." 0 "${error}"

  value=1
  is_unsigned_integer "${value}"; error=$?
  assertEquals "${value} should succeed." 0 "${error}"

  value=10
  is_unsigned_integer "${value}"; error=$?
  assertEquals "${value} should succeed." 0 "${error}"

  value=9999999999999
  is_unsigned_integer "${value}"; error=$?
  assertEquals "${value} should succeed." 0 "${error}"

  # expect error
  value=1.0
  is_unsigned_integer "${value}"; error=$?
  assertEquals "${value} should fail." 1 "${error}"

  value=-1
  is_unsigned_integer "${value}"; error=$?
  assertEquals "${value} should fail." 1 "${error}"

  value=-1.0
  is_unsigned_integer "${value}"; error=$?
  assertEquals "${value} should fail." 1 "${error}"

  value="e"
  is_unsigned_integer "${value}"; error=$?
  assertEquals "${value} should fail." 1 "${error}"

  value="-"
  is_unsigned_integer "${value}"; error=$?
  assertEquals "${value} should fail." 1 "${error}"

  value=""
  is_unsigned_integer "${value}"; error=$?
  assertEquals "Empty string should fail." 1 "${error}"
}

###############################################################################
# is_unsigned_decimal
###############################################################################

function test_is_unsigned_decimal() {
  local error value

  # expect success
  value="0.0"
  is_unsigned_decimal "${value}"; error=$?
  assertEquals "${value} should succeed." 0 "${error}"
  
  value="0.1"
  is_unsigned_decimal "${value}"; error=$?
  assertEquals "${value} should succeed." 0 "${error}"

  value="1.0"
  is_unsigned_decimal "${value}"; error=$?
  assertEquals "${value} should succeed." 0 "${error}"

  value="10.0"
  is_unsigned_decimal "${value}"; error=$?
  assertEquals "${value} should succeed." 0 "${error}"

  value="10.01"
  is_unsigned_decimal "${value}"; error=$?
  assertEquals "${value} should succeed." 0 "${error}"

  value="9999999999999.9999999999999"
  is_unsigned_decimal "${value}"; error=$?
  assertEquals "${value} should succeed." 0 "${error}"

  # expect error
  value=0
  is_unsigned_decimal "${value}"; error=$?
  assertEquals "${value} should fail." 1 "${error}"

  value=1
  is_unsigned_decimal "${value}"; error=$?
  assertEquals "${value} should fail." 1 "${error}"

  value=-1
  is_unsigned_decimal "${value}"; error=$?
  assertEquals "${value} should fail." 1 "${error}"

  value=-0.0
  is_unsigned_decimal "${value}"; error=$?
  assertEquals "${value} should fail." 1 "${error}"

  value=-0.1
  is_unsigned_decimal "${value}"; error=$?
  assertEquals "${value} should fail." 1 "${error}"

  value="e"
  is_unsigned_decimal "${value}"; error=$?
  assertEquals "${value} should fail." 1 "${error}"

  value="-"
  is_unsigned_decimal "${value}"; error=$?
  assertEquals "${value} should fail." 1 "${error}"

  value=""
  is_unsigned_decimal "${value}"; error=$?
  assertEquals "Empty string should fail." 1 "${error}"
}

###############################################################################
# is_semantic_version
###############################################################################

function test_is_semantic_version() {
  local error value

  # expect success
  value="0.0.0"
  is_semantic_version "${value}"; error=$?
  assertEquals "${value} should succeed." 0 "${error}"
  
  value="1.0.0"
  is_semantic_version "${value}"; error=$?
  assertEquals "${value} should succeed." 0 "${error}"

  value="0.1.0"
  is_semantic_version "${value}"; error=$?
  assertEquals "${value} should succeed." 0 "${error}"

  value="0.0.1"
  is_semantic_version "${value}"; error=$?
  assertEquals "${value} should succeed." 0 "${error}"

  value="10.0.0"
  is_semantic_version "${value}"; error=$?
  assertEquals "${value} should succeed." 0 "${error}"

  value="0.10.0"
  is_semantic_version "${value}"; error=$?
  assertEquals "${value} should succeed." 0 "${error}"

  value="0.0.10"
  is_semantic_version "${value}"; error=$?
  assertEquals "${value} should succeed." 0 "${error}"

  value="9999999999999.9999999999999.9999999999999"
  is_semantic_version "${value}"; error=$?
  assertEquals "${value} should succeed." 0 "${error}"

  # expect error
  value=0
  is_semantic_version "${value}"; error=$?
  assertEquals "${value} should fail." 1 "${error}"

  value=1
  is_semantic_version "${value}"; error=$?
  assertEquals "${value} should fail." 1 "${error}"

  value=-1
  is_semantic_version "${value}"; error=$?
  assertEquals "${value} should fail." 1 "${error}"

  value=0.0
  is_semantic_version "${value}"; error=$?
  assertEquals "${value} should fail." 1 "${error}"

  value=0.1
  is_semantic_version "${value}"; error=$?
  assertEquals "${value} should fail." 1 "${error}"

  value=-0.0.0
  is_semantic_version "${value}"; error=$?
  assertEquals "${value} should fail." 1 "${error}"

  value=0.-0.0
  is_semantic_version "${value}"; error=$?
  assertEquals "${value} should fail." 1 "${error}"

  value=-0.0.-0
  is_semantic_version "${value}"; error=$?
  assertEquals "${value} should fail." 1 "${error}"

  value="e"
  is_semantic_version "${value}"; error=$?
  assertEquals "${value} should fail." 1 "${error}"

  value="-"
  is_semantic_version "${value}"; error=$?
  assertEquals "${value} should fail." 1 "${error}"

  value=""
  is_semantic_version "${value}"; error=$?
  assertEquals "Empty string should fail." 1 "${error}"
}

###############################################################################
# is_alphanumeric_underscore_dot_dash
###############################################################################

function test_is_alphanumeric_underscore_dot_dash() {
  local error value

  # expect success
  value=0
  is_alphanumeric_underscore_dot_dash "${value}"; error=$?
  assertEquals "${value} should succeed." 0 "${error}"

  value="0"
  is_alphanumeric_underscore_dot_dash "${value}"; error=$?
  assertEquals "${value} should succeed." 0 "${error}"

  value="a"
  is_alphanumeric_underscore_dot_dash "${value}"; error=$?
  assertEquals "${value} should succeed." 0 "${error}"

  value="_a"
  is_alphanumeric_underscore_dot_dash "${value}"; error=$?
  assertEquals "${value} should succeed." 0 "${error}"

  value="a_"
  is_alphanumeric_underscore_dot_dash "${value}"; error=$?
  assertEquals "${value} should succeed." 0 "${error}"

  value="a_a"
  is_alphanumeric_underscore_dot_dash "${value}"; error=$?
  assertEquals "${value} should succeed." 0 "${error}"

  value=".a"
  is_alphanumeric_underscore_dot_dash "${value}"; error=$?
  assertEquals "${value} should succeed." 0 "${error}"

  value="a."
  is_alphanumeric_underscore_dot_dash "${value}"; error=$?
  assertEquals "${value} should succeed." 0 "${error}"

  value="a.a"
  is_alphanumeric_underscore_dot_dash "${value}"; error=$?
  assertEquals "${value} should succeed." 0 "${error}"

  value="-a"
  is_alphanumeric_underscore_dot_dash "${value}"; error=$?
  assertEquals "${value} should succeed." 0 "${error}"

  value="a-"
  is_alphanumeric_underscore_dot_dash "${value}"; error=$?
  assertEquals "${value} should succeed." 0 "${error}"

  value="a-a"
  is_alphanumeric_underscore_dot_dash "${value}"; error=$?
  assertEquals "${value} should succeed." 0 "${error}"

  value="_.-"
  is_alphanumeric_underscore_dot_dash "${value}"; error=$?
  assertEquals "${value} should succeed." 0 "${error}"

  value="_.-abcABC012_.-abcABC012_.-abcABC012_.-abcABC012_.-abcABC012"
  is_alphanumeric_underscore_dot_dash "${value}"; error=$?
  assertEquals "${value} should succeed." 0 "${error}"

  # expect error
  value="!"
  is_alphanumeric_underscore_dot_dash "${value}"; error=$?
  assertEquals "${value} should fail." 1 "${error}"

  value="?"
  is_alphanumeric_underscore_dot_dash "${value}"; error=$?
  assertEquals "${value} should fail." 1 "${error}"

  value="a?"
  is_alphanumeric_underscore_dot_dash "${value}"; error=$?
  assertEquals "${value} should fail." 1 "${error}"

  value=" "
  is_alphanumeric_underscore_dot_dash "${value}"; error=$?
  assertEquals "Space should fail." 1 "${error}"
  
  value='\n'
  is_alphanumeric_underscore_dot_dash "${value}"; error=$?
  assertEquals "Newline should fail." 1 "${error}"

  value='\t'
  is_alphanumeric_underscore_dot_dash "${value}"; error=$?
  assertEquals "Tab should fail." 1 "${error}"

  value=""
  is_alphanumeric_underscore_dot_dash "${value}"; error=$?
  assertEquals "Empty string should fail." 1 "${error}"
}

###############################################################################
# _split_short_options
###############################################################################

function test_split_short_options() {
  local stdout error input expected

  # single short option
  input="-a"
  expected="-a"
  stdout=$(_split_short_options "${input}"); error=$?
  assertEquals "-a should succeed." 0 "${error}"
  assertEquals "-a should be unchanged." "${expected[@]}" "${stdout}"

  # grouped short options
  input="-abcd"
  expected="-a
-b
-c
-d"
  stdout=$(_split_short_options "${input}"); error=$?
  assertEquals "-abcd should succeed." 0 "${error}"
  assertEquals "-abcd should be split." "${expected[@]}" "${stdout}"

  # single short option with value
  input="-a=78"
  expected="-a
78"
  stdout=$(_split_short_options "${input}"); error=$?
  assertEquals "-a=78 should succeed." 0 "${error}"
  assertEquals "-a=78 should be split." "${expected[@]}" "${stdout}"

  #single short option with complex value
  input="-a=78=abc,deg"
  expected="-a
78=abc,deg"
  stdout=$(_split_short_options "${input}"); error=$?
  assertEquals "-a=78=abc,deg should succeed." 0 "${error}"
  assertEquals "-a=78=abc,deg should be split." "${expected[@]}" "${stdout}"

  # grouped short options with complex value
  input="-abc=78=abc,deg"
  expected="-a
-b
-c
78=abc,deg"
  stdout=$(_split_short_options "${input}"); error=$?
  assertEquals "-abc=78=abc,deg should succeed." 0 "${error}"
  assertEquals "-abc=78=abc,deg should be split." "${expected[@]}" "${stdout}"
}

###############################################################################
# _split_long_options
###############################################################################

function test_split_long_options() {
  local stdout error input expected

  # no value
  input="--long"
  expected="--long"
  stdout=$(_split_long_options "${input}"); error=$?
  assertEquals "--long should succeed." 0 "${error}"
  assertEquals "--long should be unchanged." "${expected[@]}" "${stdout}"

  # complex value
  input="--long=78=abc,deg"
  expected="--long
78=abc,deg"
  stdout=$(_split_long_options "${input}"); error=$?
  assertEquals "--long=78=abc,deg should succeed." 0 "${error}"
  assertEquals "--long=78=abc,deg should be split." "${expected[@]}" "${stdout}"
}

###############################################################################
# _split_options
###############################################################################

function test_split_options() {
  local stdout error input expected

  input=("arg1" "-abcd" "-efgh=d=4" "arg2" "--long1" "arg3" "--long2=val" "--long3=g=7" "arg4")
  expected="arg1
-a
-b
-c
-d
-e
-f
-g
-h
d=4
arg2
--long1
arg3
--long2
val
--long3
g=7
arg4"

  _split_options "${input[@]}"; error=$?

  printf -v _args_stringified "%s\n" "${_args[@]}"
  _args_stringified="${_args_stringified::-1}"

  assertEquals "Should succeed." 0 "${error}"
  assertEquals "Should split options." "${expected}" "${_args_stringified}"
}

###############################################################################
# __get_option_value
###############################################################################

function test_get_option_value() {
  local stdout stderr error option value

  # expect success
  option="-a"; value="1"
  stdout=$(__get_option_value "${option}" "${value}"); error=$?
  assertEquals "-a and 1 should succeed." 0 "${error}"
  assertEquals "Should return 1." "${value}" "${stdout}"

  option="-a"; value="d=14"
  stdout=$(__get_option_value "${option}" "${value}"); error=$?
  assertEquals "-a and d=14 should succeed." 0 "${error}"
  assertEquals "Should return d=14." "${value}" "${stdout}"

  # expect error
  option="-a"; value=""
  stderr=$(__get_option_value "${option}" "${value}" 2>&1); error=$?
  assertEquals "-a and empty string should fail." 1 "${error}"
  assertContains "Error message should mention failing option name." "${stderr}" "${option}"
}

###############################################################################
# _parse_common_options
###############################################################################

function test_parse_common_options_help_option_calls_usage() {
  local stdout error

  stdout=$(_parse_common_options "--help"); error=$?

  assertEquals "Should succeed." 0 "${error}"
  assertEquals "Should call usage." "${__usage_stub_string}" "${stdout}"
}

function test_parse_common_options_version_option_returns_versions() {
  local stdout error

  stdout=$(_parse_common_options "-V"); error=$?

  assertEquals "Should succeed." 0 "${error}"
  assertContains "Should see text from script." "${stdout}" "${_script_version}"
  assertContains "Should see text from boilerplate." "${stdout}" "${__boilerplate_version:?}"
}

function test_parse_common_options__verbose_option_sets__verbose_option_flag() {
  local error expected_args

  __verbose_option=0

  expected_args=""

  _parse_common_options "-v"; error=$?

  printf -v _args_stringified "%s\n" "${_args[@]}"
  _args_stringified="${_args_stringified::-1}"

  assertEquals "Should succeed." 0 "${error}"
  assertEquals "Should set __verbose_option." 1 "${__verbose_option}"
  assertEquals "Should replace -v with empty string in arguments array." "${expected_args}" "${_args_stringified}"
}

function test_parse_common_options__debug_option_sets__debug_option_flag() {
  local stdout error expected_args

  __debug_option=0

  expected_args=""

  _parse_common_options "--debug"; error=$?

  printf -v _args_stringified "%s\n" "${_args[@]}"
  _args_stringified="${_args_stringified::-1}"

  assertEquals "Should succeed." 0 "${error}"
  assertEquals "Should set __debug_option." 1 "${__debug_option}"
  assertEquals "Should replace --debug with empty string in arguments array." "${expected_args}" "${_args_stringified}"
}

function test_parse_common_options_endopts_terminates_parsing() {
  local stdout error expected_args

  __verbose_option=0
  __debug_option=0

  expected_args="arg1"

  _parse_common_options "arg1" "--endopts" "--verbose" "--debug" "arg2"; error=$?

  printf -v _args_stringified "%s\n" "${_args[@]}"
  _args_stringified="${_args_stringified::-1}"

  assertEquals "Should succeed." 0 "${error}"
  assertEquals "Should set __verbose_option." 0 "${__verbose_option}"
  assertEquals "Should set __debug_option." 0 "${__debug_option}"
  assertEquals "Should remove --endopts and trailing arguments from arguments array." "${expected_args}" "${_args_stringified}"
}

# shellcheck disable=SC1091
source shunit2
