#!/bin/bash
# need to update to use dev names
DEV_THEME_BRANCH=${DEV_THEME_BRANCH:-master}
DEV_THEME_USERNAME=${DEV_THEME_USERNAME:-titaniumbones}
DEV_THEME_REPONAME=${DEV_THEME_REPONAME:-understrap}
BASEDIR=/wordpress/wp-content/themes

# Helpers
# ---------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
PURPLE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\E[1m'
NC='\033[0m'

h1() {
  local len=$(($(tput cols)-1))
  local input=$*
  local size=$(((len - ${#input})/2))

  for ((i = 0; i < len; i++)); do echo -ne "${PURPLE}${BOLD}="; done; echo ""
  for ((i = 0; i < size; i++)); do echo -n " "; done; echo -e "${NC}${BOLD}$input"
  for ((i = 0; i < len; i++)); do echo -ne "${PURPLE}${BOLD}="; done; echo -e "${NC}"
}

h2() {
  echo -e "${ORANGE}${BOLD}==>${NC}${BOLD} $*${NC}"
}


_colorize() {
  local IN
  local success="${GREEN}${BOLD}Success:${NC}"
  local failed="${RED}${BOLD}Error:${NC}"
  local warning="${CYAN}${BOLD}Warning:${NC}"
  while read -r IN; do
   IN="${IN/Success\:/$success}"
   IN="${IN/Error\:/$failed}"
   IN="${IN/Warning\:/$warning}"
   echo -e "$IN"
  done
}

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
    if [ -z "$(ls -A $BASEDIR/$DEV_THEME_REPONAME/)" ]; then
      mkdir -p  $BASEDIR/
      cd $BASEDIR/
      git clone --branch $DEV_THEME_BRANCH  "https://github.com/$DEV_THEME_USERNAME/${DEV_THEME_REPONAME}.git" \
          $BASEDIR/$DEV_THEME_REPONAME
      _log_last_exit_colorize "Success: $DEV_THEME_REPONAME repo has been cloned."\
                              "Error: unable to clone $DEV_THEME_REPONAME"
    else
      echo "dev-theme folder not empty, not cloning"
    fi
  elif [[ $DEV_THEME_REPONAME || $DEV_THEME_USERNAME ]]; then
    echo "Please provide both the DEV_THEME_USERNAME and the DEV_THEME_REPONAME variables in order to download the dev theme"
  else
    echo "No Dev Theme URL provided"
  fi
  chmod -R a+rw $BASEDIR/$DEV_THEME_REPONAME

}

echo "getting dev theme"
get_dev_theme

echo "installing node modules"
cd $BASEDIR/$DEV_THEME_REPONAME
npm install gulp
npm install -d

while true; do
 echo "wathcing for changes"
 gulp watch-bs
done
