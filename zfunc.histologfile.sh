#!/bin/ksh -p
# Perform cleanup and exit $STF_FAIL
#
# $@ - message text

function log_fail
{
	_endlog $STF_FAIL "$@"
}


# Execute a positive test and exit $STF_FAIL is test fails
#
# $@ - command to execute

function log_must
{
	log_pos "$@"
	(( $? != 0 )) && log_fail
}
function log_note
{
	echo -e  $@
}

# Set an exit handler
#
# $@ - function(s) to perform on exit

function log_onexit
{
	_CLEANUP=("$*")
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

# Execute custom callback scripts on test failure
#
# callback script paths are stored in TESTFAIL_CALLBACKS, delimited by ':'.

function _execute_testfail_callbacks
{
	typeset callback

	print "$TESTFAIL_CALLBACKS:" | while read -d ":" callback; do
		if [[ -n "$callback" ]] ; then
			log_note "Performing test-fail callback ($callback)"
			$callback
		fi
	done
}


# Perform cleanup and exit
#
# $1 - stf exit code
# $2-$n - message text

function _endlog
{
	typeset logfile="/tmp/log.$$"
	_recursive_output $logfile

	typeset exitcode=$1
	shift
	(( ${#@} > 0 )) && _printline "$@"

	if [[ $exitcode == $STF_FAIL ]] ; then
		_execute_testfail_callbacks
	fi

	typeset stack=("${_CLEANUP[@]}")
	log_onexit ""
	typeset i=${#stack[@]}
	while (( i-- )); do
		typeset cleanup="${stack[i]}"
		log_note "Performing local cleanup via log_onexit ($cleanup)"
		$cleanup
	done

	exit $exitcode
}


