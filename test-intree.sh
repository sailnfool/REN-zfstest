#!/bin/bash
#######################################################################
# Author Robert E. Novak
# email: novak5@llnl.gov, sailnfool@gmail.com
#
# This script will set up in-tree testing of ZFS, taking care to
# install the necessary packages required for testing of ZFS
# depending on the Linux installation
# In the github wiki it recommends installing the following packages
# for Ubuntu.
# https://github.com/openzfs/zfs/wiki/Building-ZFS
#
#
# Get correct version of the source from github
#
source func.insufficient
source func.errecho
source func.debug
source zfunc.zfsparent

USAGE="\r\n${0##*/} [-hn]\r\n
\t\tTest an in-tree copy of ZFS. The default is to retrieve a copy\r\n
\t\tof the source tree from a repository, then give the user the\r\n
\t\tchoice to select a branch from that repository for testing.\r\n
\t\tThe default repository is a private fork.	The -s option\r\n
\t\tgives the option to select the [standard] default OpenZFS\r\n
\t\trepository and -r lets the user specify an alternate repository\r\n
\t-h\t\tPrint this message\r\n
\t-n\t\tSkip requesting which branch (no branch) to test\r\n
\t-u\t\tConfigure build for user space only\r\n
"

NUMARGS=0
if [ "${NUMARGS}" -gt 0 ]
then
	if [ $# -lt "${NUMARGS}" ]
	then
		insufficient ${0##*/} ${LINENO} ${NUMARGS}
	fi
fi

skip_get_branch=0
reconfigure=1
user_space=""
testing=0

####################
# Find out what operating system we are running
####################
OS_RELEASE=$(lsb_release -i | cut -f 2)
OS_REVISION=$(lsb_release -r | cut -f 2)

ZFSPARENT=$(zfsparent)
mkdir -p ${ZFSPARENT}
LAST_BRANCH=${ZFSPARENT}/.zfs_last_branch

errecho "Working from host $host"
errecho "Working with OS Release ${OS_RELEASE}"
errecho "Working with OS Release ${OS_REVISION}"
if [ -r /etc/toss-release ]
then
	errecho "This is a TOSS system $(cat /etc/toss-release)"
fi

optionargs="hntu"
while getopts ${optionargs} name
do
	case ${name} in
	h)
		errecho "-e" ${0##*/} ${LINENO} ${USAGE}
		exit 0
		;;
	n)
		skip_get_branch=1
		;;
	t)
		testing=1
		;;
	u)
		user_space="--with-config=user"
		;;
	\?)
		errecho "-e" ${0##*/} ${LINENO} "invalid option: -${OPTARG}"
		errecho "-e" ${0##*/} ${LINENO} ${USAGE}
		exit 1
		;;
	esac
done
####################
# Get the correct version of the source from github
# This small chunk of script will retrieve the list of branches
# that are available for this repository and allow the user to
# select which branch will be built for testing. This next
# section of code should probably be placed in a source'd
# script since it is also used in "test-intree"
####################

ZFSDIR="${ZFSPARENT}/zfs"
if [ ! -d ${ZFSDIR} ]
then
	echo "Could not find ${ZFSDIR}"
	exit 1
fi
errecho "Working with zfs in ${ZFSDIR}"
cd ${ZFSDIR}
if [ "${skip_get_branch}" = 0 ]
then
	declare -A -g branch_name
	tmpbranchlist=/tmp/zfs_branches.$$.txt
	git branch -a | \
		sed -n -e 's,^\(..\)\(.*\),\1	\2,p'> ${tmpbranchlist} 
	branchnumber=1
	OFS=$IFS
	IFS="	"
	while read prefix branchname
	do
		branch_name[${branchnumber}]=${branchname}
		printf "%s %4d\t%s\n" ${prefix} ${branchnumber} ${branchname}
		((branchnumber++))
	done < ${tmpbranchlist}
	IFS=$OFS
	read -p "Which Branch Number [1]: " choice
	if [ -z "${choice}" ]
	then
		choice=1
	fi
	rm -f ${tmpbranchlist}

	####################
	# No matter the source, by default load the master branch,
	# then load the selected branch.
	####################
	git checkout ${branch_name[$choice]}
	new_branch=${branch_name[$choice]}
	if [ -f ${LAST_BRANCH} ]
	then
		old_branch=$(cat ${LAST_BRANCH})
	else
		echo "0" > ${LAST_BRANCH}
	fi
	if [ "${old_branch}" = "${new_branch}" ]
	then
		reconfigure=0
	else
		reconfigure=1
		echo ${new_branch} > ${LAST_BRANCH}
	fi
fi

####################
# Now we return to the building of ZFS
####################
if [ "${reconfigure}" -eq "1" ]
then
	configtxt=/tmp/zfs.$$.config.txt
	kerneltxt=/tmp/zfs.$$.kernel.txt
	sh autogen.sh
	./configure ${user_space} 2>&1 | tee ${configtxt}
	grep "checking kernel source directory" ${configtxt} >> ${kerneltxt}
	grep "checking kernel build directory" ${configtxt} >> ${kerneltxt}
	grep "checking kernel source version" ${configtxt} >> ${kerneltxt}
	uname -r >> ${kerneltxt}
fi
make -s -j$(nproc)

####################
# Install additional packages needed for the ZFS Test Suite (ZTS)
# This list of packages is also dependent on the release on which
# the test is being performed (Ubuntu, RHEL 7, etc.)
####################
slagname='slag[i0-9][0-9]*'
jetname='jet[i0-9][0-9]*'
if [[ ! "${host}" =~ ${slagname} && \
	! "${host}" =~ ${jetname} ]]
then
	errecho "We are on host ${host} not a slag/jet node"
	case ${OS_RELEASE} in
	Ubuntu | Debian)
		sudo apt install ksh bc fio acl sysstat mdadm lsscsi \
		    parted attr dbench nfs-kernel-server samba rng-tools \
		    pax linux-tools-common selinux-utils quota
		;;
	RedHatEnterpriseWorkstation)

		####################
		# WARNING!! WARNING!! WARNING!! Not yet tested
		# This needs a further test for RHEL 7 vs. RHEL 8
		####################
		version7name='7\..*'
		version8name='8\..*'
		if [[ "${OS_REVISION}" =~ ${version7name} ]]
		then
			sudo yum install ksh bc fio acl sysstat mdadm \
			    lsscsi parted attr dbench nfs-utils samba \
			    rng-tools pax perf
		elif [[ "${OS_REVISION}" =~ ${version8name} ]]
		then
			sudo dnf install ksh bc fio acl sysstat mdadm \
			    lsscsi parted attr dbench nfs-utils samba \
			    rng-tools pax perf
		fi
		;;
	RedHatEnterpriseServer)
		####################
		# Do Nothing for TOSS servers
		####################
		if [[ ! -r /etc/toss-release ]]
		then
			errecho "Red Hat Enterprise Server but not " \
			    "a TOSS release\n"
			exit 1
		fi
		;;

	\?) #Invalid
		errecho "Unknown Operating System ${OS_RELEASE}"
		exit 1
		;;
	esac
