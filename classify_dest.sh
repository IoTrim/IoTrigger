#!/bin/bash
#To retry the list of installed apps: adb shell "pm list packages -3"|cut -f 2 -d ":"
#To check the coordinate to tap: settings/Developer options/Pointer location

DATE=`date "+%Y%m%d_%H%M%S"`

#./auto_app2multi_list_dest.sh $phone $file_dev $dir_data

# The first parameter $1 should be the phone name, and a file "ids/phone_name" must exist
# If running the script witho only the first  parameter, dev_auto is used, and all experiments executed and tagged
# If running the script with additional parameters: $2 is the experiment file (default: 'dev_auto')
# $3 is the tag dir. If it is 'default' the experiment is tagged in the default directory, if 'notag' the experiment is not tagged (default: 'default') 
# $4 is the device to experiment with (if the option is not provided, all devices will be tested)
# $5 is the experiment to be started (if the option is not provided, all experiments for the chosen device will be started)
CAPT_DIR="$1"
PHONE="$2"
DEV_AUTO="$3"
TAG_DIR="$4"
DO_DEVICE="$5"
DO_EXPERIMENT="$6"

while IFS=";" read name name_exp crop phone_exp package sleep1 sleep2 function_1 function_2 function_3 function_4 function_5 function_6 function_7 function_8 function_9
do
count_exp=$(grep $name_exp $TAG_DIR/$name/$name_exp/dest_list | wc -l)
grep -v $name_exp $TAG_DIR/$name/$name_exp/dest_list | sort | uniq -c | awk -v c=$count_exp {'if((c-$1)<=3) print $1";"$2'} > $TAG_DIR/$name/$name_exp/rec_dest
grep -v $name_exp $TAG_DIR/$name/$name_exp/dest_list | sort | uniq -c | awk -v c=$count_exp {'if((c-$1)>3) print $1";"$2'} > $TAG_DIR/$name/$name_exp/unrec_dest
done < $DEV_AUTO
