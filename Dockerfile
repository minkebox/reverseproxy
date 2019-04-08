FROM alpine:latest

RUN apk --no-cache add nginx dnsmasq ;\
    rm -f /etc/nginx/conf.d/default.conf ;\
    mkdir -p /etc/nginx/sites-enabled

COPY root/ /

EXPOSE 80 

ENTRYPOINT ["/startup.sh"]
