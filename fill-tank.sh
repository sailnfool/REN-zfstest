#!/bin/bash
case $(hostname) in
slag5 | auk134 | corona* )
	cd $HOME/..
	find ${USER} -print | cpio -pdm /tank
	;;
\?)
	cd ~/Dropbox/
	sudo /bin/time find AAA_My_Jobs -print | cpio -pdmv /tank
	;;
esac
