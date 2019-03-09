FROM alpine:latest

RUN apk --no-cache add nginx dnsmasq ;\
    rm -f /etc/nginx/conf.d/default.conf

COPY root/ /

EXPOSE 80 443 

ENTRYPOINT ["/startup.sh"]
