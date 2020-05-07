#!/bin/bash
cd ~/Dropbox/
sudo /bin/time find AAA_My_Jobs -print | cpio -pdmv /tank
