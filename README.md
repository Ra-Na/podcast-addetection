# podcast-addetection

This bash script extracts advertisement time stamps from audio files by

1. transcribing the audio files to text files using openai-whisper,
2. comparing the transcripts to each other to find common text blocks, which are usually ads, intos and outros
3. comparing the identified text block to the transcripts and fetching the corresponding time stamps.

## Requirements

1. openai-whisper and ffmpeg
2. standard linux bash with sed, awk, diff and the like
