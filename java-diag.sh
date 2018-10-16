#!/usr/bin/env bash
#
# This file is part of the java-diag (https://github.com/pes-soft/java-diag).
# Copyright (c) 2018 Peter 'Pessoft' Kolínek.
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
  [ "$1" = "full" ] && isUsageFullEnabled=true || isUsageFullEnabled=false
  echo
    echo "  Java Diag 0.4 - Java Application Diagnostic Helper Script"
    if $isUsageFullEnabled; then
    echo "    Home site, bug reports, feature requests, feedback and downloads at:"
    echo "    https://github.com/pes-soft/java-diag"
    echo "    Author: Peter 'Pessoft' Kolínek (dev@pessoft.com) - Licensed under GPLv3"
    echo
    echo "  Initial information:"
    echo "    Purpose of this helper script is to assist with collection of information"
    echo "    about running Java process, which could help to identify the reason for some"
    echo "    unexpected behavior. Such behavior is usually non-responding application or"
    echo "    application with high load on resources during time period of no usage."
    echo "    Basic operation of the script is requesting a thread dump from Java process,"
    echo "    either by sending it a signal 3 (SIGQUIT) and collecting of the thread dump"
    echo "    output from a log file or by executing a jstack with pid of the Java"
    echo "    process. Additionally some other system information is collected too in"
    echo "    the process (network connections, open files, ...) and active threads are"
    echo "    picked out from the thread dump with their stack trace included."
    echo "    Because this script was created primarily for assistance with JIRA and"
    echo "    Confluence applications running on Tomcat with OpenJDK or Oracle JDK Java,"
    echo "    only such configurations have been tested and by using different setup YMMV."
    echo "    Using the various options however makes it possible to diagnose other Java"
    echo "    applications too."
  else
    echo
    echo "  For full help and usage information use --help option."
    echo
  fi
  echo "  Options:"
  echo "    --help                  Shows full help and usage information"
  echo "    --profile=<PROFILE>     Sets defaults for selected options. See Profiles"
  echo "                            section in full help. (default: None)"
  echo "    --pid=<PID>             PID of diagnosed Java application. (default: None)"
  echo "    --command=<COMMAND>     COMMAND to look for in process names, uses"
  echo "                            awk regexp match (default: java\$)"
  echo "    --class=<CLASS>         CLASS to look for in Jps class names, uses"
  echo "                            awk regexp match (default: None)"
  echo "    --argument=<ARGUMENT>   ARGUMENT to look for in process command line, uses"
  echo "                            awk regexp match (default: None)"
  echo "    --td-source=<TDSRC>     TDSRC is either path to the log file, where thread"
  echo "                            dumps are saved on Java process signal - usually"
  echo "                            where standard output of Java process is redirected."
  echo "                            Or it is a special tag by which thread dump can be"
  echo "                            obtained:"
  echo "                              $journaltag - system journal extraction"
  echo "                            (default: None)"
  echo "    --report-dir=<DIRPATH>  Reports will be saved in timestamped directories"
  echo "                            under DIRPATH (default: '.' current directory)"
  echo "    --td-modes=<TDMODES>    TDMODES is a comma separated list of thread dump"
  echo "                            modes in preferred order, which will be executed"
  echo "                            to obtain the thread dump. Possible values are:"
  echo "                            jstack, jstackforce, kill."
  echo "                            Kill must be additionally allowed by --use-kill."
  echo "                            Forced jstack can cause Java application to become"
  echo "                            unresponsive until the thread dump is created."
  echo "                            (default: jstack,kill)"
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
  echo "    --skip-test-random      If set, skips test for speed of /dev/random."
  echo "                            (default: Unset, /dev/random test is executed)"
  echo "    --detail-log            If set, log lines contain extra data."
  echo "                            (default: Unset, log lines are nice looking)"
  echo "    --debug                 Increase logging of the script"
  echo "    --version, --usage, --help, -v"
  echo "                            Shows this information"
  echo
  if $isUsageFullEnabled; then
    echo "  Profiles:"
    echo "    tomcat      Sets defaults which expect the script to be started from"
    echo "                Tomcat's log directory."
    echo "                command:   java\$"
    echo "                argument:  Dcatalina.base=CWDPARENT"
    echo "                td-source: CWDPARENT/logs/catalina.out"
    echo "    glassfish   (Experimental)"
    echo "                Sets defaults which expect start of the script from"
    echo "                Glassfish domain's log directory."
    echo "                command:   java\$"
    echo "                argument:  domaindir CWDPARENT"
    echo "                td-source: $asadmintag"
    echo "    wildfly     (Experimental)"
    echo "                Sets defaults which expect start of the script from"
    echo "                Wildfly standalone's or domain's log directory."
    echo "                command:   java\$"
    echo "                argument:  Djboss.server.log.dir=CWDPARENT/log (domain)"
    echo "                argument:  Dorg.jboss.boot.log.file=CWDPARENT/log (standalone)"
    echo "                td-source: $wildflytag"
    echo "    jetty       (Experimental)"
    echo "                Sets defaults which expect start of the script from"
    echo "                Jetty's log directory."
    echo "                command:   java\$"
    echo "                argument:  Djetty.home=CWDPARENT"
    echo "                td-source: $jettytag"
    echo "    <unset>     Attempts profile auto-detection:"
    echo "                  tomcat - if catalina.out is in current directory"
    echo "                  glassfish - if server.log is in current directory and"
    echo "                              3rd parent of current directory is glassfish"
    echo "                  wildfly - if server.log is in current directory and"
    echo "                              2nd parent of current directory is standalone"
    echo "                              or 3rd parent is domain and 2nd parent is servers"
    echo "   custom       Does not perform profile auto-detection, but relies on defaults"
    echo "                and supplied arguments only."
    echo
    echo "    CWDPARENT is the parent of the current working directory, now:"
    echo "    '$cwd_parent'"
    echo
  fi
  echo "  Known Issues:"
  echo "    Paths with white spaces might fail the diagnostics partially or completelly."
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
      '--pid='*)
        cfg_pid="${arg#*=}"
        ;;
      '--command='*)
        cfg_command="${arg#*=}"
        ;;
      '--argument='*)
        cfg_argument="${arg#*=}"
        ;;
      '--td-source='*)
        cfg_td_source="${arg#*=}"
        ;;
      '--report-dir='*)
        cfg_reports_dir="${arg#*=}"
        ;;
      '--td-modes='*)
        cfg_td_modes="${arg#*=}"
        ;;
      '--username='*)
        cfg_username="${arg#*=}"
        ;;
      '--multi-pid')
        isMultiplePidProcessingAllowed=true
        ;;
      '--ps-all')
        isPsAllAllowed=true
        ;;
      '--lsof-all')
        isLsofAllAllowed=true
        ;;
      '--skip-test-random')
        runTestDevRandom=false
        ;;
      '--use-kill')
        isKillAllowed=true
        ;;
      '--detail-log')
        isLoggingNice=false
        ;;
      '--debug')
        isDebugEnabled=true
        ;;
      '--help'|'--usage')
        usage "full"
        exit 1
        ;;
      *)
        log "ERROR" "Unknown argument '$arg'"
        usage
        exit 1
    esac
    shift
    arg="$1"
  done
}

