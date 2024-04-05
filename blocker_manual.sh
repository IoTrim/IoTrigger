#!/bin/bash
#This script guides the user to check the blocker procedure. It blocks destinations one-by-one, it asks
#to execute the activity and asks to report the result (success or not)


#Run with sudo permissions and pass the experiment filename in first parameter
#EXAMPLE: sudo ./blocker_manual.sh switchbot-mini



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


POWER_SCRIPT="$IOTRIM_DIR/kasa-power.py"
SPEAK_DIR="$IOTRIM_DIR/speak"
TAG_DIR="$MONIOTR_DIR/traffic/tagged"

EXP_FILE="$IOTRIM_DIR/experiments/$exp_name"

#optional parameters to filter only specific device or exp name in the experiment file
DO_DEVICE="$2"
DO_EXPERIMENT="$3"

waitphone() {
    while [ -z "$PHONE_FOUND" ]; do
        echo "Phone not found, waiting for $PHONE/$ANDROID_SERIAL"
        sleep 5
        PHONE_FOUND=`adb devices | grep $ANDROID_SERIAL`
    done
}

#read exp file
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
	
	
	#set the screenshot directory
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
	
	
   	$MONIOTR_DIR/bin/dns-override wipe $name >/dev/null
	$MONIOTR_DIR/bin/ip-block wipe $name >/dev/null
    while read dest
    do
		DATE=`date "+%Y%m%d_%H%M%S"`
        if [[ "${dest}" =~ [a-z] ]]; then
            $MONIOTR_DIR/bin/dns-override add $name $dest NXDOMAIN 
        else
            $MONIOTR_DIR/bin/ip-block add $name $dest all all
        fi
		
		
		
		if [ $onoff = "1" ]; then
			#cancel previous power experiments if any
			$MONIOTR_DIR/bin/tag-experiment cancel $name "power" >/dev/null
			$MONIOTR_DIR/bin/tag-experiment start $name "power" >/dev/null
			python3 $POWER_SCRIPT $plug_name "off" #switch off device
			sleep 5s
			python3 $POWER_SCRIPT $plug_name "on" #switch on device
			sleep 30s
			$MONIOTR_DIR/bin/tag-experiment stop $name "power"
		fi
		
		
        # Ignore commented lines starting with # (spaces before # are allowed)
        [[ $name  =~ ^[[:space:]]*# ]] && continue
        # Ignore empty lines and lines with only spaces
        [[ $name  =~ ^[[:space:]]*$ ]] && continue

        echo "Cancel past experiment $name_exp for device $name"
        [ "$TAG_DIR" != "notag" ] && $MONIOTR_DIR/bin/tag-experiment cancel $name $name_exp
		
		sleep $sleep1
		
		
		
		if [[ $package == "echo" || $package == "google" || $package == "allure-speaker" || $package == "amazon" ]]; then
			
			echo "PRESS ENTER when you want to start the activity"
			read dumb < /dev/tty
			echo "Starting experiment $name_exp for device $name. Execute the activity then wait"
			$MONIOTR_DIR/bin/tag-experiment start $name $name_exp >/dev/null
			sleep 2
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
			
			#implement here the check of the speaker function
			sudo python3 $SPEAK_DIR/speak_probe_check/check_speak_execution_rfnorm.py $name $name_exp $DATE
			file_path="$CAPT_DIR/${name_exp}.${DATE}"
			COMP=$(<"$file_path")
			echo "Auto check detected as $COMP"
			echo "TYPE OK if activity was good, or NO if not"
			read COMP < /dev/tty
			
			if [[ "$COMP" == "OK" || "$COMP" == "ok" ]]; then
				#if [ $COMP = "0" ]; then
				echo "Activity noted as OK"
				echo $DATE $name $name_exp $dest "ok" >> $TAG_DIR/$name/$name_exp/res_block_manual
				sleep 2s
			else
				echo "Activity noted as FAILED"
				echo $DATE $name $name_exp $dest "failed" >> $TAG_DIR/$name/$name_exp/res_block_manual
				if [[ "${dest}" =~ [a-z] ]]; then
					$MONIOTR_DIR/bin/dns-override del $name $dest >/dev/null
				else
					$MONIOTR_DIR/bin/ip-block del $name $dest all all >/dev/null
				fi
			fi
			
		
		else
			#echo "Starting app for device" $name_dev
			waitphone
			adb -s $ANDROID_SERIAL shell -n monkey -p $package -c android.intent.category.LAUNCHER 1
			
			
			echo "PRESS ENTER AND RUN THE ACTIVITY $name_exp FOR THE DEVICE $name"
			read dumb < /dev/tty
			echo "Starting experiment $name_exp for device $name. Execute the activity then wait"
			$MONIOTR_DIR/bin/tag-experiment start $name $name_exp >/dev/null
			sleep $sleep2
			echo "Stopped experiment for device" $name_dev
			$MONIOTR_DIR/bin/tag-experiment stop $name $name_exp $TAG_DIR >/dev/null
			
			echo "Type OK if activity was good, or NO if not"
			read COMP < /dev/tty
			if [[ "$COMP" == "OK" || "$COMP" == "ok" ]]; then
				echo "Activity noted as OK"
				#if [ $COMP = "0" ]; then
				echo $DATE $name $name_exp $dest "ok" >> $TAG_DIR/$name/$name_exp/res_block_manual
				sleep 2s
				echo $TAG_DIR/$name/$name_exp
			else
				echo "Activity noted as FAILED"
				echo $DATE $name $name_exp $dest "failed" >> $TAG_DIR/$name/$name_exp/res_block_manual
				if [[ "${dest}" =~ [a-z] ]]; then
					$MONIOTR_DIR/bin/dns-override del $name $dest >/dev/null
				else
					$MONIOTR_DIR/bin/ip-block del $name $dest all all >/dev/null
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
		tshark -r $LAST_CAPT -Y "dns.flags.response == 1" -T fields -E separator=\; -e dns.qry.name -e dns.a -E header=n -E quote=n | sort | uniq | awk -F ";" {'if($1) print $1'} | awk -F "," {'print $1 "\n" $2 "\n" $3 "\n" $4 "\n" $5 "\n" $6 "\n" $7'} | grep -v "ntp" | grep -v "time" | grep -v "dns" | sort | uniq>$TAG_DIR/$name/$name_exp/list_dest_block
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
	
		grep -v '^$' $TAG_DIR/$name/rec_dest_block | grep -v "^$(cat $MONIOTR_DIR/traffic/by-name/$name/ip.txt | cut -d. -f1-3)" | grep -v '\.local' | sort -u > $TAG_DIR/$name/rec_dest_unique_block			
		chmod o+w $TAG_DIR/$name/rec_dest_unique_block
		chmod o+w $TAG_DIR/$name/rec_dest_block
		chmod o+w $TAG_DIR/$name/$name_exp/res_block_manual
		#--------------------------------------
		#end of Optional block
		#####################################



	done < $TAG_DIR/$name/rec_dest_unique
	$MONIOTR_DIR/bin/dns-override wipe $name
	$MONIOTR_DIR/bin/ip-block wipe $name
done < $EXP_FILE

