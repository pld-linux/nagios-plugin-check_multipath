#!/bin/sh
#
# Nagios plugin to check the state of Linux device mapper multipath devices
#
# (C) 2006 Riege Software International GmbH
# Licensed under the General Public License, Version 2
# Contact: Gunther Schlegel, schlegel@riege.com
#
# v1.0	20060220 gs	new script

PROGNAME=${1##*/}
PROGPATH=${0%/*}
REVISION=$(echo '$Revision$' | sed -e 's/[^0-9.]//g')

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
	MULTIPATH="$SUDO $MULTIPATH"
	# on grsec kernel /proc might be protected
	if [ ! -r /proc/modules ]; then
		LSMOD="$SUDO $LSMOD"
	fi
fi

OUTPUT=$($MULTIPATH -l 2>/dev/null)
if [ $? != 0 ]; then
	# Failed. grab more info why
	if [ $(id -un) != "root" ] && [ $($SUDO -l | grep -c multipath) -eq 0 ]; then
		echo "MULTIPATH: UNKNOWN - sudo not configured"
		exit $STATE_UNKNOWN
	fi

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
	exit $STATE_WARNING
fi

FAILCOUNT=$(echo "$OUTPUT" | grep -c failed)
if [ $FAILCOUNT -gt 0 ]; then
	echo "MULTIPATH: CRITICAL - $FAILCOUNT paths failed"
	exit $STATE_CRITICAL
fi

if [ "$NUMPATHS" ]; then
	# multipath-tools-0.4.8-0.12.amd64
	#	LUN-32 (36006016002c11800b2d9d4c3142adc11) dm-9 DGC     ,RAID 10 [1]
	#	[size=4.0G][features=1 queue_if_no_path][hwhandler=1 emc] [2]
	#	\_ round-robin 0 [prio=0][active] [3]
	#	 \_ 0:0:0:1 sdb 8:16  [active][undef] [4]
	#	\_ round-robin 0 [prio=0][enabled]
	#	 \_ 0:0:1:1 sdg 8:96  [active][undef]
	# multipath-tools-0.4.8-13.x86_64
	#	LUN-33 (36006016002c11800ec11344a7134dc11) dm-6 DGC,RAID 10 [1]
	#	size=30G features='1 queue_if_no_path' hwhandler='1 emc' wp=rw [2]
	#	|-+- policy='round-robin 0' prio=-1 status=active [3]
	#	| `- 1:0:1:0 sdc 8:32 active undef running [4]
	#	`-+- policy='round-robin 0' prio=-1 status=enabled
	#	  `- 1:0:0:0 sdb 8:16 active undef running


	echo "$OUTPUT" | awk -vnpaths=$NUMPATHS \
		-vSTATE_OK=$STATE_OK \
		-vSTATE_WARNING=$STATE_WARNING \
		-vSTATE_CRITICAL=$STATE_CRITICAL \
		-vSTATE_UNKNOWN=$STATE_UNKNOWN \
	'
	BEGIN {
		nlun = -1;
	}
	/([0-9a-f]*) dm-[0-9]+/ { # find lun [1]
		nlun++;
		names[nlun] = $1 " " $2;
		targets[nlun] = 0;
		next;
	}

	/size=.*features=/ { # skip flags [2]
		next
	}

	/prio=/ {
		targets[nlun]++;
		# skip first dev line [3]
		next
	}

	/[#0-9]+:[#0-9]+:[#0-9]+:[#0-9]+ [^ ]+ [0-9]+:[0-9]/ { # second line with device [4]
		next
	}

	END {
		if (nlun == -1) {
			print "MULTIPATH: No paths parsed from multipath output."
			exit STATE_UNKNOWN;
		}

		rc = STATE_OK;
        for (i = 0; i <= nlun; i++) {
			if (npaths != targets[i]) {
				printf("CRITICAL: %d of %d paths available for LUN %s\n", targets[i], npaths, names[i])
				rc = 1
			}
		}

		if (rc) {
			exit rc;
		}
		printf("Found %d LUNs each having %d paths OK\n", 1 + nlun, npaths);
		exit rc;
	}
	'
	exit $?
fi

echo "MULTIPATH: OK - No failed paths"
exit $STATE_OK

# vim: ts=4:sw=4:noet
