#!/bin/bash

# control variables (now = number of words)
now1="8" # Comparing two transcripts, number of consecutive words to mark as ad.
now2="4" # Comparing ad snippets to transcripts, number of words to mark as ad.

# Clean up
rm out* 2> /dev/null
rm *nl 2> /dev/null
rm advertisement 2> /dev/null
rm *timestamps* 2> /dev/null
rm tmp* 2> /dev/null
rm linenumbers 2> /dev/null

###  Transcribe all mp3 files to text/subtitle files.
###  This requires openai-whisper. It can be installed with "python3 -m pip install -U openai-whisper",
###  which may download around 3 GB. If the trancription fails with a SHA256-error you may have faulty RAM. 
###  Comment out after first run. when experimenting with
for f in *.mp3;do whisper $f --model small;done

###  Now we operate on the transcripts. 
###  Sting matching is computationally expensive. We leverage the power of the diff-tool, 
###  which is quite fast. Since diff is line-based, we need to break all words into 
###  individual lines, the addendum "nl" means "newline".

echo "Comparing the transcripts to find common blocks which are collected in the file \"advertisement\"."
for f in *.txt;do
    cat $f | tr " " "\n" > "${f}nl"
done

# Get list of files and its length
filelist=(*.txtnl)
total=${#filelist[@]}

###  We compare now all transcripts agains each other with diff to find common parts. 
###  These are likely to be ads, intros and outros. We ask diff for "unchanged groups",
###  which is equivalent to a common string. 

# one-way-diff
#for (( var1=1; var1<=$total; var1++ )); do
#    for (( var2=$var1+1; var2<=$total; var2++ )); do
#        cmd=$'diff --unchanged-group-format=\'@@ %dn,%df\n%<\' --old-group-format=\'\' --new-group-format=\'\' --changed-group-format=\'\''
#        cmd+=" ${filelist[var1-1]} ${filelist[var2-1]} > out_${var1}_${var2}"
#	eval "$cmd"
#    done
#done

# two-way-diff
for (( var1=1; var1<=$total; var1++ )); do
    for (( var2=1; var2<=$total; var2++ )); do
        if [ $var1 != $var2 ]; then
            cmd=$'diff --unchanged-group-format=\'@@ %dn,%df\n%<\' --old-group-format=\'\' --new-group-format=\'\' --changed-group-format=\'\''
            cmd+=" ${filelist[var1-1]} ${filelist[var2-1]} > out_${var1}_${var2}"
	        eval "$cmd"
        fi
    done
done

###  We now go through the diff output using awk. When a large number of lines (words) 
###  has been found as "unchanged group", it is a text block common in the two transcripts. 
###  Adjust count > now1 (control variable at the beginning) carefully. "now1" (number of words) 
###  is the number of common consecutive words in two transcripts. Too small gives many false 
###  positives, to large misses the ads. We collect the common blocks in the file "advertisement".
filelist="out*"
for file in $filelist;do
    cmd="awk '!/@@/{count++;block=block \"\n\" \$0}/@@/{if(count>"
    cmd+=$now1
    cmd+="){print block;};count = 0;block=\"\"}' $file >> advertisement"
    eval "$cmd"
done

###  We now compare the text blocks in "advertisement" against all transcripts and extract the 
###  timestamps from the srt files where ads where found. Again, we use diff for efficiency, 
###  which requires breaking words to individual lines. 
###  Instead, you may well use longest common substring algorithms in bash or python, 
###  but diff is blazingly fast in comparison.
echo "Searching for ads:"
for f in *.srt;do
    echo "${f%.*}" #  Print name of file to examin.
    sed 's/ --> /-->/' $f | tr " " "\n" > "${f}nl"  # Prepare srt file by removing spaces in timestamps and then breaking at spaces.
    # Assemble diff command and write "unchanged groups" to file "tmp"
    cmd=$'diff --unchanged-group-format=\'@@ %dn,%df\n%<\' --old-group-format=\'\' --new-group-format=\'\' --changed-group-format=\'\''
    cmd+=" ${f}nl"
    cmd+=' advertisement > tmp'
    eval "$cmd"   
    # Next we extract the [@@ a,b] - headers of big "unchanged groups". Again, count needs to be adjusted carefully. 
    # Its the critical number of consecutive words common in the "advertisement" file and the current transcript,
    # stored in the control variable "now2" at the beginning.
    cmd="awk '!/@@/{count++;}/@@/{if(count>"
    cmd+=$now2
    cmd+=$'){print block;};count = 0;block=$0}\' tmp > tmp2'
    eval "$cmd"
    # In the diff header [@@ a,b], b is a line number in transcript.srtnl file, above which an ad timestamp is found.
    # We firstly fetch these numbers from the list of headers in "tmp2" with awk and store them in "linenumbers".
    awk -F ',' '{print $2}' tmp2 > linenumbers
    # Next, we get the time stamps above these lines in transcript.srtnl by appending them to tmp3.
    rm tmp3 2> /dev/null
    while read -r linenumber
    do
        cmd=$'awk \'{if(index($0, ":") > 0){lasttimestamp=$0};if(NR=='
	    cmd+=$linenumber
	    cmd+=$'){print lasttimestamp;exit}}\''
	    cmd+=" ${f}nl"
	    eval "$cmd" >> tmp3
        done < linenumbers
    sort tmp3 | uniq > timestamps_su     # Sort the found timestamps and delete duplicates (su = sorted, unique). 
    sed -i 's/-->/ --> /' timestamps_su  # Restore the spaces in the timestamps. 
    sed -i "s/,/./g" timestamps_su       # Replace , by . to treat seconds as a number in the next step.
    # We round the times to seconds (sur = sorted, unique, rounded)
    cmd="awk -F'[: ]' '{ printf \"%s:%s:%02.0f %s %s:%s:%02.0f \n\",\$1,\$2,\$3,\$4,\$5,\$6,\$7}' timestamps_su > timestamps_sur"  # auf sekunden runden
    eval $cmd
    # Append a dummy line for the next awk algorithm.
    echo "dummy dummy dummy" >> timestamps_sur 
    # We now join consecutive time intervals.
    awk '{if(prev3==$1){prev2=$2;prev3=$3} else {printf "%s %s %s\n",prev1,prev2,prev3;prev1=$1;prev2=$2;prev3=$3};}' timestamps_sur > tmp4
    # Remove first empty line and print to transcript_ad_timestamps.txt
    tail -n +2 "tmp4" > "${f%.*}_ad_timestamps.txt"
done

### We can now continue to process the timestamps, e.g. by joining big blocks which are close to each other and then eliminating small, isolated findings. 
