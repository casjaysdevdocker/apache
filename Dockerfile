# setup webserver
FROM casjaysdevdocker/php:latest as apache2

RUN apk -U upgrade && \
  apk add --no-cache \
  apache2 \
  apache2-brotli \
  apache2-ctl \
  apache2-http2 \
  apache2-icons \
  apache2-ldap \
  apache2-lua \
  apache2-mod-wsgi \
  apache2-proxy \
  apache2-ssl \
  apache2-webdav 

COPY ./data/htdocs/www/ /var/www/localhost/htdocs/
COPY ./config/apache2/httpd.conf /etc/apache2/httpd.conf
COPY ./bin/. /usr/local/bin/

# build container
FROM apache2
ARG BUILD_DATE="$(date +'%Y-%m-%d %H:%M')" 

LABEL \
  org.label-schema.name="apache2" \
  org.label-schema.description="Apache2 web server based on Alpine" \
  org.label-schema.url="https://hub.docker.com/r/casjaysdevdocker/apache" \
  org.label-schema.vcs-url="https://github.com/casjaysdevdocker/apache" \
  org.label-schema.build-date=$BUILD_DATE \
  org.label-schema.version=$BUILD_DATE \
  org.label-schema.vcs-ref=$BUILD_DATE \
  org.label-schema.license="WTFPL" \
  org.label-schema.vcs-type="Git" \
  org.label-schema.schema-version="latest" \
  org.label-schema.vendor="CasjaysDev" \
  maintainer="CasjaysDev <docker-admin@casjaysdev.com>" 

ENV PHP_SERVER=apache2

EXPOSE 19000

WORKDIR /data/htdocs
VOLUME [ "/data", "/config" ]

HEALTHCHECK CMD ["/usr/local/bin/entrypoint-apache.sh", "healthcheck"]

ENTRYPOINT ["/usr/local/bin/entrypoint-apache.sh"]
