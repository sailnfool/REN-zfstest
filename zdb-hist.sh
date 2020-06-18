#!/bin/bash
source zfunc.results
USAGE="${0##*/} [-p <pool>] <user>\n
\t-p\t<pool>\tName of the pool that is used\n
\t\t\tThe default name is tank\n
"
if [ $(id -u) != 0 ]
then
	echo "You must be root.  You are $(id -ur)"
	exit -1
fi

pool="tank"
optionargs="p:"
while getopts ${optionargs} name
do
	case ${name} in
	p)
		poolspecified=1
		pool="${OPTARG}"
		pooldir="/${pool}"
		;;
	\?)
		echo "-e" "invalid option -${OPTARG}"
		echo "-e" ${USAGE}
		exit -1
		;;
	esac
done
NUMARGS=1
shift "$(($OPTIND - 1 ))"
if [ $# -ge ${NUMARGS} ]
then
	luser=$1
	shift
else
	echo "Missing username"
	echo "${0##*/} <username>"
	exit -1
fi
host=$(hostname)
RESULTS=$(benchresults ${luser})
if [ -z "${RESULTS}" ]
then
	echo "${0##*/}: results directory is null?"
	exit -1
fi
mkdir -p ${RESULTS}
echo "${0##*/}: We are on ${host} and will place results in directory ${RESULTS}"
echo "/bin/time zdb -bbb ${pool} |  tee  ${RESULTS}/${host}.${pool}.dumpbbb.txt"
/bin/time zdb -bbb ${pool} 2> ${RESULTS}/${host}.${pool}.timer.txt | \
	tee  ${RESULTS}/${host}.${pool}.dumpbbb.txt
echo "/bin/time zdb -Pbbb ${pool} | tee  ${RESULTS}/${host}.${pool}.dumpPbbb.txt"
/bin/time zdb -Pbbb ${pool} 2> ${RESULTS}/${host}.${pool}.timerP.txt | \
	tee  ${RESULTS}/${host}.${pool}.dumpPbbb.txt
	find ${RESULTS} -name "${host}.${pool}.*" -exec chown ${luser} {} ';' \
		-exec chgrp ${luser} {} ';'
vim ${RESULTS}/${host}.${pool}.*.txt
