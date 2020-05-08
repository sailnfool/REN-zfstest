#!/bin/bash
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
if [ -r /root/.bashrc.${USER}.save ]
then
	sudo cp /root/.bashrc.${USER}.save /root/.bashrc
	chown root /root/.bashrc
else
	sudo cp /root/.bashrc /root/.bashrc.${USER}.save
	sudo chown ${USER} /root/.bashrc.${USER}.save
fi
sudo echo "export PATH=$HOME/github/zfs/bin:$PATH" >> /root/.bashrc
if [ ! -d /zpool ]
then
	sudo mkdir -p /zpool
 	sudo chown ${USER} /zpool
 	sudo chgrp ${USER} /zpool
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
sudo (source /root/.bashrc; zpool create tank ${POOLNAMES})
sudo (source /root/.bashrc; zpool status tank)
sudo (source /root/.bashrc; chown $USER /tank)
sudo (source /root/.bashrc; chgrp $USER /tank)
sudo mv /root/.bashrc.${USER}.save /root/.bashrc
chown root /root/.bashrc
