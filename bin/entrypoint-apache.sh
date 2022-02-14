#!/usr/bin/env bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version       : 202202020147-git
# @Author        : Jason Hempstead
# @Contact       : jason@casjaysdev.com
# @License       : WTFPL
# @ReadME        : docker-entrypoint --help
# @Copyright     : Copyright: (c) 2022 Jason Hempstead, Casjays Developments
# @Created       : Wednesday, Feb 02, 2022 01:47 EST
# @File          : docker-entrypoint
# @Description   :
# @TODO          :
# @Other         :
# @Resource      :
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
APPNAME="$(basename "$0")"
VERSION="202202020147-git"
USER="${SUDO_USER:-${USER}}"
HOME="${USER_HOME:-${HOME}}"
SRC_DIR="${BASH_SOURCE%/*}"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set bash options
if [[ "$1" == "--debug" ]]; then shift 1 && set -xo pipefail && export SCRIPT_OPTS="--debug" && export _DEBUG="on"; fi
trap 'exitCode=${exitCode:-$?};[ -n "$DOCKER_ENTRYPOINT_TEMP_FILE" ] && [ -f "$DOCKER_ENTRYPOINT_TEMP_FILE" ] && rm -Rf "$DOCKER_ENTRYPOINT_TEMP_FILE" &>/dev/null' EXIT

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SSL="${SSL:-}"
HOSTADMIN="${HOSTADMIN:-admin@localhost}"
export TZ="${TZ:-America/New_York}"
export HOSTNAME="${HOSTNAME:-casjaysdev-apache}"

[ -n "${TZ}" ] && echo "${TZ}" >/etc/timezone
[ -n "${HOSTNAME}" ] && echo "${HOSTNAME}" >/etc/hostname
[ -n "${HOSTNAME}" ] && echo "127.0.0.1 $HOSTNAME localhost" >/etc/hosts
[ -f "/usr/share/zoneinfo/${TZ}" ] && ln -sf "/usr/share/zoneinfo/${TZ}" "/etc/localtime"

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

if [ "$SSL" = on ] && [ -z "$CONFIG" ]; then
  CONFIG="/config/apache2/httpd.ssl.conf"
else
  CONFIG="${APACHE_CONF:-/config/apache2/httpd.conf}"
fi

if [ -f "/config/php8/php.ini" ]; then
  cp -Rf "/config/php8/php.ini" "/etc/php8/php.ini"
else
  mkdir -p "/config/php8"
  cp -Rf "/etc/php8/php.ini" "/config/php8/php.ini"
fi

if [ -d "/config/php8/php-fpm.d" ]; then
  cp -Rf /config/php8/php-fpm.* "/etc/php8/"
else
  mkdir -p "/config/php8"
  cp -Rf /etc/php8/php-fpm.* "/config/php8/"
fi

if [ ! -f "/data/htdocs/www/index.html" ] || [ ! -f "/data/htdocs/www/index.php" ]; then
  [ -f "/data/htdocs/.docker_complete" ] || cp -Rf "/var/www/localhost/htdocs/." "/data/htdocs/www/"
  touch "/data/htdocs/.docker_complete"
fi

if [ -f "/etc/apache2/httpd.conf" ] && [ ! -f "$CONFIG" ]; then
  cp -Rf "/etc/apache2/httpd.conf" "$CONFIG"
  sed -i "s/ServerName .*/ServerName $HOSTNAME/" "$CONFIG"
  sed -i "s/ServerAdmin .*/ServerAdmin $HOSTADMIN/" "$CONFIG"
fi

case "$1" in

healthcheck)
  if curl -q -LSsf -o /dev/null -s -w "200" "http://localhost/server-health"; then
    echo "OK"
    exit 0
  else
    echo "FAIL"
    exit 10
  fi
  ;;

bash | shell | sh)
  ARGS="$*"
  exec /bin/bash ${ARGS:--l}
  ;;

*)
  rm -f /usr/local/apache2/logs/httpd.pid
  [ -f "$CONFIG" ] && exec httpd -f "$CONFIG" -DFOREGROUND "$@" || exit 10
  ;;
esac
