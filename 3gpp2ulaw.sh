#!/bin/sh

set -e -x

cutlast() {
  ffmpeg -y -i "$2" -ss 0 -to $(echo $(ffprobe -i "$2" -show_entries format=duration -v quiet -of csv="p=0") - "$1" | bc) -c copy "$3"
}

process() {(
  f="$1"
  n="$2"
  wav="$(dirname "$f")/$(basename "$f" .3gpp).wav"
  wav2="$(dirname "$f")/$(basename "$f" .3gpp)_short.wav"
  ulaw="$(dirname "$f")/Phrase_${n}.ulaw"

  ffmpeg -y -i "$f" -codec:a pcm_mulaw "$wav"
  cutlast 0.4 "$wav" "$wav2"
  sox -V "$wav2" -r 8000 -c 1 -t ul "$ulaw"
)}

test -d "${1}"
i=1
for f in ${1}/*3gpp ; do
  echo "Processing $f"
  process "$f" "$i"
  i=$(expr $i + 1)
done
