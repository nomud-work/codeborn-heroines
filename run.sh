#!/bin/bash
# usage: run.sh WxH scene [user args...]
G=${GODOT:-godot}   # path to a Godot 4.7.2 binary
cd "$(dirname "$0")"
RES=$1; SCENE=$2; shift 2
timeout ${TMO:-600} xvfb-run -a -s "-screen 0 ${RES}x24" $G --path . --audio-driver Dummy --rendering-driver opengl3 --resolution $RES $EXTRA $SCENE -- "$@" 2>&1 | grep -vE "^\s*$|V-Sync|set_use_vsync|OpenGL API|ALSA|ObjectDB|cleanup \(core"
