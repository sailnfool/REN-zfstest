#!/bin/ksh -p
SPA_MAXBLOCKSHIFT=24

function histo_populate_pool
{
	if [ $# -ne 1 ]
	then
		log_note "histo_populate_test_pool: insufficient parameters"
		log_fail "hptp: 1 requested $# received"
	fi
	typeset pool=$1

	set -A recordsizes
	typeset -i min_rsbits=9 #512
	typeset -i max_rsbits=SPA_MAXBLOCKSHIFT #16 MiB
	typeset -i sum_filesizes=0
	re_number='^[0-9]+$'

	let histo_pool_size=$(histo_get_pool_size ${pool})
	if [[ ! ${histo_pool_size} =~ ${re_number} ]]
	then
		log_fail "histo_pool_size is not numeric ${pool_size}"
	fi
	let max_pool_record_size=$(zfs get -p recordsize ${pool}| awk "/${pool}/{print \$3}")
	if [[ ! ${max_pool_record_size} =~ ${re_number} ]]
	then
		log_fail "hptp: max_pool_record_size is not numeric ${max_pool_record_size}"
	fi

	sum_filesizes=$(echo "2^21"|bc)
	((min_pool_size=12*sum_filesizes))
	if [ ${histo_pool_size} -lt ${min_pool_size} ]
	then
		log_note "hptp: Your pool size ${histo_pool_size}"
		log_fail "hptp: is less than minimum ${min_pool_size}"
	fi
	this_ri=min_rsbits
	file_num=0
	total_count=0
	###################
	# generate 10% + 20% + 30% + 40% = 100% of the filespace
	# attempting to use 100% will lead to no space left on device
	###################
	for pass in 10 20 30 31
	do
		((thiscount=(((histo_pool_size*pass)/100)/sum_filesizes)))

		((total_count+=thiscount))
		for rb in $(seq ${min_rsbits} ${max_rsbits})
		do
			this_rs=$(echo "2^${rb}" | bc)
			if [ ${this_rs} -gt ${max_pool_record_size} ]
			then
				continue
			fi
	
			if [ ! -d /${pool}/B_${this_rs} ]
			then
				zfs create ${pool}/B_${this_rs}
				zfs set recordsize=${this_rs} \
				    ${pool}/B_${this_rs}
			fi
			####################
			# Create the files in the devices and datasets
			# of the right size.  The files are filled
			# with random data to defeat the compression
			#
			# Note that the dd output is suppressed unless
			# there are errors
			####################

			dd if=/dev/urandom \
			    of=/${pool}/B_${this_rs}/file_${filenum} \
			    bs=${this_rs} count=${thiscount} \
			    iflag=fullblock 2>&1 | \
			    egrep -v -e "records in" -e "records out" \
				-e "bytes.*copied"
#			    egrep -v -e "records in" -e "records out" 
#				-e "bytes.*copied"
			((filenum+=1))
		done
	done
}

