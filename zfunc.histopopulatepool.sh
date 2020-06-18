#!/bin/ksh -p
SPA_MAXBLOCKSHIFT=24

function histo_populate_pool
{
	if [ $# -ne 1 ]
	then
		$(insufficient 1)
	fi
	typeset pool=$1

	set -A recordsizes
	typeset -i min_rsbits=9 #512
	typeset -i max_rsbits=SPA_MAXBLOCKSHIFT #16 MiB
	typeset -i sum_filesizes=0
	re_number='^[0-9]+$'

	my_pool_size=$(histo_get_pool_size ${pool})
	if [[ ! ${my_pool_size} =~ ${re_number} ]]
	then
		log

	max_pool_record_size=\
	    $(zfs get -p recordsize ${pool}| awk "/${pool}/{print \$3}")

	for rb in $(seq ${min_rsbits} ${max_rsbits})
	do
		this_rs=$(echo "2^${rb}" | bc)
		recordsizes[$rb]=${this_rs}
		((sum_filesizes+=recordsizes[$rb]))
		if [ ${recordsizes[$rb]} -le ${max_pool_record_size} ]
		then
			if [ ! -d /${pool}/B_${recordsizes[$rb]} ]
			then
				echo "zfs create ${pool}/B_${this_rs}"
				zfs create ${pool}/B_${this_rs}
				echo "zfs set recordsize=${this_rs} " \
				    "${pool}/B_${this_rs}"
				zfs set recordsize=${this_rs} \
				    ${pool}/B_${this_rs}
			fi
		fi

	done

	((max_files=my_pool_size % sum_filesizes))
	this_ri=min_rsbits

	filenum=0
	for pass in 10 20 30 40
	do
		((thiscount=(max_files * pass)/100))
		echo "${0##*/} Pass = ${pass}, filenum=${filenum}"
		echo "${0##*/} thiscount=${thiscount}, max_files=${max_files}"
		while [ ${filenum} -le ${max_files} ]
		do
			if [ $(expr ${filenum} % 10000)  -eq 0 ]
			then
				echo "${0##*/}: File number " \
				   "${filenum} of ${max_files}"
			fi

			####################
			# 12 = number of steps (inclusive) from
			# 2^9 = 512 to
			# 2^20 = 1 MiB
			####################
			if [ ${thiscount} -lt 12 ]
			then
				thiscount=12
			fi
			filecount=$(expr ${thiscount} / 12)
			if [ ${filecount} -eq 0 ]
			then
				let filecount=1
			fi

			let this_rs=${recordsizes[${this_ri}]}
			if [[ ${this_ri} -gt ${max_rsbits} || \
				${this_rs} -gt ${max_pool_record_size} ]]
			then
				let this_ri=${min_rsbits}
				let this_rs=${recordsizes[${this_ri}]}
				break
			fi
	
			####################
			# Create the files in the devices and datasets
			# of the right size.  The files are filled
			# with random data to defeat the compression
			#
			# Note that the dd output is suppressed unless
			# there are errors
			####################

			echo "dd if=/dev/urandom " \
			    "of=/${pool}/B_${this_rs}/file_${filenum} " \
			    "bs=${this_rs} count=${filecount} " \
			    "iflag=fullblock"
			dd if=/dev/urandom \
			    of=/${pool}/B_${this_rs}/file_${filenum} \
			    bs=${this_rs} count=${filecount} \
			    iflag=fullblock 2>&1 | \
			    egrep -v -e "records in" -e "records out" \
				-e "bytes.*copied"
			((filenum+=${filecount}))
			((this_ri++))
		done
	done
}

