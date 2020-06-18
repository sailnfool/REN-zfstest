#!/bin/ksh -p
source func.kerrecho
source func.kinsufficient
source func.kkbytes
source func.knice2num
source zfunc.histochecktestpool
source zfunc.histogetpoolsize
source zfunc.histopopulatepool
source zfunc.histologfile
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

USAGE="\n${0##*/} [-hd] [-b blksize] [-p <pool>] [-f <#>] <user>\n
\t\tfill a zfs tank.  The options specify creating\n
\t\ta set of files of varying blocksizes to fill the tank\n
\t-h\t\tPrint this message\n
\t-d\t\tTurn on diagnostics (set -x)\n
\t-b\t<blksize>\tThe size of the blocks dd will use for\n
\t\t\tcreating file vdevs, see dd documentation for\n
\t\t\tspecifying sizes\n
\t-o\t\tOverlook filling the pool and skip to testing\n
\t\t\tTurns on testing by default\n
\t-p\t<pool>\tName of the pool to be used\n
\t\t\tThe default name is tank\n
\t-s\t<blksize>\tThe maximum block size to create.  The block\n
\t\t\tsizes will be distributed across the number of files\n
\t\t\tcreated.\n
\t-t\t\tTest that the files output by the test match the\n
\t\t\tblocksizes created. This should be a multiple of 24\n
"
####################
# The default tank name is tank.  The resulting ZFS directory will
# be /tank
#
# The default location if there are vdevs created "by file" they
# will be in /zpool/files/file-xx where xx varies from 0 -> -f #
####################
optionargs="hb:df:op:s:t"
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
overlookfill=0
testspecified=0
max_blocksize=128*__kibibytes
ZFS_MAXBLOCKSHIFT=24
re_number='^[0-9]+$'

((max_files=${ZFS_MAXBLOCKSHIFT} * 2))

while getopts ${optionargs} name
do
	case ${name} in
	h)
		echo -en ${USAGE}
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
	o)
		overlookfill=1
		testspecified=1
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
		testspecified=1
		;;
	\?)
		errecho "-e" "invalid option -${OPTARG}"
		echo -en ${USAGE}
		exit -1
		;;

	esac
done
shift "$(($OPTIND - 1 ))"
if [ $(id -u) != 0 ]
then
	echo "You must be root.  You are $(id -ur)"
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
case $(hostname) in
slag5 | slag6 | auk134 | corona* )
#	if [ ! -d ${pooldir}/${luser} ]
#	then
#		cd /g/g0
#		/usr/bin/time find ${luser} -print | cpio -pdm ${pooldir}
#	fi
	if [ ${overlookfill} -eq 0 ]
	then
		histo_populate_pool ${pool}
	fi
	if [ ${testspecified} -eq 1 ]
	then
		histo_check_test_pool ${pool}
	fi
	;;
OptiPlex980|Inspiron3185)
	if [ ${overlookfill} -eq 0 ]
	then
		histo_populate_pool ${pool}
	fi
	if [ ${testspecified} -eq 1 ]
	then
		histo_check_test_pool ${pool}
	fi
	;;
\?)
	if [ ${overlookfill} -eq 0 ]
	then
		histo_populate_pool ${pool}
	fi
	if [ ${testspecified} -eq 1 ]
	then
		histo_check_test_pool ${pool}
	fi
	;;
esac
# vim: set syntax=ksh, lines=55, columns=120,colorcolumn=78
