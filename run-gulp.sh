#!/bin/bash
if [[ !  "$(ls -A /themes/understrap)" ]]; then
  git clone https://github.com/titaniumbones/understrap.git -b dockerize /themes/understrap
fi
cd /themes/understrap
npm install gulp
npm install -d
while true; do
 gulp watch-bs
done
