# Curbify
A command line utility to add a Curb Your Enthusiasm credits roll to a file.

## Requirements
`ffmpeg` - https://ffmpeg.org/

## Usage
```
curbify.sh <video_file> <timestamp> <output_file>
```

|Argument|Description|Example|
|----|----|:--:|
|`video_file` |File to curbify|`video.mp4`|
|`timestamp`  |time in HH:MM:SS format to begin credits song |`00:01:09`|
|`output_file`|File to curbify|`output.mp4`|