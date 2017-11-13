#!/bin/bash
# shellcheck disable=SC1091

# Environment
# ------------
#!/bin/bash
ADMIN_EMAIL=${ADMIN_EMAIL:-"admin@${DB_NAME:-wordpress}.com"}
DB_HOST=${DB_HOST:-db}
DB_NAME=${DB_NAME:-wordpress}
DB_PASS=${DB_PASS:-root}
DB_PREFIX=${DB_PREFIX:-wp_}
PERMALINKS=${PERMALINKS:-'/%year%/%monthnum%/%postname%/'}
SERVER_NAME=${SERVER_NAME:-localhost}
WP_VERSION=${WP_VERSION:-latest}
# FIXME: Remove in next version
URL_REPLACE=${URL_REPLACE:-"$SEARCH_REPLACE"}
BEFORE_URL="${URL_REPLACE%,*}"
AFTER_URL="${URL_REPLACE#*,}"
# dev theme option
# I don't know how to do the replacement in bash so skipping
# DEV_THEME_NAME=${DEV_THEME_NAME:"${DEV_THEME_URL:"}
DEV_THEME_BRANCH=${DEV_THEME_BRANCH:-master}

declare -A plugin_deps
declare -A theme_deps
declare -A plugin_volumes
declare -A theme_volumes

# Apache configuration
# --------------------
sed -i "s/#ServerName www.example.com/ServerName $SERVER_NAME\nServerAlias www.$SERVER_NAME/" /etc/apache2/sites-available/000-default.conf
# sed -i "s/\/app\//\/wordpress\//" /etc/apache2/sites-available/000-default.conf

# WP-CLI configuration
# ---------------------
cat > ~/.wp-cli/config.yml <<EOF
apache_modules:
  - mod_rewrite

core config:
  dbuser: root
  dbpass: $DB_PASS
  dbname: $DB_NAME
  dbprefix: $DB_PREFIX
  dbhost: $DB_HOST:3306
  extra-php: |
    define('WP_DEBUG', ${WP_DEBUG:-false});
    define('WP_DEBUG_LOG', ${WP_DEBUG_LOG:-false});
    define('WP_DEBUG_DISPLAY', ${WP_DEBUG_DISPLAY:-true});

core install:
  url: ${AFTER_URL:-localhost:8080}
  title: $DB_NAME
  admin_user: root
  admin_password: $DB_PASS
  admin_email: $ADMIN_EMAIL
  skip-email: true
EOF

# WP-CLI bash completions
# ------------------
echo "
. /etc/bash_completion.d/wp-cli
" >> /root/.bashrc
. /etc/bash_completion.d/wp-cli

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

