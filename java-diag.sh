#!/usr/bin/env bash
#
# This file is part of the java-diag (https://github.com/pes-soft/java-diag).
# Copyright (c) 2017 Peter 'Pessoft' Kolínek.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#

# functions

usage() {
  echo
  echo "  Java Diag 0.2 - Java Application Diagnostic Helper Script"
  echo "   Bug reports, feature requests and downloads at https://github.com/pes-soft/java-diag"
  echo "   Author: Pessoft (dev@pessoft.com) - Licensed under GPLv3"
  echo
  echo "  Initial information:"
  echo "    Purpose of this helper script is to assist with collection of information"
  echo "    about running Java process, which could help to identify the reason for some"
  echo "    unexpected behavior. Such behavior is usually non-responding application or"
  echo "    application with high load on resources in time periods of no usage. One of"
  echo "    the main features of the script is the sending of signal 3 (SIGQUIT) to"
  echo "    a Java process (this invokes thread dump) and collection of the thread dump"
  echo "    from a log file. Additionally some other system information is collected too"
  echo "    (network connecitons, open files) and active threads are picked out from"
  echo "    the thread dump with their stack trace included. Because this script was at"
  echo "    first done primarily for applications running on Tomcat with OpenJDK and"
  echo "    OracleJDK, currently only Tomcat profile is available and only OpenJDK and"
  echo "    OracleJDK has been tested. Using the options however makes it possible to"
  echo "    fit the configuration of other Java applications as well."
  echo
  echo "  Options:"
  echo "    --profile=<PROFILE>     Sets defaults for selected options. See Profiles"
  echo "                            section below. (default: None)"
  echo "    --command=<COMMAND>     COMMAND to look for in process names, uses"
  echo "                            awk regexp match (default: java\$)"
  echo "    --argument=<ARGUMENT>   ARGUMENT to look for in process command line, uses"
  echo "                            awk regexp match (default: None)"
  echo "    --log-file=<FILEPATH>   Path to the logfile, where thread dumps are saved."
  echo "                            If set to $journaltag then journal will be searched."
  echo "                            (default: None)"
  echo "    --report-dir=<DIRPATH>  Reports will be saved in timestamped directories"
  echo "                            under DIRPATH (default: '.' current directory)"
  echo "    --username=<USERNAME>   USERNAME under which the process runs, must be exact"
  echo "                            match (default: None, all users are matched)"
  echo "    --use-kill              If set, processed PID will receive signal 3"
  echo "                            (SIGQUIT). This causes Java VM to generate thread"
  echo "                            dump, but for other processes this can result in"
  echo "                            termination. Therefore this feature needs to be"
  echo "                            individually allowed. Use with caution."
  echo "                            (default: Unset, no process will receive the signal)"
  echo "    --multi-pid             If set, allows script to diagnose multiple PIDs,"
  echo "                            (default: Unset, multiple PIDs cause error)"
  echo "    --ps-all                If set, gets list of all processes, even if USERNAME"
  echo "                            is set (default: Unset, gets processes for USERNAME)"
  echo "    --lsof-all              If set, tries to get all open files. This might take"
  echo "                            some time (default: Unset, gets open files per PID)"
  echo "    --debug                 Increase logging of the script"
  echo "    --version, --usage, --help, -v"
  echo "                            Shows this information"
  echo
  echo "  Profiles:"
  echo "    tomcat      Sets defaults which expect start of the script from Tomcat's log"
  echo "                directory."
  echo "                command:  java\$"
  echo "                argument: Dcatalina.base=CWDPARENT"
  echo "                log-file: CWDPARENT/logs/catalina.out)"
  echo "    glassfish   Not available"
  echo "    wildfly     Not available"
  echo
  echo "    CWDPARENT is the parent of the current working directory, now:"
  echo "    '$cwd_parent'"
  echo
}

