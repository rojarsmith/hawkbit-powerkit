ARG NGINX_VERSION=1.27.5
FROM nginx:${NGINX_VERSION}-alpine

ARG HTTP_PORT=8080
ARG HTTPS_PORT=443
EXPOSE ${HTTP_PORT}
EXPOSE ${HTTPS_PORT}

RUN set -ex \
    && apk upgrade --update-cache --available \
    && apk add bash git openssl \
    && git clone https://github.com/acmesh-official/acme.sh.git acmesh_src \
    && cd /acmesh_src && ./acme.sh --install --cert-home /acmesh_cert \
    && apk del git \
    && rm -rf /acmesh_src /var/cache/apk/* \
    && mkdir -p /etc/nginx/ssl \
    && alias acme.sh=~/.acme.sh/acme.sh

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

VOLUME "/usr/share/nginx/html"
RUN chmod -R 644 /usr/share/nginx/html

ENTRYPOINT ["/docker-entrypoint.sh"]
