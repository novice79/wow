#!/usr/bin/env bash

for i in "en" "zh"; do
cd /data/wow3.3.5a_$i
targetDir="/data/wow-extracted-data/tc-wow3.3.5a_$i"
mkdir -p "$targetDir"
# Cameras, DBC and Maps files
/tc-server/bin/mapextractor
# Visual Maps (aka vmaps)
/tc-server/bin/vmap4extractor
mkdir vmaps
/tc-server/bin/vmap4assembler Buildings vmaps
# Movement Maps (aka mmaps - optional RECOMMENDED)
mkdir mmaps
/tc-server/bin/mmaps_generator
mv cameras dbc maps "$targetDir"
mv vmaps "$targetDir"
mv mmaps "$targetDir"
rm -rf Buildings
cd "$targetDir" \
&& tar Jcvf tc-wow3.3.5a_${i}.tar.xz * && mv *.xz ..

done