parse_args() {
  local arg
  arg="$1"
  while [ -n "$arg" ]; do
    case "$arg" in
      '--profile='*)
        cfg_profile="${arg#*=}"
        ;;
      '--command='*)
        cfg_command="${arg#*=}"
        ;;
      '--argument='*)
        cfg_argument="${arg#*=}"
        ;;
      '--log-file='*)
        cfg_log_file="${arg#*=}"
        ;;
      '--report-dir='*)
        cfg_reports_dir="${arg#*=}"
        ;;
      '--username='*)
        cfg_username="${arg#*=}"
        ;;
      '--multi-pid')
        cfg_multi_pid=1
        ;;
      '--ps-all')
        cfg_ps_all=1
        ;;
      '--lsof-all')
        cfg_lsof_all=1
        ;;
      '--use-kill')
        cfg_use_kill=1
        ;;
      '--debug')
        cfg_debug=1
        ;;
      '-v'|'--help'|'--version'|'--usage'|'-v')
        usage
        exit 1
        ;;
      *)
        echo "ERROR: Unknown argument '$arg'" >&2
        usage
        exit 1
    esac
    shift
    arg="$1"
  done
}

log() {
  local level
  level="$1"
  shift
  if [ "$level" = "ERROR" ]; then
    echo "[java-diag] ($(date -Iseconds)) $level: $*" >&2
  elif [ "$level" = "DEBUG" ] && [ "$cfg_debug" != "1" ]; then
    return
  else
    echo "[java-diag] ($(date -Iseconds)) $level: $*"
  fi
}

get_system_processes() {
  local user
  user="$1"
  if [ -z "$user" ]; then
    ps -o "$proc_attributes" -LA
  else
    ps -o "$proc_attributes" -Lu"$user"
  fi
  return $?
}

