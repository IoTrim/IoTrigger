#THIS SCRIPT TAKES A SCREENSHOT AND SAVE IT IN THE PROPER CAPTURE FOLDER.
#Be sure to set the proper experiment file and to reach the desired state in the phone

#Run with sudo permissions and pass the experiment filename in first parameter
#EXAMPLE: sudo ./get_screenshot.sh switchbot-mini

# The first parameter $1 should be the experiment filename (placed in the $MONIOTR_DIR/experiemnts folder)
exp_name="$1"
if [ -z "$1" ]; then
    echo "Usage: $0 <EXPERIMENT_NAME>"
    exit 1
fi


#setup directory parameters
IOTRIM_DIR="" #write here the directory where all IoTrigger scripts are located

#default value for iotrim_dir is the current directory where script is located
if [ -z "$IOTRIM_DIR" ]; then
    IOTRIM_DIR="$(dirname $0)"
fi

CAPTURE_DIR="$IOTRIM_DIR/captures"
exp_file="$IOTRIM_DIR/experiments/$exp_name"



#function to wait for the phone
waitphone() {
    while [ -z "$PHONE_FOUND" ]; do
        echo "Phone not found, waiting for $PHONE/$ANDROID_SERIAL"
        sleep 5
        PHONE_FOUND=`adb devices | grep $ANDROID_SERIAL`
    done
}

#read the experiment file for parameters
IFS=";" read name plug_name onoff name_exp crop phone_exp package network sleep1 sleep2 function_1 function_2 function_3 function_4 function_5 function_6 function_7 function_8 function_9 function_10 function_11 function_12 function_13 function_14 < $exp_file
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


#capture screenshot
adb -s $ANDROID_SERIAL shell -n screencap -p /sdcard/screen_exp.png

#SAVE Screenshot to folder
mkdir -p "$CAPTURE_DIR/$name/reference/$phone_exp"
sudo chmod o+wx "$CAPTURE_DIR/$name/reference/$phone_exp"
sudo chmod o+wx "$CAPTURE_DIR/$name/reference"
adb -s $ANDROID_SERIAL pull /sdcard/screen_exp.png "$CAPTURE_DIR/$name/reference/$phone_exp/${name}.${name_exp}.png"
sudo chmod o+w $CAPTURE_DIR/$name/reference/$phone_exp/${name}.${name_exp}.png

#save the crop aswell
sudo convert $CAPTURE_DIR/$name/reference/$phone_exp/${name}.${name_exp}.png -crop $crop $CAPTURE_DIR/$name/reference/$phone_exp/${name}.${name_exp}_crop.png








