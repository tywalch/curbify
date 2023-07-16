# Curbify
A command line utility to add a Curb Your Enthusiasm credits roll to a file.

## Requirements
`ffmpeg` - https://ffmpeg.org/

## Usage

```
curbify.sh <input_file> <timestamp> <output_file>
```

| Argument     | Description                                   | Example        |
| ------------ | --------------------------------------------- | :-----------:  |
| `input_file` | File to curbify                               | `./video.mp4`  |
| `timestamp`  | Time in HH:MM:SS format to begin credits song | `00:01:09`     |
| `output_file`| File to curbify                               | `./output.mp4` |