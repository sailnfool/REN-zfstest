export GLOBAL=/tftpboot/global/novak5
export PATH=${GLOBAL}/bin:${GLOBAL}/github/zfs/bin:$PATH
export OLDPS1=$PS1
export PS1="[\u@\h:\w:$(/usr/bin/git branch 2>/dev/null | /usr/bin/grep '^*')] \$ "
echo $PATH
