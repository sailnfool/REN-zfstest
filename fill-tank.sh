#!/bin/bash
if [ $EUID != 0 ]
then
	echo "Not root"
	exit -1
fi
if [ $# -gt 0 ]
then
	luser=$1
fi
case $(hostname) in
slag5 | slag6 | auk134 | corona* )
	cd $HOME/..
	/usr/bin/time find ${luser} -print | cpio -pdm /tank
	;;
\?)
	cd ~/Dropbox/
	/usr/bin/time find AAA_My_Jobs -print | cpio -pdmv /tank
	;;
esac
