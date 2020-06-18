#!/bin/ksh -p
function log_note
{
	echo -e  $@
}
# Execute a positive test and exit $STF_FAIL is test fails
#
# $@ - command to execute

function log_must
{
	log_pos "$@"
	(( $? != 0 )) && log_fail
}
# Execute and print command with status where success equals zero result
#
# $@ command to execute
#
# return command exit status

function log_pos
{
	typeset out=""
	typeset logfile="/tmp/log.$$"

	while [[ -e $logfile ]]; do
		logfile="$logfile.$$"
	done

	"$@" 2>$logfile
	typeset status=$?
	out="cat $logfile"

	if (( $status != 0 )) ; then
		print -u2 $($out)
		_printerror "$@" "exited $status"
	else
		$out | egrep -i "internal error|assertion failed" \
			> /dev/null 2>&1
		# internal error or assertion failed
		if [[ $? -eq 0 ]]; then
			print -u2 $($out)
			_printerror "$@" "internal error or assertion failure" \
				" exited $status"
			status=1
		else
			[[ -n $LOGAPI_DEBUG ]] && print $($out)
			_printsuccess "$@"
		fi
	fi
	_recursive_output $logfile "false"
	return $status
}

# Output a formatted line
#
# $@ - message text

function _printline
{
	print "$@"
}

# Output an error message
#
# $@ - message text

function _printerror
{
	_printline ERROR: "$@"
}

# Output a success message
#
# $@ - message text

function _printsuccess
{
	_printline SUCCESS: "$@"
}

# Output logfiles recursively
#
# $1 - start file
# $2 - indicate whether output the start file itself, default as yes.

function _recursive_output #logfile
{
	typeset logfile=$1

	while [[ -e $logfile ]]; do
		if [[ -z $2 || $logfile != $1 ]]; then
			cat $logfile
		fi
		rm -f $logfile
		logfile="$logfile.$$"
        done
}

