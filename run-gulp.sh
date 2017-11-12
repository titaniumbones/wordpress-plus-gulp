#!/bin/bash
# need to update to use dev names
DEV_THEME_BRANCH=${DEV_THEME_BRANCH:-master}

_log_last_exit_colorize() {
  if [ $? -eq 0 ]; then
    echo "$1" |& _colorize
  else
    echo "$2" |& _colorize
    exit 1
  fi
}


# do something similar for dev plugin I guess
get_dev_theme() {
  echo "vars $DEV_THEME_REPONAME $DEV_THEME_USERNAME"
  if [[ $DEV_THEME_USERNAME && $DEV_THEME_REPONAME ]]; then
    if [ -z "$(ls -A /wordpress/wp-content/themes/$DEV_THEME_REPONAME/)" ]; then
      mkdir -p  /wordpress/wp-content/themes/
      cd /wordpress/wp-content/themes/
      git clone --branch $DEV_THEME_BRANCH  "https://github.com/$DEV_THEME_USERNAME/${DEV_THEME_REPONAME}.git" \
          /wordpress/wp-content/themes/$DEV_THEME_REPONAME
      _log_last_exit_colorize "Success: $DEV_THEME_URL repo has been cloned."\
                              "Error: unable to clone $DEV_THEME_URL"
    else
      echo "dev-theme folder not empty, not cloning"
    fi
  elif [[ $DEV_THEME_REPONAME || $DEV_THEME_USERNAME ]]; then
    echo "Please provide both the DEV_THEME_USERNAME and the DEV_THEME_REPONAME variables in order to download the dev theme"
  else
    echo "No Dev Theme URL provided"
  fi
  chmod -R a+rw /wordpress/wp-content/themes/$DEV_THEME_REPONAME
  _wp theme activate $DEV_THEME_REPONAME || _log_last_exit_colorize \
                                              "Success: activated $DEV_THEME_URL theme." \
                                              "Error: unable to activate $DEV_THEME_URL"
}

# mkdir -p /wordpress/wp-content/themes/understrap
# # if [[ !  "$(ls -A /wordpress/wp-content/themes/understrap)" ]]; then
#   git clone https://github.com/titaniumbones/understrap.git \
#       -b dockerize /wordpress/wp-content/themes/understrap
# # fi


echo "getting dev theme"
get_dev_theme

echo "installing node modules"
cd /wordpress/wp-content/themes/understrap
npm install gulp
npm install -d

while true; do
 echo "wathcing for changes"
 gulp watch-bs
done
