#!/bin/bash
source func.errecho
source func.genrange
source func.kbytes
source func.nice2num
#######################################################################
# Author: Rober E. Novak
# email: novak5@llnl.gov, sailnfool@gmail.com
#
# fill a zpool tank.  There are default tanks and default cpio commands
# to complement them.
#
# Adding a process to specify the tank to fill, the number of files
# to place in the tank and specify a divide the set of blocksizes for
# the files to be created with dd commands and then copied into the
# tank.
#######################################################################

USAGE="\n${0##*/} [-hd] [-b blksize] [-p <pool>] [-f <#>]\n
\t\tfill a zfs tank.  The default fills the default tank by doing a\n
\t\tcpio of the user's home directory.  The options specify creating\n
\t\ta set of files of varying blocksizes to fill the tank\n
\t-h\t\tPrint this message\n
\t-d\t\tTurn on diagnostics (set -x)\n
\t-b\t<blksize>\tThe size of the blocks dd will use for creating file\n
\t\t\tvdevs, see dd documentation for specifying sizes\n
\t-p\t<pool>\tName of the pool to be used\n
\t\t\tThe default name is tank\n
\t-s\tThe maximum block size to create.  The block sizes will be\n
\t\t\tdistributed across the number of files created.\n
\t-t\t<#>\tThe number of files to create\n
\t\t\tThis should be a multiple of 24\n
"
####################
# The default tank name is tank.  The resulting ZFS directory will
# be /tank
#
# The default location if there are vdevs created "by file" they
# will be in /zpool/files/file-xx where xx varies from 0 -> -f #
####################
optionargs="hb:df:p:s:t:"
NUMARGS=0
num_vdevs=8
debug=0

pool="tank"
pooldir="/${pool}"
bs=1G

vdevsdir="/vdevs"
vdevsfiledir="${vdevsdir}/files"
vdevlist=""
poolspecified=0
vdevspecified=0
max_blocksize=128*__kibibytes
ZFS_MAXBLOCKSHIFT=24
re_number='^[0-9]+$'
max_files=${ZFS_MAXBLOCKSHIFT}\*2

while getopts ${optionargs} name
do
	case ${name} in
	h)
		errecho "-e" ${USAGE}
#		echo -en "${USAGE}"
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
	s)
		max_blocksize=${OPTARG}
		;;
	t)
		max_files="${OPTARG}"
		if [[ ! "${max_files}" =~ ${re_number} ]]
		then
			errecho "Not a number ${OPTARG}"
			echo -en "${USAGE}"
			exit -1
		fi
		if [ ${max_files} -lt ${ZFS_MAXBLOCKSHIFT} ]
		then
			errecho "Must be greater than ${ZFS_MAXBLOCKSHIFT}, got ${max_files}"
			echo -en "${USAGE}"
			exit -1
		fi
		;;
	\?)
		errecho "-e" "invalid option -${OPTARG}"
		errecho "-e" ${USAGE}
		exit -1
		;;

	esac
done
shift "$(($OPTIND - 1 ))"
if [ $EUID != 0 ]
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
	exit -1
fi
case $(hostname) in
slag5 | slag6 | auk134 | corona* )
	if [ ! -d ${pooldir}/${luser} ]
	then
		cd /g/g0
		/usr/bin/time find ${luser} -print | cpio -pdm ${pooldir}
	fi
	;;
OptiPlex980)
	targetdir=AAA_My_Jobs
	targetpath=${pooldir}
# 	if [ ! -d ${pooldir}/AAA_My_Jobs ]
# 	then
# 		cd /home/${luser}/Dropbox/
# 		/usr/bin/time find AAA_My_Jobs -print | cpio -pdmv ${pooldir}
# 	fi
	existingsize=$(zfs get recordsize ${pool} | awk /${pool}/{print\ \$3})
	numericsize=$(nice2num ${existingsize})
	if [ -z "${numericsize}" ]
	then
		((numericsize=128*__kibibyte))
	fi
	gen_blocksize=9
	((recordsize=2**gen_blocksize))
	for filenum in $(gen_range 0 ${max_files})
	do
		if [[ ${gen_blocksize} -gt ${ZFS_MAXBLOCKSHIFT}  || ${recordsize} -ge ${numericsize}  ]]
		then
			gen_blocksize=9
		fi
		((recordsize=2**gen_blocksize))
		if [ ! -d ${pooldir}/B_${recordsize} ]
		then
			zfs create ${pool}/B_${recordsize}
			zfs set recordsize=${recordsize} \
			    ${pool}/B_${recordsize}
			chown ${luser} ${pooldir}/B_${recordsize}
			chgrp ${luser} ${pooldir}/B_${recordsize}
		fi
		dd if=/dev/urandom \
		    of=${pooldir}/B_${recordsize}/file_${filenum} \
		    bs=${recordsize} count=512 iflag=fullblock
		((gen_blocksize++))
	done

	;;
\?)
	cd ~/Dropbox/
	/usr/bin/time find AAA_My_Jobs -print | cpio -pdmv ${pooldir}
	;;
esac


