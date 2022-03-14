#!/bin/bash

# SRE Take Home Assessment

# A cURL wrapper script which allows you to monitor multiple vhosts on a single 
# httpd hosted instance. The script takes several command arguments which allow the 
# injest of a vhost file, parse it, then extracts all virtual host entries in order to
# compose the proper Host header value for curl runtime. The frequency for how 
# often curl fetches can be controlled with the polling interval set (seconds) 
# such that it allows enough time to fetch up to 1000 virtual hosts per period.
# During each poll period a event.log is written which is ingested by awslogs
# agent and streamed to AWS CloudWatch for Observability. In addition, the 
# runtime leverages xargs capability to run multiple asynchronous processes 
# as a means to speed up execution for URL fetch times.

# Command arguments 
#  -f : Path to Apache Vhost file to be parsed and used for processing 
#  -u : URL of target EC2 instance to be monitored
#  -p : Run up to max-procs processes at a time
#  -t : Poll the target EC2 instance every X seconds. 
#
# Output files
#  event.log : Error only logging for log injest.

parsed_file="/var/tmp/h.tmp"
event_log="./events.log"

declare -A Telemetry
declare -A MonitoringStatus
declare -A Parsed

usage(){
	echo "${0} [[ -f[path_to_vhost_file] | -u[target_host_url] | -p[max_procs_parallel] | -t[poll_time]] ]" 
exit 1
}

# STDOUT FATAL errors then exit
fatal_exit(){
local date=$(date)
local message=$1
	echo "$(date) FATAL: Exiting with: $message"
exit 1
}

# Log alarm events
log_event(){
local date=$(date)
local log_level=$1
local message=$2
	echo "$date $log_level $message" >>$event_log
}

while getopts "f:u:p:t:" options; do

	case ${options} in

	f)
	vhost_file=${OPTARG}
	;;

	u)
	target_host=${OPTARG}
	export URL=$target_host
	;;

	p)
	max_procs=${OPTARG}
	;;

	t)
	poll_interval=${OPTARG}
	;;

	:)
	usage
	;;

	?)
	usage
	;;

	esac
done
shift $((OPTIND -1))

# Checking command dependencies
curl --version >/dev/null 2>&1
if [[ $? != 0 ]]; then
	fatal_exit "Command not found: curl"
fi

# Checking command dependencies
xargs --version >/dev/null 2>&1
if [[ $? != 0 ]]; then
	fatal_exit "Command not found: xargs"
fi

# Parse and extract ServerName values
if [ -f "$vhost_file" ]; then
Parsed=$(egrep -v '#.*$' $vhost_file |\
sed 's/^[ \t]*//' |\
grep -v '^[[:space:]]*$' |\
grep ServerName |\
cut -d" " -f2 >$parsed_file)
else
	usage
	fatal_exit "No input file"
fi

# Main loop
while true; do

	if [ ! -f $parsed_file ]; then
		fatal_exit "File not found: $parsed_file"
	fi

	Telemetry=$(xargs -P$max_procs -a $parsed_file -I'{}' bash -c '{ curl -s -H"Host: {}" --url "${URL}" -o /dev/null -w %{http_code}; echo ":{}" ; }')

	for i in $Telemetry; do
	code=$(echo $i |cut -d: -f1)
	vhost=$(echo $i |cut -d: -f2)
		MonitoringStatus[$vhost]=$code
	done

	for fqdn in "${!MonitoringStatus[@]}"; do 
	http_code="${MonitoringStatus[$fqdn]}"

		case $http_code in
		1[0-9][0-9])
			log_event "Info $fqdn $http_code"
		;;

		2[0-9][0-9])
			log_event "Success $fqdn $http_code"
		;;

		3[0-9][0-9])
			log_event "Redirect $fqdn $http_code"
		;;

		4[0-9][0-9])
			log_event "ClientError $fqdn $http_code"
		;;

		5[0-9][0-9])
			log_event 'ERROR' "$fqdn $http_code"
		;;

		*)
			log_debug "DefaultError: $fqdn $http_code"
		;;
		esac
	done
sleep $poll_interval
done
