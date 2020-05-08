#!/bin/bash
if [ $# -gt 0 ]
then
	luser=$1
else
	echo "Missing username"
	echo "${0##*/} <username>
	exit -1
fi
#######################################################################
# Author: Robert E. Novak
# email: novak5@llnl.gov, sailnfool@gmail.com
#
# create a zpool in the root directory of the current drive. If this
# gets more usage, make the location of the pool a parameter to this
# script.
#
# The pool is created by root, but the ownership is transferred to
# the user invoking the script.
#######################################################################
set -x
if [ $EUID != 0 ]
then
	echo "Not root"
	exit -1
fi
if [ -r /root/.bashrc.${luser}.save ]
then
	cp /root/.bashrc.${luser}.save /root/.bashrc
	chown root /root/.bashrc
else
	cp /root/.bashrc /root/.bashrc.${luser}.save
	chown ${luser} /root/.bashrc.${luser}.save
fi
export PATH=~${luser}/github/zfs/bin:~${luser}/bin:$PATH

case $(hostname) in
slag5)
	zpool create tank /dev/disk/by-vdev/U?
	zpool status tank
	chown ${luser} /tank
	chgrp ${luser} /tank
	;;
slag6)
	zpool create tank /dev/disk/by-vdev/U1?
	zpool status tank
	chown ${luser} /tank
	chgrp ${luser} /tank
	;;
auk134 | rnovak-Optiplex-980)
	if [ ! -d /zpool ]
	then
		mkdir -p /zpool
	 	chown ${luser} /zpool
	 	chgrp ${luser} /zpool
	fi
	####################
	# create 8 files of 8GB each for a total pool size of 64GB
	####################
	ZPOOL=/zpool/file
	for i in 1 2 3 4 5 6 7 8
	do
	  if [ ! -f ${ZPOOL}${i} ]
	  then
	    dd if=/dev/zero of=${ZPOOL}${i} bs=1G count=8 &> /dev/null
	  fi
	  POOLNAMES="${POOLNAMES} ${ZPOOL}${i}"
	done
	zpool create tank ${POOLNAMES}
	zpool status tank
	chown ${luser} /tank
	chgrp ${luser} /tank
	;;
\?)
	echo "Unrecognized hostname"
	;;
esac
mv /root/.bashrc.${luser}.save /root/.bashrc
chown root /root/.bashrc
