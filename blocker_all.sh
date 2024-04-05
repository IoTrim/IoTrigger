#!/bin/bash

#This scripts does the following:
# Switch off the device, block all the "blocked_all" destination then back ON the device
# Then wait for input to unlock them all (so we can test functions manually)

#Run with sudo permissions and pass the experiment filename in first parameter
#EXAMPLE: sudo ./blocker_all.sh switchbot-mini


# The first parameter $1 should be the experiment filename (placed in the $MONIOTR_DIR/experiemnts folder)
exp_name="$1"
if [ -z "$1" ]; then
    echo "Usage: $0 <EXPERIMENT_NAME>"
    exit 1
fi


#setup directory parameters
MONIOTR_DIR="/opt/moniotr" #This is the directory where MONIOTR is located
IOTRIM_DIR="" #write here the directory where all IoTrigger scripts are located

#default value for iotrim_dir is the current directory where script is located
if [ -z "$IOTRIM_DIR" ]; then
    IOTRIM_DIR="$(dirname $0)"
fi


TAG_DIR="$MONIOTR_DIR/traffic/tagged"
POWER_SCRIPT="$IOTRIM_DIR/kasa-power.py"

EXP_FILE="$IOTRIM_DIR/experiments/$exp_name"

#optional parameters to filter only specific device or exp name in the experiment file
DO_DEVICE="$2"
DO_EXPERIMENT="$3"


#read experiment file
while IFS=";" read name plug_name onoff name_exp crop phone_exp package network sleep1 sleep2 function_1 function_2 function_3 function_4 function_5 function_6 function_7 function_8 function_9  function_10 function_11 function_12 function_13 function_14
do
	# Ignore empty lines
	[[ -z "$name" ]] && continue
	# Ignore commented lines starting with # (spaces before # are allowed)
    [[ $name  =~ ^[[:space:]]*# ]] && continue
    # Ignore empty lines and lines with only spaces
    [[ $name  =~ ^[[:space:]]*$ ]] && continue
	# Run only experiments matching the given device (if provided)
	[[ -n "$DO_DEVICE" ]] && [[ "$DO_DEVICE" != "$name" ]] && continue
    # Run only experiments matching the given experiment name (if provided)
    [[ -n "$DO_EXPERIMENT" ]] && [[ "$DO_EXPERIMENT" != "$name_exp" ]] && continue
	
	$MONIOTR_DIR/bin/dns-override wipe $name
	$MONIOTR_DIR/bin/ip-block wipe $name
	$MONIOTR_DIR/bin/tag-experiment cancel $name "block_all"
	echo "Switching device OFF" 
	python3 $POWER_SCRIPT $plug_name "off" #switch off device
	sleep 5s
	#read and block all dests
	while read dest
	do
		#skip commented rows
		if [[ "${dest}" =~ ^# ]]; then
			continue
		fi
		if [[ "${dest}" =~ [a-z] ]]; then
			$MONIOTR_DIR/bin/dns-override add $name $dest NXDOMAIN
		else
			$MONIOTR_DIR/bin/ip-block add $name $dest all all
		fi
		echo "blocking $dest"
	done < $TAG_DIR/$name/blocked_all
	echo "Switching device ON"
	python3 $POWER_SCRIPT $plug_name "on" #switch on device
	sleep 40
	if [[ $name == "roku-tv" ]]; then
			sleep 60
			echo "Time for opening the app"
	fi
	sleep $sleep1
	echo "Blocked all dests. Press ENTER then execute your activity"
	read dumb < /dev/tty
	$MONIOTR_DIR/bin/tag-experiment start $name "block_all"
	
	echo "When you finish the activity. Press ENTER to finish the experiment and unblock all dests"
	read dumb < /dev/tty
	
	$MONIOTR_DIR/bin/tag-experiment stop $name "block_all" $TAG_DIR
	$MONIOTR_DIR/bin/dns-override wipe $name
	$MONIOTR_DIR/bin/ip-block wipe $name
	
	exit
done < $EXP_FILE