else
	errecho "No update to tools required for zfs on TOSS"
fi
#
# zfs-helper.sh: Certain functionality (i.e. /dev/zvol/) depends
# on the ZFS provided udev helper scripts being installed on the
# system. This script can be used to create symlinks on the system
# from the installation location to the in-tree helper. These
# links must be in place to successfully run the ZFS Test Suite.
# The -i and -r options can be used to install and remove the
# symlinks.
#
sudo ./scripts/zfs-helpers.sh -i

#
# zfs.sh: The freshly built kernel modules can be loaded using zfs.sh.
# This script can later be used to unload the kernel modules with the
# -u option.
#
sudo ./scripts/zfs.sh

#
# This process originally developed for the histogram block size 
# output of zdb.  Here we exercise the single test of this
# functionality that has been added to zdb
#
if [ ${testing} -eq 1 ]
then
	testpath=tests/functional/cli_root/zdb
	./scripts/zfs-tests.sh -t ${testpath}/zdb_block_size_histogram
fi
#
# zloop.sh: A wrapper to run ztest repeatedly with randomized
# arguments. The ztest command is a user space stress test designed
# to detect correctness issues by concurrently running a random set
# of test cases. If a crash is encountered, the ztest logs, any
# associated vdev files, and core file (if one exists) are collected
# and moved to the output directory for analysis.
#
sudo ./scripts/zloop.sh
# sudo ./scripts/zfs-tests.sh -vx