get_pids_filtered() {
  local file cmd arg user
  file="$1"
  cmd="$2"
  arg="$3"
  user="$4"
  awk "
  ( \"$cmd\" == \"\" || \$10 ~ \"$cmd\" ) && \
  ( \"$user\" == \"\" || \$1 == \"$user\" ) && \
  ( \"$arg\" == \"\" || \$0 ~ \"$arg\" ) \
      { pids[\$2] = 1 }
  END { for (pid in pids) print pid }
  " "$file"
  return $?
}

get_threads_by_pid() {
  local file pid
  file="$1"
  pid="$2"
  awk "( \"$pid\" == \"\" || \$2 == \"$pid\" ) { print \$0 }" "$file"
  return $?
}

get_threads_by_tid() {
  local file tid
  file="$1"
  tid="$2"
  awk "( \"$tid\" == \"\" || \$4 == \"$tid\" ) { print \$0 }" "$file"
  return $?
}

get_threads_running() {
  local file stat
  file="$1"
  stat="R"
  awk "( \$8 ~ \"$stat\" ) { print \$0 }" "$file"
  return $?
}

get_threads_active() {
  local file cpuperc
  file="$1"
  cpuperc="0.0"
  awk "( \$5 != \"$cpuperc\") { print \$0 }" "$file"
  return $?
}

get_tids() {
  local file
  file="$1"
  while [ -n "$file" ]; do
    shift
    awk "{ tids[\$4] = 1 } END { for (tid in tids) print tid }" "$file"
    file="$1"
  done
  return $?
}

get_system_netstats() {
  netstat -nopee 2>/dev/null
  return $?
}

get_ip_connections_by_pid() {
  local file pid
  file="$1"
  pid="$2"
  awk "( \$1 ~ \"^tcp\" || \$1 ~ \"^udp\" ) && \
    ( \"$pid\" == \"\" || \$9 ~ \"^$pid/\" ) \
      { print \$0 }" "$file"
  return $?
}

get_system_openfiles() {
  local pid ret
  pid="$1"
  if [ -z "$lsof_bin" ]; then
    ret=1
    log "WARNING" "'lsof' command not found"
    if [ -n "$pid" ] && [ -d "/proc/$pid/fd" ]; then
      log "INFO" "Getting open files from proc fs instead"
      ls -l "/proc/$pid/fd"
      ret=$?
    fi
  else
    [ -n "$lsof_bin" ] && "$lsof_bin" -b -w ${pid:+-p "$pid"}
    ret=$?
  fi
  return $ret
}

get_log_td_lines() {
  local file pid
  file="$1"
  if [ "${file%%:*}" = "$journaltag" ]; then
    pid=${file#*:}
    journalctl --output=cat --quiet --since "$start_today" _PID="$pid" | \
      grep -n -E "^($td_header_start)" | sed s/':.*'//
  else
    grep -n -E "^($td_header_start)" "$file" | sed s/':.*'//
  fi
  return $?
}

get_log_line_count() {
  local file pid
  file="$1"
  if [ "${file%%:*}" = "$journaltag" ]; then
    pid=${file#*:}
    journalctl --output=cat --quiet --since "$start_today" _PID="$pid" | \
      wc -l | awk ' { print $1 } '
  else
    wc -l "$file" | awk ' { print $1 } '
  fi
  return $?
}

get_log_part() {
  local file pid lstart lnum
  file="$1"
  lstart="$2"
  lnum="$3"
  if [ "${file%%:*}" = "$journaltag" ]; then
    pid=${file#*:}
    journalctl --output=cat --quiet --since "$start_today" _PID="$pid" | \
      tail -n +"$lstart" | head -n "$lnum"
  else
    tail -n +"$lstart" "$file" | head -n "$lnum"
  fi
  return $?
}

get_td_new() {
  local file pid
  file="$1"
  pid="$2"
  if [ "$file" = "$journaltag" ]; then
    file="$file:$pid"
  fi
  log "DEBUG" "Getting list of existing thread dumps from '$file'"
  java_tds_last=$(get_log_td_lines "$file")
  log "DEBUG" "Sending signal 3 to PID '$pid'"
  kill -3 "$pid"
  retry=16
  while [ $retry -gt 0 ]; do
    log "DEBUG" "Getting list of new thread dumps from '$file'"
    java_tds_new=$(get_log_td_lines "$file")
    if [ "$java_tds_new" != "$java_tds_last" ]; then
      sleep 1
      java_log_lines=$(get_log_line_count "$file")
      java_td_line=$(echo "$java_tds_new" | tail -n1)
      log "DEBUG" "New thread dump found in '$file' on line '$java_td_line'"
      java_td_lines=$((java_log_lines - java_td_line))
      get_log_part "$file" "$java_td_line" "$java_td_lines" > "$report_root/java_pid-${process_pid}_td"
      return $?
    fi
    sleep 2
  done
  return 2
}

get_thread_from_td() {
  local file tid
  file="$1"
  tid="$2"
  tid=$(printf "0x%x" "$tid")
  awk " {
    if ( \$0 ~ \" nid=0x\" ) prn=0;
    if ( tolower(\$0) ~ tolower(\" nid=$tid \") ) prn=1;
    if (prn == 1) print \$0;
  } " "$file"
  return $?
}

set_profile() {
  local profile cmd arg log dir
  profile="$1"
  case "$profile" in
    'tomcat')
      cmd="java\$"
      arg="Dcatalina.base=$cwd_parent"
      log="$cwd_parent/logs/catalina.out"
      dir="$cwd_parent/logs"
      ;;
    *)
      log "ERROR" "Unknown profile '$profile'"
      exit 1
  esac
  log "INFO" "Setting profile '$profile'"
  [ -z "$cfg_command" ] && cfg_command="$cmd"
  [ -z "$cfg_argument" ] && cfg_argument="$arg"
  [ -z "$cfg_log_file" ] && cfg_log_file="$log"
  [ -z "$cfg_reports_dir" ] && cfg_reports_dir="$dir"
}

# main

cwd_parent=$(dirname "$(pwd)")
proc_attributes="user:16,pid,ppid,tid,%cpu,%mem,time,stat,start,command"
td_header_start="Full thread dump"
start_today=$(date +%Y-%m-%d)
journaltag="__journal__"

# arguments
parse_args "$@"

# profiles
[ -n "$cfg_profile" ] && set_profile "$cfg_profile"

# defaults
[ -z "$cfg_command" ] && cfg_command="java\$"
[ -z "$cfg_reports_dir" ] && cfg_reports_dir="."
report_root="$cfg_reports_dir/java-diag-$(date -Iseconds)-$$"
lsof_bin=$(which lsof)

# checks
[ -z "$cfg_log_file" ] && { log "ERROR" "No log file set, use --help option"; exit 2; }
[ "$cfg_log_file" = "$journaltag" ] || {
  [ -r "$cfg_log_file" ] || { log "ERROR" "Cannot read log file '$cfg_log_file'"; exit 2; }
}
[ -d "$cfg_reports_dir" ] || { log "ERROR" "Cannot find reports directory '$cfg_reports_dir'"; exit 2; }
mkdir "$report_root"
[ -d "$report_root" ] || { log "ERROR" "Cannot create report root '$report_root'"; exit 2; }

[ "$cfg_ps_all" = "1" ] || [ -z "$cfg_username" ] && {
  log "INFO" "Getting all system processes"
  get_system_processes > "$report_root/sys_procs"
  src_procs="sys_procs"
}

[ -n "$cfg_username" ] && {
  log "INFO" "Getting system processes of '$cfg_username'"
  get_system_processes "$cfg_username" > "$report_root/sys_user-${cfg_username}_procs"
  src_procs="sys_user-${cfg_username}_procs"
}

log "INFO" "Getting network statistics"
get_system_netstats > "$report_root/sys_netstat"

[ "$cfg_lsof_all" = "1" ] && {
  log "INFO" "Getting all open files"
  get_system_openfiles > "$report_root/sys_openfiles"
}

log "DEBUG" "Parsing PIDs from processes"
process_pids=( $(get_pids_filtered "$report_root/$src_procs" "$cfg_command" "$cfg_argument") )
process_pids_num=${#process_pids[@]}

if [ "$process_pids_num" = "1" ]; then
  log "INFO" "PID found [${process_pids[*]}]"
elif [ "$process_pids_num" = "0" ]; then
  log "ERROR" "No matching PID found, exiting"
  log "INFO" "Make sure the application is running and selection criteria has been set"
  exit 3
else
    log "WARNING" "Multiple [$process_pids_num] PIDs found [${process_pids[*]}]"
    [ "$cfg_multi_pid" = "1" ] || {
      log "ERROR" "Diagnosing multiple PIDs is not allowed by default, exiting"
      log "INFO" "Try to narrow down the selection criteria or use --multi-pid option"
      exit 5
    }
fi

for process_pid in "${process_pids[@]}"; do
  log "INFO" "Getting open files for PID '$process_pid'"
  get_system_openfiles "$process_pid" > "$report_root/process_pid-${process_pid}_openfiles"
  log "INFO" "Getting IP connections for PID '$process_pid'"
  get_ip_connections_by_pid "$report_root/sys_netstat" "$process_pid" > "$report_root/process_pid-${process_pid}_ipconnections"
  log "INFO" "Getting threads for PID '$process_pid'"
  get_threads_by_pid "$report_root/$src_procs" "$process_pid" > "$report_root/process_pid-${process_pid}_threads"
  get_threads_running "$report_root/process_pid-${process_pid}_threads" > "$report_root/process_pid-${process_pid}_running_threads"
  get_threads_active "$report_root/process_pid-${process_pid}_threads" > "$report_root/process_pid-${process_pid}_busy_threads"

  if [ "$cfg_use_kill" = "1" ]; then
    log "INFO" "Sending signal to PID '$process_pid' and getting thread dump from log file '$cfg_log_file'"
    get_td_new "$cfg_log_file" "$process_pid"
    ret=$?
    if [ $ret -eq 0 ]; then
      log "INFO" "Getting suspicious threads for PID '$process_pid'"
      echo > "$report_root/java_pid-${process_pid}_suspicious_threads"
      for tid in $(get_tids "$report_root/process_pid-${process_pid}_running_threads" "$report_root/process_pid-${process_pid}_busy_threads"); do
        {
          head -n1 "$report_root/$src_procs"
          get_threads_by_tid "$report_root/process_pid-${process_pid}_threads" "$tid"
          get_thread_from_td "$report_root/java_pid-${process_pid}_td" "$tid"
          echo >> "$report_root/java_pid-${process_pid}_suspicious_threads"
        } >> "$report_root/java_pid-${process_pid}_suspicious_threads"
      done
    else
      log "WARNING" "Thread dump has been not retrieved [$ret]"
    fi
  else
    log "INFO" "Sending signal to process not allowed by options, no thread dump will be retrieved"
    log "INFO" "If PID of java process has been found, use --use-kill option to get thread dump"
  fi
done
