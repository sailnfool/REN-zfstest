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
source func.errecho
source func.insufficient

USAGE="\r\n${0##*/} [-hus] [-r <repo>]\r\n
\t\tTest an in-tree copy of ZFS.  	The default is to retrieve a copy\r\n
\t\tof the source tree from a repository, then give the user the\r\n
\t\tchoice to select a branch from that repository for testing.\r\n
\t\tThe default repository is a private fork.  	The -s option\r\n
\t\tgives the option to select the [standard] default OpenZFS\r\n
\t\trepository and -r lets the user specify an alternate repository\r\n
\t-h\t\tPrint this message\r\n
\t-c\t\tUse the existing clone of the last repository deposited\r\n
\t\t\tin \$HOME/github/zfs without reloading from a repository\r\n
\t-s\t\tClone from the standard OpenZFS repository\r\n
\t-r\t<repo>\tClone from <repo>\r\n
\t-u\t\tRunning in User Mode, no need for kernel modules\r\n
"
NUMARGS=0
if [ "${NUMARGS}" -gt 0 ]
then
	if [ $# -lt "${NUMARGS}" ]
	then
		insufficient ${0##*/} ${LINENO} ${NUMARGS}
	fi
fi
REPO_REN_BRANCH="https://github.com/sailnfool/zfs"
REPO_STANDARD="https://github.com/openzfs/zfs"
REPO=${REPO_REN_BRANCH}
use_existing_clone=0
user_mode_only=0
LAST_BRANCH=$HOME/.zfs_last_branch

####################
# Find out what operating system we are running
####################
OS_RELEASE=$(lsb_release -i | cut -f 2)
OS_REVISION=$(lsb_release -r | cut -f 2)

####################
# The assumption here is that we are cloning into a github subdirectory
# of the user's HOME directory, since that will hopefully be 
# intuitively obvious.
# However, 
####################
host=$(hostname)
case ${host} in
slagi|jet*)
	ZFSPARENT="/tftpboot/global/novak5/github"
	;;
*)
	ZFSPARENT="$HOME/github"
	;;
esac
mkdir -p ${ZFSPARENT}

errecho "Working from host $host"
errecho "Working with OS Release ${OS_RELEASE}"
errecho "Working with OS Revision ${OS_REVISION}"
if [ -r /etc/toss-release ]
then
	errecho "This is a TOSS system $(cat /etc/toss-release)"
fi

optionargs="hcr:su"
while getopts ${optionargs} name
do
	case ${name} in
		h)
			errecho -e ${USAGE}
			exit 0
			;;
		c)
			use_existing_clone=1
			;;
		s)
			REPO=${REPO_STANDARD}
			;;
		r)
			REPO=${OPTARG}
			;;
		u)
			user_mode_only=1
			;;
		\?)
			errecho "-e" "invalid option: -${OPTARG}"
			errecho "-e" ${USAGE}
			exit 1
			;;
	esac
done
slagname='slag[i0-9][0-9]*'
jetname='jet[i0-9][0-9]*'
if [[ ! "${host}" =~ ${slagname} && \
	! "${host}" =~ ${jetname} ]]
then
	errecho "Installing tools required for zfs"
	case ${OS_RELEASE} in
		Ubuntu | Debian )
			sudo apt install build-essential autoconf \
			    automake libtool gawk alien fakeroot dkms \
			    libblkid-dev uuid-dev libudev-dev libssl-dev \
			    zlib1g-dev libaio-dev libattr1-dev libelf-dev \
			    linux-headers-$(uname -r) python3 python3-dev \
			    python3-setuptools python3-cffi libffi-dev

			####################
			# When I went to do testing on .scritps/zloop.sh,
			# I discovered that libtool was missing. The tool
			# was there, but not the binary command line
			# interface since Ubuntu places that in libtool-bin
			####################
			sudo apt install libtool-bin
			;;

		RedHatEnterpriseWorkstation)
			####################
			# WARNING!! WARNING!! WARNING!! Not yet tested
			# Works for RedHatEnterprise...
			# This needs a further test for RHEL 7 vs. RHEL 8
			####################
			version7name='7\..*'
			version8name='8\..*'
			if [[ "${OS_REVISION}" =~ ${version7name} ]]
			then
				sudo yum install epel-release gcc make \
				    autoconf automake libtool rpm-build \
				    dkms libtirpc-devel libblkid-devel \
				    libuuid-devel libudev-devel \
				    openssl-devel zlib-devel libaio-devel \
				    libattr-devel elfutils-libelf-devel \
				    kernel-devel-$(uname -r) python \
				    python2-devel python-setuptools \
				    python-cffi libffi-devel
			else
			  	if [[ "$OS_REVISION" =~ ${version8name} ]]
			  	then
			  	  	sudo dnf install gcc make autoconf \
					    automake libtool rpm-build dkms \
					    libtirpc-devel libblkid-devel \
					    libuuid-devel libudev-devel \
					    openssl-devel zlib-devel \
					    libaio-devel libattr-devel \
					    elfutils-libelf-devel \
					    kernel-devel-$(uname -r) \
					    python3 python3-devel \
					    python3-setuptools python3-cffi \
					    libffi-devel
			  	fi
			fi
			;;
		RedHatEnterpriseServer )
			####################
			# DO NOTHING.  	TOSS Servers need no changes
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
####################
# The assumption here is that we are cloning into a github subdirectory
# of the user's HOME directory, since that will hopefully be 
# intuitively obvious.
####################
ZFSHOME="${ZFSPARENT}/zfs"
cd ${ZFSPARENT}

####################
# If there has been a previous build, we want to first unload
# any of the kernel modules that the build loaded into the kernel
# to avoid contamination with mixed modules.
####################
LOAD_UNLOAD_SCRIPT="./scripts/zfs.sh"
if [[ -f ${ZFSHOME}/${LOAD_UNLOAD_SCRIPT} && \
	"user_mode_only" = "0" ]]
then
	cd ${ZFSHOME}
	echo "Super user required to unload old kernel modules"
	sudo ${LOAD_UNLOAD_SCRIPT} -u
	cd ${ZFSPARENT}
fi

####################
# Remove the old copy of zfs that may have existed 
####################
cd ${ZFSPARENT}
if [ "${use_existing_clone}" -eq 0 ]
then
	rm -rf zfs
	if [ -f ${LAST_BRANCH} ]
	then
		rm -rf ${LAST_BRANCH}
	fi
fi

####################
# This should be parameterized to load either a tree from the stable
# builds or from a forked copy of zfs under test with branches.  	For
# now we know we are testing a forked copy which may contain branches
# that are to be tested.
####################
# git clone https://github.com/openzfs/zfs
if [ "${use_existing_clone}" -eq 0 ]
then
	/usr/bin/time git clone ${REPO}
	rm -rf ${LAST_BRANCH}
fi

echo "${0##*/}: run test-intree to test this cloned copy of ZFS"
