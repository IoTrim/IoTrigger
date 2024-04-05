#First parameter is the audio file to reproduce
audio=$1
cat $audio | ffplay -v 0 -nodisp -autoexit -
