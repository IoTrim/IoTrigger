#!/bin/bash

#This script simply executes the activity from the experiment file.
#All activities are logged to the LOG directory, with a file per device
#App-controlled devices have the check with the screenshot to log success or not

#Run with sudo permissions and pass the experiment filename in first parameter
#EXAMPLE: sudo ./trigger_function.sh switchbot-mini

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



CAPT_BASE_DIR="$IOTRIM_DIR/captures"
EXP_FILE="$IOTRIM_DIR/experiments/$exp_name"
SPEAK_DIR="$IOTRIM_DIR/speak"
LOG_DIR="$IOTRIM_DIR/logs"
NETWORK_DIR="$IOTRIM_DIR/networks"

#this function is to wait for the phone to be available
waitphone() {
    while [ -z "$PHONE_FOUND" ]; do
        echo "Phone not found, waiting for $PHONE/$ANDROID_SERIAL"
        sleep 5
        PHONE_FOUND=`adb devices | grep $ANDROID_SERIAL`
    done
}


#read the experiment file
while IFS=";" read name plug_name onoff name_exp crop phone_exp package network sleep1 sleep2 function_1 function_2 function_3 function_4 function_5 function_6 function_7 function_8 function_9
do
	echo "running activity for device $name: $name_exp"
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
	
	
	#be sure you connected to the proper network (if local, get the local interface, otherwise use the network from file)
	#if [[ $network == "local" ]]; then
	#	network_name=$(cat $MONIOTR_DIR/traffic/by-name/$name/monitor-if.txt)
	#	IFS=";" read net_ssid net_passwd < $NETWORK_DIR/$network_name
	#else
	#	IFS=";" read net_ssid net_passwd < $NETWORK_DIR/$network
	#fi
	#EXPECTED_RESULT=$net_ssid
	## Check if expected network name and actual network name correspond, otherwise re-connect
	#until [[ "$CONNECTION_STATUS" == *"$EXPECTED_RESULT"* ]]; do
	#	sleep 10s
	#	CONNECTION_STATUS=$(adb -s "$ANDROID_SERIAL" shell dumpsys netstats | grep -E 'iface=wlan.*networkId')
	#	if [[ "$CONNECTION_STATUS" == *"$EXPECTED_RESULT"* ]]; then
	#		continue
	#	fi
	#	adb -s "$ANDROID_SERIAL" shell "su -c 'cmd wifi connect-network $net_ssid wpa2 $net_passwd'"
	#done
	
	
	
	#if the device is a speaker, the activity calls a script to SPEAK 
	if [[ $package == "echo" || $package == "google" || $package == "allure-speaker" || $package == "amazon" ]]; then
		
		#sleep BEFORE the activity is executed
		sleep $sleep1
		echo "Running experiment for the speaker: " $package
		DATE_START=`date "+%Y%m%d_%H%M%S"`
		
		#call the activity script
		$SPEAK_DIR/speak.sh $SPEAK_DIR/$function_1
		
		#sleep AFTER the activity is executed
		sleep $sleep2
		
		#call command to stop previous voices if any (e.g. music)
		if [[ $package == "echo" ]]; then
			$SPEAK_DIR/speak.sh $SPEAK_DIR/echo_stop.wav
		elif [[ $package == "amazon" ]]; then
			$SPEAK_DIR/speak.sh $SPEAK_DIR/amazon_stop.wav
		elif [[ $package == "google" ]]; then
			#script for google
			echo "GOOGLE STOP"
		elif [[ $package == "siri" ]]; then
			#script for siri
			echo "SIRI STOP"
		fi
		DATE_STOP=`date "+%Y%m%d_%H%M%S"`
		echo "${DATE_START}-${DATE_STOP} $name $name_exp" >> $LOG_DIR/$name.txt
		sleep 1
	
	#all the other devices require to interact with the app
	else
		
		CAPT_DIR=$CAPT_BASE_DIR/$name
		sleep 10
		
		#open the APP in the smartphone
		waitphone
		adb -s $ANDROID_SERIAL shell -n monkey -p $package -c android.intent.category.LAUNCHER 1
		
		DATE_START=`date "+%Y%m%d_%H%M%S"`
		DATE=$DATE_START
		
		#sleep BEFORE the activity is executed
		sleep $sleep1
		
		#echo "Starting functionalities for device $name"
		#execute the activity clicking on the phone
		
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
		else
			[ -n "$function_1" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_1 ; sleep 8s )
			[ -n "$function_2" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_2 ; sleep 3s )
			[ -n "$function_3" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_3 ; sleep 3s )
			[ -n "$function_4" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_4 ; sleep 3s )
			[ -n "$function_5" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_5 ; sleep 3s )
			[ -n "$function_6" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_6 ; sleep 3s )
			[ -n "$function_7" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_7 ; sleep 3s )
			[ -n "$function_8" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_8 ; sleep 3s )
			[ -n "$function_9" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_9 ; sleep 3s )
			[ -n "$function_10" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_10 ; sleep 3s )
			[ -n "$function_11" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_11 ; sleep 3s )
			[ -n "$function_12" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_12 ; sleep 3s )
		fi
		DATE_STOP=`date "+%Y%m%d_%H%M%S"`
		
		#sleep AFTER the activity is executed
		sleep $sleep2
		
		#------------------------------
		#capture screenshot and compare
		#------------------------------
		waitphone
		adb -s $ANDROID_SERIAL shell -n screencap -p /sdcard/screen_exp.png
		waitphone
		adb -s $ANDROID_SERIAL pull /sdcard/screen_exp.png $CAPT_DIR/${name}.${name_exp}.${DATE}.png
		waitphone
		adb -s $ANDROID_SERIAL shell -n rm /sdcard/screen_exp.png
		
		#wyze app if screenshot is equal then fails 
		if [[ $name == "wyze-cam-pan" ]]; then
			NEGCOMP=$(convert $CAPT_DIR/reference/$phone_exp/${name}.${name_exp}.png $CAPT_DIR/${name}.${name_exp}.${DATE}.png -crop $crop +repage miff:- | compare -verbose -metric MAE  - $CAPT_DIR/out.${name}.${name_exp}.${DATE}.png 2>&1 | grep all | awk '{print $2}')
			if [ $NEGCOMP == "0" ]; then
				COMP="0"
			else
				COMP="1"
			fi
		else
			COMP=$(convert $CAPT_DIR/reference/$phone_exp/${name}.${name_exp}.png $CAPT_DIR/${name}.${name_exp}.${DATE}.png -crop $crop +repage miff:- | compare -verbose -metric MAE  - $CAPT_DIR/out.${name}.${name_exp}.${DATE}.png 2>&1 | grep all | awk '{print $2}')
			COMP2=$(convert $CAPT_DIR/reference/$phone_exp/${name}.${name_exp}2.png $CAPT_DIR/${name}.${name_exp}.${DATE}.png -crop $crop +repage miff:- | compare -verbose -metric MAE  - $CAPT_DIR/out.${name}.${name_exp}2.${DATE}.png 2>&1 | grep all | awk '{print $2}')
		fi
		
		if [[ $COMP == "0" || $COMP2 == "0" ]]; then
			echo "${DATE_START}-${DATE_STOP} $name $name_exp ok" >> $LOG_DIR/$name.txt
		else
			echo "${DATE_START}-${DATE_STOP} $name $name_exp failed" >> $LOG_DIR/$name.txt
		
		fi
		#------------------------------
		
		#stop the APP and other eventuals (e.g. chrome, play store)
		waitphone
		adb -s $ANDROID_SERIAL shell -n am force-stop $package
		adb -s $ANDROID_SERIAL shell -n am force-stop "com.android.chrome"
		adb -s $ANDROID_SERIAL shell -n am force-stop "com.android.vending"
		
		sleep 2s
	fi
done < "$EXP_FILE"

