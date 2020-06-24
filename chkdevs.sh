#!/bin/bash
USAGE="${0##*/} [UL]\n
\tCollects and prints information about the devices in /dev/disk/by-vdev\n
\tThe listed devices are those with prefex U or L (default U)\n
"
optionargs="h"
NUMARGS=0
while getopts ${optionargs} name
do
	case ${name} in
	h)
		echo -e ${USAGE}
		exit 0
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
declare -A devname scsiname sdname tsize model vendor
echo "number	v-dev	/dev	size	Model	Vendor"
for i in ${prefix}*
do
	number=$(echo $i|sed 's/^.//')
	devname[$i]=$(lsblk $i | tail -1 | cut -d ' ' -f 1)
	cd /dev/disk/by-id
	scsiname[$i]=$(ls scsi*${devname[$i]})
	sdname[$i]=$(ls -l ${scsiname[$i]}|sed 's/.*-> ..\/..\///')
	cd /dev/disk/by-vdev
	tsize[$i]=$(lsblk $i|tail -1|awk '{print $4}')
	model[$i]=$(lsblk --output MODEL /dev/${sdname[${i}]}|head -2|tail -1)
	vendor[$i]=$(lsblk --output VENDOR /dev/${sdname[${i}]}|head -2|tail -1)
	echo "$number	$i	${sdname[${i}]}	${tsize[${i}]}	${model[${i}]} ${vendor[${i}]}" >> /tmp/devlist.$$
done
sort -n  /tmp/devlist.$$
rm -f /tmp/devlist.$$

