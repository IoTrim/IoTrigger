#!/bin/bash
#This scripts executes the activities and get all the destinations contacted by the device

#Run with sudo permissions and pass the experiment filename in first parameter
#EXAMPLE: sudo ./get_dest.sh switchbot-mini

# The first parameter $1 should be the experiment filename (placed in the $MONIOTR_DIR/experiemnts folder)
exp_name="$1"
if [ -z "$1" ]; then
    echo "Usage: $0 <EXPERIMENT_NAME>"
    exit 1
fi

#get experiment date
DATE=`date "+%Y%m%d_%H%M%S"`

#setup directory parameters
MONIOTR_DIR="/opt/moniotr" #This is the directory where MONIOTR is located
IOTRIM_DIR="" #write here the directory where all IoTrigger scripts are located

#default value for iotrim_dir is the current directory where script is located
if [ -z "$IOTRIM_DIR" ]; then
    IOTRIM_DIR="$(dirname $0)"
fi

POWER_SCRIPT="$IOTRIM_DIR/kasa-power.py"
SPEAK_DIR="$IOTRIM_DIR/speak"
TAG_DIR="$MONIOTR_DIR/traffic/tagged"
EXP_FILE="$IOTRIM_DIR/experiments/$exp_name"



#optional parameters to filter only specific device or exp name in the experiment file
DO_DEVICE="$2"
DO_EXPERIMENT="$3"



#functiont o wait for the phone to be plugged and available
waitphone() {
    while [ -z "$PHONE_FOUND" ]; do
        echo "Phone not found, waiting for $PHONE/$ANDROID_SERIAL"
        sleep 5
       PHONE_FOUND=`adb devices | grep $ANDROID_SERIAL`
    done
}


