for files in $(seq 1 12)
do
	output=/tmp/testing_$files.$$.txt
	touch $output
	drain-tank rnovak 2>&1 | tee -a $output
	build-tank -f $files -b 4G rnovak 2>&1 | tee -a $output
	fill-tank -t rnovak 2>&1 | tee -a $output
done

