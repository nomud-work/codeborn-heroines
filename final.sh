#!/bin/bash
# Final renders: stills supersampled 2x (3840x2160 -> 1920x1080 lanczos), turntable 720p.
cd "$(dirname "$0")"
set -e
log=final/render_log.txt; : > $log
r() { local res=$1 name=$2; shift 2; local t0=$(date +%s.%N)
  TMO=900 ./run.sh $res res://main.tscn "$@" --out=raw_$name 2>&1 | grep -E "STILL|BUILD|TRIS|ERROR" | tee -a $log
  ffmpeg -loglevel error -y -i out/raw_$name.png -vf scale=1920:1080:flags=lanczos final/$name.png
  echo "WALL $name $(echo "$(date +%s.%N) - $t0" | bc) s" | tee -a $log; }
for k in paladin mage ranger; do
  r 3840x2160 hero_$k --mode=hero --char=$k
  r 3840x2160 face_$k --mode=face --char=$k
  r 2560x1440 wireface_$k --mode=wireface --char=$k
done
r 2560x1440 wire_paladin --mode=wire --char=paladin
r 3840x2160 lineup --mode=lineup