_get_volumes() {
  local volume_type="$1"
  local filenames dirnames
  local names=()

  filenames=$(
    find /wordpress/wp-content/"$volume_type"/* -maxdepth 0 -type f ! -name 'index*' -print0 2>/dev/null |
    xargs -0 -I {} basename {} .php
  )
  dirnames=$(
    find /wordpress/wp-content/"$volume_type"/* -maxdepth 0 -type d -print0 2>/dev/null |
    xargs -0 basename -a 2>/dev/null
  )
  names=( $filenames $dirnames )

  echo "${names[@]}"
}

_wp() {
  wp --allow-root "$@"
}

# FIXME: Remove in next version
# Deprecations
# ---------------------
_local_deprecation() {
  local local_type="$1" # 'plugin' or 'theme'
  echo "Warning: [local]$local_type-name has been deprecated and will be dropped in the next version." |& _colorize
}

_search_replace_deprecation() {
  echo "Warning: SEARCH_REPLACE environment variable has been renamed to URL_REPLACE and will be dropped in the next version." |& _colorize
}

# Config Functions
# ---------------------

init() {
  local plugins themes i

  # FIXME: Remove in next version
  [[ -n $SEARCH_REPLACE ]] && _search_replace_deprecation

  PLUGINS="${PLUGINS/%,},"
  THEMES="${THEMES/%,},"

  if [[ -f /root/.dockercache ]]; then
    . /root/.dockercache
  else
    plugins=$( _get_volumes plugins )
    themes=$( _get_volumes themes )
    echo "plugins='$plugins'" >> ~/.dockercache
    echo "themes='$themes'" >> ~/.dockercache
  fi

  for i in $plugins; do
    plugin_volumes[$i]="$i"
  done

  for i in $themes; do
    theme_volumes[$i]="$i"
  done

  local key value IFS=$'\n'
  while read -r -d, i; do
    [[ ! "$i" ]] && continue
    i="${i# }"          # Trim leading whitespace
    key="${i%]*}"       # Trim right bracket to end of string
    key="${key//[\[ ]}" # Trim left bracket
    value="${i##\[*\]}" # Trim bracketed text inclusive
    # FIXME: Remove in next version
    [[ "$key" == 'local' ]] && _local_deprecation plugin && continue
    plugin_deps[$key]="$value"
  done <<< "$PLUGINS"

  while read -r -d, i; do
    [[ ! "$i" ]] && continue
    i="${i# }"          # Trim leading whitespace
    key="${i%]*}"       # Trim right bracket to end of string
    key="${key//[\[ ]}" # Trim left bracket
    value="${i##\[*\]}" # Trim bracketed text inclusive
    # FIXME: Remove in next version
    [[ "$key" == 'local' ]] && _local_deprecation theme && continue
    theme_deps[$key]="$value"
  done <<< "$THEMES"

  # Download WordPress
  # ------------------
  if [[ ! -f /wordpress/wp-settings.php ]]; then
    h2 "Downloading WordPress"
    _wp core download --version="$WP_VERSION"
    _log_last_exit_colorize "Success: Wordpress downloaded" "Error: Wordpress download failed!"
  fi

  chown -R www-data /wordpress/wp-content
}

check_database() {
  local data_path

  # Already installed
  wp core is-installed --allow-root 2>/dev/null && return

  _wp db create
  _log_last_exit_colorize "Success: db create" "Error: db create failed!"

  # No backups found
  if [[ "$( find /data -name "*.sql" 2>/dev/null | wc -l )" -eq 0 ]]; then
    _wp core install
    _log_last_exit_colorize "Success: core install" "Error: core install failed!"

    return
  fi

  data_path=$( find /data -name "*.sql" -print -quit )
  _wp db import "$data_path"
  _log_last_exit_colorize "Success: db import" "Error: db import failed!"

  if [[ -n "$URL_REPLACE" ]]; then
    wp search-replace --skip-columns=guid "$BEFORE_URL" "$AFTER_URL" --allow-root \
    | grep 'replacement' \
    |& _colorize
  fi
}

check_plugins() {
  local key
  local plugin
  local to_install=()
  local to_remove=()

  if [[ "${#plugin_deps[@]}" -gt 0 ]]; then
    for key in "${!plugin_deps[@]}"; do
      if ! wp plugin is-installed --allow-root "$key"; then
        to_install+=( "${plugin_deps[$key]}" )
      fi
    done
  fi

  for plugin in $(wp plugin list --field=name --allow-root); do
    [[ ${plugin_deps[$plugin]} ]] && continue
    [[ ${plugin_volumes[$plugin]} ]] && continue
    to_remove+=( "$plugin" )
  done

  for key in "${to_install[@]}"; do
    wp plugin install --allow-root "$key"
    _log_last_exit_colorize "Success: $key plugin installed" "Error: $key plugin install failure!"
  done

  [[ "${#to_remove}" -gt 0 ]] && _wp plugin delete "${to_remove[@]}"
  _wp plugin activate --all
  _log_last_exit_colorize "Success: plugin activate all" "Error: plugin activate all failed!"
 }

check_themes() {
  local key
  local theme
  local to_install=()
  local to_remove=()

  if [[ "${#theme_deps[@]}" -gt 0 ]]; then
    for key in "${!theme_deps[@]}"; do
      if ! wp theme is-installed --allow-root "$key"; then
        to_install+=( "${theme_deps[$key]}" )
      fi
    done
  fi

  for key in "${to_install[@]}"; do
    wp theme install --allow-root "$key"
    _log_last_exit_colorize "Success: $key theme install " "Error: $key theme install failed!"
  done

  for theme in $(wp theme list --field=name --status=inactive --allow-root); do
    [[ ${theme_deps[$theme]} ]] && continue
    [[ ${theme_volumes[$theme]} ]] && continue
    to_remove+=( "$theme" )
  done

  for key in "${to_remove[@]}"; do
    wp theme delete --allow-root "$key"
    _log_last_exit_colorize "Success: $key theme deleted" "Error: $key theme delete failed!"
  done

}

# do something similar for dev plugin I guess
get_dev_theme() {
  echo "vars $DEV_THEME_REPONAME $DEV_THEME_USERNAME"
  # if [[ $DEV_THEME_USERNAME && $DEV_THEME_REPONAME ]]; then
  #   if [ -z "$(ls -A /wordpress/wp-content/themes/$DEV_THEME_REPONAME/)" ]; then
  #     cd /wordpress/wp-content/themes/
  #     git clone --branch $DEV_THEME_BRANCH  "https://github.com/$DEV_THEME_USERNAME/${DEV_THEME_REPONAME}.git" \
  #         /wordpress/wp-content/themes/$DEV_THEME_REPONAME
  #     _log_last_exit_colorize "Success: $DEV_THEME_URL repo has been cloned."\
  #                             "Error: unable to clone $DEV_THEME_URL"
  #   else
  #     echo "dev-theme folder not empty, not cloning"
  #   fi
  # elif [[ $DEV_THEME_REPONAME || $DEV_THEME_USERNAME ]]; then
  #   echo "Please provide both the DEV_THEME_USERNAME and the DEV_THEME_REPONAME variables in order to download the dev theme"
  # else
  #   echo "No Dev Theme URL provided"
  # fi
  # chmod -R a+rw /wordpress/wp-content/themes/$DEV_THEME_REPONAME
  _wp theme activate $DEV_THEME_REPONAME || _log_last_exit_colorize \
                                              "Success: activated $DEV_THEME_URL theme." \
                                              "Error: unable to activate $DEV_THEME_URL"
  }
function add_local_scripts() {
  echo "made it into add_local_scripts"
  # for f in "/wordpress/wp-content/themes/local-scripts"/*; do
  #  echo "trying to run $f"
  #  if [[ -f $f ]]; then
  #     exec /wordpress/wp-content/themes/local-scripts/$f &
  #     _log_last_exit_colorize "Success: /local-scripts/$f ran without errors." \
  #                             "Failure: unable to run /local-scripts/$f ."
  #  fi
  # done
  echo "running watch-underscores manually"
  /local-scripts/watch-understrap.sh &
  echo "any sign of success"?

}

main() {
  h1 "Begin WordPress Installation"
  init

  # Wait for MySQL
  # --------------
  h2 "Waiting for MySQL to initialize..."
  while ! mysqladmin ping --host="$DB_HOST" --password="$DB_PASS" --silent; do
    sleep 1
  done

  h2 "Configuring WordPress"
  rm -f /wordpress/wp-config.php
  _wp core config
  _log_last_exit_colorize "Success: core config" "Error: core config failed!"

  h2 "Checking database"
  check_database

  if [[ "$MULTISITE" == "true" ]]; then
    h2 "Enabling Multisite"
    _wp core multisite-convert
    _log_last_exit_colorize "Success: core multisite-convert" "Error: core multisite-convert failed!"
  fi

  h2 "Checking themes"
  check_themes

  h2 "Checking plugins"
  check_plugins

  # Wait for MySQL
  # --------------
  h2 "Waiting for MySQL to initialize..."
  while ! mysqladmin ping --host="$DB_HOST" --password="$DB_PASS" --silent; do
   sleep 1
  done

  
  h2 "Installing development theme"
  /wait-for-it.sh gulp:3001 -- echo "gulp is up, activating script"
  get_dev_theme
  # h2 "Running local scripts from /local-scripts directory"
  # add_local_scripts

  h2 "Finalizing"
  if [[ "$MULTISITE" != 'true' ]]; then
    _wp rewrite structure "$PERMALINKS"
    _log_last_exit_colorize "Success: rewrite structure" "Error: rewrite structure failed!"

    _wp rewrite flush --hard
    _log_last_exit_colorize "Success: rewrite flush" "Error: rewrite flush failed!"
  fi

  chown -R www-data /wordpress /var/www/html
  find /wordpress -type d -exec chmod 755 {} \;
  find /wordpress -type f -exec chmod 644 {} \;
  find /wordpress \( -type f -or -type d \) ! -group www-data -exec chmod g+rw {} \;
  chmod -R a+rw /wordpress/wp-content/
  h1 "WordPress Configuration Complete!"

  rm -f /var/run/apache2/apache2.pid
  . /etc/apache2/envvars
  exec apache2 -D FOREGROUND
}

main
