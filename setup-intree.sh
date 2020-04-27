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
#######################################################################
OS_RELEASE=$(lsb_release -i | cut -f 2)
case ${OS_RELEASE} in
  Ubuntu)
    sudo apt install build-essential autoconf automake libtool \
      gawk alien fakeroot dkms libblkid-dev uuid-dev libudev-dev \
      libssl-dev zlib1g-dev libaio-dev libattr1-dev libelf-dev \
      linux-headers-$(uname -r) python3 \
      python3-dev python3-setuptools python3-cffi libffi-dev

    ####################
    # When I went to do testing on .scritps/zloop.sh, I discovered that
    # libtool was missing.  The tool was there, but not the binary
    # command line interface since Ubuntu places that in libtool-bin
    ####################
    sudo apt install libtool-bin
    ;;
  RedHatEnterpriseWorkstation | RedHatEnterpriseServer )

    ####################
    # WARNING!! WARNING!! WARNING!! Not yet tested
    # This needs a further test for RHEL 7 vs. RHEL 8
    ####################
    sudo yum install epel-release gcc make autoconf automake \
      libtool rpm-build dkms libtirpc-devel libblkid-devel \
      libuuid-devel libudev-devel openssl-devel zlib-devel \
      libaio-devel libattr-devel elfutils-libelf-devel \
      kernel-devel-$(uname -r) python python2-devel \
      python-setuptools python-cffi libffi-devel
    ;;
  \?) #Invalid
    errecho "$-e" ${FUNCNAME} ${LINENO} \
      "Unknown Operating System ${OPTARG}"
    exit 1
    ;;
esac

####################
# The assumption here is that we are cloning into a github subdirectory
# of the user's HOME directory, since that will hopefully be 
# intuitively obvious.
####################
ZFSPARENT="$HOME/github"
ZFSHOME="${ZFSPARENT}/zfs"
cd ${ZFSPARENT}

####################
# If there has been a previous build, we want to first unload
# any of the kernel modules that the build loaded into the kernel
# to avoid contamination with mixed modules.
####################
LOAD_UNLOAD_SCRIPT="./scripts/zfs.sh"
if [ -f ${ZFSHOME}/${LOAD_UNLOAD_SCRIPT} ]
then
  cd ${ZFSHOME}
  sudo ${LOAD_UNLOAD_SCRIPT} -u
  cd ${ZFSPARENT}
fi

####################
# Remove the old copy of zfs that may have existed 
####################
cd ${ZFSPARENT}
rm -rf zfs

####################
# This should be parameterized to load either a tree from the stable
# builds or from a forked copy of zfs under test with branches.  For
# now we know we are testing a forked copy which may contain branches
# that are to be tested.
####################
# git clone https://github.com/openzfs/zfs
/usr/bin/time git clone https://github.com/sailnfool/zfs

echo "run test-intree to test this cloned copy of ZFS"
