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

MULTIPATH=/sbin/multipath
SUDO=/usr/bin/sudo
LSMOD=/sbin/lsmod

print_usage() {
	echo "Usage:"
	echo "  $PROGNAME [-n NUMPATHS]"
	echo ""
	echo "Options:"
	echo "  -n NUMPATHS     If specified there must be NUMPATHS paths present for each LUN"
}

print_help() {
	print_revision $PROGNAME $REVISION

	echo "Check multipath status."
	echo ""
	print_usage
	echo ""
	echo "Really simple: runs $MULTIPATH and greps for \"failed\" paths."
	echo "if NUMPATHS is specified each LUN must have that number of PATHS present."
	echo ""

	echo "Requires sudo and multipath-tools"
	echo ""

	echo "Add this to your sudoers file by running visudo to add access:"
	if [ -r /proc/modules ]; then
		echo "Cmnd_Alias MULTIPATH=$MULTIPATH -l"
	else
		echo "Cmnd_Alias MULTIPATH=$MULTIPATH -l, $SUDO"
	fi
	echo "nagios  ALL= NOPASSWD: MULTIPATH"
	echo "The user nagios may very well be nobody or someone else depending on your configuration"
	echo ""
	support
}

NUMPATHS=''

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
-n)
	shift
	NUMPATHS="$1"
	;;
esac

if [ ! -x $MULTIPATH ]; then
	echo "MULTIPATH: UNKNOWN - $MULTIPATH not found"
	exit $STATE_UNKNOWN
fi

# if not yet root, check sudo
if [ $(id -un) != "root" ]; then
	if [ `$SUDO -l | grep -c multipath` -eq 0 ]; then
		echo "MULTIPATH: UNKNOWN - sudo not configured"
		exit $STATE_UNKNOWN
	fi
	MULTIPATH="$SUDO $MULTIPATH"

	# on grsec kernel /proc might be protected
	if [ ! -r /proc/modules ]; then
		LSMOD="$SUDO $LSMOD"
	fi
fi

OUTPUT=$($MULTIPATH -l 2>/dev/null)
if [ $? != 0 ]; then
	# Failed. grab more info why
	MODCOUNT=$($LSMOD | grep -c ^dm_multipath)
	if [ $MODCOUNT = 0 ]; then
		echo "MULTIPATH: UNKNOWN - Module dm-multipath not loaded"
		exit $STATE_UNKNOWN
	fi

	echo "MULTIPATH: $(MULTIPATH -l 2>&1)"
	exit $STATE_UNKNOWN
fi

PATHCOUNT=$(echo "$OUTPUT" | wc -l)
if [ $PATHCOUNT -eq 0 ]; then
	echo "MULTIPATH: WARNING - No paths defined"
	exit $STATEWARNING
fi

FAILCOUNT=$(echo "$OUTPUT" | grep -c failed)
if [ $FAILCOUNT -gt 0 ]; then
	echo "MULTIPATH: CRITICAL - $FAILCOUNT paths failed"
	exit $STATE_CRITICAL
fi

if [ "$NUMPATHS" ]; then
	echo "$OUTPUT" | awk -vnumpaths=$NUMPATHS -vrc=0 -vlun= -vtargets=0 '
	/^\[/{next} # skip flags
   	/^\\/{targets++; next} # count targets
	/^ \\/{next} # skip devinfo
	{
		# The LUN line
		# process if this is not first LUN
		if (lun && numpaths != targets) {
			printf("CRITICAL: %d of %d paths available for LUN %s\n", numpaths, targets, lun)
			rc = 1
		}

		# reset counter
		targets = 0
		lun = $0
	}
	END { exit rc }
	'
	if [ $? -gt 0 ]; then
		exit $STATE_CRITICAL
	fi
fi

echo "MULTIPATH: OK - No failed paths"
exit $STATE_OK

# vim: ts=4:sw=4:noet
