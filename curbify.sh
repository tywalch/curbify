#!/bin/bash

# Curbify takes an input video, timestamp, and an output filename to add a comedic curb your enthusiasm credits roll

# directory of the script
project_dir=$(dirname $(realpath $0 ))

# make a temp directory for storage of intermediate files
tmp_dir=$(mktemp -d -t curbify-$(date +%Y-%m-%d-%H-%M-%S))

# format to expect timestamp in
timestamp_test="\d{2}:\d{2}:\d{2}"

music="$project_dir/curb.mp3"
credits="$project_dir/curb.mp4"
short_video="$tmp_dir/short_video.mp4"
remastered_video="$tmp_dir/remastered_video.mp4"
combined_video="$tmp_dir/combined_video.mp4"
blank_audio="$tmp_dir/blank_audio.mp3"
full_audio="$tmp_dir/full_audio.mp3"
video_audio="$tmp_dir/video_audio.mp3"
merged_audio="$tmp_dir/merged_audio.mp3"
trimmed_audio="$tmp_dir/trimmed_audio.mp3"
video_file="$tmp_dir/videos.txt"

# Add seconds to a timestamp
function add_seconds() {
  # https://stackoverflow.com/questions/14309032/bash-script-difference-in-minutes-between-two-times
  start_time="00:00:00" 
  end_time=$1 
  seconds_to_add=$2

  # feeding variables by using read and splitting with IFS
  IFS=: read ah am as <<< "$start_time"
  IFS=: read bh bm bs <<< "$end_time"

  # Convert hours to minutes.
  # The 10# is there to avoid errors with leading zeros
  # by telling bash that we use base 10
  secondsA=$((10#$ah*60*60 + 10#$am*60 + 10#$as))
  secondsB=$((10#$bh*60*60 + 10#$bm*60 + 10#$bs))
  diff_seconds=$((secondsB - secondsA))
  SUM=`expr $diff_seconds + $seconds_to_add`
  SEC=$(($SUM%60))
  MIN=$((($SUM-$SEC)%3600/60))
  HRS=$((($SUM-$MIN*60)/3600))
  
  # Handle single digit values  
  if [[ "$SEC" == "0" ]]; then
    SEC="00"
  fi
  if [[ "$MIN" == "0" ]]; then
    MIN="00"
  fi
  if [[ "$HRS" == "0" ]]; then
    HRS="00"
  fi

  time_diff="$HRS:$MIN:$SEC";
  echo $time_diff;
}

# shorten video to specific timestamp
function shorten {  
  location=$1
  video=$2
  output=$3
  ffmpeg -y -ss 00:00:00 -i "$video" -t $location -c copy "$output"
}

# remove audio from a video
function mute {
  video=$1
  output=$2
  ffmpeg -y -i $video -c copy -an $output
}

# remaster a video (to match the credits)
function remaster {
  video=$1
  output=$2
  ffmpeg -y -i $video -s hd720 -r 30000/1001 -video_track_timescale 30k -c:a copy $output
}

# combine two videos 
function combine {
  video1=$1
  video2=$2
  output=$3
  echo "file $video1" > $video_file
  echo "file $video2" >> $video_file
  ffmpeg -y -f concat -safe 0 -i $video_file -c copy $output
}

# get the length of a video in seconds
function video_seconds {
  video=$1
  ffprobe -v error -select_streams v:0 -show_entries stream=duration -of default=noprint_wrappers=1:nokey=1 $video | awk '{print int($0)}'
}

# get the length of a video as a timestamp 
function video_duration {
  video=$1
  ffmpeg -i $video 2>&1 | grep "Duration"| cut -d ' ' -f 4 | sed s/,// | sed -E 's/(:[0-9]+)\.[0-9]+/\1/g'
}

function layer {
  # https://stackoverflow.com/questions/32949824/ffmpeg-mix-audio-at-specific-time
  video=$1
  audio=$2 
  music_start=$3 # in seconds
  output=$4

  # length of the video
  blank_length=$(video_seconds $video)
  
  # create blank audio the length of the video
  ffmpeg -y -f lavfi -i anullsrc=r=44100:cl=mono -t $blank_length -q:a 9 -acodec libmp3lame $blank_audio
  
  # add audio to blank at start after n seconds
  ffmpeg -y -i $blank_audio -i $audio -filter_complex "aevalsrc=0:d=$music_start[s1];[s1][1:a]concat=n=2:v=0:a=1[aout]" -c:v copy -map [aout] $full_audio
  
  # extract audio from video
  ffmpeg -y -i $video -q:a 0 -map a $video_audio

  # mix the two audios over top each other
  ffmpeg -y -i $full_audio -i $video_audio -filter_complex "amix=inputs=2:duration=longest:dropout_transition=0, volume=2" $merged_audio
  
  # trim the length of the audio to match the video's length
  ffmpeg -y -i $merged_audio -ss 00:00:00 -to $(video_duration $video) -c copy $trimmed_audio

  # apply the audio to the video
  ffmpeg -y -i $video -i $trimmed_audio -map 0:v -map 1:a -c:v copy -shortest $output
}

function curbify {
  video=$1
  location=$2
  
  # How long should the audio start before the credits roll
  lead_in="8"
  
  # shorten the video to the desired timestamp with room at the end for the theme 
  shorten $(add_seconds $location $lead_in) $video $short_video

  # remaster the video to match the same quality as the credits video
  remaster $short_video $remastered_video

  # combine the shortened video with the credits 
  combine $remastered_video $credits $combined_video
  
  # length the whole video after being combined
  combined_length=$(video_seconds $combined_video)

  # total length of the credits plus the lead_in seconds
  start_intro=`expr $(video_seconds $credits) + $lead_in`

  # when to queue the music based on the length of the video minus the lead_in + credits
  music_cue=`expr $combined_length - $start_intro`

  # layer the music onto the video at the location of the music queue
  layer $combined_video $music $music_cue $3

  # remove the temp directory
  rm -r $tmp_dir
}

if [[ $1 == "" || $2 == "" || $3 == "" ]]; then 
  echo "Please include the arguments <video_name> <timestamp> <ouputname>"
  exit 1
fi

video=$(realpath $1)
location=$2
output=$3

if ! [[ -f "$video" ]]; then
    echo "File $1 does not exist"
    exit 1
fi

if ! [[ "$location" =~ ^[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
  echo "Timestamp $location is not in the correct format HH:MM:SS"
  exit 1
fi

curbify $video $location $output