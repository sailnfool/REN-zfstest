#!/bin/ksh -p
TEST_BASE_DIR=/tmp/check_test.$$
function histo_check_test_pool
{
	if [ $# -ne 1 ]
	then
		log_fail \
		"check_histo_test_pool insufficient parameters"
	fi	
	typeset pool=$1

	set -A recordsizes
	set -A recordcounts
	typeset -i pool_size=0
	typeset -i rb
	typeset -i min_rsbits=9 #512
	typeset -i max_rsbits=SPA_MAXBLOCKSHIFT+1
	typeset -i this_rs
	typeset -i this_ri
	typeset -i sum_filesizes=0
	typeset dumped
	typeset stripped

	let pool_size=$(histo_get_pool_size ${pool})
	mkdir -p ${TEST_BASE_DIR}

	for rb in $(seq ${min_rsbits} ${max_rsbits})
	do
		recordsizes[${rb}]=$(echo "2^${rb}"|bc)
		((sum_filesizes+=recordsizes[${rb}]))
	done

	dumped="${TEST_BASE_DIR}/${pool}_dump.txt"
	stripped="${TEST_BASE_DIR}/${pool}_stripped.txt"

	zdb -Pbbb ${pool} | \
	    tee ${dumped} | \
	    sed -e '1,/^block[ 	][ 	]*psize[ 	][ 	]*lsize.*$/d' \
	    -e '/^size[ 	]*Count/d' -e '/^$/,$d' \
	    > ${stripped}

	((max_files=pool_size % sum_filesizes))

	this_ri=min_rsbits

	filenum=0

	###################
	# generate 10% + 20% + 30% + 40% = 100% of the files
	###################
	for pass in 10 20 30 40
	do
		((thiscount=(max_files * pass)/100))
		echo "${0##*/} Pass = ${pass}, filenum=${filenum}"
		echo "${0##*/} thiscount=${thiscount}, max_files=${max_files}"

		if [ ${thiscount} -lt 12 ]
		then
			echo "found zero thiscount"
			thiscount=12
		fi

		####################
		# This code mirrors the code in histo_populate_test_pool
		# but does not perform the dd copies to create the
		# files with block sizes
		####################
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
				let this_ri=min_rsbits
				let this_rs=${recordsizes[${this_ri}]}
				break
			fi
			((recordcounts[${this_rs}]+=filecount))
			((filenum+=filecount))
			((this_ri++))
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
	# The max_variance is hard-coded here at 5%.  testing so far
	# has shown this to be in the range of 2%-3% so we leave a
	# generous allowance... This might need changes in the future
	###################
	let max_variance=5
	log_note "Comparisons for ${pool}"
	log_note "Blocksize\tCount\tpsize\tlsize\tasize"
	while read -r blksize pc pl pm lc ll lm ac al am
	do
		log_note \
		    "$blksize\t${recordcounts[$blksize]}\t$pc\t$lc\t$ac"
		rc=${recordcounts[${blksize}]}
		diff=$(echo \
		    "define abs(i){if((i<0)return(-i);return(i)}(abs($rc-$lc)/$rc)*100" \
		    | bc -l)

		####################
		# strip the decimal portion
		####################
		dp=${diff%%.*}
		if [ $dp -lt ${max_variance} ]
		then
			log_fail "Variance exceeded ${max_variance} -- $dp"
		fi
	done < ${stripped}
	rm -rf ${TEST_BASE_DIR}
}
