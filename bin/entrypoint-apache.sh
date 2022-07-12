#!/usr/bin/env bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202207112232-git
# @Author            :  Jason Hempstead
# @Contact           :  jason@casjaysdev.com
# @License           :  LICENSE.md
# @ReadME            :  entrypoint-apache.sh --help
# @Copyright         :  Copyright: (c) 2022 Jason Hempstead, Casjays Developments
# @Created           :  Monday, Jul 11, 2022 22:32 EDT
# @File              :  entrypoint-apache.sh
# @Description       :
# @TODO              :
# @Other             :
# @Resource          :
# @sudo/root         :  no
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
APPNAME="$(basename "$0" 2>/dev/null)"
VERSION="202207112232-git"
HOME="${USER_HOME:-$HOME}"
USER="${SUDO_USER:-$USER}"
RUN_USER="${SUDO_USER:-$USER}"
SRC_DIR="${BASH_SOURCE%/*}"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set bash options
if [[ "$1" == "--debug" ]]; then shift 1 && set -xo pipefail && export SCRIPT_OPTS="--debug" && export _DEBUG="on"; fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set functions
__exec_bash() {
  local cmd="${*:-/bin/bash}"
  local exitCode=0
  echo "Executing command: $cmd"
  $cmd || exitCode=10
  return ${exitCode:-$?}
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__find() { ls -A "$*" 2>/dev/null; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Define default variables
TZ="${TZ:-America/New_York}"
HOSTNAME="${HOSTNAME:-casjaysdev-bin}"
BIN_DIR="${BIN_DIR:-/usr/local/bin}"
DATA_DIR="${DATA_DIR:-$(__find /data/ 2>/dev/null | grep '^' || false)}"
CONFIG_DIR="${CONFIG_DIR:-$(__find /config/ 2>/dev/null | grep '^' || false)}"
CONFIG_COPY="${CONFIG_COPY:-false}"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Additional variables
SSL="${SSL:-}"
HOSTADMIN="${HOSTADMIN:-admin@localhost}"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Export variables
export TZ HOSTNAME
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# import variables from file
[[ -f "/root/env.sh" ]] && . "/root/env.sh"
[[ -f "/config/.env.sh" ]] && . "/config/.env.sh"
[[ -f "/root/env.sh" ]] && [[ ! -f "/config/.env.sh" ]] && cp -Rf "/root/env.sh" "/config/.env.sh"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set timezone
[[ -n "${TZ}" ]] && echo "${TZ}" >/etc/timezone
[[ -f "/usr/share/zoneinfo/${TZ}" ]] && ln -sf "/usr/share/zoneinfo/${TZ}" "/etc/localtime"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set hostname
if [[ -n "${HOSTNAME}" ]]; then
  echo "${HOSTNAME}" >/etc/hostname
  echo "127.0.0.1 ${HOSTNAME} localhost ${HOSTNAME}.local" >/etc/hosts
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Delete any gitkeep files
[[ -n "${CONFIG_DIR}" ]] && { [[ -d "${CONFIG_DIR}" ]] && rm -Rf "${CONFIG_DIR}/.gitkeep" || mkdir -p "/config/"; }
[[ -n "${DATA_DIR}" ]] && { [[ -d "${DATA_DIR}" ]] && rm -Rf "${DATA_DIR}/.gitkeep" || mkdir -p "/data/"; }
[[ -n "${BIN_DIR}" ]] && { [[ -d "${BIN_DIR}" ]] && rm -Rf "${BIN_DIR}/.gitkeep" || mkdir -p "/bin/"; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Copy config files to /etc
if [[ -n "${CONFIG_DIR}" ]] && [[ "${CONFIG_COPY}" = "true" ]]; then
  for config in ${CONFIG_DIR}; do
    if [[ -d "/config/$config" ]]; then
      [[ -d "/etc/$config" ]] || mkdir -p "/etc/$config"
      cp -Rf "/config/$config/." "/etc/$config/"
    elif [[ -f "/config/$config" ]]; then
      cp -Rf "/config/$config" "/etc/$config"
    fi
  done
fi
[[ -f "/etc/.env.sh" ]] && rm -Rf "/etc/.env.sh"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Additional commands
[[ -d "$DATA_DIR/htdocs/www" ]] && cp -Rf "$DATA_DIR/htdocs/www/." "/var/www/localhost/htdocs"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ -f "/config/ssl/server.crt" ] && [ -f "/config/ssl/server.key" ]; then
  SSL="on"
  SSL_CERT="/config/ssl/server.crt"
  SSL_KEY="/config/ssl/server.key"
  if [ -f "/config/ssl/ca.crt" ]; then
    cat "/config/ssl/ca.crt" >>"/etc/ssl/certs/ca-certificates.crt"
  fi
elif [ "$SSL" = "on" ]; then
  create-ssl-cert "/config/ssl"
fi
update-ca-certificates
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ "$SSL" = on ] && [ -z "$CONFIG" ]; then
  CONFIG="/config/apache2/httpd.ssl.conf"
else
  CONFIG="${APACHE_CONF:-/config/apache2/httpd.conf}"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ -f "/config/php8/php.ini" ]; then
  cp -Rf "/config/php8/php.ini" "/etc/php8/php.ini"
else
  mkdir -p "/config/php8"
  cp -Rf "/etc/php8/php.ini" "/config/php8/php.ini"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ -d "/config/php8/php-fpm.d" ]; then
  cp -Rf /config/php8/php-fpm.* "/etc/php8/"
else
  mkdir -p "/config/php8"
  cp -Rf /etc/php8/php-fpm.* "/config/php8/"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ ! -f "/data/htdocs/www/index.html" ] || [ ! -f "/data/htdocs/www/index.php" ]; then
  [ -f "/data/htdocs/.docker_complete" ] || cp -Rf "/var/www/localhost/htdocs/." "/data/htdocs/www/"
  touch "/data/htdocs/.docker_complete"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ -f "/etc/apache2/httpd.conf" ] && [ ! -f "$CONFIG" ]; then
  cp -Rf "/etc/apache2/httpd.conf" "$CONFIG"
  sed -i "s/ServerName .*/ServerName $HOSTNAME/" "$CONFIG"
  sed -i "s/ServerAdmin .*/ServerAdmin $HOSTADMIN/" "$CONFIG"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
case "$1" in
--help) # Help message
  echo 'Docker container for '$APPNAME''
  echo "Usage: $APPNAME [healthcheck, bash, command]"
  echo "Failed command will have exit code 10"
  echo
  exitCode=$?
  ;;

healthcheck) # Docker healthcheck
  if curl -q -LSsf -o /dev/null -s -w "200" "http://localhost/server-health"; then
    echo "$(uname -s) $(uname -m) is running"
    exit 0
  else
    echo "Apache web server has failed"
    exit 10
  fi
  exitCode=$?
  ;;

*/bin/sh | */bin/bash | bash | shell | sh) # Launch shell
  shift 1
  __exec_bash "${@:-/bin/bash}"
  exitCode=$?
  ;;

*) # Execute primary command
  if [[ $# -eq 0 ]]; then
    rm -f /usr/local/apache2/logs/httpd.pid
    [ -f "$CONFIG" ] && exec httpd -f "$CONFIG" -DFOREGROUND || exit 10
  else
    __exec_bash "/bin/bash"
  fi
  exitCode=$?
  ;;
esac
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# end of entrypoint
exit ${exitCode:-$?}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
