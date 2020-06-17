#!/bin/bash
source func.errecho
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

USAGE="\n${0##*/} [-hd] [-p <pool>]\n
\t\tfill a zfs tank.  The default fills the default tank by doing a\n
\t\tcpio of the user's home directory.  The options specify creating\n
\t\ta set of files of varying blocksizes to fill the tank\n
\t-h\t\tPrint this message\n
\t-d\t\tTurn on diagnostics (set -x)\n
\t-p\t<pool>\tName of the pool to be used\n
\t\t\tThe default name is tank\n
"
####################
# The default tank name is tank.  The resulting ZFS directory will
# be /tank
#
# The default location if there are vdevs created "by file" they
# will be in /zpool/files/file-xx where xx varies from 0 -> -f #
####################
optionargs="hdp:"
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
max_blocksize=128K
ZFS_MAXBLOCKSHIFT=24
re_number='^[0-9]+$'
max_files=${ZFS_MAXBLOCKSHIFT}\*2

while getopts ${optionargs} name
do
	case ${name} in
	h)
		errecho "-e" ${USAGE}
		exit 0
		;;
	d)
		debug=1
		set -x
		;;
	p)
		poolspecified=1
		pool="${OPTARG}"
		pooldir="/${pool}"
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
	echo "You must be root.  You are $(id -ur)"
	exit -1
fi
case $(hostname) in
slag5 | slag6 | auk134 | corona* )
	zfs destroy -r ${pool}
	cd /
	zpool destroy ${pool}
	rm -rf ${pooldir} /vdevs
	;;
OptiPlex980)
	zfs destroy -r ${pool}
	cd /
	zpool destroy ${pool}
	rm -rf ${pooldir} /vdevs
	;;
\?)
	cd ~/Dropbox/
	/usr/bin/time find AAA_My_Jobs -print | cpio -pdmv ${pooldir}
	;;
esac


