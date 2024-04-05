#!/bin/bash
# This scripts blocks one-by-one the destinations located in the file:
# $MONIOTR_DIR/traffic/tagged/$dev_name/rec_dest_unique
# After blocking the destinations, the scripts executes the function and check that it is executed correctly

#Run with sudo permissions and pass the experiment filename in first parameter
#EXAMPLE: sudo ./blocker.sh switchbot-mini


# The first parameter $1 should be the experiment filename (file to be placed in the $MONIOTR_DIR/experiments folder)
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
SPEAK_DIR="$IOTRIM_DIR/speak"
EXP_FILE="$IOTRIM_DIR/experiments/$exp_name"


#optional parameters to filter only specific device or exp name in the experiment file
DO_DEVICE="$2"
DO_EXPERIMENT="$3"

#function to wait the proper phone to be plugged
waitphone() {
    while [ -z "$PHONE_FOUND" ]; do
        echo "Phone not found, waiting for $PHONE/$ANDROID_SERIAL"
        sleep 5
        PHONE_FOUND=`adb devices | grep $ANDROID_SERIAL`
    done
}


#read the experiment file
while IFS=";" read name plug_name onoff name_exp crop phone_exp package network sleep1 sleep2 function_1 function_2 function_3 function_4 function_5 function_6 function_7 function_8 function_9 function_10 function_11 function_12 function_13 function_14
do 
	# Ignore empty lines in the experiment file
	[[ -z "$name" ]] && continue
	
	# Ignore commented lines starting with # (spaces before # are allowed)
    [[ $name  =~ ^[[:space:]]*# ]] && continue
    # Ignore empty lines and lines with only spaces
    [[ $name  =~ ^[[:space:]]*$ ]] && continue
	
	# Run only experiments matching the given device (if provided)
	[[ -n "$DO_DEVICE" ]] && [[ "$DO_DEVICE" != "$name" ]] && continue
    # Run only experiments matching the given experiment name (if provided)
    [[ -n "$DO_EXPERIMENT" ]] && [[ "$DO_EXPERIMENT" != "$name_exp" ]] && continue
	
	
	#set the screenshot directory parameter using device name
	CAPT_DIR="$IOTRIM_DIR/captures/$name"
	
	#read phone and wait it is ready
	PHONE=$phone_exp
	if [ ! -f "ids/$PHONE" ]; then
		echo "File ids/$phone_exp not found, skipping..."
		continue
    fi
	ANDROID_SERIAL=$(cat ids/$PHONE)
	PHONE_FOUND=`adb devices | grep $ANDROID_SERIAL | grep device`
	waitphone
	echo Phone ready, proceeding...

	
    #delete previous blocked destinations
	$MONIOTR_DIR/bin/dns-override wipe $name
	$MONIOTR_DIR/bin/ip-block wipe $name
	
	#For each detinations in the "rec_dest_unique" file:
    while read dest
    do
		DATE=`date "+%Y%m%d_%H%M%S"`
		
		#block the destinations (ip or domain)
        if [[ "${dest}" =~ [a-z] ]]; then
            $MONIOTR_DIR/bin/dns-override add $name $dest NXDOMAIN
        else
            $MONIOTR_DIR/bin/ip-block add $name $dest all all
        fi
		

		#if the ONOFF parameter is set tot 1, then run the POWER experiment
		if [ $onoff = "1" ]; then
			#cancel previous power experiments if any and start a new one
			$MONIOTR_DIR/bin/tag-experiment cancel $name "power"
			$MONIOTR_DIR/bin/tag-experiment start $name "power"
			python3 $POWER_SCRIPT $plug_name "off" #switch off device, sleep 5s then back on
			sleep 5s #sleep after device is off
			python3 $POWER_SCRIPT $plug_name "on" #switch on device
			sleep 80s #sleep after turning the device on
			$MONIOTR_DIR/bin/tag-experiment stop $name "power"
		fi
		
		#sleep BEFORE the activity is performed
		sleep $sleep1
		
		#start experiment for the device (cancel previous if any)
		$MONIOTR_DIR/bin/tag-experiment cancel $name $name_exp
        echo "Starting experiment $name_exp for device $name"
        $MONIOTR_DIR/bin/tag-experiment start $name $name_exp
		
		sleep 5
		
		#SPEAKER CASE (amazon echo, google home etc)
		if [[ $package == "echo" || $package == "google" || $package == "allure-speaker" || $package == "amazon" ]]; then
			echo "Running experiment for the speaker: " $package
			#Call the speak script for speaker
			$SPEAK_DIR/speak.sh $SPEAK_DIR/$function_1
			sleep $sleep2

			$MONIOTR_DIR/bin/tag-experiment stop $name $name_exp $TAG_DIR
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
			sleep 1
			
			#Call the probe checker for the speak case
			sudo python3 $SPEAK_DIR/speak_probe_check/check_speak_execution_rfnorm.py $name $name_exp $DATE
			file_path="$CAPT_DIR/${name_exp}.${DATE}"
			COMP=$(<"$file_path")
			
			if [ "$COMP" == "OK" ]; then
				#if [ $COMP = "0" ]; then
				echo $DATE $name $name_exp $dest "ok" >> $TAG_DIR/$name/$name_exp/res_block
				sleep 2s
			else
				echo $DATE $name $name_exp $dest "failed" >> $TAG_DIR/$name/$name_exp/res_block
				if [[ "${dest}" =~ [a-z] ]]; then
					$MONIOTR_DIR/bin/dns-override del $name $dest
				else
					$MONIOTR_DIR/bin/ip-block del $name $dest all all
				fi
			fi
			
		
		else #ALL OTHER CASES NOT SPEAKEERS
			waitphone
			adb -s $ANDROID_SERIAL shell -n monkey -p $package -c android.intent.category.LAUNCHER 1
			sleep 15
			
			#ROKUTV NEEDS SPECIFIC TIMINGS
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
			#elif [[ $name == "DEVICE_NAME" ]]; then
			#	[ -n "$function_1" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_1 ; sleep 5s )
			#	[ -n "$function_2" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_2 ; sleep 4s )
			#	[ -n "$function_3" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_3 ; sleep 4s )
			#	[ -n "$function_4" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_4 ; sleep 4s )
			#	[ -n "$function_5" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_5 ; sleep 15s )
			#	[ -n "$function_6" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_6 ; sleep 10s )
			#	[ -n "$function_7" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_7 ; sleep 45s )
			#	[ -n "$function_8" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_8 ; sleep 3s )
			#	[ -n "$function_9" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_9 ; sleep 3s )
			#	[ -n "$function_10" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_10 ; sleep 3s )
			#	[ -n "$function_11" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_11 ; sleep 3s )
			#	[ -n "$function_12" ] && ( waitphone ; adb -s $ANDROID_SERIAL shell -n input $function_12 ; sleep 3s )
			
			#all other cases (non roku and non speakers)
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
			
			#Sleep AFTER the activity is executed, and before stopping experiment
			sleep $sleep2
			
			
			#STOP the experiment
			echo "Stop experiment for device" $name_dev
			$MONIOTR_DIR/bin/tag-experiment stop $name $name_exp $TAG_DIR
			
			#PROBE CHECKER for non-speakers
			
			
			#roku case (being a tv, check on traffic)
			if [[ $name == "roku-tv" ]]; then
				#implement here the check of the speaker function
				sudo python3 $SPEAK_DIR/speak_probe_check/check_speak_execution_simple.py $name $name_exp $DATE
				file_path="$CAPT_DIR/${name_exp}.${DATE}"
				COMP_FILE=$(<"$file_path")
				if [[ $COMP_FILE == "OK" ]]; then
					COMP=0
				else
					COMP=1
				fi
				
			#all other cases (non-speakers not roku)
			#check the screenshot!
			else
				#capture screenshot
				waitphone
				adb -s $ANDROID_SERIAL shell -n screencap -p /sdcard/screen_exp.png
				waitphone
				adb -s $ANDROID_SERIAL pull /sdcard/screen_exp.png $CAPT_DIR/${name}.${name_exp}.${DATE}.png
				waitphone
				adb -s $ANDROID_SERIAL shell -n rm /sdcard/screen_exp.png
				
				#Wyze app has a negative comparison (if match, then it didnt work (e.g. streaming rate=0)
				if [[ $name == "wyze-cam-pan" ]]; then
					NEGCOMP=$(convert $CAPT_DIR/reference/$phone_exp/${name}.${name_exp}.png $CAPT_DIR/${name}.${name_exp}.${DATE}.png -crop $crop +repage miff:- | compare -verbose -metric MAE  - $CAPT_DIR/out.${name}.${name_exp}.${DATE}.png 2>&1 | grep all | awk '{print $2}')
					if [[ $NEGCOMP == "0" ]]; then
						COMP="1"
					else
						COMP="0"
					fi
				#check the screen and if match the activity worked
				else
					COMP=$(convert $CAPT_DIR/reference/$phone_exp/${name}.${name_exp}.png $CAPT_DIR/${name}.${name_exp}.${DATE}.png -crop $crop +repage miff:- | compare -verbose -metric MAE  - $CAPT_DIR/out.${name}.${name_exp}.${DATE}.png 2>&1 | grep all | awk '{print $2}')
					COMP2=$(convert $CAPT_DIR/reference/$phone_exp/${name}.${name_exp}2.png $CAPT_DIR/${name}.${name_exp}.${DATE}.png -crop $crop +repage miff:- | compare -verbose -metric MAE  - $CAPT_DIR/out.${name}.${name_exp}2.${DATE}.png 2>&1 | grep all | awk '{print $2}')
				fi
			fi
			
			
			#if match, activity succeded (non-essential destination)
			if [[ $COMP == "0" || $COMP2 == "0" ]]; then
				echo $DATE $name $name_exp $dest "ok" >> $TAG_DIR/$name/$name_exp/res_block
				sleep 2s
			#if no match, activity failed (essential destination)
			else
				echo $DATE $name $name_exp $dest "failed" >> $TAG_DIR/$name/$name_exp/res_block
				if [[ "${dest}" =~ [a-z] ]]; then
					$MONIOTR_DIR/bin/dns-override del $name $dest
				else
					$MONIOTR_DIR/bin/ip-block del $name $dest all all
				fi
			fi
			waitphone
			adb -s $ANDROID_SERIAL shell -n am force-stop $package
			sleep 2s
		fi
		echo $dest
		
		
		#this is for processing all destinations contacted when blocking the destinatin
		#----------------
		# THIS BLOCK IS Optional anc can be removed
		LAST_CAPT=$(ls $TAG_DIR/$name/$name_exp/*.pcap -t | grep -v companion |  grep -v http | head -n 1)
		tshark -r $LAST_CAPT -Y "dns.flags.response == 1" -T fields -E separator=\; -e dns.qry.name -e dns.a -E header=n -E quote=n | sort | uniq | awk -F ";" {'if($1) print $1'} | awk -F "," {'print $1 "\n" $2 "\n" $3 "\n" $4 "\n" $5 "\n" $6 "\n" $7'} | grep -v "ntp" | grep -v "time" | grep -v "dns" | sort | uniq > $TAG_DIR/$name/$name_exp/list_dest_block
		tshark -r $LAST_CAPT -T fields -e dns.qry.name -e dns.resp.name -E separator=\;  -E header=n -E quote=n | sort | uniq | awk -F ";" {'if($2) print $2'} | awk -F "," {'print $1 "\n" $2 "\n" $3 "\n" $4 "\n" $5 "\n" $6 "\n" $7'} | grep -v "ntp" | grep -v "time" | grep -v "dns" | sort | uniq >>$TAG_DIR/$name/$name_exp/list_cname_block
		tshark -r $LAST_CAPT  -q -z hosts | awk 'NF && $1!~/^#/' | awk '{print $1}' | grep -v "ntp" | grep -v "time" | grep -v "dns" | sort | uniq > $TAG_DIR/$name/$name_exp/list_ipdom_block
		tshark -r $LAST_CAPT -T fields  -e ip.dst -e udp.port -E separator=\; | grep -v ",53" | grep -v "53," | grep -v ",123" | grep -v "123," | sort | uniq > $TAG_DIR/$name/$name_exp/list_ip_block
		tshark -r $LAST_CAPT -T fields  -e ip.src -e udp.port -E separator=\; | grep -v ",53" | grep -v "53," | grep -v ",123" | grep -v "123," | sort | uniq >> $TAG_DIR/$name/$name_exp/list_ip_block
		grep -v -f $TAG_DIR/$name/$name_exp/list_ipdom_block $TAG_DIR/$name/$name_exp/list_ip_block >$TAG_DIR/$name/$name_exp/list_ipnodom_block
		grep -v -f $TAG_DIR/$name/$name_exp/list_ipdom_pow_block $TAG_DIR/$name/$name_exp/list_ipnodom_block >$TAG_DIR/$name/$name_exp/list_ipnodom_dest_pow_block
		rm $TAG_DIR/$name/$name_exp/dest_list2_block
		cat $TAG_DIR/$name/$name_exp/list_dest_pow_block | sort | uniq | awk -F ";" {'print $1'} | grep -v "192.168." | grep -v "146.179.255.34" | grep -v "155.198.142" | grep -v "224.0.0" | grep -v "239.255." | grep -v "255.255." | grep -v "0.0.0.0" > $TAG_DIR/$name/$name_exp/dest_list2_block
		cat $TAG_DIR/$name/$name_exp/list_ipnodom_pow_block | sort | uniq | awk -F ";" {'print $1'} | grep -v "192.168." | grep -v "146.179.255.34" | grep -v "155.198.142" | grep -v "224.0.0" | grep -v "239.255." | grep -v "255.255." | grep -v "0.0.0.0" >> $TAG_DIR/$name/$name_exp/dest_list2_block
		cat $TAG_DIR/$name/$name_exp/list_dest_block | sort | uniq | awk -F ";" {'print $1'} | grep -v "192.168." | grep -v "146.179.255.34" | grep -v "155.198.142" | grep -v "224.0.0" | grep -v "239.255." | grep -v "255.255." | grep -v "0.0.0.0" >> $TAG_DIR/$name/$name_exp/dest_list2_block
		cat $TAG_DIR/$name/$name_exp/list_ipnodom_dest_pow_block | sort | uniq | awk -F ";" {'print $1'} | grep -v "192.168." | grep -v "146.179.255.34" | grep -v "155.198.142" | grep -v "224.0.0" | grep -v "239.255." | grep -v "255.255." | grep -v "0.0.0.0" >> $TAG_DIR/$name/$name_exp/dest_list2_block

		echo "$DATE;$name_exp">>$TAG_DIR/$name/$name_exp/dest_list_block
		cat $TAG_DIR/$name/$name_exp/dest_list2_block | sort | uniq | awk -F ";" {'print $1'} | grep -v "192.168." | grep -v "146.179.255.34" | grep -v "155.198.142" | grep -v "224.0.0" | grep -v "239.255." | grep -v "255.255." | grep -v "0.0.0.0" >> $TAG_DIR/$name/$name_exp/dest_list_block

		echo "$DATE;$name_exp">>$TAG_DIR/$name/$name_exp/list_dest_pow_all_block
		echo "$DATE;$name_exp">>$TAG_DIR/$name/$name_exp/list_dest_all_block
		cat $TAG_DIR/$name/$name_exp/list_ipnodom_pow_block | sort | uniq | grep -v "192.168." | grep -v "146.179.255.34" | grep -v "155.198.142" | grep -v "224.0.0" | grep -v "239.255." | grep -v "255.255." | grep -v "0.0.0.0" >>$TAG_DIR/$name/$name_exp/list_dest_pow_all_block
		cat $TAG_DIR/$name/$name_exp/list_ipnodom_dest_pow_block | sort | uniq | grep -v "192.168." | grep -v "146.179.255.34" | grep -v "155.198.142" | grep -v "224.0.0" | grep -v "239.255." | grep -v "255.255." | grep -v "0.0.0.0" >> $TAG_DIR/$name/$name_exp/list_dest_all_block
		cat $TAG_DIR/$name/$name_exp/list_dest_pow_block | sort | uniq | grep -v "192.168." | grep -v "146.179.255.34" | grep -v "155.198.142" | grep -v "224.0.0" | grep -v "239.255." | grep -v "255.255." | grep -v "0.0.0.0" >>$TAG_DIR/$name/$name_exp/list_dest_pow_all_block
		cat $TAG_DIR/$name/$name_exp/list_dest_block | sort | uniq | grep -v "192.168." | grep -v "146.179.255.34" | grep -v "155.198.142" | grep -v "224.0.0" | grep -v "239.255." | grep -v "255.255." | grep -v "0.0.0.0" >> $TAG_DIR/$name/$name_exp/list_dest_all_block
		count_exp=$(grep $name_exp $TAG_DIR/$name/$name_exp/dest_list | wc -l)
		grep -v $name_exp $TAG_DIR/$name/$name_exp/dest_list_block | sort | uniq -c | awk -v c=$count_exp {'if((c-$1)<=3) print $2'} > $TAG_DIR/$name/$name_exp/rec_dest_block
		grep -v $name_exp $TAG_DIR/$name/$name_exp/dest_list_block | sort | uniq -c | awk -v c=$count_exp {'if((c-$1)>3) print $2'} > $TAG_DIR/$name/$name_exp/unrec_dest_block
		
		cat $TAG_DIR/$name/*/rec_dest_block >> $TAG_DIR/$name/rec_dest_block
		cat $TAG_DIR/$name/*/unrec_dest_block >> $TAG_DIR/$name/unrec_dest_block
	
		grep -v '^$' $TAG_DIR/$name/rec_dest_block | grep -v "^$(cat $MONIOTR_DIR/traffic/by-name/$name/ip.txt | cut -d. -f1-3)" | grep -v '\.local' | sort -u > $TAG_DIR/$name/rec_dest_unique_block
		grep -v '^$' $TAG_DIR/$name/unrec_dest_block | grep -v "^$(cat $MONIOTR_DIR/traffic/by-name/$name/ip.txt | cut -d. -f1-3)" | grep -v '\.local' | sort -u > $TAG_DIR/$name/unrec_dest_unique_block
		chmod o+w $TAG_DIR/$name/rec_dest_unique_block
		chmod o+w $TAG_DIR/$name/unrec_dest_unique_block
		chmod o+w $TAG_DIR/$name/rec_dest_block
		chmod o+w $TAG_DIR/$name/unrec_dest_block
		chmod o+w $TAG_DIR/$name/$name_exp/res_block
		#--------------------------------------
		#end of Optional block
		#####################################

	done < $TAG_DIR/$name/rec_dest_unique #do this for each unique destination in this file
	
	#remove all the blocked destinations for next experiment.
	$MONIOTR_DIR/bin/dns-override wipe $name
	$MONIOTR_DIR/bin/ip-block wipe $name
done < $EXP_FILE
