#!/bin/bash
USAGE="${0##*/} [UL]\n
\tCollects and prints information about the devices in /dev/disk/by-vdev\n
\tThe listed devices are those with prefex U or L (default U)\n
\t-s\t\tSort the devices by size, then by number\n
"
sortkey=""
optionargs="hs"
NUMARGS=0
while getopts ${optionargs} name
do
	case ${name} in
	h)
		echo -e ${USAGE}
		exit 0
		;;
	s)
		sortkey="--key=4h"
		;;
	\?)
		echo "invalid option ${OPTARG}"
		echo -e ${USAGE}
		exit -1
		;;
	esac
done
shift "$((OPTIND - 1 ))"
if [ $# -lt $NUMARGS ]
then
	echo "Insufficient arguments"
	exit -1
fi
if [ $# -eq 1 ]; then
	prefix=$1
	shift
else
	prefix=U
fi
cd /dev/disk/by-vdev
declare -A devname scsiname sdname tsize model vendor accesstype
echo -e "number\tv-dev\t/dev\tsize\tAccess\tModel\tVendor\tname" > /tmp/header.$$
rm -f /tmp/foo.txt
for i in ${prefix}*
do
	number=$(echo $i|sed 's/^.//')
	cd /dev/disk/by-vdev
	devname[$i]=$(lsblk $i | tail -1 | cut -d ' ' -f 1)
	lsblk $i | tail -1 >> /tmp/foo.txt
	accesstype[$i]=$(lsblk $i | tail -1 | sed -e 's/  */ /g' | cut -d ' ' -f 6)
	cd /dev/disk/by-id
	scsiname[$i]=$(ls scsi*${devname[$i]})
	sdname[$i]=$(ls -l ${scsiname[$i]}|sed 's/.*-> ..\/..\///')
	cd /dev/disk/by-vdev
	tsize[$i]=$(lsblk $i|tail -1|awk '{print $4}')
	model[$i]=$(lsblk --output MODEL /dev/${sdname[${i}]}|head -2|tail -1)
	vendor[$i]=$(lsblk --output VENDOR /dev/${sdname[${i}]}|head -2|tail -1)
	echo -e -n "$number\t$i\t" >> /tmp/devlist.$$
	echo -e -n "${sdname[${i}]}\t" >> /tmp/devlist.$$
	echo -e -n "${tsize[${i}]}\t" >> /tmp/devlist.$$
	echo -e -n "${accesstype[${i}]}\t" >> /tmp/devlist.$$
	echo -e -n "${model[${i}]}\t" >> /tmp/devlist.$$
	echo -e -n "${vendor[${i}]}\t" >> /tmp/devlist.$$
	echo -e -n "${devname[${i}]}" >> /tmp/devlist.$$
	echo "" >>/tmp/devlist.$$
done
sort ${sortkey} --key="1n" /tmp/devlist.$$ >> /tmp/header.$$
cat /tmp/header.$$ | more
rm -f /tmp/devlist.$$ /tmp/header.$$

