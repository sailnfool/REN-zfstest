#!/bin/ksh
source func.kerrecho
source func.kinsufficient
source func.kgenrange
source func.kkbytes
source func.knice2num
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
function histo_get_pool_size
{
	if [ $# -ne 1 ]
	then
		insufficient 1
	fi
	typeset pool=$1
	typeset -i pool_size=0

	let pool_size=$(zpool list -p|awk "/${pool}/{print \ \$2}")

	if [ -z "${pool_size}" ]
	then
		errecho "Could not retrieve the size of ${pool}"
		exit -1
	fi
	echo ${pool_size}
}

SPA_MAXBLOCKSHIFT=24

function populate_pool
{
	if [ $# -ne 1 ]
	then
		insufficient 1
	fi
	typeset pool=$1

	set -A recordsizes
	typeset -i pool_size=0
	typeset -i recordsize
	typeset -i min_recordsizebits=9 #512
	typeset -i max_recordsizebits=SPA_MAXBLOCKSHIFT+1 #16 MiB
	typeset -i this_recordsize
	typeset -i this_record_index
	typeset -i sum_filesizes=0

	let pool_size=$(get_pool_size ${pool}

	for recordsize in gen_range(min_recordsizebits max_recordsizebits)
	do
		((recordsizes[recordsize]= 1ULL '<<' recordsize))
		((sum_filesizes+=recordsizes[recordsize]))
	done

	((max_files=pool_size % sum_filesizes))

	this_record_index=min_recordsizebits

	for filenum in $(gen_range 0 ${max_files})
	do
		if [ this_record_index -gt max_recordsizebits ]
		then
			let this_record_index=min_recordsizebits
		fi
		let this_recordsize=recordsizes[this_record_index]
		if [ ! -d ${pool}/B_${this_recordsize} ]
		then
			zfs create ${pool}/B_${this_recordsize}
			zfs set recordsize=${this_recordsize} \
			    ${pool}/B_{this_recordsize}
		fi

		####################
		# Create the files in the devices and datasets of the
		# right size.  The files are filled with random data
		# to defeat the compression
		# Alternatively we could use truncate for a faster
		# file creation of sparse files.
		####################
		dd if=/dev/urandom \
		    of=${pool}/B_${this_recordsize}/file_${filenum} \
		    bs=${this_recordsize} count=1 iflag=fullblock

		((this_record_index++))
	done
}

function check_histo_test_pool
{
	if [ $# -ne 1 ]
	then
		log_fail \
		"check_histo_test_pool insufficient parameters"
	fi	
	typeset pool=$1

	set -A recordsizes
	set -A recordcounts
	typeset -i pool_size=0
	typeset -i recordsize
	typeset -i min_recordsizebits=9 #512
	typeset -i max_recordsizebits=SPA_MAXBLOCKSHIFT+1
	typeset -i this_recordsize
	typeset -i this_record_index
	typeset -i sum_filesizes=0
	typeset dumped
	typeset stripped

	let pool_size=$(get_pool_size ${pool}

	for recordsize in gen_range(min_recordsizebits max_recordsizebits)
	do
		((recordsizes[recordsize]= 1ULL '<<' recordsize))
		((sum_filesizes+=recordsizes[recordsize]))
	done

	dumped="/tmp/${pool}_dump.txt"
	stripped="/tmp/${pool}_stripped.txt"

	# log_must zdb -Pbbb ${pool} | \
	zdb -Pbbb ${pool} | \
	    tee ${dumped} | \
	    sed -e '1,/^block[ 	][ 	]*psize[ 	][ 	]*lsize/d' \
	    > ${stripped}

	((max_files=pool_size % sum_filesizes))

	this_record_index=min_recordsizebits

	for filenum in $(gen_range 0 ${max_files})
	do
		if [ this_record_index -gt max_recordsizebits ]
		then
			let this_record_index=min_recordsizebits
		fi
		((recordcounts[this_record_index]++))

		((this_record_index++))
	done

	errecho "Comparisons for ${pool}"
	errecho "Blocksize\tCount\tpsize\tlsize\tasize"
	for recordsize in gen_range(min_recordsizebits max_recordsizebit)
	do
		psize=$(awk "/${recordsize}/{print\ \$2}" < ${stripped}
		lsize=$(awk "/${recordsize}/{print\ \$5}" < ${stripped}
		asize=$(awk "/${recordsize}/{print\ \$8}" < ${stripped}
		errecho "${recordsize}\t${recordcounst[${recordsize}]}\t${psize}\t${lsize}\t${asize}"
	done
}
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
	echo "${USAGE}"
	exit -1
fi
case $(hostname) in
slag5 | slag6 | auk134 | corona* )
#	if [ ! -d ${pooldir}/${luser} ]
#	then
#		cd /g/g0
#		/usr/bin/time find ${luser} -print | cpio -pdm ${pooldir}
#	fi
	targetpath=${pooldir}
	existingsize=$(zfs get recordsize ${pool} | \
		awk /${pool}/{print\ \$3})
	numericsize=$(nice2num ${existingsize})
	if [ -z "${numericsize}" ]
	then
		numericsize=128*${__kbibibyte}
	fi
	let gen_blocksize=9 
	recordsize=$(echo "2 ^ ${gen_blocksize}"|bc)
	for filenum in $(gen_range 0 ${max_files})
	do
		if [[ ${gen_blocksize} -gt ${ZFS_MAXBLOCKSHIFT} || \
			${recordsize} -ge ${numericsize} ]]
		then
			let gen_blocksize=9
		fi
		recordsize=$(echo "2 ^ ${gen_blocksize}"|bc)
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
		    bs=${recordsize} count=1024 iflag=fullblock
		((gen_blocksize++))
		echo "Completed ${filenum} of ${max_files}"
	done
	;;
OptiPlex980|Inspiron3185)
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
		numericsize=128*${__kibibyte}
	fi
	gen_blocksize=9
	recordsize=$(echo "2 ^ ${gen_blocksize}"|bc)
	for filenum in $(gen_range 0 ${max_files})
	do
		if [[ ${gen_blocksize} -gt ${ZFS_MAXBLOCKSHIFT}  || \
			${recordsize} -ge ${numericsize}  ]]
		then
			let gen_blocksize=9
		fi
		recordsize=$(echo "2 ^ ${gen_blocksize}"|bc)
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


