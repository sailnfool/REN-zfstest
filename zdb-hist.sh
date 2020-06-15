#!/bin/bash
if [ $(id -u) != 0 ]
then
	echo "Not root"
	exit -1
fi
if [ $# -gt 0 ]
then
	luser=$1
else
	echo "Missing username"
	echo "${0##*/} <user>"
	echo -en "${USAGE}"
	exit -1
fi
host=$(hostname)
pool=tank
case ${host} in
jet*)
	RESULTS=/tftpboot/global/novak5/bench_results
	;;
*)
	ldir=$(getent passwd | grep ${luser} | cut -d: -f6)
	RESULTS=${ldir}/bench_results
	;;
esac
echo "mkdir -p ${RESULTS}/"
mkdir -p ${RESULTS}
echo "${0##*/}: We are on ${host} and will place results in directory ${RESULTS}"
echo "/bin/time zdb -bbb ${pool} |  tee  ${RESULTS}/${host}.dumpbbb.txt"
/bin/time zdb -bbb ${host} 2> ${RESULTS}/${host}.timer.txt | \
	tee  ${RESULTS}/${host}.dumpbbb.txt
echo "/bin/time zdb -Pbbb ${pool} | tee  ${RESULTS}/${host}.dumpPbbb.txt"
/bin/time zdb -Pbbb ${host} 2> ${RESULTS}/${host}.timerP.txt | \
	tee  ${RESULTS}/${host}.dumpPbbb.txt
