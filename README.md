# java-diag

[![Build Status - Master](https://travis-ci.org/pes-soft/java-diag.svg?branch=master)](https://travis-ci.org/pes-soft/java-diag)
[![Average time to resolve an issue](http://isitmaintained.com/badge/resolution/pes-soft/java-diag.svg)](http://isitmaintained.com/project/pes-soft/java-diag "Average time to resolve an issue")
[![Percentage of issues still open](http://isitmaintained.com/badge/open/pes-soft/java-diag.svg)](http://isitmaintained.com/project/pes-soft/java-diag "Percentage of issues still open")
[![License: GPL v3](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

**java-diag** is a shell script which assists system administrator with collection of information about running Java process in environments where diagnosis by native Java tools is not easily possible or available at all. Primary goal is to help with diagnosis of root cause for unexpected application behavior, such as non-responding application or high load on system resources.

##### WARNING

**java-diag** looks for running process based on certain criteria and then sends the kill signal to this process. If the selected process is not a Java, it might result in termination and/or data-loss. Make sure that you know how the tool works and how the process is selected, before actually allowing to use the kill signal.

### Usage Examples

**Usage**: Initial test recon. Change directory to Tomcat logs and perform search for the target process. No kill signal is sent, just basic info gathered. Output provides verification whether one correct PID has been found.

```sh
cd /opt/apache-tomcat/logs
/opt/java-diag/java-diag.sh --profile=tomcat
```

**Usage**: Thread dump generation by sending the kill signal. Change directory to Tomcat logs, search for the target process, collect basic info, send kill signal and gather thread dump. Report directory contains full thread dump with list of suspected threads and their stack traces.

```sh
cd /opt/apache-tomcat/logs
/opt/java-diag/java-diag.sh --profile=tomcat --use-kill
```

### Report Directory Content

* *sys_procs*: List of all running processes and threads
* *sys_user-~USERNAME~_procs*: List of running processes and threads of user *~USERNAME~*
* *sys_netstat*: List of all network connections
* *sys_openfiles*: List of all open files
* *process_pid-~PIDNUM~_openfiles*: List of open files by process with PID *~PIDNUM~*
* *process_pid-~PIDNUM~_ipconnections*: List of TCP and UDP connections by process with PID *~PIDNUM~*
* *process_pid-~PIDNUM~_threads*: List of threads by process with PID *~PIDNUM~*
* *process_pid-~PIDNUM~_running_threads*: List of threads with status *running* by process with PID *~PIDNUM~*
* *process_pid-~PIDNUM~_busy_threads*: List of threads with higher percentual CPU usage than *0.0* by process with PID *~PIDNUM~*
* *java_pid-~PIDNUM~_td*: Full thread dump of Java process with PID *~PIDNUM~*
* *java_pid-~PIDNUM~_suspicious_threads*: List of stack traces for running and busy threads of Java process with PID *~PIDNUM~*

Notes:

* *~NAMES~* are placeholders for actual values, which will depend on your setup.
* Some of the files are optional and will be generated only in case of correct configuration ( thread dump requires kill signal enabled, global process list or list of open files requires specific parameter configuration, ... )

### Detail Usage Scenario

Setup:

* java-diag is installed in /opt/java-diag directory
* Apache Tomcat is installed in /opt/apache-tomcat directory
* Tomcat does not use any specific JAVA_HOME and calls bare java command ( java is available in PATH )
* Tomcat uses default configuration for logging ( $CATALINA_BASE/logs/catalina.out )
* Tomcat is running and unexpected behavior occurs with the application ( application is not responding )

Before performing application restart, which would (usually) restore application behavior to normal, necessary runtime data can be collected, which can later help with diagnosis of the root cause. This includes:

* Thread Dump: provided later using java-diag tool
* Process Information: partially provided by java-diag tool ( open files, network connections, ... )
* Garbage Collector logs: suitable for diagnosis of memory issues - memory leaks, memory misconfigurations, and so on. Currently not supported by **java-diag**

Commands:

```sh
cd /opt/apache-tomcat/logs
/opt/java-diag/java-diag.sh --profile=tomcat
```

Output:

```
[java-diag] (2017-09-07T20:16:44+02:00) INFO: Setting profile 'tomcat'
[java-diag] (2017-09-07T20:16:44+02:00) INFO: Getting all system processes
[java-diag] (2017-09-07T20:16:44+02:00) INFO: Getting network statistics
[java-diag] (2017-09-07T20:16:44+02:00) INFO: PID found [1583]
[java-diag] (2017-09-07T20:16:44+02:00) INFO: Getting open files for PID '1583'
[java-diag] (2017-09-07T20:16:44+02:00) INFO: Getting IP connections for PID '1583'
[java-diag] (2017-09-07T20:16:44+02:00) INFO: Getting threads for PID '1583'
[java-diag] (2017-09-07T20:16:44+02:00) INFO: Sending signal to process not allowed by options, no thread dump will be retrieved
[java-diag] (2017-09-07T20:16:44+02:00) INFO: If PID of java process has been found, use --use-kill option to get thread dump
```

Setting profile to *tomcat* configured default values for following options:

* Command: `java$`
* Argument: `Dcatalina.base=/opt/apache-tomcat`
* Log File: `/opt/apache-tomcat/logs/catalina.out`
* Reports Directory: `/opt/apache-tomcat/logs`

 **java-diag** created a new directory `java-diag-2017-09-07T20:16:44+02:00-1767` located under *Reports Directory* path. In this directory are all gathered data saved.

PID is manually verified as belonging to the target Java process ( for example by checking using `ps` command ).

Commands:

```sh
cd /opt/apache-tomcat/logs
/opt/java-diag/java-diag.sh --profile=tomcat --use-kill
```

Output:

```
[java-diag] (2017-09-07T20:21:54+02:00) INFO: Setting profile 'tomcat'
[java-diag] (2017-09-07T20:21:54+02:00) INFO: Getting all system processes
[java-diag] (2017-09-07T20:21:54+02:00) INFO: Getting network statistics
[java-diag] (2017-09-07T20:21:55+02:00) INFO: PID found [1583]
[java-diag] (2017-09-07T20:21:55+02:00) INFO: Getting open files for PID '1583'
[java-diag] (2017-09-07T20:21:55+02:00) INFO: Getting IP connections for PID '1583'
[java-diag] (2017-09-07T20:21:55+02:00) INFO: Getting threads for PID '1583'
[java-diag] (2017-09-07T20:21:55+02:00) INFO: Sending signal to PID '1583' and getting thread dump from log file '/opt/apache-tomcat/logs/catalina.out'
[java-diag] (2017-09-07T20:21:56+02:00) INFO: Getting suspicious threads for PID '1583'
```

**java-diag** created a new directory `java-diag-2017-09-07T20:21:54+02:00-2406` located under *Reports Directory* path. In this directory are all gathered data saved.

Note: In case of security sensitive environments, make sure you upload anonymized data for online analysis.

Extracted thread dump located in file *java_pid-1583_td* can be analyzed for hanging locked threads and other issues:

 * http://fastthread.io/ ( online thread dump analysis )
 * http://samuraism.jp/samurai/en/index.html ( offline thread dump analysis tool )
 * https://github.com/irockel/tda ( offline thread dump analysis tool )

Garbage collector log can be analyzed for memory leak behavior, out of memory and other issues:

 * http://www.gceasy.io/ ( online garbage collector log analysis tool )

Limits of system related metrics can be checked:

 * processes: Run `ulimit -u` under the Tomcat user to get the limit of max user processes and compare it with amount of user's threads in *sys_procs* report. Also in case of systemd Tomcat service management, pay attention into configuration of the service and its default for the limits.
 * open files: Run `ulimit -n` under the Tomcat user to get the limit of max open file handles and compare it with amount of user's threads in *sys_openfiles* report. Also in case of systemd Tomcat service management, pay attention into configuration of the service and its default for the limits.
 * network connections: Get the limits of external network destinations used by Tomcat and compare it with amount of Tomcat's connections in *sys_netstat*.

Log of the application itself can lead to the root cause of the unexpected behavior ( out of memory errors, database connection issues, ... ).

Actively running threads and those with higher system load can be checked for suspicious behavior. Their stack traces are located in file *java_pid-1583_suspicious_threads*.

### FAQ

##### Why not use jstack to get the thread dump?

* jstack can take some extra time in case the application is hung to generate the stack.
* jstack might not be able to get the stack trace without use the force switch ( -F ). This switch however causes application to stop for some time and can for example result into request failures in case of web application.
* jstack must be in the compatible version as is running the application's java. On some environments jstack is not available or might be time consuming to look for compatible jstack on the system.
