#!/bin/ksh -p
TEST_BASE_DIR=/tmp/check_test.$$
function histo_check_test_pool
{
	if [ $# -ne 1 ]
	then
		log_note "histo_check_test_pool: insufficient parameters"
		log_fail "hctp: 1 requested $# received"
	fi	
	typeset pool=$1

	set -A recordsizes
	set -A recordcounts
	typeset -i rb
	typeset -i min_rsbits=9 #512
	typeset -i max_rsbits=SPA_MAXBLOCKSHIFT+1
	typeset -i this_rs
	typeset -i this_ri
	typeset -i sum_filesizes=0
	typeset dumped
	typeset stripped

	let histo_check_pool_size=$(histo_get_pool_size ${pool})
	if [[ ! ${histo_check_pool_size} =~ ${re_number} ]]
	then
		log_note "histo_check_pool_size is not numeric ${histo_check_pool_size}"
		log_fail
	fi
	let max_pool_record_size=$(zfs get -p recordsize ${pool}| awk "/${pool}/{print \$3}")
	if [[ ! ${max_pool_record_size} =~ ${re_number} ]]
	then
		log_fail "hctp: max_pool_record_size is not numeric ${max_pool_record_size}"
	fi

	mkdir -p ${TEST_BASE_DIR}

	dumped="${TEST_BASE_DIR}/${pool}_dump.txt"
	stripped="${TEST_BASE_DIR}/${pool}_stripped.txt"

	zdb -Pbbb ${pool} | \
	    tee ${dumped} | \
	    sed -e '1,/^block[ 	][ 	]*psize[ 	][ 	]*lsize.*$/d' \
	    -e '/^size[ 	]*Count/d' -e '/^$/,$d' \
	    > ${stripped}

	sum_filesizes=$(echo "2^21"|bc)

	###################
	# generate 10% + 20% + 30% + 31% = 91% of the filespace
	# attempting to use 100% will lead to no space left on device
	###################
	for pass in 10 20 30 31
	do
		((thiscount=(((histo_check_pool_size*pass)/100)/sum_filesizes)))

		for rb in $(seq ${min_rsbits} ${max_rsbits})
		do
			blksize=$(echo "2^$rb"|bc)
			if [ $blksize -le $max_pool_record_size ]
			then
				((recordcounts[$blksize]+=thiscount))
			fi
		done
	done

	###################
	# compare the above computed counts for blocks against
	# lsize count.  Since some devices have a minimum hardware
	# blocksize > 512, we cannot compare against the asize count.
	# E.G., if the HWBlocksize = 4096, then the asize counts for
	# 512, 1024 and 2048 will be zero and rolled up into the 
	# 4096 blocksize count for asize.   For verification we stick
	# to just lsize counts.
	#
	# The max_variance is hard-coded here at 10%.  testing so far
	# has shown this to be in the range of 2%-8% so we leave a
	# generous allowance... This might need changes in the future
	###################
	let max_variance=10
	let fail_value=0
	let error_count=0
	log_note "Comparisons for ${pool}"
	log_note "Bsize is the blocksize, Count is predicted block count"
	log_note "Bsize\tCount\tpsize\tlsize\tasize"
	while read -r blksize pc pl pm lc ll lm ac al am
	do
		if [ $blksize -gt $max_pool_record_size ]
		then
			continue
		fi
		log_note \
		    "$blksize\t${recordcounts[${blksize}]}\t$pc\t$lc\t$ac"

		###################
		# get the computer record count and compute the
		# difference percentage in integer arithmetic
		###################
		rc=${recordcounts[${blksize}]}
		((rclc=(rc-lc)<0?lc-rc:rc-lc)) # absolute value
		((dp=(rclc*100)/rc))

		###################
		# Check against the allowed variance
		###################
		if [ $dp -gt ${max_variance} ]
		then
			log_note \
			"\thctp: Expected variance < ${max_variance}% observed ${dp}%"
			if [ ${dp} -gt ${fail_value} ]
			then
				fail_value=${dp}
				((error_count++))
			fi
		fi
	done < ${stripped}
	if [ ${fail_value} -gt 0 ]
	then
		if [ ${error_count} -eq 1 ]
		then
			log_note "hctp: There was ${error_count} error"
		else
			log_note "hctp:There were a total of ${error_count} errors"
		fi
		log_note \
		"hctp: Max variance of ${max_variance}% exceeded, saw ${fail_value}%"
		log_fail
	fi
	rm -rf ${TEST_BASE_DIR}
}
