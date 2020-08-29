#!/bin/bash
[ -f /etc/sysconfig/sshd ] && . /etc/sysconfig/sshd
prog="sshd"
SSHD=/usr/sbin/sshd
[ -x $SSHD ] || exit 5
[ -f /etc/ssh/sshd_config ] || exit 6
/usr/sbin/sshd-keygen
echo -n $"Starting $prog: "
exec $SSHD -e -D $OPTIONS

