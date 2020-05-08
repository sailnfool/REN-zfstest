#!/bin/bash
if [ $# -gt 0 ]
then
	luser=$1
fi
case $(hostname) in
slag5 | auk134 | corona* )
	cd $HOME/..
	find ${luser} -print | cpio -pdm /tank
	;;
\?)
	cd ~/Dropbox/
	sudo /bin/time find AAA_My_Jobs -print | cpio -pdmv /tank
	;;
esac
