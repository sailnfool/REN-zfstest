#!/bin/ksh -p
function histo_get_pool_size
{
	if [ $# -ne 1 ]
	then
		$(insufficient 1)
	fi
	typeset pool=$1
	real_pool_size=0
	re_number='^[0-9]+$'

	let real_pool_size=$(zpool list -p|awk "/${pool}/{print \$2}")

	if [ -z "${real_pool_size}" ]
	then
		errecho "Could not retrieve the size of ${pool}"
		exit -1
	elif [[ ! ${real_pool_size} =~ ${re_number} ]]
	then
		errecho "pool size is not numeric: ${real_pool_size}"
		exit -1
	fi
	echo ${real_pool_size}
}