log() {
  local level prefix
  level="$1"
  shift
  prefix="[java-diag] ($(date -Iseconds)) $level:"
  if [ "$level" = "ERROR" ]; then
    $isLoggingNice && prefix="[!!]"
    echo "$prefix $*" >&2
  elif [ "$level" = "WARNING" ]; then
    $isLoggingNice && prefix="[!!]"
    echo "$prefix $*"
  elif [ "$level" = "DEBUG" ] && ! $isDebugEnabled; then
    return
  else
    $isLoggingNice && prefix="[--]"
    echo "$prefix $*"
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

get_java_processes() {
  local jps_bin
  jps_bin="$1"
  "$jps_bin" -m -l -v
  return $?
}

get_pspids_filtered() {
  local file cmd user cls arg
  file="$1"
  cmd="$2"
  user="$3"
  cls="$4"
  arg="$5"
  awk "
  ( \"$cmd\" == \"\" || \$9 ~ \"$cmd\" ) && \
  ( \"$user\" == \"\" || \$1 == \"$user\" ) && \
  ( \"$cls\" == \"\" || \$0 ~ \" $cls\\\s?\" ) && \
  ( \"$arg\" == \"\" || \$0 ~ \"$arg\" ) \
      { pids[\$2] = 1 }
  END { for (pid in pids) print pid }
  " "$file"
  return $?
}

get_jpspids_filtered() {
  local file cls arg
  file="$1"
  cls="$2"
  arg="$3"
  awk "
  ( \"$cls\" == \"\" || \$2 == \"$cls\" ) && \
  ( \"$arg\" == \"\" || \$0 ~ \"$arg\" ) \
      { pids[\$1] = 1 }
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
  # if 'lsof' command is not found"
  if [ -z "$lsof_bin" ]; then
    ret=1
    if [ -n "$pid" ] && [ -d "/proc/$pid/fd" ]; then
      # get open files from proc fs instead"
      ls -l "/proc/$pid/fd"
      ret=$?
    fi
  else
    [ -n "$lsof_bin" ] && "$lsof_bin" -b -w ${pid:+-p "$pid"}
    ret=$?
  fi
  return $ret
}

get_system_devrandom_speed() {
  local ret
  dd if=/dev/random of=/dev/null bs=4096 count=1 iflag=fullblock 2>&1
  return $?
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

thread_dump_by_kill() {
  local pid file
  pid="$1"
  file="$2"
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
      # TODO: check if sleep is always necessary
      # sleep before getting
      sleep 1
      java_log_lines=$(get_log_line_count "$file")
      java_td_line=$(echo "$java_tds_new" | tail -n1)
      log "DEBUG" "New thread dump found in '$file' on line '$java_td_line'"
      java_td_lines=$((java_log_lines - java_td_line))
      get_log_part "$file" "$java_td_line" "$java_td_lines" > "$report_root/java_pid-${process_pid}_td"
      return $?
    fi
    # sleep before trying again
    sleep 2
    retry=$((retry - 1))
  done
  return 2
}

thread_dump_by_jstack() {
  local pid jstack_bin isJstackForced
  pid="$1"
  jstack_bin="$2"
  [ "$3" = "true" ] && isJstackForced="true" || isJstackForced="false"
  retry=1
  while [ $retry -gt 0 ]; do
    if $isJstackForced; then
      "$jstack_bin" -F -l "$pid" > "$report_root/java_pid-${process_pid}_td"
      ret=$?
    else
      "$jstack_bin" -l "$pid" > "$report_root/java_pid-${process_pid}_td"
      ret=$?
    fi
    return $?
    sleep 2
    retry=$((retry - 1))
  done
  return 2
}

get_gclog_path_by_pid() {
  local pid file
  pid="$1"
  file="$2"
  awk " {
    if ( \"$pid\" == \$2 ) print \$0;
  }
  " "$file" | grep -m 1 -o ' -Xloggc:\S\+' | sed s/'^ -Xloggc:'//
  return $?
}

get_thread_from_td() {
  local file tid tidh isThreadDumpFormatForced
  file="$1"
  tid="$2"
  [ "$3" = "true" ] && isThreadDumpFormatForced="true" || isThreadDumpFormatForced="false"
  if $isThreadDumpFormatForced; then
    awk " {
      if ( \$1 ~ \"^Thread \" ) prn=0;
      if ( \$1 ~ \"^Thread $tid:\" ) prn=1;
      if (prn == 1) print \$0;
    } " "$file"
    ret=$?
  else
    tidh=$(printf "0x%x" "$tid")
    awk " {
      if ( \$0 ~ \" nid=0x\" ) prn=0;
      if ( tolower(\$0) ~ tolower(\" nid=$tidh \") ) prn=1;
      if (prn == 1) print \$0;
    } " "$file"
    ret=$?
  fi
  return $?
}

get_process_java_path() {
  local file pid
  file="$1"
  pid="$2"
  awk " {
    if ( \$2 == \"$pid\" ) { print \$9; exit; }
  } " "$file"
  return $?
}

set_profile() {
  local profile cmd kil arg tds dir cls
  profile="$1"
  # profile autodetect
  if [ -z "$profile" ]; then
    log "DEBUG" "No profile set, attempting auto-detection using log directory"
    if [ -f "./catalina.out" ]; then
      profile="tomcat"
    fi
    if [ -f "./server.log" ]; then
      if [ "$(basename "$cwd_parent")" = "standalone" ]; then
        profile="wildfly"
      fi
      if [ "$(basename "$cwd_parent2")" = "servers" ]; then
        if [ "$(basename "$cwd_parent3")" = "domain" ]; then
          profile="wildfly"
        fi
      fi
      if [ "$(basename "$cwd_parent3")" = "glassfish" ]; then
        profile="glassfish"
      fi
    fi
    [ -n "$profile" ] && log "INFO" "Auto-detection suggested profile '$profile'"
  fi
  case "$profile" in
    'tomcat')
      cmd="java\$"
      kil="true"
      arg="Dcatalina.base=$cwd_parent"
      tds="$cwd_parent/logs/catalina.out"
      dir="$cwd_parent/logs"
      cls="org.apache.catalina.startup.Bootstrap"
      ;;
    'glassfish')
      cmd="java\$"
      kil="true"
      arg="domaindir $cwd_parent"
      #tds="$asadmintag"
      dir="$cwd_parent/logs"
      cls="com.sun.enterprise.glassfish.bootstrap.ASMain"
      ;;
    'wildfly')
      cmd="java\$"
      kil="true"
      #domain
      arg="Djboss.server.log.dir=$cwd_parent/log"
      #standalone
      arg="Dorg.jboss.boot.log.file=$cwd_parent/log"
      #tds="$wildflytag"
      dir="$cwd_parent/log"
      cls="*/jboss-modules.jar"
      ;;
    'jetty')
      cmd="java\$"
      kil="true"
      #standalone
      arg="Djetty.home=$cwd_parent"
      #tds="$jettytag"
      dir="$cwd_parent/logs"
      cls=".*/start.jar"
      ;;
    ''|'custom')
      ;;
    *)
      log "ERROR" "Unknown profile '$profile'"
      exit 1
  esac
  log "DEBUG" "Setting profile '$profile'"
  [ -z "$cfg_command" ] && cfg_command="$cmd"
  if ! $isKillAllowed && [ "$kil" = "true" ]; then
    log "DEBUG" "Kill signal allowed by profile"
    isKillAllowed="$kil"
  fi
  [ -z "$cfg_class" ] && cfg_class="$cls"
  [ -z "$cfg_argument" ] && cfg_argument="$arg"
  [ -z "$cfg_td_source" ] && cfg_td_source="$tds"
  [ -z "$cfg_reports_dir" ] && cfg_reports_dir="$dir"
}

# main
cwd_parent=$(dirname "$(pwd)")
cwd_parent2=$(dirname "$cwd_parent")
cwd_parent3=$(dirname "$cwd_parent2")
proc_attributes="user:16,pid,ppid,tid,%cpu,%mem,time,stat,command"
td_header_start="Full thread dump"
start_today=$(date +%Y-%m-%d)
journaltag="__journal__"
asadmintag="__asadmin__"
wildflytag="__wildfly__"
jettytag="__jetty__"

# arguments
unset cfg_profile cfg_pid cfg_td_source cfg_reports_dir cfg_command cfg_argument
unset cfg_class cfg_username cfg_td_modes cfg_jps_path cfg_jmap_path
isKillAllowed=false
isDebugEnabled=false
isPstackEnabled=true
isMultiplePidProcessingAllowed=false
isGcLogExtractionAllowed=true
isPsAllAllowed=false
isLsofAllAllowed=false
isNetstatAllowed=true
isPidsByJpsEnabled=false
isPidsByPsEnabled=false
isLoggingNice=true

parse_args "$@"
set_profile "$cfg_profile"

# defaults
[ -z "$cfg_td_modes" ] && cfg_td_modes="jstack,kill"
if [ -z "$cfg_command" ]; then
  cfg_command="java\$"
fi
[ -z "$cfg_jps_path" ] && cfg_jps_path="$(which jps 2>/dev/null)"
[ -z "$cfg_reports_dir" ] && cfg_reports_dir="."
report_root="$cfg_reports_dir/java-diag-$(date +%Y-%m-%d_%H-%M-%S%z)-$$"
lsof_bin=$(which lsof 2>/dev/null)
pstack_bin=$(which pstack 2>/dev/null)

# report directory
[ -d "$cfg_reports_dir" ] || { log "ERROR" "Cannot find reports directory '$cfg_reports_dir'"; exit 2; }
mkdir "$report_root"
[ -d "$report_root" ] || { log "ERROR" "Cannot create report root '$report_root'"; exit 2; }
log "INFO" "Report directory '$report_root' has been created"

# get general system information before Java diagnostics
if $isPsAllAllowed || [ -z "$cfg_username" ]; then
  log "INFO" "Getting all system processes"
  src_procs="sys_procs"
  if get_system_processes > "$report_root/$src_procs"; then
    isPidsByPsEnabled=true
  fi
fi

if [ -n "$cfg_username" ]; then
  log "INFO" "Getting system processes of '$cfg_username'"
  src_procs="sys_user-${cfg_username}_procs"
  if get_system_processes "$cfg_username" > "$report_root/$src_procs"; then
    isPidsByPsEnabled=true
  fi
fi

if [ -x "$cfg_jps_path" ]; then
  log "INFO" "Getting all Java processes"
  if get_java_processes "$cfg_jps_path" > "$report_root/sys_javaprocs"; then
    isPidsByJpsEnabled=true
  fi
fi

if $isNetstatAllowed; then
  log "INFO" "Getting network statistics"
  get_system_netstats > "$report_root/sys_netstat"
fi

if $isLsofAllAllowed; then
  log "INFO" "Getting all open files"
  get_system_openfiles > "$report_root/sys_openfiles"
fi

if $runTestDevRandom; then
  log "INFO" "Testing /dev/random speed"
  get_system_devrandom_speed > "$report_root/sys_devrandom_speed"
fi

if [ -n "$cfg_pid" ]; then
  log "DEBUG" "Got PID '$cfg_pid' from argument"
  process_pids=( "$cfg_pid" )
fi
# jps goes first as it considers only local cgroup and excludes containers
if [ -z "${process_pids[*]}" ] && $isPidsByJpsEnabled; then
  log "DEBUG" "Parsing PIDs from Java processes file"
  process_pids=( $(get_jpspids_filtered "$report_root/sys_javaprocs" "$cfg_class" "$cfg_argument") )
fi
if [ -z "${process_pids[*]}" ] && $isPidsByPsEnabled; then
  log "DEBUG" "Parsing PIDs from processes file"
  process_pids=( $(get_pspids_filtered "$report_root/$src_procs" "$cfg_command" "" "$cfg_class" "$cfg_argument") )
fi
process_pids_num=${#process_pids[@]}

if [ "$process_pids_num" = "1" ]; then
  log "INFO" "PID to process '${process_pids[*]}'"
elif [ "$process_pids_num" = "0" ]; then
  log "ERROR" "No PIDs to process, exiting"
  log "INFO" "Make sure the application is running and criteria are set correctly"
  exit 3
else
    log "WARNING" "Total '$process_pids_num' PIDs found [${process_pids[*]}]"
    if ! $isMultiplePidProcessingAllowed; then
      log "ERROR" "Diagnosing multiple PIDs is not allowed by default, exiting"
      log "INFO" "Try to narrow down the selection criteria or use --multi-pid option"
      exit 5
    fi
fi

log "INFO" "Java Diagnostics Start"

for process_pid in "${process_pids[@]}"; do
  java_path=$(get_process_java_path "$report_root/$src_procs" "$process_pid")
  if [ -z "$java_path" ]; then
    log "WARNING" "Skipping PID '$process_pid', because Java path was not found in process list"
    break
  fi
  # get additional pid related system information before Java diagnostics
  log "INFO" "Getting open files for PID '$process_pid'"
  get_system_openfiles "$process_pid" > "$report_root/process_pid-${process_pid}_openfiles"
  log "INFO" "Getting IP connections for PID '$process_pid'"
  get_ip_connections_by_pid "$report_root/sys_netstat" "$process_pid" > "$report_root/process_pid-${process_pid}_ipconnections"
  log "INFO" "Getting threads for PID '$process_pid'"
  get_threads_by_pid "$report_root/$src_procs" "$process_pid" > "$report_root/process_pid-${process_pid}_threads"
  get_threads_running "$report_root/process_pid-${process_pid}_threads" > "$report_root/process_pid-${process_pid}_running_threads"
  get_threads_active "$report_root/process_pid-${process_pid}_threads" > "$report_root/process_pid-${process_pid}_busy_threads"
  if $isGcLogExtractionAllowed; then
    log "DEBUG" "Looking for GClog path for PID '$process_pid'"
    gclog=$(get_gclog_path_by_pid "$process_pid" "$report_root/$src_procs")
    if [ -r "$gclog" ]; then
      log "DEBUG" "GClog path found as '$gclog'"
      if [ -f "$gclog" ]; then
        log "INFO" "Getting GC log for PID '$process_pid'"
        cat "$gclog" > "$report_root/java_pid-${process_pid}_gc.log"
      fi
    fi
  fi
  if [ -x "$pstack_bin" ] && $isPstackEnabled; then
    log "DEBUG" "Getting pstack trace"
    "$pstack_bin" "$process_pid" > "$report_root/process_pid-${process_pid}_pstack"
  fi

  # get thread dump
  isThreadDumpAvailable=false
  isThreadDumpFormatForced=false
  for td_mode in ${cfg_td_modes//,/ }; do
    case "$td_mode" in
      'jstack')
        jstack_bin="${java_path:0:-4}jstack"
        log "DEBUG" "Using jstack at '$jstack_bin'"
        if [ -x "$jstack_bin" ]; then
          log "INFO" "Executing jstack for PID '$process_pid' and getting thread dump"
          if thread_dump_by_jstack "$process_pid" "$jstack_bin"; then
            isThreadDumpAvailable=true
            break
          else
            log "WARNING" "Mode '$td_mode' failed to obtain thread dump"
          fi
        else
          log "WARNING" "Skipping '$td_mode' thread dump mode, because of missing jstack"
        fi
        ;;
      'jstackforce')
        jstack_bin="${java_path:0:-4}jstack"
        log "DEBUG" "Using jstack at '$jstack_bin'"
        if [ -x "$jstack_bin" ]; then
          log "INFO" "Executing forced jstack for PID '$process_pid' and getting thread dump"
          if thread_dump_by_jstack "$process_pid" "$jstack_bin" "true"; then
            isThreadDumpAvailable=true
            isThreadDumpFormatForced=true
            break
          else
            log "WARNING" "Mode '$td_mode' failed to obtain thread dump"
          fi
        else
          log "WARNING" "Skipping '$td_mode' thread dump mode, because of missing jstack"
        fi
        ;;
      'kill')
        if $isKillAllowed; then
          if [ -z "$cfg_td_source" ]; then
            log "WARNING" "Skipping '$td_mode' thread dump mode, because no thread dump source is set"
          else
            # TODO: Verify whether log file is readable
            log "INFO" "Sending signal to PID '$process_pid' and getting thread dump"
            if thread_dump_by_kill "$process_pid" "$cfg_td_source"; then
              isThreadDumpAvailable=true
              break
            else
              log "WARNING" "Mode '$td_mode' failed to obtain thread dump"
            fi
          fi
        else
          log "WARNING" "Skipping '$td_mode' thread dump mode, because sending of the kill signal"
          log "WARNING" "to the process is not allowed"
          log "WARNING" "You can use --use-kill option to enable sending of the kill signal"
        fi
        ;;
      *)
        log "ERROR" "Unknown thread dump gathering mode '$td_mode'"
        exit 1
    esac
  done
  if $isThreadDumpAvailable; then
    log "INFO" "Getting suspicious threads for PID '$process_pid'"
    echo > "$report_root/java_pid-${process_pid}_suspicious_threads"
    for tid in $(get_tids "$report_root/process_pid-${process_pid}_running_threads" "$report_root/process_pid-${process_pid}_busy_threads"); do
      log "DEBUG" "Checking thread '$tid'"
      {
        head -n1 "$report_root/$src_procs"
        get_threads_by_tid "$report_root/process_pid-${process_pid}_threads" "$tid"
        get_thread_from_td "$report_root/java_pid-${process_pid}_td" "$tid" "$isThreadDumpFormatForced"
        echo >> "$report_root/java_pid-${process_pid}_suspicious_threads"
      } >> "$report_root/java_pid-${process_pid}_suspicious_threads"
    done
  else
    log "WARNING" "Thread dump has been not retrieved"
  fi
done
log "INFO" "Java Diagnostics End"
