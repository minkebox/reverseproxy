FROM alpine:latest

RUN apk --no-cache add nginx dnsmasq miniupnpc ;\
    rm -f /etc/nginx/conf.d/default.conf

COPY root/ /

EXPOSE 80 

ENTRYPOINT ["/startup.sh"]
