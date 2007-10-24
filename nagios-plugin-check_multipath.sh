#!/bin/sh
#
# Nagios plugin to check the state of Linux device mapper multipath devices
# 
# (C) 2006 Riege Software International GmbH
# Licensed under the General Public License, Version 2
# Contact: Gunther Schlegel, schlegel@riege.com
#
# v1.0	20060220 gs	new script

PROGNAME=`basename $0`
PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
REVISION=`echo '$Revision$' | sed -e 's/[^0-9.]//g'`

. $PROGPATH/utils.sh

MULTIPATH='/usr/bin/sudo /sbin/multipath'

print_usage() {
  echo "Usage:"
  echo "  $PROGNAME"
}

print_help() {
  print_revision $PROGNAME $REVISION
  echo ""
  print_usage
  echo ""
  echo "Check multipath status"
  echo ""
  echo "really simple: runs /sbin/multipath and greps for \"failed\" paths. No options yet."
  echo "Requires sudo."
  echo ""
  echo "Add this to your sudoers file by running visudo to add access:"
  echo "Cmnd_Alias MULTIPATH=/sbin/multipath -l"
  echo "nagios  ALL= NOPASSWD: MULTIPATH"
  echo "The user nagios may very well be nobody or someone else depending on your configuration"
  echo ""
  support
}

# Information options
case "$1" in
--help)
		print_help
    exit $STATE_OK
    ;;
-h)
		print_help
    exit $STATE_OK
    ;;
--version)
		print_revision $PLUGIN $REVISION
    exit $STATE_OK
    ;;
-V)
		print_revision $PLUGIN $REVISION
    exit $STATE_OK
    ;;
esac

# check
if [ `/usr/bin/sudo -l|grep -c multipath` -eq 0 ]; then 
	echo "MULTIPATH: UNKNOWN - sudo not configured"
	exit $STATE_UNKNOWN
else 
	if [  -x /sbin/multipath ]; then 
		MODCOUNT=`/sbin/lsmod|grep -c ^dm_multipath`
		if [ $MODCOUNT -gt 0 ]; then	
			PATHCOUNT=`$MULTIPATH -l|wc -l`
			if [ $PATHCOUNT -eq 0 ]; then
				echo "MULTIPATH: WARNING - no paths defined"
				exit $STATEWARNING
			else 
				FAILCOUNT=`$MULTIPATH -l|grep -c failed`
				if [ $FAILCOUNT -eq 0 ]; then
					echo "MULTIPATH: OK - no failed paths"
					exit $STATE_OK
				else
					echo "MULTIPATH: CRITICAL - $FAILCOUNT paths failed"
					exit $STATE_CRITICAL
				fi
			fi
		else 
			echo "MULTIPATH: UNKNOWN - module dm_multipath not loaded"
			exit $STATE_UNKNOWN
		fi	
	else
		echo "MULTIPATH: UNKNOWN - /sbin/multipath not found"
		exit $STATE_UNKNOWN
	fi
fi

# vim: ts=4
