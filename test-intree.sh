#!/bin/bash
#######################################################################
# Author Robert E. Novak
# email: novak5@llnl.gov, sailnfool@gmail.com
#
# This script will set up in-tree testing of ZFS, taking care to 
# install the necessary packages required for testing of ZFS
# depending on the 
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

USAGE="\r\n${0##*/} [-hn]\r\n
\t\tTest an in-tree copy of ZFS.  The default is to retrieve a copy\r\n
\t\tof the source tree from a repository, then give the user the\r\n
\t\tchoice to select a branch from that repository for testing.\r\n
\t\tThe default repository is a private fork.  The -s option\r\n
\t\tgives the option to select the [standard] default OpenZFS\r\n
\t\trepository and -r lets the user specify an alternate repository\r\n
\t-h\t\tPrint this message\r\n
\t-n\t\tSkip requesting which branch (no branch) to test\r\n
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
optionargs="hn"
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
# select which branch will be built for testing.  This next
# section of code should probably be placed in a source'd 
# script since it is also used in "test-intree"
####################
host=$(hostname)
if [ "${host}" = "slagi" ]
then
  ZFSPARENT="/tftpboot/global/novak5/github"
  mkdir -p ${ZFSPARENT}
else
  ZFSPARENT="$HOME/github"
fi

ZFSDIR="${ZFSPARENT}/zfs"
if [ ! -d ${ZFSDIR} ]
then
  echo "Could not find ${ZFSDIR}"
  exit 1
fi
cd ${ZFSDIR}
if [ "${skip_get_branch}" = 0 ]
then
	declare -A -g branch_name
	git branch -a | \
	  sed -n -e 's,remotes/origin/\([^H]\),\1,p' \
	  > /tmp/zfs_branches.$$.txt
	branchnumber=1
	while read branchname
	do
	  branch_name[${branchnumber}]=${branchname}
	  echo -e "${branchnumber}\t${branchname}"
	  ((branchnumber++))
	done < /tmp/zfs_branches.$$.txt
	read -p "Which Branch Number: " choice
	rm -f /tmp/zfs_branches.$$.txt
	
	####################
	# No matter the source, by default load the master branch,
	# then load the selected branch.
	####################
	git checkout ${branch_name[$choice]}
  # git checkout REN/9158-Block-Histogram
fi

####################
# Now we return to the building of ZFS
####################
sh autogen.sh
./configure
make -s -j$(nproc)

####################
# Install additional packages needed for the ZFS Test Suite (ZTS)
# This list of packages is also dependent on the release on which
# the test is being performed (Ubuntu, RHEL 7, etc.)
#
OS_RELEASE=$(lsb_release -i | cut -f 2)
case ${OS_RELEASE} in
  Ubuntu)
    sudo apt install ksh bc fio acl sysstat mdadm lsscsi parted attr \
      dbench nfs-kernel-server samba rng-tools pax linux-tools-common \
      selinux-utils quota
    ;;
  RedHatEnterpriseServer | RedHatEnterpriseWorkstation )

    ####################
    # WARNING!! WARNING!! WARNING!! Not yet tested
    # This needs a further test for RHEL 7 vs. RHEL 8
    ####################
    sudo yum install ksh bc fio acl sysstat mdadm lsscsi parted \
      attr dbench nfs-utils samba rng-tools pax perf
    ;;
  \?) #Invalid
    errecho "$-e" ${FUNCNAME} ${LINENO} \
      "Unknown Operating System ${OS_RELEASE}"
    exit 1
    ;;
esac
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
# zloop.sh: A wrapper to run ztest repeatedly with randomized
# arguments. The ztest command is a user space stress test designed
# to detect correctness issues by concurrently running a random set
# of test cases. If a crash is encountered, the ztest logs, any
# associated vdev files, and core file (if one exists) are collected
# and moved to the output directory for analysis.
#
sudo ./scripts/zloop.sh
# sudo ./scripts/zfs-tests.sh -vx
# vim: set syntax=bash, ts=2, sw=2, lines=55, columns=120,colorcolumn=78
