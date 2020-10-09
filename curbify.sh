#!/bin/bash
tmp_dir=$(mktemp -d -t curbify-$(date +%Y-%m-%d-%H-%M-%S))
# tmp_dir="./temp"

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
  DIFF_SEC=$((secondsB - secondsA))
  EXTRA=`expr $DIFF_SEC + $seconds_to_add`
  SEC=$(($EXTRA%60))
  MIN=$((($EXTRA-$SEC)%3600/60))
  HRS=$((($EXTRA-$MIN*60)/3600))
  if [[ "$SEC" == "0" ]]; then
    SEC="00"
  fi
  if [[ "$MIN" == "0" ]]; then
    MIN="00"
  fi
  if [[ "$HRS" == "0" ]]; then
    HRS="00"
  fi
  TIME_DIFF="$HRS:$MIN:$SEC";
  echo $TIME_DIFF;
}

# ffmpeg -ss 00:00:00 -i curb.mp4 -t 00:00:09 -c copy shortcurb.mp4
function shorten {  
  location=$1
  video=$2
  output=$3
  ffmpeg -y -ss 00:00:00 -i "$video" -t $location -c copy "$output"
}

# ffmpeg -i shortcurb.mp4 -c copy -an silentcurb.mp4
function mute {
  video=$1
  output=$2
  ffmpeg -y -i $video -c copy -an $output
}

function remaster {
  video=$1
  output=$2
  ffmpeg -y -i $video -s hd720 -r 30000/1001 -video_track_timescale 30k -c:a copy $output
}

function combine {
  video1=$1
  video2=$2
  output=$3
  echo "file $video1" > videos.txt
  echo "file $video2" >> videos.txt
  ffmpeg -y -f concat -safe 0 -i videos.txt -c copy $output
}

function video_seconds {
  video=$1
  ffprobe -v error -select_streams v:0 -show_entries stream=duration -of default=noprint_wrappers=1:nokey=1 $video | awk '{print int($0)}'
}

function video_duration {
  video=$1
  ffmpeg -i $video 2>&1 | grep "Duration"| cut -d ' ' -f 4 | sed s/,// | sed -E 's/(:[0-9]+)\.[0-9]+/\1/g'
}

function layer {
  # https://stackoverflow.com/questions/32949824/ffmpeg-mix-audio-at-specific-time
  video=$1
  audio=$2
  music_start=$3
  output=$4
  blank_length=$(video_seconds $video)
  blank_audio="$tmp_dir/blank_audio.mp3"
  full_audio="$tmp_dir/full_audio.mp3"
  video_audio="$tmp_dir/video_audio.mp3"
  merged_audio="$tmp_dir/merged_audio.mp3"
  trimmed_audio="$tmp_dir/trimmed_audio.mp3"
  ffmpeg -y -f lavfi -i anullsrc=r=44100:cl=mono -t $blank_length -q:a 9 -acodec libmp3lame $blank_audio
  ffmpeg -y -i $blank_audio -i $audio -filter_complex "aevalsrc=0:d=$music_start[s1];[s1][1:a]concat=n=2:v=0:a=1[aout]" -c:v copy -map [aout] $full_audio
  ffmpeg -y -i $video -q:a 0 -map a $video_audio
  ffmpeg -y -i $full_audio -i $video_audio -filter_complex "amix=inputs=2:duration=longest:dropout_transition=0, volume=2" $merged_audio
  ffmpeg -y -i $merged_audio -ss 00:00:00 -to $(video_duration $video) -c copy $trimmed_audio
  ffmpeg -y -i $video -i $trimmed_audio -map 0:v -map 1:a -c:v copy -shortest $output
}

function curbify {
  video=$1
  location=$2
  lead_in="8"
  credits="curb.mp4"
  shorten $(add_seconds $location $lead_in) $video "$tmp_dir/short_video.mp4"
  remaster "$tmp_dir/short_video.mp4" "$tmp_dir/remastered_video.mp4"
  combine "$tmp_dir/remastered_video.mp4" $credits "$tmp_dir/combined_video.mp4"
  start_intro=`expr $(video_seconds $credits) + $lead_in`
  combined_length=$(video_seconds "$tmp_dir/combined_video.mp4")
  music_cue=`expr $combined_length - $start_intro`
  layer "$tmp_dir/combined_video.mp4" "curb.mp3" $music_cue $3
  rm -r $tmp_dir
}

timestamp_test="\d{2}:\d{2}:\d{2}"
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

if [[ $output = "" ]]; then
  echo "Output filename must be provided"
  exit 1
fi

curbify $video $location $output