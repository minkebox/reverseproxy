FROM alpine:3.12

RUN apk add nginx dnsmasq openssl curl git ;\
    rm -f /etc/nginx/conf.d/default.conf ;\
    mkdir -p /etc/nginx/sites-enabled /etc/nginx/acme.sh /etc/acme.sh/data ;\
    cd /tmp ;\
    git clone --depth 1 https://github.com/acmesh-official/acme.sh.git ;\
    cd /tmp/acme.sh ;\
    ./acme.sh --install --home /etc/acme.sh --config-home /etc/acme.sh/data --cert-home /etc/acme.sh/certs ;\
    rm -rf /tmp/acme.sh ;\
    apk del git

COPY root/ /

EXPOSE 80 443

VOLUME /etc/nginx/acme.sh /etc/acme.sh/data

HEALTHCHECK --interval=60s --timeout=5s CMD /health.sh

ENTRYPOINT ["/startup.sh"]
