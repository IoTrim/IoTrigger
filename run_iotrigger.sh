DATE=`date "+%Y%m%d_%H%M%S"`


./get_dest.sh $capt_dir $phone $file_dev $dir_data

./classify_dest.sh $capt_dir $phone $file_dev $dir_data

./blocker.sh $capt_dir $phone $file_dev $dir_data




./blocker_manual.sh $exp_filename
./blocker_all.sh $exp_filename [$list_filename]
./get_screenshot.sh $exp_filename