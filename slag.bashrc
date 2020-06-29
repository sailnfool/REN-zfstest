#!/bin/bash
function func_pathmunge() {
	USAGE="${FUNCNAME} <dir> [ after ]"
	BASHRC_ADDPATH=$HOME/.bashrc.addpath
	if [ -d "$1" ]
	then
	  realpath / 2>&1 >/dev/null && path=$(realpath "$1") || path="$1"
	  # GNU bash, version 2.02.0(1)-release (sparc-sun-solaris2.6) ==> TOTAL incompatibility with [[ test ]]
	  [ -z "$PATH" ] && export PATH="$path:/bin:/usr/bin"
	  # SunOS 5.6 ==> (e)grep option "-q" not implemented !
	  /bin/echo "$PATH" | /bin/egrep -s "(^|:)$path($|:)" >/dev/null || {
	    [ "$2" == "after" ] && export PATH="$PATH:$path" || export PATH="$path:$PATH"
	  }
	else
		echo "${0##*/} $1 is not a directory" "${USAGE}"
	fi
	echo "export PATH=$PATH" >> $BASHRC_ADDPATH
}
export GLOBAL=/tftpboot/global/novak5
func_pathmunge ~novak5/github/zfs/bin before
func_pathmunge ~novak5/bin before
func_pathmunge ${GLOBAL}/github/zfs/bin before
func_pathmunge ${GLOBAL}/bin before
if [ -f BASHRC_ADDPATH ]
then
	source ${BASHRC_ADDPATH}
fi
export OLDPS1=$PS1
export PS1="[\u@\h:\w:\$(/usr/bin/git branch 2>/dev/null | /usr/bin/grep '^*')] \$ "
echo ""
echo $PATH
