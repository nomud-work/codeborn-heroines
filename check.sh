#!/bin/bash
G=${GODOT:-godot}   # path to a Godot 4.7.2 binary
cd "$(dirname "$0")"
timeout 60 $G --headless --path . --import >/dev/null 2>&1
for f in *.gd; do [ "$f" = bench.gd ] && continue; timeout 30 $G --headless --path . --check-only -s $f 2>&1 | grep -E "SCRIPT ERROR|Parse Error" -A1 | grep -v "Failed to compile depended" | head -4; done | sort -u
