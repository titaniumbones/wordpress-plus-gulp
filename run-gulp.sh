#!/bin/bash
mkdir -p /wordpress/wp-content/themes/understrap
# if [[ !  "$(ls -A /wordpress/wp-content/themes/understrap)" ]]; then
  git clone https://github.com/titaniumbones/understrap.git \
      -b dockerize /wordpress/wp-content/themes/understrap
# fi
cd /wordpress/wp-content/themes/understrap
npm install gulp
npm install -d
while true; do
 gulp watch-bs
done