#read experiment file
while IFS=";" read name plug_name onoff name_exp crop phone_exp package network sleep1 sleep2 function_1 function_2 function_3 function_4 function_5 function_6 function_7 function_8 function_9 function_10 function_11 function_12 function_13 function_14
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


	PHONE=$phone_exp
	#read phone and wait it is ready
	if [ ! -f "ids/$PHONE" ]; then
		echo "File ids/$phone_exp not found, skipping..."
		continue
    fi
	ANDROID_SERIAL=$(cat ids/$PHONE)
	PHONE_FOUND=`adb devices | grep $ANDROID_SERIAL | grep device`
	waitphone
	echo Phone ready, proceeding...
	
	
	
	#create required directories (if not exist already)
    mkdir $TAG_DIR/$name/power -p
    mkdir $TAG_DIR/$name/$name_exp -p

	#wiping previous blocked destinations
	$MONIOTR_DIR/bin/dns-override wipe $name
	$MONIOTR_DIR/bin/ip-block wipe $name

    echo "Cancel past experiment POWER for device $name"
	$MONIOTR_DIR/bin/tag-experiment cancel $name "power"


	#if the ONOFF parameter is 1, then run the power experiment: plug off, then back on and get dests
	if [ $onoff = "1" ]; then
	
		#start capture experiment
		echo "Starting experiment POWER for device $name"
		$MONIOTR_DIR/bin/tag-experiment start $name "power"
		echo "Turning OFF device with plug $plug_name"
		
		#turn device OFF
		python3 $POWER_SCRIPT $plug_name "off"
		sleep 5s
		echo "Turning ON device with plug $plug_name"
		#turn device ON
		python3 $POWER_SCRIPT $plug_name "on"
		sleep 40s
		echo $DATE $name $name_exp "power ok" >> $TAG_DIR/$name/exp_okA
		
		#stop capture experiment
		$MONIOTR_DIR/bin/tag-experiment stop $name "power"
		
		LAST_CAPT=$(ls $TAG_DIR/$name/power/*.pcap -t | grep -v companion | grep -v http | head -n 1)
		#extract all the destinations from tshark
		tshark -r $LAST_CAPT -Y "dns.flags.response == 1" -T fields -E separator=\; -e dns.qry.name -e dns.a -E header=n -E quote=n | sort | uniq | awk -F ";" {'if($1) print $1'} | awk -F "," {'print $1 "\n" $2 "\n" $3 "\n" $4 "\n" $5 "\n" $6 "\n" $7'} | grep -v "ntp" | grep -v "time" | grep -v "dns" | sort | uniq >$TAG_DIR/$name/$name_exp/list_dest_pow
		tshark -r $LAST_CAPT -T fields -e dns.qry.name -e dns.resp.name -E separator=\;  -E header=n -E quote=n | sort | uniq | awk -F ";" {'if($2) print $2'} | awk -F "," {'print $1 "\n" $2 "\n" $3 "\n" $4 "\n" $5 "\n" $6 "\n" $7'} | grep -v "ntp" | grep -v "time" | grep -v "dns" | sort | uniq >>$TAG_DIR/$name/$name_exp/list_cname_pow
		tshark -r $LAST_CAPT  -q -z hosts | awk 'NF && $1!~/^#/' | awk '{print $1}' | grep -v "ntp" | grep -v "time" | grep -v "dns" | sort | uniq > $TAG_DIR/$name/$name_exp/list_ipdom_pow
		tshark -r $LAST_CAPT -T fields  -e ip.dst -e udp.port -E separator=\; | grep -v ",53" | grep -v "53," | grep -v ",123" | grep -v "123," | sort | uniq > $TAG_DIR/$name/$name_exp/list_ip_pow
		tshark -r $LAST_CAPT -T fields  -e ip.src -e udp.port -E separator=\; | grep -v ",53" | grep -v "53," | grep -v ",123" | grep -v "123," | sort | uniq >> $TAG_DIR/$name/$name_exp/list_ip_pow
		grep -v -f $TAG_DIR/$name/$name_exp/list_ipdom_pow $TAG_DIR/$name/$name_exp/list_ip_pow >$TAG_DIR/$name/$name_exp/list_ipnodom_pow
	fi

	sleep $sleep1 #sleep BEFORE the activity is executed
	
	#start the activity experiment
	echo "Starting experiment $name_exp for device $name"
	$MONIOTR_DIR/bin/tag-experiment start $name $name_exp
	sleep 5
	
	#case SPEAKERS, call Speak scripts
    if [[ $package == "echo" || $package == "google" || $package == "allure-speaker" || $package == "amazon" ]]; then
        echo "Running experiment for the speaker: " $package
        $SPEAK_DIR/speak.sh $SPEAK_DIR/$function_1
		sleep $sleep2 #sleep AFTER activity is executed
		
		echo $DATE $name $name_exp "ok" >> $TAG_DIR/$name/exp_okA
		$MONIOTR_DIR/bin/tag-experiment stop $name $name_exp
		sleep 2s
		
		LAST_CAPT=$(ls $TAG_DIR/$name/$name_exp/*.pcap -t | grep -v companion |  grep -v http | head -n 1)
		tshark -r $LAST_CAPT  -q -z hosts | awk 'NF && $1!~/^#/' | awk '{print $2}' | grep -v "ntp" | grep -v "time" | grep -v "dns" | sort | uniq > $TAG_DIR/$name/$name_exp/list_dest
		tshark -r $LAST_CAPT -T fields -e dns.qry.name -e dns.resp.name -E separator=\;  -E header=n -E quote=n | sort | uniq | awk -F ";" {'if($2) print $2'} | awk -F "," {'print $1 "\n" $2 "\n" $3 "\n" $4 "\n" $5 "\n" $6 "\n" $7'} | grep -v "ntp" | grep -v "time" | grep -v "dns" | sort | uniq>>$TAG_DIR/$name/$name_exp/list_dest
		tshark -r $LAST_CAPT -T fields -e dns.qry.name -e dns.resp.name -E separator=\;  -E header=n -E quote=n | sort | uniq | awk -F ";" {'if($2) print $2'} | awk -F "," {'print $1 "\n" $2 "\n" $3 "\n" $4 "\n" $5 "\n" $6 "\n" $7'} | grep -v "ntp" | grep -v "time" | grep -v "dns" | sort | uniq >>$TAG_DIR/$name/$name_exp/list_cname
		tshark -r $LAST_CAPT  -q -z hosts | awk 'NF && $1!~/^#/' | awk '{print $1}' | grep -v "ntp" | grep -v "time" | grep -v "dns" | sort | uniq > $TAG_DIR/$name/$name_exp/list_ipdom
		tshark -r $LAST_CAPT -T fields  -e ip.dst -e udp.port -E separator=\; | grep -v ",53" | grep -v "53," | grep -v ",123" | grep -v "123," | sort | uniq > $TAG_DIR/$name/$name_exp/list_ip
		tshark -r $LAST_CAPT -T fields  -e ip.src -e udp.port -E separator=\; | grep -v ",53" | grep -v "53," | grep -v ",123" | grep -v "123," | sort | uniq >> $TAG_DIR/$name/$name_exp/list_ip
		grep -v -f $TAG_DIR/$name/$name_exp/list_ipdom $TAG_DIR/$name/$name_exp/list_ip >$TAG_DIR/$name/$name_exp/list_ipnodom
		grep -v -f $TAG_DIR/$name/$name_exp/list_ipdom_pow $TAG_DIR/$name/$name_exp/list_ipnodom >$TAG_DIR/$name/$name_exp/list_ipnodom_dest_pow
		
		
		#call command to stop previous voices if any (e.g. music)
		if [[ $package == *"echo"* ]]; then
			$SPEAK_DIR/speak.sh $SPEAK_DIR/echo_stop.wav
		elif [[ $package == *"amazon"* ]]; then
			$SPEAK_DIR/speak.sh $SPEAK_DIR/amazon_stop.wav
		elif [[ $package == *"google"* ]]; then
			#script for google
			echo "GOOGLE STOP"
		elif [[ $package == *"siri"* ]]; then
			#script for siri
			echo "SIRI STOP"
		fi
		sleep 1

	#all other devices
	else
        #echo "Starting app for device" $name_dev
        waitphone
        adb -s $ANDROID_SERIAL shell -n monkey -p $package -c android.intent.category.LAUNCHER 1 >/dev/null
        sleep 15
        #scroll just in case and run functionalities
        #echo "Starting functionalities for device $name"
		
		#execute activity
		
		#this case is for roku: specific sleep times are used
		if [[ $name == "roku-tv" ]]; then
			[ -n "$function_1" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_1 ; sleep 5s )
			[ -n "$function_2" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_2 ; sleep 4s )
			[ -n "$function_3" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_3 ; sleep 4s )
			[ -n "$function_4" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_4 ; sleep 4s )
			[ -n "$function_5" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_5 ; sleep 15s )
			[ -n "$function_6" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_6 ; sleep 10s )
			[ -n "$function_7" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_7 ; sleep 45s )
			[ -n "$function_8" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_8 ; sleep 3s )
			[ -n "$function_9" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_9 ; sleep 3s )
			[ -n "$function_10" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_10 ; sleep 3s )
			[ -n "$function_11" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_11 ; sleep 3s )
			[ -n "$function_12" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_12 ; sleep 3s )
		
		#you can add cases here if needed
		#elif [[ $name == "switchbot-mini" ]]; then
		#	[ -n "$function_1" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_1 ; sleep 10s )
		#	[ -n "$function_2" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_2 ; sleep 10s )
		#	[ -n "$function_3" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_3 ; sleep 3s )
		#	[ -n "$function_4" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_4 ; sleep 3s )
		#	[ -n "$function_5" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_5 ; sleep 3s )
		#	[ -n "$function_6" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_6 ; sleep 3s )
		#	[ -n "$function_7" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_7 ; sleep 3s )
		#	[ -n "$function_8" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_8 ; sleep 3s )
		#	[ -n "$function_9" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_9 ; sleep 3s )
		#	[ -n "$function_10" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_10 ; sleep 3s )
		#	[ -n "$function_11" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_11 ; sleep 3s )
		#	[ -n "$function_12" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_12 ; sleep 3s )
		#	[ -n "$function_13" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_13 ; sleep 3s )
		#	[ -n "$function_14" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_14 ; sleep 3s )
		
		#elif [[ $name == "dev2" ]]; then
	
		#in all other cases
		else
			[ -n "$function_1" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_1 ; sleep 4s )
			[ -n "$function_2" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_2 ; sleep 4s )
			[ -n "$function_3" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_3 ; sleep 4s )
			[ -n "$function_4" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_4 ; sleep 4s )
			[ -n "$function_5" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_5 ; sleep 4s )
			[ -n "$function_6" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_6 ; sleep 4s )
			[ -n "$function_7" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_7 ; sleep 4s )
			[ -n "$function_8" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_8 ; sleep 4s )
			[ -n "$function_9" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_9 ; sleep 4s )
			[ -n "$function_10" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_10 ; sleep 4s )
			[ -n "$function_11" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_11 ; sleep 4s )
			[ -n "$function_12" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_12 ; sleep 4s )
			[ -n "$function_13" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_13 ; sleep 4s )
			[ -n "$function_14" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_14 ; sleep 4s )
		fi
        sleep $sleep2
	
		#stop capture experiment
		echo "Stop experiment for device" $name_dev
		echo $DATE $name $name_exp "ok" >> $TAG_DIR/$name/exp_okA
		$MONIOTR_DIR/bin/tag-experiment stop $name $name_exp >/dev/null
		sleep 2s
		
		#------------
		#process pcaps
		#-------------
		LAST_CAPT=$(ls $TAG_DIR/$name/$name_exp/*.pcap -t | grep -v companion |  grep -v http | head -n 1)
		tshark -r $LAST_CAPT -Y "dns.flags.response == 1" -T fields -E separator=\; -e dns.qry.name -e dns.a -E header=n -E quote=n | sort | uniq | awk -F ";" {'if($1) print $1'} | awk -F "," {'print $1 "\n" $2 "\n" $3 "\n" $4 "\n" $5 "\n" $6 "\n" $7'} | grep -v "ntp" | grep -v "time" | grep -v "dns" | sort | uniq>$TAG_DIR/$name/$name_exp/list_dest
		tshark -r $LAST_CAPT -T fields -e dns.qry.name -e dns.resp.name -E separator=\;  -E header=n -E quote=n | sort | uniq | awk -F ";" {'if($2) print $2'} | awk -F "," {'print $1 "\n" $2 "\n" $3 "\n" $4 "\n" $5 "\n" $6 "\n" $7'} | grep -v "ntp" | grep -v "time" | grep -v "dns" | sort | uniq >>$TAG_DIR/$name/$name_exp/list_cname
		tshark -r $LAST_CAPT  -q -z hosts | awk 'NF && $1!~/^#/' | awk '{print $1}' | grep -v "ntp" | grep -v "time" | grep -v "dns" | sort | uniq > $TAG_DIR/$name/$name_exp/list_ipdom
		tshark -r $LAST_CAPT -T fields  -e ip.dst -e udp.port -E separator=\; | grep -v ",53" | grep -v "53," | grep -v ",123" | grep -v "123," | sort | uniq > $TAG_DIR/$name/$name_exp/list_ip
		tshark -r $LAST_CAPT -T fields  -e ip.src -e udp.port -E separator=\; | grep -v ",53" | grep -v "53," | grep -v ",123" | grep -v "123," | sort | uniq >> $TAG_DIR/$name/$name_exp/list_ip
		grep -v -f $TAG_DIR/$name/$name_exp/list_ipdom $TAG_DIR/$name/$name_exp/list_ip >$TAG_DIR/$name/$name_exp/list_ipnodom
		grep -v -f $TAG_DIR/$name/$name_exp/list_ipdom_pow $TAG_DIR/$name/$name_exp/list_ipnodom >$TAG_DIR/$name/$name_exp/list_ipnodom_dest_pow
		#------------

		sleep 2s
    fi
	
	#------------
	#process dests
	#-------------
	rm $TAG_DIR/$name/$name_exp/dest_list2
	cat $TAG_DIR/$name/$name_exp/list_dest_pow | sort | uniq | awk -F ";" {'print $1'} | grep -v "192.168." | grep -v "146.179.255.34" | grep -v "155.198.142" | grep -v "224.0.0" | grep -v "239.255." | grep -v "255.255." | grep -v "0.0.0.0" > $TAG_DIR/$name/$name_exp/dest_list2
	cat $TAG_DIR/$name/$name_exp/list_ipnodom_pow | sort | uniq | awk -F ";" {'print $1'} | grep -v "192.168." | grep -v "146.179.255.34" | grep -v "155.198.142" | grep -v "224.0.0" | grep -v "239.255." | grep -v "255.255." | grep -v "0.0.0.0" >> $TAG_DIR/$name/$name_exp/dest_list2
	cat $TAG_DIR/$name/$name_exp/list_dest | sort | uniq | awk -F ";" {'print $1'} | grep -v "192.168." | grep -v "146.179.255.34" | grep -v "155.198.142" | grep -v "224.0.0" | grep -v "239.255." | grep -v "255.255." | grep -v "0.0.0.0" >> $TAG_DIR/$name/$name_exp/dest_list2
	cat $TAG_DIR/$name/$name_exp/list_ipnodom_dest_pow | sort | uniq | awk -F ";" {'print $1'} | grep -v "192.168." | grep -v "146.179.255.34" | grep -v "155.198.142" | grep -v "224.0.0" | grep -v "239.255." | grep -v "255.255." | grep -v "0.0.0.0" >> $TAG_DIR/$name/$name_exp/dest_list2

	echo "$DATE;$name_exp">>$TAG_DIR/$name/$name_exp/dest_list
	cat $TAG_DIR/$name/$name_exp/dest_list2 | sort | uniq | awk -F ";" {'print $1'} | grep -v "192.168." | grep -v "146.179.255.34" | grep -v "155.198.142" | grep -v "224.0.0" | grep -v "239.255." | grep -v "255.255." | grep -v "0.0.0.0" >> $TAG_DIR/$name/$name_exp/dest_list

	echo "$DATE;$name_exp">>$TAG_DIR/$name/$name_exp/list_dest_pow_all
	echo "$DATE;$name_exp">>$TAG_DIR/$name/$name_exp/list_dest_all
	cat $TAG_DIR/$name/$name_exp/list_ipnodom_pow | sort | uniq | grep -v "192.168." | grep -v "146.179.255.34" | grep -v "155.198.142" | grep -v "224.0.0" | grep -v "239.255." | grep -v "255.255." | grep -v "0.0.0.0" >>$TAG_DIR/$name/$name_exp/list_dest_pow_all
	cat $TAG_DIR/$name/$name_exp/list_ipnodom_dest_pow | sort | uniq | grep -v "192.168." | grep -v "146.179.255.34" | grep -v "155.198.142" | grep -v "224.0.0" | grep -v "239.255." | grep -v "255.255." | grep -v "0.0.0.0" >> $TAG_DIR/$name/$name_exp/list_dest_all
	cat $TAG_DIR/$name/$name_exp/list_dest_pow | sort | uniq | grep -v "192.168." | grep -v "146.179.255.34" | grep -v "155.198.142" | grep -v "224.0.0" | grep -v "239.255." | grep -v "255.255." | grep -v "0.0.0.0" >>$TAG_DIR/$name/$name_exp/list_dest_pow_all
	cat $TAG_DIR/$name/$name_exp/list_dest | sort | uniq | grep -v "192.168." | grep -v "146.179.255.34" | grep -v "155.198.142" | grep -v "224.0.0" | grep -v "239.255." | grep -v "255.255." | grep -v "0.0.0.0" >> $TAG_DIR/$name/$name_exp/list_dest_all
	#-------------

	#stop the CAPTURE experiment, if any
	$MONIOTR_DIR/bin/tag-experiment stop $name $name_exp >/dev/null
	
	#close the APPs
	adb -s $ANDROID_SERIAL shell -n am force-stop $package
	adb -s $ANDROID_SERIAL shell -n am force-stop "com.android.chrome" #close chrome, if any ad opened
	adb -s $ANDROID_SERIAL shell -n am force-stop "com.android.vending" #close play store, if any ad opened
		
done < $EXP_FILE
