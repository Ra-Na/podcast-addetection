# podcast-addetection

This bash script extracts advertisement time stamps from audio files by

1. transcribing the audio files to text files using openai-whisper,
2. comparing the transcripts to each other to find common text blocks, which are usually ads, intros and outros
3. comparing the identified text blocks to the transcripts and fetching the corresponding time stamps.

## Requirements

1. Openai-whisper and ffmpeg.
2. Standard linux bash with sed, awk, diff and the like.

Skim through the comments in the bash script for more info.

## Usage

Store your mp3 files and the script in the same folder and execute the script in a bash inside the folder. 
