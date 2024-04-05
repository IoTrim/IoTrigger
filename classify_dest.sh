#!/bin/bash
# This script analyze the destinations files and create the list of reccurrent/non-reccurent activities.
# Lists are stored in the folder $MONIOTR_DIR/traffic/tagged/$device_name


#Run with sudo permissions and pass the experiment filename in first parameter
#EXAMPLE: sudo ./classify_dest.sh switchbot-mini

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
EXP_FILE="$IOTRIM_DIR/experiments/$exp_name"

DEVICE=""
while IFS=";" read name plug_name onoff name_exp crop phone_exp package network sleep1 sleep2 function_1 function_2 function_3 function_4 function_5 function_6 function_7 function_8 function_9 function_10 function_11 function_12 function_13 function_14
do
	# Ignore empty lines
	[[ -z "$name" ]] && continue
	# Ignore commented lines starting with # (spaces before # are allowed)
    [[ $name  =~ ^[[:space:]]*# ]] && continue
    # Ignore empty lines and lines with only spaces
    [[ $name  =~ ^[[:space:]]*$ ]] && continue
	
	count_exp=$(grep $name_exp $TAG_DIR/$name/$name_exp/dest_list | wc -l)
	#grep -v $name_exp $TAG_DIR/$name/$name_exp/dest_list | sort | uniq -c | awk -v c=$count_exp {'if((c-$1)<=3) print $2'} > $TAG_DIR/$name/$name_exp/rec_dest
	#grep -v $name_exp $TAG_DIR/$name/$name_exp/dest_list | sort | uniq -c | awk -v c=$count_exp {'if((c-$1)>3) print $2'} > $TAG_DIR/$name/$name_exp/unrec_dest
	grep -v $name_exp $TAG_DIR/$name/$name_exp/dest_list | sort | uniq -c | awk -v c=$count_exp {'if($1>=5) print $2'} > $TAG_DIR/$name/$name_exp/rec_dest
	grep -v $name_exp $TAG_DIR/$name/$name_exp/dest_list | sort | uniq -c | awk -v c=$count_exp {'if($1<5) print $2'} > $TAG_DIR/$name/$name_exp/unrec_dest

	DEVICE=$name
done < $EXP_FILE


#find $TAG_DIR/$DEVICE -name "rec_dest" -exec cat {} \; > $TAG_DIR/$name/rec_dest
cat $TAG_DIR/$DEVICE/*/rec_dest >> $TAG_DIR/$DEVICE/rec_dest
#remove duplicates, empty lines, local network dests, ".local" destinations
grep -v '^$' $TAG_DIR/$DEVICE/rec_dest | grep -v "^$(cat $MONIOTR_DIR/traffic/by-name/$DEVICE/ip.txt | cut -d. -f1-3)" | grep -v '\.local' | sort -u > $TAG_DIR/$DEVICE/rec_dest_unique
chmod o+w $TAG_DIR/$DEVICE/rec_dest_unique
chmod o+w $TAG_DIR/$DEVICE/rec_dest


#find $TAG_DIR/$name -name "unrec_dest" -exec cat {} \; > $TAG_DIR/$name/unrec_dest
cat $TAG_DIR/$DEVICE/*/unrec_dest >> $TAG_DIR/$DEVICE/unrec_dest
#remove duplicates, empty lines, local network dests, ".local" destinations
grep -v '^$' $TAG_DIR/$DEVICE/unrec_dest | grep -v "^$(cat $MONIOTR_DIR/traffic/by-name/$DEVICE/ip.txt | cut -d. -f1-3)" | grep -v '\.local' | sort -u > $TAG_DIR/$DEVICE/unrec_dest_unique
chmod o+w $TAG_DIR/$DEVICE/unrec_dest_unique
chmod o+w $TAG_DIR/$DEVICE/unrec_dest

#create additional files useful later
cp $TAG_DIR/$DEVICE/rec_dest $TAG_DIR/$DEVICE/blocked_all
chmod o+w $TAG_DIR/$DEVICE/blocked_all

cp $TAG_DIR/$DEVICE/rec_dest $TAG_DIR/$DEVICE/non_essential
chmod o+w $TAG_DIR/$DEVICE/non_essential

cp $TAG_DIR/$DEVICE/rec_dest $TAG_DIR/$DEVICE/essential
chmod o+w $TAG_DIR/$DEVICE/essential


