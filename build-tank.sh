#!/bin/bash
source func.errecho
source func.genrange
#######################################################################
# Author: Robert E. Novak # email: novak5@llnl.gov, sailnfool@gmail.com
#
# create a zpool in the root directory of the current drive. If this
# gets more usage, make the location of the pool a parameter to this
# script.
#
# The pool is created by root, but the ownership is transferred to
# the user invoking the script.
#######################################################################
####################
# For the slag machines we have chosen to arbitrarily assign the
# first 12 drives to slag5 and the second 12 drives to slag6
#
# Rather than hard-coding this we will generate the list of drives,
# split the list in two and use those lists to set up the pools
# later
# For the slag{5,6} machines the SSDs are listed by V-Dev name
# for persistent naming affiliated with their rack locations.
####################
function slaglists() {
	slagdir="/dev/disk/by-vdev/"
	slagssdprefix="U"
	slagssdlist=/tmp/slagssdlist.$$.txt
	slag5list=/tmp/slag5list.$$.txt
	slag6list=/tmp/slag6list.$$.txt
	slagtmplist=/tmp/slagtmplist.$$.txt
	pushd ${slagdir}
	ls ${slagssdprefix}* > ${slagssdlist}
	count=$(wc -l ${slagssdlist})
	((countfor5=count / 2))
	((countfor6=count - countfor6))
	head -${countfor5} ${slagssdlist} > ${slag5list}
	tail -${countfor6} ${slagssdlist} > ${slag6list}
	cat ${slag5list} ${slag6list} > ${slagtmplist}
	if [ cmp -s ${slagssdlist} ${slagtmplist} ]
	then
		errecho "Mismatch in generated devlists"
		errecho "${slagssdist}"
		errecho "${slagtmplist}"
		diff ${slagssdist} ${slagtmplist}
		exit -1
	fi
}
USAGE="\n${0##*/} [-hdvf:] <username> [ssd path1 ...]\n
\t\tbuild a zfs tank from files or from existing devices\n
\t-h\t\tPrint this message\n
\t-d\t\tTurn on diagnostics (set -x)\n
\t-f\t<#>\tNumber of plain files to initialize and use for vdev\n
\t\t\tDefault is 8 files of 8 GB each.\n
\t-p\t<pool>\tName of the pool to be created\n
\t\t\tThe default name is tank\n
\t-x\t<vdev-prefix>\n
\t\t\tNote that the files will be in /<vdev-prefix>-files\n
\t\t\tif file vdevs are used.\n
\t-v\t\tList of devices on the command line\n
"

####################
# The default tank name is tank.  The resulting ZFS directory will
# be /tank
#
# The default location if there are vdevs created by file will be
# in /zpool/files/file-xx where xx varies from 0 -> -f #
####################
optionargs="hb:dp:vx:f:"
NUMARGS=1
num_vdevs=8
debug=0

####################
# Define where we will put the created pool - Other pools may
# already exist on this system.
####################
pool="tank"
pooldir="/${pool}"
bs=1G

vdevsdir="/vdevs"
vdevsfiledir=${vdevsdir}/files
vdevlist=""
poolspecified=0
vdevsspecified=0


while getopts ${optionargs} name
do
	case ${name} in
	h)
#		errecho "-e" ${USAGE}
		echo -en "${USAGE}"
		exit 0
		;;
	b)
		bs="${OPTARG}"
		;;
	d)
		debug=1
		set -x
		;;
	f)
		num_vdevs="${OPTARG}"
		;;
	p)
		poolspecified=1
		pool="${OPTARG}"
		pooldir="/${pool}"
		;;
	x)
		vdevsspecified=1
		vdevsdir="/${OPTARG}"
		vdevsfiledir="${vdevsdir}/files"
		;;
	\?)
		errecho "-e" "invalid option -${OPTARG}"
		errecho "-e" ${USAGE}
		exit -1
		;;
	esac
done
shift "$(($OPTIND - 1 ))"
if [ $# -gt 0 ]
then
	luser=$1
else
	echo "Missing username"
	echo "${0##*/} <username>"
	exit -1
fi
shift
if [ $EUID != 0 ]
then
	echo "Not root"
	exit -1
fi
while [ $# -gt 0 ]
do
	vdevlist="${vdevlist} $1"
	shift
done
if [ -r /root/.bashrc.${luser}.save ]
then
	cp /root/.bashrc.${luser}.save /root/.bashrc
	chown root /root/.bashrc
else
	cp /root/.bashrc /root/.bashrc.${luser}.save
	chown ${luser} /root/.bashrc.${luser}.save
fi
export PATH=~${luser}/github/zfs/bin:~${luser}/bin:$PATH
echo "We are on  $(hostname)"
case $(hostname) in
slag5)
	slaglists()
	if [ ${vdevsspecified} -eq 0 ]
	then
		zpool create ${pool} ${slag5list}
		zpool status ${pool}
		zfs set recordsize=1m ${pool}
		chown ${luser} ${pooldir}
		chgrp ${luser} ${pooldir}
	else
		zpool create ${pool} 
	fi
	;;
slag6)
	slaglists()
	zpool create ${pool} ${slag6list}
	zpool status ${pool}
	zfs set recordsize=1m ${pool}
	chown ${luser} ${pooldir}
	chgrp ${luser} ${pooldir}
	;;
auk134)
	echo "We are on $(hostname)"
	if [ ! -d ${vdevsfiledir} ]
	then
		mkdir -p ${vdevsfiledir}
	 	chown ${luser} ${vdevsfiledir}
	 	chgrp ${luser} ${vdevsfiledir}
	fi
	####################
	# create 8 files of 8GB each for a total pool size of 64GB
	####################
	for i in $(genrange 1 ${num_vdevs})
	do
	  if [ ! -f ${vdevsfiledir}/file-${i} ]
	  then
	    dd if=/dev/zero of=${vdevsfiledir}/file-${i} bs=1G count=8 &> /dev/null
	  fi
	  POOLNAMES="${POOLNAMES} ${vdevsfiledir}/file-${i}"
	done
	zpool create ${pool} ${POOLNAMES}
	zpool status ${pool}
	zfs set recordsize=1m ${pool}
	chown ${luser} ${pooldir}
	chgrp ${luser} ${pooldir}
	;;
OptiPlex980)
	echo "We are on $(hostname)"
	if [ ! -d ${vdevsfiledir} ]
	then
		mkdir -p ${vdevsfiledir}
	 	chown ${luser} ${vdevsfiledir}
	 	chgrp ${luser} ${vdevsfiledir}
	fi
	####################
	# create 8 files of 8GB each for a total pool size of 64GB
	####################
	ZPOOL=${vdevsfiledir}/file
	set +x
	for i in $(genrange 1 ${num_devs})
	do
	  if [ ! -f ${ZPOOL}${i} ]
	  then
		echo "Building ${ZPOOL}${i}"
	    dd if=/dev/zero of=${ZPOOL}${i} bs=1G count=8 &> /dev/null 
	  fi
	  POOLNAMES="${POOLNAMES} ${ZPOOL}${i}"
	done
	wait
	zpool create tank ${POOLNAMES}
	zpool status tank
	zfs set recordsize=1m tank
	chown ${luser} ${pooldir}
	chgrp ${luser} ${pooldir}
	;;
\?)
	echo "Unrecognized hostname"
	;;
esac
mv /root/.bashrc.${luser}.save /root/.bashrc
chown root /root/.bashrc
